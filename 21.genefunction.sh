#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file UNIPROT_FASTA
require_var EGGNOG_TAX_SCOPE


cd $workdir
mkdir -p 21.genefunction
cd 21.genefunction

ln -s ../20.PASA_update/genome.final.gff3 ./
ln -s  ../14.Repeat/4.RepeatMasker/genome.fa.masked genome.softmasked.fa

"$TRANSDECODER_UTIL"/gff3_file_to_proteins.pl  --gff3  genome.final.gff3  --fasta  genome.softmasked.fa --seqType prot >pep.fa

"$TRANSDECODER_UTIL"/gff3_file_to_proteins.pl  --gff3  genome.final.gff3 --fasta genome.softmasked.fa   --seqType CDS >cds.fa

#获得基因最长的蛋白序列作为基因的代表序列，用于功能注释
perl $scriptsdir/get_gene_longest_fa.pl pep.fa genome.final.gff3 gene.pep.fa


############### 1.EGGNOG 注释 ##################################################

# 第一步：使用eggNOG提供的 emapper 流程进行注释
mkdir -p EGGNOG
cd EGGNOG
eggnogdb=$database/eggNOG/latest/  #设置数据库所在路径

#查看 物种分类：emapper.py --list_taxa  ：在线网站：http://eggnog-mapper.embl.de/

emapper.py -i ../gene.pep.fa --itype proteins -o eggnog -m diamond \
  --cpu ${threads} --seed_ortholog_evalue 1e-5 --override  --tax_scope "$EGGNOG_TAX_SCOPE" \
  --dmnd_db $eggnogdb/eggnog_proteins.dmnd --data_dir $eggnogdb

# 第二步：注释结果统计

Rscript  $scriptsdir/eggNOG/eggnog_stat.r  --emapper_anno eggnog.emapper.annotations -f ../gene.pep.fa -e "Human Diseases" "Drug Development"


############### 2.uniprot 注释 #################################################

cd $workdir/21.genefunction
mkdir -p uniprot
cd uniprot

#数据库所在路径， 下载地址：https://www.omicsclass.com/article/1515
db=$UNIPROT_FASTA

blastp -query ../pep.fa -db ${db} \
-num_threads ${threads}  -evalue 0.000001 -seg yes -soft_masking true -lcase_masking -max_hsps 1 -max_target_seqs 1\
 -outfmt "6 qseqid sseqid qlen slen pident length  mismatch gapopen qstart qend sstart send evalue bitscore qcovs stitle"\
  -out uniprot.blast.out.tsv


#把注释信息添加到基因上面
maker_functional_gff ${db}   uniprot.blast.out.tsv ../genome.final.gff3 > final.func.gff
maker_functional_fasta ${db} uniprot.blast.out.tsv ../pep.fa > pep.func.fa
maker_functional_fasta ${db} uniprot.blast.out.tsv ../cds.fa > cds.func.fa

############### 3.InterProScan 注释 #################################################
##InterProScan#耗时20h

cd $workdir/21.genefunction
mkdir -p InterProScan
cd InterProScan

mkdir -p ./tmp
#  -appl CDD,COILS,Gene3D,HAMAP,MobiDBLite,PANTHER,Pfam,PIRSF,PRINTS,PROSITEPATTERNS,PROSITEPROFILES,SFLD,SMART,SUPERFAMILY,TIGRFAM


sed   's/\*//g' ../pep.fa >interproscan.pep.fa #去掉氨基酸末尾的* 否则会报错

"$INTERPROSCAN" -i interproscan.pep.fa \
   -b interproscan.out -f "TSV" \
  -cpu ${threads} -dp -t p -pa -goterms -iprlookup \
  -T ./tmp

#添加结构域信息到GFF文件中
ipr_update_gff ../genome.final.gff3 interproscan.out.tsv > final.func.protdom.gff

#track 方便后续IGV等可视化
#iprscan2gff3 interproscan.out.tsv ../genome.final.gff3 > final.visible_domains.gff
