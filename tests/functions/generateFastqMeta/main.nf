include { generateFastqMeta } from '../../../subworkflows/local/utils_nfcore_demultiplex_pipeline'

workflow TEST_GENERATEFASTQMETA {
    take:
    ch_reads
    sample_name_regex
    platform
    use_sanitized_id

    main:
    captured = generateFastqMeta(ch_reads, sample_name_regex, platform, use_sanitized_id)
        .map { meta, fastqs ->
            [
                meta,
                fastqs.collect { it.getFileName().toString() }
            ]
        }

    emit:
    captured
}
