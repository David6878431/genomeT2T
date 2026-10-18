#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file FINAL_ASSEMBLY
require_var REPEAT_TAXON
require_file REPEATMASKER_LIB
require_file SPROT_CLEAN




cd $workdir
mkdir -p 14.Repeat

REP_DIR=$workdir/14.Repeat

cd $REP_DIR
# 所有序列都大写，避免和后面的软掩盖冲突
seqkit seq "$FINAL_ASSEMBLY" -u > genome.fa

######################### 1.预测LTR ############################################

mkdir -p 1.LTR
cd 1.LTR
ltr_lib=$workdir/13.qualAssess/LAI/result/ref.fa.LTRlib.fa
require_file ltr_lib
mkdir -p result
ln -s "$ltr_lib" result/ref.fa.LTRlib.fa

########################## 2.MITE-Hunter 预测 MITE##############################

cd $REP_DIR
mkdir -p 2.MITE-Hunter
cd 2.MITE-Hunter
ln -s ../genome.fa ./

MITE_Hunter_manager.pl  -i genome.fa -g MITE_Hunter   -n 5 -c ${threads} -S 12345678
#合并结果
cat MITE_Hunter_Step8_*.fa > MITE.lib

#修改分类名字
sed -i '/>/s$\s.*$#DNA/MITE$' MITE.lib

# http://target.iplantcollaborative.org/mite_hunter/MITE-Hunter_manual.pdf

################################################################################
#近源物种重复序列 同源预测
################################################################################

########################## 3.RepeatMasker 进行同源预测 #########################

cd $REP_DIR
mkdir -p 3.RepeatMasker-homo
cd 3.RepeatMasker-homo/
ln -s ../genome.fa ./

RepeatMaskerLib=$REPEATMASKER_LIB
# famdb.py -i $RepeatMaskerLib lineage --ancestors  --descendants 物种

RepeatMasker -e rmblast -gff -xsmall  -no_is  -nolow  -pa $threads -norna -species "$REPEAT_TAXON" genome.fa

perl $scriptsdir/repeat_to_gff.pl -in genome.fa.out -out genome.TE_repeat.gff

#对TE区屏蔽，方便后续 同源蛋白重复注释
bedtools maskfasta  -fi genome.fa -bed genome.TE_repeat.gff -fo genome.hardmasked.fa

# 生成RepeatLandscape  ； -g 设置基因组大小计算屏蔽比例
size=$(esl-seqstat --dna genome.fa| grep "Total " | tr -s [:space:] | sed 's/: /\t/g' | cut -f 2)
calcDivergenceFromAlign.pl -s genome.fa.divsum genome.fa.cat.gz
createRepeatLandscape.pl -div genome.fa.divsum -g $size > genome.fa.html

########################## 4.RepeatMasker 进行预测注释的合并 ###################

cd $REP_DIR
mkdir -p 4.RepeatMasker
cd 4.RepeatMasker/
ln -s ../genome.fa ./

cat ../2.MITE-Hunter/MITE.lib  ../1.LTR/result/ref.fa.LTRlib.fa  > MITE_LTR.lib

RepeatMaskerLib=$REPEATMASKER_LIB

famdb.py -i $RepeatMaskerLib families --format fasta_name \
  --ancestors --curated --descendants --include-class-in-name  "$REPEAT_TAXON"  >Homology.db

SPROT=$SPROT_CLEAN

for lib in MITE_LTR.lib Homology.db; do
  blastx -query ${lib} -db ${SPROT} -evalue 1e-10 -num_descriptions 10 -num_threads ${threads} -out ${lib}_blast_results.txt
  perl $scriptsdir/ProtExcluder1.2/ProtExcluder.pl ${lib}_blast_results.txt ${lib}
  echo -e "${lib}\tbefore\t$(grep -c ">" ${lib})\tafter\t$(grep -c ">" ${lib}noProtFinal)"
done

cat MITE_LTR.libnoProtFinal  Homology.dbnoProtFinal> allRepeats.lib
vsearch --cluster_fast allRepeats.lib --id 0.97 --centroids allRepeats.non-redundant.lib #去除重复

RepeatMasker -e rmblast -gff -xsmall -html -norna   -source  -no_is -pa ${threads} -s -lib allRepeats.non-redundant.lib genome.fa

## 变out文件为gff，但是这个gff只有有名字的repeat在
cat ../3.RepeatMasker-homo/genome.fa.out genome.fa.out > all.out
perl $scriptsdir/repeat_to_gff.pl -in all.out  -out genome.TE_repeat.gff

#对TE区屏蔽，方便后续 同源蛋白重复注释
bedtools maskfasta  -fi genome.fa -bed genome.fa.out.gff -fo genome.hardmasked.fa

########################## 5.TRF 预测简单重复 ##################################

cd $REP_DIR
mkdir -p 5.TRF
cd 5.TRF
ln -s ../4.RepeatMasker/genome.hardmasked.fa ./

trf genome.hardmasked.fa 2 7 7 80 10 50 2000 -h -d
#TRF简单重复序列查找
#atching weight = 2, mismatching penalty = 7, INDEL penalty = 7, match probability = 80, INDEL probability = 10, minimum alignment score to report = 50, maximum period size to report = 2000, -d –h
# Where args are Match, Mismatch, Delta, PM, PI, Minscore, MaxPeriod, [options]

#TRF分析结果转换GFF文件
perl $scriptsdir/repeat_to_gff.pl -in genome.hardmasked.fa.2.7.7.80.10.50.2000.dat  -out genome.trf.gff

#简单重复序列长度 统计 不考虑overlap
awk 'BEGIN{sum=0}{sum=sum+$5-$4+1}END{print sum}' genome.trf.gff


########################## 6.汇总所有重复序列结果 ##############################

cd $REP_DIR
#合并TE和简单重复区gff
cat 4.RepeatMasker/genome.TE_repeat.gff 5.TRF/genome.trf.gff  > genome.all.repeat.gff

#结果统计  脚本 buildRepeatSummary.pl 修改自repeatmasker 中的 buildSummary.pl

samtools faidx genome.fa
sort -k1,1 -k4,4n genome.all.repeat.gff >genome.all.repeat.sorted.gff #bug fix 对于一些基因组，需要排序之后统计，不然会统计错误 2023.4.28
perl $scriptsdir/buildRepeatSummary.pl -genome genome.fa.fai  -useAbsoluteGenomeSize  genome.all.repeat.sorted.gff   >genome.repeat.summary.txt
