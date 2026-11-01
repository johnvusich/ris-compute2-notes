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
squeue --me                       # head job + nf-NFCORE_... child jobs
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
- **Modules change under you**: on 2026-11-01 `nextflow/25.10.0` was gone and `nextflow/25.10.2` was the only one.
  Run `module spider nextflow` before a project, and do a cheap stub/test run when the version changes. Validated on 25.10.2:
  rnaseq 3.26.0, differentialabundance 1.5.0 (2.0.0 needs ≥ 25.10.4). See [07, T6](07_pipeline_tests.md).
- Check modules: `module avail nextflow`, `module avail apptainer`.
- Record pipeline + module versions in the analysis `README.md`.

## Chaining pipelines (e.g. rnaseq → differentialabundance)

Submit both head jobs at once and let Slurm hold the second:

```bash
RNA=$(sbatch --parsable run_rnaseq.sbatch)
sbatch --dependency=afterok:$RNA run_da.sbatch     # squeue shows PENDING (Dependency)
```

- `afterok` starts the second job only if the first **head job** exits 0, and nf-core head jobs exit non-zero when the pipeline fails.
  If rnaseq fails, the DA job sits at `DependencyNeverSatisfied`. Cancel it, fix and `-resume` rnaseq, then resubmit DA.
- In the second script, fail fast if the expected inputs are missing (`[[ -s counts.tsv ]] || exit 1`), and point the params at
  the absolute paths the first run *will* write (for rnaseq star_salmon:
  `<outdir>/star_salmon/salmon.merged.gene_counts.tsv` and `salmon.merged.gene_lengths.tsv`).
- Tested 2026-11-01 ([07, T6](07_pipeline_tests.md)): DA started within seconds of rnaseq finishing.

## After a run

- `results/pipeline_info/execution_report_*.html` — requested vs used CPU/memory per process.
  Use it to trim resources (billing is based on what's requested).
- `results/multiqc/` — QC summary.
- Clean up scratch when done: `rm -rf $SCRATCH/nf_work/<project>/<analysis>`
  (or let the 28-day purge do it).

## Test runs

All test runs (commands, attempts, results) are in [07_pipeline_tests.md](07_pipeline_tests.md).
The first rnaseq test (2026-10-02, job 3284986, succeeded on attempt 4) is T1 there.

`-stub-run` with your real samplesheet is a cheap check of inputs and Slurm submission, but for rnaseq it ends after
trimming (the empty stub reads fail the trimmed-reads threshold), so alignment and QC processes are never submitted. Check their
resources with `nextflow -c ... config nf-core/rnaseq -profile apptainer` instead.

Symlinks are a clean way to feed in FASTQs whose real path has spaces: `ln -s "/path with spaces/x.fastq.gz" $SCRATCH/<proj>/fastq/x.fastq.gz`
and put the symlink paths in the samplesheet. This worked with apptainer in both stub and real rnaseq runs (2026-11-01).

## Container engine
- Engine is selected with `-profile singularity` (or `apptainer`), not in the global config.
- Use `singularity` for older nf-core pipelines (e.g. cutandrun 3.2.2): their modules
  check `workflow.containerEngine == 'singularity'` to pull native Singularity images;
  with `apptainer` they fall back to converting Docker images.
- Tests: `-profile test,singularity`
