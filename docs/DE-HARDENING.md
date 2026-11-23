# Dé-hardening — Harvester v1.10

Le dé-hardening prouve que le durcissement est réversible sur un nœud Harvester
(OS immuable Elemental SLEMicro) sans réinstallation.

```text
baseline  ->  harden L1/L2  ->  verify  ->  deharden (--dry-run puis réel)  ->  audit final
```

## 1. Spécificité Harvester : OS immuable

Les changements persistants passent par `/oem/90_custom.yaml` (cloud-init
Elemental). Le script `guest/apply-harvester.sh` sauvegarde ce fichier dans
`/root/harvester-hardening-backups/<horodatage>/` avant de l'écraser.

## 2. Ce que fait `guest/deharden-harvester.sh`

| Action | Détail |
| --- | --- |
| Sauvegarde de sécurité | `/oem/90_custom.yaml` copié dans `/root/hv-deharden-safety-<horodatage>/` |
| `RESTORE` | `/oem/90_custom.yaml` ← snapshot le plus ancien contenant `oem-path` |
| `REMOVE` | `/etc/sysctl.d/99-harvester.conf` |
| `REMOVE` | `/etc/rancher/rke2/config.yaml.d/52-stig.yaml` (profil CIS) |
| `REMOVE` | `/etc/rancher/rke2/audit-policy.yaml` |
| `REMOVE` | `51-rke2-pss-custom.yaml`, `92-harvester-kube-audit-policy.yaml` |
| `REMOVE` | `/etc/ssh/sshd_config.d/00-harvester-hardening.conf` (niveau 2) |
| Clé SSH | retrait de la clé du lab de `/home/rancher/.ssh/authorized_keys` et `/root/.ssh/authorized_keys` |
| Runtime | `sysctl --system`, `systemctl reload sshd` (si `sshd -t` OK) |

> ⚠️ **Un reboot est nécessaire** pour que la configuration OEM restaurée
> prenne effet. Le `rke2-server` peut rester `activating` environ 1 minute
> après le changement de configuration ; le nœud reste `Ready`.

## 3. Commandes

```bash
# côté hôte Windows (toujours le dry-run d'abord)
python scripts/hv.py deharden --dry-run
python scripts/hv.py deharden

# ou directement sur le nœud
sudo bash guest/deharden-harvester.sh --dry-run --report /tmp/hv-deharden-dry.md
sudo bash guest/deharden-harvester.sh --report /tmp/hv-deharden.md
```

Le dry-run affiche les actions `RESTORE / REMOVE / sysctl / reload sshd` sans
écrire. Le rapport Markdown produit est archivable dans `artifacts/`.

## 4. Vérification

```bash
python scripts/hv.py run --phase baseline
python scripts/hv.py run --phase verify --no-func
bash guest/func-test-harvester.sh
```

Attendu : `19 PASS / 0 FAIL` en état durci, profil CIS/audit policy absents
après dé-hardening, compte `etcd` et clé SSH du lab supprimés, services
`rke2-server` et `rancherd` actifs.

Résultats réels : `docs/RESULTS-v1.10.md` et
`reports/report-harvester-v1.10-l2.md`.

## 5. Limitations connues

- Les contrôles portant sur des paramètres noyau (`net.ipv6.conf.*`,
  `bpf_jit_harden`) ne se réinitialisent complètement qu'au reboot.
- Le dé-hardening ne supprime aucun paquet ni aucune image Longhorn : il ne
  restaure que les fichiers et paramètres écrits par `apply-harvester.sh`.
- En cas d'upgrade interrompu (voir `docs/UPGRADE-PLAN.md`), préférer un
  redéploiement propre documenté dans `docs/REDEPLOY-PLAN.md`.
