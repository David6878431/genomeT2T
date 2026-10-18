#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"


require_file HOMOLOGY_REFERENCES
require_file GEMOMA_JAR
args=()
declare -A seen_ids=()
# TSV 每行：参考ID、基因组FASTA、已筛选的蛋白编码基因GFF3；无表头。
while IFS=$'\t' read -r ref_id ref_fasta ref_gff extra || [[ -n "${ref_id:-}" ]]; do
    [[ -z "$ref_id" || "$ref_id" == \#* ]] && continue
    [[ "$ref_id" =~ ^[A-Za-z0-9_-]+$ && -z "$extra" ]] || die "参考清单格式错误：$ref_id"
    [[ -z "${seen_ids[$ref_id]:-}" ]] || die "重复参考ID：$ref_id"
    seen_ids[$ref_id]=1
    require_file ref_fasta
    require_file ref_gff
    args+=(s=own "i=$ref_id" "a=$ref_gff" "g=$ref_fasta")
done < "$HOMOLOGY_REFERENCES"
(( ${#args[@]} > 0 )) || die '同源参考清单为空'
mkdir -p "$workdir/16.GeMoMa"
cd "$workdir/16.GeMoMa"
target=$workdir/14.Repeat/4.RepeatMasker/genome.hardmasked.fa
require_file target
java -jar "$GEMOMA_JAR" CLI GeMoMaPipeline "threads=$threads" \
    AnnotationFinalizer.r=NO p=false o=true tblastn=false "t=$target" outdir=gemoma "${args[@]}"
GeMoMa_gff_to_gff3.pl gemoma/final_annotation.gff > gemoma.evm.format.gff3
