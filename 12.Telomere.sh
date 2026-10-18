#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file FINAL_ASSEMBLY
require_var TELOMERE_CLADE


mkdir -p $workdir/12.Telomere
cd $workdir/12.Telomere

ln -s "$FINAL_ASSEMBLY" ./genome.fa

"$TELOEXPLORER" \
  -i genome.fa -c "$TELOMERE_CLADE" -p telo_out
# -g Specify clade of this genome.
