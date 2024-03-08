# Initial setup
# Run in HPC
# mamba create -c conda-forge -c bioconda -c defaults --name nf_core_2023 python nextflow nf-core singularity python-keycloak

# Locate file

cd nfcore_demultiplex/

# Load modules and activate conda environment
ml purge
module use --append /opt/shared/modules/all/
module use --append /software/shared/modules/all
# conda activate nf_core
#conda init
#conda activate nf_core_2023
module load singularity/3.4.1

# Test 1 run from nf_core/demultiplex

#nextflow run nf-core/demultiplex \
#    -profile test,singularity \
#    --outdir test_nf_core \
#    -c /data/scratch/LAB/temp_demultiplex/nfcore_demultiplex/mansego/nfcore_demultiplex/demultiplex.conf

# Test 2  run from nfcore_demultiplex/main.nf
# nextflow run nfcore_demultiplex/main.nf \
#    -profile test,singularity \
#    --outdir test_nf_core_fork \
#    -c /data/scratch/LAB/temp_demultiplex/nfcore_demultiplex/mansego/nfcore_demultiplex/demultiplex.conf

## Test 3 Full test https://github.com/nf-core/demultiplex/tree/1.4.1/conf/test_full.config

# nextflow run nf-core/demultiplex -profile test_full,singularity --outdir test_nf_core_full -c /data/scratch/LAB/temp_demultiplex/nfcore_demultiplex/mansego/nfcore_demultiplex/demultiplex.conf


# Real data iSeq
 nextflow run nfcore_demultiplex/main.nf \
     -profile singularity \
     --input ./samplesheet_real.csv \
     --outdir test_nf_core_fork_iSeq \
     --demultiplexer 'bcl2fastq' \
     -c /data/scratch/LAB/temp_demultiplex/nfcore_demultiplex/mansego/nfcore_demultiplex/demultiplex.conf \
     #-resume


# Real data NovaSeq
# nextflow run nfcore_demultiplex/main.nf \
#    -profile singularity \
#    --input samplesheet_NovaSeq.csv \
#    --outdir /data/scratch/LAB/temp_demultiplex/nfcore_demultiplex/mansego/test_nfcore_NovaSeq \
#    --demultiplexer 'bcl2fastq' \
#    -c /data/scratch/LAB/temp_demultiplex/nfcore_demultiplex/mansego/nfcore_demultiplex/demultiplex.conf \
#    #-resume
