#!/bin/bash
#SBATCH --job-name=nf-condo
#SBATCH --account=compute2-sheila.stewart
#SBATCH --partition=condo-siteman
#SBATCH --cpus-per-task=2          # = 1 physical core on the condo (cores have 2 threads)
#SBATCH --mem=4G
#SBATCH --time=01:00:00            # ALWAYS set: condo default is 28 days
#SBATCH --output=logs/%x_%j.log

# Nextflow head job on the Siteman condo; tasks also go to the condo via siteman_condo.config.
# Usage (from the launch dir, which must contain logs/):
#   sbatch -J nf-hello-condo run_nf_condo.sbatch nextflow-io/hello v1.3 none
#   sbatch -J nf-rnaseq-condo -t 2:00:00 run_nf_condo.sbatch nf-core/rnaseq 3.26.0 test,apptainer [extra.config]
# Argument 3 is the -profile ("none" for no profile). Optional 4th: extra -c config, loaded last.

set -eo pipefail
PIPELINE="$1"
REVISION="$2"
PROFILE="$3"
EXTRA_CONFIG="${4:+$(realpath "$4")}"

SCRATCH=/scratch2/fs1/sheila.stewart/john.v
STORAGE=/storage3/fs1/sheila.stewart/Active/john.v
export NXF_APPTAINER_CACHEDIR=$STORAGE/apptainer_cache
export APPTAINER_CACHEDIR=$STORAGE/apptainer_cache

module purge
module load ris
module load slurm/compute2/25.05   # module purge removes Slurm; head job needs sbatch
module load nextflow/25.10.0 apptainer/1.3.6

NAME="$(basename "$PIPELINE")_${REVISION}_condo"
echo "Host     : $(hostname)  (partition $SLURM_JOB_PARTITION, $SLURM_CPUS_ON_NODE CPUs)"
echo "Pipeline : $PIPELINE $REVISION, profile $PROFILE"
echo "Extra -c : ${EXTRA_CONFIG:-none}"
echo "Started  : $(date)"

cd "$SLURM_SUBMIT_DIR"
nextflow run "$PIPELINE" -r "$REVISION" \
  $([[ $PROFILE != none ]] && echo "-profile $PROFILE") \
  -ansi-log false \
  -c ~/.config/nextflow/nextflow.config \
  -c ~/ris-compute2-notes/templates/siteman_condo.config \
  ${EXTRA_CONFIG:+-c "$EXTRA_CONFIG"} \
  -work-dir "$SCRATCH/nf_work/tests/$NAME" \
  --outdir "$SLURM_SUBMIT_DIR/results" \
  -with-trace -with-report \
  -resume

echo "Finished : $(date)"
