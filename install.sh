#!/bin/bash
# ==============================================================================
# PostgreSQL / pgAdmin 4 Module for Control Web Panel (CWP)
# Author: Qadir Adamson
# Description: Automated installer for PostgreSQL, pgAdmin 4 Web and CWP Admin Module
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}   PostgreSQL / pgAdmin 4 Manager for Control Web Panel (CWP)              ${NC}"
echo -e "${BLUE}==============================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This installer must be run as root!${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ask user for PostgreSQL version (default to latest LTS: 17 with 10s timeout)
echo -e "\n${CYAN}Available PostgreSQL LTS Versions:${NC}"
echo -e "  [1] PostgreSQL 14"
echo -e "  [2] PostgreSQL 15"
echo -e "  [3] PostgreSQL 16"
echo -e "  [4] PostgreSQL 17 (Recommended / Latest LTS)"
echo -e "  [5] PostgreSQL 18"

PG_CHOICE=""
if [ -e /dev/tty ]; then
    read -t 10 -p "Select PostgreSQL version to install [1-5] (Default: 4 -> PostgreSQL 17 in 10s): " PG_CHOICE < /dev/tty || true
    echo ""
fi

case "$PG_CHOICE" in
    1) PG_VER=14 ;;
    2) PG_VER=15 ;;
    3) PG_VER=16 ;;
    5) PG_VER=18 ;;
    4|"") PG_VER=17 ;;
    *)
        echo -e "${YELLOW}Invalid option. Defaulting to PostgreSQL 17.${NC}"
        PG_VER=17
        ;;
esac

echo -e "${GREEN}Selected version: PostgreSQL ${PG_VER}${NC}"

# Stop any previously running PostgreSQL services to avoid port 5432 conflicts
for v in 14 15 16 17 18; do
    systemctl stop postgresql-$v 2>/dev/null || true
    systemctl disable postgresql-$v 2>/dev/null || true
done
systemctl stop postgresql 2>/dev/null || true
systemctl disable postgresql 2>/dev/null || true

# 1. Install PostgreSQL Repo & Selected Version
echo -e "\n${YELLOW}[1/6] Installing PostgreSQL ${PG_VER}...${NC}"
if ! rpm -q pgdg-redhat-repo >/dev/null 2>&1; then
    dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm 2>/dev/null || true
fi
dnf -qy module disable postgresql 2>/dev/null || true

if ! rpm -q postgresql${PG_VER}-server >/dev/null 2>&1; then
    dnf install -y postgresql${PG_VER}-server postgresql${PG_VER}-contrib
fi

# 2. Init DB & Configure Auth
echo -e "\n${YELLOW}[2/6] Configuring PostgreSQL ${PG_VER}...${NC}"

# Ensure postgres user has a valid shell for initdb & CLI commands (EL packages set /sbin/nologin by default)
usermod -s /bin/bash postgres 2>/dev/null || true

if [ ! -d "/var/lib/pgsql/${PG_VER}/data/base" ]; then
    /usr/pgsql-${PG_VER}/bin/postgresql-${PG_VER}-setup initdb || {
        echo -e "${YELLOW}Retrying initdb directly via postgres user...${NC}"
        su - postgres -c "/usr/pgsql-${PG_VER}/bin/initdb -D /var/lib/pgsql/${PG_VER}/data"
    }
fi

if [ -f "/var/lib/pgsql/${PG_VER}/data/pg_hba.conf" ]; then
    sed -i 's/scram-sha-256/md5/g' /var/lib/pgsql/${PG_VER}/data/pg_hba.conf 2>/dev/null || true
    sed -i 's/peer/trust/g' /var/lib/pgsql/${PG_VER}/data/pg_hba.conf 2>/dev/null || true
    sed -i 's/ident/md5/g' /var/lib/pgsql/${PG_VER}/data/pg_hba.conf 2>/dev/null || true
fi

systemctl daemon-reload
systemctl enable --now postgresql-${PG_VER}
echo "${PG_VER}" > /etc/cwp_active_pg_version

# Wait briefly for PostgreSQL service to listen
for i in {1..10}; do
    if systemctl is-active --quiet postgresql-${PG_VER}; then
        break
    fi
    sleep 1
done

# Set default password for postgres user
su - postgres -c "psql -p 5432 -c \"ALTER USER postgres WITH PASSWORD '2qvUkiz7BgXGvNDx';\"" 2>/dev/null || true

# 3. Install pgAdmin 4 Web (Latest compatible version)
echo -e "\n${YELLOW}[3/6] Installing latest pgAdmin 4 Web for PostgreSQL ${PG_VER}...${NC}"
rpm -Uvh --replacepkgs --nodeps https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-redhat-repo-2-1.noarch.rpm 2>/dev/null || \
    dnf install -y https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-redhat-repo-2-1.noarch.rpm 2>/dev/null || true

rpm --import https://www.pgadmin.org/static/packages_pgadmin_org.pub 2>/dev/null || true
rpm --import /etc/pki/rpm-gpg/PGADMIN_PKG_KEY 2>/dev/null || true

# Refresh repository cache to ensure the newest packages are resolved
dnf clean expire-cache --disablerepo="*" --enablerepo="pgAdmin4" 2>/dev/null || true

# Install or upgrade to the latest pgAdmin 4 Web & Server packages
dnf install -y --best pgadmin4-web pgadmin4-server || dnf install -y pgadmin4-web pgadmin4-server
dnf upgrade -y --best pgadmin4-web pgadmin4-server 2>/dev/null || true

PGADMIN_VER=$(rpm -q --queryformat '%{VERSION}' pgadmin4-web 2>/dev/null || echo "latest")
echo -e "${GREEN}✓ pgAdmin 4 version ${PGADMIN_VER} successfully installed and updated.${NC}"

# 4. Setup pgAdmin 4 Python environment and systemd service
echo -e "\n${YELLOW}[4/6] Setting up pgAdmin 4 service & admin account...${NC}"
mkdir -p /var/log/pgadmin /var/lib/pgadmin /etc/pgadmin

cat << 'PGLOCAL' > /etc/pgadmin/config_system.py
SERVER_MODE = True
DEFAULT_SERVER = '0.0.0.0'
DEFAULT_SERVER_PORT = 5050
DATA_DIR = '/var/lib/pgadmin'
LOG_FILE = '/var/log/pgadmin/pgadmin4.log'
SQLITE_PATH = '/var/lib/pgadmin/pgadmin4.db'
SESSION_DB_PATH = '/var/lib/pgadmin/sessions'
STORAGE_DIR = '/var/lib/pgadmin/storage'
PGLOCAL

cat << 'RUNPY' > /usr/pgadmin4/run_pgadmin.py
import sys, os
sys.path.insert(0, '/usr/pgadmin4/web')
from pgAdmin4 import app
import werkzeug.serving

if __name__ == '__main__':
    werkzeug.serving.run_simple('0.0.0.0', 5050, app, threaded=True)
RUNPY

# Initialize pgAdmin database non-interactively
export PGADMIN_SETUP_EMAIL="admin@cwp.com"
export PGADMIN_SETUP_PASSWORD="admin1234"
/usr/pgadmin4/venv/bin/python3 /usr/pgadmin4/web/setup.py setup-db 2>/dev/null || true

# Pre-configure local PostgreSQL server in pgAdmin
cat << 'JSON' > /tmp/pga_initial_servers.json
{
    "Servers": {
        "1": {
            "Name": "PostgreSQL (Localhost)",
            "Group": "Servers",
            "Port": 5432,
            "Username": "postgres",
            "Host": "127.0.0.1",
            "SSLMode": "prefer",
            "MaintenanceDB": "postgres"
        }
    }
}
JSON
/usr/pgadmin4/venv/bin/python3 /usr/pgadmin4/web/setup.py load-servers /tmp/pga_initial_servers.json --user admin@cwp.com --replace 2>/dev/null || true
rm -f /tmp/pga_initial_servers.json

cat << 'PGSERVICE' > /etc/systemd/system/pgadmin4.service
[Unit]
Description=pgAdmin 4 Web Service
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/usr/pgadmin4/web
Environment="PYTHONPATH=/usr/pgadmin4/web"
ExecStart=/usr/pgadmin4/venv/bin/python3 /usr/pgadmin4/run_pgadmin.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
PGSERVICE

systemctl daemon-reload
systemctl enable --now pgadmin4
systemctl restart pgadmin4

# 5. Clean any legacy cwpsrv reverse proxy & open standalone pgAdmin port 5050
echo -e "\n${YELLOW}[5/6] Opening pgAdmin Web Port 5050 in Firewall...${NC}"
sed -i '/location \/pgadmin\//,+15d' /usr/local/cwpsrv/conf/cwp_services.conf 2>/dev/null || true
sed -i '/location = \/pgadmin/,+2d' /usr/local/cwpsrv/conf/cwp_services.conf 2>/dev/null || true
systemctl reload cwpsrv 2>/dev/null || true

iptables -I INPUT -p tcp --dport 5050 -j ACCEPT 2>/dev/null || true
if which firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
    firewall-cmd --add-port=5050/tcp --permanent 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
fi
if [ -f /etc/csf/csf.conf ]; then
    if ! grep -E '^TCP_IN = .*5050' /etc/csf/csf.conf >/dev/null 2>&1; then
        sed -i -E 's/(TCP_IN = "[^"]*)/\1,5050/' /etc/csf/csf.conf 2>/dev/null || true
        csf -r 2>/dev/null || true
    fi
fi

# 6. Deploy CWP Module & Controller Script
echo -e "\n${YELLOW}[6/6] Installing CWP Admin Module and Menu...${NC}"
REPO_RAW="https://raw.githubusercontent.com/QadirAdamson/CWP-Module-PostgreSQL-pgAdmin/main"
if [ -f "$SCRIPT_DIR/root/cwp_pg_ctl.sh" ]; then
    cp -f "$SCRIPT_DIR/root/cwp_pg_ctl.sh" /usr/local/bin/cwp_pg_ctl.sh
    cp -f "$SCRIPT_DIR/resources/admin/modules/postgresql-pgadmin.php" /usr/local/cwpsrv/htdocs/resources/admin/modules/
    cp -f "$SCRIPT_DIR/resources/admin/include/pg_menu.php" /usr/local/cwpsrv/htdocs/resources/admin/include/
else
    curl -fsSL "$REPO_RAW/root/cwp_pg_ctl.sh" -o /usr/local/bin/cwp_pg_ctl.sh
    curl -fsSL "$REPO_RAW/resources/admin/modules/postgresql-pgadmin.php" -o /usr/local/cwpsrv/htdocs/resources/admin/modules/postgresql-pgadmin.php
    curl -fsSL "$REPO_RAW/resources/admin/include/pg_menu.php" -o /usr/local/cwpsrv/htdocs/resources/admin/include/pg_menu.php
fi
chmod +x /usr/local/bin/cwp_pg_ctl.sh
chmod 644 /usr/local/cwpsrv/htdocs/resources/admin/modules/postgresql-pgadmin.php /usr/local/cwpsrv/htdocs/resources/admin/include/pg_menu.php

# Sudoers permission for cwpsrv
cat << 'SUDO' > /etc/sudoers.d/cwpsrv_pg
cwpsrv ALL=(ALL) NOPASSWD: /usr/local/bin/cwp_pg_ctl.sh
SUDO
chmod 440 /etc/sudoers.d/cwpsrv_pg

# Compatibility alias for CWP default module name if missing
if [ ! -f /usr/local/cwpsrv/htdocs/resources/admin/modules/postgresql_manager.php ]; then
    echo "<?php include_once __DIR__ . '/postgresql-pgadmin.php'; ?>" > /usr/local/cwpsrv/htdocs/resources/admin/modules/postgresql_manager.php
    chmod 644 /usr/local/cwpsrv/htdocs/resources/admin/modules/postgresql_manager.php
fi

# Include menu into 3rdparty.php if not already present
if ! grep -q "pg_menu.php" /usr/local/cwpsrv/htdocs/resources/admin/include/3rdparty.php 2>/dev/null; then
    echo "<?php include_once('/usr/local/cwpsrv/htdocs/resources/admin/include/pg_menu.php'); ?>" >> /usr/local/cwpsrv/htdocs/resources/admin/include/3rdparty.php
fi

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  Installation completed successfully! (PostgreSQL ${PG_VER} & pgAdmin 4)      ${NC}"
echo -e "${GREEN}  - CWP Module: CWP Admin -> SQL Services -> PostgreSQL / pgAdmin             ${NC}"
echo -e "${GREEN}  - Direct Link: https://YOUR_SERVER_IP:2031/admin/index.php?module=postgresql-pgadmin${NC}"
echo -e "${GREEN}  - pgAdmin 4 Web: http://YOUR_SERVER_IP:5050/                                ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
