# PostgreSQL & pgAdmin Management Module for Control Web Panel (CWP)

A high-performance, native PostgreSQL & pgAdmin 4 (Web Mode) management module designed for [Control Web Panel (CWP)](https://control-webpanel.com/).

---

## ✨ Key Features

- **Multi-Version PostgreSQL**: Install and manage PostgreSQL 14, 15, 16, 17, or 18 via LTS installer selector.
- **Database Management**: Create, inspect, and drop databases with live disk size and encoding statistics.
- **User Management**: Manage roles, grant superuser privileges, update passwords, and delete users safely.
- **pgAdmin 4 Web Deployment**: Native pgAdmin 4 service on port 5050 with automatic server discovery.
- **Service Controls**: Start, stop, and restart PostgreSQL and pgAdmin 4 services directly from the panel.
- **Dynamic Port Configuration**: Update PostgreSQL (default: 5432) and pgAdmin 4 (default: 5050) ports with automated firewall sync.
- **Configuration Editor**: In-browser `postgresql.conf` editor with automated backups and service restart.

---

## 🚀 Installation

Run on your CWP server as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/QadirAdamson/CWP-Module-PostgreSQL-pgAdmin/main/install.sh | bash
```

Access in CWP Admin Panel: 👉 **SQL Services → PostgreSQL / pgAdmin**

---

## 🗑️ Uninstallation

Run on your CWP server as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/QadirAdamson/CWP-Module-PostgreSQL-pgAdmin/main/uninstall.sh | bash
```

*(PostgreSQL server packages and user database data are preserved for safety).*

---

## 📄 License

This project is open-source and licensed under the [MIT License](LICENSE).
