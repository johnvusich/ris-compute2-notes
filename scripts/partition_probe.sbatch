#!/bin/bash
#SBATCH --job-name=probe
#SBATCH --account=compute2-sheila.stewart
#SBATCH --cpus-per-task=1
#SBATCH --mem=100M
#SBATCH --time=00:02:00
#SBATCH --output=logs/%x_%j.log

# Trivial job to compare partitions: where it ran, what Slurm allocated, which QOS applied.
# Partition is given on the command line so it's the only thing that changes between runs.
# Usage (from a dir containing logs/):
#   sbatch -p condo-siteman -J probe-condo ~/ris-compute2-notes/scripts/partition_probe.sbatch
#   sbatch -p general-cpu   -J probe-gen   ~/ris-compute2-notes/scripts/partition_probe.sbatch

module load ris slurm/compute2/25.05 2>/dev/null   # sacct/scontrol inside the job

echo "host      : $(hostname)"
echo "date      : $(date)"
echo "nproc     : $(nproc)   (cores visible to the job)"
echo "cpu model : $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
env | grep -E '^SLURM_(JOB_PARTITION|JOB_QOS|JOB_ACCOUNT|CPUS_ON_NODE|CPUS_PER_TASK|MEM_PER_CPU|MEM_PER_NODE|JOB_CPUS_PER_NODE)=' | sort
echo "--- scontrol show job"
scontrol show job "$SLURM_JOB_ID"
echo "--- sacct"
sacct -j "$SLURM_JOB_ID" -X -P \
  --format=JobID,Partition,QOS,Account,AllocCPUS,ReqMem,ReqTRES%60,AllocTRES%60,Submit,Start,Timelimit,NodeList
