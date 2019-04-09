#!/usr/bin/env python
from __future__ import print_function
from collections import OrderedDict
import re

# TODO nf-core: Add additional regexes for new tools in process get_software_versions
regexes = {
    'nf-core/demultiplex': ['v_pipeline.txt', r"(\S+)"],
    'Nextflow': ['v_nextflow.txt', r"(\S+)"],
    'bcl2fastq': ['v_bcl2fastq.txt', r"(\S+)"],
    'FastQC': ['v_fastqc.txt', r"FastQC v(\S+)"],
    'FastQ_Screen': ['v_fastqscreen.txt', r"FastQ_Screen, version (\S+)"],
    'MultiQC': ['v_multiqc.txt', r"multiqc, version (\S+)"],
    'CellRanger': ['v_cellranger.txt', r"CellRanger, version (\S+)"],
    'CellRangerATAC': ['v_cellrangeratac.txt', r"CellRangerATAC, version (\S+)"],
    'CellRangerDNA': ['v_cellrangerdna.txt', r"CellRangerDNA, version (\S+)"],
}

results = OrderedDict()
results['nf-core/demultiplex'] = '<span style="color:#999999;\">N/A</span>'
results['Nextflow'] = '<span style="color:#999999;\">N/A</span>'
results['bcl2fastq'] = '<span style="color:#999999;\">N/A</span>'
results['FastQC'] = '<span style="color:#999999;\">N/A</span>'
results['FastQ_Screen'] = '<span style="color:#999999;\">N/A</span>'
results['MultiQC'] = '<span style="color:#999999;\">N/A</span>'
results['CellRanger'] = '<span style="color:#999999;\">N/A</span>'
results['CellRangerATAC'] = '<span style="color:#999999;\">N/A</span>'
results['CellRangerDNA'] = '<span style="color:#999999;\">N/A</span>'

# Search each file using its regex
for k, v in regexes.items():
    with open(v[0]) as x:
        versions = x.read()
        match = re.search(v[1], versions)
        if match:
            results[k] = "v{}".format(match.group(1))

# Dump to YAML
print ('''
id: 'nf-core/demultiplex-software-versions'
section_name: 'nf-core/demultiplex Software Versions'
section_href: 'https://github.com/nf-core/demultiplex'
plot_type: 'html'
description: 'are collected at run time from the software output.'
data: |
    <dl class="dl-horizontal">
''')
for k,v in results.items():
    print("        <dt>{}</dt><dd>{}</dd>".format(k,v))
print ("    </dl>")
