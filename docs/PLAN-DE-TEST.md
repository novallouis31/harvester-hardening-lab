# Plan de test — Harvester Hardening Lab

Méthode identique aux labs `pve9-hardening-lab` et `xcp-ng-hardening-lab` :
**mesurer → durcir → mesurer → vérifier la réversibilité → monter de version**.

## 1. Plateforme

| Élément | Valeur |
| --- | --- |
| VM | `harvester`, EFI, 24 Go RAM, 8 vCPU, VDI 300 Go |
| Version | Harvester **v1.10.0-rc3** (RKE2 `v1.36.6+rke2r1`, noyau `6.12.0-160000.41-default`) |
| Réseau | NAT VirtualBox, management `enp0s3` en DHCP |
| Accès | SSH `rancher` (identifiants dans `.local/credentials.txt`, non versionné), clé `.keys/id_ed25519` |
| Snapshot | `pristine` pris juste après l'installation, avant tout durcissement |

Déploiement bare-metal : voir `docs/DEPLOIEMENT-PXE.md`.

## 2. Chaîne de validation

| # | Étape | Commande | Critère |
| --- | --- | --- | --- |
| 1 | Baseline | `python scripts/hv.py run --phase baseline` | état d'origine mesuré, 5 PASS / 5 FAIL |
| 2 | Dry-run durcissement | `python scripts/hv.py harden --level 2 --dry-run` | aucune écriture, liste des changements |
| 3 | Durcissement | `python scripts/hv.py harden --level 2` | `/oem/90_custom.yaml` écrit, redémarrage RKE2 |
| 4 | Verify | `python scripts/hv.py run --phase verify` | **19 PASS / 0 FAIL / 6 NA**, 12/12 tests fonctionnels |
| 5 | Rapport | `python scripts/hv.py report --title "Harvester L2" --dirs … --pdf` | Markdown + HTML + PDF |
| 6 | Dry-run dé-hardening | `python scripts/hv.py deharden --dry-run` | aucune écriture |
| 7 | Dé-hardening | `python scripts/hv.py deharden` | fichiers OEM et SSH restaurés (reboot requis) |
| 8 | Upgrade / redéploiement | `docs/UPGRADE-PLAN.md`, `docs/REDEPLOY-PLAN.md` | nouvel état de référence |

## 3. Familles de contrôles

| Famille | Niveau | Contrôles clés |
| --- | --- | --- |
| RKE2 CIS | L1+L2 | profil `cis`, `--tls-cipher-suites`, `protect-kernel-defaults`, audit policy |
| Pod Security | L1 | Pod Security Admission (`restricted`) |
| Audit | L1 | `/etc/rancher/rke2/audit-policy.yaml` hors de `config.yaml.d/` |
| Système | L1+L2 | sysctl persistants via `/oem/90_custom.yaml`, `vm.panic_on_oom`, `kernel.panic` |
| Comptes | L1 | compte `etcd`, `PermitRootLogin prohibit-password` |
| SSH | L2 | `PasswordAuthentication no`, clé ED25519 du lab |
| Réseau | L1 | pare-feu, désactivation de `rpcbind` si présent |

Les contrôles non applicables en mono-nœud NAT sont marqués **NA** (pas FAIL).

## 4. Tests de non-régression (`guest/func-test-harvester.sh`)

12 tests : accès SSH par clé, nœud `Ready`, composants `fleet-local/local` et
RKE2 actifs, réponse de l'API Harvester, résolution DNS, montage Longhorn,
accès UI HTTPS, absence d'unités en échec.

## 5. Résultats

Voir `docs/RESULTS-v1.10.md` et `reports/report-harvester-v1.10-l2.md`
(également disponibles en PDF). La tentative d'upgrade v1.9.1 → v1.10.0-rc3
bloquée par un cluster CAPI endommagé est documentée dans `docs/UPGRADE-PLAN.md` ;
le redéploiement propre qui l'a remplacée est dans `docs/REDEPLOY-PLAN.md`.
