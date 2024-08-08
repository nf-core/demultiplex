#!/usr/bin/env python3

from samshee.samplesheetv2 import read_samplesheetv2
from samshee.validation import illuminasamplesheetv2schema, illuminasamplesheetv2logic, validate
import json
import sys

def validate_samplesheet(filename, custom_schema_file=None):
    # Load the custom schema if provided
    if custom_schema_file:
        with open(custom_schema_file, 'r') as f:
            custom_schema = json.load(f)
        custom_validator = lambda doc: validate(doc, custom_schema)
    else:
        custom_validator = None

    # Prepare the list of validators
    validators = [illuminasamplesheetv2schema, illuminasamplesheetv2logic]
    if custom_validator:
        validators.append(custom_validator)
    
    # Read and validate the sample sheet
    try:
        sheet = read_samplesheetv2(filename, validation=validators)
        print(f"Validation successful for {filename}")
    except Exception as e:
        print(f"Validation failed: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print("Usage: validate_samplesheet.py <SampleSheet.csv> [custom_schema.json]")
        sys.exit(1)
    
    samplesheet_file = sys.argv[1]
    schema_file = sys.argv[2] if len(sys.argv) == 3 else None

    validate_samplesheet(samplesheet_file, schema_file)
