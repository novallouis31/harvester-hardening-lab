# Harvester Hardening Lab

Projet dédié (sur le même principe que `pve9-hardening-lab` et `xcp-ng-hardening-lab`) pour durcir une VM **Rancher Harvester**, avec script de dé-hardening et tests de montée de version.

## État actuel

**En cours de préparation** : la VM VirtualBox `harvester` était vide (disque de 2 Mo, aucun système installé). L'ISO `harvester-v1.9.1-amd64.iso` est attachée et j'ai démarré l'installateur en mode EFI après avoir agrandi le disque à 300 Go (minimum Harvester : 250 Gi). L'installation interactive est bloquée à la page « Configure network » (sélection de la NIC `enp0s3` faite, mais l'installateur ne passe pas à la page suivante via les scancodes VirtualBox). Voir `docs/VM-STATE.md`.

## Sources trouvées

| Projet | Licence | Intérêt | Test |
| --- | --- | --- | --- |
| `bcdurden/harvester_hardening_beta` (2 étoiles) | voir dépôt | **Spécifiquement Harvester** : Elemental SLEMicro, RKE2 CIS 1.23/1.6, Pod Security Admission, audit policy, Longhorn encryption | analysé, à intégrer |
| `bcdurden/terraform-harvester-rke2-hardened` (6 étoiles) | voir dépôt | Terraform RKE2 cluster STIG-compliant dans Harvester | référence |
| `SUSE-Enceladus/CaC-Tracking` (SUSE, peu connu) | GPL-3.0 | Validation OpenSCAP CIS Level 1 d'images SUSE durcies : baseline → 2 remediations → comparaison | **testé localement** : `bin/compare-results` passe après normalisation CRLF et copie des baselines dans `results/` |

Détails et liens : `docs/RESEARCH.md`.

## Structure

```
vendor/CaC-Tracking/   outil SUSE de validation OpenSCAP (clone, licence GPL-3.0)
docs/                  recherche, état VM, plan de test
guest/                 scripts invité (à écrire après installation)
scripts/               orchestrateur hôte (à écrire après installation)
```

## Prochaines étapes

1. Terminer l'installation Harvester dans l'UI VirtualBox (ou fournir une VM déjà installée + identifiants).
2. Prendre le snapshot `pristine`, mesurer le baseline.
3. Porter les contrôles RKE2 CIS du guide `bcdurden` dans un script idempotentsur `/oem/90_custom.yaml` (Elemental = OS immuable, les changements doivent passer par cloud-init).
4. Écrire le dé-hardening (restauration du fichier OEM + `sysctl -p`) et tester les montées de version Harvester (ISO/UI).
