#!/bin/bash
# PostgreSQL & pgAdmin Management Helper for CWP

ACTION=$1
ARG1=$2
ARG2=$3

CUR_V=$(cat /etc/cwp_active_pg_version 2>/dev/null || echo "17")
CONF="/var/lib/pgsql/$CUR_V/data/postgresql.conf"

get_active_port() {
    local P
    P=$(grep -E '^[[:space:]]*port[[:space:]]*=' "$CONF" 2>/dev/null | head -n 1 | awk '{print $3}' | tr -d "';#")
    if [ -z "$P" ]; then
        P="5432"
    fi
    echo "$P"
}

PG_PORT=$(get_active_port)

case $ACTION in
    status)
        systemctl is-active postgresql-$CUR_V 2>/dev/null || systemctl is-active postgresql
        ;;
    start)
        systemctl start postgresql-$CUR_V 2>/dev/null || systemctl start postgresql
        ;;
    stop)
        systemctl stop postgresql-$CUR_V 2>/dev/null || systemctl stop postgresql
        ;;
    restart)
        systemctl restart postgresql-$CUR_V 2>/dev/null || systemctl restart postgresql
        ;;
    get_version)
        /usr/pgsql-$CUR_V/bin/postgres -V 2>/dev/null | awk '{print $3}' || su - postgres -c "psql -p $PG_PORT -t -A -c 'SHOW server_version;'" 2>/dev/null
        ;;
    get_all_info)
        PG_STAT=$(systemctl is-active postgresql-$CUR_V 2>/dev/null || systemctl is-active postgresql 2>/dev/null || echo "inactive")
        PA_STAT=$(systemctl is-active pgadmin4 2>/dev/null || echo "inactive")
        PA_USER=$(python3 -c "import sqlite3; conn = sqlite3.connect('/var/lib/pgadmin/pgadmin4.db'); c = conn.cursor(); c.execute('SELECT email FROM user LIMIT 1'); r = c.fetchone(); print(r[0] if r and r[0] else 'admin@cwp.com')" 2>/dev/null || echo "admin@cwp.com")
        PA_PORT=$(grep -E '^[[:space:]]*DEFAULT_SERVER_PORT[[:space:]]*=' /etc/pgadmin/config_system.py 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' "')
        [ -z "$PA_PORT" ] && PA_PORT="5050"
        PA_VER=$(rpm -q --queryformat '%{VERSION}' pgadmin4-web 2>/dev/null || echo "4")
        PG_VER=$(/usr/pgsql-$CUR_V/bin/postgres -V 2>/dev/null | awk '{print $3}' || echo "$CUR_V")
        [ -z "$PG_VER" ] && PG_VER="$CUR_V"
        echo "pg_version=$PG_VER"
        echo "pg_port=$PG_PORT"
        echo "pg_conf_path=$CONF"
        echo "pg_status=$PG_STAT"
        echo "pgadmin_port=$PA_PORT"
        echo "pgadmin_user=$PA_USER"
        echo "pgadmin_version=$PA_VER"
        echo "pgadmin_status=$PA_STAT"
        ;;
    get_port)
        echo "$PG_PORT"
        ;;
    set_port)
        NEW_PORT=$ARG1
        if [[ ! "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
            echo "ERROR: Invalid port number"
            exit 1
        fi
        if [ -f "$CONF" ]; then
            if grep -E '^[[:space:]]*port[[:space:]]*=' "$CONF" >/dev/null 2>&1; then
                sed -i -E "s/^[[:space:]]*port[[:space:]]*=.*/port = $NEW_PORT/" "$CONF"
            elif grep -E '^#port[[:space:]]*=' "$CONF" >/dev/null 2>&1; then
                sed -i "s/^#port = 5432/port = $NEW_PORT/" "$CONF"
                sed -i "s/^#port[[:space:]]*=.*/port = $NEW_PORT/" "$CONF"
            else
                echo "port = $NEW_PORT" >> "$CONF"
            fi
            systemctl restart postgresql-$CUR_V 2>/dev/null || systemctl restart postgresql
            systemctl restart pgadmin4 2>/dev/null || true
            PG_PORT=$NEW_PORT
            TMP_JSON="/tmp/pga_servers_$$.json"
            CURRENT_USER=$(python3 -c "import sqlite3; conn = sqlite3.connect('/var/lib/pgadmin/pgadmin4.db'); c = conn.cursor(); c.execute('SELECT email FROM user LIMIT 1'); r = c.fetchone(); print(r[0] if r and r[0] else 'admin@cwp.com')" 2>/dev/null || echo "admin@cwp.com")
            if [ -n "$CURRENT_USER" ]; then
                cat << JSONEOF > "$TMP_JSON"
{
    "Servers": {
        "1": {
            "Name": "PostgreSQL (Localhost)",
            "Group": "Servers",
            "Port": $NEW_PORT,
            "Username": "postgres",
            "Host": "127.0.0.1",
            "SSLMode": "prefer",
            "MaintenanceDB": "postgres"
        }
    }
}
JSONEOF
                /usr/pgadmin4/venv/bin/python3 /usr/pgadmin4/web/setup.py load-servers "$TMP_JSON" --user "$CURRENT_USER" --replace 2>/dev/null || true
                rm -f "$TMP_JSON"
            fi
            echo "SUCCESS"
        else
            echo "ERROR: Configuration file not found"
            exit 1
        fi
        ;;
    pgadmin_status)
        systemctl is-active pgadmin4
        ;;
    pgadmin_start)
        systemctl start pgadmin4
        ;;
    pgadmin_stop)
        systemctl stop pgadmin4
        ;;
    pgadmin_restart)
        systemctl restart pgadmin4
        ;;
    get_pgadmin_port)
        P=$(grep -E '^[[:space:]]*DEFAULT_SERVER_PORT[[:space:]]*=' /etc/pgadmin/config_system.py 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' "')
        if [ -z "$P" ]; then
            P="5050"
        fi
        echo "$P"
        ;;
    set_pgadmin_port)
        NEW_PORT=$ARG1
        if [[ ! "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
            echo "ERROR: Invalid port number"
            exit 1
        fi
        sed -i -E "s/DEFAULT_SERVER_PORT[[:space:]]*=[[:space:]]*[0-9]+/DEFAULT_SERVER_PORT = $NEW_PORT/" /etc/pgadmin/config_system.py 2>/dev/null || true
        sed -i -E "s/('0.0.0.0',[[:space:]]*)[0-9]+/\1$NEW_PORT/" /usr/pgadmin4/run_pgadmin.py 2>/dev/null || true
        iptables -I INPUT -p tcp --dport "$NEW_PORT" -j ACCEPT 2>/dev/null || true
        if which firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld >/dev/null 2>&1; then
            firewall-cmd --add-port="${NEW_PORT}/tcp" --permanent 2>/dev/null || true
            firewall-cmd --reload 2>/dev/null || true
        fi
        if [ -f /etc/csf/csf.conf ]; then
            if ! grep -E "^TCP_IN = .*${NEW_PORT}" /etc/csf/csf.conf >/dev/null 2>&1; then
                sed -i -E "s/(TCP_IN = \"[^\"]*)/\1,${NEW_PORT}/" /etc/csf/csf.conf 2>/dev/null || true
                csf -r 2>/dev/null || true
            fi
        fi
        systemctl restart pgadmin4 2>/dev/null || true
        echo "SUCCESS"
        ;;
    get_pgadmin_user)
        python3 -c "import sqlite3; conn = sqlite3.connect('/var/lib/pgadmin/pgadmin4.db'); c = conn.cursor(); c.execute('SELECT email FROM user LIMIT 1'); r = c.fetchone(); print(r[0] if r and r[0] else 'admin@cwp.com')" 2>/dev/null || echo "admin@cwp.com"
        ;;
    set_pgadmin_user)
        NEW_USER=$ARG1
        if [ -z "$NEW_USER" ]; then
            echo "ERROR: Empty email"
            exit 1
        fi
        /usr/pgadmin4/venv/bin/python3 -c "
import sys
sys.path.insert(0, '/usr/pgadmin4/web')
from pgAdmin4 import app
from pgadmin.model import User, db
with app.app_context():
    u = User.query.first()
    if u:
        u.email = '$NEW_USER'
        u.username = '$NEW_USER'
        u.login_attempts = 0
        u.locked = False
        db.session.commit()
        print('SUCCESS')
    else:
        print('NO_USER')
"
        # Sync server definition in pgAdmin for the updated user
        TMP_JSON="/tmp/pga_servers_$$.json"
        cat << JSONEOF > "$TMP_JSON"
{
    "Servers": {
        "1": {
            "Name": "PostgreSQL (Localhost)",
            "Group": "Servers",
            "Port": $PG_PORT,
            "Username": "postgres",
            "Host": "127.0.0.1",
            "SSLMode": "prefer",
            "MaintenanceDB": "postgres"
        }
    }
}
JSONEOF
        /usr/pgadmin4/venv/bin/python3 /usr/pgadmin4/web/setup.py load-servers "$TMP_JSON" --user "$NEW_USER" --replace 2>/dev/null || true
        rm -f "$TMP_JSON"
        ;;
    get_pgadmin_version)
        rpm -q --queryformat '%{VERSION}' pgadmin4-web 2>/dev/null || echo "4"
        ;;
    change_pgadmin_pwd)
        NEW_PWD=$ARG1
        /usr/pgadmin4/venv/bin/python3 -c "
import sys
sys.path.insert(0, '/usr/pgadmin4/web')
from pgAdmin4 import app
from pgadmin.model import User, db
from flask_security.utils import hash_password
with app.app_context():
    u = User.query.first()
    if u:
        u.password = hash_password('$NEW_PWD')
        u.login_attempts = 0
        u.locked = False
        db.session.commit()
        print('SUCCESS')
    else:
        print('USER_NOT_FOUND')
"
        ;;
    pgadmin_sync_servers)
        CURRENT_USER=$(python3 -c "import sqlite3; conn = sqlite3.connect('/var/lib/pgadmin/pgadmin4.db'); c = conn.cursor(); c.execute('SELECT email FROM user LIMIT 1'); r = c.fetchone(); print(r[0] if r and r[0] else 'admin@cwp.com')" 2>/dev/null || echo "admin@cwp.com")
        if [ -n "$CURRENT_USER" ]; then
            TMP_JSON="/tmp/pga_servers_$$.json"
            cat << JSONEOF > "$TMP_JSON"
{
    "Servers": {
        "1": {
            "Name": "PostgreSQL (Localhost)",
            "Group": "Servers",
            "Port": $PG_PORT,
            "Username": "postgres",
            "Host": "127.0.0.1",
            "SSLMode": "prefer",
            "MaintenanceDB": "postgres"
        }
    }
}
JSONEOF
            /usr/pgadmin4/venv/bin/python3 /usr/pgadmin4/web/setup.py load-servers "$TMP_JSON" --user "$CURRENT_USER" --replace 2>/dev/null || true
            rm -f "$TMP_JSON"
            echo "SUCCESS"
        else
            echo "NO_USER"
        fi
        ;;
    list_dbs)
        su - postgres -c "psql -p $PG_PORT -t -A -F'|' -c 'SELECT datname, pg_size_pretty(pg_database_size(datname)), pg_encoding_to_char(encoding) FROM pg_database WHERE datistemplate = false ORDER BY datname;'"
        ;;
    list_users)
        su - postgres -c "psql -p $PG_PORT -t -A -F'|' -c \"SELECT usename, CASE WHEN usesuper THEN 'Yes' ELSE 'No' END FROM pg_user ORDER BY usename;\""
        ;;
    create_db)
        DBNAME=$ARG1
        su - postgres -c "createdb -p $PG_PORT '$DBNAME'"
        ;;
    drop_db)
        DBNAME=$ARG1
        su - postgres -c "dropdb -p $PG_PORT '$DBNAME'"
        ;;
    create_user)
        USERNAME=$ARG1
        PASSWORD=$ARG2
        su - postgres -c "psql -p $PG_PORT -c \"CREATE USER \\\"$USERNAME\\\" WITH PASSWORD '$PASSWORD';\""
        ;;
    change_user_pwd)
        USERNAME=$ARG1
        PASSWORD=$ARG2
        su - postgres -c "psql -p $PG_PORT -c \"ALTER USER \\\"$USERNAME\\\" WITH PASSWORD '$PASSWORD';\""
        ;;
    drop_user)
        USERNAME=$ARG1
        su - postgres -c "psql -p $PG_PORT -c \"DROP USER \\\"$USERNAME\\\" ;\""
        ;;
    get_conf_path)
        echo "$CONF"
        ;;
    get_conf)
        if [ -f "$CONF" ]; then
            cat "$CONF"
        fi
        ;;
    save_conf)
        # Reads new configuration from stdin or tmp file
        TMP_CONF="$ARG1"
        if [ -f "$TMP_CONF" ] && [ -f "$CONF" ]; then
            cp -f "$CONF" "${CONF}.bak_$(date +%Y%m%d_%H%M%S)"
            cp -f "$TMP_CONF" "$CONF"
            chown postgres:postgres "$CONF" 2>/dev/null || true
            chmod 600 "$CONF" 2>/dev/null || true
            rm -f "$TMP_CONF"
            echo "SUCCESS"
        else
            echo "ERROR"
            exit 1
        fi
        ;;
    *)
        echo "Unknown action: $ACTION"
        exit 1
        ;;
esac
