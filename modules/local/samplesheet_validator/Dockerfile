# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Install Samshee and any additional Python packages
RUN pip install --no-cache-dir samshee

# Copy the validation script into the container's PATH
COPY validate_samplesheet.py /usr/local/bin/

# Make sure the script is executable
RUN chmod +x /usr/local/bin/validate_samplesheet.py

# Make sure bash is available
RUN apt-get update && apt-get install -y bash

# Set the entry point to bash, so you can run commands interactively
ENTRYPOINT ["/bin/bash"]
