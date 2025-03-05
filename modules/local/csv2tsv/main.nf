process CSV2TSV {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:22.04' :
        'nf-core/ubuntu:22.04' }"

    input:
    tuple val(meta), path(sample_sheet), val(fastq_readstructure_pairs)
    // fastq_readstructure_pairs example:
    // [[<fastq name: string>, <read structure: string>, <path to fastqs: path>], [example_R1.fastq.gz, 150T, ./work/98/30bc..78y/fastqs/]]

    output:
    tuple val(meta), path('samplesheet.tsv'), val(fastq_readstructure_pairs), emit: ch_output
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    sed 's/,/\t/g' ${sample_sheet} > samplesheet.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$( sed --version | grep "sed (GNU sed) " | sed -e "s/sed (GNU sed) //g" )
    END_VERSIONS
    """
}
