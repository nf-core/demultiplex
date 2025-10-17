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
  
  publishDir(
    "${params.outdir}/demx_mgikit",
    mode: 'copy',
    saveAs: { name ->
      // keep only *_R1_001.fastq.gz or *_R2_001.fastq.gz
      if (!(name ==~ /.*_R[12]_001\.fastq\.gz$/)) return null
      // drop ambiguous/undetermined
      if (name.startsWith('Ambiguous_') || name.startsWith('Undetermined_')) return null
      // drop mgikit side files like <id>.L01.mgikit.*
      if (name ==~ /^[A-Za-z0-9.-]+\.L\d+\.mgikit\..*$/) return null
      return name
    }
  )
  
  input:                                                                        // [ meta, batch_file, flowcell_path, r1, r2 ]  
    tuple val(meta), path(batch_file), path(flowcell_path), path(r1), path(r2)  // meta = [id:'SERIAL_NUMBER_FC', lane:1] 

  output:
    path("demx_mgikit/*"),  emit: demx_mgikit_all
    val(meta),              emit: demx_mgikit_meta
    path(batch_file),       emit: demx_mgikit_batch_sheet

  script:
  """
  set -euo pipefail
  mkdir -p demx_mgikit
  "${params.mgikit_bin}" demultiplex \
    --sample-sheet "${batch_file}" \
    --read1 "${r1}" \
    --read2 "${r2}" \
    --output demx_mgikit/ \
    -m ${params.mgikit_mismatches} \
    --memory ${params.mgikit_memory_cli} \
    --template "${params.mgikit_template}" \
    -t ${task.cpus}
  """
}

