#!/usr/bin/env bash
# Common config loader and validation helpers for all pipeline stages.

set -Ee -o pipefail
_genomet2t_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
_genomet2t_config=${GENOMET2T_CONFIG:-"${_genomet2t_dir}/config.sh"}
[[ -f "$_genomet2t_config" ]] || { printf 'ERROR: 缺少配置文件：%s；请复制 config.example.sh 为 config.sh 并填写。\n' "$_genomet2t_config" >&2; exit 1; }
# shellcheck source=/dev/null
source "$_genomet2t_config"

# Accept lower-case historical names and upper-case config keys. Defaults here
# are container paths, not organism-specific scientific assumptions.
workdir=${workdir:-${WORKDIR:-/work/myt2t}}
datadir=${datadir:-${DATADIR:-/work/data}}
database=${database:-${DATABASE_DIR:-/work/database}}
scriptsdir=${scriptsdir:-${SCRIPTS_DIR:-/work/script}}
threads=${threads:-${THREADS:-10}}
species=${species:-${SPECIES_PREFIX:-}}
DATABASE=${DATABASE:-"${workdir}/18.PASA/pasa.sqlite"}
TRANSDECODER_UTIL=${TRANSDECODER_UTIL:-${TRANSDECODER_DIR:-/share/work/biosoft/TransDecoder/latest}/util}
BUSCO_PLOT=${BUSCO_PLOT:-${database}/busco_db/generate_plot.py}
VISUALIZER=${VISUALIZER:-${HIC_VISUALIZER:-}}
RACON=${RACON:-${RACON_PATH:-}}
GENOMETOOLS_BIN=${GENOMETOOLS_BIN:-${GENOMETOOLS_DIR:-}}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
_cfg_value() { local key=$1; printf '%s' "${!key:-}"; }
require_var() {
    local key=$1 value
    value=$(_cfg_value "$key")
    [[ -n "$value" && "$value" != *REPLACE_ME* ]] || die "${key} 未设置：请在 config.sh 中填写后再运行。"
}
require_file() {
    local key=$1 value
    value=$(_cfg_value "$key")
    [[ -n "$value" && "$value" != *REPLACE_ME* ]] || die "${key} 未设置：请在 config.sh 中填写文件路径。"
    [[ -f "$value" ]] || die "${key} 文件不存在：${value}"
}
require_positive() {
    local key=$1 value
    value=$(_cfg_value "$key")
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "${key} 必须为正整数。"
}
require_percent() {
    local key=$1 value
    value=$(_cfg_value "$key")
    [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v n="$value" 'BEGIN{exit !(n>=0 && n<=100)}' || die "${key} 必须是 0 到 100 之间的百分数。"
}
need_value() { require_var "$1"; }
need_file() { require_file "$1"; }
need_command() { command -v "$1" >/dev/null 2>&1 || die "缺少可执行程序：$1"; }
make_step_dir() { mkdir -p "$1"; cd "$1"; }

require_positive threads
for _p in "$workdir" "$datadir" "$database" "$scriptsdir"; do
    [[ "$_p" != *[[:space:]]* ]] || die '目录路径不能包含空格（现有流程脚本仍有未引用的旧路径）。'
done
export PATH="${SOFTWARE_DIR:-/share/work/biosoft}/bedtools:${SOFTWARE_DIR:-/share/work/biosoft}/Ltr_retriever/latest:${PATH}"
