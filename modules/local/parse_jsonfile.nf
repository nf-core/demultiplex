process PARSE_JSONFILE {
    tag "${sheet.name}"
    label 'process_low'

    // TODO Lock this down
    conda (params.enable_conda ? "pandas" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-2076f4a3fb468a04063c9e6b7747a630abb457f6:fccb0c41a243c639e11dd1be7b74f563e624fcca-0' :
        'quay.io/biocontainers/mulled-v2-2076f4a3fb468a04063c9e6b7747a630abb457f6:fccb0c41a243c639e11dd1be7b74f563e624fcca-0' }"

    input:
    path json
    path sheet
    path samp_probs
    path result

    when:
    result.name =~ /^fail.*/

    output:
    file "*.csv"       , emit: updated_samplesheet
    path "versions.yml", emit: versions

    script:
    """
    parse_json.py \\
        --samplesheet $sheet \\
        --jsonfile $json \\
        --problemsamples $samp_probs

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
