# Research — Harvester hardening (20 novembre 2026)

## 1. Guide communautaire spécifique Harvester

**`bcdurden/harvester_hardening_beta`** — https://github.com/bcdurden/harvester_hardening_beta
2 étoiles, créé en mars 2024, explicitement marqué WIP. C'est le projet « récent / peu d'étoiles / spécifiquement Harvester » le plus probable.

Composants à durcir selon ce guide :
- **Elemental SLEMicro** : OS immuable, toute modification doit être persistée via `/oem/90_custom.yaml` (nommé `/oem/99_custom.yaml` sur les versions < 1.1.2) ou une ressource CloudInit CRD.
- **RKE2** : profil CIS (`profile: cis-1.23`, `cis-1.6` pour Harvester ≤ 1.1.x), `use-service-account-credentials`, arguments TLS 1.2+ pour kube-apiserver/kube-controller-manager/kube-scheduler, `authorization-mode=RBAC,Node`, `anonymous-auth=false`, audit policy, `protect-kernel-defaults`, PSA `restricted`.
- **Sysctl** : `vm.panic_on_oom=0`, `vm.overcommit_memory=1`, `kernel.panic=10`, `kernel.panic_on_oops=1`.
- **Longhorn** : encryption at rest avec une clé globale au minimum.
- Utilisateur `etcd` (groupe + compte système) créé dans la section `commands` du cloud-init pour éviter les race conditions.

Attention : le guide prévient qu'une erreur de indentation YAML peut empêcher le boot. Procédure de récupération : SSH `rancher@node`, console `rancher`, terminal alternatif Ctrl-Alt-F2, puis fallback `rancher`/`rancher` au init.

## 2. Projet SUSE peu connu : validation d'images durcies

**`SUSE-Enceladus/CaC-Tracking`** — https://github.com/SUSE-Enceladus/CaC-Tracking
GPL-3.0, outils de validation du hardening d'images SUSE cloud (testé seulement avec `suse:sles-sap-15-sp4-hardened:gen2:2023.08.28` sur Azure).

Méthode :
1. `oscap` avec le profil CIS Level 1 → `results/*-Initial-CiSL1.txt` ;
2. deux passes de remediation OpenSCAP (certains correctifs activent les suivants) ;
3. check final → `results/*-Post-Remed-CiSL1.txt` ;
4. `bin/compare-results` compare aux baselines `baseline/` et échoue sur toute différence.

Test effectué dans ce lab (hôte Windows, Git Bash) :
- clone dans `vendor/CaC-Tracking` ;
- normalisation CRLF (`sed -i 's/\r$//'`) sur `bin/*` et les fichiers `.txt` (le checkout Windows cassait le script) ;
- copie des baselines vers `results/` ;
- `bash bin/compare-results` → `INFO: Compare initial results to base line` / `INFO: Compare final results to base line`, code 0.

Limite : l'outil cible des images SLES classiques avec `oscap` installé. Harvester/SLEMicro est immuable et ne fournit pas `oscap` — l'idée réutilisable est surtout la **comparaison baseline vs post-remediation**, pas l'exécution directe d'`oscap` sur le nœud.

## 3. Autres références

- `bcdurden/terraform-harvester-rke2-hardened` (6 étoiles, 2023) : module Terraform pour un cluster RKE2 conforme STIG dans Harvester.
- Documentation Harvester « Update Harvester Configuration After Installation » (v1.6/v1.9) : fichier persistant `/oem/90_custom.yaml` depuis v1.1.2, CloudInit CRD préférable à l'édition manuelle.
- Rancher hardening guides / CIS benchmarks (RKE2, K3s) : source des paramètres Kubernetes.

## 4. Décision

La base de travail sera le guide `bcdurden/harvester_hardening_beta` (contrôles Harvester spécifiques), avec la **méthode de validation par baseline** de `CaC-Tracking`. Les tests openSCAP directs seront marqués N/A sur SLEMicro si l'outil n'est pas disponible, plutôt que simulés.
