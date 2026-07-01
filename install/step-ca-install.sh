#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Joerg Heinemann (heinemannj)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://github.com/smallstep/certificates

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

if [[ -z "${STEP_CA_DB_MODE:-}" ]]; then
  if prompt_confirm "Install step-ca with MariaDB backend for LabCA compatibility?" "n" 60; then
    STEP_CA_DB_MODE="mysql"
  else
    STEP_CA_DB_MODE="badger"
  fi
fi

setup_step_ca

motd_ssh
customize
cleanup_lxc
