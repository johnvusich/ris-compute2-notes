#!/bin/bash
#SBATCH --job-name=nf-test
#SBATCH --account=compute2-sheila.stewart
#SBATCH --partition=general-cpu
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%j.log

# Test any nf-core pipeline with its built-in test profile.
# Usage (from the test dir, which must contain logs/):
#   sbatch -J nf-<pipeline>-test run_nf_test.sbatch <pipeline> <version>
# Example:
#   sbatch -J nf-cutandrun-test run_nf_test.sbatch cutandrun 3.2.2

set -eo pipefail
PIPELINE="$1"
REVISION="$2"

SCRATCH=/scratch2/fs1/sheila.stewart/john.v
STORAGE=/storage3/fs1/sheila.stewart/Active/john.v
export NXF_APPTAINER_CACHEDIR=$STORAGE/apptainer_cache
export APPTAINER_CACHEDIR=$STORAGE/apptainer_cache

module purge
module load ris nextflow/25.10.0 apptainer/1.3.6

cd "$SLURM_SUBMIT_DIR"
nextflow run "nf-core/$PIPELINE" -r "$REVISION" -profile test \
  -ansi-log false \
  -c ~/.config/nextflow/nextflow.config \
  -work-dir "$SCRATCH/nf_work/tests/${PIPELINE}_${REVISION}" \
  --outdir "$SLURM_SUBMIT_DIR/results" \
  -resume
