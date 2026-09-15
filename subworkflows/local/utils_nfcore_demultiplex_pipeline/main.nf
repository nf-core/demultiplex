//
// Subworkflow with functionality specific to the nf-core/demultiplex pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN   } from '../../nf-core/utils_nfschema_plugin'
include { paramsSummaryMap        } from 'plugin/nf-schema'
include { samplesheetToList       } from 'plugin/nf-schema'
include { paramsHelp              } from 'plugin/nf-schema'
include { completionEmail         } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary       } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE   } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NEXTFLOW_PIPELINE } from '../../nf-core/utils_nextflow_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {
    take:
    version // boolean: Display version and exit
    validate_params // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir //  string: The output directory where the results will be saved
    input //  string: Path to input samplesheet
    flowcell_id // string: Flowcell id for single-flowcell runs
    flowcell_samplesheet // string: Path to flowcell samplesheet for single-flowcell runs
    flowcell_lane // integer: Lane number for single-flowcell runs
    flowcell_path // string: Path to flowcell run directory for single-flowcell runs
    flowcell_per_flowcell_manifest // string: Path to per-flowcell manifest for fqtk
    help // boolean: Display help message and exit
    help_full // boolean: Show the full help message
    show_hidden // boolean: Show hidden parameters in the help message

    main:

    ch_versions = channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE(
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1,
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //

    def before_text = ""
    def after_text = ""
    before_text = """
-\033[2m----------------------------------------------------\033[0m-
                                        \033[0;32m,--.\033[0;30m/\033[0;32m,-.\033[0m
\033[0;34m        ___     __   __   __   ___     \033[0;32m/,-._.--~\'\033[0m
\033[0;34m  |\\ | |__  __ /  ` /  \\ |__) |__         \033[0;33m}  {\033[0m
\033[0;34m  | \\| |       \\__, \\__/ |  \\ |___     \033[0;32m\\`-._,-`-,\033[0m
                                        \033[0;32m`._,._,\'\033[0m
\033[0;35m  nf-core/demultiplex ${workflow.manifest.version}\033[0m
-\033[2m----------------------------------------------------\033[0m-
"""
    after_text = """${workflow.manifest.doi ? "\n* The pipeline\n" : ""}${workflow.manifest.doi.tokenize(",").collect { doi -> "    https://doi.org/${doi.trim().replace('https://doi.org/', '')}" }.join("\n")}${workflow.manifest.doi ? "\n" : ""}
* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/nf-core/demultiplex/blob/master/CITATIONS.md
"""
    if (monochrome_logs) {
        before_text = before_text.replaceAll(/\033\[[0-9;]*m/, '')
    }

    command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"

    UTILS_NFSCHEMA_PLUGIN(
        workflow,
        validate_params,
        null,
        help,
        help_full,
        show_hidden,
        before_text,
        after_text,
        command,
        false,
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE(
        nextflow_cli_args
    )

    //
    // Create channel from input file provided through params.input or from single-flowcell params
    //
    // When using the demultiplexer fqtk, the samplesheet must contain an additional
    // column per_flowcell_manifest. The column per_flowcell_manifest must contain
    // two headers fastq and read_structure
    // For reference:
    //      https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/samplesheet/1.3.0/fqtk-samplesheet.csv VS
    //      https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/samplesheet/1.3.0/sgdemux-samplesheet.csv

    def flowcell_params = [flowcell_id, flowcell_samplesheet, flowcell_lane, flowcell_path, flowcell_per_flowcell_manifest]
    def has_flowcell_params = flowcell_params.any { v -> v != null }

    // Validate single-flowcell parameters if provided
    if (has_flowcell_params) {
        if (params.demultiplexer == 'fqtk' && !flowcell_per_flowcell_manifest) {
            error("[Parameter Error] --flowcell_per_flowcell_manifest is required when using fqtk demultiplexer in single-flowcell mode")
        }
        if (params.demultiplexer == 'fqtk' && !file(flowcell_per_flowcell_manifest).exists()) {
            error("[Parameter Error] The per flowcell manifest file does not exist: ${flowcell_per_flowcell_manifest}")
        }
    }

    // Create flowcell input list as channel
    def flowcell_input_list = has_flowcell_params
        ? channel.of(
            [[id: params.flowcell_id.toString(), lane: params.flowcell_lane ?: []], file(params.flowcell_samplesheet), file(params.flowcell_path), params.flowcell_per_flowcell_manifest
                ? file(params.flowcell_per_flowcell_manifest)
                : []]
        )
        : channel.empty()

    if (params.demultiplexer == 'fqtk') {

        ch_samplesheet = (input
            ? channel.fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
            : flowcell_input_list).map { meta, samplesheet, flowcell, per_flowcell_manifest ->
            if (!file(per_flowcell_manifest).exists()) {
                error("[Samplesheet Error] The per flowcell manifest file does not exist: ${per_flowcell_manifest}")
            }
            [meta + [lane: meta.lane == [] ? null : meta.lane], samplesheet, flowcell, per_flowcell_manifest]
        }
    }
    else {
        ch_samplesheet = (input
            ? channel.fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
            : flowcell_input_list).map { meta, samplesheet, flowcell, per_flowcell_manifest ->
            [meta + [lane: meta.lane == [] ? null : meta.lane], samplesheet, flowcell, per_flowcell_manifest]
        }
    }

    ch_samplesheet.dump(tag: "ch_samplesheet")

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {
    take:
    email //  string: email address
    email_on_fail //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    multiqc_report //  string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def multiqc_reports = multiqc_report.toList()

    //
    // Completion email and summary
    //
    // We need to ensure that the multiqc_report is a value channel (DataflowVariable).
    // Queue channels will not be available in the workflow.onComplete block.

    workflow.onComplete {
        assert multiqc_reports instanceof groovyx.gpars.dataflow.DataflowVariable : "Expected a value channel (DataflowVariable) for multiqc_reports inside workflow.onComplete block."

        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                multiqc_reports.getVal(),
            )
        }

        completionSummary(monochrome_logs)
    }

    workflow.onError {
        log.error("Pipeline failed. Please refer to troubleshooting docs for common issues: https://nf-co.re/docs/running/troubleshooting")
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Get attribute from genome config file e.g. fasta
//
def getGenomeAttribute(attribute) {
    if (params.genomes && params.genome && params.genomes.containsKey(params.genome)) {
        if (params.genomes[params.genome].containsKey(attribute)) {
            return params.genomes[params.genome][attribute]
        }
    }
    return null
}

//
// Exit pipeline if incorrect --genome key provided
//
def genomeExistsError() {
    if (params.genomes && params.genome && !params.genomes.containsKey(params.genome)) {
        def error_string = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n" + "  Genome '${params.genome}' not found in any config files provided to the pipeline.\n" + "  Currently, the available genome keys are:\n" + "  ${params.genomes.keySet().join(", ")}\n" + "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        error(error_string)
    }
}
//
// Generate methods description for MultiQC
//
def toolCitationText() {
    // TODO nf-core: Optionally add in-text citation tools to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "Tool (Foo et al. 2023)" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def citation_text = [
        "Tools used in the workflow included:",
        "FastQC (Andrews 2010),",
        "MultiQC (Ewels et al. 2016)",
        ".",
    ].join(' ').trim()

    return citation_text
}

def toolBibliographyText() {
    // TODO nf-core: Optionally add bibliographic entries to this list.
    // Can use ternary operators to dynamically construct based conditions, e.g. params["run_xyz"] ? "<li>Author (2023) Pub name, Journal, DOI</li>" : "",
    // Uncomment function in methodsDescriptionText to render in MultiQC report
    def reference_text = [
        "<li>Andrews S, (2010) FastQC, URL: https://www.bioinformatics.babraham.ac.uk/projects/fastqc/).</li>",
        "<li>Ewels, P., Magnusson, M., Lundin, S., & Käller, M. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. Bioinformatics , 32(19), 3047–3048. doi: /10.1093/bioinformatics/btw354</li>",
    ].join(' ').trim()

    return reference_text
}

def methodsDescriptionText(mqc_methods_yaml) {
    // Convert  to a named map so can be used as with familiar NXF ${workflow} variable syntax in the MultiQC YML file
    def meta = [:]
    meta.workflow = workflow.toMap()
    meta["manifest_map"] = workflow.manifest.toMap()

    // Pipeline DOI
    if (meta.manifest_map.doi) {
        // Using a loop to handle multiple DOIs
        // Removing `https://doi.org/` to handle pipelines using DOIs vs DOI resolvers
        // Removing ` ` since the manifest.doi is a string and not a proper list
        def temp_doi_ref = ""
        def manifest_doi = meta.manifest_map.doi.tokenize(",")
        manifest_doi.each { doi_ref ->
            temp_doi_ref += "(doi: <a href=\'https://doi.org/${doi_ref.replace("https://doi.org/", "").replace(" ", "")}\'>${doi_ref.replace("https://doi.org/", "").replace(" ", "")}</a>), "
        }
        meta["doi_text"] = temp_doi_ref.substring(0, temp_doi_ref.length() - 2)
    }
    else {
        meta["doi_text"] = ""
    }
    meta["nodoi_text"] = meta.manifest_map.doi ? "" : "<li>If available, make sure to update the text to include the Zenodo DOI of version of the pipeline used. </li>"

    // Tool references
    meta["tool_citations"] = ""
    meta["tool_bibliography"] = ""

    // TODO nf-core: Only uncomment below if logic in toolCitationText/toolBibliographyText has been filled!
    // meta["tool_citations"] = toolCitationText().replaceAll(", \\.", ".").replaceAll("\\. \\.", ".").replaceAll(", \\.", ".")
    // meta["tool_bibliography"] = toolBibliographyText()


    def methods_text = mqc_methods_yaml.text

    def engine = new groovy.text.SimpleTemplateEngine()
    def description_html = engine.createTemplate(methods_text).make(meta)

    return description_html.toString()
}


def generateFastqMeta(ch_reads, sampleNameRegex = /_R[0-9].*$/, platform = 'SINGULAR', useSanitizedId = false) {
    ch_reads
        .transpose()
        .map { fc_meta, fastq ->
            def samplename = fastq.getSimpleName().toString() - ~sampleNameRegex
            def readgroup = readgroupFromFastq(fastq, platform) + [SM: samplename]
            def meta = [
                "id": useSanitizedId ? samplename.replaceAll(/[^A-Za-z0-9_.-]/, '_') : samplename,
                "samplename": samplename,
                "readgroup": readgroup,
                "fcid": fc_meta.id,
                "lane": fc_meta.lane,
            ]

            [meta, fastq]
        }
        .groupTuple(by: [0])
        .map { meta, fastq ->
            [meta + [single_end: fastq.size() == 1], fastq.flatten()]
        }
}

// https://github.com/nf-core/sarek/blob/7ba61bde8e4f3b1932118993c766ed33b5da465e/workflows/sarek.nf#L1014-L1040
def readgroupFromFastq(path, platform = 'SINGULAR') {
    def line

    path.withInputStream { inputStream ->
        InputStream gzipStream = new java.util.zip.GZIPInputStream(inputStream)
        Reader decoder = new InputStreamReader(gzipStream, 'ASCII')
        BufferedReader buffered = new BufferedReader(decoder)
        line = buffered.readLine()
    }
    assert line.startsWith('@')
    line = line.substring(1)
    def fields = line.split(':')
    def rg = [:]

    def fcid = fields[2]
    def lane = fields[3]
    def index = fields[-1] =~ /[GATC+-]/ ? fields[-1] : ""

    rg.ID = [fcid, lane].join('.')
    rg.PU = [fcid, lane, index].findAll().join('.')
    rg.PL = platform

    rg
}

def csvToTSV(ch_samplesheet) {
    def ch_samplesheet_tsv = ch_samplesheet
        .collectFile(storeDir: "${params.outdir}") { item ->
            def suffix = item[0].lane ? ".lane${item[0].lane}" : ""
            def lines_out = ''
            item[1]
                .readLines()
                .each { line ->
                    lines_out += line.replace(',', '\t') + '\n'
                }
            ["${item[0].id}${suffix}.tsv", lines_out]
        }
        .map { sample_sheet ->
            def meta_id = (sample_sheet =~ /.*\/(.*?)(\.lane|\.tsv)/)[0][1]
            def meta_lane = sample_sheet.getName().contains('.lane') ? (sample_sheet =~ /\.lane(\d+)/)[0][1].toInteger() : null
            [[id: meta_id.toString(), lane: meta_lane], sample_sheet]
        }

    ch_samplesheet
        .join(ch_samplesheet_tsv, failOnMismatch: true)
        .map { meta, _sample_sheet_csv, flowcell, fastq_readstructure_pairs, sample_sheet_tsv ->
            [meta, sample_sheet_tsv, flowcell, fastq_readstructure_pairs]
        }
}

def removeAdapters(samplesheet) {
    def lines_out = ''
    def removal_checker = false
    samplesheet
        .readLines()
        .each { line ->
            if (line =~ /Adapter(Read[12])?,[ACGT]+,?/) {
                removal_checker = true
            }
            else {
                // keep original line otherwise
                lines_out = lines_out + line + '\n'
            }
        }
    if (!removal_checker) {
        System.out.println("\u001B[94m[INFO] Parameter `remove_samplesheet_adapter` was set to true but no adapters were found in samplesheet\u001B[0m")
    }
    return lines_out
}

def prettyFormat(Object object) {
    // Convert problematic types to strings before JSON conversion
    def sanitized = sanitizeObject(object)
    def json = new groovy.json.JsonBuilder(sanitized)
    return groovy.json.JsonOutput.prettyPrint(json.toString())
}

def sanitizeObject(Object object) {
    if (object == null) {
        return null
    }
    else if (object instanceof Map) {
        return object.collectEntries { k, v -> [k, sanitizeObject(v)] }
    }
    else if (object instanceof Collection) {
        return object.collect { it -> sanitizeObject(it) }
    }
    else if (object instanceof java.nio.file.Path) {
        return object.toString()
    }
    else if (object instanceof java.time.OffsetDateTime) {
        return object.toString()
    }
    else if (object.getClass().getName().contains('Duration')) {
        return object.toString()
    }
    else {
        return object
    }
}
