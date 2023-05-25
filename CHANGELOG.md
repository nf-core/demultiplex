# nf-core/demultiplex: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## dev

### `Added`

- Add `public_aws_ecr` profile for using ECR containers.

### `Changed`

### `Fixed`

## v1.2.0 - 2023-04-25

### `Added`

### `Changed`

- [#115](https://github.com/nf-core/demultiplex/pull/115/files) Add public_aws_ecr profile
- [#113](https://github.com/nf-core/demultiplex/pull/113) Back to dev

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
- [#71](https://github.com/nf-core/demultiplex/pull/71) Add nf-test (@emiller88)

### `Changed`

- [#78](https://github.com/nf-core/demultiplex/pull/78) Nextflow minimal version is now `22.10.1`

### `Fixed`

- [#63](https://github.com/nf-core/demultiplex/pull/63) Fix MultiQC report inputs, fixes MultiQC report is empty (@matthdsm)
- [#67](https://github.com/nf-core/demultiplex/pull/67) Enable institutional configs (@emiller88)
- [#83](https://github.com/nf-core/demultiplex/pull/83) Fix skip_tools (@glichtenstein)
- [#80](https://github.com/nf-core/demultiplex/issues/80) When NoLaneSplitting is true the process fails because of a glob. See [nf-core/modules #2745](https://github.com/nf-core/modules/pull/2745). (@matthdsm)
- [#79](https://github.com/nf-core/demultiplex/issues/79) Update link in docs to samplesheet (@glichtenstein & @emiller88)

## v1.0.0 - 2022-10-06

Initial release of nf-core/demultiplex, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- [#38](https://github.com/nf-core/demultiplex/pull/38) Add FastP
- [#39](https://github.com/nf-core/demultiplex/pull/39) Add FastQC
- [#51](https://github.com/nf-core/demultiplex/pull/51) Add bases2fastq

### `Fixed`

### `Deprecated`
