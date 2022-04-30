process BCL2FASTQ_PROBLEM_SS {
    tag "problem_samplesheet"
    label 'process_high'

    if (params.enable_conda) {
        exit 1, "Conda environments cannot be used when using bcl-convert. Please use docker or singularity containers."
    }
    container "nfcore/demultiplex:bcl2fastq-2.20.0"

    input:
    path sheet
    path result

    output:
    file "Stats/Stats.json", emit: stats_json_file

    when:
    result.name =~ /^fail.*/

    script:
    """
    bcl2fastq \\
        --runfolder-dir ${runDir} \\
        --output-dir . \\
        --sample-sheet ${sheet} \\
        --ignore-missing-bcls \\
        --ignore-missing-filter \\
        --with-failed-reads \\
        --barcode-mismatches 0 \\
        --loading-threads ${task.cpus / 3} \\
        --processing-threads ${task.cpus} \\
        --writing-threads ${task.cpus / 4}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcl2fastq: TODO
    END_VERSIONS
    """
}
