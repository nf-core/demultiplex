process MGIKIT_DEMULTIPLEX {
  tag {
    def fc   = (flowcell_path instanceof Path) ? flowcell_path.name : (flowcell_path as String).tokenize('/').last()
    def lane = (meta?.lane != null ? meta.lane : 'not_detected')
    def file = (batch_file instanceof Path) ? batch_file.name : (batch_file as String).tokenize('/').last()
    "demx_tag:flowcell=${fc}:lane=${lane}:batch=${file}"
  }
  
  cpus { params.mgikit_cpus as int }

  memory {
    def s = params.mgikit_memory_cli.toString()
    s.isInteger() ? "${s}GB" : s
  }
  
  maxRetries 0
  
  publishDir "${params.outdir}/mgikit_demx_fastq", mode: 'copy',
    pattern: '**/*.fastq.gz',
    saveAs: { file ->
      def name = file.name
      if (name.startsWith('Ambiguous') || name.startsWith('Undetermined')) return null
      return name
    }
  
  input:                                                                        // [ meta, batch_file, flowcell_path, r1, r2 ]  
    tuple val(meta), path(batch_file), path(flowcell_path), path(r1), path(r2)  // meta = [id:'SERIAL_NUMBER_FC', lane:1] 

  output:
    path("**/*.fastq.gz"),  emit: demx_fastq
  
  script:
  """
  set -euo pipefail
  ${params.mgikit_bin} demultiplex \
    --sample-sheet ${batch_file} \
    --read1 ${r1} \
    --read2 ${r2} \
    --output demx_${meta.id}_lane_${meta.lane}_${batch_file.baseName}_${task.hash}_attempt${task.attempt} \
    -m ${params.mgikit_mismatches} \
    --memory ${params.mgikit_memory_cli} \
    --template ${params.mgikit_template} \
    -t ${task.cpus} \
    --disable-illumina
  """
}

