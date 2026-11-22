# Plan de redéploiement propre — Harvester v1.10.0-rc3

## Objectif

Repartir d'une installation saine (cluster CAPI/Fleet intact) pour pouvoir tester l'upgrade et rejouer le hardening.

## Étapes

### 1. ISO

- Télécharger `harvester-v1.10.0-rc3-amd64.iso` (8,5 Go) depuis `releases.rancher.com`.
- **Vérifier le SHA-256** : `90fe23255a25ef0a7caa9e9d5beb8413bc1646644ba8e0d7391634ea3aeb9b3cbb43932cde6aa39117ef42390a124ac91c6408add1c8b94ab657038a7bf076de`.
- ⚠️ Le téléchargement initial via `WebClient` était corrompu (checksum différent). Utiliser curl direct.

### 2. VM

- Arrêter la VM, supprimer les snapshots (`pre-hardening`, `pre-upgrade`).
- Nouveau VDI 300 Go, EFI, **24 Go RAM / 8 CPU** (important : le snapshot restaurait 5 Go/3 CPU).
- ISO attachée sur IDE, boot1=dvd.

### 3. Installation automatique

Deux options :

**A. Serveur HTTP + paramètres GRUB (retenu)** :
- Serveur Python `tools/serve-config.py` sur `10.0.2.2:8000` servant `docs/harvester-config.yaml`.
- Au boot de l'ISO, dans le menu GRUB, appuyer sur `e` pour éditer la ligne de boot et ajouter :
  `harvester.install.automatic=true harvester.install.config_url=http://10.0.2.2:8000/config-create.yaml`
  (le config contient `install.skipchecks=true`,hostname, mot de passe `<MOT_DE_PASSE_LAB>`, clé SSH, `replica_count: 1`).
- L'installation se fait sans interaction, puis la VM reboot sur le disque.

**B. Installation interactive** (fallback) :
- Même séquence que la première fois (Yes → Create a new cluster → password → disk → NIC) mais en v1.10.

### 4. Vérification post-install

- `python scripts/hv.py info` → Harvester v1.10.0-rc3, nœud Ready.
- `kubectl get clusters.cluster.x-k8s.io -A` → `fleet-local/local` présent (contrairement au cluster endommagé).
- `kubectl get bundles.fleet.cattle.io -A` → tous `1/1`.

### 5. Cycle hardening

- `python scripts/hv.py run --phase baseline`
- `python scripts/hv.py harden --level 2 --dry-run` puis réel
- `python scripts/hv.py run --phase verify`
- `python scripts/hv.py deharden --dry-run`

Le profil RKE2 `cis` (générique) et l'audit policy sont compatibles v1.36/v1.37.

## État

- [x] ISO en cours de téléchargement (vérification SHA-256 à faire)
- [x] Serveur de config HTTP prêt (`tools/serve-config.py`, testé HTTP 200)
- [x] Fichier `docs/harvester-config.yaml` prêt
- [ ] Redéploiement VM
- [ ] Installation
- [ ] Vérification cluster
- [ ] Cycle hardening
