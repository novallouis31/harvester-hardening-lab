#!/bin/bash
# Reversible Harvester hardening (Elemental/RKE2 CIS), based on the
# bcdurden/harvester_hardening_beta guide. Run on the node as rancher (sudo).
# Usage: LEVEL=1|2 DRY_RUN=1 sudo bash apply-harvester.sh
set -u
LEVEL="${LEVEL:-1}"
DRY_RUN="${DRY_RUN:-0}"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/harvester-hardening-backups/$TS"
mkdir -p "$BACKUP"
log() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a /tmp/harvester-hardening.log; }

OEM=""
for f in /oem/90_custom.yaml /oem/99_custom.yaml; do [ -f "$f" ] && OEM="$f" && break; done
[ -n "$OEM" ] || { log "ERROR: no /oem/*_custom.yaml found"; exit 2; }
cp -a "$OEM" "$BACKUP/$(basename "$OEM")"
echo "$OEM" > "$BACKUP/oem-path"

# Entries appended to the initramfs stage of the OEM cloud-init config.
SYSCTL_ENTRY=$(cat <<'EOF'
- path: /etc/sysctl.d/99-harvester.conf
  permissions: 600
  owner: 0
  group: 0
  content: |
    vm.panic_on_oom=0
    vm.overcommit_memory=1
    kernel.panic=10
    kernel.panic_on_oops=1
EOF
)
RKE2_ENTRY=$(cat <<'EOF'
- path: /etc/rancher/rke2/config.yaml.d/52-stig.yaml
  permissions: 600
  owner: 0
  group: 0
  content: |
    profile: cis-1.23
    use-service-account-credentials: true
    kube-controller-manager-arg:
    - "secure-port=10257"
    - "tls-min-version=VersionTLS12"
    - "tls-cipher-suites=TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
    kube-scheduler-arg:
    - "tls-min-version=VersionTLS12"
    kube-apiserver-arg:
    - "tls-min-version=VersionTLS12"
    - "authorization-mode=RBAC,Node"
    - "anonymous-auth=false"
    - "audit-policy-file=/etc/rancher/rke2/config.yaml.d/92-harvester-kube-audit-policy.yaml"
    - "audit-log-mode=blocking-strict"
    kubelet-arg:
    - "protect-kernel-defaults=true"
    pod-security-admission-config-file: /etc/rancher/rke2/config.yaml.d/51-rke2-pss-custom.yaml
EOF
)
PSA_ENTRY=$(cat <<'EOF'
- path: /etc/rancher/rke2/config.yaml.d/51-rke2-pss-custom.yaml
  permissions: 600
  owner: 0
  group: 0
  content: |
    apiVersion: apiserver.config.k8s.io/v1
    kind: AdmissionConfiguration
    plugins:
    - name: PodSecurity
      configuration:
        apiVersion: pod-security.admission.config.k8s.io/v1
        kind: PodSecurityConfiguration
        defaults:
          enforce: "restricted"
          enforce-version: "latest"
        exemptions:
          namespaces: [harvester-system, harvester-public, kube-system, kube-public, kube-node-lease, longhorn-system, cattle-system]
EOF
)
AUDIT_ENTRY=$(cat <<'EOF'
- path: /etc/rancher/rke2/config.yaml.d/92-harvester-kube-audit-policy.yaml
  permissions: 600
  owner: 0
  group: 0
  content: |
    apiVersion: audit.k8s.io/v1
    kind: Policy
    omitStages: ["ResponseStarted", "ResponseComplete"]
    rules:
    - level: Metadata
      resources:
      - group: ""
        resources: ["secrets"]
    - level: RequestResponse
      resources:
      - group: ""
        resources: ["*"]
EOF
)
COMMAND_ENTRIES=$(cat <<'EOF'
- /usr/sbin/groupadd etcd 2>/dev/null || true
- /usr/sbin/useradd -r -c "etcd user" -G etcd -s /sbin/nologin -M etcd 2>/dev/null || true
- /sbin/sysctl -p /etc/sysctl.d/99-harvester.conf 2>/dev/null || true
EOF
)

export OEM BACKUP DRY_RUN TS
export SYSCTL_ENTRY RKE2_ENTRY PSA_ENTRY AUDIT_ENTRY COMMAND_ENTRIES
python3 - <<'PY'
import os
path = os.environ['OEM']
text = open(path, encoding='utf-8').read()

def insert(text, key, entry):
    lines = text.splitlines()
    idx = None
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith('initramfs:') or s.startswith('- initramfs:'):
            base = len(line) - len(line.lstrip())
            for j in range(i + 1, len(lines)):
                if lines[j].strip() == key + ':':
                    idx = j
                    break
            break
    if idx is None:
        raise SystemExit('section not found: ' + key)
    ind = len(lines[idx]) - len(lines[idx].lstrip())
    end = idx + 1
    while end < len(lines):
        s = lines[end]
        if not s.strip():
            end += 1
            continue
        cur = len(s) - len(s.lstrip())
        if cur <= ind and not s.lstrip().startswith('-'):
            break
        end += 1
    prefix = ' ' * (ind + 2)
    block = [prefix + ln if ln.strip() else '' for ln in entry.rstrip('\n').splitlines()]
    return '\n'.join(lines[:end] + block + lines[end:]) + '\n'

for name in ('SYSCTL_ENTRY', 'RKE2_ENTRY', 'PSA_ENTRY', 'AUDIT_ENTRY'):
    e = os.environ[name]
    marker = [ln for ln in e.splitlines() if ln.startswith('- path: ')][0].split('path: ')[1]
    if marker in text:
        print('IDEMPOTENT already in OEM:', marker)
        continue
    text = insert(text, 'files', e)
    print('ADDED to OEM:', marker)
marker = 'protect-kernel-defaults=true'
if marker not in text:
    text = insert(text, 'commands', os.environ['COMMAND_ENTRIES'])
    print('ADDED commands to OEM')
if os.environ['DRY_RUN'] == '1':
    print('DRY RUN: no OEM write')
else:
    open(path, 'w', encoding='utf-8').write(text)
    print('WROTE', path)
PY

if [ "$DRY_RUN" = "1" ]; then log "DRY RUN complete"; exit 0; fi

# Apply the same files at runtime so the node is hardened before reboot.
mkdir -p /etc/sysctl.d /etc/rancher/rke2/config.yaml.d
printf '%s\n' 'vm.panic_on_oom=0' 'vm.overcommit_memory=1' 'kernel.panic=10' 'kernel.panic_on_oops=1' > /etc/sysctl.d/99-harvester.conf
chmod 600 /etc/sysctl.d/99-harvester.conf
printf '%s\n' "$RKE2_ENTRY" | sed -n '/content: |/,$p' | tail -n +2 | sed 's/^    //' > /etc/rancher/rke2/config.yaml.d/52-stig.yaml
printf '%s\n' "$PSA_ENTRY" | sed -n '/content: |/,$p' | tail -n +2 | sed 's/^    //' > /etc/rancher/rke2/config.yaml.d/51-rke2-pss-custom.yaml
printf '%s\n' "$AUDIT_ENTRY" | sed -n '/content: |/,$p' | tail -n +2 | sed 's/^    //' > /etc/rancher/rke2/config.yaml.d/92-harvester-kube-audit-policy.yaml
chmod 600 /etc/rancher/rke2/config.yaml.d/*.yaml
/sbin/sysctl -p /etc/sysctl.d/99-harvester.conf 2>/dev/null || true
/usr/sbin/groupadd etcd 2>/dev/null || true
/usr/sbin/useradd -r -c "etcd user" -G etcd -s /sbin/nologin -M etcd 2>/dev/null || true

if [ "$LEVEL" -ge 2 ]; then
  mkdir -p /etc/ssh/sshd_config.d
  cat > /etc/ssh/sshd_config.d/00-harvester-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
HostKeyAlgorithms ssh-ed25519,rsa-sha2-512,rsa-sha2-256
KexAlgorithms curve25519-sha256,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MaxAuthTries 3
EOF
  chmod 600 /etc/ssh/sshd_config.d/00-harvester-hardening.conf
  if sshd -t >/dev/null 2>&1; then systemctl reload sshd 2>/dev/null || true
  else log "ERROR: sshd -t failed, removing drop-in"; rm -f /etc/ssh/sshd_config.d/00-harvester-hardening.conf; exit 4; fi
fi

cat > /root/rollback-harvester-hardening.sh <<EOF
#!/bin/bash
cp -a "$BACKUP/$(basename "$OEM")" "$OEM"
rm -f /etc/sysctl.d/99-harvester.conf /etc/rancher/rke2/config.yaml.d/{52-stig,51-rke2-pss-custom,92-harvester-kube-audit-policy}.yaml /etc/ssh/sshd_config.d/00-harvester-hardening.conf
sysctl --system >/dev/null 2>&1 || true
echo rollback done
EOF
chmod 700 /root/rollback-harvester-hardening.sh
log "DONE LEVEL=$LEVEL (reboot required for OEM persistence)"
