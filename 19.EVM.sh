#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


cd $workdir
mkdir -p 19.EVM
cd 19.EVM

ln -s ../14.Repeat/4.RepeatMasker/genome.fa.masked genome.softmasked.fa

##################################
###1. 转录组预测基因
##################################

#pasa结果
ln -s ../18.PASA/pasa.sqlite.assemblies.fasta.transdecoder.genome.gff3 ./pasa_assembly.evm.format.gff3

cat pasa_assembly.evm.format.gff3 |grep -v "^#"|sed "/^$/d" >transcript_alignments.gff3

##################################
###2. 同源蛋白预测基因
##################################
cat ../16.GeMoMa/gemoma.evm.format.gff3 |grep -v "^#"|sed "/^$/d" > homology.evm.format.gff3

##################################
###3. 基因注释迁移
##################################

cat ../17.liftoff/liftoff.gene.gff3 |grep -v "^#"|sed "/^$/d" > liftoff.gene.gff3

##################################
###3. EVM 整合证据
##################################
#Use EVM script to check the gff3 file
#gff3_gene_prediction_file_validator.pl coordinate.gff3

#配置文件模板生成
create_weights_file.pl -A liftoff.gene.gff3 \
 -P homology.evm.format.gff3\
 -T transcript_alignments.gff3 > weights.txt

#手动修改模板weights.txt，设置权重
echo "
ABINITIO_PREDICTION	Liftoff 8
PROTEIN GeMoMa  7
TRANSCRIPT  transdecoder  10
">weights.txt


#提供重复序列注释GFF文件
ln -s ../14.Repeat/genome.all.repeat.sorted.gff .

#Partitioning the inputs
partition_EVM_inputs.pl --genome genome.softmasked.fa \
  --gene_predictions liftoff.gene.gff3 \
  --protein_alignments homology.evm.format.gff3 \
  --transcript_alignments transcript_alignments.gff3 \
  --repeats $PWD/genome.all.repeat.sorted.gff \
  --segmentSize 10000000 --overlapSize 5000000 --partition_listing partitions_list.out

#Generating the EVM command set
write_EVM_commands.pl --genome genome.softmasked.fa \
  --weights $PWD/weights.txt \
  --gene_predictions liftoff.gene.gff3 \
  --protein_alignments homology.evm.format.gff3 \
  --transcript_alignments transcript_alignments.gff3 \
   --repeats $PWD/genome.all.repeat.sorted.gff \
  --output_file_name evm.out  --partitions $PWD/partitions_list.out > commands.sh

#execute_EVM_commands.pl commands.sh| tee run.log

#parallel -j 10 <commands.sh   #并行运行任务 加快速度
ParaFly -c commands.sh -CPU 10


#Combining the partitions
recombine_EVM_partial_outputs.pl --partitions partitions_list.out --output_file_name evm.out

#Convert to gff3 format
convert_EVM_outputs_to_GFF3.pl  --partitions partitions_list.out --output evm.out  --genome genome.softmasked.fa

#Combine gff3 files
find ./ -mindepth 2 -maxdepth 2 -type f -name "evm.out.gff3" -exec cat {} \; >evm.gff3
