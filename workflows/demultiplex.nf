/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowDemultiplex.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }
if (params.input) { ss_sheet = file(params.input, checkIfExists: true) } else { exit 1, "Sample sheet not found!" }
if (params.run_dir) { runDir = file(params.run_dir, checkIfExists: true) } else { exit 1, "Run directory not found!" }
runName = runDir.getName()


// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Local
//
include { REFORMAT_SAMPLESHEET } from '../modules/local/reformat_samplesheet'
include { MAKE_FAKE_SS         } from '../modules/local/make_fake_ss'
include { BCL2FASTQ_PROBLEM_SS } from '../modules/local/bcl2fastq_problem_ss'
include { PARSE_JSONFILE       } from '../modules/local/parse_jsonfile'
include { RECHECK_SAMPLESHEET  } from '../modules/local/recheck_samplesheet'
include { BCL2FASTQ            } from '../modules/local/bcl2fastq'
include { FASTQ_SCREEN         } from '../modules/local/fastq_screen'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { BCLCONVERT                    } from '../modules/nf-core/modules/bclconvert/main'
include { CELLRANGER_MKFASTQ            } from '../modules/nf-core/modules/cellranger/mkfastq/main'
include { MULTIQC                       } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS   } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow DEMULTIPLEX {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////
    /* --                                                                     -- */
    /* --               Single Cell Processes`                                -- */
    /* --                                                                     -- */
    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////

    // TODO Move to Subworkflow
    // NOTE Maybe this lives in nf-core/scrnaseq?

    /*
    * STEP 7 - CellRanger MkFastQ.
    *          ONLY RUNS WHEN ANY TYPE OF 10X SAMPLESHEET EXISTS.
    */
    CELLRANGER_MKFASTQ (
        REFORMAT_SAMPLESHEET.out.tenx_results,
        REFORMAT_SAMPLESHEET.out.tenx_samplesheet
    )

    /*
    * STEP 8 - CellRanger count.
    *          ONLY RUNS WHEN A 10X SAMPLESHEET EXISTS.
    */
    CELLRANGER_COUNT (
        CELLRANGER_MKFASTQ.out.fastq,
        params.cellranger_genomes.hg19 // FIXME Remove hard-code
    )

    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////
    /* --                                                                     -- */
    /* --               Main Demultiplexing Processes`                        -- */
    /* --                                                                     -- */
    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////

    /*
    * STEP 9 - Running bcl2fastq on the remade samplesheet or a sample sheet that
    *          passed the initial check. bcl2fastq parameters can be changed when
    *          staring up the pipeline.
    *          ONLY RUNS WHEN SAMPLES REMAIN AFTER Single Cell SAMPLES ARE SPLIT OFF
    *          INTO SEPARATE SAMPLE SHEETS.
    */
    BCL2FASTQ (
        RECHECK_SAMPLESHEET.out.problem_ss,
        INPUT_CHECK.out.result, // FIXME this doesn't exist
        REFORMAT_SAMPLESHEET.out.standard_samplesheet
        PARSE_JSONFILE.out.updated_samplesheet,
        MAKE_FAKE_SS.out.problem_samples_list,
        BCL2FASTQ_PROBLEM_SS.out.stats_json_file
    )
    // TODO
    // ch_versions = ch_versions.mix(BCL2FASTQ.out.versions.first())

    // TODO Move to Subworkflow

    //
    // STEP 11 - Run FastQC
    //
    FASTQC (
        BCL2FASTQ.out.fastq
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    KRAKEN2_KRAKEN2 (
        BCL2FASTQ.out.fastq,
        params.kraken_db,
        true,
        true
    )

    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////
    /* --                                                                     -- */
    /* --                         FastQ Screen                                -- */
    /* --                                                                     -- */
    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////

    /*
    * STEP 12 - FastQ Screen
    */
    // TODO Run this against undetermined
    FASTQ_SCREEN (
        BCL2FASTQ.out.fastq
    )

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowDemultiplex.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect()
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
