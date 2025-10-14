process MGIKIT_DEMULTIPLEX {
  tag {
    def fc   = (flowcell_path instanceof Path) ? flowcell_path.name : (flowcell_path as String).tokenize('/').last()
    def lane = (meta?.lane != null ? meta.lane : 'not_detected')
    def file = (batch_file instanceof Path) ? batch_file.name : (batch_file as String).tokenize('/').last()
    "demx_tag:flowcell=${fc}:lane=${lane}:batch=${file}"
  }
  
  cpus { (params.mgikit_cpus != null ? params.mgikit_cpus as int : 4) }

  memory {
    def m = (params.mgikit_memory_cli != null ? params.mgikit_memory_cli as int : 64)
    (m instanceof Number || m.toString().isInteger()) ? "${m}.GB" : m.toString()
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
  
  input:                                                              // [ meta, batch_file, flowcell_path, optional ]  
    tuple val(meta), path(batch_file), path(flowcell_path)            // meta = [id:'SERIAL_NUMBER_FC', lane:1]
               
    

  output:
    path("demx_mgikit/*"),  emit: demx_mgikit_all
    val(meta),              emit: demx_mgikit_meta
    path(batch_file),       emit: demx_mgikit_batch_sheet

  script:
  """
  mkdir -p demx_mgikit
  "${params.mgikit_bin}" demultiplex \
    --sample-sheet "${batch_file}" \
    --read1 "${flowcell_path}/**/*${meta.lane}_read_1.fq.gz" \
    --read2 "${flowcell_path}/**/*${meta.lane}_read_2.fq.gz" \
    --output demx_mgikit/ \
    -m ${params.mgikit_mismatches != null ? params.mgikit_mismatches as int : 2} \
    --memory ${params.mgikit_memory_cli != null ? params.mgikit_memory_cli as int : 64} \
    --template "${params.mgikit_template != null ? params.mgikit_template.toString() : 'i710:i510'}" \
    -t ${task.cpus}
  """
}

