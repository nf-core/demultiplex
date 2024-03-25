process FASTQ_SCREEN{
    tag "fastq_screen"
    label 'process_single'
    queue 'local'

    // conda "${moduleDir}/environment.yml"
    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //     'https://depot.galaxyproject.org/singularity/fastq-screen%3A0.15.3--pl5321hdfd78af_0' :
    //     'biocontainers/multiqc:1.21--pyhdfd78af_0' }"

    input:

    output:

    script:
}
