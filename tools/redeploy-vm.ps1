# Clean redeployment of the harvester VM: new empty disk, ISO attached, EFI,
# autoinstall kernel parameters. Run with the VM powered off.
$ErrorActionPreference = "Stop"
$vb = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
$vm = "harvester"
$dir = "C:\Users\Louis\VirtualBox VMs\harvester"
$iso = "C:\Users\Louis\Downloads\harvester-v1.10.0-rc3-amd64.iso"
$vdi = "$dir\harvester-new.vdi"

# Stop and remove snapshots.
& $vb controlvm $vm poweroff 2>$null | Out-Null
Start-Sleep -Seconds 3
$snaps = & $vb snapshot $vm list --machinereadable 2>$null | Select-String '^SnapshotUUID=' | ForEach-Object { ($_ -split '=')[1].Trim('"') }
foreach ($s in $snaps) { Write-Output "deleting snapshot $s"; & $vb snapshot $vm delete $s 2>&1 | Out-Null }

# Detach old disk from SATA, create a fresh 300 GB dynamic VDI.
& $vb storageattach $vm --storagectl SATA --port 0 --device 0 --type hdd --medium none 2>&1 | Out-Null
if (Test-Path $vdi) { Remove-Item $vdi -Force }
& $vb createmedium disk --filename $vdi --size 307200 --format VDI --variant Standard 2>&1 | Out-String
& $vb storageattach $vm --storagectl SATA --port 0 --device 0 --type hdd --medium $vdi 2>&1 | Out-String

# Attach ISO on IDE, boot from DVD.
& $vb storageattach $vm --storagectl IDE --port 0 --device 0 --type dvddrive --medium $iso 2>&1 | Out-String
& $vb modifyvm $vm --firmware efi --memory 24576 --cpus 8 --boot1 dvd --boot2 disk --boot3 none --boot4 none 2>&1 | Out-Null
Remove-Item "$dir\harvester.nvram" -Force -ErrorAction SilentlyContinue

# Autoinstall kernel parameters through the extra data / kernel boot args.
# Harvester ISO: extra kernel args are read from the "harvester.install.*" boot
# parameters. We use VBoxManage to inject them into the EFI boot line via
# the VM's "BootOrder" + a serial console; the config URL is passed with the
# standard kernel parameter using modifyvm's --... (not available) -> we'll
# use the interactive boot editor instead (see README).
Write-Output "VM prepared: fresh disk + ISO attached + EFI/24GB/8CPU."
& $vb showvminfo $vm --machinereadable 2>&1 | Select-String 'memory=|cpus=|firmware=|boot1|SATA-0-0|IDE-0-0' | ForEach-Object { $_.Line }
