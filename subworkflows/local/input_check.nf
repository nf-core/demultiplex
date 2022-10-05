//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fc_channel(it) }
        .set { flowcells }

    emit:
    flowcells                                 // channel: [ val(meta), samplesheet, reads ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta,  flowcell ]
def create_fc_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id   = row.flowcell
    meta.lane = row.lane ?: ""

    // add path(s) of the fastq file(s) to the meta map
    def fc_meta = []
    if (!file(row.run_dir).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> FLowcell input does not exist!\n${row.run_dir}"
    }
    if (!file(row.samplesheet).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> FLowcell SampleSheet does not exist!\n${row.samplesheet}"
    }
    fc_meta = [
        meta,
        file(row.samplesheet, checkIfExists: true),
        file(row.run_dir, checkIfExists: true)
    ]
    return fc_meta
}
