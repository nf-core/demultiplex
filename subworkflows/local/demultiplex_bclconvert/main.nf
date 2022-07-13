#!/usr/bin/env nextflow

//
// Demultiplex Illumina BCL data using bcl-convert
//

include { BCLCONVERT } from "../../../modules/nf-core/modules/bclconvert/main"

workflow DEMULTIPLEX_BCLCONVERT {
    take:
        ch_flowcell // [[id:"", lane:""],samplesheet.csv, path/to/bcl/files]

    main:
        ch_versions = Channel.empty()

        // MODULE: bclconvert
        // Demultiplex the bcl files
        BCLCONVERT( ch_flowcell )
        ch_versions = ch_versions.mix(BCLCONVERT.out.versions)

        // Generate meta for each fastq
        ch_bclconvert_fastq = generate_fastq_meta(BCLCONVERT.out.fastq)

    emit:
        bclconvert_fastq    = ch_bclconvert_fastq
        bclconvert_reports  = BCLCONVERT.out.reports
        bclconvert_interop  = BCLCONVERT.out.interop
        versions            = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Add meta values to fastq channel
def generate_fastq_meta(ch_reads) {
    ch_reads.map {
        fc_meta, raw_fastq ->
        raw_fastq
    }
    // Create a tuple with the meta.id and the fastq
    .flatten().map{
        fastq ->
        def meta = [
            "id": fastq.getSimpleName().toString() - ~/_R[0-9]_001.*$/,
            "samplename": fastq.getSimpleName().toString() - ~/_S[0-9]+.*$/,
            "readgroup": [:]
        ]
        meta.readgroup = readgroup_from_fastq(fastq)
        meta.readgroup.SM = meta.samplename

        return [ meta , fastq ]
    }
    // Group by meta.id for PE samples
    .groupTuple(by: [0])
    // Add meta.single_end
    .map {
        meta, fastq ->
        if (fastq.size() == 1){
            meta.single_end = true
        } else {
            meta.single_end = false
        }
        return [ meta, fastq.flatten() ]
    }
}

// https://github.com/nf-core/sarek/blob/7ba61bde8e4f3b1932118993c766ed33b5da465e/workflows/sarek.nf#L1014-L1040
def readgroup_from_fastq(path) {
    // expected format:
    // xx:yy:FLOWCELLID:LANE:... (seven fields)
    // or
    // FLOWCELLID:LANE:xx:... (five fields)
    def line

    path.withInputStream {
        InputStream gzipStream = new java.util.zip.GZIPInputStream(it)
        Reader decoder = new InputStreamReader(gzipStream, 'ASCII')
        BufferedReader buffered = new BufferedReader(decoder)
        line = buffered.readLine()
    }
    assert line.startsWith('@')
    line = line.substring(1)
    def fields = line.split(':')
    def rg = [:]

    if (fields.size() >= 7) {
        // CASAVA 1.8+ format, from  https://support.illumina.com/help/BaseSpace_OLH_009008/Content/Source/Informatics/BS/FileFormat_FASTQ-files_swBS.htm
        // "@<instrument>:<run number>:<flowcell ID>:<lane>:<tile>:<x-pos>:<y-pos>:<UMI> <read>:<is filtered>:<control number>:<index>"
        sequencer_serial = fields[0]
        run_nubmer       = fields[1]
        fcid             = fields[2]
        lane             = fields[3]
        index            = fields[-1] =~ /[GATC+-]/ ? fields[-1] : ""

        rg.ID = [fcid,lane].join(".")
        rg.PU = [fcid, lane, index].findAll().join(".")
        rg.PL = "ILLUMINA"
    } else if (fields.size() == 5) {
        fcid = fields[0]

        rg.ID = fcid
    }
    return rg
}
