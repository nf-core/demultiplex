process FQTK {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/80/80b8bc43e0124231809f9ae8527743e5891abc292ea42450cce1f40fcb4f3ffd/data'
:         'community.wave.seqera.io/library/fqtk_gzip:1d4381117bf10c54' }"

    input:
    tuple val(meta), path(sample_sheet), path(fastq, stageAs: "input/*"), val(read_structure)
    // fastq_readstructure_pairs example:
    // [[<fastq name: string>, <read structure: string>], [example_R1.fastq.gz, 150T]]

    output:
    // Demultiplexed file name changes depending on the arg '--output-types'
    tuple val(meta), path('*.fq.gz')                         , emit: sample_fastq
    tuple val(meta), path('demux-metrics.txt')               , emit: metrics
    tuple val(meta), path('unmatched*.fq.gz')                , emit: most_frequent_unmatched
    tuple val("${task.process}"), val('fqtk'), eval('fqtk --version 2>&1 | cut -d " " -f2'), emit: versions_fqtk, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def fastq_arg = fastq instanceof List ? fastq.join(" ") : fastq
    def structure_arg = read_structure instanceof List ? read_structure.join(" ") : read_structure

    """
    mkdir output
    fqtk \\
        demux \\
            --inputs ${fastq_arg} \\
            --read-structures ${structure_arg} \\
            --output ./ \\
            --sample-metadata ${sample_sheet} \\
            ${args}
    """

    stub:
    """
    touch demux-metrics.txt
    echo "" | gzip > unmatched_R1.fq.gz
    echo "" | gzip > unmatched_R2.fq.gz

    awk 'NR>1 {print \$1}' $sample_sheet | while read sample_id; do
        echo "\${sample_id}"
        echo "" | gzip >  "\${sample_id}.R1.fq.gz"
        echo "" | gzip >  "\${sample_id}.R2.fq.gz"
    done
    """
}
