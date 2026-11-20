# État de la VM VirtualBox `harvester`

- UUID : `b32df4be-3332-438f-820e-be7938a11a2a`
- OS type déclaré : openSUSE 64-bit, firmware initial BIOS, 3 vCPU, 4 GiB RAM.
- Disque initial : `harvester.vdi` 2 Mo (jamais installé).
- ISO attachée : `C:\Users\Louis\Downloads\harvester-v1.9.1-amd64.iso` (8,3 Go).
- NAT : règle `ssh,tcp,127.0.0.1,2224,,22` ajoutée.

## Actions effectuées

1. Snapshot `pristine` créé puis supprimé (il pointait sur un disque vide).
2. Firmware passé en **EFI** (nécessaire : en BIOS l'ISO affichait « No bootable medium found »).
3. Disque agrandi de 20 Go à **300 Go** (dynamic VDI) : l'installateur exigeait 250 Gi minimum.
4. Installation démarrée depuis l'ISO, avec validation des avertissements matériel (3 CPU / 4 Go / pas de /dev/kvm).
5. Mode « Create a new Harvester cluster » sélectionné, mot de passe `<MOT_DE_PASSE_LAB>` défini pour `rancher`.
6. Disque `sda 300G`, taille persistante `150Gi` acceptés.
7. NIC `enp0s3` cochée dans la page « Configure network » (la touche `Espace` après `Tab` fonctionne).

## Blocage actuel

L'installateur reste sur « Configure network » : `Entrée`, `Tab+Entrée` et multiples `Tab` ne font pas avancer vers la page suivante. Le port NAT 2224 répond mais aucun banner SSH n'est émis (système pas encore installé).

## Pour débloquer

- Terminer l'installation dans l'UI VirtualBox (console graphique), ou fournir une VM Harvester déjà installée avec les identifiants `rancher`.
- Une fois le système installé : reprendre le snapshot `pristine`, puis appliquer le workflow `pve.py`-like (audit baseline → apply → verify → deharden → upgrade).
