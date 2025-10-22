# 🧪 COMPREHENSIVE TEST PLAN
# VPN Multi-Profile Manager - Phase 9 Testing

**Date**: 2025-10-18
**Status**: Ready for Testing
**Tester**: Claude (Automated)

---

## 📊 SCRIPTS INVENTORY

Total Scripts: 24 files
- Core: 14 scripts
- Profile Scripts: 9 scripts
- Docker: 1 entrypoint.sh

---

## 🎯 TEST STRATEGY

### Test Levels:
1. **Unit Tests** - Individual functions
2. **Integration Tests** - Functions working together
3. **System Tests** - Full workflows
4. **Syntax Tests** - Bash syntax validation

### Test Environment:
- OS: Linux (current system)
- Shell: /bin/bash
- Working Dir: /root/work

---

## 📋 TEST PLAN BY SCRIPT

### GROUP 1: FOUNDATION (Priority: CRITICAL)

#### 1.1 scripts/utils.sh (20 functions)
**Purpose**: Core utility functions

| Function | Test Case | Expected Result | Priority |
|----------|-----------|-----------------|----------|
| `load_env()` | Load .env.example | Variables loaded | HIGH |
| `validate_domain()` | Test: example.com | Returns 0 (valid) | HIGH |
| `validate_domain()` | Test: vpn.example.com | Returns 0 (valid) | HIGH |
| `validate_domain()` | Test: invalid domain | Returns 1 (invalid) | HIGH |
| `validate_ip()` | Test: 192.168.1.1 | Returns 0 | MEDIUM |
| `generate_password()` | Generate 12 chars | String 12 chars | HIGH |
| `check_port()` | Check port 22 | Returns status | MEDIUM |
| `find_available_port()` | Find in range 2200-2299 | Returns available port | HIGH |
| `format_bytes()` | Convert 1024 to KB | "1.0 KB" | LOW |
| `get_cpu_usage()` | Get current CPU % | Number 0-100 | MEDIUM |
| `get_mem_usage()` | Get current RAM MB | Number > 0 | MEDIUM |
| `get_disk_usage()` | Get disk % | Number 0-100 | MEDIUM |

**Test Method**: Source script + call functions

---

#### 1.2 scripts/colors.sh (13 functions)
**Purpose**: Color output functions

| Function | Test Case | Expected Result | Priority |
|----------|-----------|-----------------|----------|
| `print_success()` | Print test message | Green ✔ output | LOW |
| `print_error()` | Print test message | Red ✖ output | LOW |
| `print_warning()` | Print test message | Yellow ⚠ output | LOW |
| `print_banner()` | Show banner | ASCII art displayed | LOW |
| `print_progress()` | Show 50% progress | Progress bar | LOW |

**Test Method**: Source + visual check

---

### GROUP 2: CORE FUNCTIONALITY (Priority: HIGH)

#### 2.1 scripts/profile-manager.sh (7 functions)
**Purpose**: Profile CRUD operations

| Function | Test Case | Expected Result | Priority |
|----------|-----------|-----------------|----------|
| `list_profiles()` | List when empty | "No profiles" message | HIGH |
| `create_profile()` | Interactive input test | Would need mock inputs | CRITICAL |
| `delete_profile()` | Delete test profile | Profile removed | HIGH |
| `access_profile()` | SSH to profile | SSH command shown | HIGH |
| `extend_expiration()` | Add 30 days | Expiration updated | MEDIUM |
| `extend_bandwidth()` | Add 1TB | Bandwidth updated | MEDIUM |

**Test Method**: Partial - some functions need mock input

---

#### 2.2 scripts/backup-manager.sh (8 functions)
**Purpose**: Backup orchestration

| Function | Test Case | Expected Result | Priority |
|----------|-----------|-----------------|----------|
| `create_backup_dir()` | Create /tmp/test-backup | Directory created | HIGH |
| `backup_profiles_config()` | Backup profiles.json | File copied | HIGH |
| `backup_ssl_certs()` | Check SSL backup logic | Runs without error | MEDIUM |
| `backup_profile_data()` | Backup single profile | Tar.gz created | HIGH |
| `create_backup_archive()` | Create archive | .tar.gz file exists | HIGH |
| `cleanup_old_backups()` | Remove old backups | Old files deleted | MEDIUM |

**Test Method**: Dry run with test directories

---

#### 2.3 scripts/health-check.sh (3 functions)
**Purpose**: System health monitoring

| Function | Test Case | Expected Result | Priority |
|----------|-----------|-----------------|----------|
| `show_status()` | Display health dashboard | ASCII table output | HIGH |
| `check_profile_health()` | Check Docker containers | Status per profile | HIGH |
| `run_monitor()` | Monitor mode | Continuous checking | MEDIUM |

**Test Method**: Run status command

---

### GROUP 3: MONITORING (Priority: MEDIUM)

#### 3.1 scripts/bandwidth-monitor.sh
**Purpose**: Track bandwidth usage

**Tests**:
- Run script to check syntax
- Verify vnstat commands
- Check log output format

---

#### 3.2 scripts/expiration-check.sh
**Purpose**: Check profile expiration

**Tests**:
- Check with no profiles
- Check with expired profile (mock)
- Verify notification logic

---

#### 3.3 scripts/cron-alternative.sh
**Purpose**: Background scheduler

**Tests**:
- Syntax check
- Verify cron job setup
- Check log rotation

---

### GROUP 4: BACKUP SYSTEM (Priority: MEDIUM)

#### 4.1 scripts/backup-s3.sh
**Tests**:
- Syntax validation
- Check AWS CLI usage
- Verify S3 upload logic (without real S3)

#### 4.2 scripts/backup-rclone.sh
**Tests**:
- Syntax validation
- Check rclone commands
- Verify remote path logic

#### 4.3 scripts/restore-manager.sh
**Tests**:
- List backups function
- Extract backup function (dry run)
- Verify restore logic

---

### GROUP 5: SSL MANAGEMENT (Priority: HIGH)

#### 5.1 scripts/ssl-manager.sh
**Tests**:
- Queue management functions
- Certificate request logic
- Rate limit checking
- Nginx config generation

#### 5.2 scripts/ssl-renew.sh
**Tests**:
- Check renewal logic
- Verify expiration detection
- Test acme.sh integration

---

### GROUP 6: VPN SCRIPTS (Priority: MEDIUM)

#### profile-scripts/add-vmess.sh
#### profile-scripts/add-vless.sh
#### profile-scripts/add-trojan.sh

**Tests** (for each):
- Syntax validation
- UUID generation
- Config.json manipulation
- Link generation format

#### profile-scripts/del-vpn.sh
**Tests**:
- User deletion logic
- Config cleanup

#### profile-scripts/list-users.sh
**Tests**:
- Parse config.json
- Display user list

#### profile-scripts/check-vpn.sh
**Tests**:
- User lookup
- Stats display

---

### GROUP 7: DOCKER & SYSTEM (Priority: CRITICAL)

#### 7.1 docker/Dockerfile
**Tests**:
- Docker build test
- Image size check
- Package installation verification

#### 7.2 docker/entrypoint.sh
**Tests**:
- Syntax validation
- Service startup sequence
- Logging output

#### 7.3 setup.sh
**Tests**:
- Dependency check functions
- Directory creation logic
- Permission setting
- **DO NOT run full install**

---

## 🔄 TEST EXECUTION ORDER

### Phase 1: Syntax Validation (ALL SCRIPTS)
```bash
for script in scripts/*.sh; do
  bash -n "$script" && echo "✅ $script" || echo "❌ $script"
done
```

### Phase 2: Foundation Testing
1. Test colors.sh visual output
2. Test utils.sh validation functions
3. Test utils.sh system metrics

### Phase 3: Core Function Testing
1. Test profile-manager.sh list function
2. Test backup-manager.sh dry run
3. Test health-check.sh status

### Phase 4: Integration Testing
1. Test backup → restore flow (dry run)
2. Test profile creation simulation
3. Test monitoring scripts

### Phase 5: Docker Testing
1. Docker build test
2. Image inspection
3. Entrypoint validation

---

## 📝 TEST REPORT FORMAT

For each test:
```
TEST: [Script] - [Function]
STATUS: ✅ PASS / ❌ FAIL / ⚠️ SKIP
COMMAND: <command executed>
OUTPUT: <actual output>
EXPECTED: <expected result>
NOTES: <any observations>
```

---

## 🐛 BUG TRACKING

If bugs found:
1. Document in TEST_RESULTS.md
2. Fix immediately
3. Commit fix to GitHub (pakai MCP)
4. Re-test
5. Mark as FIXED

---

## ✅ SUCCESS CRITERIA

All tests PASS when:
- ✅ All syntax checks pass
- ✅ Foundation functions return correct values
- ✅ No runtime errors in dry runs
- ✅ Docker image builds successfully
- ✅ No critical bugs found

---

**NEXT**: Execute testing phase by phase, document results
