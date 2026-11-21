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

## Résultat — **upgrade non réalisé (blocage environnemental)**

Tentatives du 21 novembre 2026 :

1. La cible `v1.10.0-rc3` a bien été identifiée et son `version.yaml` vérifié (checksum SHA-512, ISO officielle `releases.rancher.com`).
2. Le pré-check a confirmé 114 GiB libres sur `/usr/local/` du nœud (prérequis Harvester > 30 GiB) et un nœud `Ready` sous v1.9.1.
3. **Blocage matériel** : les disques de l'hôte Windows étaient saturés (`C:` et `D:` à 0 Go libre — `Get-PSDrive`). Le journal VirtualBox affiche :
   `I/O cache: Error while writing entry ... to medium "ahci-0-0" (rc=VERR_DISK_FULL)` puis
   `VM: Raising runtime error 'BLKCACHE_IOERR'` et `Changing the VM state from 'RUNNING' to 'SUSPENDING'`.
   La VM Harvester passe alors en `paused` et ensuite bloque au boot (logs noyau figés vers 4,2 s).
4. Actions de remédiation effectuées :
   - suppression des anciennes ISO dans `C:\Users\Louis\Downloads` (~6 Go, puis l'ISO Harvester 7,8 Go après détachement du `.vbox`) → **~14 Go libres sur `C:`** ;
   - restauration du snapshot `pre-hardening` (état sain) et redémarrage ;
   - augmentation de la VM à **8 vCPU / 16 Go** (elle était à 3/4 Go, sous le minimum Harvester) ;
   - suppression du `harvester.nvram` corrompu et restauration du `.vbox` depuis `.vbox-prev`.
5. Le cluster a retrouvé un nœud `Ready` par intermittence, mais les CRD Harvester (`versions.harvesterhci.io`) ne sont pas revenues durablement : la surveillance a expiré après ~1 h (`TIMEOUT waiting for CRDs`). L'objet `Version`/`Upgrade` n'a donc **jamais été créé** — aucun test d'upgrade n'a pu être mené à terme.

**Conclusion** : l'upgrade n'a pas échoué à cause du lab ou du script de hardening, mais à cause de la saturation disque de l'hôte qui a corrompu/suspendu le VDI. À reprendre après libération d'au moins ~50 Go sur l'hôte (le VDI Harvester occupe ~38,5 Go et doit pouvoir croître pendant l'upgrade).

Le snapshot `pre-upgrade` n'a pas pu être créé (le script a expiré avant cette étape) ; seul `pre-hardening` existe. Le durcissement L2 validé plus haut reste la dernière configuration de référence.

## Deuxième tentative (après libération de 96 Go sur l'hôte, 21 nov. soir)

- Snapshot `pre-upgrade` créé (UUID `9790873e`), objets `Version v1.10.0-rc3` et `Upgrade hvst-upgrade-m87v2` créés avec succès.
- **Nouveau blocage** : la restauration du snapshot `pre-upgrade` avait remis la VM à 5 Go RAM / 3 CPU → `containerd` ne démarrait pas (`connection refused`), l'Upgrade restait sans `status`. VM repassée à **24 Go / 8 CPU**.
- Upgrade `hvst-upgrade-55wnd` créé, mais le moniteur a faussement conclu à `Complete` en lisant `Completed: Unknown` (condition indéfinie, état réel `PreparingLoggingInfra`). Le nœud est resté en v1.9.1.
- Troisième tentative après nettoyage des pods `helm-operation` en erreur : le webhook `validator.harvesterhci.io` **refuse la création de l'Upgrade** :
  `can't find fleet-local/local cluster, err: clusters.cluster.x-k8s.io "local" not found`.
- Diagnostic final : `kubectl get clusters.cluster.x-k8s.io -A` → **No resources found**. Les bundles Fleet `mcc-harvester` et `mcc-rancher-monitoring-crd` sont en `ErrApplied`, `capi-controller-manager` redémarre en boucle. Le cluster local CAPI/Fleet a été détruit par les incidents matériels précédents.

**État final** : Harvester **v1.9.1** (upgrade non effectué), cluster structurellement endommagé (cluster `fleet-local/local` absent). Le durcissement L2 reste validé (19 PASS / 0 FAIL, 12/12 tests) mais n'a pas pu être rejoué après l'upgrade. Pour reprendre, il faut **redéployer Harvester à partir de zéro** (ISO v1.10.x) puis rejouer le cycle hardening — la simple restauration de snapshot ne suffit plus car les objets CAPI sont perdus.
