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
- **QOS:** `compute2-sheila.stewart` — applied automatically; add `--qos=compute2-sheila.stewart` if a QOS error appears.
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

| Partition | Use |
|---|---|
| `general-cpu` | Standard CPU jobs; Nextflow head job + tasks |
| `general-short` | Short jobs |
| `general-interactive` | Interactive sessions (`srun --pty`) |
| `general-gpu` | GPU jobs |
| `general-preempt-cpu` / `general-preempt-gpu` | Preemptible (can be killed/requeued) |

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

## Siteman Compute2 condo (access requested — pending)

The Siteman Cancer Center condo is like an MSU buy-in node: dedicated hardware I can
use instead of the `general-*` partitions.

Once access is granted, look up the details:

```bash
sacctmgr show assoc user=$USER format=account%40,partition%25,qos%40   # new account/QOS should appear
sinfo -s                                                               # find the condo partition name
```

| Field | Value |
|---|---|
| Account | `TODO` |
| Partition | `TODO` |
| QOS | `TODO` |
| Billing (counts against lab subsidy?) | `TODO — ask RIS / Siteman` |
| Limits (max time, cores, GPUs) | `TODO` |

To switch a pipeline to the condo, change **both**:

1. `#SBATCH --account` / `--partition` in the sbatch script (head job)
2. `process.queue` / `process.clusterOptions` in `nextflow.config` (child jobs)

Tip: keep a second config, e.g. `~/.config/nextflow/nextflow_siteman.config`, and pick
one with `-c`.

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
