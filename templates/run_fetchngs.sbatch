#!/bin/bash
#SBATCH --job-name=nf-fetchngs
#SBATCH --account=compute2-sheila.stewart
#SBATCH --partition=general-cpu
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=6:00:00
#SBATCH --output=logs/%x_%j.log

# Run nf-core/fetchngs with one download method.
# One launch dir per method (it gets its own .nextflow/, results/ and work dir).
# Usage (from the launch dir, which must contain logs/):
#   sbatch -J nf-fetchngs-<method> run_fetchngs.sbatch <version> <method> <ids_file>
# Example:
#   cd $STORAGE/tests/fetchngs_1.12.0/ftp
#   sbatch -J nf-fetchngs-ftp run_fetchngs.sbatch 1.12.0 ftp ../ids.csv fetchngs_1.12.0_wget.config
# Optional 4th argument: an extra -c config (e.g. container override), loaded after the global config.

set -eo pipefail
REVISION="$1"
METHOD="$2"                      # ftp | sratools | aspera (| fastq-dl in >= 1.13.0)
IDS="$(realpath "$3")"
EXTRA_CONFIG="${4:+$(realpath "$4")}"

SCRATCH=/scratch2/fs1/sheila.stewart/john.v
STORAGE=/storage3/fs1/sheila.stewart/Active/john.v
export NXF_APPTAINER_CACHEDIR=$STORAGE/apptainer_cache
export APPTAINER_CACHEDIR=$STORAGE/apptainer_cache

module purge
module load ris
module load slurm/compute2/25.05   # module purge removes Slurm; head job needs sbatch
module load nextflow/25.10.0 apptainer/1.3.6

WORK_DIR="$SCRATCH/nf_work/tests/fetchngs_${REVISION}_${METHOD}"

echo "Host     : $(hostname)"
echo "Pipeline : nf-core/fetchngs $REVISION, --download_method $METHOD"
echo "IDs      : $IDS"
echo "Work     : $WORK_DIR"
echo "Extra -c : ${EXTRA_CONFIG:-none}"
echo "Started  : $(date)"
# sra-tools reads/writes ~/.ncbi by default; record whether a run creates it
echo "~/.ncbi before: $(ls -d ~/.ncbi 2>/dev/null || echo absent)"

cd "$SLURM_SUBMIT_DIR"
nextflow run nf-core/fetchngs -r "$REVISION" -profile apptainer \
  -ansi-log false \
  -c ~/.config/nextflow/nextflow.config \
  ${EXTRA_CONFIG:+-c "$EXTRA_CONFIG"} \
  -work-dir "$WORK_DIR" \
  --input "$IDS" \
  --download_method "$METHOD" \
  --nf_core_pipeline rnaseq \
  --outdir "$SLURM_SUBMIT_DIR/results" \
  -resume

echo "~/.ncbi after: $(ls -d ~/.ncbi 2>/dev/null || echo absent)"
echo "Finished : $(date)"
