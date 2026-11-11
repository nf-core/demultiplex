process CHECKQC_DIR {
    label 'process_high'
    tag {"$meta.id"}
    container "nf-core/bcl2fastq:2.20.0.422"

    input:
    tuple val(meta), path(samplesheet), path(run_dir), path(stats), path(interop)

    output:
    tuple val(meta), path("checkqc_dir")                         , emit: checkqc_dir

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
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
                $args \\
                $run_dir \\
                $args2
        else
            tar \\
                -C $input_dir \\
                -xavf \\
                $args \\
                $run_dir \\
                $args2
        fi
    fi


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

    mkdir -p checkqc_dir/InterOp
    cp -rL $interop checkqc_dir/InterOp

    mkdir -p checkqc_dir/Data/Intensities/BaseCalls

    cp -rL Stats checkqc_dir/Data/Intensities/BaseCalls/Stats
    """
}
