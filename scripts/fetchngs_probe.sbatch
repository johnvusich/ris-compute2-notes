#!/bin/bash
#SBATCH --job-name=fetchngs-probe
#SBATCH --account=compute2-sheila.stewart
#SBATCH --partition=general-cpu
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=1:00:00
#SBATCH --output=logs/%x_%j.log

# Pre-flight for nf-core/fetchngs 1.12.0 on a compute node:
#   1. outbound network to ENA / NCBI / container registries
#   2. pull the download containers into the Apptainer cache (same file names
#      Nextflow uses, so the pipeline reuses them) and check each tool exists
#   3. where sra-tools looks for its settings / cache
# Usage (from a dir with logs/):  sbatch fetchngs_probe.sbatch

set -o pipefail
STORAGE=/storage3/fs1/sheila.stewart/Active/john.v
CACHE=$STORAGE/apptainer_cache
export APPTAINER_CACHEDIR=$CACHE

module purge
module load ris
module load apptainer/1.3.6

echo "Host: $(hostname)   Date: $(date)"

echo; echo "== 1. Network (HTTP code, or error) =="
for url in \
  "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=SRR23753578&result=read_run&fields=fastq_ftp" \
  "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR237/078/SRR23753578/SRR23753578.fastq.gz" \
  "ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR237/078/" \
  "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/einfo.fcgi" \
  "https://locate.ncbi.nlm.nih.gov/sdl/2/retrieve?acc=SRR23753578" \
  "https://sra-pub-run-odp.s3.amazonaws.com/" \
  "https://quay.io/v2/" \
  "https://depot.galaxyproject.org/singularity/" \
  "https://raw.githubusercontent.com/nf-core/configs/master/nfcore_custom.config" ; do
  out=$(curl -s -o /dev/null -I --max-time 30 -w '%{http_code} %{time_total}s' "$url" 2>&1); rc=$?
  echo "curl rc=$rc  $out  $url"
done
for hp in fasp.sra.ebi.ac.uk:33001 ftp.sra.ebi.ac.uk:21 ftp.sra.ebi.ac.uk:443; do
  h=${hp%:*}; p=${hp#*:}
  if timeout 10 bash -c "exec 3<>/dev/tcp/$h/$p" 2>/dev/null; then echo "TCP $hp open"; else echo "TCP $hp BLOCKED/unreachable (rc=$?)"; fi
done

echo; echo "== 2. Containers (fetchngs 1.12.0, -profile apptainer -> docker://quay.io/...) =="
for img in \
  biocontainers/python:3.9--1 \
  biocontainers/wget:1.20.1 \
  biocontainers/sra-tools:3.0.8--h9f5acd7_0 \
  biocontainers/mulled-v2-5f89fe0cd045cb1d615630b9261a1d17943a9b6a:6a9ff0e76ec016c3d0d27e0c0d362339f2d787e6-0 \
  biocontainers/aspera-cli:4.14.0--hdfd78af_1 ; do
  f="$CACHE/quay.io-$(echo "$img" | tr '/:' '--').img"
  [ -s "$f" ] || apptainer pull --name "$f" "docker://quay.io/$img" > /dev/null 2>&1 || echo "PULL FAILED: $img"
  echo "-- $img -> $(basename "$f") ($(du -h "$f" 2>/dev/null | cut -f1))"
  apptainer exec "$f" sh -c 'for t in wget md5sum python3 prefetch fasterq-dump vdb-validate vdb-config pigz ascp ascli; do printf "   %-13s %s\n" $t "$(command -v $t || echo -)"; done'
done
ASP="$CACHE/quay.io-biocontainers-aspera-cli-4.14.0--hdfd78af_1.img"
echo "-- aspera: key file + versions"
apptainer exec "$ASP" sh -c 'ls -l /usr/local/etc/aspera/aspera_bypass_dsa.pem; ascp --version 2>&1 | head -2; ascli --version 2>&1 | head -1'

echo; echo "== 3. sra-tools settings / cache =="
echo "~/.ncbi before: $(ls -d ~/.ncbi 2>/dev/null || echo absent)"
SRA="$CACHE/quay.io-biocontainers-sra-tools-3.0.8--h9f5acd7_0.img"
apptainer exec "$SRA" vdb-config -o n NCBI_SETTINGS
apptainer exec "$SRA" sh -c 'prefetch --version 2>&1 | head -2'
echo "~/.ncbi after: $(ls -d ~/.ncbi 2>/dev/null || echo absent)"
echo "Done: $(date)"
