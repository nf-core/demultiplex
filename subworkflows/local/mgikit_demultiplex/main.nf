process MGIKIT_DEMULTIPLEX {
  tag {
    def fc   = (flowcell_path instanceof Path) ? flowcell_path.name : (flowcell_path as String).tokenize('/').last()
    def lane = (meta?.lane != null ? meta.lane : 'not_detected')
    def file = (batch_file instanceof Path) ? batch_file.name : (batch_file as String).tokenize('/').last()
    "demx_tag:flowcell=${fc}:lane=${lane}:batch=${file}"
  }
  
  cpus { params.mgikit_cpus as int }

  memory {
    def base = (params.mgikit_memory_cli as int)
    def factor = (task.attempt > 1) ? (2 ** (task.attempt - 1)) : 1
    (base * factor).GB
  }
  
  errorStrategy {
    if (task.exitStatus in 137..140) {
      sleep(Math.pow(2, task.attempt) * 200 as long);
      return 'retry';
    } else {
      return 'terminate';
    }
  }
  maxRetries 3
  
  publishDir "${params.outdir}/mgikit/${meta.id}/L${meta.lane.toString().padLeft(2,'0')}/${batch_file.baseName}", mode: 'move',
    saveAs: { file ->
      def name = file.name
      if (!(name.startsWith('Ambiguous') || name.startsWith('Undetermined')) && name.endsWith('fastq.gz')) return name
      return null
    }
  
  input:                                                                        // [ meta, batch_file, flowcell_path, r1, r2 ]  
    tuple val(meta), path(batch_file), path(flowcell_path), path(r1), path(r2)  // meta = [id:'SERIAL_NUMBER_FC', lane:1] 

  output:
    path("**/*.fastq.gz"),  emit: demx_fastq
  
  script:
  """
  set -euo pipefail
  "${params.mgikit_bin}" demultiplex \
    --sample-sheet "${batch_file}" \
    --read1 "${r1}" \
    --read2 "${r2}" \
    --output "demx_${meta.id}_L${meta.lane.toString().padLeft(2,'0')}_${batch_file.baseName}_${task.hash}_attempt${task.attempt}" \
    -m ${params.mgikit_mismatches} \
    --memory ${task.memory.giga} \
    --template ${params.mgikit_template} \
    -t ${task.cpus} \
    --disable-illumina
  """
}

