process RECHECK_SAMPLESHEET {
    tag "${ss_sheet.name}"
    label 'process_low'

    // TODO Lock this down
    conda (params.enable_conda ? "pandas" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-2076f4a3fb468a04063c9e6b7747a630abb457f6:fccb0c41a243c639e11dd1be7b74f563e624fcca-0' :
        'quay.io/biocontainers/mulled-v2-2076f4a3fb468a04063c9e6b7747a630abb457f6:fccb0c41a243c639e11dd1be7b74f563e624fcca-0' }"

    input:
    path sheet
    path ud_sheet
    path prob_samps
    path result

    when:
    result.name =~ /^fail.*/

    output:
    file "*.txt"       , emit: problem_ss
    path "versions.yml", emit: versions

    script:
    """
    recheck_samplesheet.py \\
        --samplesheet $sheet \\
        --newsamplesheet $ud_sheet \\
        --problemsamples $prob_samps

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
