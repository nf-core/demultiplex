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
    multiqc_plots               = DEMULTIPLEX.out.multiqc_plots
    multiqc_data                = DEMULTIPLEX.out.multiqc_data     
    pipeline_samplesheets       = DEMULTIPLEX.out.pipeline_samplesheets 
    checkqc_reports             = DEMULTIPLEX.out.checkqc_reports
    fastp_reports               = DEMULTIPLEX.out.fastp_reports
    falco_reports               = DEMULTIPLEX.out.falco_reports
    md5_checksums               = DEMULTIPLEX.out.md5_checksums
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
    multiqc_data              = NFCORE_DEMULTIPLEX.out.multiqc_data
    multiqc_plots             = NFCORE_DEMULTIPLEX.out.multiqc_plots
    checkqc_reports           = NFCORE_DEMULTIPLEX.out.checkqc_reports
    fastp_reports             = NFCORE_DEMULTIPLEX.out.fastp_reports
    falco_reports             = NFCORE_DEMULTIPLEX.out.falco_reports
    md5_checksums             = NFCORE_DEMULTIPLEX.out.md5_checksums

}

output {
    
    demultiplexed_fastq {
        path { meta, _fastq ->
            def lane_dir = meta.lane ? "${meta.fcid}/L00${meta.lane}" : "${meta.fcid}"
            "${lane_dir}/"
        }
    }

    demultiplex_reports {
        path { meta, report ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            "${lane_dir}/"        
            }
    }

    demultiplex_interop {
        path { meta, interop ->
            "${meta.id}/"        
            }
    }

    demultiplex_stats {
        path { meta, stat ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            "${lane_dir}/"        
            }
    }

    demultiplex_logs {
        path { meta, log ->
            def lane_dir = meta.lane ? "${meta.id}/L00${meta.lane}" : "${meta.id}"
            "${lane_dir}/"
        }
    }

    pipeline_samplesheets {
        path { "samplesheet/" }
    }

    multiqc_report {
        path { "multiqc/" }
    }

    multiqc_data {
        path { "multiqc/" }
    }

    multiqc_plots {
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
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
