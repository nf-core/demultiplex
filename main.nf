#!/usr/bin/env nextflow
/*
========================================================================================
                         nf-core/demultiplex
========================================================================================
 nf-core/demultiplex Analysis Pipeline.
 #### Homepage / Documentation
 https://github.com/nf-core/demultiplex
 #### Authors
 Chelsea Sawyer <chelsea.sawyer@crick.ac.uk> - https://github.com/csawye01/demultiplex
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    // TODO nf-core: Add to this help message with new command line parameters
    log.info"""
    =======================================================
                                              ,--./,-.
              ___     __   __   __   ___     /,-._.--~\'
        |\\ | |__  __ /  ` /  \\ |__) |__         }  {
        | \\| |       \\__, \\__/ |  \\ |___     \\`-._,-`-,
                                              `._,._,\'

     nf-core/demultiplex v${workflow.manifest.version}
    =======================================================

    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-core/demultiplex --samplesheet /camp/stp/sequencing/inputs/instruments/fastq/RUNFOLDER/SAMPLESHEET.csv

    Mandatory arguments:

      --samplesheet                 Full pathway to samplesheet
      -profile                      Configuration profile to use. Can use multiple (comma separated)
                                    Available: conda, docker, singularity, awsbatch, test and more.

    Options:
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      --outdir                      The output directory where the results will be saved
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

    bcl2fastq Options:
      --adapter_stringency              The minimum match rate that would trigger the masking or trimming process
      --barcode_mismatches              Number of allowed mismatches per index
      --create_fastq_for_indexreads     Create FASTQ files also for Index Reads
      --ignore_missing_bcls             Missing or corrupt BCL files are ignored. Assumes 'N'/'#' for missing calls
      --ignore_missing_filter           Missing or corrupt filter files are ignored. Assumes Passing Filter for all clusters in tiles where filter files are missing
      --ignore_missing_positions        Missing or corrupt positions files are ignored. If corresponding position files are missing, bcl2fastq writes unique coordinate positions in FASTQ header.
      --minimum_trimmed_readlength      Minimum read length after adapter trimming.
      --mask_short_adapter_reads        This option applies when a read is shorter than the length specified by --minimum-trimmed-read-length (note that the read does not specifically have to be trimmed for this option to trigger, it need only fall below the —minimum-trimmed-read-length for any reason).
      --tiles                           The --tiles argument takes a regular expression to select for processing only a subset of the tiles available in the flow cell Multiple selections can be made by separating the regular expressions with commas
      --use_bases_mask                  The --use-bases-mask string specifies how to use each cycle
      --with_failed_reads               Include all clusters in the output, even clusters that are non-PF. These clusters would have been excluded by default
      --write_fastq_reversecomplement   Generate FASTQ files containing reverse complements of actual data.
      --no_bgzf_compression             Turn off BGZF compression, and use GZIP for FASTQ files. BGZF compression allows downstream applications to decompress in parallel.
      --fastq_compression_level         Zlib compression level (1–9) used for FASTQ files.
      --no_lane_splitting               Do not split FASTQ files by lane.
      --find_adapters_withsliding-window    Find adapters with simple sliding window algorithm. Insertions and deletions of bases inside the adapter sequence are not handled.

    AWSBatch options:
      --awsqueue                    The AWSBatch JobQueue that needs to be set when running on AWSBatch
      --awsregion                   The AWS Region for your AWS Batch job to run on
    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}

// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

////////////////////////////////////////////////////
/* --          VALIDATE INPUTS                 -- */
////////////////////////////////////////////////////
if ( params.samplesheet ){
    ss_sheet = file(params.samplesheet)
    if( !ss_sheet.exists() ) exit 1, "Sample sheet not found: ${params.samplesheet}"
}

if( workflow.profile == 'awsbatch') {
  // AWSBatch sanity checking
  if (!params.awsqueue || !params.awsregion) exit 1, "Specify correct --awsqueue and --awsregion parameters on AWSBatch!"
  if (!workflow.workDir.startsWith('s3') || !params.outdir.startsWith('s3')) exit 1, "Specify S3 URLs for workDir and outdir parameters on AWSBatch!"
  // Check workDir/outdir paths to be S3 buckets if running on AWSBatch
  // related: https://github.com/nextflow-io/nextflow/issues/813
  if (!workflow.workDir.startsWith('s3:') || !params.outdir.startsWith('s3:')) exit 1, "Workdir or Outdir not on S3 - specify S3 Buckets for each to run on AWSBatch!"
}

// Stage config files
ch_multiqc_config = Channel.fromPath(params.multiqc_config)
ch_output_docs = Channel.fromPath("$baseDir/docs/output.md")


// Header log info
log.info """=======================================================
                                          ,--./,-.
          ___     __   __   __   ___     /,-._.--~\'
    |\\ | |__  __ /  ` /  \\ |__) |__         }  {
    | \\| |       \\__, \\__/ |  \\ |___     \\`-._,-`-,
                                          `._,._,\'

nf-core/demultiplex v${workflow.manifest.version}"
======================================================="""
def summary = [:]
summary['Pipeline Name']  = 'nf-core/demultiplex'
summary['Pipeline Version'] = workflow.manifest.version
summary['Run Name']     = custom_runName ?: workflow.runName
// TODO nf-core: Report custom parameters here
summary['Max Memory']   = params.max_memory
summary['Max CPUs']     = params.max_cpus
summary['Max Time']     = params.max_time
summary['Output dir']   = params.outdir
summary['Working dir']  = workflow.workDir
summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outdir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
if(workflow.profile == 'awsbatch'){
   summary['AWS Region'] = params.awsregion
   summary['AWS Queue'] = params.awsqueue
}
if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


def create_workflow_summary(summary) {
    def yaml_file = workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'nf-core-demultiplex-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'nf-core/demultiplex Workflow Summary'
    section_href: 'https://github.com/nf-core/demultiplex'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
    """.stripIndent()

   return yaml_file
}

/*
 * Parse software version numbers
 */
process get_software_versions {

    output:
    file 'software_versions_mqc.yaml' into software_versions_yaml

    script:
    // TODO nf-core: Get all tools to print their version number here
    """
    echo $workflow.manifest.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    bcl2fastq --version > v_bcl2fastq.txt
    fastqc --version > v_fastqc.txt
    fastq_screen --version > v_fastq_screen.txt
    multiqc --version > v_multiqc.txt
    scrape_software_versions.py > software_versions_mqc.yaml
    """
}


///////////////////////////////////////////////////////////////////////////////
/* --                                                                     -- */
/* --                              MODULES                                -- */
/* --                                                                     -- */
///////////////////////////////////////////////////////////////////////////////
def MODULE_PYTHON_DEFAULT = "Python/3.6.4-foss-2018a"
def MODULE_BCL2FASTQ_DEFAULT = "bcl2fastq2/2.20.0-foss-2018a"
def MODULE_FASTQC_DEFAULT = "FastQC/0.11.7-Java-1.8.0_172"
def MODULE_FSCREEN_DEFAULT = "FastQ_Screen/0.12.1-foss-2018a-Perl-5.26.1"
def MODULE_MULTIQC_DEFAULT = "MultiQC/1.6-Python-2.7.15-foss-2018a"
def MODULE_CELLRANGER_DEFAULT = "CellRanger/3.0.2-bcl2fastq-2.20.0"


if (params.samplesheet){
    lastPath = params.samplesheet.lastIndexOf(File.separator)
    runName_dir =  params.samplesheet.substring(0,lastPath+1)
    runName =  params.samplesheet.substring(51,lastPath)
    samplesheet_string = params.samplesheet.getName()
}
// make channel for file

//outputDir = file("/camp/stp/sequencing/inputs/instruments/fastq/${runName}")
outputDir = file("/camp/stp/babs/working/sawyerc/nf_demux_test/${runName}/")
outDir_result = outputDir.mkdir()

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
/* --                                                                     -- */
/* --               Sample Sheet Reformatting and Check`                  -- */
/* --                                                                     -- */
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

/*
 * STEP 1 - Check sample sheet for iCLIP samples and 10X samples
 *        - This will collapse iCLIP samples into one sample and pull out 10X
 *          samples into new samplesheet
 */

process reformat_samplesheet {
  tag 'reformat_samplesheet'
  module MODULE_PYTHON_DEFAULT

  input:
  file sheet from ss_sheet

  output:
  file "*.standard.csv" into standard_samplesheet1, standard_samplesheet2, standard_samplesheet3, standard_samplesheet4
  file "*.10x.csv" optional true into tenx_samplesheet
  file "*.txt" into tenx_results1, tenx_results2

  script:
  """
  collapse_iclip.py --samplesheet "${sheet}"
  """
}

/*
 * STEP 2 - Check samplesheet for single and dual mixed lanes and long and short
 *          indexes on same lanes and output pass or fail file to next processes
 */

process check_samplesheet {
  tag 'check_samplesheet'
  module MODULE_PYTHON_DEFAULT

  input:
  file sheet from standard_samplesheet1

  output:
  file "*.txt" into failChannel1, failChannel2, failChannel3

  script:
  // output a value to  send to choice channel
  """
  check_samplesheet.py --samplesheet "${sheet}"
  """
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
/* --                                                                     -- */
/* --               Problem Sample Sheet Processes`                       -- */
/* --                                                                     -- */
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

/*
 * STEP 3 - If previous process fails remove problem samples from entire sample
 *          and create a new one
 *          ONLY RUNS WHEN SAMPLESHEET FAILS
 */

process make_fake_SS {
  tag 'fake_samplesheet'
  module MODULE_PYTHON_DEFAULT

  input:
  file sheet from standard_samplesheet2
  file result from failChannel1

  when:
  result.name =~ /^fail.*/

  output:
  file "*.csv" into fake_samplesheet
  file "*.txt" into problem_samples_list1, problem_samples_list2

  script:
  """
  create_falseSS.py --samplesheet "${sheet}"
  """
}

/*
 * STEP 4 -  Running bcl2fastq on the false_samplesheet
 *     ONLY RUNS WHEN SAMPLESHEET FAILS
 */

process bcl2fastq_problem_SS {
  tag 'bcl2fastq_problem_SS'
  module MODULE_BCL2FASTQ_DEFAULT

  input:
  file sheet from fake_samplesheet

  output:
  file "Stats/Stats.json" into stats_json_file

  script:
  """
  bcl2fastq \\
      --runfolder-dir ${runName_dir} \\
      --output-dir ${tempOutputDir} \\
      --sample-sheet ${sheet} \\
      --ignore-missing-bcls \\
      --ignore-missing-filter \\
      --with-failed-reads \\
      --barcode-mismatches 0 \\
      --loading-threads 8 \\
      --processing-threads 24 \\
      --writing-threads 6 \\
  """
}

/*
 * STEP 5 -  Parsing .json file output from the bcl2fastq run to access the
 *           unknown barcodes section. The barcodes that match the short indexes
 *           and/or missing index 2 with the highest count to remake the sample
 *           sheet so that bcl2fastq can run properly
 *     ONLY RUNS WHEN SAMPLESHEET FAILS
 */
process parse_jsonfile {
  tag 'parse_jsonfile'
  module MODULE_PYTHON_DEFAULT

  input:
  file json from stats_json_file
  file sheet from standard_samplesheet3
  file samp_probs from problem_samples_list1
  file result from failChannel3

  when:
  result.name =~ /^fail.*/

  output:
  file "*.csv" into updated_samplesheet1, updated_samplesheet2

  script:
  """
  parse_json.py --samplesheet "${sheet}" \\
  --jsonfile "${json}" \\
  --problemsamples "${samp_probs}"
  """
}

/*
 * STEP 6 -  Checking the remade sample sheet. If this fails again the pipeline
 *           will exit and fail
 *     ONLY RUNS WHEN SAMPLESHEET FAILS
 */

PROBLEM_SS_CHECK2 = Channel.create()
process recheck_samplesheet {
  tag 'recheck_samplesheet'
  module MODULE_PYTHON_DEFAULT


  input:
  file sheet from updated_samplesheet

  when:
  result.name =~ /^fail.*/

  output:
  stdout into PROBLEM_SS_CHECK2

  script:
  """
  check_samplesheet.py --samplesheet "${sheet}"
  """

}


// Take sample check result and merge into same variable as passed samplesheet
//samplesheet_check_2.choice( PROBLEM_SS_CHECK2, BCL2FASTQ ) { a -> a[0] =~ /^fail.*/ ? 0 : 1 }
//BCL2FASTQ_CHECK2= Channel.value(BCL2FASTQ).ifEmpty { exit 1, "Sample sheet recheck failed" }


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
/* --                                                                     -- */
/* --               Main Demultiplexing Processes`                        -- */
/* --                                                                     -- */
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

/*
 * STEP 7 -  Running bcl2fastq on the remade samplesheet or a sample sheet that
 *           passed the initial check. bcl2fastq parameters can be changed
 */

process bcl2fastq_default {
    tag 'bcl2fastq'
    module MODULE_BCL2FASTQ_DEFAULT
    publishDir "${params.outdir}/FastQ", mode: 'copy'

    input:
    set val(v), file(updated_samplesheet) from BCL2FASTQ

    output:
    file "*/**.fastq.gz" into fastqs_fqc_ch, fastqs_screen_ch mode flatten
    file "*.fastq.gz" into undetermined_default_fq_ch mode flatten
    file "Reports" into b2fq_default_reports_ch
    file "Stats" into b2fq_default_stats_ch

    script:

    """
    bcl2fastq \\
        --runfolder-dir ${runName_dir} \\
        --output-dir . \\
        --sample-sheet ${updated_samplesheet} \\
        --adapter-stringency ${params.adapter_stringency} \\
        --create-fastq-for-index-reads ${params.create_fastq_for_indexreads} \\
        --ignore-missing-bcls ${params.ignore_missing_bcls} \\
        --ignore-missing-filter ${params.ignore_missing_filter} \\
        --ignore-missing-positions ${params.ignore_missing_positions} \\
        --minimum-trimmed-read-length ${params.minimum_trimmed_readlength} \\
        --mask-short-adapter-reads ${params.mask_short_adapter_reads} \\
        --tiles ${params.tiles} \\
        --use-bases-mask ${params.use_bases_mask} \\
        --with-failed-reads ${params.with_failed_reads} \\
        --write-fastq-reverse-complement ${params.write_fastq_reversecomplement} \\
        --no-bgzf-compression ${params.no_bgzf_compression} \\
        --fastq-compression-level ${params.fastq_compression_level} \\
        --no-lane-splitting ${params.no_lane_splitting}  \\
        --find-adapters-with-sliding-window ${params.find_adapters_withsliding} \\
        --barcode-mismatches ${params.barcode_mismatches} \\
    """
}

// Capture Sample ID from FastQ file name
def getFastqNameFile(fqfile) {
    //println fqfile
    def m = fqfile =~ /(.+)_S\d+_L00\d_R(1|2)_001\.fastq\.gz/
    if (m.getCount()) {
        return m[0][1]
    }
}

sample_project_ch = Channel.fromPath(reformatted_samplesheet).splitCsv(header: true, skip: 1).map { row -> [ row.Sample_ID, row.Sample_Project ] }

// This channel will be a tuple associating a sample ID and a fastq file
fqname_fqfile_ch = fastqs_fqc_ch.map { fqfile -> [ getFastqNameFile(fqfile.getName()), fqfile ] }

// This creates two channels containing tuples associating a sample ID, a fastq file and a project name
// One channel will be used for fastqc and the other one for fastq screen
fqname_fqfile_ch.combine(sample_project_ch, by: 0).into{ fqname_fqfile_project_fqc_ch; fqname_fqfile_project_fastqscreen_ch }

/*
 * STEP 8 - CellRanger MkFastQ
 * for the potential of a 10X samplesheet existing
 */

process cellRangerMkFastQ {
    tag 'cellRangerMkFastQ'
    module MODULE_CELLRANGER_DEFAULT
    publishDir "${params.outdir}/FastQ", mode: 'copy'

    input:
    file sheet from tenx_samplesheet
    file result from tenx_results1

    when:
    result.name =~ /^true.*/

    output:
    file "*/*_fastqc" into cr_fq_folder_ch mode flatten

    script:
    "cellranger mkfastq --run ${runName_dir} --samplesheet ${sheet}"
}

// This channel will be a tuple associating a sample ID and a fastq file
cr_fqname_fqfile_ch = cr_fq_folder_ch.map { fqfile -> [ getFastqNameFile(fqfile.getName()), fqfile ] }

// This creates a channel containing tuples associating a sample ID, a fastq file and a project name
// This channel will be used for CellRanger Count
cr_sample_project_ch = Channel.fromPath(cellranger_input).splitCsv(header: true, skip: 1).map { row -> [ row.Sample_ID, row.Sample_Project ] }
cr_fqname_fqfile_ch.combine(cr_sample_project_ch, by: 0).into{ cr_fqname_fqfile_project_ch}

/*
 * STEP 9 - CellRanger count
 * for the potential of a 10X samplesheet existing
 */

process cellRangerCount {
  tag 'cellRangerCount'
  module MODULE_CELLRANGER_DEFAULT
  publishDir "${params.outdir}/CellRangerCount", mode: 'copy'

  input:
  set val(sampleName), file(fqFile), val(projectName) from cr_fqname_fqfile_project_ch
  file result from tenx_results1

  when:
  result.name =~ /^true.*/

  script:
  "cellranger count --id ${projectName} --transcriptome --fastqs ${fqFile} --sample ${sampleName}"

}

/*
 * STEP 10 - FastQC
 */

process fastqc {
    tag "$name"
    module MODULE_FASTQC_DEFAULT
    publishDir "${params.outdir}/FastQC", mode: 'copy',
        saveAs: {filename -> filename.indexOf(".zip") > 0 ? "zips/$filename" : "$filename"}

    input:
    set val(sampleName), file(fqFile), val(projectName) from fqname_fqfile_project_fqc_ch
    //combine in results if 10X samples are present

    output:
    file "*/*_fastqc" into fqc_folder_ch

    script:
    """
    mkdir ${params.outdir}${projectName}
    fastqc --outdir ${params.outdir}${projectName} --extract ${fqFile}
    """
}

/*
 * STEP 11 - FastQ Screen
 */

process fastq_screen {
    tag "$name"
    module MODULE_FASTQC_DEFAULT
    publishDir "${params.outdir}/FastQScreen", mode: 'copy',
        saveAs: {filename -> filename.indexOf(".zip") > 0 ? "zips/$filename" : "$filename"}

    input:
    set val(sampleName), file(fqFile), val(projectName) from fqname_fqfile_project_fastqscreen_ch

    output:
    file "*/*_fastqc" into fqc_folder_ch

    script:
    """
    fastq_screen ${fqFile} --outdir ${params.outdir}${projectName}
    """
}

/*
 * STEP 12 - MultiQC
 */
process multiqc {
    module MODULE_MULTIQC_DEFAULT
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    input:
    file fqc_folder from fqc_folder_ch.collect()

    output:
    file "*multiqc_report.html" into multiqc_report
    file "*_data"

    script:
    """
    multiqc ${fqc_folder} --config $multiqc_config .
    """
}


/*
 * STEP 13 - Output Description HTML
 */

process output_documentation {
    publishDir "${params.outdir}/Documentation", mode: 'copy'

    input:
    file output_docs from ch_output_docs

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.r $output_docs results_description.html
    """
}

/*
 * Completion e-mail notification
 */
workflow.onComplete {

    // Set up the e-mail variables
    def subject = "[nf-core/demultiplex] Successful: $workflow.runName"
    if(!workflow.success){
      subject = "[nf-core/demultiplex] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = workflow.manifest.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
    email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
    email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir" ]
    def sf = new File("$baseDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (params.email) {
        try {
          if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
          // Try to send HTML e-mail using sendmail
          [ 'sendmail', '-t' ].execute() << sendmail_html
          log.info "[nf-core/demultiplex] Sent summary e-mail to $params.email (sendmail)"
        } catch (all) {
          // Catch failures and try with plaintext
          [ 'mail', '-s', subject, params.email ].execute() << email_txt
          log.info "[nf-core/demultiplex] Sent summary e-mail to $params.email (mail)"
        }
    }

    // Write summary e-mail HTML to a file
    def output_d = new File( "${params.outdir}/Documentation/" )
    if( !output_d.exists() ) {
      output_d.mkdirs()
    }
    def output_hf = new File( output_d, "pipeline_report.html" )
    output_hf.withWriter { w -> w << email_html }
    def output_tf = new File( output_d, "pipeline_report.txt" )
    output_tf.withWriter { w -> w << email_txt }

    log.info "[nf-core/demultiplex] Pipeline Complete"

}
