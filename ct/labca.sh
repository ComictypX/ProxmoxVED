#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/hakwerk/labca

APP="LabCA"
var_tags="${var_tags:-certificate-authority;pki;gui}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

LABCA_CUSTOM_CPU="${var_cpu:-}"
LABCA_CUSTOM_RAM="${var_ram:-}"
LABCA_CUSTOM_DISK="${var_disk:-}"

function configure_labca_resources() {
  if command -v pveversion >/dev/null 2>&1; then
    if [[ -z "${LABCA_INSTALL_STEP_CA:-}" ]]; then
      ensure_whiptail
      if timeout 60 whiptail --backtitle "Proxmox VE Helper Scripts" --defaultno --title "LABCA STEP-CA" --yesno \
        "Install a local MariaDB-backed step-ca in this same LXC?\n\nNo creates a smaller LabCA-only container and lets you connect LabCA to an external MySQL/MariaDB-backed step-ca later.\n\nDefault after 60 seconds: No" \
        14 78; then
        export LABCA_INSTALL_STEP_CA="yes"
      else
        export LABCA_INSTALL_STEP_CA="no"
      fi
    fi

    case "${LABCA_INSTALL_STEP_CA,,}" in
    y | yes | true | 1)
      export LABCA_INSTALL_STEP_CA="yes"
      [[ -z "$LABCA_CUSTOM_CPU" ]] && var_cpu="2"
      [[ -z "$LABCA_CUSTOM_RAM" ]] && var_ram="1024"
      [[ -z "$LABCA_CUSTOM_DISK" ]] && var_disk="8"
      ;;
    n | no | false | 0)
      export LABCA_INSTALL_STEP_CA="no"
      [[ -z "$LABCA_CUSTOM_CPU" ]] && var_cpu="1"
      [[ -z "$LABCA_CUSTOM_RAM" ]] && var_ram="512"
      [[ -z "$LABCA_CUSTOM_DISK" ]] && var_disk="2"
      ;;
    *)
      msg_warn "Invalid LABCA_INSTALL_STEP_CA value '${LABCA_INSTALL_STEP_CA}', using LabCA-only resource defaults."
      export LABCA_INSTALL_STEP_CA="no"
      [[ -z "$LABCA_CUSTOM_CPU" ]] && var_cpu="1"
      [[ -z "$LABCA_CUSTOM_RAM" ]] && var_ram="512"
      [[ -z "$LABCA_CUSTOM_DISK" ]] && var_disk="2"
      ;;
    esac
  fi

  var_cpu="${var_cpu:-1}"
  var_ram="${var_ram:-512}"
  var_disk="${var_disk:-2}"
}

header_info "$APP"
color
configure_labca_resources
variables
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /usr/bin/labca-gui ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  if check_for_gh_release "labca-gui" "hakwerk/labca"; then
    msg_info "Stopping Service"
    systemctl stop labca
    msg_ok "Stopped Service"

    fetch_and_deploy_gh_release "labca-gui" "hakwerk/labca" "binary"

    msg_info "Starting Service"
    systemctl start labca
    msg_ok "Started Service"
    msg_ok "Updated successfully!"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
