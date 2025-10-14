process MGIKIT_DEMULTIPLEX {
  tag {
    def fc   = (meta?.id ?: 'not_detected')
    def lane = (meta?.lane != null ? meta.lane : 'not_detected')
    def file = (batch_file instanceof Path) ? batch_file.name : (batch_file as String).tokenize('/').last()
    "demx_tag:flowcell=${fc}:lane=${lane}:batch=${file}"
  }
  
  cpus ${params.mgikit_cpus != null ? params.mgikit_cpus : 4} as int

  memory {
    "${params.mgikit_memory_cli != null ? params.mgikit_memory_cli : 64}".toString().isInteger()
      ? "${params.mgikit_memory_cli != null ? params.mgikit_memory_cli : 64}.GB"
      : (${params.mgikit_memory_cli != null ? params.mgikit_memory_cli : 64} as String)
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
  
  // [ meta, batch_file, flowcell_path, optional ]
  input:  
    tuple val(meta)            // meta = [id:'SERIAL_NUMBER_FC', lane:1]
    path(batch_file)           // the split file produced by splitText(file: true)
    path(flowcell_path)

  output:
    path("demx_mgikit/*"),  emit: demx_mgikit_all
    tuple val(meta),        emit: demx_mgikit_meta
    path(batch_file),       emit: demx_mgikit_batch_sheet

  script:
  """
  mkdir -p demx_mgikit
  "${params.mgikit_bin}" demultiplex \
    --sample-sheet "${batch_file}" \
    --read1 "${flowcell_path}/**/*${meta.lane}_read_1.fq.gz" \
    --read2 "${flowcell_path}/**/*${meta.lane}_read_2.fq.gz" \
    --output demx_mgikit/ \
    -m ${params.mgikit_mismatches != null ? params.mgikit_mismatches : 2} \
    --memory ${params.mgikit_memory_cli != null ? params.mgikit_memory_cli : 64} \
    --template (${params.mgikit_template != null ? params.mgikit_template : i710:i510} as String) \
    -t ${task.cpus}
  """
}

