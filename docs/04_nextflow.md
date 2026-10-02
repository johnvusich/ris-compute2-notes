# Running Nextflow / nf-core Pipelines on Compute2

## How the pieces fit

```
Login node (c2-login-00N)
  └─ sbatch run_nextflow.sbatch            ← head job (2 CPU, 8 GB, long wall time)
        ├─ module load ris nextflow apptainer
        ├─ nextflow run nf-core/<pipeline>
        │     ├─ submits each step as its own Slurm job (executor = 'slurm')
        │     ├─ pulls containers → storage3 apptainer_cache
        │     ├─ temp files       → scratch2  (work dir)
        │     └─ final results    → storage3  (results/)
        └─ .nextflow/ + .nextflow.log + Slurm log → analysis (launch) dir on storage3
```

| What | Where | Why |
|---|---|---|
| Global cluster config | `~/.config/nextflow/nextflow.config` | Same settings for every run |
| Launch dir (`.nextflow/`, `.nextflow.log`, `-resume` cache) | `$STORAGE/projects/<project>/analyses/<date>_<name>/` | Keeps history with the analysis; `-resume` needs the same launch dir |
| Slurm head-job log | `<analysis>/logs/` | Lives with the analysis, not in home |
| Work dir | `$SCRATCH/nf_work/<project>/<date>_<name>/` | Huge, temporary |
| Results | `<analysis>/results/` | Permanent, backed up |
| Containers | `$STORAGE/apptainer_cache/` | Shared across runs; not purged |

## One-time setup

```bash
# 1. Directories
mkdir -p /scratch2/fs1/sheila.stewart/john.v \
         /storage3/fs1/sheila.stewart/Active/john.v/{apptainer_cache,projects,references,tests}

# 2. Shell variables and aliases
cat templates/bashrc_snippet.sh >> ~/.bashrc && source ~/.bashrc

# 3. Global Nextflow config
mkdir -p ~/.config/nextflow
cp templates/nextflow.config ~/.config/nextflow/nextflow.config
```

Reference: RIS's own template config (compare against mine occasionally):

```bash
wget -O ~/ris_nextflow_template.config \
  https://raw.githubusercontent.com/WashU-IT-RIS/c2-ris-app-config-templates/refs/heads/main/nextflow/nextflow.config
```

## Every new analysis

```bash
c2                                                   # load Slurm (alias)
bash ~/ris-compute2-notes/scripts/new_analysis.sh <project> <analysis>
cd /storage3/fs1/sheila.stewart/Active/john.v/projects/<project>/analyses/<YYYY-MM-DD>_<analysis>
# edit: run_nextflow.sbatch (PIPELINE, REVISION), params.yaml, add samplesheet.csv
sbatch run_nextflow.sbatch
```

**Always `cd` into the analysis dir before `sbatch`.** The script uses `$SLURM_SUBMIT_DIR`
as the launch dir and writes `logs/` relative to it.

## Monitoring

```bash
squeue -u $USER                       # head job + nf-NFCORE_... child jobs
tail -f logs/nf-*_<jobid>.log         # Nextflow progress
tail -100 .nextflow.log               # full detail / stack traces
```

Sanity checks on the first run:
- Log says `executor > slurm` (not `local`)
- `squeue` shows child jobs, not just the head job

## Resuming after a failure

```bash
cd <analysis dir>                     # SAME launch dir
sbatch run_nextflow.sbatch            # script already has -resume
```

Works only while the work dir on scratch still exists (< 28 days from creation).

## Choosing versions

- Pin the pipeline: `-r <version>`. Check each release's minimum Nextflow version.
  Example: rnaseq **3.27.0 needs Nextflow ≥ 25.10.4**; with module `nextflow/25.10.0` I used **3.26.0**.
- Check modules: `module avail nextflow`, `module avail apptainer`.
- Record pipeline + module versions in the analysis `README.md`.

## After a run

- `results/pipeline_info/execution_report_*.html` — requested vs used CPU/memory per process.
  Use it to trim resources (billing is based on what's requested).
- `results/multiqc/` — QC summary.
- Clean up scratch when done: `rm -rf $SCRATCH/nf_work/<project>/<analysis>`
  (or let the 28-day purge do it).

## Test run (Oct 2026)

```bash
nextflow run nf-core/rnaseq -r 3.26.0 -profile test \
  -c ~/.config/nextflow/nextflow.config \
  -work-dir /scratch2/fs1/sheila.stewart/john.v/nf_work/rnaseq_test \
  --outdir /storage3/fs1/sheila.stewart/Active/john.v/tests/rnaseq_test \
  -resume
```

Modules: `ris nextflow/25.10.0 apptainer/1.3.6`.
Launch dir: `/storage3/fs1/sheila.stewart/Active/john.v/tests/rnaseq_test_launch`.
Submitted from `~`, so the Slurm log went to home (see troubleshooting).
Status: running at time of writing — **TODO: record outcome, runtime, and job ID.**
