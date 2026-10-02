# RIS Compute2 Notes (WashU, Stewart Lab)

Personal reference for running analyses (especially Nextflow / nf-core) on WashU RIS **Compute2**.
Written while learning the system coming from the MSU HPCC (ICER).

## Contents

| File | What's in it |
|---|---|
| [docs/01_icer_vs_ris.md](docs/01_icer_vs_ris.md) | Key differences from MSU ICER, **especially modules and storage** |
| [docs/02_storage.md](docs/02_storage.md) | Home / scratch2 / storage3 layout, purge policy, checking space |
| [docs/03_slurm_accounts.md](docs/03_slurm_accounts.md) | Loading Slurm, accounts, QOS, partitions, billing, Siteman condo |
| [docs/04_nextflow.md](docs/04_nextflow.md) | How I run nf-core pipelines on Compute2 (step by step) |
| [docs/05_project_organization.md](docs/05_project_organization.md) | How to organize projects and analyses |
| [docs/06_troubleshooting.md](docs/06_troubleshooting.md) | Errors I've hit and how I fixed them |
| [templates/](templates/) | `nextflow.config`, sbatch script, `.bashrc` snippet, params file |
| [scripts/new_analysis.sh](scripts/new_analysis.sh) | Scaffolds a new project/analysis directory |

## Setup on Compute2

```bash
cd ~
git clone git@github.com:<my-username>/ris-compute2-notes.git   # private repo
cat ris-compute2-notes/templates/bashrc_snippet.sh >> ~/.bashrc && source ~/.bashrc
mkdir -p ~/.config/nextflow && cp ris-compute2-notes/templates/nextflow.config ~/.config/nextflow/
```

Keeping the repo cloned at `~/ris-compute2-notes` lets `scripts/new_analysis.sh` find `templates/`.

---

## Quick reference (copy/paste)

### My paths

```bash
/home/john.v                                      # HOME   (50 GB limit)
/scratch2/fs1/sheila.stewart/john.v               # SCRATCH (lab shares 10 TB, 28-day purge)
/storage3/fs1/sheila.stewart/Active/john.v        # STORAGE (lab allocation, backed up)
/storage3/fs1/sheila.stewart/Active/john.v/apptainer_cache
/storage3/fs1/sheila.stewart/Active/john.v/projects
/storage3/fs1/sheila.stewart/Active/john.v/references
/scratch2/fs1/sheila.stewart/john.v/nf_work
```

Mac (Finder → ⌘K, on campus or VPN): `smb://storage3.ris.wustl.edu/sheila.stewart`

### Login

```bash
ssh john.v@c2-login-001.ris.wustl.edu     # login nodes 001-003; VPN when off campus
```

### Load Slurm (NOT automatic on Compute2!)

```bash
module purge
module load ris slurm/compute2/25.05
```

### Check space

```bash
df -h /home/john.v
df -h /scratch2/fs1/sheila.stewart
df -h /storage3/fs1/sheila.stewart
```

### Account / QOS / partitions

```bash
sacctmgr show assoc user=$USER format=account%40,partition%25,qos%40
sinfo -s
```

- Account: `compute2-sheila.stewart`
- QOS: `compute2-sheila.stewart`
- Partition I use: `general-cpu`

### Run an nf-core pipeline

```bash
bash ~/ris-compute2-notes/scripts/new_analysis.sh <project> <analysis>   # scaffold
cd /storage3/fs1/sheila.stewart/Active/john.v/projects/<project>/analyses/<analysis>
sbatch run_nextflow.sbatch        # ALWAYS submit from the analysis dir
squeue -u $USER
tail -f logs/*.log
```

### Monitor / cancel

```bash
squeue -u $USER                     # my jobs
sacct -X -u $USER -S today          # today's jobs incl. finished
scancel <jobid>                     # cancel one job
scancel -u $USER                    # cancel all my jobs
```
