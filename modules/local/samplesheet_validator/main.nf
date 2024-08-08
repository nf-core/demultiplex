process SAMPLESHEET_VALIDATOR {
    tag {"$meta.id"}
    label 'process_low'

    container "community.wave.seqera.io/library/pip_samshee:9f3c0736b7c44dc8"

    input:
    tuple val(meta), path(samplesheet)
    path(validator_schema)              //optional

    // output: //Module is meant to crash pipeline if validation fails, output is not needed

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

    # If no validation errors, process exits with status 0
    exit \$status
    """
}
