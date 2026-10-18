#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"

require_file ONT_READS
require_positive GENOME_SIZE
require_positive NEXTDENOVO_JOBS
(( NEXTDENOVO_JOBS <= threads )) || die "NEXTDENOVO_JOBS 不能超过 threads"
job_threads=$((threads / NEXTDENOVO_JOBS))

mkdir -p $workdir/03.ONT_assembly_nextdenovo
cd $workdir/03.ONT_assembly_nextdenovo

echo "
[General]
job_type = local             # local, slurm, sge, pbs, lsf
job_prefix = nextDenovo
task = all                   # all, correct, assemble
rewrite = yes                # yes/no
deltmp = yes                 # 删除临时文件
parallel_jobs = ${NEXTDENOVO_JOBS}            # 并行任务数, 默认10 建议：内存/(32~64G)
input_type = raw             # raw, corrected
read_type = ont               # clr, ont, hifi
input_fofn = input.fofn       # reads文件路径列表
workdir = out

[correct_option]
read_cutoff = 1k               # could be 5k to make sure enough 50X to conduct assembly
genome_size = ${GENOME_SIZE}  # bp，来自目标样本的估计
pa_correction = ${NEXTDENOVO_JOBS}               # correct步骤并行任务数， 内存/(数据量*1.2/4)
sort_options = -m 2g -t ${job_threads}      # -m 数据量*1.2/4g -t 总线程数/pa_correction
minimap2_options_raw = -t ${job_threads}    #  总线程数 P/parallel_jobs
correction_options = -p ${job_threads}      # 总线程数 P/pa_correction

[assemble_option]
minimap2_options_cns = -t ${job_threads}    # 总线程数 -t P/parallel_jobs
nextgraph_options = -a 1       # 输出fasta格式
" > run.cfg

printf '%s\n' "$ONT_READS" > input.fofn

nextDenovo run.cfg
