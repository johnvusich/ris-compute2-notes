# nf-core/cutandrun `dev` test on Compute2

**Status: DONE.** nf-core/cutandrun `dev` (commit `d59714a50c67486951b480febb726e47a7833187`) passes the
test profile on Compute2 with the cluster's `nextflow/25.10.0` on the **first attempt** (job 3537574), with no
changes to the template, config, parameters, or pipeline code.

- 133 tasks: 131 completed, 2 `PRESEQ_LCEXTRAP` errors ignored by the pipeline (test data too small for
  preseq; same as the 3.2.2 test).
- 17m 29s wall time; ~1.0 CPU h allocated (head job + 133 task jobs).
- MultiQC report: `tests/cutandrun_dev/results/04_reporting/multiqc/multiqc_report.html`.
- Unlike 3.2.2, no `NXF_VER` was needed: `dev` requires Nextflow >= 25.04.0 and parses on 25.10.0 with the
  default (non-strict) parser.

## Setup

| | |
|---|---|
| Pipeline | nf-core/cutandrun, branch `dev`, pinned to commit `d59714a50c67486951b480febb726e47a7833187` (2026-05-14, "Merge pull request #311 from pinin4fjords/nfschema-samplesheet"); manifest version `3.3.0dev` |
| Nextflow | Cluster module `nextflow/25.10.0` (the only version `module spider nextflow` lists). No `NXF_VER`: no other Nextflow versions installed |
| Modules | `ris`, `slurm/compute2/25.05`, `nextflow/25.10.0`, `apptainer/1.3.6` |
| Test dir | `/storage3/fs1/sheila.stewart/Active/john.v/tests/cutandrun_dev/` (launch dir, `logs/`, `results/`) |
| Work dir | `$SCRATCH/nf_work/tests/cutandrun_d59714a50c67486951b480febb726e47a7833187` |
| Script | `templates/run_nf_test.sbatch` unchanged (`-profile test,apptainer`, global config via `-c`) |
| Submit | `cd $T && sbatch -J nf-cutandrun-dev-test run_nf_test.sbatch cutandrun d59714a50c67486951b480febb726e47a7833187` |

Starting point: what made 3.2.2 work (attempt 7 in [07_pipeline_tests.md](07_pipeline_tests.md)): load `ris` on its
own line, load `slurm/compute2/25.05` in the head job, `-profile test,apptainer`. 3.2.2 also needed
`NXF_VER=24.04.4`; that is not used here.

## Investigation

### 1. Exact commit tested

`git ls-remote https://github.com/nf-core/cutandrun.git refs/heads/dev` → `d59714a50c67486951b480febb726e47a7833187`
(checked 2026-10-14). The run passes this hash to `-r` so every attempt and `-resume` uses the same code even if `dev` moves.

### 2. Minimum Nextflow version vs cluster

- `dev` `nextflow.config`: `manifest.nextflowVersion = '!>=25.04.0'` (the `!` makes it a hard requirement).
- Cluster: `nextflow/25.10.0` → **meets the requirement**.
- `dev` CI (`.github/workflows/nf-test.yml`) tests `NXF_VER` `25.04.0` and `latest-everything` (the latter with `continue-on-error`).
- The 3.2.2 blocker on 25.10.0 (`emit: html optional true` in `modules/local/for_patch/trimgalore/main.nf`) is
  fixed in `dev`: now `emit: html, optional: true`.

### 3. Strict syntax

- Nextflow docs (v25.10.0 `docs/strict-syntax.md`; current `docs/strict-syntax.mdx`): "In Nextflow 25.04 and 25.10, the
  strict parser is disabled by default… enable it by setting `NXF_SYNTAX_PARSER=v2`. In Nextflow 26.04 and later,
  the strict parser is enabled by default."
- So on the cluster's 25.10.0 the pipeline runs with the **legacy (v1) parser** unless `NXF_SYNTAX_PARSER=v2` is set.
  The template does not set it.
- `dev` does not set `NXF_SYNTAX_PARSER` anywhere (no mention in configs, CI, or docs).
- `nextflow lint .` with the cluster's 25.10.0 on the `dev` source: **91 files, no errors**; 1 error, in
  `nf-test.config` (`Config settings must be assigned with an equals sign`), which is only used by nf-test, not by
  pipeline runs. Remaining output is deprecation warnings (implicit closure parameter `it`, `Channel` → `channel`).
- Conclusion: `dev` is written to be strict-syntax compatible, and the cluster's 25.10.0 runs it with the
  legacy parser by default, so strict syntax should not block this test. If a parse error appears anyway,
  `NXF_SYNTAX_PARSER=v2` (or `v1`) is a cluster-Nextflow-only workaround to try.

### Test profile (dev)

- `process.resourceLimits = [cpus: 4, memory: '15.GB', time: '6.h']` (3.2.2 capped at 2 CPU / 6 GB).
- Same test data as 3.2.2 (hg38 chr20, E. coli spike-in), now via `params.pipelines_testdata_base_path`.
- Uses plugin `nf-schema@2.5.1` (downloaded at launch; needs internet from the head-job node).
- Expected cost: 3.2.2 test took ~0.5 CPU h with a 2-CPU cap; with a 4-CPU cap expect ~1–2 CPU h, well under 50.

## Attempt log

Attempt limit for this test: 6 failed attempts (from the task instructions; `CLAUDE.md` default is 5).

| # | Date | Job ID | Change | Error | Result |
|---|---|---|---|---|---|
| 1 | 2026-10-14 | 3537574 | None: `templates/run_nf_test.sbatch` as-is, Nextflow 25.10.0, `-profile test,apptainer`, `-r d59714a5…` | 2 × `PRESEQ_LCEXTRAP` exit 1, `max count before zero is less than min required count (4)`, ignored by the pipeline | **Succeeded**: 131 completed, 2 ignored; 17m 29s; ~1.0 CPU h |
