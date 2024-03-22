#!/usr/bin/env nextflow

//
// Demultiplex Illumina BCL data using bcl-convert or bcl2fastq or dragen
//

include { DRAGEN_DEMULTIPLEXER     } from "../../../modules/local/dragen_demultiplexer/main"

workflow DRAGEN_DEMULTIPLEX {
    take:
        ch_flowcell     // [[id:"", lane:""],samplesheet.csv, path/to/bcl/files]
        demultiplexer   // bclconvert or bcl2fastq or dragen

    main:
        ch_versions = Channel.empty()
        ch_fastq    = Channel.empty()
        ch_reports  = Channel.empty()
        ch_stats    = Channel.empty()
        ch_interop  = Channel.empty()

        // Split flowcells into separate channels containg run as tar and run as path
        // https://nextflow.slack.com/archives/C02T98A23U7/p1650963988498929
        ch_flowcell
            .branch { meta, samplesheet, run ->
                tar: run.toString().endsWith(".tar.gz")
                dir: true
            }.set { ch_flowcells }

        ch_flowcells.tar
            .multiMap { meta, samplesheet, run ->
                samplesheets: [ meta, samplesheet ]
                run_dirs: [ meta, run ]
            }.set { ch_flowcells_tar }

        // Runs when run_dir is a tar archive
        // Re-join the metadata and the untarred run directory with the samplesheet
        ch_flowcells_tar_merged = ch_flowcells_tar.samplesheets.join( ch_flowcells_tar.run_dirs )

        // Merge the two channels back together
        ch_flowcells = ch_flowcells.dir.mix(ch_flowcells_tar_merged)

        // MODULE: DRAGEN
        // Demultiplex the bcl files
        DRAGEN_DEMULTIPLEXER( ch_flowcells )
        ch_fastq    = ch_fastq.mix(DRAGEN_DEMULTIPLEXER.out.fastq)
        ch_interop  = ch_interop.mix(DRAGEN_DEMULTIPLEXER.out.interop)
        ch_reports  = ch_reports.mix(DRAGEN_DEMULTIPLEXER.out.reports)
        ch_stats    = ch_stats.mix(DRAGEN_DEMULTIPLEXER.out.stats)
        ch_versions = ch_versions.mix(DRAGEN_DEMULTIPLEXER.out.versions)


        // Generate meta for each fastq
        ch_fastq_with_meta = generate_fastq_meta(ch_fastq)

    emit:
        fastq    = ch_fastq_with_meta
        reports  = ch_reports
        stats    = ch_stats
        interop  = ch_interop
        versions = ch_versions
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
            "id": fastq.getSimpleName().toString() - ~/_R[0-9]_001.*$/,
            "samplename": fastq.getSimpleName().toString() - ~/_S[0-9]+.*$/,
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

    return rg
}
