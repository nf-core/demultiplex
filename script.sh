#!/bin/bash
#SBATCH --job-name=bbcl2fastq       # Job name
#SBATCH --time=23:00:00               # Time limit hrs:min:sec
#SBATCH --mem-per-cpu=5G
##SBATCH --ntasks-per-node=20
#SBATCH --ntasks=20                    # Usually run on 4 CPUS except Undetermined that will need 20 CPUs
##SBATCH --mem=32GB                     # Job memory request
##SBATCH --nodes=1
#SBATCH --mail-type=END,FAIL          # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=mmansegt@navarra.es     # Where to send mail
##SBATCH --output=Array.%J_%a.out
##SBATCH --error=Array.%J_%a.error
#SBATCH --output=output_%J.txt
#SBATCH --error=error_output_%J.txt
##SBATCH --partition=ABGC_Std
#SBATCH -p intel_std              # Queue name
##SBATCH --array=0-47               # Desglose en n tares en el mismo nodo, starting from 0 to 47 ...   48 samples #ori:48

# To run just
# sbatch script.sh

# Just use when not summiting to SLURM. COMMENT IT!!!
## SLURM_ARRAY_TASK_ID='2'

# Need to get run statitistics on clusters, used and unused barcodes!!!
pwd; hostname; date
#echo 'PATH=$PATH:/home/projects/LAB/Software/bin/' >> ~/.bashrc   #Para descomprimir oras hay que descomentar este comando
source ~/.bashrc
module purge
source ~/anaconda3/etc/profile.d/conda.sh

# Job variables
# THREADS=${SLURM_JOB_CPUS_PER_NODE}
# THREADS=5

# Input directory
cd /data/scratch/LAB/temp_demultiplex/nfcore_demultiplex/mansego/nfcore_demultiplex/

conda activate bcl2fastq

bcl2fastq \
      --tiles s_1 \
      --output-dir test/iSeq/results \
      --runfolder-dir test/iSeq/20230719_FS1000138516_BTR67709-2111 \
      --sample-sheet  test/iSeq/SampleSheet.csv \
      --processing-threads 12
