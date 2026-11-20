#!/bin/bash
# Read-only non-regression tests, emits @@TEST lines.
set -u
OUT="${1:-/tmp/hv-func}"; mkdir -p "$OUT"; : > "$OUT/fonctionnel.txt"
t() { printf '@@TEST %s %s %s\n' "$1" "$2" "$3" | tee -a "$OUT/fonctionnel.txt"; }
systemctl is-active rKE2-server >/dev/null 2>&1 && t FUNC.01 PASS "rKE2-server active" || t FUNC.01 FAIL "rKE2-server inactive"
kubectl get nodes >/dev/null 2>&1 && t FUNC.02 PASS "kubectl get nodes ok" || t FUNC.02 FAIL "kubectl failed"
kubectl get pods -A >/dev/null 2>&1 && t FUNC.03 PASS "kubectl get pods ok" || t FUNC.03 FAIL "pods list failed"
ss -lnt | grep -q ':6443 ' && t FUNC.04 PASS "API 6443 listening" || t FUNC.04 FAIL "no API listener"
ss -lnt | grep -q ':22 ' && t FUNC.05 PASS "SSH 22 listening" || t FUNC.05 FAIL "no SSH"
sshd -t >/dev/null 2>&1 && t FUNC.06 PASS "sshd config valid" || t FUNC.06 FAIL "sshd invalid"
systemctl is-active chronyd >/dev/null 2>&1 && t FUNC.07 PASS "chronyd active" || t FUNC.07 WARN "chronyd inactive"
ip link show | grep -q 'enp0s3' && t FUNC.08 PASS "management NIC present" || t FUNC.08 FAIL "no management NIC"
[ -f /oem/90_custom.yaml ] || [ -f /oem/99_custom.yaml ] && t FUNC.09 PASS "OEM config present" || t FUNC.09 FAIL "no OEM config"
df -h / | tail -1 | grep -q '/' && t FUNC.10 PASS "root fs mounted" || t FUNC.10 FAIL "root fs issue"
free -m | grep -q Mem && t FUNC.11 PASS "memory readable" || t FUNC.11 FAIL "memory unreadable"
systemctl --failed --no-legend 2>/dev/null | grep -q . && t FUNC.12 WARN "failed units present" || t FUNC.12 PASS "no failed units"
getent passwd rancher >/dev/null 2>&1 && t FUNC.13 PASS "rancher user present" || t FUNC.13 FAIL "rancher user missing"
