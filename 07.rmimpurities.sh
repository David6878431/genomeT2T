#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


require_file INPUT_CONTIGS
mkdir -p "$workdir/07.rmimpurities"
cd "$workdir/07.rmimpurities"
if [[ -z "${CONTAMINANT_FASTA:-}" ]]; then
    cp "$INPUT_CONTIGS" genome.final.fa
    printf '未配置污染参考：仅复制所选组装，不自动删除 rDNA 或重复 contig。\n'
    exit 0
fi
require_file CONTAMINANT_FASTA
require_percent CONTAM_IDENTITY
require_percent CONTAM_COVERAGE
makeblastdb -in "$CONTAMINANT_FASTA" -dbtype nucl -out contaminants
blastn -query "$INPUT_CONTIGS" -db contaminants -out contamination.blast.tsv \
    -task megablast -evalue 1e-5 -perc_identity "$CONTAM_IDENTITY" \
    -outfmt '6 std qcovs' -max_target_seqs 5 -num_threads "$threads"
awk -v coverage="$CONTAM_COVERAGE" '$13>=coverage {print $1}' contamination.blast.tsv | sort -u > removed_contigs.txt
if [[ -s removed_contigs.txt ]]; then
    seqkit grep -f removed_contigs.txt -v "$INPUT_CONTIGS" > genome.final.fa
else
    cp "$INPUT_CONTIGS" genome.final.fa
fi
