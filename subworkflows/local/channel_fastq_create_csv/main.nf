workflow CHANNEL_FASTQ_CREATE_CSV {
    take:
    ch_meta_fastq // channel: queue channel of meta maps
    pipelines // val: list of pipeline names
    strandedness // val: strandedness

    main:
    ch_samplesheet = ch_meta_fastq.collect()
        .flatMap { meta_list ->
            pipelines.collect { pipeline -> [pipeline, meta_list] }
        }
        .map { pipeline, meta_list ->
            def items = meta_list.collect { meta -> buildSamplesheetMeta(meta, pipeline, strandedness) }

            // Compute union of all keys across all rows
            def allKeys = [] as LinkedHashSet
            items.each { allKeys.addAll(it.keySet()) }

            // Build header and rows with all columns
            def header = allKeys.collect { key -> '"' + key + '"' }.join(",")
            def rows = items.collect { meta ->
                allKeys
                    .collect { key ->
                        meta.containsKey(key) ? '"' + meta[key] + '"' : '""'
                    }
                    .join(",")
            }

            return [pipeline, "${header}\n${rows.join("\n")}"]
        }
        .collectFile { item -> ["${item[0]}_samplesheet.csv", item[1]] }

    emit:
    samplesheet = ch_samplesheet
}

//
// FUNCTIONS
//

def buildSamplesheetMeta(meta, pipeline, strandedness) {
    def pipeline_extras = [
        atacseq: [replicate: 1],
        methylseq: [genome: ''],
        rnaseq: [strandedness: strandedness ?: ''],
        sarek: [patient: '', lane: "${meta.lane}"],
        seqinspector: [rundir: '', tags: '', flowcell: meta.fcid ?: ''],
        taxprofiler: [fasta: ''],
    ]

    def fastq_2 = (!meta.single_end && meta.fastq_2)
        ? [fastq_2: meta.publish_dir + '/' + file(meta.fastq_2).fileName]
        : [:]

    return [
        sample: meta.samplename,
        fastq_1: meta.publish_dir + '/' + file(meta.fastq_1).fileName,
    ] + fastq_2 + (pipeline_extras[pipeline] ?: [:])
}
