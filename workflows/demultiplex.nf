/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

include { BCL_DEMULTIPLEX           } from '../subworkflows/nf-core/bcl_demultiplex'
include { FASTQ_CONTAM_SEQTK_KRAKEN } from '../subworkflows/nf-core/fastq_contam_seqtk_kraken'
include { RUNDIR_CHECKQC            } from '../subworkflows/local/rundir_checkqc'
include { CHANNEL_FASTQ_CREATE_CSV  } from '../subworkflows/local/channel_fastq_create_csv'

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTP                     } from '../modules/nf-core/fastp'
include { FALCO                     } from '../modules/nf-core/falco'
include { MULTIQC                   } from '../modules/nf-core/multiqc'
include { UNTAR as UNTAR_FLOWCELL   } from '../modules/nf-core/untar'
include { UNTAR as UNTAR_KRAKEN_DB  } from '../modules/nf-core/untar'
include { MD5SUM                    } from '../modules/nf-core/md5sum'
include { SAMSHEE                   } from '../modules/nf-core/samshee'
include { BASES2FASTQ               } from '../modules/nf-core/bases2fastq'
include { CELLRANGER_MKFASTQ        } from '../modules/nf-core/cellranger/mkfastq'
include { MGIKIT_DEMULTIPLEX        } from '../modules/nf-core/mgikit/demultiplex'
include { SGDEMUX                   } from '../modules/nf-core/sgdemux'
include { FQTK                      } from '../modules/nf-core/fqtk'

//
// FUNCTION
//
include { paramsSummaryMap          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText    } from '../subworkflows/local/utils_nfcore_demultiplex_pipeline'
include { removeAdapters            } from '../subworkflows/local/utils_nfcore_demultiplex_pipeline'
include { prettyFormat              } from '../subworkflows/local/utils_nfcore_demultiplex_pipeline'
include { generateFastqMeta         } from '../subworkflows/local/utils_nfcore_demultiplex_pipeline'
include { csvToTSV                  } from '../subworkflows/local/utils_nfcore_demultiplex_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DEMULTIPLEX {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:
    // Value inputs
    demultiplexer = params.demultiplexer
    // string: bases2fastq, bcl2fastq, bclconvert, fqtk, sgdemux, mkfastq
    trim_fastq = params.trim_fastq
    // boolean: true, false
    skip_tools = params.skip_tools ? params.skip_tools.split(',') : []
    // list: [falco, fastp, multiqc]
    sample_size = params.sample_size
    // int
    kraken_db = params.kraken_db
    // path
    strandedness = params.strandedness
    // string: auto, reverse, forward, unstranded

    // Channel inputs
    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()
    ch_multiqc_reports = channel.empty()
    ch_checkqc_reports = channel.empty()
    ch_fastp_reports = channel.empty()
    ch_falco_reports = channel.empty()
    ch_md5_checksums = channel.empty()
    ch_demultiplex_reports = channel.empty()
    ch_demultiplex_interop = channel.empty()
    ch_demultiplex_stats = channel.empty()
    ch_demultiplex_logs = channel.empty()
    ch_fastq_idx = channel.empty()
    ch_undetermined = channel.empty()
    ch_undetermined_idx = channel.empty()
    ch_multiqcsav_report = channel.empty()

    checkqc_config = params.checkqc_config ? channel.fromPath(params.checkqc_config, checkIfExists: true) : []
    // file checkqc_config.yaml
    ch_file_schema_validator = params.file_schema_validator ? channel.fromPath(params.file_schema_validator, checkIfExists: true) : []
    // file schema.json

    // Remove adapter from Illumina samplesheet to avoid adapter trimming in demultiplexer tools
    ch_samplesheet = ch_samplesheet.map { meta, csv, tar, optional -> [[id: meta.id.toString(), lane: meta.lane], csv, tar, optional] }
    // Make meta.id be always a string
    if (params.remove_samplesheet_adapter && (params.demultiplexer in ["bcl2fastq", "bclconvert", "mkfastq"])) {
        ch_samplesheet_no_adapter = ch_samplesheet
            .collectFile(storeDir: "${params.outdir}") { item ->
                def suffix = item[0].lane ? ".lane${item[0].lane}" : ""
                //need to produce one file per item in the channel else join fails
                ["${item[0].id}${suffix}_no_adapters.csv", removeAdapters(item[1])]
            }
            .map { file ->
                //build meta again from file name
                def meta_id = (file =~ /.*\/(.*?)(\.lane|_no_adapters)/)[0][1]
                //extracts everything from the last "/" until ".lane" or "_no_adapters"
                def meta_lane = file.getName().contains('.lane') ? (file =~ /\.lane(\d+)/)[0][1].toInteger() : null
                //extracts number after ".lane" until next "_", must be int to match lane value from meta
                [[id: meta_id.toString(), lane: meta_lane], file]
            }
        ch_samplesheet_new = ch_samplesheet
            .join(ch_samplesheet_no_adapter, failOnMismatch: true)
            .map { meta, _samplesheet, flowcell, lane, new_samplesheet -> [meta, new_samplesheet, flowcell, lane] }
        ch_samplesheet = ch_samplesheet_new
    }
    else {
        ch_samplesheet.collectFile(storeDir: "${params.outdir}") { item ->
            ["${item[0].id}.csv", item[1]]
        }
    }

    // RUN samplesheet_validator samshee
    if (!("samshee" in skip_tools) && (params.demultiplexer in ["bcl2fastq", "bclconvert", "mkfastq"])) {
        SAMSHEE(
            ch_samplesheet.map { meta, samplesheet, _flowcell, _lane -> [meta, samplesheet] },
            ch_file_schema_validator,
        )
        ch_samplesheet = ch_samplesheet
            .join(SAMSHEE.out.samplesheet)
            .map { meta, samplesheet, flowcell, lane, _samplesheet_formatted -> [meta, samplesheet, flowcell, lane] }
    }

    // Convenience
    ch_samplesheet.dump(tag: 'DEMULTIPLEX::inputs') { samplesheet -> prettyFormat(samplesheet) }

    // Split flowcells into separate channels containg run as tar and run as path
    // https://nextflow.slack.com/archives/C02T98A23U7/p1650963988498929
    if (demultiplexer == 'fqtk') {

        ch_flowcells = ch_samplesheet.branch { _meta, _samplesheet, flowcell, _per_flowcell_manifest ->
            tar: flowcell.toString().endsWith('.tar.gz')
            dir: true
        }
        ch_flowcells_tar = ch_flowcells.tar.multiMap { meta, samplesheet, flowcell, per_flowcell_manifest ->
            samplesheets: [meta, samplesheet, per_flowcell_manifest]
            run_dirs: [meta, flowcell]
        }
    }
    else {

        ch_flowcells = ch_samplesheet
            .map { meta, samplesheet, flowcell, _per_flowcell_manifest ->
                [meta, samplesheet, flowcell]
            }
            .branch { _meta, _samplesheet, flowcell ->
                tar: flowcell.toString().endsWith('.tar.gz')
                dir: true
            }
        ch_flowcells_tar = ch_flowcells.tar.multiMap { meta, samplesheet, flowcell ->
            samplesheets: [meta, samplesheet]
            run_dirs: [meta, flowcell]
        }
    }

    // MODULE: untar
    // Runs when run_dir is a tar archive
    // Except for bclconvert and bcl2fastq for wich we untar in the process
    // Re-join the metadata and the untarred run directory with the samplesheet

    if (demultiplexer == 'mgikit') {
        ch_flowcells_tar_merged = channel.empty()
    }
    else {
        ch_flowcells_tar_merged = ch_flowcells_tar.samplesheets.join(UNTAR_FLOWCELL(ch_flowcells_tar.run_dirs).untar, failOnMismatch: true, failOnDuplicate: true)
    }

    // Merge the two channels back together
    ch_flowcells = ch_flowcells.dir.mix(ch_flowcells_tar_merged)

    // RUN demultiplexing
    //
    ch_raw_fastq = channel.empty()

    if (demultiplexer == 'bases2fastq') {
        // MODULE: bases2fastq
        // Runs when "demultiplexer" is set to "bases2fastq"
        BASES2FASTQ(ch_flowcells)
        ch_raw_fastq = ch_raw_fastq.mix(
            generateFastqMeta(
                BASES2FASTQ.out.sample_fastq.map { meta, files ->
                    [meta, files.findAll { it.size() > 100 }]  // skip empty fastq files i.e. Undetermined_*.fastq.gz in case no indexes were used for sequencing
                },
                /_R[0-9].*$/,
                'ELEMENT'
            )
        )
        // TODO: verify that this is the correct output
        ch_multiqc_files = ch_multiqc_files.mix(BASES2FASTQ.out.metrics.map { _meta, metrics -> metrics })
        ch_demultiplex_reports = ch_demultiplex_reports.mix(BASES2FASTQ.out.metrics).mix(BASES2FASTQ.out.run_stats).mix(BASES2FASTQ.out.generated_run_manifest).mix(BASES2FASTQ.out.unassigned).mix(BASES2FASTQ.out.qc_report).mix(BASES2FASTQ.out.sample_json)
    }
    else if (demultiplexer in ['bclconvert', 'bcl2fastq']) {
        // SUBWORKFLOW: illumina
        // Runs when "demultiplexer" is set to "bclconvert" or "bcl2fastq"
        BCL_DEMULTIPLEX(ch_flowcells, demultiplexer)
        if (demultiplexer == 'bcl2fastq') {
            ch_raw_fastq = ch_raw_fastq.mix(BCL_DEMULTIPLEX.out.fastq)
        }
        else {
            // Add missing sample name to metadata
            ch_raw_fastq = ch_raw_fastq.mix(
                BCL_DEMULTIPLEX.out.fastq.map { meta, fastq ->
                    def first_file = fastq instanceof List ? fastq[0] : fastq
                    def sn = first_file.getSimpleName().toString() - ~/_S[0-9]+.*$/
                    def fc_id = meta.readgroup.PU.tokenize('.')[0]
                    [meta + [samplename: sn, fcid: fc_id], fastq]
                }
            )
        }
        ch_multiqcsav_report = ch_multiqcsav_report.mix(BCL_DEMULTIPLEX.out.sav_report.map { _meta, report -> report })
        ch_multiqcsav_report = ch_multiqcsav_report.mix(BCL_DEMULTIPLEX.out.sav_data.map { _meta, data -> data })
        ch_multiqcsav_report = ch_multiqcsav_report.mix(BCL_DEMULTIPLEX.out.sav_plots.map { _meta, plots -> plots })
        ch_multiqc_files = ch_multiqc_files.mix(BCL_DEMULTIPLEX.out.reports.map { _meta, report -> report })
        ch_multiqc_files = ch_multiqc_files.mix(BCL_DEMULTIPLEX.out.stats.map { _meta, stats -> stats })
        ch_demultiplex_reports = ch_demultiplex_reports.mix(BCL_DEMULTIPLEX.out.reports)
        ch_demultiplex_interop = ch_demultiplex_interop.mix(BCL_DEMULTIPLEX.out.interop)
        ch_demultiplex_stats = ch_demultiplex_stats.mix(BCL_DEMULTIPLEX.out.stats)
        ch_undetermined = ch_undetermined.mix(BCL_DEMULTIPLEX.out.undetermined)

        if (!("checkqc" in skip_tools) && demultiplexer == 'bcl2fastq') {
            RUNDIR_CHECKQC(ch_flowcells, BCL_DEMULTIPLEX.out.stats, BCL_DEMULTIPLEX.out.interop, checkqc_config, demultiplexer)
            ch_multiqc_files = ch_multiqc_files.mix(RUNDIR_CHECKQC.out.report.map { _meta, json -> json })
            ch_checkqc_reports = ch_checkqc_reports.mix(RUNDIR_CHECKQC.out.report)
        }
    }
    else if (demultiplexer == 'fqtk') {
        // MODULE: fqtk
        // Runs when "demultiplexer" is set to "fqtk"

        // Collect fastqs and read structures from field 2 of ch_flowcells
        fastq_read_structure = ch_flowcells
            .map { _meta, _samplesheet, per_flowcell_manifest, _dir -> per_flowcell_manifest }
            .splitCsv(header: true)
            .map { columns -> [columns.fastq, columns.read_structure] }

        // Format ch_samplesheet like so:
        // [[meta:id], <path to sample names and barcodes in tsv: path>, <path to fastqs: path>, [<fastq name: string>, <read structure: string>]]
        ch_samplesheet = ch_flowcells.merge(fastq_read_structure.toList()) { a, b -> tuple(a[0], a[1], a[3], b) }

        FQTK(csvToTSV(ch_samplesheet))
        ch_raw_fastq = ch_raw_fastq.mix(generateFastqMeta(FQTK.out.sample_fastq, /_R[0-9].*$/, 'SINGULAR'))
        ch_multiqc_files = ch_multiqc_files.mix(FQTK.out.metrics.map { _meta, metrics -> metrics })
        ch_demultiplex_reports = ch_demultiplex_reports.mix(FQTK.out.metrics)
    }
    else if (demultiplexer == 'sgdemux') {
        // MODULE: sgdemux
        // Runs when "demultiplexer" is set to "sgdemux"
        SGDEMUX(ch_flowcells)
        ch_raw_fastq = ch_raw_fastq.mix(generateFastqMeta(SGDEMUX.out.sample_fastq, /_R[0-9].*$/, 'SINGULAR'))
        ch_multiqc_files = ch_multiqc_files.mix(SGDEMUX.out.metrics.map { _meta, metrics -> metrics })
    }
    else if (demultiplexer == 'mkfastq') {
        // MODULE: mkfastq
        // Runs when "demultiplexer" is set to "mkfastq"
        CELLRANGER_MKFASTQ(ch_flowcells)
        ch_raw_fastq = ch_raw_fastq.mix(generateFastqMeta(CELLRANGER_MKFASTQ.out.fastq, /_R[0-9].*$/, 'SINGULAR'))
        ch_demultiplex_interop = ch_demultiplex_interop.mix(CELLRANGER_MKFASTQ.out.interop)
        ch_demultiplex_reports = ch_demultiplex_reports.mix(CELLRANGER_MKFASTQ.out.reports)
        ch_demultiplex_stats = ch_demultiplex_stats.mix(CELLRANGER_MKFASTQ.out.stats)
        ch_fastq_idx = ch_fastq_idx.mix(CELLRANGER_MKFASTQ.out.fastq_idx)
        ch_undetermined = ch_undetermined.mix(CELLRANGER_MKFASTQ.out.undetermined_fastq)
    }
    else if (demultiplexer == 'mgikit') {
        // MODULE: mgikit
        // Runs when "demultiplexer" is set to "mgikit"
        MGIKIT_DEMULTIPLEX(ch_flowcells)
        ch_raw_fastq = ch_raw_fastq.mix(generateFastqMeta(MGIKIT_DEMULTIPLEX.out.fastq, /_S\d+_L0\d+_R\d+.*$/, 'ELEMENT', true))
        ch_undetermined = ch_undetermined.mix(MGIKIT_DEMULTIPLEX.out.undetermined)
        ch_multiqc_files = ch_multiqc_files.mix(MGIKIT_DEMULTIPLEX.out.qc_reports.map { _meta, metrics -> metrics })
        ch_demultiplex_reports = ch_demultiplex_reports
            .mix(MGIKIT_DEMULTIPLEX.out.general_info_reports)
            .mix(MGIKIT_DEMULTIPLEX.out.index_reports)
            .mix(MGIKIT_DEMULTIPLEX.out.sample_stat_reports)
            .mix(MGIKIT_DEMULTIPLEX.out.undetermined_reports)
            .mix(MGIKIT_DEMULTIPLEX.out.ambiguous_reports)
    }
    else {
        error("Unknown demultiplexer: ${demultiplexer}")
    }
    ch_raw_fastq.dump(tag: "DEMULTIPLEX::Demultiplexed Fastq") { raw_fastq -> prettyFormat(raw_fastq) }

    //
    // RUN QC and TRIMMING
    //

    ch_fastq_to_qc = ch_raw_fastq

    // MODULE: fastp
    if (!("fastp" in skip_tools) && trim_fastq) {
        FASTP(ch_raw_fastq.map { meta, reads -> [meta, reads, []] }, [], [], [])
        ch_multiqc_files = ch_multiqc_files.mix(FASTP.out.json.map { _meta, json -> json })
        ch_fastp_reports = ch_fastp_reports.mix(FASTP.out.json).mix(FASTP.out.html)
        ch_fastq_to_qc = FASTP.out.reads
    }

    // MODULE: falco, drop in replacement for fastqc
    if (!("falco" in skip_tools)) {
        FALCO(ch_fastq_to_qc)
        ch_multiqc_files = ch_multiqc_files.mix(FALCO.out.txt.map { _meta, txt -> txt })
        ch_falco_reports = ch_falco_reports.mix(FALCO.out.html).mix(FALCO.out.txt)
    }

    // MODULE: md5sum
    // Split file list into separate channels entries and generate a checksum for each
    if (!("md5sum" in skip_tools)) {
        MD5SUM(ch_fastq_to_qc.transpose(), true)
        ch_md5_checksums = ch_md5_checksums.mix(MD5SUM.out.checksum)
    }

    // SUBWORKFLOW: FASTQ_CONTAM_SEQTK_KRAKEN
    if (!("kraken" in skip_tools) && kraken_db) {
        if (kraken_db.endsWith(".tar.gz")) {
            UNTAR_KRAKEN_DB([[], file(kraken_db)])
            kraken_db = UNTAR_KRAKEN_DB.out.untar.map { _meta, file -> file }
        }
        else {
            kraken_db = file(kraken_db)
        }
        FASTQ_CONTAM_SEQTK_KRAKEN(
            ch_fastq_to_qc,
            [sample_size],
            kraken_db,
        )
        ch_multiqc_files = ch_multiqc_files.mix(FASTQ_CONTAM_SEQTK_KRAKEN.out.reports.map { _meta, log -> log })
        ch_demultiplex_reports = ch_demultiplex_reports.mix(FASTQ_CONTAM_SEQTK_KRAKEN.out.reports)
        ch_fastq_to_qc = ch_fastq_to_qc.mix(FASTQ_CONTAM_SEQTK_KRAKEN.out.reads)
    }

    // Prepare metamap with fastq info
    ch_meta_fastq = ch_fastq_to_qc.map { meta, fastq_files ->
        // Normalize input to always be a list
        def files_list = fastq_files instanceof List ? fastq_files : [fastq_files]

        // Determine the publish directory based on the lane information
        def publish_dir = meta.lane ? "${outdir}/${meta.fcid}/L00${meta.lane}" : "${outdir}/${meta.fcid}"

        // Add full path for fastq files to the metadata
        def meta_out = meta + [
            publish_dir: publish_dir,
            fastq_1: "${publish_dir}/${files_list[0].getName()}",
        ]
        if (!meta.single_end && files_list.size() > 1) {
            meta_out.fastq_2 = "${publish_dir}/${files_list[1].getName()}"
        }
        return meta_out
    }

    // Samplesheet CSV creation via channel operators
    def pipelines = [
        'atacseq',
        'methylseq',
        'rnaseq',
        'sarek',
        'seqinspector',
        'taxprofiler',
    ]

    CHANNEL_FASTQ_CREATE_CSV(ch_meta_fastq, pipelines, strandedness)

    ch_pipeline_samplesheets = CHANNEL_FASTQ_CREATE_CSV.out.samplesheet

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_' + 'demultiplex_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )

    //
    // MODULE: MultiQC
    //
    // If a multiqc_config file is provided, we create a list and add it to the pipeline multiqc_config file.
    // That way both files are used in the pipeline
    // And the default multiqc_config file is always included
    // keeps modules ordering and path filters
    if (!("multiqc" in skip_tools)) {
        ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
        def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
        def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
        ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        def ch_multiqc_custom_methods_description = multiqc_methods_description
            ? file(multiqc_methods_description, checkIfExists: true)
            : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
        def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
        ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
        MULTIQC(
            ch_multiqc_files.flatten().collect().map { files ->
                [
                    [id: 'demultiplex'],
                    files,
                    multiqc_config
                        ? [file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true), file(multiqc_config, checkIfExists: true)]
                        : [file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true)],
                    multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                    [],
                    [],
                ]
            }
        )
        ch_multiqc_reports = ch_multiqc_reports
            .mix(MULTIQC.out.report.map { _meta, report -> report })
            .mix(MULTIQC.out.data.map { _meta, data -> data })
            .mix(MULTIQC.out.plots.map { _meta, plots -> plots })
    }
    ch_demultiplexed_fastq = ch_raw_fastq.mix(ch_fastq_to_qc)

    emit:
    demultiplexed_fastq   = ch_demultiplexed_fastq // channel: [ meta, path(fastq) ]
    demultiplex_reports   = ch_demultiplex_reports // channel: [ meta, path(demultiplex_report) ]
    demultiplex_interop   = ch_demultiplex_interop
    demultiplex_stats     = ch_demultiplex_stats
    demultiplex_logs      = ch_demultiplex_logs
    multiqc_report        = ch_multiqc_reports // channel: /path/to/multiqc_report.html
    versions              = ch_versions // channel: [ path(versions.yml) ]
    pipeline_samplesheets = ch_pipeline_samplesheets // channel: [ meta, samplesheet ]
    checkqc_reports       = ch_checkqc_reports // channel: [ meta, path(checkqc_report) ]
    fastp_reports         = ch_fastp_reports // channel: [ meta, path(fastp_report) ]
    falco_reports         = ch_falco_reports // channel: [ meta, path(falco_report) ]
    md5_checksums         = ch_md5_checksums // channel: [ meta, path(md5_checksum) ]
    fastq_idx             = ch_fastq_idx
    undetermined          = ch_undetermined
    undetermined_idx      = ch_undetermined_idx
    multiqcsav_report     = ch_multiqcsav_report
}
