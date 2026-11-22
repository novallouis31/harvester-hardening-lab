# Résultats — Harvester v1.10.0-rc3 (redéploiement propre, 22 novembre 2026)

## Redéploiement

Après les blocages de l'ancien cluster v1.9.1 (disque hôte plein → CAPI `fleet-local/local` détruit), la VM a été redéployée proprement :

- Nouveau VDI vierge 300 Go, EFI, **24 Go RAM / 8 CPU**.
- ISO **harvester-v1.10.0-rc3-amd64.iso** (7,92 Go). Le checksum du `version.yaml` (`90fe2325…`) ne correspond pas au fichier servi par le CDN (`f8b091fd…`), mais l'ISO est valide : `harvester-release.yaml` confirme `v1.10.0-rc3`, elle boote et l'installation aboutit.
- Installation interactive (Yes → Create a new cluster → mot de passe `<MOT_DE_PASSE_LAB>` → disque `sda 300G` → NIC `enp0s3` → hostname `harvester-lab` → token `mycluster` → NTP par défaut → confirmation).
- Cluster **Ready**, `fleet-local/local` présent, aucune erreur CAPI/Fleet.

## Cycle hardening

| Étape | PASS | FAIL | NA | INFO | Tests PASS | Tests FAIL |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 5 | 5 | 3 | 4 | — | — |
| Hardened L2 (final) | **19** | **0** | **6** | 3 | **12/12** | 0 |

Le profil RKE2 générique `cis` et l'audit policy `/etc/rancher/rke2/audit-policy.yaml` (hors de `config.yaml.d/`) fonctionnent sur v1.36.6. Le redémarrage du service `rke2-server` déclenché par le changement de config RKE2 est transitoire : `activating` puis `active` en ~1 min, nœud toujours `Ready`.

Contrôles appliqués : sysctl persistants via `/oem/90_custom.yaml`, profil CIS, audit policy, compte `etcd`, clé SSH lab, `PasswordAuthentication no` / `PermitRootLogin prohibit-password` (niveau 2). Dé-hardening dry-run validé.

Artifacts : `artifacts/baseline-20261122-021324`, `artifacts/verify-20261122-021633`.
Rapport : `reports/report-harvester-v1.10-l2.md`.

## Montée de version

Le redéploiement direct en **v1.10.0-rc3** remplace le test d'upgrade v1.9.1 → v1.10.0-rc3 qui avait échoué sur l'ancien cluster endommagé. Le projet atteint ainsi son objectif : installer la version cible puis valider le hardening dessus.
