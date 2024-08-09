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
    #Generate minimal samplesheet
    cat <<-END_SAMPLE_SHEET > minimal_samplesheet.csv
    [Header]
    FileFormatVersion,2
    RunName,Run_001
    Instrument Type,NextSeq 1000
    InstrumentPlatform,NextSeq 1000

    [Reads]
    Read1Cycles,150
    Read2Cycles,150
    Index1Cycles,8
    Index2Cycles,8

    [Settings]

    [Data]
    Sample_ID,Sample_Name,Description,Sample_Project
    Sample1,Sample1,,
    END_SAMPLE_SHEET


    #Generate minimal schema validator file
    cat <<-END_SCHEMA > minimal_schema.json
    {
    "type": "object",
    "properties": {
        "Header": {
        "type": "object",
        "properties": {
            "FileFormatVersion": { "type": "integer" },
            "RunName": { "type": "string" },
            "Instrument Type": { "type": "string" },
            "InstrumentPlatform": { "type": "string" }
        },
        "required": ["FileFormatVersion", "RunName", "Instrument Type", "InstrumentPlatform"]
        },
        "Reads": {
        "type": "object",
        "properties": {
            "Read1Cycles": { "type": "integer" },
            "Read2Cycles": { "type": "integer" },
            "Index1Cycles": { "type": "integer" },
            "Index2Cycles": { "type": "integer" }
        },
        "required": ["Read1Cycles", "Read2Cycles", "Index1Cycles", "Index2Cycles"]
        },
        "Settings": {
        "type": "object"
        },
        "Data": {
        "type": "array",
        "items": {
            "type": "object",
            "properties": {
            "Sample_ID": { "type": "string" },
            "Sample_Name": { "type": "string" },
            "Description": { "type": "string" },
            "Sample_Project": { "type": "string" }
            },
            "required": ["Sample_ID", "Sample_Name", "Description", "Sample_Project"]
        }
        }
    },
    "required": ["Header", "Reads", "Settings", "Data"]
    }
    END_SCHEMA

    # Run validation command and capture output
    output=\$(validate_samplesheet.py minimal_samplesheet.csv minimal_schema.json  2>&1)
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
}
