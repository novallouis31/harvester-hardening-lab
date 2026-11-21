# Harvester L1

| ID | Before | After | Detail |
| --- | --- | --- | --- |
| HV.01 | INFO | INFO | os=SLES harvester= kernel=6.12.0-160000.40-default |
| HV.02 | PASS | PASS | persistent config: /oem/90_custom.yaml |
| HV.03 | FAIL | PASS | CIS profile set |
| HV.04 | MISSING | PASS | service account credentials |
| HV.05 | MISSING | PASS | TLS 1.2 minimum |
| HV.06 | MISSING | PASS | cipher suites pinned |
| HV.07 | MISSING | PASS | RBAC,Node |
| HV.08 | MISSING | PASS | anonymous auth off |
| HV.09 | MISSING | PASS | audit policy referenced |
| HV.10 | MISSING | PASS | kubelet protect-kernel-defaults |
| HV.11 | MISSING | FAIL | no PSA config |
| HV.12 | PASS | PASS | audit policy file present |
| HV.13 | FAIL | PASS | PSA restricted |
| HV.14 | FAIL | MISSING | no persistent sysctl file |
| HV.14.kernel.panic | MISSING | PASS | kernel.panic=10 |
| HV.14.kernel.panic_on_oops | MISSING | PASS | kernel.panic_on_oops=1 |
| HV.14.vm.overcommit_memory | MISSING | PASS | vm.overcommit_memory=1 |
| HV.14.vm.panic_on_oom | MISSING | PASS | vm.panic_on_oom=0 |
| HV.15 | FAIL | FAIL | etcd user/group missing |
| HV.16 | FAIL | FAIL | password auth allowed |
| HV.17 | FAIL | FAIL | root login unrestricted |
| HV.18 | PASS | PASS | sshd config valid |
| HV.19 | FAIL | FAIL | rKE2-server inactive |
| HV.20 | PASS | PASS | API 6443 listening |
| HV.21 | FAIL | FAIL | kubectl failed |
| HV.22 | INFO | INFO | no longhorn namespace |
| HV.23 | NA | NA | Longhorn encryption at rest: verify manually with kubectl |
| HV.24 | NA | NA | Management network isolation / VPN: not testable in NAT lab |
| HV.25 | NA | NA | Physical / IPMI / supply chain: out of lab scope |

## Functional
| ID | Before | After |
| --- | --- | --- |
| FUNC.01 | FAIL | FAIL |
| FUNC.02 | FAIL | FAIL |
| FUNC.03 | FAIL | FAIL |
| FUNC.04 | PASS | PASS |
| FUNC.05 | PASS | PASS |
| FUNC.06 | PASS | PASS |
| FUNC.07 | WARN | WARN |
| FUNC.08 | PASS | PASS |
| FUNC.09 | PASS | PASS |
| FUNC.10 | PASS | PASS |
| FUNC.11 | PASS | PASS |
| FUNC.12 | PASS | PASS |
| FUNC.13 | PASS | PASS |
