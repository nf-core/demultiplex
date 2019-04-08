# nf-core/demultiplex
**Demultiplexing pipeline for Illumina data**
**IN PROGRESS**

[![Build Status](https://travis-ci.org/nf-core/demultiplex.svg?branch=master)](https://travis-ci.org/nf-core/demultiplex)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.32.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/demultiplex.svg)](https://hub.docker.com/r/nfcore/demultiplex)
![Singularity Container available](
https://img.shields.io/badge/singularity-available-7E4C74.svg)

### Introduction
**nf-core/demultiplex** is a bioinformatics demultiplexing pipeline used for multiple types of data input from sequencing runs.
The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker / singularity containers making installation trivial and results highly reproducible.

### Pipeline summary
1. Reformatting the input sample sheet it collapse iCLIP samples into one per lane, split 10X samples into 10X, 10XATAC and 10XDNA. This process also outputs the results of needing to run specific processes in the pipeline (only 10X samples, mix of 10X and non 10X samples)
2. Checking the sample sheet for error causing samples such as a mix of short and long barcodes on same lane, mix of single and dual on the same lane, and both of the latter. 
3. Create a new sample sheet with any samples that would cause an error removed and create a a txt file of a list of the removed problem samples
4. Run bcl2fastq on the newly created sample sheet and output the Stats.json file
5. Parsing the Stats.json file for the indexes that were in the problem samples list.
6. Recheck newly made sample sheet for any errors or problem samples that did not match any indexes in the Stats.json file. If there is still an issue the pipeline will exit at this stage.
7. Run bcl2fastq on either the original sample sheet that had no error prone samples or on the newly created sample sheet created from the extra steps. This is only run when there are samples left on the sample sheet after removing the single cell samples. The arguments passed in bcl2fastq are changable parameters that can be set when starting to run the pipeline
8. Cell Ranger mkfastq runs only when 10X samples exist. This will run the process with CellRanger, CellRanger ATAC, and Cell Ranger DNA depending on which sample sheet has been created.
9. Cell Ranger Count runs only when 10X samples exist. This will run the process with CellRanger, CellRanger ATAC, and Cell Ranger DNA depending on the output from Cell Ranger mkfastq.
10. FastQC will pool the fastq files from all the conditional processes and run [`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) on them.
11. FastQScreen takes the pooled results from all the conditional processes and runs [`FastQ Screen`](https://www.bioinformatics.babraham.ac.uk/projects/fastq_screen/) on them.
12. MultiQC takes the results from FastQC and amalgamates the results [`MultiQC`](https://multiqc.info/docs/)



### Documentation
The nf-core/demultiplex pipeline comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](docs/installation.md)
2. Pipeline configuration
    * [Local installation](docs/configuration/local.md)
    * [Adding your own system](docs/configuration/adding_your_own.md)
    * [Reference genomes](docs/configuration/reference_genomes.md)  
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](docs/troubleshooting.md)

<!-- TODO nf-core: Add a brief overview of what the pipeline does and how it works -->

### Credits
nf-core/demultiplex was originally written by Chelsea Sawyer.
