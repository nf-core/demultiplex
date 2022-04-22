process BCL2FASTQ {
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

    file "*/**{R1,R2,R3}_001.fastq.gz" into fastqs_fqc_ch, fastqs_screen_ch, fastq_kraken_ch mode flatten
    file "*/**{I1,I2}_001.fastq.gz" optional true into fastqs_idx_ch
    file "*{R1,R2,R3}_001.fastq.gz" into undetermined_default_fq_ch, undetermined_default_fastqs_screen_ch, undetermined_fastq_kraken_ch mode flatten
    file "*{I1,I2}_001.fastq.gz" optional true into undetermined_idx_fq_ch
    file "Reports" into b2fq_default_reports_ch
    file "Stats" into b2fq_default_stats_ch
    output:

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
