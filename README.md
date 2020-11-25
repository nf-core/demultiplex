# ![nf-core/demultiplex](docs/images/nf-core-demultiplex_logo.png)

[![GitHub Actions CI Status](https://github.com/nf-core/demultiplex/workflows/nf-core%20CI/badge.svg)](https://github.com/nf-core/demultiplex/actions)
[![GitHub Actions Linting Status](https://github.com/nf-core/demultiplex/workflows/nf-core%20linting/badge.svg)](https://github.com/nf-core/demultiplex/actions)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A520.04.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](https://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/demultiplex.svg)](https://hub.docker.com/r/nfcore/demultiplex)
[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23demultiplex-4A154B?logo=slack)](https://nfcore.slack.com/channels/demultiplex)

## Introduction

**nf-core/demultiplex** is a bioinformatics pipeline used to demultiplex the raw data produced by next generation sequencing machines. At present, only Illumina sequencing data is supported.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker containers making installation trivial and results highly reproducible.

## Pipeline summary

1. Reformatting the input sample sheet
    * Searches for [Data] tag
    * Splits 10X single cell samples into 10X, 10X-ATAC and 10X-DNA .csv files by searching in the sample sheet column DataAnalysisType for `10X-3prime`, `10X-ATAC` and `10X-CNV`.
    * Outputs the results of needing to run specific processes in the pipeline (can be only 10X single cell samples, mix of 10X single cell with non single cell samples or all non single cell samples)
2. Checking the sample sheet for downstream error causing samples such as:
    * a mix of short and long indexes on the same lane
    * a mix of single and dual indexes on the same lane
3. Processes that only run if there are issues within the sample sheet found by the sample sheet check process (CONDITIONAL):
      1. Creates a new sample sheet with any samples that would cause an error removed and create a a txt file of a list of the removed problem samples
      2. Run [`bcl2fastq`](http://emea.support.illumina.com/sequencing/sequencing_software/bcl2fastq-conversion-software.html) on the newly created sample sheet and output the Stats.json file
      3. Parsing the Stats.json file for the indexes that were in the problem samples list.
      4. Recheck newly made sample sheet for any errors or problem samples that did not match any indexes in the Stats.json file. If there is still an issue the pipeline will exit at this stage.
4. Single cell 10X sample processes (CONDITIONAL):
      NOTE: Must create CONFIG to point to CellRanger genome References
      1. Cell Ranger mkfastq runs only when 10X samples exist. This will run the process with [`CellRanger`](https://support.10xgenomics.com/single-cell-gene-expression/software/pipelines/latest/what-is-cell-ranger), [`CellRanger ATAC`](https://support.10xgenomics.com/single-cell-atac/software/pipelines/latest/what-is-cell-ranger-atac), and [`Cell Ranger DNA`](https://support.10xgenomics.com/single-cell-dna/software/pipelines/latest/what-is-cell-ranger-dna) depending on which sample sheet has been created.
      2. Cell Ranger Count runs only when 10X samples exist. This will run the process with [`Cell Ranger Count`](https://support.10xgenomics.com/single-cell-gene-expression/software/pipelines/latest/using/count), [`Cell Ranger ATAC Count`](https://support.10xgenomics.com/single-cell-atac/software/pipelines/latest/using/count), and [`Cell Ranger DNA CNV`](https://support.10xgenomics.com/single-cell-dna/software/pipelines/latest/using/cnv)depending on the output from Cell Ranger mkfastq. 10X reference genomes can be downloaded from the 10X site, a new config would have to be created to point to the location of these. Must add config to point Cell Ranger to genome references if used outside the Crick profile.
5. [`bcl2fastq`](http://emea.support.illumina.com/sequencing/sequencing_software/bcl2fastq-conversion-software.html) (CONDITIONAL):
      1. Runs on either the original sample sheet that had no error prone samples or on the newly created sample sheet created from the extra steps.
      2. This is only run when there are samples left on the sample sheet after removing the single cell samples.
      3. The arguments passed in bcl2fastq are changeable parameters that can be set on the command line when initiating the pipeline. Takes into account if Index reads will be made into FastQ's as well
6. [`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) runs on the pooled fastq files from all the conditional processes.
7. [`FastQ Screen`](https://www.bioinformatics.babraham.ac.uk/projects/fastq_screen/) runs on the pooled results from all the conditional processes. Must have own fastq_screen config to direct to.
8. [`MultiQC`](https://multiqc.info/docs/) runs on each projects FastQC results produced.
9. [`MultiQC_all`](https://multiqc.info/docs/) runs on all FastQC results produced.

### Samplesheet format

The input sample sheet must adhere to Illumina standards as outlined in the table below. Additional columns for `DataAnalysisType` and `ReferenceGenome` are required for the correct processing of 10X samples. The order of columns does not matter but the case of column name's does.

| Lane | Sample_ID | index    | index2   | Sample_Project | ReferenceGenome | DataAnalysisType |
|------|-----------|----------|----------|----------------|-----------------|------------------|
| 1    | ABC11A2   | TCGATGTG | CTCGATGA | PM10000        | Homo sapiens    | Whole Exome      |
| 2    | SAG100A10 | SI-GA-C1 |          | SC18100        | Mus musculus    | 10X-3prime       |
| 3    | CAP200A11 | CTCGATGA |          | PM18200        | Homo sapiens    | Other            |

## Quick Start

1. Install [`nextflow`](https://nf-co.re/usage/installation)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) or [`Podman`](https://podman.io/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```bash
    nextflow run nf-core/demultiplex -profile test,<docker/singularity/podman/conda/institute>
    ```

    > Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.

4. Start running your own analysis!

    ```bash
    nextflow run nf-core/demultiplex -profile <docker/singularity/podman/conda/institute> --input samplesheet.csv  --run_dir /path/to/run/directory/*
    ```

See [usage docs](https://nf-co.re/demultiplex/usage) for all of the available options when running the pipeline.

## Documentation

The nf-core/demultiplex pipeline comes with documentation about the pipeline: [usage](https://nf-co.re/demultiplex/usage) and [output](https://nf-co.re/demultiplex/output).

## Credits

The nf-core/demultiplex pipeline was written by Chelsea Sawyer from The Bioinformatics & Biostatistics Group for use at The Francis Crick Institute, London.

Many thanks to others who have helped out along the way too, including (but not limited to): [`@ChristopherBarrington`](https://github.com/ChristopherBarrington), [`@drpatelh`](https://github.com/drpatelh), [`@danielecook`](https://github.com/danielecook), [`@escudem`](https://github.com/escudem), [`@crickbabs`](https://github.com/crickbabs)

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#demultiplex` channel](https://nfcore.slack.com/channels/demultiplex) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citation

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
> ReadCube: [Full Access Link](https://rdcu.be/b1GjZ)
