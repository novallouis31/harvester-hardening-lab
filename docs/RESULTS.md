# Résultats — Harvester 1.9.1 hardening

## Environnement

- VM VirtualBox `harvester`, passée de 3 vCPU / 4 Go à **8 vCPU / 16 Go** (Harvester exige 8 cœurs / 32 Go en production ; avec 3/4 Go le nœud était en `soft lockup` et bloquait au boot).
- Disque VDI 300 Go, EFI, ISO éjectée (boot sur disque).
- Compte `rancher` (mot de passe du lab **non versionné**, voir `.local/credentials.txt`), sudo sans mot de passe, clé ED25519 du lab installée au niveau 2.
- RKE2 `v1.36.6+rke2r1`, noyau `6.12.0-160000.40-default`.

## Cycle validé (21 novembre 2026)

| Étape | PASS | FAIL | NA | INFO | Tests PASS | Tests FAIL |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 5 | 5 | 3 | 4 | — | — |
| Hardened L2 (final) | **19** | **0** | **6** | 3 | **12/12** | 0 |

Contrôles appliqués :
- `/oem/90_custom.yaml` persistant : sysctl (`panic_on_oom`, `overcommit_memory`, `kernel.panic`, `panic_on_oops`), config RKE2 CIS `profile: "cis"`, audit policy `/etc/rancher/rke2/audit-policy.yaml`.
- Runtime : mêmes fichiers créés, compte `etcd` créé (`-g etcd`, car le groupe existe déjà), `sysctl -p`.
- Niveau 2 : clé SSH lab installée avant `PasswordAuthentication no` / `PermitRootLogin prohibit-password` avec `sshd -t` gate.

## Incidents rencontrés et corrigés

1. **SFTP indisponible** sur SLEMicro → transferts base64 via `exec`.
2. **`/root` non accessible à `rancher`** → scripts et clé passés par `/tmp` + `sudo`.
3. **`sudo` perdait `DRY_RUN`/`LEVEL`** → `sudo env ...`.
4. **Premier dry-run a écrit le OEM** → corrigé ; restauration puis nouveau dry-run vérifié (`DRY RUN: no OEM write`).
5. **`profile: cis-1.23` invalide sur RKE2 v1.36** → `profile: "cis"` (doc RKE2 v1.29+).
6. **PSA/audit dans `config.yaml.d/`** lus comme config RKE2 → audit policy déplacée vers `/etc/rancher/rke2/audit-policy.yaml`, PSA géré automatiquement par le profil `cis`.
7. **`useradd -G etcd` échouait** (groupe existant) → `-g etcd`.
8. **VM sous-dimensionnée** → 8 vCPU / 16 Go.
9. **Boot sur l'ISO** après reboot → boot1=disk, ISO éjectée.

Le dé-hardening a été validé en dry-run à chaque étape (restauration du OEM, suppression des fichiers créés, retrait de la clé lab, `sysctl --system`).

## Hors périmètre (déclaré N/A)

Longhorn encryption at rest (nécessite une clé via kubectl), réseaux séparés/VPN, physical/IPMI, et les contrôles TLS/cipher/PSA/account-credentials désormais gérés par le profil `cis` de RKE2.

Rapport de diff : `reports/report-harvester-l2-final.md`.

## Montée de version — tentative infructueuse

La montée v1.9.1 → v1.10.0-rc3 a été **tentée à trois reprises sans aboutir** :

1. Disque hôte saturé (0 Go libre) → `VERR_DISK_FULL`, VM suspendue.
2. Après libération de 96 Go : upgrade créé mais bloqué car la restauration du snapshot avait remis la VM à 5 Go RAM / 3 CPU (`containerd` ne démarrait pas). VM repassée à 24 Go / 8 CPU.
3. Le webhook Harvester refuse alors l'upgrade : `clusters.cluster.x-k8s.io "local" not found`. Le cluster CAPI `fleet-local/local` a disparu, bundles Fleet en `ErrApplied`, `capi-controller-manager` en boucle de redémarrage.

**État final : Harvester v1.9.1**, upgrade non effectué, cluster structurellement endommagé. Le durcissement L2 reste la dernière configuration validée (19 PASS / 0 FAIL, 12/12 tests). Voir `docs/UPGRADE-PLAN.md` pour le journal détaillé et la recommandation de redéploiement.
