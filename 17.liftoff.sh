#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


require_file REF_GENOME
require_file REF_GFF
target=$workdir/14.Repeat/4.RepeatMasker/genome.fa.masked
require_file target
chrom_args=()
if [[ -n "${LIFTOFF_CHROM_MAP:-}" ]]; then
    require_file LIFTOFF_CHROM_MAP
    chrom_args=(-chroms "$LIFTOFF_CHROM_MAP")
fi
mkdir -p "$workdir/17.liftoff"
cd "$workdir/17.liftoff"
liftoff -g "$REF_GFF" -o liftoff.gene.gff3 -p "$threads" \
    "$target" "$REF_GENOME" "${chrom_args[@]}" -u unmap.txt
