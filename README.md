# Harvester Hardening Lab

Lab de durcissement **Rancher Harvester v1.10.0-rc3** (RKE2 `v1.36.6+rke2r1`),
sur le même modèle que `pve9-hardening-lab` (Proxmox) et `xcp-ng-hardening-lab` :
mesures avant/après, hardening réversible, tests de non-régression, snapshots et
test de montée de version / redéploiement.

## État actuel

VM VirtualBox `harvester` : EFI, 24 Go RAM, 8 vCPU, VDI 300 Go. Cluster
**Ready**, `fleet-local/local` intact. Cycle hardening validé :
**19 PASS / 0 FAIL / 6 NA**, **12/12 tests fonctionnels**. Snapshot `pristine`
pris sur l'installation propre.

L'ISO distribuée par le CDN a un `version.yaml` dont le checksum ne correspond
pas au fichier servi (`f8b091fd…` au lieu de `90fe2325…`) ; l'ISO est valide
(`harvester-release.yaml` confirme `v1.10.0-rc3`), boote et installe correctement.
Détails : `docs/RESULTS-v1.10.md`.

## Documentation

| Document | Contenu | PDF |
| --- | --- | --- |
| `docs/PLAN-DE-TEST.md` | protocole baseline → apply → verify → deharden → upgrade | `docs/PLAN-DE-TEST.pdf` |
| `docs/DE-HARDENING.md` | réversibilité, OEM immuable, reboot requis | `docs/DE-HARDENING.pdf` |
| `docs/DEPLOIEMENT-PXE.md` | déploiement bare-metal iPXE / UEFI HTTP Boot | `docs/DEPLOIEMENT-PXE.pdf` |
| `docs/RESULTS.md` | résultats v1.9.1 | `docs/RESULTS.pdf` |
| `docs/RESULTS-v1.10.md` | redéploiement propre v1.10.0-rc3 | `docs/RESULTS-v1.10.pdf` |
| `docs/UPGRADE-PLAN.md` | tentative d'upgrade bloquée (CAPI endommagé) | `docs/UPGRADE-PLAN.pdf` |
| `docs/REDEPLOY-PLAN.md` | redéploiement propre de remplacement | `docs/REDEPLOY-PLAN.pdf` |
| `docs/VM-STATE.md`, `docs/RESEARCH.md` | état VM, sources analysées | PDF correspondants |
| `reports/report-harvester-v1.10-l2.md` | rapport final | `reports/report-harvester-v1.10-l2.pdf` |

## Générer les PDF (même méthode que Proxmox)

`scripts/pdf.py` porte le moteur de `pve9-hardening-lab` : Markdown → HTML → PDF
via Chrome/Edge headless, sans dépendance Python tierce (profil isolé + sortie
temporaire ASCII).

```bash
python scripts/pdf.py --all --docs          # reports/*.md + docs/*.md
python scripts/hv.py pdf --all --docs       # équivalent via l'orchestrateur
python scripts/hv.py pdf --md docs/DE-HARDENING.md
python scripts/hv.py report --title "Harvester L2" --dirs artifacts/<baseline> artifacts/<verify> --pdf
```

## Déploiement bare-metal (PXE / iPXE)

Testé sur VirtualBox, mais la cible est un serveur physique. Voir
`docs/DEPLOIEMENT-PXE.md` et les exemples dans `pxe/` :

```
#!ipxe
kernel harvester-v1.10.0-rc3-vmlinuz initrd=harvester-v1.10.0-rc3-initrd ip=dhcp \
  net.ifnames=1 rd.cos.disable console=tty1 \
  root=live:http://10.0.0.10/harvester/harvester-v1.10.0-rc3-rootfs-amd64.squashfs \
  harvester.install.automatic=true \
  harvester.install.config_url=http://10.0.0.10/harvester/config-create.yaml
initrd harvester-v1.10.0-rc3-initrd
boot
```

Fichiers fournis : `pxe/config-create.yaml`, `pxe/config-join.yaml`,
`pxe/ipxe-create`, `pxe/ipxe-join`, `pxe/dnsmasq.conf`.
⚠️ UEFI obligatoire depuis v1.8.0, ≥ 8 Gio RAM, DHCP avec option `routers`.
Les secrets du lab ne sont **jamais versionnés** (placeholders `<MOT_DE_PASSE_LAB>`
et `<TOKEN_CLUSTER>`).

## Commandes

```bash
python scripts/hv.py info
python scripts/hv.py snapshot list
python scripts/hv.py snapshot take pristine

# cycle complet : baseline -> apply -> verify
python scripts/hv.py run --phase all --level 2

# étapes séparées
python scripts/hv.py run --phase baseline
python scripts/hv.py harden --level 2 --dry-run
python scripts/hv.py harden --level 2
python scripts/hv.py run --phase verify
python scripts/hv.py deharden --dry-run
python scripts/hv.py deharden
python scripts/hv.py report --title "Harvester L2" --dirs artifacts/<baseline> artifacts/<verify> --pdf
```

Le niveau 1 applique les contrôles RKE2 CIS (profil, TLS, RBAC, audit, PSA,
sysctl, compte `etcd`) de façon persistante via `/oem/90_custom.yaml` ;
le niveau 2 ajoute le durcissement SSH. Le dé-hardening restaure le fichier OEM
sauvegardé et supprime les fichiers créés (reboot requis).

## Structure

```
guest/                 scripts invité : audit, apply (RKE2 CIS + sysctl + PSA),
                       deharden, func-test — testés sur v1.10.0-rc3
scripts/hv.py          orchestrateur hôte : info, snapshot, run, harden, deharden, report, pdf
scripts/pdf.py         moteur Markdown -> HTML -> PDF (Chrome headless)
pxe/                   exemples de déploiement bare-metal (iPXE, DHCP, config)
docs/                  plan de test, résultats, PXE, upgrade, redéploiement (+ PDF)
reports/               rapports Markdown + HTML + PDF
tools/                 serveur de config HTTP, vérification ISO, aide au boot
```

## Sécurité

Identifiants et clésSSH du lab uniquement, dans `.local/credentials.txt` et
`.keys/` (tous deux ignorés par git). Aucun mot de passe ni token n'est
versionné : les fichiers de configuration contiennent des placeholders.
