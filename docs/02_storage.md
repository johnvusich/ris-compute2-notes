# Storage on RIS Compute2

## Overview

| Space | Path | Size | Backed up? | Purged? | Use for |
|---|---|---|---|---|---|
| Home | `/home/john.v` | 50 GB (per user) | — | No | Configs, dotfiles, small scripts |
| Scratch2 | `/scratch2/fs1/sheila.stewart/john.v` | 10 TB **shared by lab** | **No** | **Yes — 28 days after creation** | Nextflow `work/`, temp files |
| Storage3 Active | `/storage3/fs1/sheila.stewart/Active/john.v` | Lab allocation | Yes (+ 1 week of snapshots) | No | Raw data, results, references, containers |
| Storage3 Archive | `/storage3/fs1/sheila.stewart/Archive` (only if enabled) | Lab allocation | Yes (tape) | No | Finished projects |

### What "storage3" means

One storage allocation (`sheila.stewart` on the storage3 platform), reachable three ways:

| From | Address |
|---|---|
| Compute2 login/compute nodes | `/storage3/fs1/sheila.stewart` |
| Globus | RIS storage3 endpoint, path `/storage3/fs1/sheila.stewart` |
| Mac Finder (⌘K, on campus or VPN) | `smb://storage3.ris.wustl.edu/sheila.stewart` |

## Rules I follow

1. **Never keep the only copy of anything on scratch.** It disappears after 28 days with no notice.
2. **Nextflow `work/` → scratch. `--outdir` → storage3.**
3. **`-resume` only works while the work dir still exists** (~4 weeks max). Re-run failures promptly.
4. **Apptainer image cache → storage3.** Not home (fills 50 GB fast), not scratch (purged → re-downloads).
5. **Raw data is read-only** once checksums are verified (`chmod -R a-w <raw_dir>`).
6. **Home stays small:** configs and scripts only.

## Checking space

`quota` does **not** work on Compute2 (`Operation not permitted`). Use `df`:

```bash
df -h /home/john.v
df -h /scratch2/fs1/sheila.stewart
df -h /storage3/fs1/sheila.stewart
```

Run `df` from a login node or interactive session. RIS storage docs note that inside
non-interactive batch jobs `df` on storage can report a cache layer rather than true
allocation usage.

What is using the space:

```bash
du -sh /storage3/fs1/sheila.stewart/Active/*          # by lab member (slow on big trees)
du -sh /storage3/fs1/sheila.stewart/Active/john.v/*   # my directories
du -sh /scratch2/fs1/sheila.stewart/*                 # lab scratch by member
du -sh ~/* ~/.[!.]* 2>/dev/null | sort -h             # what is filling home (.nextflow, .apptainer, ...)
```

Find my scratch directories approaching the purge (older than ~21 days):

```bash
find /scratch2/fs1/sheila.stewart/john.v -maxdepth 3 -type d -mtime +21
```

## Recovering deleted files (storage3 Active only)

```bash
ls /storage3/fs1/sheila.stewart/Active/.snapshots/
# copy back from a snapshot taken before the deletion
cp -a /storage3/fs1/sheila.stewart/Active/.snapshots/<snapshot>/john.v/<path> <destination>
```

Snapshots cover about one week. **Scratch has no snapshots.**

## Moving data

```bash
# Between spaces on Compute2 (resumable, preserves attributes)
rsync -avh --progress <src>/ <dest>/

# From Mac (on VPN) to storage3
rsync -avh --progress ./local_dir/ \
  john.v@c2-login-001.ris.wustl.edu:/storage3/fs1/sheila.stewart/Active/john.v/<dest>/
```

- Large transfers / sequencing core deliveries → **Globus**.
- After any transfer, verify checksums: `md5sum -c md5sums.txt`.
- Archive tier (if enabled): `tar` the finished project, then `rsync` Active → Archive.
