# Siteman condo (`condo-siteman`) vs `general-cpu`

> **DONE** (2026-10-16). Condo works with my existing account; nextflow-io/hello and nf-core/rnaseq 3.26.0
> `-profile test` both succeeded on the condo on the first attempt (no failed attempts).
> 244 Slurm jobs, **0.833 CPU h** total (`sacct -X -u $USER -S 2026-10-16T09:40`), all COMPLETED.
> Key gotchas: **default time is 28 days**, **`-c 1` becomes 2 CPUs** (SMT node), it's **one shared node**
> with no per-user limits. **Free for Siteman members** (no charge, no subsidy use) but only for cancer-related work,
> per the Siteman condo admins' emails.

Test log (attempts, job IDs, rnaseq condo vs general-cpu comparison): [07_pipeline_tests.md, T5](07_pipeline_tests.md#t5-siteman-condo-probes-hello-rnaseq).
Fact sources are labelled as in [03_slurm_accounts.md](03_slurm_accounts.md):
**[live]** = live Slurm, **[RIS docs]**, **[Siteman email]** = Siteman condo admins' announcement / approval email, **[unverified]**.

## Condo vs general-cpu

| | `general-cpu` | `condo-siteman` | Source |
|---|---|---|---|
| Account | `compute2-sheila.stewart` | same | [live] |
| QOS shown on job (`sacct`, `SLURM_JOB_QOS`) | `compute2-sheila.stewart` | same | [live] jobs 3555065/66 |
| Partition QOS (limits) | `general-cpu-qos` | `condo-siteman-qos` (can't request it) | [live] |
| Access | `AllowGroups=compute2,ris` (everyone) | `ris`, `compute2-sitemanadmin` + 13 lab groups incl. `compute2-sheila.stewart` | [live] |
| Nodes | 77 × Intel Xeon Gold 6548Y+ (Emerald Rapids), 64 CPU, ~0.8-0.9 TiB, 1 thread/core | **1** × AMD EPYC 9755 (Zen 5), 512 CPU = 256 cores × 2 threads, 1.33 TiB | [live] |
| Per-user limit | 128 CPU, 2 TB mem, 100 jobs | **none** (only the node itself) | [live] = [RIS docs] for general-cpu |
| Max / default time | 15 d / 8 h | 28 d / **28 d** | [live] jobs 3555068 |
| Default memory | 4000 MB per CPU | 4000 MB per *allocated* CPU (→ 8000 MB for `-c 1`) | [live] job 3555067 |
| `-c 1` gets | 1 CPU, billing=1 | **2 CPUs, billing=2** | [live] |
| Preemption | off | off (node in no other partition) | [live] |
| Priority | Tier 7000, JobFactor 50; all priority weights 0 | Tier 60, JobFactor 100 | [live] |
| Queue wait observed today | 1-2 s | 1 s | [live] (one morning, both idle) |
| `--test-only` start estimate | ~22 h (wrong) | now | [live] |
| rnaseq test, per-task runtime | 16.8 min summed | 9.1 min summed (one run, see T5) | [live] |
| Cost | billed per use, counts against subsidy | **free**, doesn't count toward subsidy | [RIS docs] / [Siteman email] |
| Who / what for | any Compute2 user | Siteman members' **cancer-related** research only; access revocable | [Siteman email] |

## Recommended snippets

sbatch (always set `--time`; use even `--cpus-per-task`):

```bash
#SBATCH --account=compute2-sheila.stewart
#SBATCH --partition=condo-siteman
#SBATCH --cpus-per-task=2            # 1 core; odd numbers are rounded up anyway
#SBATCH --mem=8G
#SBATCH --time=04:00:00              # default would be 28 days
```

Nextflow: keep the global config, add [`templates/siteman_condo.config`](../templates/siteman_condo.config):

```groovy
process {
    executor       = 'slurm'
    queue          = 'condo-siteman'
    clusterOptions = '--account=compute2-sheila.stewart'
    time           = '1h'                                     // only for processes with no time of their own
    resourceLimits = [ cpus: 64, memory: 256.GB, time: 48.h ] // node is shared, no per-user limits
}
```

```bash
nextflow run nf-core/<pipeline> -r <ver> -profile apptainer \
  -c ~/.config/nextflow/nextflow.config \
  -c ~/ris-compute2-notes/templates/siteman_condo.config \
  [-c ~/ris-compute2-notes/templates/nfcore_test_caps.config]   # only with -profile test
```

Head job on the condo: [`scripts/run_nf_condo.sbatch`](../scripts/run_nf_condo.sbatch) (`-c 2 --mem=4G`, set `-t`).

## Troubleshooting

- **Job sits with a 28-day limit / blocks backfill** → forgot `--time`; condo `DefaultTime=28-00:00:00`.
- **Asked for 1 CPU, `sacct` shows 2 (and billing=2)** → expected: condo node has 2 threads/core and Slurm allocates whole cores. `billing` is accounting only; condo jobs aren't charged.
- **More memory than expected without `--mem`** → default is 4000 MB per *allocated* CPU, and allocation was rounded up.
- **`Invalid qos specification`** → don't pass `--qos=condo-siteman-qos`; it's the partition's QOS, not mine. Omit `--qos` or use `compute2-sheila.stewart`.
- **`Invalid account or account/partition combination`** → missing `-A compute2-sheila.stewart` (same as general).
- **nf-core test run requests 12 CPU / 72 GB tasks** → a later `-c` config's `process.resourceLimits` replaced the test profile's caps; add `nfcore_test_caps.config` last. Check with
  `nextflow -c A -c B config nf-core/<p> -profile test,apptainer | grep resourceLimits` (`-c` goes before `config`; `config` has no `-r`).
- **`nextflow: command not found` in a one-liner** → `module load ... | tail` runs in a subshell; load modules on their own line.
- **Can't see who else is on the condo** → `squeue` hides other users (`PrivateData`); use `scontrol show node c2-node-115 | grep -E 'CPUAlloc|AllocMem'`.
- **`sbatch --test-only` says general-cpu won't start until tomorrow** → ignore; the real job started in 2 s.
- nf-core writes `execution_trace` to `results/pipeline_info/`, not the launch dir, even with `-with-trace`.

## Open questions for RIS

Answered by the Siteman condo admins' emails: condo jobs are **free** and don't count toward the subsidy;
use is limited to cancer-related research, should be efficient, and access is revocable.

Still open (for Siteman admins or RIS):

1. Is there a concrete fair-share expectation (e.g. max share of the node per lab) behind "reasonable efforts"?
   `condo-siteman-qos` enforces nothing.
2. Is the 28-day **DefaultTime** intentional? Short defaults would help backfill on a single shared node.
3. Is more condo hardware planned (currently 1 node), and is it ever shared to `general-preempt-cpu`?
4. The Compute2 Cluster page's `sinfo` example still lists old partition names (`general`, `gpu`, `bigmem`).

