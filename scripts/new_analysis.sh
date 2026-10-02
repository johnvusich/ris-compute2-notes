#!/bin/bash
# =============================================================================
# Scaffold a new project and/or analysis on storage3, with matching scratch dir.
#
# Usage:
#   bash new_analysis.sh <project> <analysis>
#
# Example:
#   bash new_analysis.sh 2026_senCAF_cutrun rnaseq_pilot
#
# Creates (if missing):
#   $STORAGE/projects/<project>/{data/raw,data/processed,metadata,docs,analyses}
#   $STORAGE/projects/<project>/analyses/<YYYY-MM-DD>_<analysis>/{logs,results}
#       + run_nextflow.sbatch, params.yaml, README.md (from templates/)
#   $SCRATCH/nf_work/<project>/<YYYY-MM-DD>_<analysis>
# =============================================================================
set -eo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: bash $0 <project> <analysis>"
    exit 1
fi

PROJECT="$1"
ANALYSIS="$(date +%Y-%m-%d)_$2"

STORAGE=/storage3/fs1/sheila.stewart/Active/john.v
SCRATCH=/scratch2/fs1/sheila.stewart/john.v
TEMPLATES="$(cd "$(dirname "$0")/../templates" && pwd)"

PROJ_DIR="$STORAGE/projects/$PROJECT"
ANAL_DIR="$PROJ_DIR/analyses/$ANALYSIS"
WORK_DIR="$SCRATCH/nf_work/$PROJECT/$ANALYSIS"

# ---- Project skeleton ---------------------------------------------------------
mkdir -p "$PROJ_DIR"/{data/raw,data/processed,metadata,docs,analyses}
if [[ ! -f "$PROJ_DIR/README.md" ]]; then
    cat > "$PROJ_DIR/README.md" << EOF
# $PROJECT

**Started:** $(date +%Y-%m-%d)
**Question / aim:**
**Samples:** see metadata/
**Raw data source:** (sequencing core, delivery date, Globus task ID)

## Analyses
| Date_name | Pipeline + version | Status | Notes |
|---|---|---|---|
EOF
fi

# ---- Analysis skeleton --------------------------------------------------------
if [[ -d "$ANAL_DIR" ]]; then
    echo "Analysis dir already exists: $ANAL_DIR"
    exit 1
fi
mkdir -p "$ANAL_DIR"/{logs,results} "$WORK_DIR"

sed -e "s/__PROJECT__/$PROJECT/g" -e "s/__ANALYSIS__/$ANALYSIS/g" \
    "$TEMPLATES/run_nextflow.sbatch" > "$ANAL_DIR/run_nextflow.sbatch"
cp "$TEMPLATES/params.yaml" "$ANAL_DIR/params.yaml"

cat > "$ANAL_DIR/README.md" << EOF
# $ANALYSIS  ($PROJECT)

- **Pipeline / version:**
- **Nextflow / Apptainer modules:**
- **Input samplesheet:**
- **Reference:**
- **Work dir (scratch, purged 28 days after creation):** $WORK_DIR
- **Slurm job IDs:**
- **Outcome / notes:**

## Run
\`\`\`bash
cd $ANAL_DIR
sbatch run_nextflow.sbatch
\`\`\`
EOF

echo "Project : $PROJ_DIR"
echo "Analysis: $ANAL_DIR"
echo "Work    : $WORK_DIR"
echo
echo "Next:"
echo "  cd $ANAL_DIR"
echo "  # edit params.yaml, add samplesheet.csv, set PIPELINE/REVISION in run_nextflow.sbatch"
echo "  sbatch run_nextflow.sbatch"
