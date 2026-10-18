#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


require_file ILLUMINA_R1
require_file ILLUMINA_R2
require_positive PLOIDY
mkdir -p "$workdir/01.Kmer"
cd "$workdir/01.Kmer"
printf 'gzip -dc %s\ngzip -dc %s\n' "$ILLUMINA_R1" "$ILLUMINA_R2" > generate.file
jellyfish count -t "$threads" -C -m "$KMER_SIZE" -s "$JELLYFISH_HASH" -g generate.file -G 2 -o illu
jellyfish stats -o illu.stat illu
jellyfish histo -v -t "$threads" -h "$KMER_HIST_MAX" -o illu.histo illu
genomescope.R -i illu.histo -o genomescope_out -p "$PLOIDY" -k "$KMER_SIZE" -m "$KMER_HIST_MAX"
