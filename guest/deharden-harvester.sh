#!/bin/bash
# Restores the pre-hardening state of a Harvester node.
# Usage: sudo bash deharden-harvester.sh [--dry-run] [--report FILE]
set -u
DRY=0; REPORT=""
while [ $# -gt 0 ]; do
  case "$1" in --dry-run) DRY=1 ;; --report) REPORT="${2:-/tmp/hv-deharden.md}"; shift ;; esac
  shift
done
ROOT=/root/harvester-hardening-backups
[ -d "$ROOT" ] || { echo "ERROR: no backup dir $ROOT"; exit 3; }
TS="$(date +%Y%m%d-%H%M%S)"; SAFE="/root/hv-deharden-safety-$TS"; mkdir -p "$SAFE"
[ "$DRY" = 1 ] || { [ -f /oem/90_custom.yaml ] && cp -a /oem/90_custom.yaml "$SAFE/90_custom.yaml" || true; }
log() { printf '%s\n' "$*" | tee -a "$SAFE/log.txt"; }
log "=== Harvester de-hardening DRY=$DRY ==="

BEST=""
for d in "$ROOT"/*; do [ -f "$d/oem-path" ] && { BEST="$d"; break; }; done
[ -n "$BEST" ] || { echo "ERROR: no hardening session found"; exit 3; }
OEM="$(cat "$BEST/oem-path")"
SRC="$BEST/$(basename "$OEM")"
log "RESTORE $OEM <- $SRC"
[ "$DRY" = 1 ] || cp -a "$SRC" "$OEM"

for f in /etc/sysctl.d/99-harvester.conf \
  /etc/rancher/rke2/config.yaml.d/52-stig.yaml \
  /etc/rancher/rke2/audit-policy.yaml \
  /etc/rancher/rke2/config.yaml.d/51-rke2-pss-custom.yaml \
  /etc/rancher/rke2/config.yaml.d/92-harvester-kube-audit-policy.yaml \
  /etc/ssh/sshd_config.d/00-harvester-hardening.conf; do
  log "REMOVE $f"; [ "$DRY" = 1 ] || rm -f "$f"
done
if [ -f /tmp/hv-lab-key.pub ]; then
  for ak in /home/rancher/.ssh/authorized_keys /root/.ssh/authorized_keys; do
    [ -f "$ak" ] || continue
    log "REMOVE lab key from $ak"
    if [ "$DRY" = 1 ]; then continue; fi
    grep -vF "$(cat /tmp/hv-lab-key.pub)" "$ak" > "$ak.new" && mv "$ak.new" "$ak"
    chmod 600 "$ak"
  done
fi
log "sysctl --system"; [ "$DRY" = 1 ] || sysctl --system >/dev/null 2>&1 || true
if sshd -t >/dev/null 2>&1; then log "reload sshd"; [ "$DRY" = 1 ] || systemctl reload sshd 2>/dev/null || true; fi
log "NOTE: a reboot is required for the immutable OEM config to take effect"

if [ -n "$REPORT" ]; then
  { echo "# Harvester de-hardening"; echo; echo "- date: $(date -u +%FT%TZ)"; echo "- host: $(hostname)"; echo "- mode: $([ "$DRY" = 1 ] && echo dry-run || echo applied)"; echo "- restored: $OEM"; echo "- safety: $SAFE"; } > "$REPORT"
fi
log "=== END ==="
