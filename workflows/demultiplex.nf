/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { BCL_DEMULTIPLEX           } from '../subworkflows/nf-core/bcl_demultiplex/main'
include { BASES_DEMULTIPLEX         } from '../subworkflows/local/bases_demultiplex/main'
include { FQTK_DEMULTIPLEX          } from '../subworkflows/local/fqtk_demultiplex/main'
include { SINGULAR_DEMULTIPLEX      } from '../subworkflows/local/singular_demultiplex/main'
include { CHECKQC_DIR               } from '../modules/local/checkqc_dir/main'

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTP                         } from '../modules/nf-core/fastp/main'
include { FALCO                         } from '../modules/nf-core/falco/main'
include { MULTIQC                       } from '../modules/nf-core/multiqc/main'
include { UNTAR                         } from '../modules/nf-core/untar/main'
include { MD5SUM                        } from '../modules/nf-core/md5sum/main'
include { CHECKQC                       } from "../modules/nf-core/checkqc/main"

//
// FUNCTION
//
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_demultiplex_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DEMULTIPLEX {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:
    // Value inputs
    demultiplexer = params.demultiplexer                                   // string: bases2fastq, bcl2fastq, bclconvert, fqtk, sgdemux
    trim_fastq    = params.trim_fastq                                      // boolean: true, false
    skip_tools    = params.skip_tools ? params.skip_tools.split(',') : []  // list: [falco, fastp, multiqc]

    // Channel inputs
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_multiqc_reports = Channel.empty()
    checkqc_config    = params.checkqc_config ? Channel.fromPath(params.checkqc_config, checkIfExists: true) : []  // file checkqc_config.yaml

    // Convenience
    ch_samplesheet.dump(tag: 'DEMULTIPLEX::inputs', {FormattingService.prettyFormat(it)})

    // Split flowcells into separate channels containg run as tar and run as path
    // https://nextflow.slack.com/archives/C02T98A23U7/p1650963988498929
    if (demultiplexer == 'fqtk'){

        ch_flowcells = ch_samplesheet
            .branch { meta, samplesheet, flowcell, per_flowcell_manifest ->
                tar: flowcell.toString().endsWith('.tar.gz')
                dir: true
            }
        ch_flowcells_tar = ch_flowcells.tar
            .multiMap { meta, samplesheet, flowcell, per_flowcell_manifest ->
                samplesheets: [ meta, samplesheet, per_flowcell_manifest ]
                run_dirs: [ meta, flowcell ]
            }
    } else {

        ch_flowcells = ch_samplesheet
            .map { meta, samplesheet, flowcell, per_flowcell_manifest ->
                [ meta, samplesheet, flowcell ]
            }
            .branch { meta, samplesheet, flowcell ->
                tar: flowcell.toString().endsWith('.tar.gz')
                dir: true
            }
        ch_flowcells_tar = ch_flowcells.tar
            .multiMap { meta, samplesheet, flowcell ->
                samplesheets: [ meta, samplesheet ]
                run_dirs: [ meta, flowcell ]
            }
    }

    // MODULE: untar
    // Runs when run_dir is a tar archive
    // Except for bclconvert and bcl2fastq for wich we untar in the process
    // Re-join the metadata and the untarred run directory with the samplesheet

    if (demultiplexer in ['bclconvert', 'bcl2fastq']) ch_flowcells_tar_merged = ch_flowcells_tar.samplesheets.join(ch_flowcells_tar.run_dirs, failOnMismatch:true, failOnDuplicate:true)
    else {
        ch_flowcells_tar_merged = ch_flowcells_tar.samplesheets.join( UNTAR ( ch_flowcells_tar.run_dirs ).untar, failOnMismatch:true, failOnDuplicate:true )
        ch_versions = ch_versions.mix(UNTAR.out.versions)
    }

    // Merge the two channels back together
    ch_flowcells = ch_flowcells.dir.mix(ch_flowcells_tar_merged)

    // RUN demultiplexing
    //
    ch_raw_fastq = Channel.empty()

    switch (demultiplexer) {
        case 'bases2fastq':
            // MODULE: bases2fastq
            // Runs when "demultiplexer" is set to "bases2fastq"
            BASES_DEMULTIPLEX ( ch_flowcells )
            ch_raw_fastq = ch_raw_fastq.mix(BASES_DEMULTIPLEX.out.fastq)
            // TODO: verify that this is the correct output
            ch_multiqc_files = ch_multiqc_files.mix(BASES_DEMULTIPLEX.out.metrics.map { meta, metrics -> return metrics} )
            ch_versions = ch_versions.mix(BASES_DEMULTIPLEX.out.versions)
            break
        case ['bcl2fastq', 'bclconvert']:
            // SUBWORKFLOW: illumina
            // Runs when "demultiplexer" is set to "bclconvert" or "bcl2fastq"
            BCL_DEMULTIPLEX( ch_flowcells, demultiplexer )
            ch_raw_fastq = ch_raw_fastq.mix( BCL_DEMULTIPLEX.out.fastq )
            ch_multiqc_files = ch_multiqc_files.mix( BCL_DEMULTIPLEX.out.reports.map { meta, report -> return report} )
            ch_multiqc_files = ch_multiqc_files.mix( BCL_DEMULTIPLEX.out.stats.map   { meta, stats  -> return stats } )
            ch_versions = ch_versions.mix(BCL_DEMULTIPLEX.out.versions)

                if (!("checkqc" in skip_tools)){
                        ch_dir = ch_flowcells.join(BCL_DEMULTIPLEX.out.stats).join(BCL_DEMULTIPLEX.out.interop)
                        CHECKQC_DIR(ch_dir)
                        CHECKQC_DIR.out.checkqc_dir.dump(tag:"CHECKQC_DIR")
                        CHECKQC(CHECKQC_DIR.out.checkqc_dir, checkqc_config)
                        CHECKQC.out.report.dump(tag:"CHECKQC_report")
                    }

            break
        case 'fqtk':
            // MODULE: fqtk
            // Runs when "demultiplexer" is set to "fqtk"

            // Collect fastqs and read structures from field 2 of ch_flowcells
            fastq_read_structure = ch_flowcells.map{it[2]}
                .splitCsv(header:true)
                .map{[it.fastq, it.read_structure]}

            // Combine the directory containing the fastq with the fastq name and read structure
            // [example_R1.fastq.gz, 150T, ./work/98/30bc..78y/fastqs/]
            fastqs_with_paths = fastq_read_structure.combine(UNTAR.out.untar.collect{it[1]}).toList()

            // Format ch_samplesheet like so:
            // [[meta:id], <path to sample names and barcodes in tsv: path>, [<fastq name: string>, <read structure: string>, <path to fastqs: path>]]]
            ch_samplesheet = ch_flowcells.merge( fastqs_with_paths ) { a,b -> tuple(a[0], a[1], b)}

            FQTK_DEMULTIPLEX ( ch_samplesheet )
            ch_raw_fastq = ch_raw_fastq.mix(FQTK_DEMULTIPLEX.out.fastq)
            ch_multiqc_files = ch_multiqc_files.mix(FQTK_DEMULTIPLEX.out.metrics.map { meta, metrics -> return metrics} )
            ch_versions = ch_versions.mix(FQTK_DEMULTIPLEX.out.versions)
            break
        case 'sgdemux':
            // MODULE: sgdemux
            // Runs when "demultiplexer" is set to "sgdemux"
            SINGULAR_DEMULTIPLEX ( ch_flowcells )
            ch_raw_fastq = ch_raw_fastq.mix(SINGULAR_DEMULTIPLEX.out.fastq)
            ch_multiqc_files = ch_multiqc_files.mix(SINGULAR_DEMULTIPLEX.out.metrics.map { meta, metrics -> return metrics} )
            ch_versions = ch_versions.mix(SINGULAR_DEMULTIPLEX.out.versions)
            break
        default:
            error "Unknown demultiplexer: ${demultiplexer}"
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
    if (!("md5sum" in skip_tools)){
        MD5SUM(ch_fastq_to_qc.transpose())
        ch_versions = ch_versions.mix(MD5SUM.out.versions)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    // MODULE: MultiQC
    if (!("multiqc" in skip_tools)){
        ch_multiqc_files.collect().dump(tag: "multiqc_files",{FormattingService.prettyFormat(it)})

        ch_multiqc_config        = Channel.fromPath(
            "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
        ch_multiqc_custom_config = params.multiqc_config ?
            Channel.fromPath(params.multiqc_config, checkIfExists: true) :
            Channel.empty()
        ch_multiqc_logo= params.multiqc_logo ?
            Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
            Channel.empty()
        summary_params      = paramsSummaryMap(
            workflow, parameters_schema: "nextflow_schema.json")
        ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

        ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
            file(params.multiqc_methods_description, checkIfExists: true) :
            file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
        ch_methods_description                = Channel.value(
            methodsDescriptionText(ch_multiqc_custom_methods_description))

        ch_multiqc_files = ch_multiqc_files.mix(
            ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
        ch_multiqc_files = ch_multiqc_files.mix(
            ch_methods_description.collectFile(
                name: 'methods_description_mqc.yaml',
                sort: true
            )
        )

        MULTIQC (
            ch_multiqc_files.collect(),
            ch_multiqc_config.toList(),
            ch_multiqc_custom_config.toList(),
            ch_multiqc_logo.toList()
        )
        ch_multiqc_reports = ch_multiqc_reports.mix(MULTIQC.out.report)
    }

    emit:
    multiqc_report = ch_multiqc_reports // channel: /path/to/multiqc_report.html
    versions       = ch_versions        // channel: [ path(versions.yml) ]

}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
