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
| 2026-10-14 | cutandrun | 3.2.2 | 24.04.4 (`NXF_VER`) | 3533290 | 135 | 9m 50s | 0.5 | Succeeded (2 PRESEQ_LCEXTRAP errors ignored) |
| 2026-10-14 | cutandrun | dev (`d59714a5`) | 25.10.0 | 3537574 | 133 | 17m 29s | 1.0 | Succeeded (2 PRESEQ_LCEXTRAP errors ignored); see [08_cutandrun_dev_test.md](08_cutandrun_dev_test.md) |
| 2026-10-15 | fetchngs | 1.13.0 | 25.10.0 | 3543545 | 0 | 19s | 0.01 | Failed at launch: needs Nextflow >= 25.10.4; see [08_fetchngs_tests.md](08_fetchngs_tests.md) |
| 2026-10-15 | fetchngs | 1.12.0 | 25.10.0 | 3543676 (ftp), 3543725 (sratools), 3543820 (aspera) | 17 (8 cached) / 22 / 12 | 5m 39s / 7m 54s / 3m 23s | 0.59 / 0.75 / 0.26 | ftp succeeded with wget container override; sratools succeeded as-is (recommended); aspera blocked (ascp SSH key exchange fails); see [08_fetchngs_tests.md](08_fetchngs_tests.md) |
| 2026-10-16 | (Slurm probe, condo-siteman vs general-cpu) | - | - | 3555065-3555068 | 4 jobs | 3-6 s each | <0.01 | Succeeded; condo starts in 1 s, rounds `-c 1` up to 2 CPUs, default time 28 d; see [10_siteman_condo.md](10_siteman_condo.md) |
| 2026-10-16 | hello (nextflow-io) | v1.3 | 25.10.0 | 3555072 | 4 | 1m 3s | 0.11 | Succeeded on `condo-siteman` (head + tasks); see [10_siteman_condo.md](10_siteman_condo.md) |

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
| 7 | 2026-10-14 | 3533290 | `module load slurm/compute2/25.05` after `module load ris` (pipeline also re-downloaded, see above) | 2 × `PRESEQ_LCEXTRAP` exit 1, `max count before zero is less than min required count (4)`, ignored by the pipeline (test data too small for preseq) | **Succeeded**: 133 completed, 2 ignored |

Between 6 and 7, `~/.nextflow/assets/nf-core/` was deleted by hand, so attempt 7 re-downloads the pipeline.

## Notes

- rnaseq 3.27.0 needs Nextflow >= 25.10.4; used 3.26.0.
- cutandrun 3.2.2 declares Nextflow `!>=23.04.0` but fails to parse on 25.10.0; use `NXF_VER=24.04.4`.
- fetchngs 1.13.0 needs Nextflow >= 25.10.4; used 1.12.0 (no `NXF_VER`). fetchngs runs one launch dir per download method:
  `tests/fetchngs_1.12.0/<method>/`, work dir `$SCRATCH/nf_work/tests/fetchngs_1.12.0_<method>`.
- rnaseq test was launched before this layout; its files are in `tests/rnaseq_test_launch/` and `tests/rnaseq_test/`.
