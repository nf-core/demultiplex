process FALCO {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/falco:1.2.1--h867801b_3':
        'biocontainers/falco:1.2.1--h867801b_3' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.txt") , emit: txt
    path  "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    // Filter reads that are less than 20 bytes
    def valid_reads = reads.findAll { it.size() > 20 }

    if (valid_reads.isEmpty()) {
        log.warn "No valid reads for ${meta.id} after filtering by size."
        """
        echo "No valid reads for ${meta.id}" > ${prefix}_no_valid_reads.txt
        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            falco:\$( falco --version | sed -e "s/falco//g" )
        END_VERSIONS
        """
    } else {
        if (valid_reads.size() == 1) {
            """
            falco $args --threads $task.cpus ${valid_reads[0]} -D ${prefix}_fastqc_data.txt -S ${prefix}_summary.txt -R ${prefix}_report.html

            cat <<-END_VERSIONS > versions.yml
            "${task.process}":
                falco:\$( falco --version | sed -e "s/falco//g" )
            END_VERSIONS
            """
        } else {
            """
            falco $args --threads $task.cpus ${valid_reads.join(' ')}

            cat <<-END_VERSIONS > versions.yml
            "${task.process}":
                falco:\$( falco --version | sed -e "s/falco//g" )
            END_VERSIONS
            """
        }
    }

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_data.txt
    touch ${prefix}_fastqc_data.html
    touch ${prefix}_summary.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        falco: \$( falco --version | sed -e "s/falco v//g" )
    END_VERSIONS
    """
}
