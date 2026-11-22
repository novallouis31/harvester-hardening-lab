"""Verify the downloaded Harvester ISO against the official version.yaml checksum."""
import hashlib, sys, urllib.request, re
from pathlib import Path

ISO = Path(r"C:\Users\Louis\Downloads\harvester-v1.10.0-rc3-amd64.iso")
VERSION_URL = "https://releases.rancher.com/harvester/v1.10.0-rc3/version.yaml"


def main():
    version = urllib.request.urlopen(VERSION_URL, timeout=30).read().decode()
    expected = re.search(r"isoChecksum:\s*'([0-9a-f]+)'", version).group(1)
    print(f"size: {ISO.stat().st_size / (1024**3):.2f} GB", flush=True)
    h = hashlib.sha256()
    with ISO.open("rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    actual = h.hexdigest()
    print(f"expected: {expected}", flush=True)
    print(f"actual:   {actual}", flush=True)
    if actual != expected:
        print("MISMATCH - ISO is corrupt", flush=True)
        sys.exit(1)
    print("ISO checksum OK", flush=True)


if __name__ == "__main__":
    main()
