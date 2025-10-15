process MGIKIT_FIND_READ_PAIRS {
  tag { 
    def fc   = (flowcell_path instanceof Path) ? flowcell_path.name : (flowcell_path as String).tokenize('/').last()
    def lane = (meta?.lane != null ? meta.lane : 'not_detected')
  }

  input:
    tuple path(flowcell_path), val(lane)

  // emit ONE item per pair
  output:
    tuple path(flowcell_path), val(lane), path(r1), path(r2)

  script:
  """
  set -euo pipefail

  # Adjust name patterns to your files. This matches ...<lane>_read_1.fq.gz and mates to _read_2.fq.gz
  mapfile -d '' -t R1 < <(find "${flowcell_path}" -type f -name "*${lane}_read_1.fq.gz" -print0)

  if [[ \${#R1[@]} -eq 0 ]]; then
    echo "No R1 for lane ${lane} under ${flowcell_path}" >&2
    exit 2
  fi

  i=0
  for r1 in "\${R1[@]}"; do
    r2="\${r1/_read_1.fq.gz/_read_2.fq.gz}"
    [[ -f "\$r2" ]] || { echo "Missing mate for: \$r1" >&2; continue; }
    ln -s "\$r1" "r1_\$i.fq.gz"
    ln -s "\$r2" "r2_\$i.fq.gz"
    echo -e "${flowcell_path}\t${lane}\tr1_\$i.fq.gz\tr2_\$i.fq.gz"
    i=\$((i+1))
  done > pairs.tsv

  # materialize declared outputs (Nextflow captures files referenced on each line)
  while IFS=\\$'\\t' read -r fc ln rf1 rf2; do :; done < pairs.tsv
  """
}
