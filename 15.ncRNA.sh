#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_var RNAMMER_DOMAIN
(( ${#TRNASCAN_OPTIONS[@]} > 0 )) || die "请配置 TRNASCAN_OPTIONS 数组"


cd $workdir
mkdir -p 15.ncRNA
cd 15.ncRNA

ln -s ../14.Repeat/genome.fa ./

################################################
#Run Infernal cmscan to find Rfam families
################################################

mkdir -p Rfam
cd Rfam
rfamdb=$database/Rfam/latest/ #设置rfam数据库路径

Z=$(esl-seqstat --dna ../genome.fa| grep "Total " | tr -s [:space:] | sed 's/: /\t/g' | cut -f 2)
Zvalue=$(awk -v i=${Z} 'BEGIN {print i*2/1000000}')

cmscan -Z ${Zvalue} --rfam --nohmmonly --cut_ga --cpu ${threads} \
 -o genome.Rfam.txt --verbose --fmt 2 \
 --tblout genome.Rfam.tbl \
 --clanin ${rfamdb}/Rfam.clanin \
 ${rfamdb}/Rfam.cm ../genome.fa

#整理数据
grep -v " = " genome.Rfam.tbl > genome.Rfam.deoverlapped.tbl    #去掉 overlap

#转换成GFF格式

perl $scriptsdir/convert_cmscan_to_gff3.pl --cmscan --fmt2  --all  --source Rfam genome.Rfam.deoverlapped.tbl > genome.Rfam.deoverlapped.gff

###################################
#rRNA 预测
###################################
#tsu代表5s或者5.8s rRNA，ssu代表16或者18S的rRNA，lsu代表23或者28s
#rnammer -S bac -m lsu,ssu,tsu -xml rRNA.rnammer.xml -gff rRNA.rnammer.gff -h rRNA.rnammer.hmmreport < genome.fa
cd $workdir/15.ncRNA
mkdir -p rRNA
cd rRNA

rnammer -S "$RNAMMER_DOMAIN" -m lsu,ssu,tsu -xml genome.rRNA.rnammer.xml -gff genome.rRNA.rnammer.tbl -h genome.rRNA.rnammer.hmmreport < ../genome.fa

#-S参数指定物种类型，arc代表古菌，bac代表细菌，euk代表真核生物；-xml指定XML格式的输出结果；-gff指定GFF格式的输出结果;-h指定html格式的输出结果。
#需要注意的是，本地版的rnammer依赖hmmer2.0版本。可执行文件rnammer 是一个perl脚本，需要编辑这个脚本，设置rnammer和hmmsearch的路径。

perl $scriptsdir/convert_RNAmmer_to_gff3.pl --input genome.rRNA.rnammer.tbl >genome.rRNA.rnammer.gff


###################################
#tRNA 预测
###################################

cd $workdir/15.ncRNA
mkdir -p tRNA
cd tRNA

tRNAscan-SE "${TRNASCAN_OPTIONS[@]}" -o genome.tRNA.out -f genome.tRNA.ss -m genome.tRNA.stats ../genome.fa
#-E 表示真核  -o保存到文件 -f将tRNA的二级结构保存到文件 -m将统计结果保存到文件

perl $scriptsdir/convert_tRNAScanSE_to_gff3.pl --input genome.tRNA.out >genome.tRNA.out.gff

###################################
#整理合并数据
###################################

cd $workdir/15.ncRNA

awk '$3!~"rRNA" && $3!~"tRNA"{print} ' Rfam/genome.Rfam.deoverlapped.gff > genome.Rfam.NorRNAtRNA.gff
cat tRNA/genome.tRNA.out.gff rRNA/genome.rRNA.rnammer.gff genome.Rfam.NorRNAtRNA.gff >genome.ncRNA.gff


#转换成标准的GFF文件并排好序
agat_convert_sp_gxf2gxf.pl  -g genome.ncRNA.gff -o genome.ncRNA.final.gff

#生成 rRNA 区域用于过滤蛋白基因
awk 'BEGIN{OFS="\t"} $3=="rRNA"{print $1,$4-1,$5}' genome.ncRNA.final.gff >genome.rRNA.bed


#genome gff 转换成 chromosome  gff
#liftOver -gff genome.ncRNA.final.gff $datadir/genome.chain genome.ncRNA.final.gff unmapped

#对ncRNA结果进行统计
perl $scriptsdir/Rfam.stat.v2.0.pl -in genome.ncRNA.final.gff -o genome.ncRNA.stat.xls
