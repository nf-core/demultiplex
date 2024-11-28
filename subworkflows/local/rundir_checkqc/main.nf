#!/usr/bin/env nextflow

//
// Create a directory with checkqc data and run checkqc
//

include { CHECKQC_DIR   } from "../../../modules/local/checkqc_dir/main"
include { CHECKQC       } from "../../../modules/nf-core/checkqc/main"


workflow RUNDIR_CHECKQC {
    take:
        ch_flowcell     // [[id:"", lane:""],samplesheet.csv, path/to/bcl/files]
        ch_stats
        ch_interop
        ch_checkqc_config
        demultiplexer

    main:
        ch_versions      = Channel.empty()
        ch_report        = Channel.empty()
        ch_checkqc_dir   = Channel.empty()

        // Split flowcells into separate channels containing run as tar and run as path
        // https://nextflow.slack.com/archives/C02T98A23U7/p1650963988498929
        ch_flowcell
            .branch { meta, samplesheet, run ->
                tar: run.toString().endsWith(".tar.gz")
                dir: true
            }.set { ch_flowcells }

        ch_flowcells.tar
            .multiMap { meta, samplesheet, run ->
                samplesheets: [ meta, samplesheet ]
                run_dirs: [ meta, run ]
            }.set { ch_flowcells_tar }

        // Runs when run_dir is a tar archive
        // Re-join the metadata and the untarred run directory with the samplesheet
        ch_flowcells_tar_merged = ch_flowcells_tar
                                    .samplesheets
                                    .join( ch_flowcells_tar.run_dirs )

        // Merge the two channels back together
        ch_flowcells = ch_flowcells.dir.mix(ch_flowcells_tar_merged)

        // Join flowcells with demultiplexer output data
        ch_dir = ch_flowcells.join(ch_stats).join(ch_interop)

        if (demultiplexer == "bcl2fastq") {
                // Prepare checkqc directory
                CHECKQC_DIR(ch_dir)
                ch_checkqc_dir = CHECKQC_DIR.out.checkqc_dir

                // Run checkqc
                CHECKQC(ch_checkqc_dir, ch_checkqc_config)
                ch_report = CHECKQC.out.report
                ch_versions = ch_versions.mix(CHECKQC.out.versions)
        }

    emit:
        checkqc_dir = ch_checkqc_dir
        report      = ch_report
        versions    = ch_versions
}
