# Downloading references: Ensembl genomes and MSigDB gene sets

> Tested 2026-11-01 (Ensembl 116, MSigDB 2026.2.Mm) on `condo-siteman`. Nothing needed a login and nothing was blocked.

Run every download as an sbatch job. Don't use the login node: the genome alone is ~0.8 GB, and compute nodes get
about **1 MB/s** from ftp.ensembl.org, so a mouse FASTA + GTF + 3 GMTs took **18 min** at 2 CPU / 2 GB
(0.61 CPU h allocated). Set `--time=02:00:00` (on the condo the default time is 28 days).

## Ensembl

**Latest release**: `curl -s 'https://rest.ensembl.org/info/data?content-type=application/json'` →
`{"releases":[116]}`. This is light enough to run on the login node.

**Files** (example: mouse; humans are the same pattern with `homo_sapiens` / `GRCh38`):

```
https://ftp.ensembl.org/pub/release-<R>/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna.primary_assembly.fa.gz
https://ftp.ensembl.org/pub/release-<R>/gtf/mus_musculus/Mus_musculus.GRCm39.<R>.gtf.gz
https://ftp.ensembl.org/pub/release-<R>/fasta/mus_musculus/dna/CHECKSUMS
https://ftp.ensembl.org/pub/release-<R>/gtf/mus_musculus/CHECKSUMS
```

- Use the **full `.gtf.gz`** with the primary assembly, not `.chr.gtf.gz`. The primary assembly FASTA includes unplaced and unlocalized scaffolds, and the `.chr` GTF drops their genes.
- **The `CHECKSUMS` files are BSD `sum` output** (checksum and 1 KB block count), **not md5**. Verify with `sum`:

```bash
check() {  # <file> <CHECKSUMS file>
  local want got
  want=$(awk -v f="$1" '$3==f{print $1+0, $2+0}' "$2")
  got=$(sum "$1" | awk '{print $1+0, $2+0}')
  echo "$1 expected [$want] got [$got]"
  [[ "$want" == "$got" ]] || { echo "CHECKSUM MISMATCH: $1"; exit 1; }
}
```

  (`$1+0` strips the leading zeros that `sum` prints.) Keep a `sha256sum` next to the files for later re-checks.
- nf-core/rnaseq accepts the `.gz` FASTA/GTF directly. With `--save_reference` it saves the STAR/Salmon indexes under `<outdir>/genome/`, so later runs can pass `--star_index`/`--salmon_index` and skip about 8 CPU h of index building (mouse; see [08](08_resource_sizing.md)).

## MSigDB (gene sets for GSEA)

- **No login for direct downloads.** The release directory is public:
  `https://data.broadinstitute.org/gsea-msigdb/msigdb/release/` (list it to find the newest `<YYYY.N>.Mm` / `.Hs`).
- File pattern: `<release>/<collection>.v<release>.symbols.gmt`, for example:

| Collection | File (mouse) |
|---|---|
| Hallmark | `mh.all.v<release>.symbols.gmt` (50 sets) |
| GO Biological Process | `m5.go.bp.v<release>.symbols.gmt` (~7.7k sets) |
| Reactome | `m2.cp.reactome.v<release>.symbols.gmt` (~1.35k sets) |

- **Mouse**: use the mouse-native `*.Mm` collections, which use mouse gene symbols, rather than mapping human `.Hs` sets.
- **License**: MSigDB (v2022.1+) is **CC BY 4.0**. Extra restrictions apply only to **KEGG** and
  **BioCarta**-derived sets, so check before using `c2.cp.kegg*` / `m2.cp.biocarta`. Terms:
  https://www.gsea-msigdb.org/gsea/msigdb_license_terms.jsp
- MSigDB publishes no checksums, so record your own `sha256sum`.
- nf-core/differentialabundance takes them as `gene_sets_files: a.gmt,b.gmt,c.gmt` (comma-separated, one GSEA run
  per file) and matches symbols to `features_name_col` (e.g. `gene_name` from the GTF).
