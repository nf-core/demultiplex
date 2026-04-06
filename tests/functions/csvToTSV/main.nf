include { csvToTSV } from '../../../subworkflows/local/utils_nfcore_demultiplex_pipeline'

workflow TEST_CSVTOTSV {
    take:
    ch_samplesheet

    main:
    captured = csvToTSV(ch_samplesheet)
        .map { meta, sample_sheet_tsv, flowcell, fastq_readstructure_pairs ->
            [
                meta                     : meta,
                sample_sheet_tsv_name    : sample_sheet_tsv.getFileName().toString(),
                sample_sheet_tsv_content : sample_sheet_tsv.text,
                flowcell                 : flowcell,
                fastq_readstructure_pairs: fastq_readstructure_pairs,
            ]
        }

    emit:
    captured
}
