# nf-core/fetchngs on Compute2: download method comparison

**Status: DONE**, with aspera BLOCKED and fastq-dl not testable.

- **1.13.0 (latest) can't run here**: it needs Nextflow ≥ 25.10.4 and the cluster has 25.10.0. All method tests used
  **1.12.0**, the newest release that runs.
- **sratools: works as-is** (1st try). **ftp: works after one fix**: 1.12.0's wget container has no DNS under
  Apptainer, so its container is swapped for the image 1.13.0 uses ([`templates/fetchngs_1.12.0_wget.config`](../templates/fetchngs_1.12.0_wget.config)).
  **aspera: BLOCKED**: `ascp` 4.4.2 fails SSH key exchange with ENA (not a firewall block). **fastq-dl**: only in
  1.13.0, so not testable.
- **Same reads, different qualities.** ftp and sratools give identical read IDs and sequences for all 4 runs, but
  **ENA's FASTQs carry placeholder qualities** (only Q3/Q30) while sra-tools gives the real Illumina qualities.
  The gz md5s differ for that reason (and formatting), not because of corruption.
- **Recommendation: `--download_method sratools`** on Compute2 (see §7).
- Samplesheet from `--nf_core_pipeline rnaseq` is accepted by nf-core/rnaseq 3.26.0 (nf-schema validation, `-preview`).
- No outbound network blocks from compute nodes to ENA or NCBI. sra-tools writes nothing to home.
- Cost: **2.12 CPU h** for everything (69 Slurm jobs incl. probes, manual tests, comparison).
- One side effect to clean up by hand: my probe created `~/.ncbi/user-settings.mkfg` (107 bytes).
  No pipeline task sees it (`--no-home`); `rm -r ~/.ncbi` is safe (I didn't, since it's outside the test dirs).

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

- `vdb-config -o n NCBI_SETTINGS` → `/home/john.v/.ncbi/user-settings.mkfg` when run by hand with plain
  `apptainer exec` (which mounts `$HOME`). Pipeline tasks don't see home at all; see attempt 4.
- `CUSTOM_SRATOOLSNCBISETTINGS` writes its own `user-settings.mkfg` (random `/LIBS/GUID` +
  `/libs/cloud/report_instance_identity`) **into the task work dir** if `~/.ncbi/user-settings.mkfg` doesn't exist;
  otherwise it copies the home one (never happens under Nextflow, which uses `--no-home`).
  `SRATOOLS_PREFETCH` / `SRATOOLS_FASTERQDUMP` export `NCBI_SETTINGS=$PWD/...`.
- Neither settings file sets `/repository/user/main/public/root`, so `prefetch` writes `.sra` files into the
  task's cwd (the work dir on scratch), and `fasterq-dump` uses cwd for temp files. Nothing large goes to home.
- **Side effect of the probe:** running `vdb-config` created `~/.ncbi/user-settings.mkfg` (107 bytes, only
  `/LIBS/GUID`). Before the probe `~/.ncbi` did not exist. I did not delete it (outside the test dirs). I expected
  the sratools run to copy it; it didn't (tasks run with `--no-home`), so it had no effect on the tests.

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

### Attempt 5 (aspera, 1.12.0): "failed to authenticate" (really a key-exchange failure)

- Metadata tasks fine; all 4 `ASPERA_CLI` tasks exit 1 with `ascp: failed to authenticate, exiting.` (3 within
  ~13 ms, one after 1m 30s). Head job 3543820, 3m 23s, 0.26 CPU h.
- TCP 33001 to `fasp.sra.ebi.ac.uk` is open (probe) and the SSH session starts, so this is not a network block.
  First guess was that the server rejects the key; the debug log below shows it fails earlier, at key exchange.
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
| `ascp -DD -L <dir>` debug log | `ERR [asssh] SSH connection startup failed, err = -5` → `SSH connection startup encountered invalid protocol` → `errcode=89 errstr="SSH authentication failed"`, 7 ms after the client sent its KEX list. libssh2 error −5 is a **key-exchange failure**: the session dies before any key is offered, so no key choice can fix it. Apparently ENA's Aspera SSH endpoint and the libssh2 inside `ascp` 4.4.2 (Oct 2023 image) share no algorithms |
| aspera-cli **4.19.0** image (newest that might still bundle a newer `ascp`) | No `ascp` in the image (`executable file not found in $PATH`) and no `/usr/local/etc/aspera/` → no 1.12.0 image ships a newer `ascp` |
| aspera-cli **4.20.0** image + `ascli conf ascp install` (1.13.0's way of getting a current `ascp` from IBM) | `ERROR: Argument: unprocessed values: ["conf", "ascp", "install"]` (also with `config`); Apptainer also refused my `HOME` override (`Overriding HOME environment variable with APPTAINERENV_HOME is not permitted`). **Inconclusive**: this may be my invocation, not 1.13.0's module; I stopped here |

**Aspera on Compute2: BLOCKED for 1.12.0.** Not a firewall problem (TCP 33001 open, SSH handshake starts); the
`ascp` 4.4.2 bundled with every image 1.12.0 can use fails key exchange with ENA's server. Whether 1.13.0's runtime
`ascp` download works here is untested (needs Nextflow ≥ 25.10.4, and outbound access to IBM's download servers).
Same practical result as on the MSU cluster: don't use aspera.

## 6. Results and comparison

### Per method (fetchngs 1.12.0, 4 runs, 518.6 MB on ENA)

| Method | Final job | Result | Wall time | CPU h (alloc) | Download step (per file) | FASTQ bytes | Scratch work dir | Failed attempts |
|---|---|---|---|---|---|---|---|---|
| ftp (+ wget container override) | 3543676 | **Succeeded** | 5m 39s¹ | 0.59¹ | 2–4.3 min, ~0.5–1 MB/s (HTTP from ENA) | 518,601,963 (= ENA) | 495 MB | 2 (#1 release, #2 DNS) |
| sratools | 3543725 | **Succeeded** | 7m 54s | 0.75 | prefetch 6–14 s (one 3m 7s) + fasterq-dump ~20 s | 946,293,168 (1.8×) | 1.6 GB | 0 |
| aspera | 3543820 | **Failed** (blocked) | 3m 23s | 0.26 | — | — | — | 1 (2nd not spent; manual tests show it can't work) |
| fastq-dl | — | Not available in 1.12.0 | — | — | — | — | — | — |

¹ ftp's metadata tasks were reused from attempt 2 (`-resume`); a fresh ftp run would add ~1–2 min and ~0.07 CPU h (the metadata steps cost 0.07 CPU h in the sratools run).
Wall times include Slurm queueing of each task (~20–35 s per step here) and are dominated by it at this size.

### FASTQ content (job 3543892, [`scripts/fastq_compare.sbatch`](../scripts/fastq_compare.sbatch))

| Run | Reads (both) | gz md5 ftp (= ENA md5) | gz md5 sratools | Read IDs | Sequences | Qualities | Quality chars ftp / sratools |
|---|---|---|---|---|---|---|---|
| SRR23753576 | 5,083,893 | `8a9a34cf…` | `ca6dcf8c…` | identical | identical | **differ** | `$?` / `#/6<AE` |
| SRR23753575 | 4,111,400 | `d97fb705…` | `3117560a…` | identical | identical | **differ** | `$?` / `#/6<AE` |
| SRR23753574 | 4,894,709 | `a35fb1db…` | `dee28942…` | identical | identical | **differ** | `$?` / `#/6<AE` |
| SRR23753573 | 4,911,343 | `9caacdc5…` | `a34f5000…` | identical | identical | **differ** | `$?` / `#/6<AE` |

(Identical = same md5 of that field across all reads. Quality characters from the first 200,000 reads.)

- **The gz files are not byte-identical and can't be**: different headers (`@SRR23753576.1 1/1` vs
  `@SRR23753576.1 1 length=85` with the name repeated on the `+` line) and different gzip streams.
- **The reads are the same** (count, order, IDs, bases).
- **The qualities are not.** ENA's FASTQs use only `?` (Q30) and `$` (Q3), the simplified scores of NCBI's
  "SRA Lite" format, while `prefetch` downloaded the full `.sra` and `fasterq-dump` wrote NextSeq's real binned
  qualities (`#/6<AE` = Q2/14/21/27/32/36). That's also why the sratools files are ~1.8× larger.
  Whether ENA has real qualities is per run (this is an NCBI-submitted 2023 study); check before relying on ENA:
  `zcat x.fastq.gz | head -n 400 | awk 'NR%4==0' | fold -w1 | sort -u | tr -d '\n'`.
- Integrity: ftp checks each file against ENA's md5 (`md5sum -c` in the task); sratools runs `vdb-validate` on the
  `.sra` (all "consistent") but publishes no md5 for the FASTQs.

### Samplesheet for nf-core/rnaseq (`--nf_core_pipeline rnaseq`)

`results/samplesheet/samplesheet.csv`, quoted CSV, one row per run (runs of one experiment would share `sample`):

```
"sample","fastq_1","fastq_2","strandedness","run_accession","experiment_accession", ... 31 ENA metadata columns
"SRX19604796","/storage3/.../fetchngs_1.12.0/ftp/results/fastq/SRX19604796_SRR23753576.fastq.gz","","auto","SRR23753576",...
```

- `sample` = experiment accession (SRX), `fastq_1` = absolute path in the fetchngs outdir, `fastq_2` empty
  (single-end), `strandedness` = `auto` (`--nf_core_rnaseq_strandedness`; needs rnaseq ≥ 3.10).
- ftp and sratools sheets are identical except the FASTQ paths.
- Checked against rnaseq 3.26.0's `assets/schema_input.json` with
  [`scripts/check_rnaseq_samplesheet.py`](../scripts/check_rnaseq_samplesheet.py): **VALID** (both sheets; a deliberately
  broken sheet is rejected).
- Real check: `nextflow run nf-core/rnaseq -r 3.26.0 -profile apptainer --input <ftp samplesheet> --genome R64-1-1 -preview`
  (job 3543893, 2m 11s): nf-schema validated params and samplesheet, **"Pipeline completed successfully"**, exit 0.
  Only warnings: `Found the following unidentified headers` listing the 31 metadata columns (ignored by rnaseq).
- Other `--nf_core_pipeline` values in 1.12.0: `atacseq` (adds `replicate` = 1, fix by hand), `viralrecon`, `taxprofiler`.

### Network from compute nodes

No blocks seen. Reached: ENA portal API, `ftp.sra.ebi.ac.uk` (HTTP/HTTPS/FTP), `fasp.sra.ebi.ac.uk:33001` (TCP),
NCBI eutils and SDL, SRA on AWS S3, quay.io, depot.galaxyproject.org, Seqera Wave CDN, GitHub raw. The ENA portal
API was flaky on 2026-10-15 15:00–15:06 (one timeout, several HTTP 500s from the login node too); the pipeline's
`sra_ids_to_runinfo.py` retries 500s and the task retries twice, and no run failed on it.

## 7. Recommendation

**Use `--download_method sratools` with fetchngs 1.12.0 on Compute2.**

- Works with the stock pipeline and our standard config; no container override.
- Gives the original base qualities. ENA's FASTQs for this (NCBI-submitted) study have placeholder Q30/Q3 scores,
  which silently disables quality trimming (Trim Galore's default cutoff is Q20) and makes FastQC/MultiQC per-base
  quality meaningless. For gene-level RNA-seq counts it matters little; for anything quality-aware (variant calling,
  QC reporting) it matters a lot.
- Downloads from NCBI were fast (most `prefetch` runs 6–14 s for ~150–180 MB) vs ~0.5–1 MB/s from ENA over HTTP.
- Handles reads ENA doesn't expose (`--include-technical`, e.g. 10x/UMI reads) and dbGaP (`--dbgap_key`).
- Keeps everything off home: tasks run with `--no-home`; `.sra` files and temp FASTQs go to the scratch work dir.

Costs and caveats of sratools:
- ~1.8× larger FASTQs on storage3 (real qualities compress worse) and ~3× the data size in the scratch work dir
  (`.sra` + uncompressed temp + copy). Plan scratch for big studies; delete the work dir after a successful run.
- `SRATOOLS_FASTERQDUMP` asks for `process_medium` (6 CPU / 36 GB) and used ~5 cores × 20 s and 64 MB here; fine
  at this scale, worth trimming in a `custom.config` for large studies (see [09_resource_sizing.md](09_resource_sizing.md)).
- No md5 for the final FASTQs; integrity rests on `vdb-validate`.

When ftp is fine: quick downloads where ENA's FASTQs are known to carry real qualities (check with the one-liner in §6).
It needs [`templates/fetchngs_1.12.0_wget.config`](../templates/fetchngs_1.12.0_wget.config) on 1.12.0, and gives you
ENA md5 verification for free. Don't use aspera on Compute2. Revisit all of this (incl. fastq-dl) when RIS installs
Nextflow ≥ 25.10.4 and fetchngs 1.13.0 can run.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Nextflow version 25.10.0 does not match workflow required version: >=25.10.4` | fetchngs 1.13.0 (and differentialabundance 2.0.0) need Nextflow ≥ 25.10.4; cluster module is 25.10.0 | Use fetchngs `-r 1.12.0`; or ask RIS for a newer `nextflow` module (`NXF_VER` would also work but downloads another Nextflow) |
| `SRA_FASTQ_FTP` exit 4, `wget: unable to resolve host address 'ftp.sra.ebi.ac.uk'`, with `WARNING: Skipping mount .../etc/resolv.conf [files]: /etc/resolv.conf doesn't exist in container` | `biocontainers/wget:1.20.1` has a dangling `/etc/resolv.conf` symlink, so Apptainer can't give it DNS (nf-core/fetchngs#373) | `-c templates/fetchngs_1.12.0_wget.config` (1.13.0's wget image). Not a firewall issue |
| `ascp: failed to authenticate, exiting.` / `Session Stop (Error: failed to authenticate)` | Really an SSH key-exchange failure (`ascp -DD -L <dir>`: `SSH connection startup failed, err = -5`) between `ascp` 4.4.2 and ENA's Aspera server; changing DSA → RSA key doesn't help | Use sratools or ftp. No 1.12.0-compatible image ships a newer `ascp` (aspera-cli 4.19.0+ don't bundle it) |
| `ascli conf ascp install` → `ERROR: Argument: unprocessed values` (manual test in aspera-cli 4.20.0) | Unclear (my invocation; `HOME` override refused by Apptainer) | Untested in the real 1.13.0 module; re-check when 1.13.0 can run |
| ENA API `curl` timeout or HTTP 500 (metadata step) | ENA portal API outages (seen 2026-10-15 ~15:00–15:06) | Script retries 500s ×3, task retries ×2; if a run still fails, `-resume` later |
| `~/.ncbi/user-settings.mkfg` appears in home | Running `vdb-config`/sra-tools **outside** Nextflow (e.g. my probe) with home mounted | Harmless; pipeline tasks use `--no-home` and their own settings file. `rm -r ~/.ncbi` if unwanted |
| sratools FASTQs ~2× bigger than ENA's and md5 differs | Real vs placeholder qualities, different headers/gzip | Expected; compare reads with `scripts/fastq_compare.sbatch`, not gz md5 |
| `WARN: Found the following unidentified headers` in rnaseq | fetchngs appends ENA metadata columns to the samplesheet | Harmless; trim the columns if you want a clean sheet |
| Execution report / timeline fail to render after a failed run | Nextflow report generation on error | Use the trace: `scripts/nf_trace_cpuh.py <head job> results/pipeline_info/execution_trace_*.txt` |

## 9. Next: fetchngs → rnaseq → differentialabundance

### Handoff files

| Step | Hands over | What it looks like |
|---|---|---|
| fetchngs → rnaseq | `results/samplesheet/samplesheet.csv` (+ `results/fastq/*.fastq.gz`) | `sample,fastq_1,fastq_2,strandedness` + 31 ENA columns; absolute FASTQ paths into the fetchngs outdir; `sample` = SRX; `strandedness` = `auto` |
| fetchngs → differentialabundance | `results/samplesheet/samplesheet.csv` or `id_mappings.csv` as the starting point for the sample sheet | Has `sample` and `sample_title` (`30°C, rep1`, …) but **no condition column**: add e.g. `temperature` = `30C`/`37C` by hand |
| rnaseq → differentialabundance | `results/star_salmon/salmon.merged.gene_counts.tsv` + `salmon.merged.gene_lengths.tsv` (or `salmon.merged.gene_counts_length_scaled.tsv`), and the GTF used | Gene × sample matrices; columns are the rnaseq `sample` values; `gene_id`/`gene_name` columns |

differentialabundance inputs (1.5.0 docs): `--input` sample sheet (`--observations_id_col sample` must match the
matrix column names), `--contrasts` CSV with `id,variable,reference,target[,blocking]`
(e.g. `temp_37_vs_30,temperature,30C,37C`), `--matrix salmon.merged.gene_counts.tsv --transcript_length_matrix
salmon.merged.gene_lengths.tsv` (raw counts **without** lengths are not recommended), `--gtf` (same one rnaseq used),
`--study_type rnaseq`.

### Decide before chaining

1. **Download method / qualities**: sratools (real qualities) vs ftp. Decide before rnaseq, since it changes trimming and QC.
2. **Where the FASTQs live**: the samplesheet has absolute paths into the fetchngs outdir. For a real project put
   the fetchngs outdir under `projects/<p>/data/raw/` (read-only after checks) and don't move it afterwards, or
   rewrite the paths.
3. **Sample names**: SRX accessions flow into every rnaseq output and the count-matrix columns. Keep them, or rename
   now (e.g. `T30_rep1`) in the rnaseq samplesheet, before rnaseq runs; renaming after breaks the matrix ↔ sheet match.
4. **Strandedness**: `auto` (Salmon infers it) or set it if known.
5. **Reference**: the same FASTA + GTF for rnaseq and differentialabundance, kept in `references/` with a README.
   For yeast: Ensembl R64-1-1 (current release) rather than the old iGenomes copy; check that `gene_id`/`gene_name`
   exist in the GTF (differentialabundance's defaults).
6. **Design**: which column is the condition, what is the reference level, any blocking factors (batch). Here:
   2 × 30 °C vs 2 × 37 °C; n = 2 per group is enough for a pipeline test, thin for biology. (25 °C samples exist too.)
7. **Versions on this cluster's Nextflow 25.10.0**: rnaseq 3.26.0 works (tested). differentialabundance **2.0.0 needs
   Nextflow ≥ 25.10.4** (same blocker as fetchngs 1.13.0); 1.5.0 declares ≥ 23.10.0 but is **untested** on 25.10.0
   (older pipelines can fail to parse, cf. cutandrun 3.2.2 / `NXF_VER`). Test it with `-profile test` first.
8. **Cost**: this 4-sample yeast set should be a cheap rnaseq run; human data needs an estimate first (CLAUDE.md: ask
   before > ~50 CPU h).

## Files

| Where | What |
|---|---|
| repo `templates/run_fetchngs.sbatch` | Head job: `sbatch -J nf-fetchngs-<m> run_fetchngs.sbatch <version> <method> <ids> [extra.config]` |
| repo `templates/fetchngs_1.12.0_wget.config` | wget container override for 1.12.0 ftp |
| repo `scripts/fetchngs_probe.sbatch` | Network / container / sra-tools pre-flight on a compute node |
| repo `scripts/fastq_compare.sbatch` | Read-level FASTQ comparison across methods |
| repo `scripts/check_rnaseq_samplesheet.py` | Samplesheet vs rnaseq `schema_input.json` |
| repo `scripts/nf_trace_cpuh.py` | CPU h of a run from its trace + sacct |
| `$STORAGE/tests/fetchngs_1.12.0/` | `ids.csv`; `ftp/`, `sratools/`, `aspera/` launch dirs (`results/`, `logs/`); `probe/`, `compare/`, `rnaseq_preview/` |
| `$STORAGE/tests/fetchngs_1.13.0/ftp/` | Attempt 1 (version error) |
| `$SCRATCH/nf_work/tests/fetchngs_1.12.0_{ftp,sratools,aspera,rnaseq_preview}`, `.../aspera_manual` | Work dirs (purged after 28 days; safe to delete now) |
