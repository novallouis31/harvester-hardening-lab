# Déploiement Harvester v1.10 par PXE / iPXE (bare-metal)

Lab validé sur VirtualBox (VM EFI 24 Go / 8 CPU), mais le chemin de déploiement
est le même sur serveur physique : **iPXE + serveur HTTP** servant le noyau,
l'initrd, le rootfs squashfs et le fichier de configuration Harvester.

Sources officielles :
<https://docs.harvesterhci.io/v1.10/install/pxe-boot-install/>.

> ⚠️ Depuis v1.8.0, le boot PXE en **legacy BIOS échoue** : UEFI est obligatoire.
> Chaque nœud doit avoir au moins **8 Gio de RAM** (l'ISO est chargée en tmpfs).
> Le DHCP **doit** fournir l'option `routers`, sinon le nœud ne démarre pas.

## 1. Principe

```
Client UEFI
   |  DHCP (option 66/67) -> ipxe.efi (via HTTP/TFTP)
   v
iPXE script (ipxe-create / ipxe-join)
   |  kernel harvester-vmlinuz ... root=live:http://…/rootfs.squashfs
   |  harvester.install.automatic=true
   |  harvester.install.config_url=http://…/config-create.yaml
   v
Installation automatique (CREATE ou JOIN) ---> reboot ---> cycle de hardening
```

## 2. Fichiers à servir (HTTP)

Pour la version `v1.10.0-rc3`, télécharger depuis `releases.rancher.com` :

| Fichier | Rôle |
| --- | --- |
| `harvester-v1.10.0-rc3-vmlinuz-amd64` | noyau installateur |
| `harvester-v1.10.0-rc3-initrd-amd64` | initrd |
| `harvester-v1.10.0-rc3-rootfs-amd64.squashfs` | rootfs live (chargé en tmpfs) |
| `harvester-v1.10.0-rc3-amd64.iso` | source de l'installation (`iso_url`) |
| `config-create.yaml`, `config-join.yaml` | configuration (voir `pxe/`) |
| `ipxe-create`, `ipxe-join` | scripts iPXE |
| `ipxe.efi` | programme iPXE UEFI (`http://boot.ipxe.org/x86_64-efi/ipxe.efi`) |

Exemple d'arborescence NGINX : `/usr/share/nginx/html/harvester/`.

## 3. Configuration CREATE (`pxe/config-create.yaml`)

```yaml
scheme_version: 1
token: <TOKEN_CLUSTER>                 # remplacer ; jamais de secret réel
os:
  hostname: harvester-lab
  ssh_authorized_keys:
    - ssh-ed25519 AAAA... lab
  password: <MOT_DE_PASSE_LAB>         # injecté par un secret, non commité
  ntp_servers:
    - 0.suse.pool.ntp.org
install:
  mode: create
  automatic: true
  skipchecks: true                     # utile sur VM de lab (< requis prod)
  management_interface:
    interfaces:
      - name: enp0s3
    default_route: true
    method: dhcp
  device: /dev/sda
  iso_url: http://10.0.0.10/harvester/harvester-v1.10.0-rc3-amd64.iso
  vip_mode: dhcp
```

> Le mot de passe et le token **ne sont jamais versionnés** : les fichiers fournis
> contiennent des placeholders. Servir le fichier via un serveur qui injecte les
> secrets à la volée (ou monter un fichier local non commité).

## 4. Script iPXE CREATE (`pxe/ipxe-create`)

```
#!ipxe
kernel harvester-v1.10.0-rc3-vmlinuz initrd=harvester-v1.10.0-rc3-initrd ip=dhcp \
  net.ifnames=1 rd.cos.disable rd.noverifyssl console=tty1 \
  root=live:http://10.0.0.10/harvester/harvester-v1.10.0-rc3-rootfs-amd64.squashfs \
  harvester.install.automatic=true \
  harvester.install.config_url=http://10.0.0.10/harvester/config-create.yaml
initrd harvester-v1.10.0-rc3-initrd
boot
```

Le paramètre `initrd=<nom>` est **obligatoire en UEFI**. Pour une console série :
`console=ttyS0,115200n8` et `harvester.install.tty=ttyS0`.

Le mode JOIN (`pxe/config-join.yaml`, `pxe/ipxe-join`) utilise `mode: join`,
`server_url: https://<VIP>:443` et le même token que le cluster CREATE.

## 5. DHCP (extrait `pxe/dnsmasq.conf`)

```
dhcp-range=10.0.0.100,10.0.0.200,12h
dhcp-option=option:router,10.0.0.10     # OBLIGatoire : route par defaut
dhcp-option=option:dns-server,10.0.0.1

# user-class=iPXE -> le script HTTP ; sinon -> ipxe.efi (UEFI)
dhcp-match=set:ipxe,175
dhcp-match=set:uefi,option:client-arch,7
dhcp-boot=tag:ipxe,http://10.0.0.10/harvester/ipxe-create
dhcp-boot=tag:!ipxe,tag:uefi,http://10.0.0.10/harvester/ipxe.efi
```

L'URL de l'answer file peut aussi être passée en paramètre noyau :
`harvester.install.config_url=…` (prioritaire sur le fichier).

## 6. Test sur VirtualBox (simulation)

1. Réseau interne `intnet` partagé entre la VM Harvester et une VM serveur
   (dnsmasq + NGINX/`python -m http.server`).
2. Firmware **EFI obligatoire** : `VBoxManage modifyvm harvester --firmware efi`.
3. Démarrer en `headless` et capturer l'écran pour vérifier le menu iPXE ;
   le serveur HTTP doit journaliser les `GET /harvester/vmlinuz`, `initrd`,
   `rootfs.squashfs` et `config-create.yaml`.
4. `harvester.install.skipchecks=true` est déjà positionné dans l'exemple pour
   tolérer une VM de lab en dessous des prérequis production.

Note : l'installation interactive manuelle (sans iPXE) reste documentée dans
`docs/REDEPLOY-PLAN.md` ; elle a été utilisée pour le redéploiement v1.10.0-rc3.

## 7. Après installation

```bash
python scripts/hv.py info
python scripts/hv.py snapshot take pristine
python scripts/hv.py run --phase all --level 2
python scripts/hv.py report --title "Harvester L2" --dirs artifacts/<baseline> artifacts/<verify> --pdf
```

## Fichiers fournis

| Fichier | Rôle |
| --- | --- |
| `pxe/config-create.yaml` | config CREATE (premier nœud) |
| `pxe/config-join.yaml` | config JOIN (nœuds suivants) |
| `pxe/ipxe-create` | script iPXE CREATE |
| `pxe/ipxe-join` | script iPXE JOIN |
| `pxe/dnsmasq.conf` | extrait DHCP + iPXE UEFI |
