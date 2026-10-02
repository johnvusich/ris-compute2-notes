# MSU ICER (HPCC) vs WashU RIS Compute2

Same Linux command line, very different infrastructure and nomenclature.

## The two biggest differences

### 1. Slurm and Apptainer are NOT loaded for you

| | MSU ICER | WashU Compute2 |
|---|---|---|
| Slurm commands (`sbatch`, `squeue`, ...) on login/dev node | Available immediately | **Must load a module first** |
| Apptainer/Singularity | Available by default | **Must load a module** (`apptainer/...`) |
| What goes in my sbatch script | `module purge; module load Nextflow` | `module load ris nextflow/<ver> apptainer/<ver>` |

On Compute2, before I can submit or check jobs from a login node:

```bash
module purge
module load ris slurm/compute2/25.05
```

Without this, `sbatch` / `squeue` are not found. The `ris` module unlocks the
RIS software tree. Check available versions with:

```bash
module avail slurm
module avail nextflow
module avail apptainer
```

Optional shortcut in `~/.bashrc` (see `templates/bashrc_snippet.sh`):

```bash
alias c2='module purge && module load ris slurm/compute2/25.05'
```

### 2. Storage is organized by lab allocation, not by user

| | MSU ICER | WashU Compute2 |
|---|---|---|
| Home | `$HOME` | `/home/john.v` — **50 GB limit** |
| Scratch | `$SCRATCH` (per user, defined for you) | `/scratch2/fs1/sheila.stewart` — **shared by the whole lab (10 TB)**; `$SCRATCH` is NOT defined |
| Scratch purge | Old files purged | **Deleted 28 days after creation**, no warning; old data may be deleted sooner if the lab hits quota |
| Research space | `/mnt/research/<group>` | `/storage3/fs1/sheila.stewart/Active` |
| Check quota | `quota` / `quota_check` | **`df -h <path>`** (`quota` errors out) |
| Recover deleted files | — | `.snapshots/` inside `Active` (1 week of daily snapshots) |

Details: [02_storage.md](02_storage.md).

## Other differences

| | MSU ICER | WashU Compute2 |
|---|---|---|
| Scheduler | Slurm | Slurm (Compute1, the older cluster, uses LSF — ignore Compute1 docs) |
| Account | Often optional | **Required**: `--account=compute2-sheila.stewart` |
| Cost | Free (or buy-in) | **Billed per use**, subsidized (see [03_slurm_accounts.md](03_slurm_accounts.md)) |
| Partitions | e.g. general | `general-cpu`, `general-gpu`, `general-interactive`, `general-short`, `general-preempt-cpu`, `general-preempt-gpu` |
| Buy-in nodes | Buy-in accounts | "Condo" (e.g. Siteman condo) |
| Data transfer | `rsync`, Globus | `rsync`, Globus, SMB mount on Mac |
| Nextflow cluster config | Often provided by nf-core institutional profile | Write my own (`templates/nextflow.config`) |

## Shell gotcha I hit

Typing a variable alone tries to *run* its value:

```bash
$HOME          # bash: /home/john.v: Is a directory   <- wrong
echo $HOME     # /home/john.v                          <- right
```

## Where to get help

- RIS docs: https://washu.atlassian.net/wiki/spaces/RUD/overview
- Compute2 Nextflow page: https://washu.atlassian.net/wiki/spaces/RUD/pages/2087682083/C2+Nextflow
- Compute2 storage page: https://washu.atlassian.net/wiki/spaces/RUD/pages/2336653380/Storage+Access+on+Compute2
- RIS Service Desk (tickets + docs-aware chatbot), 15-min virtual office hours Mon–Thu
