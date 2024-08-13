process SAMSHEE {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/python_pip_samshee:84a770c9853c725d' :
        'community.wave.seqera.io/library/python_pip_samshee:e8a5c47ec32efa42' }"

    input:
    tuple val(meta), path(samplesheet)
    path(validator_schema)              //optional

    output:
    // Module is meant to stop the pipeline if validation fails
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''
    def arg_validator_schema = validator_schema ? "${validator_schema}" : ""
    """
    # Run validation command and capture output
    output=\$(validate_samplesheet.py "${samplesheet}" "${arg_validator_schema}" 2>&1)
    status=\$?
    # Check if validation failed
    if echo "\$output" | grep -q "Validation failed:"; then
        echo "\$output"  # Print output for debugging
        exit 1  # Fail the process if validation failed
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samshee: \$( python -m pip show --version samshee | grep "Version" | sed -e "s/Version: //g" )
        python: \$( python --version | sed -e "s/Python //g" )
    END_VERSIONS

    # If no validation errors, process exits with status 0
    exit \$status
    """

    stub:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samshee: \$( python -m pip show --version samshee | grep "Version" | sed -e "s/Version: //g" )
        python: \$( python --version | sed -e "s/Python //g" )
    END_VERSIONS
    """
}
