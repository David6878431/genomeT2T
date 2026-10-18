#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


require_file SCAFFOLD_FASTA
require_var GAPFILL_MODE
mkdir -p "$workdir/09.gapfill"
cd "$workdir/09.gapfill"
case "$GAPFILL_MODE" in
    assembly)
        require_file GAPFILL_ASSEMBLY
        tgsgapcloser --thread "$threads" --min_nread "$GAPFILL_MIN_READS" --min_match "$GAPFILL_MIN_MATCH" \
            --scaff "$SCAFFOLD_FASTA" --reads "$GAPFILL_ASSEMBLY" --output gapfill --minmap_arg '-x asm5' --ne
        ;;
    reads)
        require_file ONT_READS
        require_file RACON
        seqkit fq2fa "$ONT_READS" > ont.fasta
        tgsgapcloser --thread "$threads" --min_nread "$GAPFILL_MIN_READS" --min_match "$GAPFILL_MIN_MATCH" \
            --scaff "$SCAFFOLD_FASTA" --reads ont.fasta --output gapfill --racon "$RACON"
        ;;
    *) die 'GAPFILL_MODE 必须为 assembly 或 reads' ;;
esac
