# ---- RIS Compute2 (append to ~/.bashrc, then: source ~/.bashrc) -------------
export SCRATCH=/scratch2/fs1/sheila.stewart/john.v
export STORAGE=/storage3/fs1/sheila.stewart/Active/john.v
export PROJECTS=$STORAGE/projects
export NXF_APPTAINER_CACHEDIR=$STORAGE/apptainer_cache
export APPTAINER_CACHEDIR=$STORAGE/apptainer_cache

# Load Slurm on a login node (not automatic on Compute2)
alias c2='module purge && module load ris slurm/compute2/25.05'

# Shortcuts
alias cds='cd $SCRATCH'
alias cdp='cd $PROJECTS'
alias sq='squeue --me'
alias space='df -h /home/john.v /scratch2/fs1/sheila.stewart /storage3/fs1/sheila.stewart'
