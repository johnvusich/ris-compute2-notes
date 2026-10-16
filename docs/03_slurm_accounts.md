# Slurm, Accounts, QOS, Partitions, and Billing on Compute2

## Load Slurm first (every login session)

```bash
module purge
module load ris slurm/compute2/25.05
```

Version may change; check with `module avail slurm`.

## My account and QOS

```bash
sacctmgr show assoc user=$USER format=account%40,partition%25,qos%40
```

Output (Oct 2026):

```
Account                   Partition   QOS
compute2-sheila.stewart               compute2-sheila.stewart
```

- **Account:** `compute2-sheila.stewart` — **required** on every job.
- **QOS:** `compute2-sheila.stewart` — applied automatically; add `--qos=compute2-sheila.stewart` if a QOS error appears. *[live 2026-10-16: it is my only association QOS and has no limits; each partition adds its own partition QOS with the real limits, see Partitions]*
- **Blank partition column** = account is not restricted to specific partitions.

Every sbatch script needs:

```bash
#SBATCH --account=compute2-sheila.stewart
#SBATCH --partition=general-cpu
```

Error without `--account`:

```
sbatch: error: slurm_job_submit: You must specify an account when submitting a job with the '-A' parameter
sbatch: error: Batch job submission failed: Invalid account or account/partition combination specified
```

Nextflow's child jobs need the account too (in `nextflow.config`):

```groovy
process { clusterOptions = '--account=compute2-sheila.stewart' }
```

## Partitions

| Partition | Use | Max time / default time [live] | Per-user limit (partition QOS) [live, matches RIS docs] |
|---|---|---|---|
| `general-cpu` | Standard CPU jobs; Nextflow head job + tasks | 15 d / 8 h | `general-cpu-qos`: 128 CPU, 2 TB, 100 jobs |
| `general-short` | Short jobs | 30 min / 30 min | 218 CPU, 1744 GB, 16 jobs |
| `general-interactive` | Interactive sessions (`srun --pty`) | 5 d / 8 h | 8 CPU, 64 GB, 1 GPU, 2 jobs |
| `general-gpu` | GPU jobs (H100) | 15 d / 8 h | 8 GPUs |
| `general-bigmem` | 2 nodes, ~3.7 TB RAM each (missing from my earlier table) | 28 d / 8 h | RIS docs: 128 cores, 8 TB |
| `general-preempt-cpu` / `general-preempt-gpu` | Preemptible (can be killed/requeued); RIS docs: "No costs" | 15 d / 8 h | none |
| `condo-siteman` | Siteman condo, see below | 28 d / **28 d** | none |

RIS docs: "Unless indicated differently, max resource limits are per user, across all jobs, per partition";
defaults in general partitions `--cpus-per-task=1`, `--mem-per-cpu=4GB`, `--time=8h`
([Compute Platform Policies](https://washu.atlassian.net/wiki/spaces/RUD/pages/3403546664/Compute+Platform+Policies)).
[live] Partition limits live in a *partition QOS* (`general-cpu-qos`, `condo-siteman-qos`, ...);
my association QOS `compute2-sheila.stewart` has no limits (flags `DenyOnLimit,NoDecay`).

Check limits (max wall time, etc.):

```bash
sinfo -s
scontrol show partition general-cpu
sacctmgr show qos compute2-sheila.stewart format=name%30,maxwall,maxtrespu%40,maxjobspu
```

## Interactive session

```bash
srun --account=compute2-sheila.stewart --partition=general-interactive \
     --cpus-per-task=2 --mem=8G --time=2:00:00 --pty bash
```

## Siteman Compute2 condo

The Siteman Cancer Center condo is like a buy-in node, containing dedicated hardware we can
use at no cost instead of the `general-*` partitions. *[Siteman email: confirmed, see Billing and Usage rules rows]*

Checked 2026-10-16 (Slurm 25.05.5). Labels: **[live]** = verified from live Slurm,
**[RIS docs]** = from RIS documentation, **[Siteman email]** = from the Siteman condo admins' announcement
and my access-approval email (Oct 2026), **[unverified]** = my unverified note.
Test jobs and full details: [10_siteman_condo.md](10_siteman_condo.md).

```bash
sacctmgr show assoc user=$USER format=account%40,partition%25,qos%40   # NO separate condo account/QOS appears
sinfo -s                                                               # condo-siteman, 1 node
scontrol show partition condo-siteman                                  # AllowGroups, QoS, DefaultTime
sacctmgr show qos condo-siteman-qos                                    # limits (none)
```

| Field | Value | Source |
|---|---|---|
| Account | `compute2-sheila.stewart` (same as general; no separate condo account exists) | [live] `sacctmgr show assoc` |
| Partition | `condo-siteman` | [live] `sinfo` |
| QOS | My note said `compute2-sheila.stewart`. **Clarified:** that is my association QOS; the partition also has its own partition QOS `condo-siteman-qos` (`scontrol show partition`). Condo jobs report QOS `compute2-sheila.stewart` in `sacct` (jobs 3555065-3555068); `condo-siteman-qos` applies silently as the limit set. Don't pass `--qos=condo-siteman-qos`; access is via the partition, not the QOS. | [live] |
| Who may use | Unix groups in `AllowGroups`: `ris`, `compute2-sitemanadmin` and 13 lab groups incl. **`compute2-sheila.stewart`** (I'm in it: `id`). `AllowAccounts=ALL`, `AllowQos=ALL`. | [live] |
| Hardware | **1 node**, `c2-node-115`: AMD Zen 5, 2 sockets × 128 cores, `ThreadsPerCore=2` → Slurm counts **512 CPUs** (256 physical cores), `RealMemory=1392505` MB (≈1.33 TiB usable), no GPUs. Not in any other partition. | [live] `scontrol show node` |
| Limits (max time, cores, GPUs) | My note: `256 CPU cores and ~1.5 TB of memory` (same wording as the Siteman announcement). **Clarified:** that is the *whole node* (256 physical cores = 512 Slurm CPUs; ~1.39 TB = 1.33 TiB schedulable), not a per-user limit. `condo-siteman-qos` has **no** per-user/per-job/max-jobs limits; partition `MaxTime=28-00:00:00`, `MaxNodes=UNLIMITED`. Effective cap = the node, shared with every lab in `AllowGroups`. | [live] |
| Default time | **28 days** (`DefaultTime=28-00:00:00`); general-cpu default is 8 h. **Always set `--time`** on the condo. | [live] |
| Default memory | Global `DefMemPerCPU=4000` (MB); partition `DefMemPerNode=UNLIMITED` (= not set). | [live] `scontrol show config` |
| Preemption | Partition `PreemptMode=OFF`; cluster uses `preempt/partition_prio`, and node-115 is in no other partition, so nothing can preempt condo jobs. | [live] |
| Priority | `PriorityTier=60`, `PriorityJobFactor=100` (general-cpu: 7000 / 50). All `PriorityWeight*` = 0, so in practice FIFO + backfill; tiers only matter between partitions sharing nodes, which the condo doesn't. | [live] |
| Billing (counts against lab subsidy?) | **No (verified).** Jobs on `condo-siteman` are free for Siteman members and don't count toward the group's Compute2 subsidy; jobs on every other partition are billed as usual. The `billing` TRES Slurm records on condo jobs (e.g. `billing=2` for `-c 1`) is just accounting, not a charge. (RIS docs only cover what condo *owners* pay: "no service fees" vs "server plus an operational fee".) | [Siteman email] |
| Usage rules | Only for **cancer-related research** by Siteman investigators and their labs. Use resources efficiently; request only what the job needs and don't hold idle CPUs, GPUs, memory, or storage. Access can be revoked at any time. Getting access: have a Compute2 account, fill in Siteman's request form, then Siteman asks RIS to add you. None of this is enforced in Slurm (`condo-siteman-qos` has no limits). | [Siteman email] |
| Visibility | `PrivateData` hides other users' jobs in `squeue`, so condo load can't be seen except via `sinfo`/`scontrol show node` (CPUAlloc). | [live] |

RIS docs used: [Compute Platform Policies](https://washu.atlassian.net/wiki/spaces/RUD/pages/3403546664/Compute+Platform+Policies)
(updated Sept 28; condos "dedicated to a PI lab, department or school", "usage policies set and monitored by the condo owner"),
[Scientific Compute Platform](https://ris.wustl.edu/systems/scientific-compute-platform/) (condos: "exclusive access and customized job limits", "no service fees").
Neither page mentions Siteman; the condo info link `ris.wustl.edu/services/compute/compute-condo/` returns 404.

To switch a pipeline to the condo, change **both**:

1. `#SBATCH --account` / `--partition` in the sbatch script (head job), and **always `--time`** (condo default is 28 days); use even `--cpus-per-task` (odd counts are rounded up to whole 2-thread cores)
2. `process.queue` / `process.clusterOptions` in `nextflow.config` (child jobs)

Tip: keep a second config, e.g. `~/.config/nextflow/nextflow_siteman.config`, and pick
one with `-c`. *[Done: `templates/siteman_condo.config`, tested with hello and rnaseq; see [10_siteman_condo.md](10_siteman_condo.md).]*

## Billing

- Compute2 is **billed by use**. RIS's launch announcement lists monthly billing/usage
  metrics and a **$2,800 yearly subsidy per faculty member**.
- I have not found a command that shows a dollar balance; reports likely go to the PI.
  **TODO:** ask Sheila / lab manager / RIS Service Desk how to view current spend and remaining subsidy.

Estimate usage myself (core-hours, not dollars):

```bash
# Lab usage by user since July 1 (WashU fiscal year start; adjust to billing cycle)
sreport -t hours cluster AccountUtilizationByUser \
  account=compute2-sheila.stewart start=2026-07-01 end=now

# My jobs since a date
sacct -X -u $USER -S 2026-10-01 \
  --format=JobID,JobName%30,Partition,AllocCPUS,ReqMem,Elapsed,CPUTimeRAW,State
```

`CPUTimeRAW` = allocated cores × runtime (core-seconds). Charges are generally based on
what is **requested**, so right-size resources using the Nextflow execution report.

## Monitoring jobs

```bash
squeue --me
sacct -X -u $USER -S today --format=JobID,JobName%30,State,Elapsed,ExitCode
seff <jobid>            # efficiency of a finished job (if installed)
scancel <jobid>
scancel -u $USER        # cancel ALL my jobs
```
