process FASTQ_TO_SAMPLESHEET {
    tag "$meta.id"

    executor 'local'
    memory 100.MB

    input:
    val meta
    val pipeline
    val strandedness

    output:
    tuple val(meta_clone), path("*samplesheet.csv"), emit: samplesheet

    exec:

    // Calculate the dynamic output directory based on meta.lane
    def outputDir = meta.publish_dir

    // Add relevant fields to the map
    def pipeline_map = [
        sample  : meta.samplename,
        fastq_1 : outputDir + '/' + file(meta.fastq_1).fileName
    ]

    // Add fastq_2 if it's a paired-end sample
    if (!meta.single_end) {
        pipeline_map.fastq_2 = outputDir + '/' + file(meta.fastq_2).fileName
    }

    // Add pipeline-specific entries
    if (pipeline == 'rnaseq') {
        pipeline_map << [ strandedness: strandedness ]
    } else if (pipeline == 'atacseq') {
        pipeline_map << [ replicate: 1 ]
    } else if (pipeline == 'taxprofiler') {
        pipeline_map << [ fasta: '' ]
    }

    // Create the samplesheet content
    def samplesheet = pipeline_map.keySet().collect { '"' + it + '"' }.join(",") + '\n'
    samplesheet += pipeline_map.values().collect { '"' + it + '"' }.join(",")

    // Write samplesheet to file
    def samplesheet_file = task.workDir.resolve("${meta.id}.samplesheet.csv")
    samplesheet_file.text = samplesheet

    meta_clone = meta.clone()
    meta_clone.remove('publishdir')

}
