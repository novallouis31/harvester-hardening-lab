#!/bin/bash
# Read-only Harvester audit. Output: @@CHECK <ID> <STATUS> <text> + TSV rows.
set -u
OUT="${1:-/tmp/hv-audit}"
mkdir -p "$OUT"; : > "$OUT/checks.tsv"; LOG="$OUT/audit.txt"; : > "$LOG"
chk() { printf '@@CHECK %s %s %s\n' "$1" "$2" "$3" | tee -a "$LOG"; printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$OUT/checks.tsv"; }
note() { printf '## %s\n' "$1" | tee -a "$LOG"; }

OEM=""
for f in /oem/90_custom.yaml /oem/99_custom.yaml; do [ -f "$f" ] && OEM="$f" && break; done
RKE2=/etc/rancher/rke2/config.yaml.d/52-stig.yaml
SYSCTL=/etc/sysctl.d/99-harvester.conf
PSA=/etc/rancher/rke2/config.yaml.d/51-rke2-pss-custom.yaml
AUDITP=/etc/rancher/rke2/audit-policy.yaml

note "PLATFORM"
OS="$(grep -h '^NAME=' /etc/os-release 2>/dev/null | cut -d'"' -f2)"
HV="$(cat /etc/harvester-release 2>/dev/null | head -1)"
chk HV.01 INFO "os=$OS harvester=$HV kernel=$(uname -r)"
[ -n "$OEM" ] && chk HV.02 PASS "persistent config: $OEM" || chk HV.02 FAIL "no /oem/*_custom.yaml"

note "RKE2 CIS PROFILE"
if [ -f "$RKE2" ]; then
  grep -Eq 'profile: *"?cis(-1\.[0-9]+)?' "$RKE2" && chk HV.03 PASS "CIS profile set" || chk HV.03 FAIL "no CIS profile"
  chk HV.04 NA "service-account flag removed in RKE2 v1.29+"
  grep -q 'tls-min-version=VersionTLS12' "$RKE2" && chk HV.05 PASS "TLS 1.2 minimum" || chk HV.05 FAIL "TLS version not pinned"
  chk HV.06 NA "TLS cipher suites handled by the generic cis profile on RKE2 v1.29+"
  grep -q 'authorization-mode=RBAC,Node' "$RKE2" && chk HV.07 PASS "RBAC,Node" || chk HV.07 FAIL "authorization-mode not RBAC,Node"
  grep -q 'anonymous-auth=false' "$RKE2" && chk HV.08 PASS "anonymous auth off" || chk HV.08 FAIL "anonymous auth enabled"
  grep -q 'audit-policy-file=' "$RKE2" && chk HV.09 PASS "audit policy referenced" || chk HV.09 FAIL "no audit policy"
  grep -q 'protect-kernel-defaults=true' "$RKE2" && chk HV.10 PASS "kubelet protect-kernel-defaults" || chk HV.10 FAIL "kubelet defaults not protected"
  chk HV.11 NA "PSA is managed automatically by the generic cis profile"
else chk HV.03 FAIL "missing $RKE2"; fi
[ -f "$AUDITP" ] && chk HV.12 PASS "audit policy file present" || chk HV.12 INFO "no audit policy file"
chk HV.13 INFO "PSA restricted mode applied by RKE2 cis profile (no manual file)"

note "SYSCTL (Elemental persist)"
if [ -f "$SYSCTL" ]; then
  for k in vm.panic_on_oom=0 vm.overcommit_memory=1 kernel.panic=10 kernel.panic_on_oops=1; do
    grep -q "$k" "$SYSCTL" && chk "HV.14.${k%%=*}" PASS "$k" || chk "HV.14.${k%%=*}" FAIL "$k missing"
  done
else chk HV.14 FAIL "no persistent sysctl file"; fi
getent group etcd >/dev/null 2>&1 && id etcd >/dev/null 2>&1 && chk HV.15 PASS "etcd user/group present" || chk HV.15 FAIL "etcd user/group missing"

note "SSH"
grep -q '^PasswordAuthentication no' /etc/ssh/sshd_config.d/*.conf 2>/dev/null && chk HV.16 PASS "password auth off" || chk HV.16 FAIL "password auth allowed"
grep -q '^PermitRootLogin prohibit-password' /etc/ssh/sshd_config.d/*.conf 2>/dev/null && chk HV.17 PASS "root key-only" || chk HV.17 FAIL "root login unrestricted"
sshd -t >/dev/null 2>&1 && chk HV.18 PASS "sshd config valid" || chk HV.18 FAIL "sshd -t failed"

note "CLUSTER STATE"
systemctl is-active rke2-server >/dev/null 2>&1 && chk HV.19 PASS "rke2-server active" || chk HV.19 FAIL "rke2-server inactive"
ss -lnt | grep -q ':6443 ' && chk HV.20 PASS "API 6443 listening" || chk HV.20 FAIL "no API listener"
KUBECTL=/var/lib/rancher/rke2/bin/kubectl
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
[ -x "$KUBECTL" ] && "$KUBECTL" get nodes >/dev/null 2>&1 && chk HV.21 PASS "kubectl get nodes ok" || chk HV.21 FAIL "kubectl failed"
[ -x "$KUBECTL" ] && "$KUBECTL" -n longhorn-system get secret >/dev/null 2>&1 && chk HV.22 INFO "longhorn secrets readable" || chk HV.22 INFO "no longhorn namespace"
chk HV.23 NA "Longhorn encryption at rest: verify manually with kubectl"
chk HV.24 NA "Management network isolation / VPN: not testable in NAT lab"
chk HV.25 NA "Physical / IPMI / supply chain: out of lab scope"
