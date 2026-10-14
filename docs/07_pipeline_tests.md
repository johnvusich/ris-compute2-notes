# nf-core Pipeline Tests on Compute2

Test dir layout: `/storage3/fs1/sheila.stewart/Active/john.v/tests/<pipeline>_<version>/`
(launch dir, with `logs/` and `results/` inside). Work dirs: `$SCRATCH/nf_work/tests/`.

## How to run a test

```bash
c2                                            # module purge && module load ris slurm/compute2/25.05
T=/storage3/fs1/sheila.stewart/Active/john.v/tests/<pipeline>_<version>
mkdir -p $T/logs && cd $T
cp ~/ris-compute2-notes/templates/run_nf_test.sbatch .
sbatch -J nf-<pipeline>-test run_nf_test.sbatch <pipeline> <version>
squeue --me
tail -f logs/*.log
```

## Results

| Date | Pipeline | Version | Nextflow | Job ID | Tasks | Time | CPU h | Result |
|---|---|---|---|---|---|---|---|---|
| 2026-10-02 | rnaseq | 3.26.0 | 25.10.0 | 3284986 | 234 | 27m 9s | 0.5 | Succeeded |
| TODO | cutandrun | 3.2.2 | 25.10.0 | TODO | TODO | TODO | TODO | TODO |

## Attempt log: cutandrun 3.2.2

Test dir: `tests/cutandrun_3.2.2/`. Work dir: `$SCRATCH/nf_work/tests/cutandrun_3.2.2`.

| # | Date | Job ID | Change | Error | Result |
|---|---|---|---|---|---|
| 1 | 2026-10-03 | 3292985 | Template as-is (`-profile test`, Nextflow 25.10.0) | Lmod: `nextflow/25.10.0` `apptainer/1.3.6` unknown | Failed (1 s) |
| 2 | 2026-10-03 | 3292996 | (rerun) | Same Lmod error | Failed (1 s) |
| 3 | 2026-10-03 | 3293000 | Load `ris` on its own line | `Cannot invoke method optional() on null object` (`modules/local/for_patch/trimgalore/main.nf:18`, old `optional true` syntax rejected by Nextflow 25.10) | Failed (1 m) |
| 4 | 2026-10-03 | 3293014 | (rerun) | Same `optional()` error | Failed (16 s) |
| 5 | 2026-10-03 | 3293017 | `export NXF_VER=24.04.4` | `Cannot run program "sbatch"` (`module purge` unloads Slurm; head job can't submit tasks) | Failed (33 s) |
| 6 | 2026-10-03 | 3293038 | `-profile test,apptainer` | Same `sbatch` error | Failed (27 s) |

Between 6 and 7, `~/.nextflow/assets/nf-core/` was deleted by hand, so attempt 7 re-downloads the pipeline.

## Notes

- rnaseq 3.27.0 needs Nextflow >= 25.10.4; used 3.26.0.
- cutandrun 3.2.2 declares Nextflow `!>=23.04.0` but fails to parse on 25.10.0; use `NXF_VER=24.04.4`.
- rnaseq test was launched before this layout; its files are in `tests/rnaseq_test_launch/` and `tests/rnaseq_test/`.
