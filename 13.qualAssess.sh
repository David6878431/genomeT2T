#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"

require_file FINAL_ASSEMBLY
require_var QUAL_MODULES
mkdir -p "$workdir/13.qualAssess"
cd "$workdir/13.qualAssess"
ln -s "$FINAL_ASSEMBLY" genome.fa
samtools faidx genome.fa
for module in $QUAL_MODULES; do
    case "$module" in
        stats)
            mkdir -p stats
            assembly-stats genome.fa > stats/N50_stats
            seqkit fx2tab -g -H -l -n -i genome.fa > stats/all_stats
            if [[ -n "${GENOME_SIZE:-}" ]]; then
                require_positive GENOME_SIZE
                ragtag.py asmstats -g "$GENOME_SIZE" genome.fa > stats/NG50
            fi
            ;;
        mapping)
            require_file ILLUMINA_R1; require_file ILLUMINA_R2; require_file HIFI_READS
            mkdir -p map
            bwa index genome.fa
            awk 'BEGIN{OFS="\t"}{print $1,0,$2}' genome.fa.fai > map/genome.bed
            bwa mem -t "$threads" genome.fa "$ILLUMINA_R1" "$ILLUMINA_R2" | samtools sort -o map/illu.bam
            minimap2 -t "$threads" -ax map-hifi --secondary=no genome.fa "$HIFI_READS" | samtools sort -o map/hifi.bam
            for kind in illu hifi; do
                samtools flagstat "map/$kind.bam" > "map/$kind.flagstats"
                bedtools coverage -a map/genome.bed -b "map/$kind.bam" > "map/$kind.coverage"
                awk '{covered+=$5;total+=$6} END{if(total>0)print covered/total;else exit 1}' "map/$kind.coverage" > "map/$kind.coverage_all"
            done
            ;;
        merqury)
            require_file HIFI_READS; require_positive MERQURY_K
            mkdir -p merqury
            cd merqury
            meryl "k=$MERQURY_K" "memory=$MERYL_MEMORY" "threads=$threads" count "$HIFI_READS" output hifi.meryl
            merqury.sh hifi.meryl ../genome.fa merqury_out
            cd ..
            ;;
        lai)
            require_var LTR_MUTATION_RATE
            mkdir -p LAI/result
            cd LAI
            awk '{print $1}' ../genome.fa > ref.fa
            LTR_HARVEST_parallel -seq ref.fa -threads "$threads" -gt "$GENOMETOOLS_BIN/"
            LTR_FINDER_parallel -seq ref.fa -threads "$threads" -harvest_out -size 5000000 -time 500 \
                -finder_para '-w 2 -C -D 15000 -d 1000 -L 7000 -l 100 -p 20 -M 0.85'
            cat ref.fa.harvest.combine.scn ref.fa.finder.combine.scn > ref.fa.rawLTR.scn
            cd result
            LTR_retriever -genome ../ref.fa -inharvest ../ref.fa.rawLTR.scn -threads "$threads" \
                -u "$LTR_MUTATION_RATE" -repeatmasker "$REPEATMASKER_DIR/"
            cd ../..
            ;;
        busco)
            require_var BUSCO_LINEAGES
            mkdir -p BUSCO
            for lineage in $BUSCO_LINEAGES; do
                [[ "$lineage" =~ ^[A-Za-z0-9_.-]+$ ]] || die 'BUSCO lineage 名称格式错误'
                busco -m geno -i genome.fa -o "${lineage}_busco" --out_path "$PWD/BUSCO" -l "$lineage" \
                    -c "$threads" --offline -f --download_path "$database/busco_db/latest"
            done
            ;;
        *) die "未知 QUAL_MODULES 模块：$module" ;;
    esac
done
