process BCL2FASTQ {
    tag "${std_samplesheet.name}"
    label 'process_high'

    if (params.enable_conda) {
        exit 1, "Conda environments cannot be used when using bcl-convert. Please use docker or singularity containers."
    }
    container "nfcore/demultiplex:bcl2fastq-2.20.0"

    input:
    path result2
    path result
    path std_samplesheet
    path sheet
    path bcl_result

    output:
    path "*/**{R1,R2,R3}_001.fastq.gz", emit: fastq
    path "*/**{I1,I2}_001.fastq.gz"   , emit: fastqs_idx
    path "*{R1,R2,R3}_001.fastq.gz"   , emit: undetermined
    path "*{I1,I2}_001.fastq.gz"      , emit: undetermined_idx
    path "Reports"                    , emit: reports
    path "Stats"                      , emit: stats

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''

    if (result.name =~ /^pass.*/){
        """
        bcl2fastq \\
        --runfolder-dir ${runDir} \\
        --output-dir . \\
        --sample-sheet ${std_samplesheet} \\
        --adapter-stringency ${params.adapter_stringency} \\
        $args \\
        --minimum-trimmed-read-length ${params.minimum_trimmed_readlength} \\
        --mask-short-adapter-reads ${params.mask_short_adapter_reads} \\
        --fastq-compression-level ${params.fastq_compression_level} \\
        --barcode-mismatches ${params.barcode_mismatches} \\
        $args2
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
        $args \\
        --minimum-trimmed-read-length ${params.minimum_trimmed_readlength} \\
        --mask-short-adapter-reads ${params.mask_short_adapter_reads} \\
        --fastq-compression-level ${params.fastq_compression_level} \\
        --barcode-mismatches ${params.barcode_mismatches}
        $args2
        """
    }
}
