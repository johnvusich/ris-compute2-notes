# Right-sizing Nextflow resource requests (from test runs)

Data: the three successful test runs, from each run's `execution_report_*.html` (per-task requests, `realtime`,
`%cpu`, `peak_rss`) joined to `sacct` on the task's Slurm job ID (`ElapsedRaw`, `CPUTimeRAW` = allocated
core-seconds, `TotalCPU` = used core-seconds, `MaxRSS`). Re-run with
[`scripts/nf_usage.py`](../scripts/nf_usage.py) on any finished run.

| Run | Job | Tasks | Head job | Task CPU h allocated | Task CPU h used | Efficiency |
|---|---|---|---|---|---|---|
| rnaseq 3.26.0 test | 3284986 | 234 | 2 CPU × 27m 28s = 0.92 CPU h; MaxRSS 7.5 GB of 8 GB | 0.81 | 0.21 | 26% |
| cutandrun 3.2.2 test (caps 2 CPU / 6 GB) | 3533290 | 135 | 2 CPU × 9m 50s = 0.33 CPU h; MaxRSS 2.4 GB | 0.19 | 0.06 | 33% |
| cutandrun dev test (caps 4 CPU / 15 GB) | 3537574 | 133 | 2 CPU × 17m 29s = 0.58 CPU h; MaxRSS 3.8 GB | 0.42 | 0.06 | 14% |

## Read this first: what test data can and cannot tell us

- **The test data is tiny.** cutandrun: 10,000 read pairs of 25 bp per sample (2 samples), aligned to hg38 chr20
  only. A real CUT&RUN sample is typically millions of read pairs against a full genome, i.e. roughly 1,000×
  more reads. Median task wall time in all three tests was ~1 s; the longest task was 68 s.
- **The test profile caps every request** (3.2.2: 2 CPU / 6 GB; dev: 4 CPU / 15 GB), so the "requested"
  column below is the cap, not the pipeline's real request. Without the cap, cutandrun dev asks for e.g.
  32 CPU / 64 GB for `BOWTIE2_*_ALIGN`, 12 CPU / 72 GB for `TRIMGALORE` (`process_high`), 16 CPU / 64 GB for
  `DEEPTOOLS_COMPUTEMATRIX_*` (from `conf/base.config` at commit `d59714a5`).
- So the tests **do** show: which processes don't use the CPUs they're given (`%cpu`), the memory floor of the
  many small steps, how many tasks run per sample, and the head job's footprint. They **do not** show real
  runtimes or peak memory for the heavy steps. Those numbers below are labelled as assumptions; calibrate them
  with a 2-sample pilot (see the end).
- Billing: `scontrol show partition general-cpu` shows no `TRESBillingWeights`, so Slurm's billing TRES defaults
  to CPUs (CPU count × wall time). Memory requests affect scheduling but, as far as Slurm's accounting goes, not
  the bill. (Still TODO from [03_slurm_accounts.md](03_slurm_accounts.md): confirm how RIS invoices.)

## cutandrun dev: per-process usage (test job 3537574)

Sorted by allocated CPU h. `%cpu` = Nextflow's CPU use (100 = one full core). Memory = max of Nextflow
`peak_rss` and sacct `MaxRSS`. Requests are the test-profile caps.

| Process | Tasks | Req CPU | Req GB | Max wall (s) | Max %cpu | Max RSS (GB) | Alloc CPU h | Used CPU h |
|---|---|---|---|---|---|---|---|---|
| FASTQC | 2 | 4 | 15 | 4 | 80 | 0.20 | 0.082 | 0.002 |
| ANNOTATION_BEDTOOLS_SORT | 1 | 4 | 15 | 0 | 36 | 0.04 | 0.043 | 0.000 |
| SAMTOOLS_STATS | 11 | 1 | 6 | 1 | 35 | 0.04 | 0.027 | 0.001 |
| DEEPTOOLS_PLOTFINGERPRINT | 2 | 4 | 15 | 10 | 93 | 1.12 | 0.027 | 0.005 |
| SAMTOOLS_SORT | 13 | 4 | 15 | 0 | 59 | 0.01 | 0.026 | 0.001 |
| SAMTOOLS_INDEX | 11 | 2 | 12 | 1 | 42 | 0.01 | 0.022 | 0.001 |
| DEEPTOOLS_COMPUTEMATRIX_GENE(_ALL) | 2 | 4 | 15 | 14 | 341 | 0.40 | 0.035 | 0.026 |
| TRIMGALORE | 2 | 4 | 15 | 5 | 182 | 0.20 | 0.017 | 0.004 |
| PICARD_MARKDUPLICATES | 3 | 4 | 15 | 4 | 134 | 2.39 | 0.016 | 0.004 |
| BOWTIE2_SPIKEIN_ALIGN | 2 | 4 | 15 | 1 | 27 | 0.01 | 0.009 | 0.000 |
| BOWTIE2_TARGET_ALIGN | 2 | 4 | 15 | 2 | 214 | 0.12 | 0.006 | 0.002 |
| MULTIQC | 1 | 1 | 6 | 13 | 24 | 0.74 | 0.004 | 0.003 |
| BEDTOOLS_GENOMECOV | 2 | 1 | 6 | 1 | 79 | 0.49 | 0.001 | 0.000 |
| FRAG_LEN_HIST | 1 | 1 | 15 | 3 | 66 | 0.13 | 0.001 | 0.001 |
| DEEPTOOLS_PLOTHEATMAP_* | 3 | 1–2 | 12–15 | 2 | 81 | 0.10 | 0.004 | 0.001 |
| PRESEQ_LCEXTRAP (failed, ignored) | 2 | 1 | 6 | 10 | 0 | 0.01 | 0.001 | 0.000 |
| 41 other processes (awk, sort, gunzip, bedtools, samtools idxstats/flagstat, peak calling, …) | 73 | 1–4 | 2–15 | ≤ 4 | ≤ 105 | ≤ 0.12 | 0.097 | 0.008 |
| **Total (133 tasks)** | | | | | | | **0.416** | **0.059** |

Observations that should carry over to real data:

1. **Many processes can't use more than ~1–2 cores** however many they're given: `FASTQC` (≤ 1 thread per FASTQ
   file), `PICARD_MARKDUPLICATES` (134%, JVM), `SAMTOOLS_STATS/INDEX/IDXSTATS/FLAGSTAT`, `PRESEQ`, `SEACR`,
   `MACS2`, bedtools, awk/sort, `DEEPTOOLS_PLOTHEATMAP_*`, `MULTIQC`. Default labels give several of these 6–12
   CPUs (`process_medium` = 6 CPU / 36 GB, `process_high` = 12 CPU / 72 GB) → mostly idle cores, billed.
2. **Threaded processes that do scale:** `BOWTIE2_*_ALIGN` (214% on tiny input; bowtie2 + samtools both get
   `--threads task.cpus`), `DEEPTOOLS_COMPUTEMATRIX_*` (341% of 4), `DEEPTOOLS_PLOTFINGERPRINT`
   (`--numberOfProcessors task.cpus`), `SAMTOOLS_SORT` (`-@ task.cpus`). For these, CPU h is roughly constant
   with CPU count; fewer CPUs mainly means longer wall time but easier scheduling.
3. **`TRIMGALORE` uses `--cores = task.cpus − 4`** (paired-end; minimum 1), so 4 CPUs → 1 core. 8 CPUs → 4
   cores is the useful size; the default 12 gives 8 cores.
4. **Small steps need < 0.5 GB at test scale** vs 6 GB default (`process_single`). Some will grow with genome
   size and depth (`BEDTOOLS_GENOMECOV` 0.49 GB already), so the proposal keeps headroom and retries.
5. **Head job:** used 28–40% of its 2 CPUs; rnaseq reached **7.5 GB of 8 GB** (it pulls/converts Apptainer
   images). Keep 2 CPU; consider `--mem=12G` in `run_nextflow.sbatch` for first runs with new containers.
   On a real multi-hour run the head job is a noticeable cost (2 CPU × wall time).

cutandrun 3.2.2 shows the same pattern (0.19 alloc / 0.06 used CPU h); rnaseq 3.26.0's largest consumers were
`BBMAP_BBSPLIT` (308% of 4, 1.5 GB), `STAR_ALIGN` (148%, 1.0 GB), `PICARD_MARKDUPLICATES` (3.9 GB). Full
per-task tables: run `scripts/nf_usage.py` (outputs `usage_<label>.tsv`).

## Proposed custom config for real cutandrun runs

Save as `custom.config` in the analysis dir and add `-c custom.config` after the global config in
`run_nextflow.sbatch` (do **not** name it `nextflow.config`; see [04_nextflow.md](04_nextflow.md)).
Written against cutandrun dev `d59714a5` process names; check names if you use another version.

Approach: shrink processes that can't use their CPUs; give threaded aligners/deeptools a moderate CPU count;
keep memory headroom where real data will grow; let OOM/timeout retries scale memory and time up. CPU counts
stay fixed on retry (CPU is what's billed).

```groovy
// custom.config — right-sized requests for nf-core/cutandrun (dev d59714a5) on Compute2.
// Basis: docs/09_resource_sizing.md. Heavy-step values are estimates until a pilot run calibrates them.

process {
    // Allow 2 retries (pipeline default 1) since requests are tighter; same exit codes as the pipeline:
    // 130-145 (incl. 137 OOM-kill, 140 time limit), 104, 175.
    errorStrategy = { task.exitStatus in ((130..145) + 104 + 175) ? 'retry' : 'finish' }
    maxRetries    = 2

    // Keep any request within a general-cpu node (64 CPUs)
    resourceLimits = [ cpus: 32, memory: 256.GB, time: 48.h ]

    // ---- Labels (pipeline defaults in comments) ------------------------------------------
    withLabel:process_single { cpus = 1; memory = { 2.GB  * task.attempt }; time = { 2.h * task.attempt } }  // 1 / 6 GB / 4 h
    withLabel:process_low    { cpus = 2; memory = { 4.GB  * task.attempt }; time = { 2.h * task.attempt } }  // 2 / 12 GB / 4 h
    withLabel:process_medium { cpus = 2; memory = { 8.GB  * task.attempt }; time = { 4.h * task.attempt } }  // 6 / 36 GB / 8 h
    withLabel:process_high   { cpus = 4; memory = { 16.GB * task.attempt }; time = { 8.h * task.attempt } }  // 12 / 72 GB / 16 h

    // ---- Threaded steps that scale with CPUs ----------------------------------------------
    withName: '.*:BOWTIE2_TARGET_ALIGN' {          // 32 / 64 GB; bowtie2 + samtools sort (~768 MB/thread)
        cpus = 16; memory = { 24.GB * task.attempt }; time = { 8.h * task.attempt }
    }
    withName: '.*:BOWTIE2_SPIKEIN_ALIGN' {         // 32 / 64 GB; E. coli index is small
        cpus = 8;  memory = { 12.GB * task.attempt }; time = { 8.h * task.attempt }
    }
    withName: '.*:SAMTOOLS_SORT' {                 // process_medium 6 / 36 GB
        cpus = 4;  memory = { 8.GB  * task.attempt }; time = { 4.h * task.attempt }
    }
    withName: '.*:DEEPTOOLS_COMPUTEMATRIX_.*' {    // 16 / 64 GB
        cpus = 8;  memory = { 16.GB * task.attempt }; time = { 4.h * task.attempt }
    }
    withName: '.*:DEEPTOOLS_PLOTFINGERPRINT' {     // process_high 12 / 72 GB
        cpus = 4;  memory = { 8.GB  * task.attempt }; time = { 4.h * task.attempt }
    }
    withName: '.*:TRIMGALORE' {                    // process_high 12 / 72 GB; --cores = cpus - 4 (PE)
        cpus = 8;  memory = { 8.GB  * task.attempt }; time = { 4.h * task.attempt }
    }

    // ---- Steps that use ~1-2 cores --------------------------------------------------------
    withName: '.*:FASTQC' {                        // process_medium 6 / 36 GB; 1 thread per FASTQ
        cpus = 2;  memory = { 4.GB  * task.attempt }; time = { 4.h * task.attempt }
    }
    withName: '.*:PICARD_MARKDUPLICATES' {         // process_medium 6 / 36 GB; JVM -Xmx = 80% of memory
        cpus = 2;  memory = { 16.GB * task.attempt }; time = { 4.h * task.attempt }
    }
    withName: '.*:DEEPTOOLS_PLOTHEATMAP_.*' {      // 1 / 64 GB; single-threaded plotting
        cpus = 1;  memory = { 16.GB * task.attempt }; time = { 2.h * task.attempt }
    }
    withName: '.*:FRAG_LEN_HIST' {                 // 1 / 32 GB
        cpus = 1;  memory = { 8.GB  * task.attempt }; time = { 2.h * task.attempt }
    }
    withName: '.*:BEDTOOLS_GENOMECOV' {
        cpus = 1;  memory = { 8.GB  * task.attempt }; time = { 2.h * task.attempt }
    }
    withName: '.*:(SEACR_CALLPEAK.*|MACS2_CALLPEAK.*)' {   // process_medium 6 / 36 GB; single-threaded
        cpus = 1;  memory = { 8.GB  * task.attempt }; time = { 4.h * task.attempt }
    }
    withName: '.*:MULTIQC' {
        cpus = 1;  memory = { 8.GB  * task.attempt }; time = { 2.h * task.attempt }
    }
}
```

Checked: parses with the cluster's Nextflow 25.10.0 (`nextflow config`, default parser). With
`NXF_SYNTAX_PARSER=v2` it prints `Unrecognized config option` warnings for the `withName` blocks; recheck when the
cluster moves to Nextflow 26.04+, where that parser is the default.

Before relying on it, verify on the pilot run that the trace's `cpus`/`memory` columns show these values (a
`withName` in a `-c` config should override the pipeline's own `withName`/`withLabel`, but check).

## Estimating CPU hours for N samples

N counts **every library**, including IgG controls (e.g. 3 targets × 2 reps + 2 IgG = 8).

```
CPU h ≈ N × D × c_sample   +   F_run   +   H
```

| Term | Meaning | Value | Source |
|---|---|---|---|
| D | read pairs per library, millions | your data | — |
| c_sample | allocated CPU h per million read pairs per library, all per-sample steps | **0.15 – 0.5** (planning range) | **Assumption, not measured** (see below) |
| F_run | per-run steps (genome prep, consensus peaks, deeptools across samples, MultiQC) | ~1–3 CPU h with a prebuilt bowtie2 index; **+10–30 CPU h once** if the pipeline builds the index | Assumption; test runs measured ~0.1 CPU h at chr20 scale |
| H | head job | 2 CPU × wall time (expect several hours for a real run) | Measured: 2 CPU × 10–27 min on tests |

How c_sample breaks down (per million read pairs, allocated CPU h, with the config above): bowtie2 target
~0.05–0.2, bowtie2 spike-in ~0.03–0.1, Trim Galore + FastQC ~0.02–0.05, sorting/duplicates/deeptools/bigWigs/
peaks ~0.05–0.15. These are planning ranges from typical tool throughput for 2×50–150 bp reads, not
measurements on Compute2. The tests cannot pin them down: at 10,000 reads every step finishes in seconds and
startup dominates.

Worked examples (prebuilt index, H ≈ 2 CPU × 6 h = 12 CPU h, F_run ≈ 2):

| N libraries | 10 M pairs each | 20 M pairs each |
|---|---|---|
| 4 | 20 – 34 CPU h | 26 – 54 CPU h |
| 8 | 26 – 54 CPU h | 38 – 94 CPU h |
| 12 | 32 – 74 CPU h | 50 – 134 CPU h |
| 24 | 50 – 134 CPU h | 86 – 254 CPU h |

With the pipeline's **default** requests the same run would allocate noticeably more, mainly from idle cores
in `TRIMGALORE` (12), `FASTQC` (6), `PICARD_MARKDUPLICATES` (6), `SAMTOOLS_SORT` (6), `SEACR`/`MACS2` (6),
`DEEPTOOLS_PLOTFINGERPRINT` (12) and the 6–12 CPU labels on single-threaded steps. The test runs show the
direction (14–33% CPU efficiency with capped requests) but not the size of the saving at real scale.

Many realistic runs cross the **~50 CPU h** line in `CLAUDE.md`, so a full run needs your OK first.

## Calibrating with a pilot

1. Run 1 target + 1 IgG library at full depth with `-c custom.config` (≈ 2 × D × c_sample + F_run + H; e.g.
   ~15–35 CPU h at 20 M pairs with a prebuilt index; ask first if it would build the index).
2. `python3 scripts/nf_usage.py pilot <analysis>/results/pipeline_info/execution_report_*.html`
3. From `usage_pilot.tsv`: replace c_sample with the measured allocated CPU h ÷ (2 × D); set each heavy
   process's memory to ~1.5 × its max RSS and time to ~2 × its max wall time; lower CPUs where `%cpu` is far
   below `100 × cpus`.
4. Update this page and the config, then size the full run.
