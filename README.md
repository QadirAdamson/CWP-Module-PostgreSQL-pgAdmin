# PostgreSQL & pgAdmin Management Module for Control Web Panel (CWP)

A native PostgreSQL & pgAdmin 4 (Web Mode) management module designed for [Control Web Panel (CWP)](https://control-webpanel.com/).

---

## ✨ Features

- **🐘 PostgreSQL Server Support**: Interactive LTS version selector during installation (PostgreSQL 14, 15, 16, 17, 18).
- **🖥️ pgAdmin 4 Web Integration**: Reverse-proxied natively through CWP's `cwpsrv` Nginx engine (`/pgadmin/`) with system `root` authentication.
- **⚙️ Dynamic Port & Config Management**: In-browser configuration editor for `postgresql.conf` with automatic timestamped backups, instant service restart option, and custom PostgreSQL port switcher.
- **🗄️ Database Management**: Create, list disk sizes & encodings, and drop databases directly from the GUI.
- **👥 User Management**: Add users with passwords, view superuser privileges, inline password update drawers, and remove accounts.
- **🔄 Service Controls & Management**: Real-time service status, quick service restarts, and automated latest pgAdmin 4 deployment.
- **📊 PowerDNS-Style Unified UI**: Clean, responsive layout with clickable ASC/DESC column sorting for all tables.

---

## 🚀 Installation

Run on your CWP server as `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/QadirAdamson/CWP-Module-PostgreSQL-pgAdmin/main/install.sh | bash
```

Access in CWP Admin Panel: 👉 **SQL Services → PostgreSQL / pgAdmin**

---

## 🗑️ Uninstallation

```bash
curl -fsSL https://raw.githubusercontent.com/QadirAdamson/CWP-Module-PostgreSQL-pgAdmin/main/uninstall.sh | bash
```

---

## 📄 License

This project is open-source and licensed under the [MIT License](LICENSE).
