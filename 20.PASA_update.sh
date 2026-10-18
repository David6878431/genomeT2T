#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_var species


cd $workdir
mkdir -p ${threads}.PASA_update
cd 20.PASA_update

ln -s ../14.Repeat/4.RepeatMasker/genome.fa.masked ./genome.softmasked.fa

DATABASE=$workdir/18.PASA/pasa.sqlite

echo "

## templated variables to be replaced exist as <__var_name__>

# Pathname of an SQLite database
# If the environment variable DSN_DRIVER=mysql then it is the name of a MySQL database
DATABASE=$DATABASE

#script cDNA_annotation_comparer.dbi
cDNA_annotation_comparer.dbi:--MIN_PERCENT_OVERLAP=<__MIN_PERCENT_OVERLAP__>
cDNA_annotation_comparer.dbi:--MIN_PERCENT_PROT_CODING=<__MIN_PERCENT_PROT_CODING__>
cDNA_annotation_comparer.dbi:--MIN_PERID_PROT_COMPARE=<__MIN_PERID_PROT_COMPARE__>
cDNA_annotation_comparer.dbi:--MIN_PERCENT_LENGTH_FL_COMPARE=<__MIN_PERCENT_LENGTH_FL_COMPARE__>
cDNA_annotation_comparer.dbi:--MIN_PERCENT_LENGTH_NONFL_COMPARE=<__MIN_PERCENT_LENGTH_NONFL_COMPARE__>
cDNA_annotation_comparer.dbi:--MIN_FL_ORF_SIZE=<__MIN_FL_ORF_SIZE__>
cDNA_annotation_comparer.dbi:--MIN_PERCENT_ALIGN_LENGTH=<__MIN_PERCENT_ALIGN_LENGTH__>
cDNA_annotation_comparer.dbi:--MIN_PERCENT_OVERLAP_GENE_REPLACE=<__MIN_PERCENT_OVERLAP_GENE_REPLACE__>
cDNA_annotation_comparer.dbi:--STOMP_HIGH_PERCENTAGE_OVERLAPPING_GENE=<__STOMP_HIGH_PERCENTAGE_OVERLAPPING_GENE__>
cDNA_annotation_comparer.dbi:--TRUST_FL_STATUS=<__TRUST_FL_STATUS__>
cDNA_annotation_comparer.dbi:--MAX_UTR_EXONS=<__MAX_UTR_EXONS__>
cDNA_annotation_comparer.dbi:--GENETIC_CODE=<__GENETIC_CODE__>

" >annotCompare.config

###########################与转录本序列 比较分析 添加UTR信息 等########################
#参数说明：
#1、-A compare to annotated genes。-R 用于比对transcripts ， -A 用于和已有gff3注释文件的比较和更新。
#2、PASA 将输出一个新的 GFF3 文件，其中包含 PASA 更新版本的基因组注释，包括 PASA 成功更新的那些基因模型，以及那些保持不变的基因模型。mysql_db.gene_structures_post_PASA_updates.pid.gff3（pid 是进程 ID）
#3、一个较完整gff3注释文件通常需要至少两轮的注释加载、注释比较和注释更新，才能最大程度地将转录本对齐并入基因结构中。
#4、alignAssembly.config文件。将 $PASAHOME/pasa_conf/pasa.annotationCompare.Template.txt 文件复制到工作目录中作为“annotCompare.config”。然后，像之前一样使用 alignAssembly.config 文件那样将 MYSQLDB=< MYSQLDB> 替换为 MYSQLDB=/tmp/mydb.sqlite。

#第一次比较

Launch_PASA_pipeline.pl \
-c annotCompare.config \
-g  genome.softmasked.fa \
-t ../18.PASA/all_transcripts.fasta.clean \
-A -L --annots ../19.EVM/evm.gff3 \
--CPU ${threads}

#第二次比较

recent_update_gff_file=`ls -t *.gene_structures_post_PASA_updates.*.gff3 |head -1`

Launch_PASA_pipeline.pl \
-c annotCompare.config  \
-g genome.softmasked.fa  \
-t ../18.PASA/all_transcripts.fasta.clean  \
-A -L --annots $recent_update_gff_file \
--CPU ${threads}

####################整理基因注释结果#######################################################
recent_update_gff_file=`ls -t *.gene_structures_post_PASA_updates.*.gff3 |head -1`
#去掉空行和 带 #号的行
cat $recent_update_gff_file |grep -v "^#"|sed "/^$/d" > genome.all.gff3

#过滤ORF 长度小于50个氨基酸的基因
orflen=${ORF_MIN_AA:-50}
require_positive orflen
agat_sp_filter_by_ORF_size.pl --gff genome.all.gff3 --size "$orflen" --test ">" --output genome.orf

#过滤不完整的基因， ATG 等； 注意，基因组序列需要折叠：seqtk seq -l 50 contig.fa  >contig1.fa
agat_sp_filter_incomplete_gene_coding_models.pl --gff "genome.orf_sup${orflen}.gff" --fasta ./genome.softmasked.fa --output genome.filtered_partial_gene.gff3

#过滤没有功能注释的基因； keep.list 一个基因ID 一行
#cut -f 1 ann/Result/Integrated_Function.annotation.xls  >keep.list
#agat_sp_filter_feature_from_keep_list.pl --gff contig.filtered_partial_gene.gff3 --type mRNA --keep_list keep.list  -o contig.final.func.gff3

ln -s genome.filtered_partial_gene.gff3 genome.filtered_func.gff3

#一个基因保留最长的转录本
agat_sp_keep_longest_isoform.pl --gff genome.filtered_func.gff3 -o genome.final.longest_isoform.gff3

#过滤与rRNA有重叠的基因
agat_sp_filter_record_by_coordinates.pl --gff genome.final.longest_isoform.gff3  -c ../15.ncRNA/genome.rRNA.bed -o genome.rRNA-filter

#对基因的名称重新命名
agat_sp_manage_IDs.pl --gff genome.rRNA-filter/remaining.gff3 --prefix ${species} --ensembl  --collective --type_dependent -o genome.rename.gff3

ln -s genome.rename.gff3 genome.final.gff3

#sort -k 1,1 -k 4,5n -k 9n genome.rename.gff3 > genome.final.gff3
#gff3_sort -g genome.rename.gff3 -og genome.final.gff3
