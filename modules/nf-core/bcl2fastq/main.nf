process BCL2FASTQ {
    tag {"$meta.lane" ? "$meta.id"+"."+"$meta.lane" : "$meta.id" }
    label 'process_high'

    container "nf-core/bcl2fastq:2.20.0.422"

    input:
    tuple val(meta), path(samplesheet), path(run_dir)

    output:
    tuple val(meta), path("**_S[1-9]*_R?_00?.fastq.gz")          , emit: fastq
    tuple val(meta), path("**_S[1-9]*_I?_00?.fastq.gz")          , optional:true, emit: fastq_idx
    tuple val(meta), path("**Undetermined_S0*_R?_00?.fastq.gz")  , optional:true, emit: undetermined
    tuple val(meta), path("**Undetermined_S0*_I?_00?.fastq.gz")  , optional:true, emit: undetermined_idx
    tuple val(meta), path("Reports")                             , emit: reports
    tuple val(meta), path("Stats")                               , emit: stats
    tuple val(meta), path("InterOp/*.bin")                       , emit: interop
    tuple val(meta), path("checkqc_dir")                         , emit: checkqc_dir
    path("versions.yml")                                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "BCL2FASTQ module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''
    def input_tar = run_dir.toString().endsWith(".tar.gz") ? true : false
    def input_dir = input_tar ? run_dir.toString() - '.tar.gz' : run_dir
    """
    if [ ! -d ${input_dir} ]; then
        mkdir -p ${input_dir}
    fi

    if ${input_tar}; then
        ## Ensures --strip-components only applied when top level of tar contents is a directory
        ## If just files or multiple directories, place all in $input_dir

        if [[ \$(tar -taf ${run_dir} | grep -o -P "^.*?\\/" | uniq | wc -l) -eq 1 ]]; then
            tar \\
                -C $input_dir --strip-components 1 \\
                -xavf \\
                $args2 \\
                $run_dir \\
                $args3
        else
            tar \\
                -C $input_dir \\
                -xavf \\
                $args2 \\
                $run_dir \\
                $args3
        fi
    fi

    bcl2fastq \\
        $args \\
        --output-dir . \\
        --runfolder-dir ${input_dir} \\
        --sample-sheet ${samplesheet} \\
        --processing-threads ${task.cpus}

    cp -r ${input_dir}/InterOp .

     echo "Directory for checkQC"
    # custom dir for checkqc
    mkdir checkqc_dir
    cp $samplesheet checkqc_dir/SampleSheet.csv

    if [ -f ${input_dir}/RunInfo.xml ]; then
        cp ${input_dir}/RunInfo.xml checkqc_dir
    fi
    if [ -f ${input_dir}/runParameters.xml ]; then
        cp ${input_dir}/runParameters.xml checkqc_dir
    fi
    if [ -f ${input_dir}/RunParameters.xml ]; then
        cp ${input_dir}/RunParameters.xml checkqc_dir
    fi

    mkdir -p checkqc_dir/Data/Intensities/BaseCalls
    cp -r Stats checkqc_dir/Data/Intensities/BaseCalls/Stats

    cp -r ${input_dir}/InterOp checkqc_dir/InterOp

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcl2fastq: \$(bcl2fastq -V 2>&1 | grep -m 1 bcl2fastq | sed 's/^.*bcl2fastq v//')
    END_VERSIONS
    """
}
