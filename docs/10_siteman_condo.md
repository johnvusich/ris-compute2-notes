# Siteman condo (`condo-siteman`) vs `general-cpu`

**Status: IN PROGRESS** (2026-10-16): Slurm checks done; Nextflow tests next.

Branch `siteman-condo-test`. Test dir: `/storage3/fs1/sheila.stewart/Active/john.v/tests/siteman_condo/`
(`logs/` inside). Fact sources are labelled as in [03_slurm_accounts.md](03_slurm_accounts.md):
**[live]** = live Slurm, **[RIS docs]**, **[unverified]**.

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
