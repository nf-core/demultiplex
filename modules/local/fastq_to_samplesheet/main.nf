process FASTQ_TO_SAMPLESHEET {

    executor 'local'
    memory 100.MB

    input:
    val meta // Expecting a list of items
    val pipeline
    val strandedness

    output:
    tuple val(meta_clone), path("*samplesheet.csv"), emit: samplesheet

    exec:
    // Initialize the samplesheet content
    def samplesheetHeader = []
    def samplesheetRows = []

    // Sort meta by item.id
    def sortedMeta = meta.sort { it.id }

    // Collect all unique columns from all items and create rows
    def allColumns = new LinkedHashSet()

    sortedMeta.each { item ->
        // Check for required keys in each item
        if (!item.samplename) {
            error "Item with id ${item.id} is missing the 'samplename' key."
        }
        if (!item.fastq_1) {
            error "Item with id ${item.id} is missing the 'fastq_1' key."
        }

        def pipeline_map = [:] // Initialize as an empty map

        // Prepare sample information
        pipeline_map.sample = item.samplename
        pipeline_map.fastq_1 = item.publish_dir + '/' + file(item.fastq_1).fileName

        // Add fastq_2 if it's a paired-end sample
        if (!item.single_end && item.fastq_2) {
            pipeline_map.fastq_2 = item.publish_dir + '/' + file(item.fastq_2).fileName ?: ''
        }

        // Add pipeline-specific entries
        if (pipeline == 'rnaseq') {
            pipeline_map.strandedness = strandedness ?: ''
        } else if (pipeline == 'atacseq') {
            pipeline_map.replicate = 1
        } else if (pipeline == 'taxprofiler') {
            pipeline_map.fasta = ''
        } else if (pipeline == 'sarek') {
            pipeline_map.patient = ''
            pipeline_map.lane = "${item.lane}"
        } else if (pipeline == 'methylseq') {
            pipeline_map.genome = ''
        }

        // Add all keys to the set of unique columns
        allColumns.addAll(pipeline_map.keySet())

        // Prepare a row for the samplesheet, filling in missing values with empty strings
        def rowValues = allColumns.collect { key ->
            pipeline_map.containsKey(key) ? '"' + pipeline_map[key] + '"' : '""'
        }
        samplesheetRows << rowValues.join(",")
    }

    // Create a sorted list of headers
    samplesheetHeader = allColumns.collect { '"' + it + '"' }

    // Create the complete samplesheet content
    def samplesheet = samplesheetHeader.join(",") + '\n' + samplesheetRows.join("\n")

    // Write samplesheet to file
    def samplesheet_file = task.workDir.resolve("${pipeline}_samplesheet.csv")
    samplesheet_file.text = samplesheet

    // Clone the first item in meta for output
    meta_clone = meta.first().clone()
    meta_clone.remove('publish_dir') // Removing the publish_dir just in case, although output channel is not used by other process

}
