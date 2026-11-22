"""Automate the GRUB boot-line edit in the Harvester ISO to start autoinstall.

The Harvester ISO boots with GRUB. At the menu, pressing 'e' opens the boot
line editor. We send the keystrokes through VBoxManage, append the
harvester.install.* kernel parameters, then boot with F10/Ctrl-X.

Sequence of scancodes is tuned for the standard GRUB menu of COS_LIVE ISOs.
"""
import subprocess, time, sys

VBOX = r"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
VM = "harvester"

# scancodes: e=0x12, End=0x4f, Ctrl-X=0x1d 0x2d 0xae 0x9c, space=0x39
# Text to append (ASCII -> scancode map for lowercase, '=', '.', ':', '/', '-')
SCAN = {
    'a':0x1e,'b':0x30,'c':0x2e,'d':0x20,'e':0x12,'f':0x21,'g':0x22,'h':0x23,
    'i':0x17,'j':0x24,'k':0x25,'l':0x26,'m':0x32,'n':0x31,'o':0x18,'p':0x19,
    'q':0x10,'r':0x13,'s':0x1f,'t':0x14,'u':0x16,'v':0x2f,'w':0x11,'x':0x2d,
    'y':0x2c,'z':0x2a,'0':0x0b,'1':0x02,'2':0x03,'3':0x04,'4':0x05,'5':0x06,
    '6':0x07,'7':0x08,'8':0x09,'9':0x0a,'=':0x0d,'.':0x34,'/':0x35,'-':0x0c,
    ':':0x27,'_':0x0d,' ':0x39,'t':0x14,'r':0x13,'u':0x16,'e':0x12,
}
SHIFT = {'=':'+', ':':';', '_':'_'}

def key(ch, shift=False):
    if ch not in SCAN:
        return []
    s = SCAN[ch]
    codes = []
    if shift:
        codes.append(0x2a)  # LShift down
    codes.append(s)
    if shift:
        codes.append(0xaa)  # LShift up
    return codes

def text(t):
    out = []
    for ch in t:
        out += key(ch, ch in "=:_")
    return out

def send(codes):
    if not codes:
        return
    hexs = ' '.join(f'{c:02x}' for c in codes)
    subprocess.run([VBOX, 'controlvm', VM, 'keyboardputscancode', hexs], capture_output=True)

def wait(sec):
    time.sleep(sec)

def main():
    # 1. Wait for GRUB menu (boot from ISO)
    print("Waiting for GRUB menu...", flush=True)
    wait(int(sys.argv[1]) if len(sys.argv) > 1 else 45)

    # 2. Press 'e' to edit the first entry
    send([0x12])  # e
    wait(2)

    # 3. Go to end of the linux line
    send([0x4f])  # End
    wait(1)

    # 4. Append autoinstall parameters
    params = " harvester.install.automatic=true harvester.install.config_url=http://10.0.2.2:8000/config-create.yaml"
    send(text(params))
    wait(2)

    # 5. Boot with Ctrl-X
    send([0x1d, 0x2d, 0xae, 0x9c])
    print("Booted with autoinstall parameters", flush=True)

if __name__ == "__main__":
    main()
