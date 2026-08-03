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
    DEMULTIPLEX(
        samplesheet,
        params.multiqc_config,
        params.multiqc_logo,
        params.multiqc_methods_description,
        params.outdir,
    )

    emit:
    demultiplexed_fastq   = DEMULTIPLEX.out.demultiplexed_fastq
    demultiplex_reports   = DEMULTIPLEX.out.demultiplex_reports
    demultiplex_interop   = DEMULTIPLEX.out.demultiplex_interop
    demultiplex_stats     = DEMULTIPLEX.out.demultiplex_stats
    demultiplex_logs      = DEMULTIPLEX.out.demultiplex_logs
    multiqc_report        = DEMULTIPLEX.out.multiqc_report
    pipeline_samplesheets = DEMULTIPLEX.out.pipeline_samplesheets
    checkqc_reports       = DEMULTIPLEX.out.checkqc_reports
    fastp_reports         = DEMULTIPLEX.out.fastp_reports
    falco_reports         = DEMULTIPLEX.out.falco_reports
    md5_checksums         = DEMULTIPLEX.out.md5_checksums
    fastq_idx             = DEMULTIPLEX.out.fastq_idx
    undetermined          = DEMULTIPLEX.out.undetermined
    undetermined_idx      = DEMULTIPLEX.out.undetermined_idx
    multiqcsav_report     = DEMULTIPLEX.out.multiqcsav_report
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
    PIPELINE_INITIALISATION(
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
        params.show_hidden,
    )

    // WORKFLOW: Run main workflow
    NFCORE_DEMULTIPLEX(
        PIPELINE_INITIALISATION.out.samplesheet
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        NFCORE_DEMULTIPLEX.out.multiqc_report,
    )

    publish:
    demultiplexed_fastq   = NFCORE_DEMULTIPLEX.out.demultiplexed_fastq.transpose()
    demultiplex_reports   = NFCORE_DEMULTIPLEX.out.demultiplex_reports.transpose()
    demultiplex_interop   = NFCORE_DEMULTIPLEX.out.demultiplex_interop.transpose()
    demultiplex_stats     = NFCORE_DEMULTIPLEX.out.demultiplex_stats
    demultiplex_logs      = NFCORE_DEMULTIPLEX.out.demultiplex_logs
    pipeline_samplesheets = NFCORE_DEMULTIPLEX.out.pipeline_samplesheets
    multiqc_report        = NFCORE_DEMULTIPLEX.out.multiqc_report
    checkqc_reports       = NFCORE_DEMULTIPLEX.out.checkqc_reports
    fastp_reports         = NFCORE_DEMULTIPLEX.out.fastp_reports
    falco_reports         = NFCORE_DEMULTIPLEX.out.falco_reports
    md5_checksums         = NFCORE_DEMULTIPLEX.out.md5_checksums
    fastq_idx             = NFCORE_DEMULTIPLEX.out.fastq_idx.transpose()
    undetermined          = NFCORE_DEMULTIPLEX.out.undetermined.transpose()
    undetermined_idx      = NFCORE_DEMULTIPLEX.out.undetermined_idx.transpose()
    multiqcsav_report     = NFCORE_DEMULTIPLEX.out.multiqcsav_report
}

output {
    demultiplexed_fastq {
        path { meta, fastq ->
            fastq >> (meta.lane ? "${meta.fcid}/L00${meta.lane}/${fastq.name}" : "${meta.fcid}/${fastq.name}")
        }
        index {
            path 'demultiplexed_fastq.csv'
        }

    }
    demultiplex_reports {
        path { meta, report ->
            report >> (meta.lane ? "${meta.id}/L00${meta.lane}/${report.name}" : "${meta.id}/${report.name}")
        }
        index {
            path 'demultiplex_reports.csv'
        }
    }
    demultiplex_interop {
        path { meta, interop ->
            interop >> "${meta.id}/InterOp/${interop.name}"
        }
        index {
            path 'demultiplex_interop.csv'
        }
    }
    demultiplex_stats {
        path { meta, stat ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            "${lane_dir}/${stat.name}"
        }
        index {
            path 'demultiplex_stats.csv'
        }
    }
    demultiplex_logs {
        path { meta, log ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            "${lane_dir}/${log.name}"
        }
        index {
            path 'demultiplex_logs.csv'
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
        index {
            path 'checkqc_reports.csv'
        }
    }
    fastp_reports {
        path { meta, _report ->
            def lane_dir = meta.lane ? "${meta.fcid}/L00${meta.lane}" : "${meta.fcid}"
            "${lane_dir}/"
        }
        index {
            path 'fastp_reports.csv'
        }
    }
    falco_reports {
        path { meta, _report ->
            def lane_dir = meta.lane ? "${meta.fcid}/L00${meta.lane}" : "${meta.fcid}"
            "${lane_dir}/"
        }
        index {
            path 'falco_reports.csv'
        }
    }
    md5_checksums {
        path { meta, _checksum ->
            def lane_dir = meta.lane ? "${meta.fcid}/L00${meta.lane}" : "${meta.fcid}"
            "${lane_dir}/"
        }
        index {
            path 'md5_checksums.csv'
        }
    }
    fastq_idx {
        path { meta, fastq ->
            fastq >> (meta.lane ? "${meta.fcid ?: meta.id}/L00${meta.lane}/${fastq.name}" : "${meta.fcid ?: meta.id}/${fastq.name}")
        }
        index {
            path 'fastq_idx.csv'
        }

    }
    undetermined {
        enabled params.optional_outputs
        path { meta, fastq ->
            fastq >> (meta.lane ? "${meta.id}/L00${meta.lane}/undetermined/${fastq.name}" : "${meta.id}/undetermined/${fastq.name}")
        }
        index {
            path 'undetermined.csv'
        }
    }
    undetermined_idx {
        enabled params.optional_outputs
        path { meta, fastq ->
            fastq >> (meta.lane ? "${meta.id}/L00${meta.lane}/undetermined/${fastq.name}" : "${meta.id}/undetermined/${fastq.name}")
        }
        index {
            path 'undetermined_idx.csv'
        }
    }
    multiqcsav_report {
        path { "multiqcsav/" }
    }
}
