#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file RNASEQ_R1
require_file RNASEQ_R2


cd $workdir
mkdir -p 18.PASA
cd 18.PASA

ln -s ../14.Repeat/4.RepeatMasker/genome.fa.masked ./genome.softmasked.fa

contig=genome.softmasked.fa

# 可靠的全长转录本为可选输入，不能将近缘物种 CDS 默认当作目标物种证据。
est=${TRUSTED_TRANSCRIPTS:-}
if [[ -n "$est" ]]; then require_file TRUSTED_TRANSCRIPTS; fi

####################有参的转录本预测############################################

hisat2-build $contig $contig
hisat2 --dta --new-summary -p "$threads" -x "$contig" -1 "$RNASEQ_R1" -2 "$RNASEQ_R2" 2>hisat2.log | samtools sort -@ "${threads}" > rnaseq.bam
samtools index  rnaseq.bam  #建立索引方便后续可视化
stringtie rnaseq.bam   -p ${threads}   -o rnaseq.gtf

# Trinity 基于基因组辅助的组装
##  如果是真菌细菌小基因组 基因密度高 需要加参数 --jaccard_clip  ; 连特异性文库： --SS_lib_type RF
Trinity  --genome_guided_bam rnaseq.bam  \
 --genome_guided_max_intron 100000 --max_memory "$TRINITY_MEMORY" --CPU $threads \
 --output trinity_gg_out --full_cleanup

####################无参的转录本预测############################################


# Trinity denovo 组装
##  如果是真菌细菌小基因组 需要加参数 --jaccard_clip
Trinity --seqType fq --left "$RNASEQ_R1" --right "$RNASEQ_R2" --output trinity_tdn_out \
 --CPU $threads --full_cleanup --max_memory "$TRINITY_MEMORY"  #双端

##Trinity  --seqType fq  --output trinity_tdn_out_dir  --CPU $threads --full_cleanup --max_memory "$TRINITY_MEMORY"  --single $fq    #单端

#denovo 组装的ID提取
accession_extractor.pl < trinity_tdn_out.Trinity.fasta > tdn.accs

cat trinity_gg_out.Trinity-GG.fasta trinity_tdn_out.Trinity.fasta > all_transcripts.fasta
if [[ -n "$est" ]]; then cat "$est" >> all_transcripts.fasta; fi

################PASA 回帖转录本到基因组，去冗余#####################################

# sqlite3 pasa.sqlite
# #sqlite>
# .database
# #ctrl+D 退出

#设置 DATABASE

#DATABASE=${species}_pasa    #mysql数据库名称  速度会快
DATABASE=pasa.sqlite  #sqlite数据库输出文件

#生成配置文件 注意这里的数据库名字要以 _pasa 结尾，不然会报错
echo "
## templated variables to be replaced exist as <__var_name__>
# Pathname of an SQLite database
# If the environment variable DSN_DRIVER=mysql then it is the name of a MySQL database
DATABASE=${workdir}/18.PASA/${DATABASE}
# Parameters to specify to specific scripts in pipeline
# create a key = 'script_name' + ':' + 'parameter'
# assign a value as done above.

#script validate_alignments_in_db.dbi
validate_alignments_in_db.dbi:--MIN_PERCENT_ALIGNED=75
validate_alignments_in_db.dbi:--MIN_AVG_PER_ID=95
validate_alignments_in_db.dbi:--NUM_BP_PERFECT_SPLICE_BOUNDARY=0

#script subcluster_builder.dbi
subcluster_builder.dbi:-m=50

"  >alignAssembly.config

#索引 与去污染 #identify poly-a tails using SeqClean
export USER="${USER:-genomet2t}"   #seqclean 在docker 里面需要否则报错
seqclean all_transcripts.fasta -c ${threads} -n 10000  -v $database/UniVec/UniVec

#已知的全长转录本,提高权重
full_length_args=()
if [[ -n "$est" ]]; then
    accession_extractor.pl < "$est" > FL_accs.txt
    full_length_args=(-f FL_accs.txt)
fi
#grep ">" transcripts.fasta.transdecoder.cds |grep "complete"|sed 's#>##'|sed 's#\s.*##' >>FL_accs.txt


#####################################################
#回比基因组 PASA转录本组装
####################################################
#比较之前先看看 格式问题：
#pasa_gff3_validator.pl ../03.Braker/transcripts.fasta.transdecoder.contig.gff3


Launch_PASA_pipeline.pl "${full_length_args[@]}" -c alignAssembly.config -C -r -R -g genome.softmasked.fa -T  -t  all_transcripts.fasta.clean -u all_transcripts.fasta --CPU $threads --ALIGNERS blat,minimap2  --TRANSDECODER --TDN tdn.accs --MAX_INTRON_LENGTH 1000000

# -f  指定可靠的全长转录本 ID 列表 导入注释结果
# --stringent_alignment_overlap 30.0   真菌 细菌  基因密度高的基因组 设置
# --transcribed_is_aligned_orient  连特异性 加参数

# 结果文件：
# 1.$DATABASE.pasa_assemblies.gff3 PASA装配结构结果
# 2.$DATABASE.assemblies.fasta FASTA格式的PASA装配结果
# 3.$DATABASE.pasa_alignment_assembly_building.ascii_illustrations.out：装配程序集的描述以及它们是如何从底层转录本比对中构建的

# 可选训练集导出；默认不运行。
[[ "$EXPORT_TRAINING_SET" == 1 ]] || exit 0
require_file UNIPROT_DIAMOND
###Create golden gene set for training gene predictors
pasa_asmbls_to_training_set.dbi --pasa_transcripts_fasta ./$DATABASE.assemblies.fasta --pasa_transcripts_gff3 ./$DATABASE.pasa_assemblies.gff3

######################如果后面需要进行ab into预测的话，进行下面这些步骤#########

###对数据进行过滤，筛选高质量的基因作为 ab initio 预测的训练基因集，参考：https://github.com/fcamara7/GeneidTRAINerDocker

#need to identify a subset of really good ones (golden) that can be used for training 'de-novo' gene prediction (including generating the different file formats these predictors expect):
#Extract complete genes (exon >= 3、cds lenth >=900bp、cds region accounted for exon region ratio>=0.6、sort intron by lenth (retain %95 )、sort cds by lenth (retain %95 )
perl $scriptsdir/pasa_extract_best_candidate_geneModels.pl $DATABASE.assemblies.fasta.transdecoder.genome.gff3 $DATABASE.assemblies.fasta.transdecoder.cds 3 900 0.60 0.95 0.95 > best_candidates.gff3

### all vs all    相似性高的基因保留一个

"$TRANSDECODER_UTIL"/gff3_file_to_proteins.pl --gff3 best_candidates.gff3 --fasta genome.softmasked.fa --seqType prot > best_candidates.fasta

#比对uniprot_sprot 数据库，用于筛选具有编码潜能的基因
diamond blastp --query  best_candidates.fasta --db "$UNIPROT_DIAMOND" --threads $threads  --evalue 0.000001  --outfmt 6 qseqid sseqid qlen slen pident length  mismatch gapopen qstart qend sstart send evalue bitscore  stitle  --out uniprot.blast.out.tsv
#数据筛选 identity < 70%

#数据筛选
perl $scriptsdir/remove_redundant_high_identity_genes.pl best_candidates.gff3 best_candidates.fasta $threads 0.70 uniprot.blast.out.tsv > high_quality_gene.gff3

#过滤掉距离太短基因
agat_sp_filter_by_locus_distance.pl -gff high_quality_gene.gff3 -d 1000 -o trainingSetComplete.gff3

#awk '$3=="gene"{print}' trainingSetComplete.gff3   #统计基因数量，建议保留  ～2500 个基因
# trainingSetComplete.gff3 can be used for other gene prediction software (HMM trainning) 。
