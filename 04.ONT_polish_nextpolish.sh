#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file HIFI_READS
require_positive NEXTPOLISH_JOBS
(( NEXTPOLISH_JOBS <= threads )) || die "NEXTPOLISH_JOBS 不能超过 threads"
polish_threads=$((threads / NEXTPOLISH_JOBS))
require_file ONT_READS
require_file ILLUMINA_R1
require_file ILLUMINA_R2


mkdir -p $workdir/04.ONT_polish_nextpolish
cd $workdir/04.ONT_polish_nextpolish

ln -s ../03.ONT_assembly_nextdenovo/out/03.ctg_graph/nd.asm.fasta contig.fa

cat > run.cfg <<EOF
[General]
job_type = local         ## 运行环境，可选local、sge、pbs；
job_prefix = nextPolish  #任务名称，随便起个；
task = best              ## task need to run [all, default, best, 1, 2, 5, 12, 1212…], 1, 2 are different algorithm modules for short reads, while 5 is the algorithm module for long reads, all=[5]1234, default=[5]12, best=[55]1212. (default: best)
rewrite = yes
rerun = 3
parallel_jobs = ${NEXTPOLISH_JOBS}
multithread_jobs = ${polish_threads}
genome = contig.fa      ## 基因组文件
genome_size = auto      #基因组大小，设置为auto就可以了；
workdir = ./output      #指定输出工作路径；
polish_options = -p {multithread_jobs}

[sgs_option]
sgs_fofn = ./sgs.fofn
sgs_options = -max_depth 100 -bwa

[lgs_option]
lgs_fofn = ./lgs.fofn
lgs_options = -min_read_len 1k -max_depth 100
lgs_minimap2_options = -x map-ont -t {multithread_jobs} ##其他数据修改-x参## 二代reads文件

[hifi_option]
hifi_fofn = ./hifi.fofn
hifi_options = -min_read_len 1k -max_depth 100
hifi_minimap2_options = -x map-hifi
EOF

printf '%s\n' "$HIFI_READS" > ./hifi.fofn
printf '%s\n' "$ONT_READS" > ./lgs.fofn
printf '%s\n' "$ILLUMINA_R1" "$ILLUMINA_R2" > ./sgs.fofn

nextPolish run.cfg
