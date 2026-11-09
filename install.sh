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

# Ask user for PostgreSQL version (default to latest LTS: 17)
echo -e "\n${CYAN}Available PostgreSQL LTS Versions:${NC}"
echo -e "  [1] PostgreSQL 14"
echo -e "  [2] PostgreSQL 15"
echo -e "  [3] PostgreSQL 16"
echo -e "  [4] PostgreSQL 17 (Recommended / Latest LTS)"
echo -e "  [5] PostgreSQL 18"

read -p "Select PostgreSQL version to install [1-5] (Default: 4 -> PostgreSQL 17): " PG_CHOICE

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
if [ ! -d "/var/lib/pgsql/${PG_VER}/data/base" ]; then
    /usr/pgsql-${PG_VER}/bin/postgresql-${PG_VER}-setup initdb
fi

if [ -f "/var/lib/pgsql/${PG_VER}/data/pg_hba.conf" ]; then
    sed -i 's/scram-sha-256/md5/g' /var/lib/pgsql/${PG_VER}/data/pg_hba.conf 2>/dev/null || true
    sed -i 's/peer/trust/g' /var/lib/pgsql/${PG_VER}/data/pg_hba.conf 2>/dev/null || true
    sed -i 's/ident/md5/g' /var/lib/pgsql/${PG_VER}/data/pg_hba.conf 2>/dev/null || true
fi

systemctl daemon-reload
systemctl enable --now postgresql-${PG_VER}
echo "${PG_VER}" > /etc/cwp_active_pg_version

# Set default password for postgres user
su - postgres -c "psql -p 5432 -c \"ALTER USER postgres WITH PASSWORD '2qvUkiz7BgXGvNDx';\"" 2>/dev/null || true

# 3. Install pgAdmin 4 Web
echo -e "\n${YELLOW}[3/6] Installing pgAdmin 4 Web...${NC}"
if ! rpm -q pgadmin4-web >/dev/null 2>&1; then
    rpm -i https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-redhat-repo-2-1.noarch.rpm 2>/dev/null || true
    rpm --import /etc/pki/rpm-gpg/PGADMIN_PKG_KEY 2>/dev/null || true
    dnf install -y pgadmin4-web
fi

# 4. Setup pgAdmin 4 Python environment and systemd service
echo -e "\n${YELLOW}[4/6] Setting up pgAdmin 4 service & admin account...${NC}"
mkdir -p /var/log/pgadmin /var/lib/pgadmin /etc/pgadmin

cat << 'PGLOCAL' > /etc/pgadmin/config_system.py
SERVER_MODE = True
DEFAULT_SERVER = '127.0.0.1'
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
    werkzeug.serving.run_simple('127.0.0.1', 5050, app, threaded=True)
RUNPY

# Allow system "root" username in pgAdmin
/usr/pgadmin4/venv/bin/python3 -c "
mail_file = '/usr/pgadmin4/venv/lib64/python3.12/site-packages/flask_security/mail_util.py'
try:
    with open(mail_file, 'r') as f:
        c = f.read()
    if 'if email in [\"root\", \"admin\"]:' not in c:
        c = c.replace('def normalize(self, email: str) -> str:\n', 'def normalize(self, email: str) -> str:\n        if email in [\"root\", \"admin\"]:\n            return email\n')
        c = c.replace('def validate(self, email: str) -> str:\n', 'def validate(self, email: str) -> str:\n        if email in [\"root\", \"admin\"]:\n            return email\n')
        with open(mail_file, 'w') as f:
            f.write(c)
except Exception:
    pass
" 2>/dev/null || true

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

# 5. Configure cwpsrv (Nginx Proxy for /pgadmin)
echo -e "\n${YELLOW}[5/6] Configuring CWP cwpsrv reverse proxy (/pgadmin)...${NC}"
sed -i '/location ~ \/(pgadmin|PgAdmin|Pgadmin|phppgadmin|phpPgadmin)/,+2d' /usr/local/cwpsrv/conf/cwp_rewrite.conf 2>/dev/null || true

if ! grep -q "location /pgadmin/" /usr/local/cwpsrv/conf/cwp_services.conf 2>/dev/null; then
cat << 'CWPNX' >> /usr/local/cwpsrv/conf/cwp_services.conf

# pgAdmin 4 Reverse Proxy
location /pgadmin/ {
    proxy_pass http://127.0.0.1:5050/;
    proxy_set_header X-Script-Name /pgadmin;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_redirect off;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
}

location = /pgadmin {
    return 301 /pgadmin/;
}
CWPNX
fi

systemctl reload cwpsrv

# 6. Deploy CWP Module & Controller Script
echo -e "\n${YELLOW}[6/6] Installing CWP Admin Module and Menu...${NC}"
cp -f "$SCRIPT_DIR/root/cwp_pg_ctl.sh" /usr/local/bin/cwp_pg_ctl.sh
chmod +x /usr/local/bin/cwp_pg_ctl.sh

# Sudoers permission for cwpsrv
cat << 'SUDO' > /etc/sudoers.d/cwpsrv_pg
cwpsrv ALL=(ALL) NOPASSWD: /usr/local/bin/cwp_pg_ctl.sh
SUDO
chmod 440 /etc/sudoers.d/cwpsrv_pg

# Copy PHP module and sidebar menu hook
cp -f "$SCRIPT_DIR/resources/admin/modules/postgresql-pgadmin.php" /usr/local/cwpsrv/htdocs/resources/admin/modules/
cp -f "$SCRIPT_DIR/resources/admin/include/pg_menu.php" /usr/local/cwpsrv/htdocs/resources/admin/include/

# Include menu into 3rdparty.php if not already present
if ! grep -q "pg_menu.php" /usr/local/cwpsrv/htdocs/resources/admin/include/3rdparty.php 2>/dev/null; then
    echo "<?php include_once('/usr/local/cwpsrv/htdocs/resources/admin/include/pg_menu.php'); ?>" >> /usr/local/cwpsrv/htdocs/resources/admin/include/3rdparty.php
fi

echo -e "\n${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  Installation completed successfully! (PostgreSQL ${PG_VER} & pgAdmin 4)      ${NC}"
echo -e "${GREEN}  - CWP Module: CWP Admin -> SQL Services -> PostgreSQL / pgAdmin             ${NC}"
echo -e "${GREEN}  - Direct Link: https://YOUR_SERVER_IP:2031/admin/index.php?module=postgresql-pgadmin${NC}"
echo -e "${GREEN}  - pgAdmin 4 Web: http://YOUR_SERVER_IP:2030/pgadmin/                        ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
