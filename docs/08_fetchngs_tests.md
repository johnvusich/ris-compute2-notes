# nf-core/fetchngs on Compute2: download method comparison

**Status: IN PROGRESS.**

## 1. Orientation

### Release and Nextflow

| | |
|---|---|
| Latest stable release | **1.13.0** (2026-09-15), commit `955c892d80927cee633765e6e390f9cc6b7235c9` |
| 1.13.0 requires | `manifest.nextflowVersion = '!>=25.10.4'` (hard requirement) |
| Cluster Nextflow | `nextflow/25.10.0` (only version in `module spider nextflow`) → **1.13.0 cannot run** |
| Newest release that runs | **1.12.0** (2024-02-29), commit `8ec2d934f9301c818d961b1e4fdf7fc79610bdc5`, requires `!>=23.04.0` |

Exact error from 1.13.0 on the cluster's Nextflow (attempt 1, job 3543545):

```
N E X T F L O W  ~  version 25.10.0
Launching `https://github.com/nf-core/fetchngs` [elegant_euler] DSL2 - revision: 955c892d80 [1.13.0]
Nextflow version 25.10.0 does not match workflow required version: >=25.10.4
```

`NXF_VER` would get around this, but installing other Nextflow versions is off limits for this test, so all method
tests use **1.12.0**. 1.12.0 has none of the `emit: x optional true` syntax that broke cutandrun 3.2.2 on 25.10.0.

### `--download_method` values

| Method | 1.12.0 | 1.13.0 | Tool / container (1.12.0, `-profile apptainer`) |
|---|---|---|---|
| `ftp` (default) | yes | yes | `wget` in `quay.io/biocontainers/wget:1.20.1` (1.13.0: `gzip_wget` Wave image) |
| `sratools` | yes | yes | `prefetch` in `sra-tools:3.0.8`, `fasterq-dump` + `pigz` in a `mulled-v2-5f89fe…` image (1.13.0: sra-tools 3.2.1) |
| `aspera` | yes | yes | `ascp` in `aspera-cli:4.14.0--hdfd78af_1` (bundles `ascp` 4.4.2). 1.13.0 uses aspera-cli 4.20.0, which **no longer bundles `ascp`** and downloads it from IBM at runtime (needs outbound access from the node) |
| `fastq-dl` | **no** (not in schema enum) | yes (added in PR #353; `fastq-dl:4.0.1`) | — not testable here |

Schema enums: 1.12.0 `['aspera', 'ftp', 'sratools']`; 1.13.0 `['aspera', 'fastq-dl', 'ftp', 'sratools']`.
`--force_sratools_download` is deprecated in both (use `--download_method sratools`).

How 1.12.0 picks the method per sample (`workflows/sra/main.nf`): `aspera` only if ENA lists a `fastq_aspera` link;
`sratools` if requested **or** if ENA has no FASTQ links at all (so `ftp` silently falls back to sra-tools for
SRA-only data); otherwise `ftp`.

### Accepted input IDs

`--input` is a `.csv`, `.tsv` or `.txt` file with one ID per line, no header (schema pattern `^\S+\.(csv|tsv|txt)$`).

| SRA | ENA | DDBJ | GEO |
|---|---|---|---|
| SRR, SRX, SRS, SAMN, SRP, SRA, PRJNA | ERR, ERX, ERS, SAMEA, ERP, ERA, PRJEB | DRR, DRX, DRS, SAMD, DRP, DRA, PRJDB | GSM, GSE |

Run IDs (SRR/ERR/DRR) are resolved to their experiment (SRX/ERX/DRX); multiple runs of one experiment are
listed as `<SRX>_<SRR>` rows and share the same `sample` in the samplesheet. Metadata comes from the ENA portal API.

### Other parameters used

- `--nf_core_pipeline rnaseq` → samplesheet with `sample,fastq_1,fastq_2,strandedness` first, then ENA metadata.
  1.12.0 supports `rnaseq`, `atacseq`, `viralrecon`, `taxprofiler` (1.13.0 adds `ampliseq`, `mag`, `metatdenovo`, `sarek`).
- `--nf_core_rnaseq_strandedness` defaults to `auto` (needs rnaseq ≥ 3.10).

## 2. Dataset

**GSE226974** / PRJNA942339 / SRP426332 — *Gene expression analysis of yeast grown at 25, 30 and 37°C*
(*S. cerevisiae*, PMID 37963019). Public, not controlled access; ENA has FASTQ, FTP and Aspera links for every run.

| Run | Experiment | GSM | Condition | Reads | FASTQ (ENA bytes) | ENA md5 |
|---|---|---|---|---|---|---|
| SRR23753576 | SRX19604796 | GSM7089228 | 30°C rep1 | 5,083,893 | 140,513,241 | `8a9a34cfe0e491275c552295116c13a1` |
| SRR23753575 | SRX19604797 | GSM7089229 | 30°C rep2 | 4,111,400 | 111,406,467 | `d97fb70520f446f7b34f13eeecd6f262` |
| SRR23753574 | SRX19604798 | GSM7089230 | 37°C rep1 | 4,894,709 | 132,973,209 | `a35fb1db170fea6035332431d8120528` |
| SRR23753573 | SRX19604799 | GSM7089231 | 37°C rep2 | 4,911,343 | 133,709,046 | `9caacdc5a0e4b5b75097b8edb83187ef` |
| | | | | | **518.6 MB** | |

Why this one:
- Bulk RNA-seq (TRANSCRIPTOMIC, cDNA), single-end 85 bp NextSeq 500, ~4–5 M reads per sample: small and simple.
- 4 runs, one run per experiment, so no run merging complicates the md5 comparison.
- 2 × 2 design (30°C vs 37°C), so the same IDs can feed rnaseq → differentialabundance later.
- Yeast genome (12 Mb) keeps a follow-on rnaseq run cheap.
- Found with an ENA portal search (yeast, RNA-Seq, Illumina, GEO studies). Rejected GSE110004 (nf-core/rnaseq
  test source; 1.5–3.7 GB per run) and studies with mixed ChIP/RNA runs or no replicates.

ID file (not in this repo): `$STORAGE/tests/fetchngs_1.12.0/ids.csv` (copy in `tests/fetchngs_1.13.0/`):

```
SRR23753576
SRR23753575
SRR23753574
SRR23753573
```

## 3. Setup

| | |
|---|---|
| Script | [`templates/run_fetchngs.sbatch`](../templates/run_fetchngs.sbatch): `sbatch -J nf-fetchngs-<method> run_fetchngs.sbatch <version> <method> ../ids.csv` |
| Profile | `-profile apptainer` + global config `~/.config/nextflow/nextflow.config` (Slurm executor, account, cache on storage3) |
| Modules | `ris`, `slurm/compute2/25.05`, `nextflow/25.10.0`, `apptainer/1.3.6` (same as the cutandrun tests) |
| Launch dir (one per method) | `$STORAGE/tests/fetchngs_<version>/<method>/` with `logs/`, `results/` |
| Work dir (one per method) | `$SCRATCH/nf_work/tests/fetchngs_<version>_<method>` |
| Common flags | `--input ../ids.csv --download_method <method> --nf_core_pipeline rnaseq` |

## 4. Pre-flight checks (not attempts)

Probe script: [`scripts/fetchngs_probe.sbatch`](../scripts/fetchngs_probe.sbatch), job **3543544** on c2-node-007
(2m 23s, 286 core-s). Re-check job **3543572** (c2-node-007, 8 s).

**Outbound network from compute nodes: nothing blocked.**

| Target | Result |
|---|---|
| ENA portal API `www.ebi.ac.uk/ena/portal/api` | Probe: `curl` timeout (rc 28) after 30 s on one HEAD request. Re-check: 3/3 GET + 1 HEAD → 200 in 0.5–3.4 s. **Transient, not blocked** |
| ENA FASTQ host `ftp.sra.ebi.ac.uk` | HTTPS 200, FTP 250 (listing), TCP 21 and 443 open |
| Aspera `fasp.sra.ebi.ac.uk:33001` | TCP open (Aspera also needs UDP 33001 for data; not testable with curl) |
| NCBI eutils / SDL (`locate.ncbi.nlm.nih.gov`, used by `prefetch`) | 200 |
| NCBI SRA on AWS `sra-pub-run-odp.s3.amazonaws.com` | 200 |
| `quay.io`, `depot.galaxyproject.org`, `raw.githubusercontent.com` | reachable (401 on `quay.io/v2/` is normal without a token) |

**Tools in the containers** (pulled into `$STORAGE/apptainer_cache` under the names Nextflow uses):

| Image | Size | Tools found |
|---|---|---|
| `quay.io-biocontainers-python-3.9--1.img` (already cached) | 60 MB | `python3`, `wget`, `md5sum` |
| `quay.io-biocontainers-wget-1.20.1.img` | 28 MB | `wget`, `md5sum` |
| `quay.io-biocontainers-sra-tools-3.0.8--h9f5acd7_0.img` | 147 MB | `prefetch` 3.0.8, `vdb-validate`, `vdb-config` |
| `quay.io-biocontainers-mulled-v2-5f89fe…-6a9ff0e…-0.img` | 134 MB | `fasterq-dump`, `pigz` |
| `quay.io-biocontainers-aspera-cli-4.14.0--hdfd78af_1.img` | 51 MB | `ascp` 4.4.2.550, `ascli`, key `/usr/local/etc/aspera/aspera_bypass_dsa.pem` |

`ascli --version` in the aspera image fails (`cannot load such file -- webrick (LoadError)`); the module only uses it
to fill `versions.yml`, so expect an empty aspera version there, not a failure.

**Where sra-tools keeps settings and data:**

- `vdb-config -o n NCBI_SETTINGS` → `/home/john.v/.ncbi/user-settings.mkfg` (Apptainer mounts `$HOME`).
- `CUSTOM_SRATOOLSNCBISETTINGS` writes its own `user-settings.mkfg` (random `/LIBS/GUID` +
  `/libs/cloud/report_instance_identity`) **into the task work dir** if `~/.ncbi/user-settings.mkfg` doesn't exist;
  otherwise it copies the home one. `SRATOOLS_PREFETCH` / `SRATOOLS_FASTERQDUMP` export `NCBI_SETTINGS=$PWD/...`.
- Neither settings file sets `/repository/user/main/public/root`, so `prefetch` writes `.sra` files into the
  task's cwd (the work dir on scratch), and `fasterq-dump` uses cwd for temp files. Nothing large goes to home.
- **Side effect of the probe:** running `vdb-config` created `~/.ncbi/user-settings.mkfg` (107 bytes, only
  `/LIBS/GUID`). Before the probe `~/.ncbi` did not exist. I did not delete it (outside the test dirs). It means the
  sratools run copies this file instead of generating one; see the sratools attempt.

## 5. Attempt log

Limits: 6 failed attempts per method; ~50 CPU h total. CPU h = Slurm `CPUTimeRAW` (allocated cores × elapsed)
for the head job plus all task jobs.

| # | Date | Version | Method | Job ID | Change | Error | Result |
|---|---|---|---|---|---|---|---|
| 1 | 2026-10-15 | 1.13.0 | ftp | 3543545 | None (template as-is) | `Nextflow version 25.10.0 does not match workflow required version: >=25.10.4` | Failed at launch (19 s, 0.01 CPU h); no tasks. Switch to 1.12.0 |
| 2 | 2026-10-15 | 1.12.0 | ftp | 3543588 | `-r 1.12.0` | `SRA_FASTQ_FTP` exit 4: `wget: unable to resolve host address 'ftp.sra.ebi.ac.uk'`, after Apptainer `WARNING: Skipping mount .../etc/resolv.conf [files]: /etc/resolv.conf doesn't exist in container` | Failed: metadata steps OK, all 4 downloads failed ×3 tries; 3m 37s, 0.29 CPU h |
| 3 | 2026-10-15 | 1.12.0 | ftp | 3543676 | `-c fetchngs_1.12.0_wget.config` (SRA_FASTQ_FTP container → 1.13.0's Wave `gzip_wget` image) | — | **Succeeded**: 4/4 FASTQs, md5 OK; 5m 39s, 0.59 CPU h (metadata tasks cached) |
| 4 | 2026-10-15 | 1.12.0 | sratools | 3543725 | `--download_method sratools` (same config as #3) | — | **Succeeded** first try: 4/4 FASTQs; 7m 54s, 0.75 CPU h |
| 5 | 2026-10-15 | 1.12.0 | aspera | 3543820 | `--download_method aspera` (same config as #3) | `ascp: failed to authenticate, exiting.` / `Session Stop  (Error: failed to authenticate)` (exit 1) | Failed: all 4 `ASPERA_CLI` tasks (no retry: exit 1 isn't a retry code); 3m 23s, 0.26 CPU h |

### Attempt 2 (ftp, 1.12.0): DNS failure inside the wget container

- `SRA_IDS_TO_RUNINFO` and `SRA_RUNINFO_TO_FTP` worked (ENA API reachable from tasks; metadata in `results/metadata/`).
- Every `SRA_FASTQ_FTP` task failed with wget exit 4 (network failure) in < 1 s to 45 s, including both retries
  from the `error_retry` label (maxRetries 2), then the run stopped.
- Not a firewall block: the probe reached `ftp.sra.ebi.ac.uk` from a compute node. Cause is the image.
  In `biocontainers/wget:1.20.1` (busybox-based) `/etc/resolv.conf` is a **dangling symlink**
  (`/etc/resolv.conf -> ../tmp/resolv.conf`), so Apptainer can't bind the host's resolv.conf over it and the
  container has no DNS. Checked in job 3543647 (c2-node-007):

  ```
  -- old image: lrwxrwxrwx ... /etc/resolv.conf -> ../tmp/resolv.conf
                wget: unable to resolve host address 'ftp.sra.ebi.ac.uk'
  -- 1.13.0 image (Wave gzip_wget, GNU Wget 1.25.0): /etc/resolv.conf present
                URL: http://ftp.sra.ebi.ac.uk/vol1/fastq/SRR237/078/SRR23753578/SRR23753578.fastq.gz 200 OK
  ```

- This is upstream issue nf-core/fetchngs#373, fixed in 1.13.0 by PR #380 ("Use Seqera Wave container for wget
  to fix DNS resolution issues"). The other 1.12.0 images (python, sra-tools, mulled sra-tools/pigz,
  aspera-cli) didn't print the resolv.conf warning in the probe.
- Side note: ENA's `fastq_ftp` links have no scheme, so wget prepends `http://`: the "ftp" method actually
  downloads over **HTTP** (port 80).
- Fix for attempt 3 (one change): override the `SRA_FASTQ_FTP` container with the 1.13.0 image, via
  [`templates/fetchngs_1.12.0_wget.config`](../templates/fetchngs_1.12.0_wget.config).

### Attempt 3 (ftp, 1.12.0 + wget container override): success

`sbatch -J nf-fetchngs-ftp run_fetchngs.sbatch 1.12.0 ftp ../ids.csv fetchngs_1.12.0_wget.config` (the sbatch gained
an optional 4th argument for an extra `-c` config). `-resume` reused the 8 metadata tasks from attempt 2.

- Head job 3543676, c2-node-015: **5m 39s**; 0.59 CPU h (head 0.19 + 4 download jobs 0.40; download jobs get
  `process_low` = 2 CPU, 12 GB and use ~0.5% CPU).
- `SRA_FASTQ_FTP` task realtime: 1m 59s – 4m 20s per file, all 4 in parallel → **~0.5–1 MB/s per file**
  (111–141 MB each), ~1.7 MB/s aggregate. Slow but fine at this size; for big studies this is the limit to watch.
- `md5sum -c` against ENA's md5 passed in every task; file sizes equal ENA `fastq_bytes` exactly.
- Outputs (`ftp/results/`): `fastq/*.fastq.gz` (4 files, 518,601,963 bytes, 495 MB), `fastq/md5/*.md5`,
  `metadata/*.runinfo_ftp.tsv`, `samplesheet/{samplesheet.csv,id_mappings.csv,multiqc_config.yml}`, `pipeline_info/`.
- The work dir also holds a full copy of the FASTQs (`publish_dir_mode = copy`): 495 MB on scratch.
- `~/.ncbi` unchanged (ftp doesn't use sra-tools).

### Attempt 4 (sratools, 1.12.0): success

Same command as attempt 3 with `sratools` (the wget override is passed but unused). Fresh work dir, no cache.

- Head job 3543725, c2-node-003: **7m 54s**; **0.75 CPU h** (head 0.26; `SRATOOLS_FASTERQDUMP` 0.30, `process_medium` =
  6 CPU / 36 GB, used ~5 cores for ~20 s; `SRATOOLS_PREFETCH` 0.12; `SRA_IDS_TO_RUNINFO` 0.07).
- Task realtimes: `SRA_IDS_TO_RUNINFO` ~1 min each (ENA API slow this time vs 3–20 s in attempt 2);
  `SRATOOLS_PREFETCH` 6–14 s for three runs (~12–25 MB/s from NCBI) and **3m 7s** for SRR23753574;
  `SRATOOLS_FASTERQDUMP` 17–22 s each.
- `prefetch` fetched full `.sra` files (147–183 MB; not SRA Lite) and `vdb-validate` reported each "consistent".
- Outputs (`sratools/results/`): `fastq/*.fastq.gz` (4 files, **946,293,168 bytes**, ~1.8× the ENA files),
  `custom/user-settings.mkfg`, `metadata/`, `samplesheet/`, `pipeline_info/`. No `fastq/md5/` (only ftp/aspera write
  md5 files; ENA md5s don't apply to these files).
- Scratch: work dir **1.6 GB** (`.sra` files + uncompressed FASTQ temp + copies).
- **sra-tools never touches home.** Nextflow runs every task as
  `apptainer exec --no-home --pid -B <task workdir> --bind /storage3,/scratch2 ...`, so `$HOME/.ncbi` is not visible
  in the container. `CUSTOM_SRATOOLSNCBISETTINGS` generated a fresh settings file in its work dir (new GUID +
  `report_instance_identity`) instead of copying the probe's `~/.ncbi/user-settings.mkfg`, and prefetch/fasterq-dump
  wrote only to their work dirs. `~/.ncbi` is unchanged (still the 107-byte file from the probe, 15:02).
- **FASTQ content differs from ENA (see comparison).** First read of SRR23753576:

  ```
  ENA (ftp):  @SRR23753576.1 1/1                 sratools: @SRR23753576.1 1 length=85
              CTGAATGATATNGTTTCGG...                         CTGAATGATATNGTTTCGG...   (same sequence)
              +                                              +SRR23753576.1 1 length=85
              ??????????????????????...                      AAAAA/6EEA/#EAEEEEAEEEE6EA#E6...
  ```

### Attempt 5 (aspera, 1.12.0): authentication rejected

- Metadata tasks fine; all 4 `ASPERA_CLI` tasks exit 1 with `ascp: failed to authenticate, exiting.` (3 within
  ~13 ms, one after 1m 30s). Head job 3543820, 3m 23s, 0.26 CPU h.
- TCP 33001 to `fasp.sra.ebi.ac.uk` is open (probe) and the SSH handshake reaches authentication, so this is not a
  network block: ENA's Aspera server rejects the key.
- 1.12.0 runs `ascp -QT -l 300m -P33001 -i /usr/local/etc/aspera/aspera_bypass_dsa.pem era-fasp@fasp.sra.ebi.ac.uk:...`
  with the **DSA** bypass key from the aspera-cli 4.14.0 image. 1.13.0's module instead uses an **RSA** bypass key it
  ships in `modules/local/aspera_cli/assets/aspera_bypass_rsa.pem` (and installs `ascp` at runtime via
  `ascli conf ascp install`, since aspera-cli 4.20.0 no longer bundles it).
- Planned fix for the 2nd (last allowed) aspera attempt: same image, RSA key. **Tested by hand first and it fails
  too, so the 2nd attempt was not spent.**

#### Manual diagnosis (srun jobs on compute nodes, one 37 MB test file SRR23753578; not pipeline attempts)

| Test | Result |
|---|---|
| aspera-cli 4.14.0 image, `ascp` 4.4.2, DSA key (1.12.0 as-is) | `failed to authenticate` |
| same, RSA key (image's own `aspera_bypass_rsa.pem`, identical md5 `cd99522f…` to 1.13.0's asset) | `failed to authenticate` |
| `ascp -DD -L <dir>` debug log | `ERR [asssh] SSH connection startup failed, err = -5` → `SSH connection startup encountered invalid protocol` → `errcode=89 errstr="SSH authentication failed"`, 7 ms after the client sent its KEX list. libssh2 error −5 is a **key-exchange failure**: the session dies before any key is offered, so no key choice can fix it. ENA's Aspera SSH endpoint and the libssh2 inside `ascp` 4.4.2 (Oct 2023) no longer share algorithms |
| aspera-cli **4.19.0** image (newest that might still bundle a newer `ascp`) | No `ascp` in the image (`executable file not found in $PATH`) and no `/usr/local/etc/aspera/` → no 1.12.0 image ships a newer `ascp` |
| aspera-cli **4.20.0** image + `ascli conf ascp install` (1.13.0's way of getting a current `ascp` from IBM) | `ERROR: Argument: unprocessed values: ["conf", "ascp", "install"]` (also with `config`); Apptainer also refused my `HOME` override (`Overriding HOME environment variable with APPTAINERENV_HOME is not permitted`). **Inconclusive**: this may be my invocation, not 1.13.0's module; I stopped here |

**Aspera on Compute2: BLOCKED for 1.12.0.** Not a firewall problem (TCP 33001 open, SSH handshake starts); the
`ascp` 4.4.2 bundled with every image 1.12.0 can use fails key exchange with ENA's server. Whether 1.13.0's runtime
`ascp` download works here is untested (needs Nextflow ≥ 25.10.4, and outbound access to IBM's download servers).
Same practical result as on the MSU cluster: don't use aspera.
