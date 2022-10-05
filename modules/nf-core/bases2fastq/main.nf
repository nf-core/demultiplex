process BASES2FASTQ {
    tag "$meta.id"
    label 'process_high'

    if (params.enable_conda) {
        exit 1, "Conda environments cannot be used when using bases2fastq. Please use docker or singularity containers."
    }
    container "elembio/bases2fastq:1.1.0"

    input:
    tuple val(meta), path(run_manifest), path(run_dir)

    output:
    tuple val(meta), path("output/Samples/*/*_R*.fastq.gz")    , emit: sample_fastq
    tuple val(meta), path("output/Samples/*/*.json")           , emit: sample_json
    tuple val(meta), path("output/info/*.log")                 , emit: b2f_log
    tuple val(meta), path("output/*.html")                     , emit: qc_html
    tuple val(meta), path("output/Metrics.csv")                , emit: metrics
    tuple val(meta), path("output/RunManifest.csv")            , emit: run_manifest_csv
    tuple val(meta), path("output/RunManifest.json")           , emit: run_manifest_json
    tuple val(meta), path("output/RunParameters.json")         , emit: run_parameter_json
    tuple val(meta), path("output/RunStats.json")              , emit: run_stats
    tuple val(meta), path("output/UnassignedSequences.csv")    , emit: unassigned
    tuple val(meta), path("output/info/RunManifestErrors.json"), optional: true, emit: manifest_errors_json
    tuple val(meta), path("output/info/*.log")                 , emit: log
    path "versions.yml"                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def runManifest = run_manifest ? "-r ${run_manifest}" : ""
    """
    bases2fastq \\
        -p $task.cpus \\
        $runManifest \\
        $args \\
        $run_dir \\
        output

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bases2fastq: \$(bases2fastq --version | sed -e "s/bases2fastq version //g")
    END_VERSIONS
    """
}
