#!/usr/bin/env python3
"""Harvester hardening lab orchestrator (host side)."""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import paramiko

ROOT = Path(__file__).resolve().parents[1]
VBOX = Path(r"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe")
CFG = json.loads((ROOT / "vm-config.json").read_text(encoding="utf-8"))
ART = ROOT / "artifacts"


def creds() -> tuple[str, str]:
    path = ROOT / ".local" / "credentials.txt"
    out = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.startswith("#"):
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip()
    return CFG["ssh"]["user"], out.get("password", "password")


class SSH:
    def __init__(self) -> None:
        self.host, self.port, self.user = CFG["ssh"]["host"], int(CFG["ssh"]["port"]), CFG["ssh"]["user"]
        _, self.password = creds()
        self.key = ROOT / ".keys" / "id_ed25519"
        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    def __enter__(self):
        for _ in range(8):
            attempts = []
            if self.key.exists():
                attempts.append({"key_filename": str(self.key)})
            attempts.append({"password": self.password})
            for a in attempts:
                try:
                    self.client.connect(self.host, self.port, self.user, timeout=8,
                                        look_for_keys=False, allow_agent=False, **a)
                    return self
                except Exception:
                    continue
            time.sleep(4)
        raise RuntimeError("SSH authentication failed")

    def __exit__(self, *exc):
        self.client.close()

    def exec(self, cmd: str, timeout: int = 900):
        _, out, err = self.client.exec_command(cmd, timeout=timeout)
        rc = out.channel.recv_exit_status()
        return rc, out.read().decode("utf-8", "replace"), err.read().decode("utf-8", "replace")

    def put(self, local: Path, remote: str, mode=0o700):
        """SFTP is not always available on SLEMicro: transfer via base64 over exec."""
        import base64
        data = base64.b64encode(local.read_bytes()).decode("ascii")
        rc, out, err = self.exec(f"printf '%s' '{data}' | base64 -d > {remote} && chmod {mode:o} {remote}")
        if rc:
            raise RuntimeError(f"upload failed: {err[-500:]}")

    def get(self, remote: str, local: Path):
        import base64
        rc, out, err = self.exec(f"sudo base64 {remote}")
        if rc:
            raise RuntimeError(f"download failed: {err[-500:]}")
        local.write_bytes(base64.b64decode("".join(out.split())))


def vbox(*args: str) -> str:
    r = subprocess.run([str(VBOX), *args], capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stderr.strip())
    return r.stdout.strip()


def upload(ssh: SSH):
    for name in CFG["guest_scripts"].values():
        ssh.put(ROOT / "guest" / name, "/tmp/hv-lab-" + name, 0o700)


def stamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def audit(ssh: SSH, label: str, func: bool = True) -> Path:
    out = ART / f"{label}-{stamp()}"
    out.mkdir(parents=True, exist_ok=True)
    upload(ssh)
    ssh.exec(f"sudo bash /tmp/hv-lab-audit-harvester.sh /tmp/hv-audit-{label}")
    ssh.get(f"/tmp/hv-audit-{label}/audit.txt", out / "audit.txt")
    ssh.get(f"/tmp/hv-audit-{label}/checks.tsv", out / "checks.tsv")
    if func:
        ssh.exec(f"sudo bash /tmp/hv-lab-func-test-harvester.sh /tmp/hv-func-{label}")
        ssh.get(f"/tmp/hv-func-{label}/fonctionnel.txt", out / "fonctionnel.txt")
    print(f"[{label}] {out}")
    return out


def apply(ssh: SSH, level: int, dry: bool):
    upload(ssh)
    key = ROOT / ".keys" / "id_ed25519.pub"
    if key.exists():
        ssh.put(key, "/root/hv-lab-key.pub", 0o600)
    env = f"LEVEL={level} DRY_RUN={'1' if dry else '0'}"
    rc, o, e = ssh.exec(f"{env} sudo bash /tmp/hv-lab-apply-harvester.sh", timeout=1800)
    print(o)
    if e.strip():
        print("stderr:", e[-1000:])
    if rc:
        raise RuntimeError(f"apply failed rc={rc}")


def deharden(ssh: SSH, dry: bool):
    upload(ssh)
    flag = " --dry-run" if dry else ""
    rc, o, e = ssh.exec(f"sudo bash /tmp/hv-lab-deharden-harvester.sh{flag} --report /tmp/hv-deharden.md", timeout=1800)
    print(o)
    if rc:
        raise RuntimeError(f"deharden failed rc={rc}")


def parse(path: Path) -> dict[str, tuple[str, str]]:
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        p = line.split("\t")
        if len(p) >= 3:
            out[p[0]] = (p[1], p[2])
        elif line.startswith("@@CHECK ") or line.startswith("@@TEST "):
            q = line.split(maxsplit=3)
            if len(q) >= 4:
                out[q[1]] = (q[2], q[3])
    return out


def report(dirs: list[Path], title: str) -> Path:
    a, b = parse(dirs[0] / "checks.tsv"), parse(dirs[-1] / "checks.tsv")
    fa, fb = parse(dirs[0] / "fonctionnel.txt"), parse(dirs[-1] / "fonctionnel.txt")
    lines = [f"# {title}", "", "| ID | Before | After | Detail |", "| --- | --- | --- | --- |"]
    for k in sorted(set(a) | set(b)):
        lines.append(f"| {k} | {a.get(k, ('MISSING',''))[0]} | {b.get(k, ('MISSING',''))[0]} | {b.get(k, a.get(k, ('','')))[1]} |")
    lines += ["", "## Functional", "| ID | Before | After |", "| --- | --- | --- |"]
    for k in sorted(set(fa) | set(fb)):
        lines.append(f"| {k} | {fa.get(k, ('MISSING',''))[0]} | {fb.get(k, ('MISSING',''))[0]} |")
    out = ROOT / "reports" / f"report-{title.lower().replace(' ', '-')}.md"
    out.parent.mkdir(exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(out)
    return out


def main():
    p = argparse.ArgumentParser(prog="hv.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("info")
    sp = sub.add_parser("snapshot"); sp.add_argument("action", choices=["list", "take", "restore"]); sp.add_argument("--name", default="")
    sr = sub.add_parser("run"); sr.add_argument("--phase", choices=["baseline", "apply", "verify", "all"], default="all"); sr.add_argument("--level", type=int, default=1); sr.add_argument("--no-func", action="store_true")
    sh = sub.add_parser("harden"); sh.add_argument("--level", type=int, default=1); sh.add_argument("--dry-run", action="store_true")
    sd = sub.add_parser("deharden"); sd.add_argument("--dry-run", action="store_true")
    rp = sub.add_parser("report"); rp.add_argument("--title", default="Harvester hardening"); rp.add_argument("--dirs", nargs="+", required=True)
    args = p.parse_args()

    if args.cmd == "snapshot":
        if args.action == "list":
            print(vbox("snapshot", CFG["vm_name"], "list"))
        elif args.action == "take":
            print(vbox("snapshot", CFG["vm_name"], "take", args.name or "snapshot"))
        else:
            print(vbox("snapshot", CFG["vm_name"], "restore", args.name))
        return
    if args.cmd == "report":
        report([Path(d if d.startswith("/") or d.startswith("C:") else str(ROOT / d)) for d in args.dirs], args.title)
        return
    with SSH() as ssh:
        if args.cmd == "info":
            rc, o, e = ssh.exec("hostname; cat /etc/os-release | head -3; kubectl get nodes -o wide 2>/dev/null | head -4")
            print(o)
            return
        if args.cmd == "harden":
            apply(ssh, args.level, args.dry_run)
            return
        if args.cmd == "deharden":
            deharden(ssh, args.dry_run)
            return
        f = not args.no_func
        if args.phase in ("baseline", "all"):
            audit(ssh, "baseline", f)
        if args.phase in ("apply", "all"):
            apply(ssh, args.level, False)
        if args.phase in ("verify", "all"):
            audit(ssh, "verify", f)


if __name__ == "__main__":
    main()
