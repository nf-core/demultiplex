#!/usr/bin/env nextflow

//
// Demultiplex FASTQ files with fqtk
//

include { FQTK }  from "../../../modules/nf-core/fqtk/main"
include { CSV2TSV } from "../../../modules/local/csv2tsv"

workflow FQTK_DEMULTIPLEX {
    take:
        ch_input     // [[id:"", lane:""],samplesheet.csv, [[fastq_name, read_structure, fastq_dir]]]

    main:
        // Convert csv to tsv
        CSV2TSV( ch_input )

        // MODULE: fqtk
        FQTK( CSV2TSV.out.ch_output )

        // Generate meta for each fastq
        ch_fastq_with_meta = generate_fastq_meta(FQTK.out.sample_fastq)

        // Add versions to versions channel
        ch_versions = FQTK.out.versions.mix(CSV2TSV.out.versions)

    emit:
        fastq                   = ch_fastq_with_meta
        metrics                 = FQTK.out.metrics
        unassigned              = FQTK.out.most_frequent_unmatched
        versions                = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Add meta values to fastq channel
def generate_fastq_meta(ch_reads) {
    // Create a tuple with the meta.id and the fastq
    ch_reads.transpose().map{
        fc_meta, fastq ->
        def meta = [
            "id": fastq.getSimpleName().toString() - ~/_R[0-9].*$/,
            "samplename": fastq.getSimpleName().toString() - ~/_R[0-9].*$/,
            "readgroup": [:],
            "fcid": fc_meta.id,
            "lane": fc_meta.lane
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

    // "@<instrument>:<run number>:<flowcell ID>:<lane>:<tile>:<x-pos>:<y-pos>:UMI <read>:N:0:<index sequence>"
    sequencer_serial = fields[0]
    run_nubmer       = fields[1]
    fcid             = fields[2]
    lane             = fields[3]
    index            = fields[-1] =~ /[GATC+-]/ ? fields[-1] : ""

    rg.ID = [fcid,lane].join(".")
    rg.PU = [fcid, lane, index].findAll().join(".")
    rg.PL = "SINGULAR"

    return rg
}
