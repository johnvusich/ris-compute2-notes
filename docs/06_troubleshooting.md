# Troubleshooting Log

Errors I've hit on Compute2 and what fixed them. Add new ones at the top.

---

### `Cannot invoke "nextflow.util.Duration.toMillis()" because "this.pullTimeout" is null`

**When:** First container pull, Nextflow 25.10.0 with my own `apptainer { }` block.
**Cause:** `pullTimeout` not set; Nextflow 25.10.0 left it null instead of using a default.
**Fix:** Add to the `apptainer` block in `~/.config/nextflow/nextflow.config`:

```groovy
pullTimeout = '1h'
```

---

### nf-core/rnaseq 3.27.0 won't run

**Cause:** 3.27.0 requires Nextflow ≥ 25.10.4; module was `nextflow/25.10.0`.
**Fix:** Use `-r 3.26.0`, or load a newer Nextflow module if available (`module avail nextflow`).
**Lesson:** Check the minimum Nextflow version in the release notes before pinning a pipeline version.

---

### `The specified configuration file does not exist: /home/john.v/.config/nextflow/nextflow.config`

**Cause:** Passed `-c` to a config I hadn't created yet.
**Fix:** Create it from `templates/nextflow.config` (see [04_nextflow.md](04_nextflow.md)).

---

### `sbatch: error: slurm_job_submit: You must specify an account ...`

**Cause:** Compute2 requires an account on every job.
**Fix:** `#SBATCH --account=compute2-sheila.stewart` in the script **and**
`process.clusterOptions = '--account=compute2-sheila.stewart'` in the Nextflow config.
Find accounts: `sacctmgr show assoc user=$USER format=account%40,partition%25,qos%40`

---

### `sbatch: command not found` / `squeue: command not found`

**Cause:** Slurm is not loaded by default on Compute2 (unlike MSU ICER).
**Fix:** `module purge && module load ris slurm/compute2/25.05` (alias `c2`).

---

### `quota: error while getting quota from scratch2.ris.wustl.edu:/scratch2/fs1 ... Operation not permitted`

**Cause:** `quota` isn't how RIS reports usage.
**Fix:** `df -h /scratch2/fs1/sheila.stewart` (same for `/storage3/fs1/sheila.stewart`, `/home/john.v`).

---

### `bash: /home/john.v: Is a directory` / `$SCRATCH` prints nothing

**Cause:** Typing `$HOME` runs its value as a command. `$SCRATCH` isn't defined on RIS.
**Fix:** `echo $HOME`; define `SCRATCH` myself in `~/.bashrc` (`templates/bashrc_snippet.sh`).

---

### Slurm log / `.nextflow.log` ended up in home

**Cause:** Ran `sbatch` from `~`. Slurm writes `--output` relative to the submit dir, and
Nextflow's launch dir is wherever `nextflow run` executes.
**Fix:** `cd` into the analysis dir before `sbatch`; template uses `$SLURM_SUBMIT_DIR` and `logs/`.

---

## General debugging steps

1. Read the error block at the end of the Slurm log (`logs/*.log`).
2. Full stack trace: `.nextflow.log` in the launch dir.
3. Failed task: the error prints its work dir → `cd` there and check
   `.command.sh`, `.command.err`, `.command.log`, `.exitcode`.
4. Job-level info: `sacct -j <jobid> --format=JobID,State,ExitCode,MaxRSS,Elapsed`
   (`OUT_OF_MEMORY` / `TIMEOUT` → raise resources in a `custom.config`).
5. Still stuck → RIS Service Desk (include job ID, paths, and log excerpts).
