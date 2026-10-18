#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"

phase=${1:-prepare}
[[ "$phase" == prepare || "$phase" == finalize ]] || die '用法：bash 08.Chromhic.sh prepare|finalize'
require_positive CHROMOSOME_COUNT
mkdir -p "$workdir/08.Chromhic"
cd "$workdir/08.Chromhic"
k=$CHROMOSOME_COUNT
if [[ "$phase" == prepare ]]; then
    require_file SCAFFOLD_CONTIGS
    require_file HIC_R1
    require_file HIC_R2
    require_var HIC_ENZYME
    require_var HIC_PREPROCESS_ENZYME
    require_var HIC_RE_SITE
    require_file VISUALIZER
    ln -s "$SCAFFOLD_CONTIGS" draft.asm.fasta
    bwa index draft.asm.fasta
    samtools faidx draft.asm.fasta
    bwa aln -t "$threads" draft.asm.fasta "$HIC_R1" > sample_R1.sai
    bwa aln -t "$threads" draft.asm.fasta "$HIC_R2" > sample_R2.sai
    bwa sampe draft.asm.fasta sample_R1.sai sample_R2.sai "$HIC_R1" "$HIC_R2" > sample.bwa_aln.sam
    samtools view -bS sample.bwa_aln.sam > sample.bwa_aln.bam
    PreprocessSAMs.pl sample.bwa_aln.bam draft.asm.fasta "$HIC_PREPROCESS_ENZYME"
    filterBAM_forHiC.pl sample.bwa_aln.REduced.paired_only.bam sample.clean.sam
    samtools view -bt draft.asm.fasta.fai sample.clean.sam > sample.clean.bam
    ALLHiC_partition -b sample.clean.bam -r draft.asm.fasta -e "$HIC_ENZYME" -k "$k"
    allhic extract sample.clean.bam draft.asm.fasta --RE "$HIC_RE_SITE"
    for ((K=1; K<=k; K++)); do
        allhic optimize "sample.clean.counts_${HIC_RE_SITE}.${k}g${K}.txt" sample.clean.clm
    done
    ALLHiC_build draft.asm.fasta
    samtools faidx groups.asm.fasta
    cut -f 1,2 groups.asm.fasta.fai > groups.chrn.list
    ALLHiC_plot -b sample.clean.bam -a groups.agp -l groups.chrn.list -m 500k -o groups.hic.heatmap
    python3 "$scriptsdir/agp2assembly.py" groups.agp groups.assembly
    cut -f 1,2 draft.asm.fasta.fai > draft.asm.sizes
    samtools view -h sample.clean.bam | pairtools parse -c draft.asm.sizes -o parsed.pairsam.gz --cmd-out gzip
    pairtools sort --memory 10G -o sorted.pairsam.gz parsed.pairsam.gz --cmd-out gzip --cmd-in gunzip
    pairtools dedup --mark-dups -o deduped.pairsam.gz sorted.pairsam.gz --cmd-out gzip --cmd-in gunzip
    pairtools select '(pair_type == "UU") or (pair_type == "UR") or (pair_type == "RU")' \
        -o filtered.pairsam.gz deduped.pairsam.gz --cmd-out gzip --cmd-in gunzip
    pairtools split --output-sam sample.filtered.bam filtered.pairsam.gz --cmd-out gzip --cmd-in gunzip
    matlock bam2 juicer sample.filtered.bam out.links.txt
    sort -k2,2 -k6,6 out.links.txt > out.sorted.links.txt
    bash "$VISUALIZER" groups.assembly out.sorted.links.txt
    printf '请在 Juicebox 中校正并保存 groups.review.assembly，再运行 finalize。\n'
    exit 0
fi
# 人工核对后再处理，名称映射须由用户明确提供，不按前 N 条序列猜染色体。
require_file CHROMOSOME_MAP
review=$PWD/groups.review.assembly
require_file review
python3 "$scriptsdir/juicebox_assembly_converter.py" -a groups.review.assembly -f draft.asm.fasta -p groups.review
python3 "$scriptsdir/rename_seqID.py" -r "$CHROMOSOME_MAP" -f groups.review.fasta -a groups.review.agp -p genome.final
samtools faidx genome.final.fa
cut -f 1,2 genome.final.fa.fai > genome.final.chrn.list
ALLHiC_plot -b sample.clean.bam -a genome.final.agp -l genome.final.chrn.list -m 500k -o genome.final.hic.heatmap
awk -v prefix="$UNPLACED_PREFIX" 'BEGIN{placed=0;unplaced=0} $0!~/^#/ && $5=="W" {
    if(index($1,prefix)==1){unplaced+=$8-$7+1}else{placed+=$8-$7+1}
} END{if(placed+unplaced>0){print placed/(placed+unplaced)}else{exit 1}}' genome.final.agp > anchoring_rate.txt
if [[ -n "${REF_GENOME:-}" ]]; then
    require_file REF_GENOME
    minimap2 -t "$threads" -x asm5 "$REF_GENOME" genome.final.fa > genome.final.overlaps.paf
    Rscript "$scriptsdir/pafCoordsDotPlotly.R" -i genome.final.overlaps.paf -o genome.final.overlaps -l -s -t -k "$k" -m 10000
fi
