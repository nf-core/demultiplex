// TODO Upstream to nf-core/modules
process FASTQ_SCREEN {
    tag "${meta.id}"
    label 'process_high'

    conda (params.enable_conda ? "bioconda::fastq-screen==0.14.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastq-screen:0.14.0--pl5321hdfd78af_2' :
        'quay.io/biocontainers/fastq-screen:0.14.0--pl5321hdfd78af_2' }"

    input:
    tuple val(meta), path(reads)
    path fastq_screen_config

    output:
    tuple val(meta), path("*_screen.txt"), emit: txt
    file "*_screen.html"                        , emit: html

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    fastq_screen \\
        --force --subset 200000 \\
        --conf $ch_fastq_screen_config \\
        --aligner bowtie2 \\
        $fqFile

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        FastQ Screen: TODO
    END_VERSIONS
    """
}
