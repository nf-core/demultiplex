/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def valid_params = [
    demultiplexers: ["bclconvert","bcl2fastq","bases2fastq"]
]

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowDemultiplex.initialise(params, log, valid_params)

// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input,
    params.multiqc_config
]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

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
include { BASES2FASTQ } from '../modules/local/bases2fastq/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { DEMUX_ILLUMINA } from "../subworkflows/local/demux_illumina/main"

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS   } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'
include { FASTP                         } from '../modules/nf-core/modules/fastp/main'
include { FASTQC                        } from '../modules/nf-core/modules/fastqc/main'
include { MULTIQC                       } from '../modules/nf-core/modules/multiqc/main'
include { UNTAR                         } from '../modules/nf-core/modules/untar/main'
include { MD5SUM                        } from '../modules/nf-core/modules/md5sum/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow DEMULTIPLEX {

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Sanitize inputs and separate input types
    ch_inputs = extract_csv(ch_input)

    // Split flowcells into separate channels containg run as tar and run as path
    // https://nextflow.slack.com/archives/C02T98A23U7/p1650963988498929
    ch_flowcells = ch_inputs
        .branch { meta, samplesheet, run ->
            tar: run.toString().endsWith('.tar.gz')
            dir: true
        }

    ch_flowcells_tar = ch_flowcells.tar
        .multiMap { meta, samplesheet, run ->
            samplesheets: [ meta, samplesheet ]
            run_dirs: [ meta, run ]
        }

    // MODULE: untar
    // Runs when run_dir is a tar archive
    // Re-join the metadata and the untarred run directory with the samplesheet
    ch_flowcells_tar_merged = ch_flowcells_tar.samplesheets.join( UNTAR ( ch_flowcells_tar.run_dirs ).untar )
    ch_versions = ch_versions.mix(UNTAR.out.versions)

    // Merge the two channels back together
    ch_flowcells = ch_flowcells.dir.mix(ch_flowcells_tar_merged)

    //
    // RUN demultiplexing
    //
    ch_raw_fastq = Channel.empty()

    // SUBWORKFLOW: illumina
    // Runs when "params.demultiplexer" is set to "bclconvert" or "bcl2fastq"
    // See conf/modules.config
    DEMUX_ILLUMINA( ch_flowcells )
    ch_raw_fastq = ch_raw_fastq.mix( DEMUX_ILLUMINA.out.fastq )
    ch_multiqc_files = ch_multiqc_files.mix( DEMUX_ILLUMINA.out.reports.map { meta, report -> return report} )
    ch_multiqc_files = ch_multiqc_files.mix( DEMUX_ILLUMINA.out.stats.map   { meta, stats  -> return stats } )
    ch_versions = ch_versions.mix(DEMUX_ILLUMINA.out.versions)

    // MODULE: bases2fastq
    // Runs when "params.demultiplexer" is set to "bases2fastq"
    // See conf/modules.config
    BASES2FASTQ ( ch_flowcells )
    ch_raw_fastq = ch_raw_fastq.mix(BASES2FASTQ.out.sample_fastq)
    // TODO ch_multiqc_files = ch_multiqc_files.mix()
    ch_versions = ch_versions.mix(BASES2FASTQ.out.versions)

    //
    // RUN QC
    //

    // MODULE: fastp
    FASTP(ch_raw_fastq, [], [])
    ch_multiqc_files = ch_multiqc_files.mix( FASTP.out.json.map { meta, json -> return json} )
    ch_versions = ch_versions.mix(FASTP.out.versions)

    // MODULE: fastqc
    FASTQC(ch_raw_fastq)
    ch_multiqc_files = ch_multiqc_files.mix( FASTQC.out.zip.map { meta, zip -> return zip} )
    ch_versions = ch_versions.mix(FASTQC.out.versions)

    // MODULE: md5sum
    // Split file list into separate channels entries and generate a checksum for each
    ch_fq_single = ch_raw_fastq.transpose()
    MD5SUM(ch_fq_single)

    // DUMP SOFTWARE VERSIONS
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    // MODULE: MultiQC
    workflow_summary    = WorkflowDemultiplex.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    MULTIQC (ch_multiqc_files.collect(),ch_multiqc_config, [])
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
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Extract information (meta data + file(s)) from csv file(s)
def extract_csv(csv_file) {
    Channel.value(csv_file).splitCsv(header: true, strip: true).map { row ->
        // check common mandatory fields
        if(!(row.id)){
            log.error "Missing id field in input csv file"
        }
        // check for invalid flowcell input
        if(row.flowcell && !(row.samplesheet)){
            log.error "Flowcell input requires both samplesheet and flowcell"
        }
        // valid flowcell input
        if(row.flowcell && row.samplesheet){
            return parse_flowcell_csv(row)
        }
    }
}

// Parse flowcell input map
def parse_flowcell_csv(row) {
    def meta = [:]
    meta.id   = row.id.toString()
    meta.lane = null
    if (row.containsKey("lane") && row.lane ) {
        meta.lane = row.lane.toInteger()
    }

    def flowcell        = file(row.flowcell, checkIfExists: true)
    def samplesheet     = file(row.samplesheet, checkIfExists: true)
    return [meta, samplesheet, flowcell]
}



/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
