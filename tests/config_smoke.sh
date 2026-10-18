#!/usr/bin/env bash
# 配置与控制流程测试：用函数替身替代生信软件，不运行真实组装。
set -Ee -o pipefail
project="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
export TEST_ROOT=$scratch
export GENOMET2T_CONFIG=$scratch/config.sh
cp "$project/config.example.sh" "$GENOMET2T_CONFIG"
mkdir -p "$scratch/results" "$scratch/data" "$scratch/db" "$scratch/helpers"
printf '>seq\nACGT\n' > "$scratch/data/input.fa"
printf 'dummy\n' > "$scratch/data/reads.fq.gz"
printf 'dummy\n' > "$scratch/tool.jar"
cat >> "$GENOMET2T_CONFIG" <<EOF
workdir=$scratch/results
datadir=$scratch/data
database=$scratch/db
scriptsdir=$scratch/helpers
threads=12
NEXTDENOVO_JOBS=3
NEXTPOLISH_JOBS=4
GENOME_SIZE=987654321
HIFI_READS=$scratch/data/reads.fq.gz
ONT_READS=$scratch/data/reads.fq.gz
ILLUMINA_R1=$scratch/data/reads.fq.gz
ILLUMINA_R2=$scratch/data/reads.fq.gz
POLISH_INPUT=$scratch/data/input.fa
INPUT_CONTIGS=$scratch/data/input.fa
REF_GENOME=$scratch/data/input.fa
REF_GFF=$scratch/data/input.fa
GEMOMA_JAR=$scratch/tool.jar
HOMOLOGY_REFERENCES=$scratch/references.tsv
CHROMOSOME_COUNT=7
CHROMOSOME_MAP=$scratch/chr.tsv
EOF
passed=0
pass() { passed=$((passed+1)); printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
expect_failure() {
    local pattern=$1; shift
    if "$@" > "$scratch/error.txt" 2>&1; then fail "预期失败：$*"; fi
    grep -q "$pattern" "$scratch/error.txt" || { cat "$scratch/error.txt"; fail "未命中错误：$pattern"; }
}
for script in "$project"/*.sh "$project"/tests/*.sh; do "$BASH" -n "$script"; done
pass '所有 Bash 文件语法'
expect_failure '缺少配置' env GENOMET2T_CONFIG="$scratch/missing" "$BASH" "$project/02.hifi_assembly_hifiasm.sh"
pass '缺少配置明确报错'
cp "$GENOMET2T_CONFIG" "$scratch/invalid.sh"
printf '\nthreads=0\n' >> "$scratch/invalid.sh"
expect_failure 'threads 必须为正整数' env GENOMET2T_CONFIG="$scratch/invalid.sh" "$BASH" "$project/02.hifi_assembly_hifiasm.sh"
pass '非法线程数拒绝执行'
nextDenovo() { cp "$1" "$TEST_ROOT/nextdenovo.cfg"; }
nextPolish() { cp "$1" "$TEST_ROOT/nextpolish.cfg"; }
java() { printf '%s\n' "$@" > "$TEST_ROOT/java.args"; mkdir -p gemoma; printf 'dummy\n' > gemoma/final_annotation.gff; }
mkdir -p "$scratch/bin"
printf '#!/usr/bin/env sh\ncat "$1"\n' > "$scratch/bin/GeMoMa_gff_to_gff3.pl"
if command -v chmod >/dev/null 2>&1; then chmod +x "$scratch/bin/GeMoMa_gff_to_gff3.pl"; fi
export PATH="$scratch/bin:$PATH"
liftoff() { printf '%s\n' "$@" > "$TEST_ROOT/liftoff.args"; }
docker() { printf '%s\n' "$@" > "$TEST_ROOT/docker.args"; }
export -f nextDenovo nextPolish java liftoff docker
if ! command -v ln >/dev/null 2>&1; then
    # Windows 精简 Bash 未附带 ln：这些测试只断言配置传参，不验证符号链接。
    ln() { :; }; export -f ln
fi
mkdir -p "$scratch/results/14.Repeat/4.RepeatMasker"
cp "$scratch/data/input.fa" "$scratch/results/14.Repeat/4.RepeatMasker/genome.hardmasked.fa"
cp "$scratch/data/input.fa" "$scratch/results/14.Repeat/4.RepeatMasker/genome.fa.masked"
cd "$scratch" # 验证从任意目录调用，配置不会因 cd 丢失。
"$BASH" "$project/03.ONT_assembly_nextdenovo.sh"
grep -q 'genome_size = 987654321' "$scratch/nextdenovo.cfg" || fail '基因组大小未传递'
grep -q 'parallel_jobs = 3' "$scratch/nextdenovo.cfg" || fail 'NextDenovo 并发未传递'
grep -q 'correction_options = -p 4' "$scratch/nextdenovo.cfg" || fail 'NextDenovo 线程分配错误'
pass 'NextDenovo：自定义基因组大小、并发与线程预算'
"$BASH" "$project/04.ONT_polish_nextpolish.sh"
grep -q 'parallel_jobs = 4' "$scratch/nextpolish.cfg" || fail 'NextPolish 并发未展开'
grep -q 'multithread_jobs = 3' "$scratch/nextpolish.cfg" || fail 'NextPolish 线程未展开'
grep -q 'polish_options = -p {multithread_jobs}' "$scratch/nextpolish.cfg" || fail '软件占位符被破坏'
pass 'NextPolish：Shell 配置展开，软件占位符保留'
"$BASH" "$project/10.polish_nextpolish.sh"
grep -q 'multithread_jobs = 3' "$scratch/nextpolish.cfg" || fail '最终纠错配置未展开'
pass '最终纠错使用显式选定的输入'
"$BASH" "$project/07.rmimpurities.sh"
cmp "$scratch/data/input.fa" "$scratch/results/07.rmimpurities/genome.final.fa" || fail '未启用过滤却删除了序列'
pass '未配置污染参考时保留原始组装'
printf 'refA\t%s\t%s\nrefB\t%s\t%s\n' "$scratch/data/input.fa" "$scratch/data/input.fa" "$scratch/data/input.fa" "$scratch/data/input.fa" > "$scratch/references.tsv"
"$BASH" "$project/16.GeMoMa.sh"
grep -qx 'i=refA' "$scratch/java.args" && grep -qx 'i=refB' "$scratch/java.args" || fail '未传递所有参考'
pass 'GeMoMa 多参考清单传递'
cat "$scratch/references.tsv" "$scratch/references.tsv" > "$scratch/duplicate.tsv"
cp "$GENOMET2T_CONFIG" "$scratch/invalid.sh"
printf '\nHOMOLOGY_REFERENCES=%s/duplicate.tsv\n' "$scratch" >> "$scratch/invalid.sh"
expect_failure '重复参考ID' env GENOMET2T_CONFIG="$scratch/invalid.sh" "$BASH" "$project/16.GeMoMa.sh"
pass 'GeMoMa 拒绝重复参考 ID'
"$BASH" "$project/17.liftoff.sh"
grep -qx "$scratch/data/input.fa" "$scratch/liftoff.args" || fail '未传递通用参考'
if grep -q -- '-chroms' "$scratch/liftoff.args"; then fail '凭空生成了染色体对应'; fi
pass 'Liftoff 默认不猜测染色体对应'
expect_failure '用法' "$BASH" "$project/08.Chromhic.sh" unknown
printf 'group1\tChr01\n' > "$scratch/chr.tsv"
expect_failure 'review 文件不存在' "$BASH" "$project/08.Chromhic.sh" finalize
pass 'Hi-C 阶段校验且等待人工校正结果'
export HOST_WORKDIR=$scratch/results HOST_DATADIR=$scratch/data HOST_DATABASE=$scratch/db
"$BASH" "$project/00.docker.sh" assembly
grep -qx 'omicsclass/genome-t2t:v1.0' "$scratch/docker.args" || fail '镜像错误'
grep -qx "type=bind,src=$scratch/data,dst=/work/data" "$scratch/docker.args" || fail '数据挂载错误'
if grep -q 'keep-groups\|dst=/work/script' "$scratch/docker.args"; then fail '非 Docker 参数或默认覆盖辅助脚本目录'; fi
pass 'Docker 参数与独立挂载'
printf '%s tests passed. 生信工具为替身，未验证真实数据结果。\n' "$passed"
