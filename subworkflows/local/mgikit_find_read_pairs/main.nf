process MGIKIT_FIND_READ_PAIRS {
  tag { 
    def fc = (flowcell_path instanceof Path) ? flowcell_path.name : (flowcell_path as String).tokenize('/').last()
    "find_reads_tag:flowcell=${fc}:lane=${laneInt}"
  }

  input:
    tuple path(flowcell_path), val(laneInt)

  // One manifest per task
  output:
    tuple path(flowcell_path), val(laneInt), path("read_pairs.tsv")
  
   script:
  """
  set -euo pipefail

  python - <<'PY' "!{flowcell_path}" "!{laneInt}"
import sys, os, re, pathlib

flowcell = pathlib.Path(sys.argv[1])
lane    = sys.argv[2]

# If your filenames use L01/L02... build a padded lane token:
lane_token = f"L{int(lane):02d}"

# Collect all candidate R1 files that contain the lane token and _read_1
r1_files = []
for p in flowcell.rglob("*.fq.gz"):
    name = p.name
    if lane_token in name and "_read_1" in name:
        r1_files.append(p.resolve())

# Pair each R1 with its R2 mate by replacing the token; keep only existing pairs
pairs = []
for r1 in sorted(r1_files):
    r2 = pathlib.Path(str(r1).replace("_read_1.fq.gz", "_read_2.fq.gz"))
    if r2.exists():
        pairs.append((str(r1), str(r2)))

with open("read_pairs.tsv", "w") as fh:
    for r1, r2 in pairs:
        fh.write(f"{r1}\\t{r2}\\n")
PY
            
  """
}