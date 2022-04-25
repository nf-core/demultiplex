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

    /*
    * STEP 7 - CellRanger MkFastQ.
    *          ONLY RUNS WHEN ANY TYPE OF 10X SAMPLESHEET EXISTS.
    */

    CELLRANGER_MKFASTQ ( tenx_samplesheet1, tenx_results1)

    /*
    * STEP 8 - Copy CellRanger FastQ files to new folder.
    *          ONLY RUNS WHEN ANY TYPE OF 10X SAMPLES EXISTS.
    */
    def getCellRangerSampleName(fqfile) {
        def sampleName = (fqfile =~ /.*\/outs\/fastq_path\/.*\/(.+)_S\d+_L00\d_[IR][123]_001\.fastq\.gz/)
        if (sampleName.find()) {
            return sampleName.group(1)
        }
        return fqfile
    }

    def getCellRangerProjectName(fqfile) {
        def projectName = (fqfile =~ /.*\/outs\/fastq_path\/([a-zA-Z0-9_]*)\//)
        if (projectName.find()) {
            return projectName.group(1)
        }
        return fqfile
    }

    cr_fastqs_copyfs_tuple_ch = cr_fastqs_copyfs_ch.map { fqfile -> [ getCellRangerProjectName(fqfile), getCellRangerSampleName(fqfile), fqfile.getFileName() ] }
    cr_undetermined_fastqs_copyfs_tuple_ch = cr_undetermined_move_fq_ch.map { fqfile -> [ "Undetermined", fqfile.getFileName() ] }

    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////
    /* --                                                                     -- */
    /* --               Main Demultiplexing Processes`                        -- */
    /* --                                                                     -- */
    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////

    /*
    * STEP 10 - Running bcl2fastq on the remade samplesheet or a sample sheet that
    *           passed the initial check. bcl2fastq parameters can be changed when
    *           staring up the pipeline.
    *           ONLY RUNS WHEN SAMPLES REMAIN AFTER Single Cell SAMPLES ARE SPLIT OFF
    *           INTO SEPARATE SAMPLE SHEETS.
    */
    process bcl2fastq_default {
        tag "${std_samplesheet.name}"
        publishDir path: "${params.outdir}/${runName}/fastq", mode: 'copy'

        label 'process_high'

        input:
        file result2 from PROBLEM_SS_CHECK2.ifEmpty { true }
        file result from resultChannel5
        file std_samplesheet from standard_samplesheet4
        file sheet from updated_samplesheet2.ifEmpty { true }
        file bcl_result from bcl2fastq_results1

        when:
        bcl_result.name =~ /^true.bcl2fastq.txt/

        output:
        file "*/**{R1,R2,R3}_001.fastq.gz" into fastqs_fqc_ch, fastqs_screen_ch, fastq_kraken_ch mode flatten
        file "*/**{I1,I2}_001.fastq.gz" optional true into fastqs_idx_ch
        file "*{R1,R2,R3}_001.fastq.gz" into undetermined_default_fq_ch, undetermined_default_fastqs_screen_ch, undetermined_fastq_kraken_ch mode flatten
        file "*{I1,I2}_001.fastq.gz" optional true into undetermined_idx_fq_ch
        file "Reports" into b2fq_default_reports_ch
        file "Stats" into b2fq_default_stats_ch

        script:
        ignore_miss_bcls = params.ignore_missing_bcls ? "--ignore-missing-bcls " : ""
        ignore_miss_filt = params.ignore_missing_filter ? "--ignore-missing-filter " : ""
        ignore_miss_pos = params.ignore_missing_positions ? "--ignore-missing-positions " : ""
        bases_mask = params.use_bases_mask ? "--use-bases-mask ${params.use_bases_mask} " : ""
        tiles = params.tiles ? "--tiles ${params.tiles} " : ""
        fq_index_rds = params.create_fastq_for_indexreads ? "--create-fastq-for-index-reads " : ""
        failed_rds = params.with_failed_reads ? "--with-failed-reads " : ""
        fq_rev_comp = params.write_fastq_reversecomplement ? "--write-fastq-reverse-complement" : ""
        no_bgzf_comp = params.no_bgzf_compression ? "--no-bgzf-compression " : ""
        no_lane_split = params.no_lane_splitting ? "--no-lane-splitting " : ""
        slide_window_adapt =  params.find_adapters_withsliding_window ? "--find-adapters-with-sliding-window " : ""

        if (result.name =~ /^pass.*/){
            """
            bcl2fastq \\
                --runfolder-dir ${runDir} \\
                --output-dir . \\
                --sample-sheet ${std_samplesheet} \\
                --adapter-stringency ${params.adapter_stringency} \\
                $tiles \\
                $ignore_miss_bcls \\
                $ignore_miss_filt \\
                $ignore_miss_pos \\
                --minimum-trimmed-read-length ${params.minimum_trimmed_readlength} \\
                --mask-short-adapter-reads ${params.mask_short_adapter_reads} \\
                --fastq-compression-level ${params.fastq_compression_level} \\
                --barcode-mismatches ${params.barcode_mismatches} \\
                $bases_mask $fq_index_rds $failed_rds  \\
                $fq_rev_comp $no_bgzf_comp $no_lane_split $slide_window_adapt
            """
        } else if (result2.name =~ /^fail.*/){
            exit 1, "Remade sample sheet still contains problem samples"
        } else if (result.name =~ /^fail.*/){
            """
            bcl2fastq \\
                --runfolder-dir ${runDir} \\
                --output-dir . \\
                --sample-sheet ${sheet} \\
                --adapter-stringency ${params.adapter_stringency} \\
                $tiles \\
                $ignore_miss_bcls \\
                $ignore_miss_filt \\
                $ignore_miss_pos \\
                --minimum-trimmed-read-length ${params.minimum_trimmed_readlength} \\
                --mask-short-adapter-reads ${params.mask_short_adapter_reads} \\
                --fastq-compression-level ${params.fastq_compression_level} \\
                --barcode-mismatches ${params.barcode_mismatches}
                $bases_mask $fq_index_rds $failed_rds  \\
                $fq_rev_comp $no_bgzf_comp $no_lane_split $slide_window_adapt
            """
        }
    }

    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////
    /* --                                                                     -- */
    /* --                           FastQC                                    -- */
    /* --                                                                     -- */
    ///////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////

    /*
    * STEP 11 - FastQC
    */
    fqname_fqfile_ch = fastqs_fqc_ch.map { fqFile -> [fqFile.getParent().getName(), fqFile ] }
    undetermined_default_fqfile_tuple_ch = undetermined_default_fq_ch.map { fqFile -> ["Undetermined_default", fqFile ] }
    cr_fqname_fqfile_fqc_ch = cr_fastqs_fqc_ch.map { fqFile -> [getCellRangerProjectName(fqFile), fqFile ] }
    cr_undetermined_default_fq_tuple_ch = cr_undetermined_default_fq_ch.map { fqFile -> ["Undetermined_default", fqFile ] }

    fastqcAll = Channel.empty()
    fastqcAll_ch = fastqcAll.mix(fqname_fqfile_ch, undetermined_default_fqfile_tuple_ch, cr_fqname_fqfile_fqc_ch, cr_undetermined_default_fq_tuple_ch)

    process fastqc {
        tag "${projectName}"
        publishDir path: "${params.outdir}/${runName}/fastqc/${projectName}", mode: 'copy'
        label 'process_high'

        when:
        !params.skip_fastqc

        input:
        set val(projectName), file(fqFile) from fastqcAll_ch

        output:
        set val(projectName), file("*_fastqc") into fqc_folder_ch, all_fcq_files_tuple
        file "*.html" into fqc_html_ch

        script:
        """
        fastqc --extract ${fqFile}
        """
    }

    // function to determine if paired end or not
    def getFastqPairName(fqfile) {
        def sampleName = (fqfile =~ /.*\/(.+)_[R][12]_001\.fastq\.gz/)
        if (sampleName.find()) {
            return sampleName.group(1)
        }
        return fqfile
    }

    // fastq_kraken_ch.map { fastq -> [ getFastqPairName(fastq), fastq] }.groupTuple().set{ fastq_pairs_ch }
    // process kraken2 {
    //     tag "${projectName}"
    //     publishDir path: "${params.outdir}/${runName}/kraken2/${projectName}", mode: 'copy'
    //     label 'process_high'
    //
    //     when:
    //     !params.skip_kraken2
    //
    //     input:
    //     set val(projectName), file(fqFile) from fastq_pairs_ch
    //
    //     output:
    //     set val(projectName), file("*_fastqc") into fqc_folder_ch, all_fcq_files_tuple
    //     file "*.html" into fqc_html_ch
    //
    //     script:
    //
    //     """
    //     kraken2 \\
    //         --db $kraken_db \\
    //         --threads $task.cpus \\
    //         --output %s.out.txt \\
    //         --report %s.report.txt
    //         $single_end \\
    //         --gzip-compressed %s \\
    //         $fastq_files
    //     """
    // }

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
    fastqs_screen_fqfile_ch = fastqs_screen_ch.map { fqFile -> [fqFile.getParent().getName(), fqFile ] }
    undetermined_fastqs_screen_fqfile_ch = undetermined_default_fastqs_screen_ch.map { fqFile -> ["Undetermined_default", fqFile ] }
    cr_fqname_fqfile_screen_ch = cr_fastqs_screen_ch.map { fqFile -> [getCellRangerProjectName(fqFile), fqFile ] }
    cr_undetermined_fastqs_screen_tuple_ch = cr_undetermined_fastqs_screen_ch.map { fqFile -> ["Undetermined_default", fqFile ] }

    fastqcScreenAll = Channel.empty()
    grouped_fqscreen_ch = fastqcScreenAll.mix(fastqs_screen_fqfile_ch, cr_fqname_fqfile_screen_ch, cr_undetermined_fastqs_screen_tuple_ch, undetermined_fastqs_screen_fqfile_ch)

    if (params.fastq_screen_conf) {
        process fastq_screen {
            tag "${projectName}"
            publishDir "${params.outdir}/${runName}/fastq_screen/${projectName}", mode: 'copy'
            label 'process_high'

            input:
            set val(projectName), file(fqFile) from grouped_fqscreen_ch
            file fastq_screen_config from ch_fastq_screen_config

            output:
            set val(projectName), file("*_screen.txt") into fastq_screen_txt, all_fq_screen_txt_tuple
            file "*_screen.html" into fastq_screen_html

            script:
            """
            fastq_screen --force --subset 200000 --conf $ch_fastq_screen_config --aligner bowtie2 ${fqFile}
            """
        }
    } else {
        fastq_screen_txt = Channel.create()
        all_fq_screen_txt_tuple = Channel.create()
    }

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
