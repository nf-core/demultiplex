# nf-core/demultiplex: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.6.0 - 2025-02-18

### `Added`

- [#308](https://github.com/nf-core/demultiplex/pull/308) Add samplesheet generation for nf-core/sarek and nf-core/methylseq.

### `Changed`

### `Fixed`

- [#310](https://github.com/nf-core/demultiplex/pull/310) Replace [] with null as default

## 1.5.4 - 2024-12-03

### `Added`

### `Changed`

- [#291](https://github.com/nf-core/demultiplex/pull/291) Updated `samshee` module to the latest version
- [#296](https://github.com/nf-core/demultiplex/pull/296) Bump to version 1.5.4.

### `Fixed`

- [#288](https://github.com/nf-core/demultiplex/pull/288) Fix `test_full` by validating parameters in `lenientMode` and fix workflow megatest workflow dispatch.
- [#294](https://github.com/nf-core/demultiplex/pull/294) Fix workflow.onComplete email sending feature.

## 1.5.3 - 2024-11-06

### `Added`

### `Changed`

- [#275](https://github.com/nf-core/demultiplex/pull/275) Update samshee module from nf-core.
- [#276](https://github.com/nf-core/demultiplex/pull/276) Template update for nf-core/tools v3.0.2
- [#284](https://github.com/nf-core/demultiplex/pull/284) nf-core modules and subworkflows update. nf-test version update.
- [#285](https://github.com/nf-core/demultiplex/pull/285) Bump to version 1.5.3.

### `Fixed`

- [#277](https://github.com/nf-core/demultiplex/pull/277) Improved samplesheet generation to always produce all types of samplesheets, added the ability to explicitly set strandedness, and fixed output paths to correctly reflect the `publishDir` subdirectory structure.
- [#281](https://github.com/nf-core/modules/pull/6932) Update cellranges/mkfastq module to fix missing reports and stats outputs.
- [#282](https://github.com/nf-core/demultiplex/pull/282) Fixed downstream samplesheet paths and `publishDir` config.

## 1.5.2 - 2024-10-07

### `Changed`

- [#263](https://github.com/nf-core/demultiplex/pull/263) Updated all modules and subworkflows, and added new bclconvert test profile.

## 1.5.1 - 2024-08-20

### `Fixed`

- [#253](https://github.com/nf-core/demultiplex/pull/253) Fixed mkfastq output channels.
- [#265](https://github.com/nf-core/demultiplex/pull/265) Fixed adapter removal for input samplesheets without lane information.

## 1.5.0 - 2024-08-12

### `Added`

- [#202](https://github.com/nf-core/demultiplex/pull/202) Added cellranger mkfastq subworkflow for demultiplexing 10x samples.
- [#206](https://github.com/nf-core/demultiplex/pull/206) Add test with uncompressed data.
- [#208](https://github.com/nf-core/demultiplex/pull/208) Added parameter for removing adapter information from samplesheets.
- [#210](https://github.com/nf-core/demultiplex/pull/210) Add checkqc module.
- [#212](https://github.com/nf-core/demultiplex/pull/212) Added resource setting arguments to mkfastq module to work with github CI.
- [#214](https://github.com/nf-core/demultiplex/pull/214) Added test_pe (paired end) profile.
- [#220](https://github.com/nf-core/demultiplex/pull/220) Added kraken2.
- [#221](https://github.com/nf-core/demultiplex/pull/221) Added checkqc_config to pipeline schema.
- [#225](https://github.com/nf-core/demultiplex/pull/225) Added test profile for multi-lane samples, updated handling of such samples and adapter trimming.
- [#234](https://github.com/nf-core/demultiplex/pull/234) Added module for samplesheet validation.
- [#236](https://github.com/nf-core/demultiplex/pull/236) Add samplesheet generation.

### `Changed`

- [#204](https://github.com/nf-core/demultiplex/pull/204) Update to latest bcl_demultiplex sub workflow.
- [#210](https://github.com/nf-core/demultiplex/pull/210) Update bcl2fastq and bcl_demultiplex.
- [#214](https://github.com/nf-core/demultiplex/pull/214) Updated method for removing adapters from samplesheet, added custom AdapterRemover function.
- [#210](https://github.com/nf-core/demultiplex/pull/212) Update bcl2fastq and bcl_demultiplex.
- [#216](https://github.com/nf-core/demultiplex/pull/216) List fastq reports for R1 and R2 separately in multiqc report.
- [#219](https://github.com/nf-core/demultiplex/pull/219) Modified workflow to store samplesheet in results folder.
- [#217](https://github.com/nf-core/demultiplex/pull/217) Update all nf-core modules and tests.
- [#240](https://github.com/nf-core/demultiplex/pull/240) Updated samshee, stub script and error strategy

### `Fixed`

- [#224](https://github.com/nf-core/demultiplex/pull/217) Fix input filename collision.
- [#231](https://github.com/nf-core/demultiplex/pull/231) Fix checkqc error message and .command.log emission.

## 1.4.1 - 2024-02-27

### `Changed`

- [#167](https://github.com/nf-core/demultiplex/pull/167) Updated template to nf-core/tools v2.12
- [#162](https://github.com/nf-core/demultiplex/pull/162) Updated template to nf-core/tools v2.11
- [#163](https://github.com/nf-core/demultiplex/pull/163) Updated template to nf-core/tools v2.11.1

## 1.4.0 - 2023-12-14

### `Added`

- [#148](https://github.com/nf-core/demultiplex/pull/148) Update CODEOWNERS to use GitHub teams

### `Changed`

- [#141](https://github.com/nf-core/demultiplex/pull/141) Updated template to nf-core/tools v2.10
- [#152](https://github.com/nf-core/demultiplex/pull/152) Updated bclconvert module to 4.2.4

### `Fixed`

- [#127](https://github.com/nf-core/demultiplex/pull/127) Add `singularity.registry = 'quay.io'` and bump NF version to 23.04.0
- [#140](https://github.com/nf-core/demultiplex/pull/140) Make it possible to skip MultiQC, fix error raising
- [#145](https://github.com/nf-core/demultiplex/pull/145) Fix MultiQC report generation
- [#152](https://github.com/nf-core/demultiplex/pull/152) Close [#150](https://github.com/nf-core/demultiplex/issues/150)
- [#157](https://github.com/nf-core/demultiplex/pull/157) Fix bcl2fastq and bclconvert publishDir
- [#158](https://github.com/nf-core/demultiplex/pull/158) Update all modules
- [#201](https://github.com/nf-core/demultiplex/pull/201) Fix samplesheet documentation issues

## `Removed`

- [#130](https://github.com/nf-core/demultiplex/pull/130) Remove `public_aws_ecr` profile.

## 1.3.2 - 2023-06-07

### `Fixed`

- [#125](https://github.com/nf-core/demultiplex/pull/125) Move containers for pipeline to quay.io

## 1.3.1 - 2023-06-05

### `Fixed`

- [#103](https://github.com/nf-core/demultiplex/issues/103) `-profile test` failing due to relative path in `flowcell_input.csv`
- [#122](https://github.com/nf-core/demultiplex/pull/122) Fails gracefully if an error is encountered

## 1.3.0 - 2023-05-31

### `Added`

- Add `public_aws_ecr` profile for using ECR containers.
- Bump `fastp` module to v0.23.4

### `Changed`

- [#115](https://github.com/nf-core/demultiplex/pull/115/files) Add public_aws_ecr profile

### `Fixed`

## v1.2.0 - 2023-04-24

### `Added`

- [#91](https://github.com/nf-core/demultiplex/pull/91) Add sgdemux
- [#99](https://github.com/nf-core/demultiplex/pull/99) Add fqtk
- [#107](https://github.com/nf-core/demultiplex/pull/107) Add test_full

### `Changed`

- [#94](https://github.com/nf-core/demultiplex/issues/94) update documentation
- [#95](https://github.com/nf-core/demultiplex/issues/95) add Codeowners
- [#108](https://github.com/nf-core/demultiplex/issues/108) update modules (untar is now in bcl2fastq and bclconvert modules)

### `Fixed`

- [#96](https://github.com/nf-core/demultiplex/issues/96) fix logo
- [#97](https://github.com/nf-core/demultiplex/issues/97) bcl2fastq installation error (@matthdsm)

## v1.1.0 - 2023-01-23

### `Added`

- [#63](https://github.com/nf-core/demultiplex/pull/63) Replace local bcl_demultiplex subworkflow with nf-core version (@matthdsm)
- [#63](https://github.com/nf-core/demultiplex/pull/63) Add bases_demultiplex local subworkflow (@matthdsm)
- [#63](https://github.com/nf-core/demultiplex/pull/63) Replace fastqc with falco for speedier QC, fixes Replace fastqc with falco [#62](https://github.com/nf-core/demultiplex/issues/62) (@matthdsm)
- [#64](https://github.com/nf-core/demultiplex/pull/64) Add subway map by @nvnieuwk
- [#70](https://github.com/nf-core/demultiplex/pull/70) Make tools and trimming optional (@matthdsm)
- [#71](https://github.com/nf-core/demultiplex/pull/71) Add nf-test (@edmundmiller)

### `Changed`

- [#78](https://github.com/nf-core/demultiplex/pull/78) Nextflow minimal version is now `22.10.1`

### `Fixed`

- [#63](https://github.com/nf-core/demultiplex/pull/63) Fix MultiQC report inputs, fixes MultiQC report is empty (@matthdsm)
- [#67](https://github.com/nf-core/demultiplex/pull/67) Enable institutional configs (@edmundmiller)
- [#83](https://github.com/nf-core/demultiplex/pull/83) Fix skip_tools (@glichtenstein)
- [#80](https://github.com/nf-core/demultiplex/issues/80) When NoLaneSplitting is true the process fails because of a glob. See [nf-core/modules #2745](https://github.com/nf-core/modules/pull/2745). (@matthdsm)
- [#79](https://github.com/nf-core/demultiplex/issues/79) Update link in docs to samplesheet (@glichtenstein & @edmundmiller)

## v1.0.0 - 2022-10-06

Initial release of nf-core/demultiplex, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- [#38](https://github.com/nf-core/demultiplex/pull/38) Add FastP
- [#39](https://github.com/nf-core/demultiplex/pull/39) Add FastQC
- [#51](https://github.com/nf-core/demultiplex/pull/51) Add bases2fastq

### `Fixed`

### `Deprecated`
