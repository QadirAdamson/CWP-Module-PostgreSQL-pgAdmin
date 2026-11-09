#!/bin/bash
# ==============================================================================
# Uninstaller for PostgreSQL / pgAdmin 4 CWP Module
# Author: Qadir Adamson
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   Uninstalling PostgreSQL / pgAdmin 4 Module for CWP                     ${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This uninstaller must be run as root!${NC}"
    exit 1
fi

# 1. Remove CWP module and menu files
echo -e "\n${YELLOW}[1/4] Removing CWP Admin modules and menus...${NC}"
rm -f /usr/local/cwpsrv/htdocs/resources/admin/modules/postgresql-pgadmin.php
rm -f /usr/local/cwpsrv/htdocs/resources/admin/include/pg_menu.php
sed -i '/pg_menu.php/d' /usr/local/cwpsrv/htdocs/resources/admin/include/3rdparty.php 2>/dev/null || true

# 2. Remove sudoers and helper scripts
echo -e "\n${YELLOW}[2/4] Removing helper scripts & permissions...${NC}"
rm -f /usr/local/bin/cwp_pg_ctl.sh
rm -f /etc/sudoers.d/cwpsrv_pg

# 3. Stop & disable pgadmin4 service
echo -e "\n${YELLOW}[3/4] Stopping and removing pgAdmin 4 service...${NC}"
systemctl stop pgadmin4 2>/dev/null || true
systemctl disable pgadmin4 2>/dev/null || true
rm -f /etc/systemd/system/pgadmin4.service
systemctl daemon-reload

# 4. Remove any legacy cwpsrv proxy configuration
echo -e "\n${YELLOW}[4/4] Cleaning CWP web server configuration...${NC}"
sed -i '/# pgAdmin 4 Reverse Proxy/,+17d' /usr/local/cwpsrv/conf/cwp_services.conf 2>/dev/null || true
sed -i '/location \/pgadmin\//,+15d' /usr/local/cwpsrv/conf/cwp_services.conf 2>/dev/null || true
sed -i '/location = \/pgadmin/,+2d' /usr/local/cwpsrv/conf/cwp_services.conf 2>/dev/null || true
systemctl reload cwpsrv 2>/dev/null || true

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  Uninstallation completed successfully!                                      ${NC}"
echo -e "${GREEN}  (PostgreSQL databases and packages have been preserved for data safety)     ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
