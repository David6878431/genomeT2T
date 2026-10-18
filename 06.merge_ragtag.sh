#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"



mkdir -p $workdir/06.merge_ragtag
cd $workdir/06.merge_ragtag

# 需要合并的组装软连接过来
ln -s $workdir/04.ONT_polish_nextpolish/output/genome.nextpolish.fasta ont.fa
ln -s $workdir/02.hifi_assembly_hifiasm/hifi.fa hifiasm.fa

# ragtag进行补充
ragtag.py patch -t ${threads} -o ont_hifi ont.fa hifiasm.fa

# make joins and fill gaps in target.fa using sequences from query.fa
# ragtag.py patch target.fa query.fa

ragtag.py asmstats ont.fa hifiasm.fa ont_hifi/ragtag.patch.fasta ../05.hifiONT_assembly_hifiasm/hifiONT.fa > ragtag.stat
