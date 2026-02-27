process CSV2TSV {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
        'nf-core/ubuntu:22.04' }"

    input:
    tuple val(meta), path(sample_sheet), path(fastq_folder, stageAs: "input"), val(fastq_readstructure_pairs)
    // fastq_readstructure_pairs example:
    // [[<fastq name: string>, <read structure: string>], [example_R1.fastq.gz, 150T]]

    output:
    tuple val(meta), path('samplesheet.tsv'), path(fastq_folder), val(fastq_readstructure_pairs), emit: ch_output
    tuple val("${task.process}"), val('sed'), eval('sed --version | sed -n "s/sed (GNU sed) //p"'), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    sed 's/,/\t/g' ${sample_sheet} > samplesheet.tsv
    """
}
