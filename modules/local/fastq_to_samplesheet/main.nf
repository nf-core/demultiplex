process FASTQ_TO_SAMPLESHEET {
    tag "$meta.id"

    executor 'local'
    memory 100.MB

    input:
    val meta
    val pipeline
    val strandedness

    output:
    tuple val(meta), path("*samplesheet.csv"), emit: samplesheet

    exec:
    // Clone metadata and remove unnecessary keys
    def meta_clone = meta.clone()
    meta_clone.remove("id")
    meta_clone.remove("single_end")
    meta_clone.remove("fcid")
    meta_clone.remove("readgroup")
    meta_clone.remove("empty")
    meta_clone.remove("lane")

    // // Add relevant fields to the map
    def pipeline_map = [
        sample  : meta.samplename,
        fastq_1 : meta.fastq_1
    ]

    // // Add fastq_2 if it's a paired-end sample
    if (!meta.single_end) {
        pipeline_map.fastq_2 = meta.fastq_2
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

}
