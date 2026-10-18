#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


require_file REF_GENOME
require_file SCAFFOLD_CONTIGS
require_positive CHROMOSOME_COUNT
mkdir -p "$workdir/08.ChromSyn"
cd "$workdir/08.ChromSyn"
ragtag.py scaffold -u -t "$threads" -o ./ "$REF_GENOME" "$SCAFFOLD_CONTIGS"
minimap2 -t "$threads" -cx asm5 "$REF_GENOME" ragtag.scaffold.fasta > minimap2.paf
Rscript "$scriptsdir/pafCoordsDotPlotly.R" -i minimap2.paf -o syn-minimap -l -s -t -k "$CHROMOSOME_COUNT" -m 10000
