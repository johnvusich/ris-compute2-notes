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

## Notes

- rnaseq 3.27.0 needs Nextflow >= 25.10.4; used 3.26.0.
- rnaseq test was launched before this layout; its files are in `tests/rnaseq_test_launch/` and `tests/rnaseq_test/`.
