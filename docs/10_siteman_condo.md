# Siteman condo (`condo-siteman`) vs `general-cpu`

> **DONE** (2026-10-16). Condo works with my existing account; nextflow-io/hello and nf-core/rnaseq 3.26.0
> `-profile test` both succeeded on the condo on the first attempt (no failed attempts).
> 244 Slurm jobs, **0.833 CPU h** total (`sacct -X -u $USER -S 2026-10-16T09:40`), all COMPLETED.
> Key gotchas: **default time is 28 days**, **`-c 1` becomes 2 CPUs** (SMT node), it's **one shared node**
> with no per-user limits. **Free for Siteman members** (no charge, no subsidy use) but only for cancer-related work,
> per the Siteman condo admins' emails.

Branch `siteman-condo-test`. Test dir: `/storage3/fs1/sheila.stewart/Active/john.v/tests/siteman_condo/`
(`logs/` inside). Fact sources are labelled as in [03_slurm_accounts.md](03_slurm_accounts.md):
**[live]** = live Slurm, **[RIS docs]**, **[Siteman email]** = Siteman condo admins' announcement / approval email, **[unverified]**.

## 1. Zero-compute checks (`sbatch --test-only`)

All with `-c 1 --mem=100M -t 2 --wrap=hostname`. `--test-only` creates no job; its "job IDs" are just numbers it consumed.

| # | Change | Result |
|---|---|---|
| 1 | `-A compute2-sheila.stewart -p condo-siteman` | Accepted: start now, **"using 2 processors"** on `c2-node-115` |
| 2 | + `--qos=compute2-sheila.stewart` | Accepted, same |
| 3 | `--qos=condo-siteman-qos` instead | **`Invalid qos specification`**: the partition QOS isn't in my association, so never pass it |
| 4 | `-p general-cpu` instead of condo | Accepted, estimated start **next day 07:33** on `c2-node-002` (wrong: real job started in 2 s, test 6 below) |
| 5 | no `-A` | `You must specify an account ...` (same as general) |

Lesson: on general-cpu, `--test-only`'s start estimate means nothing (no reservations exist: `scontrol show reservation`).

## 2. Trivial jobs

Script: [`scripts/partition_probe.sbatch`](../scripts/partition_probe.sbatch) (1 CPU, `--mem=100M`, `--time=2:00`;
prints hostname, date, `nproc`, CPU model, `SLURM_*`, `scontrol show job`, `sacct`). Partition given with `-p`.

| # | Job ID | Command | One change | Wait | Ran | Node / CPU | Alloc | QOS reported | Result |
|---|---|---|---|---|---|---|---|---|---|
| 6 | 3555065 | `sbatch -p condo-siteman -J probe-condo partition_probe.sbatch` | baseline on condo | 1 s | 4 s | c2-node-115, AMD EPYC 9755 128-Core | **cpu=2**, mem=100M, billing=2 | `compute2-sheila.stewart` | OK |
| 7 | 3555066 | `sbatch -p general-cpu -J probe-gen partition_probe.sbatch` | partition → general-cpu | 2 s | 6 s | c2-node-001, Intel Xeon Gold 6548Y+ | cpu=1, mem=100M, billing=1 | `compute2-sheila.stewart` | OK |
| 8 | 3555067 | condo, script without `--mem` | drop `--mem` | 1 s | 3 s | c2-node-115 | cpu=2, **mem=8000M** (ReqMem 4000M/CPU) | same | OK: default 4000 MB **per allocated CPU** |
| 9 | 3555068 | condo, script without `--time` | drop `--time` | 1 s | 3 s | c2-node-115 | cpu=2, mem=100M | same | OK: **Timelimit 28-00:00:00** |

Findings [live]:
- `sacct`/`SLURM_JOB_QOS` report my association QOS `compute2-sheila.stewart` on both partitions. The partition QOS
  (`condo-siteman-qos`, `general-cpu-qos`) is applied on top as the limit set, but is never shown as the job's QOS.
- **Condo rounds CPU requests up to whole cores** (`ThreadsPerCore=2`): `-c 1` → 2 CPUs (both hyperthreads of one core),
  `billing=2`. general-cpu nodes have `ThreadsPerCore=1`, so `-c 1` → 1 CPU. Ask for even `-c` on the condo.
- Because default memory is per CPU, the rounding doubles default memory too (8000M, not 4000M).
- Both have `Requeue=1` (jobs can be requeued after node failure); neither partition preempts.

## 3. Nextflow: nextflow-io/hello on the condo

Config: [`templates/siteman_condo.config`](../templates/siteman_condo.config), loaded after the global config.
Head job: [`scripts/run_nf_condo.sbatch`](../scripts/run_nf_condo.sbatch) (head job also on `condo-siteman`, `-c 2 --mem=4G -t 1:00:00`).
Launch dir `tests/hello_v1.3_condo/`, work dir `$SCRATCH/nf_work/tests/hello_v1.3_condo`.

```bash
cd /storage3/fs1/sheila.stewart/Active/john.v/tests/hello_v1.3_condo     # contains logs/
sbatch -J nf-hello-condo ~/ris-compute2-notes/scripts/run_nf_condo.sbatch nextflow-io/hello v1.3 none
```

| # | Job ID | Change | Result |
|---|---|---|---|
| 10 | 3555072 (head), 3555074-3555077 (tasks) | first attempt, config as committed | **Succeeded**, 1m 3s. 4 `sayHello` tasks, all `condo-siteman` / `c2-node-115`, each started 1-2 s after submit, `AllocCPUS=2` (core rounding), `Timelimit=01:00:00` (from `process.time`). 0.111 CPU h allocated (`nf_trace_cpuh.py`). |

Effective config check (zero compute; note `nextflow config` takes `-c` *before* the subcommand and has no `-r`):

```bash
nextflow -c ~/.config/nextflow/nextflow.config -c ~/ris-compute2-notes/templates/siteman_condo.config \
  config nf-core/rnaseq -profile test,apptainer | grep -E 'resourceLimits|queue|clusterOptions'
```

This showed `resourceLimits = [cpus:64, memory:'256 GB', time:'2d']`: **a later `-c` file replaces the
test profile's own `resourceLimits` (4 CPU / 15 GB / 1 h)**, so test-profile runs would request full-size
resources. For the rnaseq test I add [`templates/nfcore_test_caps.config`](../templates/nfcore_test_caps.config) last.

## 4. Nextflow: nf-core/rnaseq 3.26.0 `-profile test` on the condo

Launch dir `tests/rnaseq_3.26.0_condo/`, work dir `$SCRATCH/nf_work/tests/rnaseq_3.26.0_condo`.
Resource caps: `process.resourceLimits` (supported by rnaseq 3.26.0), restored to the test profile's values by
`nfcore_test_caps.config` (checked with `nextflow config` before submitting, see section 3).

```bash
cd /storage3/fs1/sheila.stewart/Active/john.v/tests/rnaseq_3.26.0_condo    # contains logs/
sbatch -J nf-rnaseq-condo -t 1:30:00 ~/ris-compute2-notes/scripts/run_nf_condo.sbatch \
  nf-core/rnaseq 3.26.0 test,apptainer ~/ris-compute2-notes/templates/nfcore_test_caps.config
```

| # | Job ID | Change vs hello | Result |
|---|---|---|---|
| 11 | 3555087 (head) + 234 task jobs | pipeline → rnaseq 3.26.0 `test,apptainer`, + `nfcore_test_caps.config`, head `-t 1:30:00` | **Succeeded**, 6m 0s, 234/234 COMPLETED, all on `c2-node-115`. |

Compared with my general-cpu run (job 3284986, 2026-10-02), both measured with the same tools
(`scripts/nf_trace_cpuh.py` + `sacct` on the task IDs in each run's `execution_trace`):

| | general-cpu (3284986) | condo-siteman (3555087) |
|---|---|---|
| Tasks | 234 COMPLETED | 234 COMPLETED |
| Head job wall time | 27m 28s | 6m 0s |
| Container pulls during run | 26 (first-ever run; pulls span 12:26-12:50) | 0 (all cached in `apptainer_cache`) |
| Task queue wait (submit→start) | median 1 s, max 3 s | median 1 s, max 3 s |
| Sum of task wall times | 16.8 min (longest task 68 s) | 9.1 min (longest task 41 s) |
| Task CPU h allocated | 0.812 | 0.515 |
| Head CPU h allocated | 0.916 | 0.200 |
| **Total CPU h allocated** | **1.728** (07 table says 0.5; that likely counted tasks' used CPU only) | **0.715** |
| CPU rounding | none | 82 tasks asked 1 CPU → got 2; 2- and 4-CPU tasks unchanged |
| Config changes needed | — | `queue`, `process.time`, and restoring test caps (`nfcore_test_caps.config`) |

Read with care: the 27 min → 6 min wall-time drop is **mostly the container cache**, not the condo.
The fair comparisons are queue wait (identical, both idle at test time) and per-task runtime (condo ~1.8×
faster in sum, plausibly Zen 5 vs Xeon Gold 6548Y+; single run, not a benchmark).

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

## Not tested (on purpose)

Preemption, limit-breaking, GPUs (none on the condo), multi-node jobs, real data.
