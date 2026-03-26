#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/demultiplex
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/demultiplex
    Website: https://nf-co.re/demultiplex
    Slack  : https://nfcore.slack.com/channels/demultiplex
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DEMULTIPLEX             } from './workflows/demultiplex'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_demultiplex_pipeline'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_demultiplex_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_DEMULTIPLEX {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    //
    // WORKFLOW: Run pipeline
    //
    DEMULTIPLEX (
        samplesheet
    )

    emit:
    demultiplexed_fastq         = DEMULTIPLEX.out.demultiplexed_fastq
    demultiplex_reports         = DEMULTIPLEX.out.demultiplex_reports
    demultiplex_interop         = DEMULTIPLEX.out.demultiplex_interop
    demultiplex_stats           = DEMULTIPLEX.out.demultiplex_stats
    demultiplex_logs            = DEMULTIPLEX.out.demultiplex_logs
    multiqc_report              = DEMULTIPLEX.out.multiqc_report
    pipeline_samplesheets       = DEMULTIPLEX.out.pipeline_samplesheets
    checkqc_reports             = DEMULTIPLEX.out.checkqc_reports
    fastp_reports               = DEMULTIPLEX.out.fastp_reports
    falco_reports               = DEMULTIPLEX.out.falco_reports
    md5_checksums               = DEMULTIPLEX.out.md5_checksums
    fastq_idx                   = DEMULTIPLEX.out.fastq_idx
    undetermined                = DEMULTIPLEX.out.undetermined
    undetermined_idx            = DEMULTIPLEX.out.undetermined_idx
    multiqcsav_report           = DEMULTIPLEX.out.multiqcsav_report
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.flowcell_id,
        params.flowcell_samplesheet,
        params.flowcell_lane,
        params.flowcell_path,
        params.flowcell_per_flowcell_manifest,
        params.help,
        params.help_full,
        params.show_hidden
    )

    // WORKFLOW: Run main workflow
    NFCORE_DEMULTIPLEX (
        PIPELINE_INITIALISATION.out.samplesheet
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_DEMULTIPLEX.out.multiqc_report
    )

    publish:
    demultiplexed_fastq       = NFCORE_DEMULTIPLEX.out.demultiplexed_fastq
    demultiplex_reports       = NFCORE_DEMULTIPLEX.out.demultiplex_reports
    demultiplex_interop       = NFCORE_DEMULTIPLEX.out.demultiplex_interop
    demultiplex_stats         = NFCORE_DEMULTIPLEX.out.demultiplex_stats
    demultiplex_logs          = NFCORE_DEMULTIPLEX.out.demultiplex_logs
    pipeline_samplesheets     = NFCORE_DEMULTIPLEX.out.pipeline_samplesheets
    multiqc_report            = NFCORE_DEMULTIPLEX.out.multiqc_report
    checkqc_reports           = NFCORE_DEMULTIPLEX.out.checkqc_reports
    fastp_reports             = NFCORE_DEMULTIPLEX.out.fastp_reports
    falco_reports             = NFCORE_DEMULTIPLEX.out.falco_reports
    md5_checksums             = NFCORE_DEMULTIPLEX.out.md5_checksums
    fastq_idx                 = NFCORE_DEMULTIPLEX.out.fastq_idx
    undetermined              = NFCORE_DEMULTIPLEX.out.undetermined
    undetermined_idx          = NFCORE_DEMULTIPLEX.out.undetermined_idx
    multiqcsav_report         = NFCORE_DEMULTIPLEX.out.multiqcsav_report

}

output {

    demultiplexed_fastq {
        path { meta, fastq ->
            def lane_dir = meta.lane ? "${meta.fcid}/L00${meta.lane}" : "${meta.fcid}"
            def files = fastq instanceof List ? fastq : [fastq]
            files.each { f ->
                f >> "${lane_dir}/${f.name}"
            }
        }
    }

    demultiplex_reports {
        path { meta, report ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            def files = report instanceof List ? report : [report]
            files.each { f ->
                f >> "${lane_dir}/${f.name}"
            }
        }
    }

    demultiplex_interop {
        path { meta, interop ->
            def files = interop instanceof List ? interop : [interop]
            files.each { f ->
                f >> "${meta.id}/InterOp/${f.name}"
            }
        }
    }

    demultiplex_stats {
        path { meta, stat ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            stat >> "${lane_dir}/${stat.name}"
            }
    }

    demultiplex_logs {
        path { meta, log ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            log >> "${lane_dir}/${log.name}"
        }
    }

    pipeline_samplesheets {
        path { "samplesheet/" }
    }

    multiqc_report {
        path { "multiqc/" }
    }

    checkqc_reports {
        path { meta, _report ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            "${lane_dir}/"
        }
    }

    fastp_reports {
        path { meta, _report ->
            def lane_dir = meta.lane ? "${meta.fcid}/L00${meta.lane}" : "${meta.fcid}"
            "${lane_dir}/"
        }
    }

    falco_reports {
        path { meta, _report ->
            def lane_dir = meta.lane ? "${meta.fcid}/L00${meta.lane}" : "${meta.fcid}"
            "${lane_dir}/"
        }
    }

    md5_checksums {
        path { meta, _checksum ->
            def lane_dir = meta.lane ? "${meta.fcid}/L00${meta.lane}" : "${meta.fcid}"
            "${lane_dir}/"
        }
    }

    fastq_idx {
        path { meta, fastq ->
            def id = meta.fcid ?: meta.id
            def lane_dir = meta.lane ? "${id}/L00${meta.lane}" : "${id}"
            def files = fastq instanceof List ? fastq : [fastq]
            files.each { f ->
                f >> "${lane_dir}/${f.name}"
            }
        }
    }

    undetermined {
        enabled params.optional_outputs
        path { meta, fastq ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}/undetermined" : "${meta.id}/undetermined"
            def files = fastq instanceof List ? fastq : [fastq]
            files.each { f ->
                f >> "${lane_dir}/${f.name}"
            }
        }
    }

    undetermined_idx {
        enabled params.optional_outputs
        path { meta, fastq ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}/undetermined" : "${meta.id}/undetermined"
            def files = fastq instanceof List ? fastq : [fastq]
            files.each { f ->
                f >> "${lane_dir}/${f.name}"
            }
        }
    }

    multiqcsav_report {
        path { "multiqcsav/" }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
