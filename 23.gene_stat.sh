#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_var species


cd $workdir
mkdir -p 23.gene_stat
cd 23.gene_stat

echo "../16.GeMoMa/gemoma.evm.format.gff3
../17.liftoff/liftoff.gene.gff3
../18.PASA/pasa.sqlite.assemblies.fasta.transdecoder.genome.gff3
../19.EVM/evm.gff3
../20.PASA_update/genome.all.gff3
../20.PASA_update/genome.final.gff3" >list

for i in `cat list`;do name=`echo $i | cut -d "/" -f3`; agat_sp_keep_longest_isoform.pl --gff $i -o $name;echo $name;done


python3 $scriptsdir/GeneStats_noSplice.py -g pasa.sqlite.assemblies.fasta.transdecoder.genome.gff3 -s $species -o pasa_gene_stat -S PASA
python3 $scriptsdir/GeneStats_noSplice.py -g gemoma.evm.format.gff3  -s $species -o gemoma_gene_stat -S GeMoMa
python3 $scriptsdir/GeneStats_noSplice.py -g liftoff.gene.gff3 -s $species -o Liftoff_gene_stat -S Liftoff

python3 $scriptsdir/GeneStats_noSplice.py  -g evm.gff3    -s $species  -o EVM_gene_stat -S EVM
python3 $scriptsdir/GeneStats_noSplice.py -g genome.all.gff3 -s $species -o pasa-update_gene_stat -S PASA-update

python3 $scriptsdir/GeneStats_noSplice.py -g genome.final.gff3 -s $species -o final_gene_stat -S "Final Set"


##################################
###不同软件预测基因汇总统计
##################################

find ./ -name gene_stats.tsv  #快速查找文件

Rscript $scriptsdir/merge_tsv_files.r -i ./gemoma_gene_stat/gene_stats.tsv  \
  ./Liftoff_gene_stat/gene_stats.tsv \
  ./pasa_gene_stat/gene_stats.tsv \
  ./EVM_gene_stat/gene_stats.tsv  \
  ./pasa-update_gene_stat/gene_stats.tsv \
  ./final_gene_stat/gene_stats.tsv \
  -b "Category" -p all_gene_predict_stat
