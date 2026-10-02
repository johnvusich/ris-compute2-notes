#!/bin/bash
#SBATCH --job-name=nf-__ANALYSIS__
#SBATCH --account=compute2-sheila.stewart
#SBATCH --partition=general-cpu
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=48:00:00
#SBATCH --output=logs/%x_%j.log
# ^ relative to the directory I run `sbatch` from (the analysis dir).
#   logs/ MUST exist before submitting or Slurm cannot write the log.

# =============================================================================
# Nextflow head job for Compute2.
# Submit FROM the analysis directory:
#   cd /storage3/fs1/sheila.stewart/Active/john.v/projects/<project>/analyses/<analysis>
#   sbatch run_nextflow.sbatch
# The head job only coordinates; each pipeline step is its own Slurm job.
# =============================================================================

set -eo pipefail   # (no -u: module scripts can trip on unset variables)

# ---- What to run (edit per analysis) ----------------------------------------
PIPELINE="nf-core/rnaseq"
REVISION="3.26.0"               # always pin; check NF version requirement in release notes
PROJECT="__PROJECT__"
ANALYSIS="__ANALYSIS__"

# ---- Paths -------------------------------------------------------------------
STORAGE=/storage3/fs1/sheila.stewart/Active/john.v
SCRATCH=/scratch2/fs1/sheila.stewart/john.v

LAUNCH_DIR="$SLURM_SUBMIT_DIR"                         # analysis dir: .nextflow/, .nextflow.log, -resume cache
WORK_DIR="$SCRATCH/nf_work/$PROJECT/$ANALYSIS"         # big temp files (28-day purge!)
OUT_DIR="$LAUNCH_DIR/results"                          # final results on storage3

export NXF_APPTAINER_CACHEDIR="$STORAGE/apptainer_cache"
export APPTAINER_CACHEDIR="$STORAGE/apptainer_cache"

# ---- Software ----------------------------------------------------------------
module purge
module load ris nextflow/25.10.0 apptainer/1.3.6

# ---- Run ---------------------------------------------------------------------
cd "$LAUNCH_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"

echo "Pipeline : $PIPELINE $REVISION"
echo "Launch   : $LAUNCH_DIR"
echo "Work     : $WORK_DIR"
echo "Outdir   : $OUT_DIR"
echo "Started  : $(date)"

nextflow run "$PIPELINE" -r "$REVISION" \
  -c ~/.config/nextflow/nextflow.config \
  -params-file params.yaml \
  -work-dir "$WORK_DIR" \
  --outdir "$OUT_DIR" \
  -resume
# Optional per-analysis resource overrides: add  -c custom.config
# (Do NOT name it nextflow.config in the launch dir — that gets auto-loaded.)
# For the nf-core test dataset instead of params.yaml:  -profile test

echo "Finished : $(date)"
