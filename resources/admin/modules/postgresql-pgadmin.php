<?php
/**
 * PostgreSQL 17 & pgAdmin 4 Management Module for Control Web Panel (CWP)
 * Styled identically to CWP PowerDNS Manager (?module=powerdns-manager)
 * Author: Qadir Adamson
 * Module Name: postgresql-pgadmin
 * Language: English
 */

if (!isset($include_path)) {
    echo "Invalid Access";
    exit();
}

$ctl = "sudo /usr/local/bin/cwp_pg_ctl.sh";
$message = "";
$msg_type = "success";

$tab = isset($_GET['tab']) ? trim($_GET['tab']) : 'overview';
$allowed_tabs = ['overview', 'databases', 'users', 'config'];
if (!in_array($tab, $allowed_tabs)) {
    $tab = 'overview';
}

// Handle Service Controls
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['service_action'])) {
        $svc_act = $_POST['service_action'];
        if ($svc_act === 'start') {
            shell_exec("$ctl start");
            $message = "PostgreSQL service started successfully.";
            $msg_type = "success";
        } elseif ($svc_act === 'stop') {
            shell_exec("$ctl stop");
            $message = "PostgreSQL service stopped.";
            $msg_type = "danger";
        } elseif ($svc_act === 'restart') {
            shell_exec("$ctl restart");
            $message = "PostgreSQL service restarted successfully.";
            $msg_type = "success";
        }
    } elseif (isset($_POST['pgadmin_service_action'])) {
        $pa_act = $_POST['pgadmin_service_action'];
        if ($pa_act === 'restart') {
            shell_exec("$ctl pgadmin_restart");
            $message = "pgAdmin 4 Web service restarted successfully.";
            $msg_type = "success";
        } elseif ($pa_act === 'upgrade') {
            shell_exec("$ctl pgadmin_upgrade 2>&1");
            $message = "pgAdmin 4 packages updated and service restarted successfully.";
            $msg_type = "success";
        }
    } elseif (isset($_POST['change_pgadmin_password'])) {
        $new_pass = $_POST['new_pgadmin_pwd'] ?? '';
        if (!empty($new_pass)) {
            $res = trim(shell_exec("$ctl change_pgadmin_pwd " . escapeshellarg($new_pass)) ?? '');
            if (strpos($res, 'SUCCESS') !== false) {
                $message = "pgAdmin root password updated successfully.";
                $msg_type = "success";
            } else {
                $message = "Failed to update pgAdmin password. User not found.";
                $msg_type = "danger";
            }
        } else {
            $message = "Please enter a valid password.";
            $msg_type = "danger";
        }
    } elseif (isset($_POST['save_config'])) {
        $new_config = $_POST['config_content'] ?? '';
        if (!empty($new_config)) {
            $tmp_file = tempnam('/tmp', 'pg_conf_');
            file_put_contents($tmp_file, $new_config);
            $res = trim(shell_exec("$ctl save_conf " . escapeshellarg($tmp_file) . " 2>&1") ?? '');
            if (strpos($res, 'SUCCESS') !== false) {
                $message = "Configuration file saved successfully.";
                $msg_type = "success";
                if (isset($_POST['restart_after_save'])) {
                    shell_exec("$ctl restart 2>&1");
                    usleep(400000);
                    $new_st = trim(shell_exec("$ctl status 2>/dev/null") ?? '');
                    if ($new_st === 'active') {
                        $message .= " PostgreSQL service restarted successfully.";
                    } else {
                        $message .= " However, PostgreSQL failed to restart. Please check configuration syntax.";
                        $msg_type = "danger";
                    }
                }
            } else {
                $message = "Error saving configuration file.";
                $msg_type = "danger";
            }
        } else {
            $message = "Configuration content cannot be empty.";
            $msg_type = "danger";
        }
    } elseif (isset($_POST['action'])) {
        $action = trim($_POST['action']);
        if ($action === 'create_db') {
            $dbname = preg_replace('/[^a-zA-Z0-9_]/', '', $_POST['dbname'] ?? '');
            if (!empty($dbname)) {
                shell_exec("$ctl create_db " . escapeshellarg($dbname) . " 2>&1");
                $message = "Database <b>" . htmlspecialchars($dbname) . "</b> created successfully.";
                $msg_type = "success";
            } else {
                $message = "Invalid database name. Please use alphanumeric characters and underscores.";
                $msg_type = "danger";
            }
        } elseif ($action === 'drop_db') {
            $dbname = preg_replace('/[^a-zA-Z0-9_]/', '', $_POST['dbname'] ?? '');
            if (!empty($dbname) && $dbname !== 'postgres') {
                shell_exec("$ctl drop_db " . escapeshellarg($dbname) . " 2>&1");
                $message = "Database <b>" . htmlspecialchars($dbname) . "</b> has been dropped.";
                $msg_type = "success";
            } else {
                $message = "The default 'postgres' system database cannot be dropped.";
                $msg_type = "danger";
            }
        } elseif ($action === 'create_user') {
            $username = preg_replace('/[^a-zA-Z0-9_]/', '', $_POST['username'] ?? '');
            $password = $_POST['password'] ?? '';
            if (!empty($username) && !empty($password)) {
                shell_exec("$ctl create_user " . escapeshellarg($username) . " " . escapeshellarg($password) . " 2>&1");
                $message = "User <b>" . htmlspecialchars($username) . "</b> created successfully.";
                $msg_type = "success";
            } else {
                $message = "Please provide both username and password.";
                $msg_type = "danger";
            }
        } elseif ($action === 'set_pg_port') {
            $new_port = (int) preg_replace('/[^0-9]/', '', $_POST['new_port'] ?? '5432');
            if ($new_port >= 1 && $new_port <= 65535) {
                shell_exec("$ctl set_port " . escapeshellarg($new_port) . " 2>&1");
                $message = "PostgreSQL port updated to <b>" . htmlspecialchars($new_port) . "</b> and service restarted.";
                $msg_type = "success";
            } else {
                $message = "Please enter a valid port number between 1 and 65535.";
                $msg_type = "danger";
            }
        } elseif ($action === 'change_user_pwd') {
            $username = preg_replace('/[^a-zA-Z0-9_]/', '', $_POST['username'] ?? '');
            $password = $_POST['new_password'] ?? '';
            if (!empty($username) && !empty($password)) {
                shell_exec("$ctl change_user_pwd " . escapeshellarg($username) . " " . escapeshellarg($password) . " 2>&1");
                $message = "Password for user <b>" . htmlspecialchars($username) . "</b> updated successfully.";
                $msg_type = "success";
            } else {
                $message = "Please provide a valid username and password.";
                $msg_type = "danger";
            }
        } elseif ($action === 'drop_user') {
            $username = preg_replace('/[^a-zA-Z0-9_]/', '', $_POST['username'] ?? '');
            if (!empty($username) && $username !== 'postgres') {
                shell_exec("$ctl drop_user " . escapeshellarg($username) . " 2>&1");
                $message = "User <b>" . htmlspecialchars($username) . "</b> removed.";
                $msg_type = "success";
            } else {
                $message = "The master 'postgres' user cannot be removed.";
                $msg_type = "danger";
            }
        }
    }
}

// Fetch Version
$pg_version_raw = trim(shell_exec("$ctl get_version 2>/dev/null") ?? '17.11');
$pg_port_raw = trim(shell_exec("$ctl get_port 2>/dev/null") ?? '5432');
$pg_conf_path = trim(shell_exec("$ctl get_conf_path 2>/dev/null") ?? '/var/lib/pgsql/17/data/postgresql.conf');
$current_config_content = ($tab === 'config') ? shell_exec("$ctl get_conf 2>/dev/null") ?? '' : '';

// Fetch Statuses
$pg_status = trim(shell_exec("$ctl status 2>/dev/null") ?? 'inactive');
$is_active = ($pg_status === 'active');
$pgadmin_status = trim(shell_exec("$ctl pgadmin_status 2>/dev/null") ?? 'inactive');
$is_pgadmin_active = ($pgadmin_status === 'active');

// Fetch Databases
$db_raw = shell_exec("$ctl list_dbs 2>/dev/null") ?? '';
$databases = [];
if (!empty($db_raw)) {
    foreach (explode("\n", trim($db_raw)) as $line) {
        if (!empty($line)) {
            $parts = explode("|", $line);
            $databases[] = [
                'name' => $parts[0] ?? '',
                'size' => $parts[1] ?? '',
                'encoding' => $parts[2] ?? ''
            ];
        }
    }
}

// Fetch Users
$user_raw = shell_exec("$ctl list_users 2>/dev/null") ?? '';
$users = [];
if (!empty($user_raw)) {
    foreach (explode("\n", trim($user_raw)) as $line) {
        if (!empty($line)) {
            $parts = explode("|", $line);
            $users[] = [
                'username' => $parts[0] ?? '',
                'superuser' => $parts[1] ?? 'No'
            ];
        }
    }
}
?>

<style type="text/css">
.pdns-card {
    background: #fff;
    border: 1px solid #dcdfe6;
    border-radius: 6px;
    padding: 20px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.06);
    margin-bottom: 25px;
}
.pdns-table {
    width: 100%;
    margin: 0;
    border-collapse: collapse;
    background: #fff;
    border: 1px solid #e4e7ed;
    font-size: 13px;
}
.pdns-table thead tr {
    background: #f5f7fa;
}
.pdns-table thead th {
    padding: 10px 12px;
    font-weight: 700;
    color: #495057;
    border: 1px solid #e4e7ed;
    vertical-align: middle;
    text-align: left !important;
}
.sortable-th {
    cursor: pointer;
    user-select: none;
    position: relative;
    transition: background 0.15s ease;
}
.sortable-th:hover {
    background: #eef2f7 !important;
    color: #007bff !important;
}
.sort-icon {
    display: inline-block;
    margin-left: 4px;
    font-size: 11px;
    color: #aaa;
    font-weight: normal;
}
.pdns-table tbody tr {
    transition: background 0.1s ease;
}
.pdns-table tbody tr:hover {
    background: #f9fbfd !important;
}
.pdns-table tbody tr:nth-child(even) {
    background: #fafbfd;
}
.pdns-table tbody td {
    padding: 9px 12px;
    border: 1px solid #e4e7ed;
    color: #333;
    vertical-align: middle;
    text-align: left !important;
}
.btn-action-delete {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    background: #6c757d !important;
    color: #ffffff !important;
    border: none;
    border-radius: 4px;
    text-decoration: none !important;
    transition: background 0.15s ease;
    cursor: pointer;
}
.btn-action-delete:hover {
    background: #dc3545 !important;
    color: #ffffff !important;
}
.btn-action-delete i, .btn-action-delete span {
    color: #ffffff !important;
}

/* Force Tab Styles to be visible and isolated */
.cwp-pg-tabs {
    display: flex !important;
    list-style: none !important;
    padding: 0 !important;
    margin: 0 0 20px 0 !important;
    border-bottom: 2px solid #ddd !important;
    visibility: visible !important;
    opacity: 1 !important;
}
.cwp-pg-tabs li {
    margin-right: 8px !important;
    display: block !important;
}
.cwp-pg-tabs li a {
    display: flex !important;
    align-items: center !important;
    gap: 6px !important;
    padding: 10px 18px !important;
    text-decoration: none !important;
    border-radius: 4px 4px 0 0 !important;
    font-weight: 700 !important;
    font-size: 13px !important;
    line-height: 1.4 !important;
    cursor: pointer !important;
}
.cwp-pg-tabs li a.active-tab {
    background: #007bff !important;
    color: #ffffff !important;
    border: none !important;
}
.cwp-pg-tabs li a.active-tab i, .cwp-pg-tabs li a.active-tab span {
    color: #ffffff !important;
}
.cwp-pg-tabs li a.inactive-tab {
    background: #f8f9fa !important;
    color: #333333 !important;
    border: 1px solid #ddd !important;
    border-bottom: none !important;
}
.cwp-pg-tabs li a.inactive-tab:hover {
    background: #e9ecef !important;
    color: #000000 !important;
}

/* Ensure all icons on colored buttons and badges are explicitly white */
.btn-primary i, .btn-primary span,
.btn-danger i, .btn-danger span,
.btn-warning i, .btn-warning span,
.btn-success i, .btn-success span,
.badge i, .badge span {
    color: #ffffff !important;
}
</style>

<!-- Top Title & Service Controls -->
<div class="row" style="margin-bottom:20px;">
    <div class="col-md-12">
        <div style="display:flex; align-items:center; justify-content:space-between; flex-wrap:wrap; gap:10px; padding:0 2px;">
            <div style="display:flex; align-items:center; flex-wrap:wrap; gap:12px;">
                <h3 style="margin:0; font-size:20px; font-weight:bold; color:#17283a;">
                    <i class="icon16 icomoon-icon-database" style="color:#2f80ed; margin-right:6px;"></i> PostgreSQL
                </h3>
                <?php if ($is_active): ?>
                    <span class="badge" style="background:#28a745; color:#ffffff; font-size:12px; font-weight:bold; padding:5px 12px; border-radius:4px; display:inline-flex; align-items:center;">
                        <i class="icon16 icomoon-icon-checkmark-circle" style="color:#ffffff !important; margin-right:5px;"></i> Service Running
                    </span>
                <?php else: ?>
                    <span class="badge" style="background:#dc3545; color:#ffffff; font-size:12px; font-weight:bold; padding:5px 12px; border-radius:4px; display:inline-flex; align-items:center;">
                        <i class="icon16 icomoon-icon-cancel-circle" style="color:#ffffff !important; margin-right:5px;"></i> Service Stopped
                    </span>
                <?php endif; ?>
            </div>
            <div style="display:flex; gap:8px; align-items:center;">
                <form method="POST" style="margin:0; display:inline-flex; gap:6px;">
                    <?php if ($is_active): ?>
                        <button type="submit" name="service_action" value="restart" class="btn btn-warning" style="background:#ffc107; color:#ffffff; border:none; padding:7px 15px; font-weight:bold; cursor:pointer; border-radius:4px;" title="Restart PostgreSQL Server">
                            <i class="icon16 icomoon-icon-lightning" style="color:#ffffff !important;"></i> Restart Service
                        </button>
                        <button type="submit" name="service_action" value="stop" class="btn btn-danger" onclick="return confirm('Stop PostgreSQL server?');" style="background:#dc3545; color:#ffffff; border:none; padding:7px 15px; font-weight:bold; cursor:pointer; border-radius:4px;">
                            <i class="icon16 icomoon-icon-cancel-circle" style="color:#ffffff !important;"></i> Stop
                        </button>
                    <?php else: ?>
                        <button type="submit" name="service_action" value="start" class="btn btn-success" style="background:#28a745; color:#ffffff; border:none; padding:7px 15px; font-weight:bold; cursor:pointer; border-radius:4px;">
                            <i class="icon16 icomoon-icon-power" style="color:#ffffff !important;"></i> Start Service
                        </button>
                    <?php endif; ?>
                </form>
            </div>
        </div>
    </div>
</div>

<?php if (!empty($message)): ?>
<div class="alert alert-<?php echo $msg_type; ?>" style="padding:10px 15px; margin-bottom:15px; border-radius:4px; <?php echo ($msg_type==='danger')?'background:#f8d7da;color:#721c24;border:1px solid #f5c6cb;':'background:#d4edda;color:#155724;border:1px solid #c3e6cb;'; ?>">
    <?php echo $message; ?>
</div>
<?php endif; ?>

<!-- Tabs Navigation -->
<ul class="cwp-pg-tabs nav nav-tabs">
    <li>
        <a href="index.php?module=postgresql-pgadmin&tab=overview" class="<?php echo ($tab==='overview') ? 'active-tab' : 'inactive-tab'; ?>">
            <i class="icon16 icomoon-icon-dashboard"></i> <span>Overview</span>
        </a>
    </li>
    <li>
        <a href="index.php?module=postgresql-pgadmin&tab=databases" class="<?php echo ($tab==='databases') ? 'active-tab' : 'inactive-tab'; ?>">
            <i class="icon16 icomoon-icon-database"></i> <span>Databases (<?php echo count($databases); ?>)</span>
        </a>
    </li>
    <li>
        <a href="index.php?module=postgresql-pgadmin&tab=users" class="<?php echo ($tab==='users') ? 'active-tab' : 'inactive-tab'; ?>">
            <i class="icon16 icomoon-icon-users"></i> <span>Users (<?php echo count($users); ?>)</span>
        </a>
    </li>
    <li>
        <a href="index.php?module=postgresql-pgadmin&tab=config" class="<?php echo ($tab==='config') ? 'active-tab' : 'inactive-tab'; ?>">
            <i class="icon16 icomoon-icon-cogs"></i> <span>Settings</span>
        </a>
    </li>
</ul>

<!-- TAB: OVERVIEW -->
<?php if ($tab === 'overview'): ?>
<div class="row">
    <!-- Left Column: PostgreSQL Info -->
    <div class="col-md-6">
        <div class="pdns-card" style="min-height:220px; display:flex; flex-direction:column; justify-content:space-between;">
            <h3 style="margin:0 0 15px 0; font-size:20px; font-weight:bold; color:#17283a;">
                <i class="icon16 icomoon-icon-database" style="color:#2f80ed; margin-right:6px;"></i> PostgreSQL
            </h3>
            <table class="pdns-table">
                <tbody>
                    <tr>
                        <td style="font-weight:bold; background:#f9fbfd;">Port:</td>
                        <td>
                            <form method="POST" style="display:flex; gap:8px; align-items:center; margin:0;" onsubmit="return confirm('Changing PostgreSQL port requires restarting PostgreSQL service. Continue?');">
                                <input type="hidden" name="action" value="set_pg_port">
                                <input type="number" name="new_port" min="1" max="65535" value="<?php echo htmlspecialchars($pg_port_raw); ?>" class="form-control" style="width:100px; height:30px; font-size:12px; font-weight:bold; border:1px solid #ced4da; border-radius:4px; padding:2px 8px;" required>
                                <button type="submit" class="btn btn-primary" style="background:#007bff; color:#ffffff; border:none; height:30px; padding:0 12px; font-size:12px; font-weight:bold; border-radius:4px; cursor:pointer;" title="Save and apply new port">
                                    <i class="icon16 icomoon-icon-checkmark" style="color:#ffffff !important;"></i> Change
                                </button>
                            </form>
                        </td>
                    </tr>
                    <tr>
                        <td style="font-weight:bold; background:#f9fbfd;">Databases:</td>
                        <td><b><?php echo count($databases); ?></b> Databases</td>
                    </tr>
                    <tr>
                        <td style="font-weight:bold; background:#f9fbfd;">Users:</td>
                        <td><b><?php echo count($users); ?></b> Users</td>
                    </tr>
                    <tr>
                        <td style="font-weight:bold; background:#f9fbfd;">Version:</td>
                        <td><code><?php echo htmlspecialchars($pg_version_raw); ?></code></td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    <!-- Right Column: pgAdmin -->
    <div class="col-md-6">
        <div class="pdns-card" style="min-height:220px; display:flex; flex-direction:column; justify-content:space-between;">
            <div>
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px; flex-wrap:wrap; gap:10px;">
                    <h3 style="margin:0; font-size:20px; font-weight:bold; color:#17283a;">
                        <i class="icon16 icomoon-icon-dashboard" style="color:#2f80ed; margin-right:6px;"></i> pgAdmin
                    </h3>
                    <div>
                        <?php if ($is_pgadmin_active): ?>
                            <span class="badge" style="background:#28a745; color:#ffffff; font-size:12px; font-weight:bold; padding:5px 12px; border-radius:4px; display:inline-flex; align-items:center;">
                                <i class="icon16 icomoon-icon-checkmark-circle" style="color:#ffffff !important; margin-right:4px;"></i> Active
                            </span>
                        <?php else: ?>
                            <span class="badge" style="background:#dc3545; color:#ffffff; font-size:12px; font-weight:bold; padding:5px 12px; border-radius:4px; display:inline-flex; align-items:center;">
                                <i class="icon16 icomoon-icon-cancel-circle" style="color:#ffffff !important; margin-right:4px;"></i> Stopped
                            </span>
                        <?php endif; ?>
                    </div>
                </div>
                <hr style="border:0; border-top:1px solid #e4e7ed; margin:0 0 16px 0;">
                
                <div style="display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin-bottom:18px;">
                    <a href="/pgadmin/" target="_blank" class="btn btn-success" style="background:#28a745; color:#ffffff; border:none; padding:8px 20px; font-size:13px; font-weight:bold; text-decoration:none; border-radius:4px; display:inline-flex; align-items:center; gap:6px;">
                        <i class="icon16 icomoon-icon-new-tab" style="color:#ffffff !important;"></i> Open pgAdmin
                    </a>
                    <form method="POST" style="margin:0; display:inline-block;">
                        <input type="hidden" name="pgadmin_service_action" value="restart">
                        <button type="submit" class="btn btn-warning" style="background:#ffc107; color:#ffffff; border:none; padding:8px 20px; font-size:13px; font-weight:bold; cursor:pointer; border-radius:4px;" title="Restart pgAdmin Service">
                            <i class="icon16 icomoon-icon-lightning" style="color:#ffffff !important;"></i> Restart Service
                        </button>
                    </form>
                    <form method="POST" style="margin:0; display:inline-block;" onsubmit="return confirm('Update pgAdmin 4 packages to the latest version?');">
                        <input type="hidden" name="pgadmin_service_action" value="upgrade">
                        <button type="submit" class="btn btn-primary" style="background:#007bff; color:#ffffff; border:none; padding:8px 20px; font-size:13px; font-weight:bold; cursor:pointer; border-radius:4px;" title="Update pgAdmin 4 Packages">
                            <i class="icon16 icomoon-icon-download" style="color:#ffffff !important;"></i> Update
                        </button>
                    </form>
                </div>
            </div>

            <!-- Change pgAdmin Password Form -->
            <div style="background:#f8f9fa; border:1px solid #e4e7ed; border-radius:5px; padding:15px; margin-top:5px;">
                <div style="font-size:12px; font-weight:bold; color:#495057; margin-bottom:10px;">
                    <i class="icon16 icomoon-icon-key" style="color:#007bff; margin-right:5px;"></i> pgAdmin username: <code>root</code> | Change Password:
                </div>
                <form method="POST" style="display:flex; gap:10px; margin:0;">
                    <input type="password" name="new_pgadmin_pwd" class="form-control" placeholder="Enter new password" required style="height:34px; font-size:12px; border:1px solid #ced4da; border-radius:4px; flex:1;">
                    <button type="submit" name="change_pgadmin_password" value="1" class="btn btn-primary" style="background:#007bff; border:none; height:34px; padding:0 16px; font-size:12px; font-weight:bold; color:#fff; border-radius:4px; cursor:pointer;">
                        Save
                    </button>
                </form>
            </div>
        </div>
    </div>
</div>
<?php endif; ?>

<!-- TAB: DATABASES -->
<?php if ($tab === 'databases'): ?>
<div class="row">
    <div class="col-md-12">
        <div class="pdns-card">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:15px; flex-wrap:wrap; gap:10px;">
                <h4 style="margin:0; font-size:16px;">
                    <i class="icon16 icomoon-icon-database" style="color:#007bff; margin-right:5px;"></i> <b>Databases</b>
                </h4>
            </div>

            <!-- Create DB inline form -->
            <form method="POST" style="margin-bottom:20px; display:flex; gap:10px; align-items:center;">
                <input type="hidden" name="action" value="create_db">
                <input type="text" name="dbname" class="form-control" placeholder="Enter database name" required pattern="[a-zA-Z0-9_]+" style="max-width:380px; height:34px; font-size:13px; border-radius:4px; border:1px solid #ced4da;">
                <button type="submit" class="btn btn-primary" style="background:#007bff; border:none; height:34px; padding:0 18px; font-weight:bold; color:#fff; border-radius:4px; cursor:pointer;">
                    <i class="icon16 icomoon-icon-plus" style="color:#ffffff !important;"></i> Create Database
                </button>
            </form>

            <table class="pdns-table sortable-table" id="table-databases">
                <thead>
                    <tr>
                        <th class="sortable-th" onclick="sortTable('table-databases', 0, 'str')">Database Name <span class="sort-icon">⇅</span></th>
                        <th style="width:140px;" class="sortable-th" onclick="sortTable('table-databases', 1, 'size')">Disk Size <span class="sort-icon">⇅</span></th>
                        <th style="width:120px;" class="sortable-th" onclick="sortTable('table-databases', 2, 'str')">Encoding <span class="sort-icon">⇅</span></th>
                        <th style="width:100px;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($databases)): ?>
                        <tr><td colspan="4" style="padding:15px; text-align:center; color:#888;">No PostgreSQL databases found.</td></tr>
                    <?php else: ?>
                        <?php foreach ($databases as $idx => $d): ?>
                            <tr>
                                <td>
                                    <span style="font-weight:bold; color:#17283a; font-size:13px;">
                                        <?php echo htmlspecialchars($d['name']); ?>
                                    </span>
                                </td>
                                <td><span class="badge" style="background:#6c757d; color:#fff; padding:4px 8px; border-radius:3px; font-size:11px;"><?php echo htmlspecialchars($d['size']); ?></span></td>
                                <td><code><?php echo htmlspecialchars($d['encoding']); ?></code></td>
                                <td>
                                    <?php if ($d['name'] !== 'postgres'): ?>
                                        <form method="POST" style="margin:0; display:inline;" onsubmit="return confirm('Are you sure you want to permanently drop database <?php echo htmlspecialchars($d['name']); ?>?');">
                                            <input type="hidden" name="action" value="drop_db">
                                            <input type="hidden" name="dbname" value="<?php echo htmlspecialchars($d['name']); ?>">
                                            <button type="submit" class="btn-action-delete" title="Drop Database">
                                                <i class="icon16 icomoon-icon-remove" style="color:#ffffff !important;"></i>
                                            </button>
                                        </form>
                                    <?php else: ?>
                                        <span style="font-size:11px; color:#888; font-weight:bold;">SYSTEM</span>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>
<?php endif; ?>

<!-- TAB: USERS -->
<?php if ($tab === 'users'): ?>
<div class="row">
    <div class="col-md-12">
        <div class="pdns-card">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:15px; flex-wrap:wrap; gap:10px;">
                <h4 style="margin:0; font-size:16px;">
                    <i class="icon16 icomoon-icon-users" style="color:#007bff; margin-right:5px;"></i> <b>Users</b>
                </h4>
            </div>

            <!-- Create User inline form -->
            <form method="POST" style="margin-bottom:20px; display:flex; gap:10px; align-items:center; flex-wrap:wrap;">
                <input type="hidden" name="action" value="create_user">
                <input type="text" name="username" class="form-control" placeholder="Enter username" required pattern="[a-zA-Z0-9_]+" style="max-width:240px; height:34px; font-size:13px; border-radius:4px; border:1px solid #ced4da;">
                <input type="password" name="password" class="form-control" placeholder="Password" required style="max-width:240px; height:34px; font-size:13px; border-radius:4px; border:1px solid #ced4da;">
                <button type="submit" class="btn btn-primary" style="background:#007bff; border:none; height:34px; padding:0 18px; font-weight:bold; color:#fff; border-radius:4px; cursor:pointer;">
                    <i class="icon16 icomoon-icon-user-plus" style="color:#ffffff !important;"></i> Add User
                </button>
            </form>

            <table class="pdns-table sortable-table" id="table-users">
                <thead>
                    <tr>
                        <th class="sortable-th" onclick="sortTable('table-users', 0, 'str')">Username <span class="sort-icon">⇅</span></th>
                        <th style="width:140px;" class="sortable-th" onclick="sortTable('table-users', 1, 'str')">Superuser <span class="sort-icon">⇅</span></th>
                        <th style="width:180px;">Action</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($users)): ?>
                        <tr><td colspan="3" style="padding:15px; text-align:center; color:#888;">No users found.</td></tr>
                    <?php else: ?>
                        <?php foreach ($users as $idx => $u): ?>
                            <tr>
                                <td>
                                    <span style="font-weight:bold; color:#17283a; font-size:13px;">
                                        <?php echo htmlspecialchars($u['username']); ?>
                                    </span>
                                </td>
                                <td>
                                    <?php if ($u['superuser'] === 'Yes'): ?>
                                        <span class="badge" style="background:#28a745; color:#fff; padding:4px 8px; border-radius:3px; font-size:11px;">YES</span>
                                    <?php else: ?>
                                        <span class="badge" style="background:#6c757d; color:#fff; padding:4px 8px; border-radius:3px; font-size:11px;">NO</span>
                                    <?php endif; ?>
                                </td>
                                <td>
                                    <div style="display:inline-flex; align-items:center; gap:6px;">
                                        <button type="button" class="btn btn-primary" onclick="toggleUserPasswordRow('pwd-row-<?php echo $idx; ?>')" style="background:#007bff !important; border:none; height:28px; padding:0 10px; font-size:11px; font-weight:bold; color:#ffffff !important; border-radius:4px; cursor:pointer; display:inline-flex; align-items:center; gap:4px;" title="Update Password">
                                            <i class="icon16 icomoon-icon-key" style="color:#ffffff !important;"></i> Update Password
                                        </button>
                                        <?php if ($u['username'] !== 'postgres'): ?>
                                            <form method="POST" style="margin:0; display:inline;" onsubmit="return confirm('Are you sure you want to delete user <?php echo htmlspecialchars($u['username']); ?>?');">
                                                <input type="hidden" name="action" value="drop_user">
                                                <input type="hidden" name="username" value="<?php echo htmlspecialchars($u['username']); ?>">
                                                <button type="submit" class="btn-action-delete" title="Delete User">
                                                    <i class="icon16 icomoon-icon-remove" style="color:#ffffff !important;"></i>
                                                </button>
                                            </form>
                                        <?php endif; ?>
                                    </div>
                                </td>
                            </tr>
                            <!-- Change Password Inline Drawer Row -->
                            <tr id="pwd-row-<?php echo $idx; ?>" style="display:none; background:#f4f6f9;">
                                <td colspan="3" style="padding:12px 18px; border-top:1px dashed #dcdfe6;">
                                    <form method="POST" style="display:flex; align-items:center; gap:10px; margin:0; flex-wrap:wrap;">
                                        <input type="hidden" name="action" value="change_user_pwd">
                                        <input type="hidden" name="username" value="<?php echo htmlspecialchars($u['username']); ?>">
                                        <span style="font-size:12px; font-weight:bold; color:#495057;">
                                            New password for <u><?php echo htmlspecialchars($u['username']); ?></u>:
                                        </span>
                                        <input type="password" name="new_password" class="form-control" placeholder="Enter new password" required style="max-width:240px; height:30px; font-size:12px; border:1px solid #ced4da; border-radius:4px;">
                                        <button type="submit" class="btn btn-primary" style="background:#007bff; border:none; height:30px; padding:0 14px; font-size:12px; font-weight:bold; color:#fff; border-radius:4px; cursor:pointer;">
                                            Update Password
                                        </button>
                                        <button type="button" onclick="toggleUserPasswordRow('pwd-row-<?php echo $idx; ?>')" class="btn btn-default" style="height:30px; padding:0 12px; font-size:12px; border:1px solid #ccc; background:#fff; border-radius:4px; cursor:pointer;">
                                            Cancel
                                        </button>
                                    </form>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
            <script type="text/javascript">
            function toggleUserPasswordRow(rowId) {
                var el = document.getElementById(rowId);
                if (el) {
                    el.style.display = (el.style.display === 'none' || el.style.display === '') ? 'table-row' : 'none';
                }
            }
            </script>
        </div>
    </div>
</div>
<?php endif; ?>
<!-- TAB: SETTINGS / CONFIG -->
<?php if ($tab === 'config'): ?>
<!-- PostgreSQL Configuration File Editor Card -->
<div class="row">
    <div class="col-md-12">
        <div class="pdns-card">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:15px; flex-wrap:wrap; gap:10px;">
                <div style="display:flex; align-items:center;">
                    <h4 style="margin:0; font-size:16px;">
                        <i class="icon16 icomoon-icon-cogs" style="color:#007bff; margin-right:5px;"></i>
                        <b>PostgreSQL Configuration File (<code><?php echo htmlspecialchars($pg_conf_path); ?></code>)</b>
                    </h4>
                </div>
                <div>
                    <span class="badge" style="background:#6c757d; color:#fff; padding:6px 10px; font-size:12px; border-radius:4px; font-weight:500;">
                        Auto-backups on save
                    </span>
                </div>
            </div>

            <form method="POST">
                <div class="form-group" style="margin-bottom:15px;">
                    <textarea name="config_content" id="pg_config_textarea" class="form-control" rows="22" style="font-family:Consolas, Monaco, monospace; font-size:13px; width:100%; padding:12px; box-sizing:border-box; background:#1e1e1e; color:#d4d4d4; border:1px solid #333; border-radius:4px; line-height:1.5; min-height:480px; resize:vertical;"><?php echo htmlspecialchars($current_config_content); ?></textarea>
                </div>
                <div style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; padding-top:12px; border-top:1px solid #eee;">
                    <label style="display:flex; align-items:center; gap:6px; cursor:pointer; font-weight:normal; margin:0;">
                        <input type="checkbox" name="restart_after_save" value="1" checked> <span style="margin: 10px 0 0 -10px">Restart PostgreSQL after changes</span>
                    </label>
                    <button type="submit" name="save_config" class="btn btn-primary" style="background:#007bff !important; background-color:#007bff !important; color:#ffffff !important; border:none; padding:8px 22px; font-weight:bold; font-size:13px; border-radius:4px; cursor:pointer; display:inline-flex; align-items:center; gap:6px;">
                        <i class="icon16 icomoon-icon-disk" style="color:#fff;"></i> Save Configuration
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>
<?php endif; ?>


<script type="text/javascript">
function parseSizeToBytes(str) {
    if (!str) return 0;
    str = str.trim().toUpperCase();
    var match = str.match(/^([0-9.]+)\s*([A-Z]+)?$/);
    if (!match) return 0;
    var num = parseFloat(match[1]);
    var unit = match[2] || '';
    if (unit.indexOf('G') !== -1) return num * 1024 * 1024 * 1024;
    if (unit.indexOf('M') !== -1) return num * 1024 * 1024;
    if (unit.indexOf('K') !== -1) return num * 1024;
    return num;
}

function sortTable(tableId, colIndex, type) {
    var table = document.getElementById(tableId);
    if (!table) return;
    var tbody = table.querySelector('tbody');
    if (!tbody) return;

    var rows = Array.from(tbody.rows);
    if (rows.length <= 1) return;

    var rowPairs = [];
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        if (r.id && r.id.indexOf('pwd-row-') === 0) continue;
        var nextRow = (i + 1 < rows.length && rows[i + 1].id && rows[i + 1].id.indexOf('pwd-row-') === 0) ? rows[i + 1] : null;
        rowPairs.push({ main: r, drawer: nextRow });
    }

    var th = table.querySelectorAll('thead th')[colIndex];
    if (!th) return;
    var currentDir = th.getAttribute('data-sort-dir') || 'none';
    var newDir = (currentDir === 'asc') ? 'desc' : 'asc';

    var allTh = table.querySelectorAll('thead th');
    allTh.forEach(function(h) {
        h.removeAttribute('data-sort-dir');
        var icon = h.querySelector('.sort-icon');
        if (icon) {
            icon.innerHTML = '⇅';
            icon.style.color = '#aaa';
        }
    });

    th.setAttribute('data-sort-dir', newDir);
    var currentIcon = th.querySelector('.sort-icon');
    if (currentIcon) {
        currentIcon.innerHTML = (newDir === 'asc') ? '▲' : '▼';
        currentIcon.style.color = '#007bff';
    }

    rowPairs.sort(function(a, b) {
        var cellA = a.main.cells[colIndex];
        var cellB = b.main.cells[colIndex];
        if (!cellA || !cellB) return 0;

        var valA = cellA.innerText.trim();
        var valB = cellB.innerText.trim();

        var cmp = 0;
        if (type === 'num') {
            var nA = parseFloat(valA) || 0;
            var nB = parseFloat(valB) || 0;
            cmp = nA - nB;
        } else if (type === 'size') {
            var sA = parseSizeToBytes(valA);
            var sB = parseSizeToBytes(valB);
            cmp = sA - sB;
        } else {
            cmp = valA.localeCompare(valB, undefined, { numeric: true, sensitivity: 'base' });
        }

        return (newDir === 'asc') ? cmp : -cmp;
    });

    rowPairs.forEach(function(pair) {
        tbody.appendChild(pair.main);
        if (pair.drawer) {
            tbody.appendChild(pair.drawer);
        }
    });
}
</script>