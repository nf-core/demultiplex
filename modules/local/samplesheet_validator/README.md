# Guide to Writing a `validation.json` Schema File

## Introduction

A JSON schema defines the structure and constraints of JSON data. This guide will help you create a `validation.json` schema file for use with Samshee to perform additional checks on Illumina® Sample Sheet v2 files.

## JSON Schema Basics

JSON Schema is a powerful tool for validating the structure of JSON data. It allows you to specify required fields, data types, and constraints. Here are some common components:

- **`$schema`**: Declares the JSON Schema version being used.
- **`type`**: Specifies the data type (e.g., `object`, `array`, `string`, `number`).
- **`properties`**: Defines the properties of an object and their constraints.
- **`required`**: Lists properties that must be present in the object.
- **`items`**: Specifies the schema for items in an array.

## Example Schema

Here’s an example of a `validation.json` schema file for an Illumina® Sample Sheet:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "Header": {
      "type": "object",
      "properties": {
        "InvestigatorName": {
          "type": "string"
        },
        "ExperimentName": {
          "type": "string"
        }
      },
      "required": ["InvestigatorName", "ExperimentName"]
    },
    "Reads": {
      "type": "object",
      "properties": {
        "Read1": {
          "type": "integer",
          "minimum": 1
        },
        "Read2": {
          "type": "integer",
          "minimum": 1
        }
      },
      "required": ["Read1", "Read2"]
    },
    "BCLConvert": {
      "type": "object",
      "properties": {
        "Index": {
          "type": "string",
          "pattern": "^[ACGT]{8}$"  // Example pattern for 8-base indices
        }
      }
    }
  },
  "required": ["Header", "Reads"]
}
```

### Explanation of the Example

- **`$schema`**: Specifies the JSON Schema version (draft-07).
- **`type`**: Defines the main type as `object`.
- **`properties`**: Lists the properties of the object:
- **`Header`**: An object with required `InvestigatorName` and `ExperimentName` fields.
- **`Reads`**: An object with required `Read1` and `Read2` fields that must be integers greater than or equal to 1.
- **`BCLConvert`**: An object with an optional `Index` field that must be a string matching a pattern for 8-base indices.
- **`required`**: Lists required properties at the top level.

### Tips for Writing JSON Schemas

1. **Start Simple**: Begin with basic constraints and gradually add complexity.
2. **Use Online Validators**: Validate your schema using online tools to ensure it adheres to the JSON Schema specification.
3. **Refer to Schema Documentation**: Consult the [JSON Schema documentation](https://json-schema.org/) for detailed guidance.

### Conclusion

By defining a JSON schema, you can enforce specific rules and ensure that your Illumina® Sample Sheet v2 files meet your required structure and constraints. Use this guide to create and validate your `validation.json` schema files effectively.
