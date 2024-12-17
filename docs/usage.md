# nf-core/demultiplex: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/demultiplex/usage](https://nf-co.re/demultiplex/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

> [!IMPORTANT]
> It is relevant to distinguish between the _pipeline_ samplesheet and the _flowcell_ samplesheet before working with this pipeline.
>
> - The **_pipeline_ samplesheet** is a file provided as input to the nf-core pipeline itself. It contains the overall configuration for your run, specifying the paths to individual _flowcell_ samplesheets, flowcell directories, and other metadata required to manage multiple sequencing runs. This is the primary configuration file that directs the pipeline on how to process your data.
> - The **_flowcell_ samplesheet** is specific to a particular sequencing run. It is typically created by the sequencing facility and contains the sample information, including barcodes, lane numbers, and indexes. The typical name is `SampleSheet.csv`. Each demultiplexer may require a different format for this file, which must be adhered to for proper data processing.

## Pipeline samplesheet input

You will need to create a _pipeline_ samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with at least 4 columns, and a header row as shown in the examples below. The input _pipeline_ samplesheet is a comma-separated file that contains four columns: `id`, `samplesheet`, `lane`, `flowcell`.

When using the demultiplexer fqtk, the _pipeline_ samplesheet must contain an additional column `per_flowcell_manifest`. The column `per_flowcell_manifest` must contain two headers `fastq` and `read_structure`. As shown in the [example](https://github.com/fulcrumgenomics/nf-core-test-datasets/blob/fqtk/testdata/sim-data/per_flowcell_manifest.csv) provided each row must contain one fastq file name and the correlating read structure.

```bash
--input '[path to pipeline samplesheet file]'
```

### Example: Pipeline samplesheet

```csv title="samplesheet.csv"
id,samplesheet,lane,flowcell
DDMMYY_SERIAL_NUMBER_FC,/path/to/SampleSheet.csv,1,/path/to/sequencer/output
DDMMYY_SERIAL_NUMBER_FC,/path/to/SampleSheet.csv,2,/path/to/sequencer/output
DDMMYY_SERIAL_NUMBER_FC2,/path/to/SampleSheet2.csv,1,/path/to/sequencer/output2
DDMMYY_SERIAL_NUMBER_FC3,/path/to/SampleSheet3.csv,3,/path/to/sequencer/output3
```

| Column        | Description                                                                                                                                                                                                                                                                   |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`          | Flowcell id                                                                                                                                                                                                                                                                   |
| `samplesheet` | Full path to the _flowcell_ `SampleSheet.csv` file containing the sample information and indexes                                                                                                                                                                              |
| `lane`        | Optional lane number. When a lane number is provided, only the given lane will be demultiplexed                                                                                                                                                                               |
| `flowcell`    | Full path to the Illumina sequencer output directory (often referred as run directory) or a `tar.gz` file containing the contents of said directory. `mgikit` demultiplexing expects a path to a directory here containing the compressed fastq files and `BioInfo.csv` file. |

An [example _pipeline_ samplesheet](https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/samplesheet/1.3.0/flowcell_input.csv) has been provided with the pipeline.

Note that the run directory in the `flowcell` column must lead to a `tar.gz` for compatibility with the demultiplexers sgdemux and fqtk.

### Example: Pipeline samplesheet for fqtk

```csv title="samplesheet.csv"
id,samplesheet,lane,flowcell,per_flowcell_manifest
DDMMYY_SERIAL_NUMBER_FC,/path/to/SampleSheet.csv,1,/path/to/sequencer/output,/path/to/flowcell/manifest.csv
DDMMYY_SERIAL_NUMBER_FC,/path/to/SampleSheet1.csv,2,/path/to/sequencer/output,/path/to/flowcell/manifest1.csv
DDMMYY_SERIAL_NUMBER_FC2,/path/to/SampleSheet2.csv,1,/path/to/sequencer/output2,/path/to/flowcell/manifest2.csv
DDMMYY_SERIAL_NUMBER_FC3,/path/to/SampleSheet3.csv,3,/path/to/sequencer/output3,/path/to/flowcell/manifest3.csv
```

| Column                  | Description                                                                                                                                         |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                    | Flowcell id                                                                                                                                         |
| `samplesheet`           | Full path to the _flowcell_ `SampleSheet.csv` file containing the sample information and indexes                                                    |
| `lane`                  | Optional lane number. When a lane number is provided, only the given lane will be demultiplexed                                                     |
| `flowcell`              | Full path to the Illumina sequencer output directory (often referred as run directory) or a `tar.gz` file containing the contents of said directory |
| `per_flowcell_manifest` | Full path to the flowcell manifest, containing the fastq file names and read structures                                                             |

### Flowcell samplesheet

Each demultiplexing software uses a distinct _flowcell_ samplesheet format. Below are examples for demultiplexer-specific _flowcell_ samplesheets. Please see the following examples to format the _flowcell_ `SampleSheet.csv`:

| Demultiplexer                | Example _flowcell_ `SampleSheet.csv` Format                                                                                                            |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **sgdemux**                  | [sgdemux SampleSheet.csv](https://github.com/nf-core/test-datasets/blob/demultiplex/testdata/sim-data/out.sample_meta.csv)                             |
| **fqtk**                     | [fqtk SampleSheet.csv](https://github.com/fulcrumgenomics/nf-core-test-datasets/raw/fqtk/testdata/sim-data/fqtk_samplesheet.csv)                       |
| **bcl2fastq and bclconvert** | [bcl2fastq and bclconvert SampleSheet.csv](https://raw.githubusercontent.com/nf-core/test-datasets/demultiplex/samplesheet/1.3.0/b2fq-samplesheet.csv) |
| **mgikit**                   | [mgikit samplesheet.csv](https://github.com/nf-core/test-datasets/blob/demultiplex/testdata/mgi/fc01_sample_sheet.csv)                                 |

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/demultiplex \
    --input pipeline_samplesheet.csv \
    --outdir results \
    -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/demultiplex -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
genome: 'GRCh37'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Optional parameters

## checkQC

If you are running this pipeline with the bcl2fastq demultiplexer, the checkqc module is run. In this case, the default run will include the default config file for checkqc, but you can additionally provide your own checkqc config file using the parameter `--checkqc_config` and a path to a `yml`. See an example of a config file in the [checkqc repository](https://github.com/Molmed/checkQC/blob/dfba84ec63e1df60c0f84ccc96a154a330b28ce4/checkQC/default_config/config.yaml).

### Trimming

The trimming process in our demultiplexing pipeline has been updated to ensure compatibility with 10x Genomics recommendations. By default, trimming in the pipeline is performed using fastp, which reliably auto-detects and removes adapter sequences without the need for storing adapter sequences. As users can also supply adapter sequences in a samplesheet and thereby triggering trimming in any `bcl2fastq` or `bclconvert` subworkflows, we have added a new parameter, `remove_adapter`, which is set to true by default. When `remove_adapter` is true, the pipeline automatically removes any adapter sequences listed in the `[Settings]` section of the Illumina sample sheet, replacing them with an empty string in order to not provoke this behaviour. This approach aligns with 10x Genomics' guidelines, as they advise against pre-processing FASTQ reads before inputting them into their software pipelines. If the `remove_adapter` setting is true but no adapter is removed, a warning will be displayed; however, this does not necessarily indicate an error, as some sample sheets may already lack these adapter sequences. Users can disable this behavior by setting `--remove_adapter false` in the command line, though this is not recommended.

## samshee (Samplesheet validator)

samshee ensures the integrity of Illumina v2 Sample Sheets by allowing users to apply custom validation rules. The module can be used together with the parameter `--json_schema_validator`, which accepts a JSON schema validation string; the `--name_schema_validator`, which accepts a schema name string; and the `--file_schema_validator` which accepts a JSON schema validation file. Users can specify additional validation rules beyond the default ones provided by the tool using all or any of these parameters, this enables tailored validation of Sample Sheets to meet specific requirements or standards relevant to your sequencing workflow. For more information refer to [Samshee on GitHub](https://github.com/lit-regensburg/samshee).

> [!NOTE]
> Samshee assumes all illumina samplesheets are v2. If working with samples that have an illumina samplesheet v1 set the parameter `--v1_schema` to true.
> When indicating `--json_schema_validator` or `--name_schema_validator`, please note that it expects a JSON reference value in string format. For example:
>
> ```bash
> --json_schema_validator '{"required": ["Data"]}'
> --name_schema_validator '{"$ref": "urn:samshee:illuminav2/v1"}'
> ```

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/demultiplex
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/demultiplex releases page](https://github.com/nf-core/demultiplex/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!NOTE]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow `24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases you may wish to change which container or conda environment a step of the pipeline uses for a particular tool. By default nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
