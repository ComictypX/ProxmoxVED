#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/hakwerk/labca

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

LABCA_STEP_CA_LOCAL="no"
LABCA_STEP_CA_DB_MODE=""

if [[ -f /etc/step-ca/config/ca.json ]]; then
  LABCA_STEP_CA_DB_MODE="$(step_ca_db_mode /etc/step-ca/config/ca.json || true)"
  case "$LABCA_STEP_CA_DB_MODE" in
  mysql)
    LABCA_STEP_CA_LOCAL="yes"
    msg_ok "Found LabCA-compatible local step-ca with MySQL/MariaDB backend"
    ;;
  badger | badgerv1 | badgerv2)
    msg_warn "Found local step-ca with ${LABCA_STEP_CA_DB_MODE} backend"
    msg_warn "LabCA standalone requires a MySQL/MariaDB-backed step-ca instance. Existing BadgerDB instances are not migrated automatically."
    ;;
  *)
    msg_warn "Found local step-ca with unknown database backend"
    msg_warn "LabCA standalone requires a MySQL/MariaDB-backed step-ca instance."
    ;;
  esac
else
  LABCA_INSTALL_STEP_CA="${LABCA_INSTALL_STEP_CA:-}"
  if [[ -z "$LABCA_INSTALL_STEP_CA" ]]; then
    if prompt_confirm "Install a local MariaDB-backed step-ca in this same LXC for LabCA?" "n" 60; then
      LABCA_INSTALL_STEP_CA="yes"
    else
      LABCA_INSTALL_STEP_CA="no"
    fi
  fi

  case "${LABCA_INSTALL_STEP_CA,,}" in
  y | yes | true | 1)
    STEP_CA_DB_MODE="mysql"
    STEP_CA_INSTALL_STEP_BADGER="no"
    setup_step_ca
    LABCA_STEP_CA_LOCAL="yes"
    LABCA_STEP_CA_DB_MODE="mysql"
    if [[ -n "${MARIADB_DB_PASS:-}" ]]; then
      msg_info "Local step-ca Database"
      echo -e "${TAB}${GATEWAY}${BGN}Host: 127.0.0.1${CL}"
      echo -e "${TAB}${GATEWAY}${BGN}Port: 3306${CL}"
      echo -e "${TAB}${GATEWAY}${BGN}Database: ${MARIADB_DB_NAME}${CL}"
      echo -e "${TAB}${GATEWAY}${BGN}Username: ${MARIADB_DB_USER}${CL}"
      echo -e "${TAB}${GATEWAY}${BGN}Password: ${MARIADB_DB_PASS}${CL}"
      msg_ok "Displayed local step-ca Database"
    fi
    ;;
  n | no | false | 0)
    msg_warn "Skipping local step-ca installation. Configure LabCA with an external MySQL/MariaDB-backed step-ca on first access."
    ;;
  *)
    msg_warn "Invalid LABCA_INSTALL_STEP_CA value '${LABCA_INSTALL_STEP_CA}', skipping local step-ca installation."
    ;;
  esac
fi

fetch_and_deploy_gh_release "labca-gui" "hakwerk/labca" "binary"

msg_info "Configuring LabCA"
mkdir -p /etc/labca
if [[ ! -f /etc/labca/config.json ]]; then
  if ! $STD /usr/bin/labca-gui -config /etc/labca/config.json -port 3000 -init; then
    cat <<EOF >/etc/labca/config.json
{
    "standalone": true
}
EOF
  fi
fi
msg_ok "Configured LabCA"

msg_info "Creating Service"
LABCA_SERVICE_AFTER="network-online.target"
LABCA_SERVICE_WANTS="network-online.target"
LABCA_SERVICE_REQUIRES=""
if [[ "$LABCA_STEP_CA_LOCAL" == "yes" ]]; then
  LABCA_SERVICE_AFTER="network-online.target step-ca.service mariadb.service"
  LABCA_SERVICE_WANTS="network-online.target step-ca.service"
  LABCA_SERVICE_REQUIRES="Requires=step-ca.service mariadb.service"
fi

cat <<EOF >/etc/systemd/system/labca.service
[Unit]
Description=LabCA GUI Service
After=${LABCA_SERVICE_AFTER}
Wants=${LABCA_SERVICE_WANTS}
${LABCA_SERVICE_REQUIRES}
StartLimitIntervalSec=30
StartLimitBurst=3

[Service]
Type=simple
ExecStart=/usr/bin/labca-gui -config /etc/labca/config.json -port 3000
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now labca
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc
