# PostgreSQL & pgAdmin Management Module for Control Web Panel (CWP)

A native PostgreSQL and pgAdmin 4 management module designed for [Control Web Panel (CWP)](https://control-webpanel.com/).

---

## ✨ Features

- **Multi-Version Support**: Choose and install your preferred PostgreSQL version during setup.
- **Database Management**: Create, inspect, and safely delete PostgreSQL databases.
- **User Management**: Create database users, update passwords, and manage permissions.
- **pgAdmin 4 Web Interface**: Manage your databases visually with an integrated pgAdmin 4 web panel.
- **Service Management**: Easily start, stop, and restart PostgreSQL and pgAdmin services.
- **Port Management**: Customize service ports directly from the panel with automatic firewall configuration.
- **Configuration Editor**: View and edit the PostgreSQL configuration file with automatic backups.

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

---

## 📄 License

This project is open-source and licensed under the [MIT License](LICENSE).
