# Organizing Projects and Analyses

## Layout

```
/storage3/fs1/sheila.stewart/Active/john.v/        ($STORAGE)
├── apptainer_cache/                     # shared container images
├── references/                          # genomes, annotations, indexes (shared across projects)
│   └── GRCm39_GENCODE_M35/
│       ├── genome.fa
│       ├── genes.gtf
│       └── README.md                    # source URL, download date, md5
├── tests/                               # pipeline test runs
└── projects/
    └── 2026_senCAF_cutrun/              # one dir per project: <year>_<short_name>
        ├── README.md                    # aim, samples, data source, analysis log
        ├── data/
        │   ├── raw/                     # untouched deliveries, read-only, md5sums.txt
        │   └── processed/               # outputs promoted from analyses for reuse
        ├── metadata/                    # sample sheets, experimental design
        ├── docs/                        # notes, figures for meetings
        └── analyses/
            ├── 2026-10-15_cutandrun_v1/ # one dir per run: <date>_<name>
            │   ├── README.md            # pipeline, versions, job IDs, outcome
            │   ├── run_nextflow.sbatch
            │   ├── params.yaml
            │   ├── samplesheet.csv
            │   ├── logs/                # Slurm logs
            │   ├── results/             # --outdir
            │   ├── .nextflow/           # resume cache (hidden)
            │   └── .nextflow.log
            └── 2026-11-02_diffbind/

/scratch2/fs1/sheila.stewart/john.v/                ($SCRATCH)
└── nf_work/
    └── 2026_senCAF_cutrun/
        └── 2026-10-15_cutandrun_v1/     # mirrors the analysis name
```

Create the skeleton with:

```bash
bash ~/ris-compute2-notes/scripts/new_analysis.sh <project> <analysis>
```

## Conventions

- **Names:** lowercase or `snake_case`, no spaces. Projects `<year>_<name>`; analyses `<YYYY-MM-DD>_<name>`.
- **One analysis dir = one launch dir = one scratch work dir.** Rerunning with `-resume`
  happens in the same dir; a genuinely new run (new parameters, new version) gets a new dated dir.
- **Raw data is immutable.** Verify md5s, then `chmod -R a-w data/raw/`. Never write outputs there.
- **References live once** in `$STORAGE/references`, each with a README (source, version, date, md5).
  Don't copy genomes into projects.
- **Every analysis gets a README** filled in when submitted (pipeline version, modules,
  job ID) and when finished (outcome, what was wrong if it failed).
- **Project README keeps a running table** of analyses and their status.
- **Downstream R/Python analysis** (DE, plots) goes in its own dated analysis dir that reads
  from an upstream `results/` — never edit pipeline outputs in place.

## Version control

- This notes repo: `~/ris-compute2-notes` (private GitHub).
- Per project: put the **small text files** under git — READMEs, `*.sbatch`, `params.yaml`,
  samplesheets, R/Python scripts. Suggested `.gitignore` per project:

```gitignore
data/
**/results/
**/logs/
**/.nextflow*
**/work/
*.bam
*.fastq.gz
*.bigWig
```

## Cleanup checklist (end of an analysis)

- [ ] Results in `results/` look complete (MultiQC reviewed)
- [ ] Analysis README updated
- [ ] Scratch work dir deleted (`rm -rf $SCRATCH/nf_work/<project>/<analysis>`)
- [ ] Failed/abandoned analysis dirs either deleted or marked in README
- [ ] At project end: ask about the Archive tier; `tar` + `rsync` project to Archive
