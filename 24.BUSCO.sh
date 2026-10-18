#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


require_var BUSCO_LINEAGES
mkdir -p "$workdir/24.BUSCO"
cd "$workdir/24.BUSCO"
perl "$scriptsdir/get_gene_longest_fa.pl" "$workdir/21.genefunction/pep.fa" \
    "$workdir/20.PASA_update/genome.final.gff3" gene.pep.fa
for lineage in $BUSCO_LINEAGES; do
    [[ "$lineage" =~ ^[A-Za-z0-9_.-]+$ ]] || die 'BUSCO_LINEAGES 含非法名称'
    busco -m prot -i gene.pep.fa -o "${lineage}_result" -l "$lineage" -c "$threads" \
        --offline -f --download_path "$database/busco_db/latest"
done
mkdir -p summaries
cp ./*/short_summary.*.txt summaries/
"$BUSCO_PLOT" -wd summaries/
