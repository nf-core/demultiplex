# nf-core/demultiplex: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.0 - 2023-01-20

### `Added`

- [#63](https://github.com/nf-core/demultiplex/pull/63) Replace local bcl_demultiplex subworkflow with nf-core version
- [#63](https://github.com/nf-core/demultiplex/pull/63) Add bases_demultiplex local subworkflow
- [#63](https://github.com/nf-core/demultiplex/pull/63) Replace fastqc with falco for speedier QC, fixes Replace fastqc with falco #62
- [#64](https://github.com/nf-core/demultiplex/pull/64) Add subway map by @nvnieuwk
- [#70](https://github.com/nf-core/demultiplex/pull/70) Make tools and trimming optional
- [#71](https://github.com/nf-core/demultiplex/pull/71) Add nf-test

### `Changed`

- [#78](https://github.com/nf-core/demultiplex/pull/78) Nextflow minimal version is now `22.10.1`

### `Fixed`

- [#63](https://github.com/nf-core/demultiplex/pull/63) Fix MultiQC report inputs, fixes MultiQC report is empty #64
- [#67](https://github.com/nf-core/demultiplex/pull/67) Enable instititutional configs
- [#83](https://github.com/nf-core/demultiplex/pull/83) Fix skip_tools
- [#80](https://github.com/nf-core/demultiplex/issues/80) When NoLaneSplitting is true the process fails because of a glob. See [nf-core/modules #2745](https://github.com/nf-core/modules/pull/2745).
- [#79](https://github.com/nf-core/demultiplex/issues/79) Update link in docs to samplesheet

## v1.0.0 - 2022-10-06

Initial release of nf-core/demultiplex, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- [#38](https://github.com/nf-core/demultiplex/pull/38) Add FastP
- [#39](https://github.com/nf-core/demultiplex/pull/39) Add FastQC
- [#51](https://github.com/nf-core/demultiplex/pull/51) Add bases2fastq

### `Fixed`

### `Deprecated`
