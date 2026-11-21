# Plan de montée de version — Harvester 1.9.1 → 1.10.0-rc3

## Contexte

- Version installée : **v1.9.1** (stable la plus récente au 21 nov. 2026).
- Cible : **v1.10.0-rc3** (RC publiée le 21 nov. 2026) — c'est la seule montée de version disponible ; pas de v1.9.2 ni de v1.10.0 stable.
- Procédure officielle : créer un objet `Version` depuis `https://releases.rancher.com/harvester/<version>/version.yaml`, puis un objet `Upgrade` dans `harvester-system`.
- Prérequis vérifiés : `/usr/local/` = 114 GiB libres (> 30 GiB), nœud `Ready`, cluster sain.

## Méthode

```bash
# Depuis le lab (scripts/hv.py non modifié pour l'upgrade) :
python tools/hv-do-upgrade.py
```

Étapes : snapshot `pre-upgrade` → `kubectl create -f version.yaml` → création de l'objet `Upgrade` → surveillance de `kubectl -n harvester-system get upgrades -o wide` jusqu'à `Complete` → relevé de la version finale.

## Points d'attention

- Harvester ne supporte pas les downgrades : le snapshot `pre-upgrade` est le seul retour arrière (restauration VM éteinte).
- L'upgrade redémarre le nœud : les sessions SSH sont coupées, le script de surveillance doit être résilient (reconnexion par requête).
- Le durcissement appliqué via `/oem/90_custom.yaml` (Elemental immuable) doit être revérifié **après** l'upgrade, puis réappliqué si nécessaire ; le profil RKE2 `cis` et l'audit policy sont dans la config persistante, donc ils devraient survivre.
- En cas de corruption du NVRAM EFI après un arrêt brutal : supprimer `harvester.nvram` et restaurer le `.vbox` depuis `.vbox-prev` (vu pendant ce lab).

## Résultat

À remplir après exécution.
