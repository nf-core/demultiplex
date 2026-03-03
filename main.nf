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
    demultiplexed_fastq         = DEMULTIPLEX.out.demultiplexed_fastq   // channel: [ meta, path(fastq) ]
    multiqc_report              = DEMULTIPLEX.out.multiqc_report        // channel: /path/to/multiqc_report.html
    pipeline_samplesheets       = DEMULTIPLEX.out.pipeline_samplesheets // channel: [ meta, samplesheet ]
    checkqc_reports        = DEMULTIPLEX.out.checkqc_reports
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
    pipeline_samplesheets     = NFCORE_DEMULTIPLEX.out.pipeline_samplesheets
    multiqc_report            = NFCORE_DEMULTIPLEX.out.multiqc_report 
        checkqc_reports        = NFCORE_DEMULTIPLEX.out.checkqc_reports

}

output {
    
    demultiplexed_fastq {
        path { "demultiplexed_fastq/" }
    }

    pipeline_samplesheets {
        path { "samplesheets/" }
    }

    multiqc_report {
        path { "multiqc/" }
    }

    checkqc_reports {
        path { "qc/checkqc/" }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
