#!/bin/bash
#SBATCH --job-name=fastq-compare
#SBATCH --account=compute2-sheila.stewart
#SBATCH --partition=general-cpu
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --time=1:00:00
#SBATCH --output=logs/%x_%j.log

# Compare FASTQs of the same runs downloaded by different fetchngs methods.
# Usage (from a dir with logs/):
#   sbatch fastq_compare.sbatch <results_dir_method1> <results_dir_method2> ...
# Each results dir must contain fastq/*.fastq.gz. Prints one TSV row per file:
#   method, file, bytes, gz md5, reads, md5 of read IDs (first word of header), md5 of sequences,
#   md5 of qualities, distinct quality characters (first 200,000 reads).
# Equal seq/qual md5 = same reads, whatever the header format or gzip settings.

set -eo pipefail
printf 'method\tfile\tbytes\tgz_md5\treads\tid_md5\tseq_md5\tqual_md5\tqual_chars\n'
for R in "$@"; do
  m=$(basename "$(dirname "$R")")
  for f in "$R"/fastq/*.fastq.gz; do
    (
      col() { zcat "$f" | awk -v n="$1" 'NR%4==n' ; }
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$m" "$(basename "$f")" "$(stat -c %s "$f")" \
        "$(md5sum < "$f" | cut -c1-32)" "$(col 2 | wc -l)" \
        "$(col 1 | awk '{print $1}' | md5sum | cut -c1-32)" "$(col 2 | md5sum | cut -c1-32)" \
        "$(col 0 | md5sum | cut -c1-32)" "$(col 0 | head -n 200000 | fold -w1 | sort -u | tr -d '\n')"
    ) &
    while [ "$(jobs -rp | wc -l)" -ge "${SLURM_CPUS_PER_TASK:-4}" ]; do wait -n; done
  done
done
wait
