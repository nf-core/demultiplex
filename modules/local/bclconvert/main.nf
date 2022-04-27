process BCLCONVERT {
    tag "$meta.id"
    label 'process_high'

    if (params.enable_conda) {
        exit 1, "Conda environments cannot be used when using bcl-convert. Please use docker or singularity containers."
    }
    container "nfcore/bclconvert:3.9.3"

    input:
    tuple val(meta), path(samplesheet), path(run_dir)

    output:
    tuple val(meta), path("**.fastq.gz")            ,emit: fastq
    path("Reports/*.{csv,xml}")                     ,emit: reports
    path("Logs/*.{log,txt}")                        ,emit: logs
    path("**.bin")                                  ,emit: interop
    path("versions.yml")                            ,emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    bcl-convert \\
        $args \\
        --output-directory . \\
        --bcl-input-directory ${run_dir} \\
        --sample-sheet ${samplesheet} \\
        --bcl-num-parallel-tiles ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bclconvert: \$(bcl-convert -V 2>&1 | head -n 1 | sed 's/^.*Version //')
    END_VERSIONS
    """
}