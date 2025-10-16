process MGIKIT_FIND_READ_PAIRS {
  tag { 
    def fc   = (flowcell_path instanceof Path) ? flowcell_path.name : (flowcell_path as String).tokenize('/').last()
    def lane = (meta?.laneInt != null ? meta.laneInt : 'not_detected')
    "find_reads_tag:flowcell=${fc}:lane=${laneInt}"
  }

  input:
    tuple path(flowcell_path), val(laneInt)

  // One manifest per task
  output:
    tuple path(flowcell_path), val(laneInt), path("pairs.tsv")
  
  script:
  """
  set -euo pipefail
  
  // define the padded lane variable
  LANE_PAD=\$(printf 'L%02d' "${laneInt}")

  # Adjust name patterns to your files. This matches ...<lane>_read_1.fq.gz and mates to _read_2.fq.gz
  mapfile -d '' -t R1 < <(find "${flowcell_path}" -type f -name "*\${LANE_PAD}_read_1.fq.gz" -print0)

  if [[ \${#R1[@]} -eq 0 ]]; then
    echo "No R1 for lane ${laneInt} under ${flowcell_path}" >&2
    exit 2
  fi

  : > pairs.tsv
  for r1 in "\${R1[@]}"; do
    r2="\${r1/_read_1.fq.gz/_read_2.fq.gz}"
    if [[ -f "\$r2" ]]; then
      # write absolute paths; easier to consume upstream
      printf "%s\\t%s\\n" "\$r1" "\$r2" >> pairs.tsv
    else
      echo "Missing mate for: \$r1" >&2
    fi
  done

  if [[ ! -s pairs.tsv ]]; then
    echo "No complete R1/R2 pairs for lane ${laneInt} under ${flowcell_path}" >&2
    exit 2
  fi
  """
}