# PostgreSQL & pgAdmin Management Module for Control Web Panel (CWP)

A high-performance, native PostgreSQL & pgAdmin 4 (Web Mode) management module designed for [Control Web Panel (CWP)](https://control-webpanel.com/).

---

## ✨ Key Features

- **🐘 Multi-Version PostgreSQL Support**: Interactive LTS version selector during installation (PostgreSQL 14, 15, 16, 17, 18).
- **🖥️ Standalone pgAdmin 4 Web (Port 5050)**: Native service deployment with automatic local PostgreSQL server discovery and registration.
- **⚡ Ultra-Fast Sub-Second Page Loads**: High-speed metadata retrieval engine querying native configurations and SQLite in microseconds without heavy framework overhead.
- **⚙️ In-Browser Configuration Editor**: Full-featured editor for `postgresql.conf` with automatic timestamped backups, syntax validation, and instant service restart.
- **🗄️ Database Management**: Create, list disk sizes & encodings, and drop databases with left-aligned tabular views.
- **👥 User & Role Management**: Add users with secure passwords, view superuser privileges, inline password update drawer, and account removal.
- **🔄 Service Controls**: Quick command-only service actions (`Start`, `Restart`, `Stop`) with live status badges.
- **🌐 Dynamic Port Switching**: Modify both PostgreSQL (default: 5432) and pgAdmin 4 (default: 5050) ports with automated firewall (CSF / firewalld / iptables) updates and server sync.
- **🎨 Unified Modern CWP UI**: Form actions in standard CWP blue (`#2f80ed`), delete actions in grey (`#6c757d`), and clean left-aligned data tables.

---

## 🔐 Default Credentials

When installing for the first time, pgAdmin 4 Web is initialized with:

| Setting | Default Value | Notes |
| :--- | :--- | :--- |
| **Web URL** | `http://<your-server-ip>:5050/` | Or via direct **Open** button in CWP Overview |
| **Email** | `admin@cwp.com` | Can be changed anytime from the Settings tab |
| **Password** | `admin1234` | Can be changed anytime from the Settings tab |
| **Pre-configured Server**| `PostgreSQL (Localhost)` | Pre-linked on port 5432, username `postgres` |

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
