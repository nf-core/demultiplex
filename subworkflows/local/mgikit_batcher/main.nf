process MGIKIT_BATCHER {
  tag {
    def fc   = (flowcell_path instanceof Path) ? flowcell_path.name : (flowcell_path as String).tokenize('/').last()
    def lane = (meta?.lane != null ? meta.lane : 'not_detected')
    def file = (samplesheet_path instanceof Path) ? samplesheet_path.name : (samplesheet_path as String).tokenize('/').last()
    "batch_tag:flowcell=${fc}:lane=${lane}:samplesheet=${file}"
  }

  input:
    tuple val(meta), path(samplesheet_path), path(flowcell_path), path(r1_path), path(r2_path)

  output:
    tuple val(meta), path("batch_*.csv"), path(flowcell_path), path(r1_path), path(r2_path)

  // params.mgikit_batch_size default if unset
  script:
  """
  set -euo pipefail

  header=\$(head -n 1 "${samplesheet_path}")
  # split the body (excluding header) into chunks of batch_size lines
  tail -n +2 "${samplesheet_path}" | split -l ${params.mgikit_batch_size} - "body_"

  i=0
  for f in body_*; do
    out="batch_\$(printf '%03d' "\$i").csv"
    # restore header for each batch
    { printf "%s\n" "\$header"; cat "\$f"; } > "\$out"
    i=\$((i+1))
  done
  """
}
