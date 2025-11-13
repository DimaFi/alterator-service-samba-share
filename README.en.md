# Script for Managing Samba Shared Folders

*(This fiel is a engish documentation. RUssian version here: [README.ru.md](README.ru.md))*

This script provides a convenient and reliable way to manage Samba shared folders (shares) on ALT Linux.  
It allows creating, updating, deleting, starting, stopping and inspecting Samba shares, as well as controlling Samba services.

---

## Key Features

- **Create and delete Samba shares** with configuration of:
  - share name (`share_name`)
  - directory path (`share_path`)
  - owner (`access_user`)
  - access type (`ro` — read-only, `rw` — read/write)
  - additional allowed users (`allowed_users`)
- **Control Samba services** (`smb.service`, `nmb.service`)
- **Deploy and undeploy Samba** (enable or disable services)
- **Full ACL support** — automatic application of filesystem permissions
- **Backup and restore of configuration and data**
- **Configuration validation** (`testparm -s`)
- **Return Samba state and existing shares in JSON format**
- **Detailed logging** of all operations for debugging and auditing

---

## File Locations

| File / Directory                           | Description                                      | Path                                                                |
|--------------------------------------------|--------------------------------------------------|---------------------------------------------------------------------|
| Main script                                | CLI tool for managing Samba shares               | `/usr/bin/service-samba-shares`                                     |
| Backend file                               | Backend logic for Alterator                     | `/usr/share/alterator/backends/service-samba-shares.backend`        |
| Alterator service description               | `.service` file for integration with Alterator  | `/usr/share/alterator/service/service-samba-shares.service`         |
| Configuration backup directory              | Stores configuration backups                    | `/var/lib/alterator/service/service-samba-shares/config-backup`     |
| Data backup directory                       | Stores share data backups                        | `/var/lib/alterator/service/service-samba-shares/backup`            |

---

## How the Script Works — Detailed Explanation

### 1. Execution, Permissions and Logging

On each run, the script:

- Must be executed as **root** (checked via `EUID`)
- Writes all significant actions and errors to:

/var/log/samba-shares.log

Logged information includes:
- timestamp  
- PID  
- message text  

---

### 2. Reading Input

The script expects input in JSON format:

- It first attempts to read JSON from stdin with a 10-second timeout
- If nothing is received, an empty object "{}" is used
- The operation field can be:
- inside JSON ({"operation": "create", ...})
- or passed as the first CLI argument

If operation is missing, the script defaults to status.

---

### 3. Parsing Parameters

Arguments are grouped inside JSON by operation type:

{
"operation": "create",
"create": {
  "share_name": "data",
  "share_path": "/srv/data",
  "access_user": "alice",
  "access_type": "rw",
  "allowed_users": "bob,carol",
  "anonymous_enabled": true
}
}

### Parameters for `create`:

* `share_name` — required
* `share_path` — required
* `access_user` — required (unless anonymous access is enabled)
* `access_type` — `ro` or `rw`
* `allowed_users` — optional comma-separated list
* `anonymous_enabled` — enables guest access

### Parameters for `update`:

* `share_name` — required
* `share_path`, `access_user`, `access_type`, `allowed_users` — optional
  (current values preserved if omitted)
* `delete_prev_allowed` — `true` to replace allowed users instead of merging
* `anonymous_enabled` — enable or disable anonymous access

### Parameters for `delete`:

* `share_name` — required

### Parameters for `backup` / `restore`:

* `backup_name` — optional name of backup set

If required parameters are missing, the script returns a JSON error message and logs the issue.

---

## 4. Working With Samba Configuration and ACL

The script operates on the main Samba configuration file:

/etc/samba/smb.conf

It uses `testparm -s` + `awk` to extract:

* share name
* directory path
* access type
* allowed users (`valid users`)

### `create` workflow:

* Ensures the share does not already exist
* Creates the directory, sets owner (`chown`) and base permissions (`chmod 2750` or `2770`)
* Builds the `valid users` list from:

  * owner
  * allowed_users
  * `anonymous_enabled` (adds or removes `nobody`)
* Applies ACL via `setfacl`:

  * owner receives full access through normal permissions
  * each allowed user receives either:

    * `rwx` (for `rw`)
    * `rx`  (for `ro`)
* Adds the share section to `smb.conf`
* Validates configuration with `testparm`
* Restarts `smb.service`

### `update` workflow:

* Reads current settings from `smb.conf`
* Merges or replaces allowed_users (depending on `delete_prev_allowed`)
* Updates directory permissions and ACL
* Removes old section and writes updated one
* Validates configuration and restarts Samba

### `delete` workflow:

* Ensures the share exists
* Removes only its configuration from `smb.conf`
  (the directory is not deleted)
* Validates configuration and restarts Samba

Errors (invalid config, failed restart, etc.) produce JSON output with explanation.

---

## 5. Service Management and Backups

The script can manage Samba services and configuration.

### `deploy`:

* Verifies Samba installation
* Saves original `smb.conf` to:

  
  /var/lib/alterator/service/service-samba-share/config-backup/smb-original.conf
  
* Enables and starts `smb` and `nmb`
* Returns JSON with service status

### `undeploy`:

* Automatically performs full backup using `backup_all`
* Stops and disables `smb` and `nmb`
* Restores the original `smb.conf`
* Returns JSON with auto-backup details

### `backup`:

* Saves:

  * `smb.conf`
  * directories of existing shares (if present)
* Stores backups in:

config-backup/
  data-backup/
  
* Returns JSON with backup paths

### `restore`:

* Restores `smb.conf` from specified or latest backup
* Validates via `testparm`
* Restarts Samba
* Restores data archive if available
* Returns JSON with restore details

### `status`:

* Checks the state of `smb.service` and `nmb.service`
* Collects all shares via `get_samba_shares` and filesystem attributes
* Returns JSON with services and shares
* Exit codes:

  * **128** — both services active
  * **127** — only one service active
  * **0** — both services inactive

---

## Description of `.service` File (Alterator Integration)

The `.service` file describes the **samba_shares** service used by the Alterator configuration system.

### Main Fields

* `type = "Service"` — defines a service-type module
* `name = "samba_shares"` — unique system name
* `category = "X-Alterator-Servers"` — displayed under “Servers” category
* `persistent = true` — settings persist after reboot
* `display_name`, `comment` — localized UI strings
* `icon = "network-server"` — icon used by Alterator

### Parameters

* `share_name` — unique name of the Samba share
* `share_path` — filesystem path
* `access_user` — owner
* `access_type` — `ro` or `rw`
* `enabled` — whether the share is active

Used in: configure, backup, restore, status.

### Resources

* `smb_conf` — `/etc/samba/smb.conf`
* `smb_service` — `smb.service`
* `nmb_service` — `nmb.service`

### The `shares` Array

Contains all current Samba shares with:

* share name
* path
* owner
* access type
* enabled flag

Displayed by Alterator in the `status` mode.

---

# ACL

The script uses `setfacl` and `getfacl` to manage access permissions.
The main function responsible for this is `apply_fs_acl_for_valid_users`.

### Workflow:

#### 1. Remove existing ACL

```bash
setfacl -b "$path"
```

#### 2. Set permission masks

setfacl -m m::rwx "$path"
setfacl -d -m m::rwx "$path"

This ensures ACL rules are not restricted by the mask.

#### 3. Assign per-user permissions

For each user in allowed_users (excluding the owner):

* rw → rwx
* ro → rx

With inheritance:

setfacl -m u:"$user":"$perms" "$path"
setfacl -d -m u:"$user":"$perms" "$path"

---

### ACL Output Example

```json
# file: /srv/projects
# owner: ivan
# group: ivan
user::rwx
user:sergey:rwx
user:anna:rx
group::---
mask::rwx
other::---
default:user::rwx
default:user:sergey:rwx
default:user:anna:rx
default:group::---
default:mask::rwx
default:other::---
```

Explanation:

* user::rwx — full access for owner (ivan)
* user:sergey:rwx — Sergey can create/edit files
* user:anna:rx — Anna can only read
* default: — inherited permissions for new files

---

### ACL & Samba Interaction

Samba uses the valid users parameter from smb.conf.
ACL ensures that filesystem permissions match Samba settings.

This prevents issues such as:

* Samba allowing access to a user who lacks filesystem permissions
* User having filesystem access but missing from valid users

Synchronization ensures consistency across both layers.

---

### ACL Mapping Examples

| Access Type           | valid users      | Filesystem ACL                  |
| --------------------- | ------------------ | ------------------------------- |
| rw (read/write)       | ivan, sergey, anna | ivan:rwx, sergey:rwx, anna:rwx  |
| ro (read-only)        | ivan, sergey, anna | ivan:rwx, sergey:rx, anna:rx    |
| anonymous_access=true | adds nobody      | nobody:rx or nobody:rwx (if rw) |

---

### ACL Behavior Highlights

* ACL applies only to the share root directory
  New files inherit permissions automatically.
* On update, old ACL entries are fully cleared to avoid conflicts.
* Owner (access_user) uses standard UNIX permissions, not ACL entries.
* If anonymous access is enabled, user nobody is added to ACL.

---

## Localization

Documentation is available in two languages:

* 🇷🇺 Russian — [README.ru.md](README.ru.md)
* 🇬🇧 English — this file [README.en.md](README.en.md)

---

## License

GPLv3 — © 2025 Dmitry Filippenko