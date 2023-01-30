/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def valid_params = [
    demultiplexers: ["bclconvert","bcl2fastq","bases2fastq","sgdemux"]
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

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { BCL_DEMULTIPLEX   } from '../subworkflows/nf-core/bcl_demultiplex/main'
include { BASES_DEMULTIPLEX } from '../subworkflows/local/bases_demultiplex/main'
include { SINGULAR_DEMULTIPLEX } from '../subworkflows/local/singular_demultiplex/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CUSTOM_DUMPSOFTWAREVERSIONS   } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { FASTP                         } from '../modules/nf-core/fastp/main'
include { FALCO                         } from '../modules/nf-core/falco/main'
include { MULTIQC                       } from '../modules/nf-core/multiqc/main'
include { UNTAR                         } from '../modules/nf-core/untar/main'
include { MD5SUM                        } from '../modules/nf-core/md5sum/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow DEMULTIPLEX {

    // Value inputs
    demultiplexer = params.demultiplexer                                   // string: bclconvert, bcl2fastq, bases2fastq, sgdemux
    trim_fastq    = params.trim_fastq                                      // boolean: true, false
    skip_tools    = params.skip_tools ? params.skip_tools.split(',') : []  // list: [falco, fastp, multiqc]

    // Channel inputs


    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Sanitize inputs and separate input types
    ch_inputs = extract_csv(ch_input)
    ch_inputs.dump(tag: 'DEMULTIPLEX::inputs',{FormattingService.prettyFormat(it)})

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

    switch (demultiplexer) {
        case ['bclconvert', 'bcl2fastq']:
            // SUBWORKFLOW: illumina
            // Runs when "demultiplexer" is set to "bclconvert" or "bcl2fastq"
            BCL_DEMULTIPLEX( ch_flowcells, demultiplexer )
            ch_raw_fastq = ch_raw_fastq.mix( BCL_DEMULTIPLEX.out.fastq )
            ch_multiqc_files = ch_multiqc_files.mix( BCL_DEMULTIPLEX.out.reports.map { meta, report -> return report} )
            ch_multiqc_files = ch_multiqc_files.mix( BCL_DEMULTIPLEX.out.stats.map   { meta, stats  -> return stats } )
            ch_versions = ch_versions.mix(BCL_DEMULTIPLEX.out.versions)
            break
        case 'bases2fastq':
            // MODULE: bases2fastq
            // Runs when "demultiplexer" is set to "bases2fastq"
            BASES_DEMULTIPLEX ( ch_flowcells )
            ch_raw_fastq = ch_raw_fastq.mix(BASES_DEMULTIPLEX.out.fastq)
            // TODO: verify that this is the correct output
            ch_multiqc_files = ch_multiqc_files.mix(BASES_DEMULTIPLEX.out.metrics.map { meta, metrics -> return metrics} )
            ch_versions = ch_versions.mix(BASES_DEMULTIPLEX.out.versions)
            break
        case 'sgdemux':
            // MODULE: sgdemux
            // Runs when "demultiplexer" is set to "sgdemux"
            SINGULAR_DEMULTIPLEX ( ch_flowcells )
            ch_raw_fastq = ch_raw_fastq.mix(SINGULAR_DEMULTIPLEX.out.fastq)
            // TODO: verify that this is the correct output for sgdemux and bases2fastq
            ch_multiqc_files = ch_multiqc_files.mix(SINGULAR_DEMULTIPLEX.out.metrics.map { meta, metrics -> return metrics} )
            ch_versions = ch_versions.mix(SINGULAR_DEMULTIPLEX.out.versions)
            break
        default:
            exit 1, "Unknown demultiplexer: ${demultiplexer}"
    }
    ch_raw_fastq.dump(tag: "DEMULTIPLEX::Demultiplexed Fastq",{FormattingService.prettyFormat(it)})

    //
    // RUN QC and TRIMMING
    //

    ch_fastq_to_qc = ch_raw_fastq

    // MODULE: fastp
    if (!("fastp" in skip_tools)){
            FASTP(ch_raw_fastq, [], [], [])
            ch_multiqc_files = ch_multiqc_files.mix( FASTP.out.json.map { meta, json -> return json} )
            ch_versions = ch_versions.mix(FASTP.out.versions)
            if (trim_fastq) {
                ch_fastq_to_qc = FASTP.out.reads
            }
    }

    // MODULE: falco, drop in replacement for fastqc
    if (!("falco" in skip_tools)){
        FALCO(ch_fastq_to_qc)
        ch_multiqc_files = ch_multiqc_files.mix( FALCO.out.txt.map { meta, txt -> return txt} )
        ch_versions = ch_versions.mix(FALCO.out.versions)
    }

    // MODULE: md5sum
    // Split file list into separate channels entries and generate a checksum for each
    MD5SUM(ch_fastq_to_qc.transpose())

    // DUMP SOFTWARE VERSIONS
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    // MODULE: MultiQC
    workflow_summary    = WorkflowDemultiplex.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowDemultiplex.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files.collect().dump(tag: "DEMULTIPLEX::MultiQC files",{FormattingService.prettyFormat(it)})

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
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
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Extract information (meta data + file(s)) from csv file(s)
def extract_csv(input_csv) {

    // Flowcell Sheet schema
    // Possible values for the "content" column: [meta, path, number, string, bool]
    def input_schema = [
        'columns': [
            'id': [
                'content': 'meta',
                'meta_name': 'id',
                'pattern': '',
            ],
            'samplesheet': [
                'content': 'path',
                'pattern': '^.*.csv$',
            ],
            'lane': [
                'content': 'meta',
                'meta_name': 'lane',
                'pattern': '',
            ],
            'flowcell': [
                'content': 'path',
                'pattern': '',
            ],

        ],
        required: ['id','flowcell', 'samplesheet'],
    ]

    // Don't change these variables
    def row_count = 1
    def all_columns = input_schema.columns.keySet().collect()
    def mandatory_columns = input_schema.required

    // Header checks
    Channel.value(input_csv).splitCsv(strip:true).first().map({ row ->

        if(row != all_columns) {
            def commons = all_columns.intersect(row)
            def diffs = all_columns.plus(row)
            diffs.removeAll(commons)

            if(diffs.size() > 0){
                def missing_columns = []
                def wrong_columns = []
                for(diff : diffs){
                    diff in all_columns ? missing_columns.add(diff) : wrong_columns.add(diff)
                }
                if(missing_columns.size() > 0){
                    exit 1, "[Samplesheet Error] The column(s) $missing_columns is/are not present. The header should look like: $all_columns"
                }
                else {
                    exit 1, "[Samplesheet Error] The column(s) $wrong_columns should not be in the header. The header should look like: $all_columns"
                }
            }
            else {
                exit 1, "[Samplesheet Error] The columns $row are not in the right order. The header should look like: $all_columns"
            }

        }
    })

    // Field checks + returning the channels
    Channel.value(input_csv).splitCsv(header:true, strip:true).map({ row ->

        row_count++

        // Check the mandatory columns
        def missing_mandatory_columns = []
        for(column : mandatory_columns) {
            row[column] ?: missing_mandatory_columns.add(column)
        }
        if(missing_mandatory_columns.size > 0){
            exit 1, "[Samplesheet Error] The mandatory column(s) $missing_mandatory_columns is/are empty on line $row_count"
        }

        def output = []
        def meta = [:]
        for(col : input_schema.columns) {
            key = col.key
            content = row[key]

            if(!(content ==~ col.value['pattern']) && col.value['pattern'] != '' && content != '') {
                exit 1, "[Samplesheet Error] The content of column '$key' on line $row_count does not match the pattern '${col.value['pattern']}'"
            }

            if(col.value['content'] == 'path'){
                output.add(content ? file(content, checkIfExists:true) : col.value['default'] ?: [])
            }
            else if(col.value['content'] == 'meta'){
                for(meta_name : col.value['meta_name'].split(",")){
                    meta[meta_name] = content != '' ? content.replace(' ', '_') : col.value['default'] ?: null
                }
            }
        }

        output.add(0, meta)
        return output
    })
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
