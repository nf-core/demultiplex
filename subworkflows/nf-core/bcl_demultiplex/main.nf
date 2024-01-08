#!/usr/bin/env nextflow

//
// Demultiplex Illumina BCL data using bcl-convert or bcl2fastq
//

include { BCLCONVERT } from "../../../modules/nf-core/bclconvert/main"
include { BCL2FASTQ  } from "../../../modules/nf-core/bcl2fastq/main"

workflow BCL_DEMULTIPLEX {
    take:
        ch_flowcell     // [[id:"", lane:""],samplesheet.csv, path/to/bcl/files]
        demultiplexer   // bclconvert or bcl2fastq

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

        // MODULE: bclconvert
        // Demultiplex the bcl files
        if (demultiplexer == "bclconvert") {
            BCLCONVERT( ch_flowcells )
            ch_fastq    = ch_fastq.mix(BCLCONVERT.out.fastq)
            ch_interop  = ch_interop.mix(BCLCONVERT.out.interop)
            ch_reports  = ch_reports.mix(BCLCONVERT.out.reports)
            ch_versions = ch_versions.mix(BCLCONVERT.out.versions)
        }

        // MODULE: bcl2fastq
        // Demultiplex the bcl files
        if (demultiplexer == "bcl2fastq") {
            BCL2FASTQ( ch_flowcells )
            ch_fastq    = ch_fastq.mix(BCL2FASTQ.out.fastq)
            ch_interop  = ch_interop.mix(BCL2FASTQ.out.interop)
            ch_reports  = ch_reports.mix(BCL2FASTQ.out.reports)
            ch_stats    = ch_stats.mix(BCL2FASTQ.out.stats)
            ch_versions = ch_versions.mix(BCL2FASTQ.out.versions)
        }

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
// Assume 'workDir' is a predefined variable pointing to the working directory
def failedFastqsLog = "${workDir}/failed_fastqs.log"
def failedDir = "${workDir}/failed_fastqs"

// Function to handle logging and moving failed FASTQ files
def handleFailedFile(String path) {
    // Ensure the directory for failed FASTQ files exists
    new File(failedDir).mkdirs()

    // Append the file path and error timestamp to the log file
    new File(failedFastqsLog).withWriterAppend { writer ->
        writer.println("${new Date()} - Empty or Failed FASTQ: ${path}")
    }

    // Move the file to the failed directory (consider copy for safety)
    new File(path).renameTo(new File("$failedDir/${path.split('/').last()}"))
}

// Main function to process FASTQ files and extract read group information
def readgroup_from_fastq(path) {
    def line

    try {
        // Attempt to open and read the first line of the FASTQ file
        path.withInputStream {
            InputStream gzipStream = new java.util.zip.GZIPInputStream(it)
            Reader decoder = new InputStreamReader(gzipStream, 'ASCII')
            BufferedReader buffered = new BufferedReader(decoder)
            line = buffered.readLine()
        }

        // Check if the line is null or doesn't start with '@'
        if (line == null || !line.startsWith('@')) {
            // Handle the failure for improper file format or empty file
            handleFailedFile(path)
            return null  // Signal to skip this file
        }

        // Process the read line to extract read group information
        line = line.substring(1)
        def fields = line.split(':')
        if (fields.length < 7) {
            // Handle the failure for unexpected number of fields
            handleFailedFile(path)
            return null  // Signal to skip this file
        }

        // Extract and return the read group information
        def rg = [:]
        rg.ID = [fields[2], fields[3]].join(".")  // Example: FLOWCELLID.LANE
        rg.PU = [fields[2], fields[3], fields[-1]].findAll().join(".")  // Example: FLOWCELLID.LANE.INDEX
        rg.PL = "ILLUMINA"

        return rg

    } catch (Exception e) {
        // Handle any unexpected errors during file processing
        handleFailedFile(path)
        return null  // Signal to skip this file
    }
}
