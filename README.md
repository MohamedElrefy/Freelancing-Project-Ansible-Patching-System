# Linux Patching System

A comprehensive Ansible-based patching solution for Rocky Linux 9.6 and Ubuntu 22.04 systems using offline mirror repositories.

## Overview

This system provides automated, auditable patching for heterogeneous Linux environments through two primary playbooks:

- **Rocky Linux 9.6 Offline Patch Playbook** - DNF-based patching for RHEL-compatible systems
- **Ubuntu 22.04 Offline Patch Playbook** - APT-based patching for Debian-compatible systems

Both playbooks follow a unified workflow: configure offline mirrors, perform updates, analyze results, and generate comprehensive JSON reports.


### Network Requirements

- **Mirror Host**: 
- **Protocol**: HTTPS (port 443)
- **Certificate**: Self-signed (verification disabled)
- **Connectivity**: All target hosts must reach the mirror on port 443

## Rocky Linux Playbook

### Repository Configuration

The playbook configures eight offline repositories:

| Repository | Purpose |
|------------|---------|
| baseos | Core OS packages |
| appstream | Additional applications |
| crb | CodeReady Builder packages |
| epel | Extra Packages for Enterprise Linux |
| extras | Additional Rocky Linux packages |
| highavailability | HA cluster packages |
| zabbix | Zabbix monitoring agent |
| zabbix-tools | Zabbix utilities |

**Base URL**: `https://##your mirror repos##`

### Workflow

1. **Pre-flight Setup**
   - Generates UTC timestamp for all logs
   - Adds mirror host entry to `/etc/hosts`
   - Verifies HTTPS connectivity to mirror

2. **Repository Management**
   - Backs up existing `.repo` files to timestamped directory
   - Creates temporary offline repository configurations
   - Disables GPG checking and SSL verification

3. **Package Operations**
   - Validates `/var` has at least 2GB free space
   - Cleans and rebuilds DNF cache
   - Performs `dnf upgrade --refresh`
   - Runs `dnf distro-sync` to repair dependencies
   - Retries failed operations automatically

4. **Post-Patch Analysis**
   - Removes temporary mirror configurations
   - Parses upgrade output for package lists
   - Identifies kernel package changes
   - Checks reboot requirements using `dnf needs-restarting`
   - Calculates execution time and uptime

5. **Reporting**
   - Aggregates results from all hosts
   - Generates timestamped JSON report
   - Creates symbolic link to latest report

### Patch States

The playbook determines one of six possible states:

- **`error`** - Patching failed with captured error message
- **`updated`** - Packages upgraded and DNF history exists
- **`no_history`** - Packages upgraded but no DNF history log
- **`no_change_patched`** - No upgrades but DNF history exists
- **`no_change_no_history`** - No upgrades and no DNF history
- **`unreported`** - State could not be determined


## Ubuntu Playbook

### Dynamic Host Building

The Ubuntu playbook includes a preliminary play (Play 0) that dynamically constructs the target host list with site-specific SSH keys:

- Filters out localhost and mirror server
- Extracts location-based groups for SSH key selection
- Sets SSH connection parameters (pipelining, no host key checking)
- Creates `dynamic_hosts` group for patching

### Repository Configuration

Configures three Ubuntu repositories through temporary mirror:

- `jammy` (main, universe)
- `jammy-updates` (main, universe)
- `jammy-security` (main, universe)

**Base URL**: `https://<mirror-repo-path>`

### Workflow

1. **Dynamic Host Setup**
   - Builds `dynamic_hosts` from inventory
   - Configures site-specific SSH keys based on location groups
   - Excludes mirror server from patching

2. **Pre-flight Setup**
   - Adds mirror host to `/etc/hosts`
   - Verifies HTTPS connectivity
   - Seeds official Ubuntu sources if missing
   - Removes legacy mirror entries

3. **Repository Management**
   - Creates temporary `_tmp-local-mirror.list` source file
   - Configures APT to accept self-signed certificate
   - Updates APT cache with retry logic (5 attempts, 12s delay)

4. **Package Operations**
   - Validates `/var` has at least 2GB free space
   - Performs `apt-get upgrade` with retry logic
   - Identifies held-back packages
   - Runs `apt-get dist-upgrade` for critical packages (systemd, snapd, linux-*)
   - Repairs broken dependencies with `apt-get -f install`

5. **Post-Patch Cleanup**
   - Removes temporary mirror configuration files
   - Cleans up all mirror references from sources
   - Normalizes file permissions (0644)

6. **Analysis & Reporting**
   - Parses upgrade statistics (upgraded, installed, removed, held-back)
   - Extracts package lists using regex patterns
   - Identifies kernel package changes
   - Checks `/var/run/reboot-required` flag
   - Generates per-host and consolidated reports

### Package List Parsing

The playbook extracts package information from APT output:

- **Upgraded**: Packages updated to newer versions
- **Newly Installed**: Dependencies installed during upgrade
- **Held Back**: Packages kept at current version
- **Linux Kernels**: Kernel-related packages (image, modules, headers)

### Example Usage

```bash
# Patch all Ubuntu systems in inventory
ansible-playbook ubuntu_patch_playbook.yml -i inventory.ini

# Patch specific site
ansible-playbook ubuntu_patch_playbook.yml -i inventory.ini --limit locations_brg
```

## Common Features

### Error Handling

Both playbooks use rescue blocks to capture failures:

```yaml
rescue:
  - name: Capture error details
    ansible.builtin.set_fact:
      patch_error_msg: "{{ ansible_failed_task.name }}: {{ ansible_failed_result.msg }}"
```

Errors are included in the final JSON report with full context.

### Reboot Detection

**Rocky Linux**: Uses `dnf needs-restarting --reboothint` (exit code ≠ 0 indicates reboot needed)

**Ubuntu**: Checks `/var/run/reboot-required` file existence

Both also detect kernel package installations and flag reboot necessity.

### Timing & Metrics

All operations capture:
- Start/finish timestamps (UTC ISO 8601)
- Execution time in seconds
- System uptime (hours, minutes, seconds)
- Kernel version before/after patching
- packages installed, upgraded, to remove and heldback

### JSON Report Structure

```json
{
  "os": "Rocky Linux 9.6 / Ubuntu 22.04",
  "host": "hostname.example.com",
  "patch_state": "updated",
  "uptime": "45 hours, 23 minutes, 12 seconds",
  "timestamp": "20241119T143022Z",
  "started_at": "2024-11-19T14:25:00Z",
  "finished_at": "2024-11-19T14:30:22Z",
  "exec_time_sec": 322,
  "kernel_before": "5.14.0-362.el9.x86_64",
  "kernel_after": "5.14.0-427.el9.x86_64",
  "kernel_changed": true,
  "reboot_needed": true,
  "reboot_reason": "kernel_upgraded",
  "unreachable": false,
  "error": "",
  "upgrade_stats": {
    "upgraded": 87,
    "newly_installed": 5,
    "to_remove": 0,
    "not_upgraded": 3,
    "security_updates": 12
  },
  "packages": {
    "upgraded": ["package1", "package2", "..."],
    "newly_installed": ["dependency1", "..."],
    "linux_kernels": ["kernel-5.14.0-427.el9.x86_64"],
    "held_back": []
  },
  "fix_broken": {
    "changed": false,
    "rc": 0,
    "output": ""
  }
}
```

### Report Locations

**Rocky Linux**: `/usr/local/ansible/projects/rocky/logs/`
**Ubuntu**: `/usr/local/ansible/projects/ubuntu/logs/`

Files:
- `master_run_YYYY-MM-DD_HH:MM:SS_UTC.json` - Timestamped report
- `master_run.json` - Symlink to latest report

## Prerequisites

### System Requirements

- Ansible 2.18+ with `community.general` collection
- Target hosts running Rocky Linux 9.6 or Ubuntu 22.04
- Python 3 on all target systems
- Rundeck user with proper permissions (for log ownership)

### Inventory Requirements

**Rocky Linux**: Standard inventory with `all` group

**Ubuntu**: Inventory with:
- Location groups (e.g., `locations_brg`, `locations_nyc`)
- SSH key files named: `ansible-{site}-plabs-it-ubuntu-primary-ws-ecdsa`
- Variables: `primary_ip4` or `ansible_host` for connectivity

### Network Access

- All target hosts → Mirror 
- Ansible controller → Target hosts (SSH)
- At least 2GB free space in `/var` partition

## Security Considerations

### SSL Verification Disabled

Both playbooks disable SSL verification for the self-signed mirror certificate:

- Rocky: `sslverify=0` in repository files
- Ubuntu: `Verify-Peer "false"` and `Verify-Host "false"` in APT config

**Recommendation**: Replace with properly signed certificates in production.

### SSH Key Management

Ubuntu playbook uses location-based SSH keys stored in:
```
/usr/local/ansible/keys/workstations/ansible-{site}-ubuntu-ecdsa
```

Ensure these keys have restricted permissions and are properly secured.



### Package Update Failures

**Rocky Linux**: Check `/var/log/dnf.log` for detailed error messages

**Ubuntu**: Review `/var/log/apt/history.log` and `/var/log/apt/term.log`

### Disk Space Issues

Both playbooks check for 2GB free space in `/var`. If failures occur:

```bash
# Check current usage
df -h /var

# Clean package cache
dnf clean all        # Rocky Linux
apt-get clean        # Ubuntu
```

### SSH Authentication Failures (Ubuntu)

Verify SSH key exists and has correct permissions:

```bash
ls -la /usr/local/ansible/keys/workstations/ansible-*
chmod 600 /usr/local/ansible/keys/workstations/ansible-*
```

### Playbook Customization

Key variables to adjust:

- `log_dir`: Change report output location
- `mirror_host`: Point to different mirror server
- `offline_repos`: Add/remove Rocky Linux repositories
- Retry counts and delays for network operations

## Best Practices

1. **Test in non-production** before deploying to critical systems
2. **Schedule during maintenance windows** when reboots are acceptable
3. **Monitor first run closely** to catch configuration issues early
4. **Review JSON reports** for unexpected held-back or failed packages
5. **Coordinate reboots** based on `reboot_needed` flag in reports
6. **Maintain mirror availability** - single point of failure for patching
7. **Archive reports** for compliance and audit trails
8. **Update SSH keys** before they expire (Ubuntu systems)

## Support

For issues or questions:
- Review playbook output for error messages
- Check generated JSON reports in log directories
- Examine system package manager logs (`/var/log/dnf.log`, `/var/log/apt/`)
- Verify mirror availability and content freshness

## Future Enhancements

### Modular Architecture Refactoring

The current playbooks contain all logic in single monolithic files. Future iterations will implement a modular structure following Ansible best practices:

#### Benefits of Modular Structure

1. **Reusability**: Common roles (mirror_setup, reporting) shared between distros
2. **Maintainability**: Each role focuses on single responsibility
3. **Testing**: Individual roles can be tested independently with Molecule
4. **Readability**: Smaller, focused files instead of 500+ line playbooks
5. **Version Control**: Easier to track changes in specific components
6. **Collaboration**: Multiple team members can work on different roles simultaneously
7. **Error Isolation**: Failures contained within specific role contexts


