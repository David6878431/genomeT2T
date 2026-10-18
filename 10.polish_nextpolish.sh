#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file HIFI_READS
require_positive NEXTPOLISH_JOBS
(( NEXTPOLISH_JOBS <= threads )) || die "NEXTPOLISH_JOBS 不能超过 threads"
polish_threads=$((threads / NEXTPOLISH_JOBS))
require_file POLISH_INPUT


mkdir -p $workdir/10.polish_nextpolish
cd $workdir/10.polish_nextpolish

cat > nextpolish.cfg <<EOF
[General]
job_type = local
job_prefix = nextPolish
task = best
rewrite = yes
rerun = 3
parallel_jobs = ${NEXTPOLISH_JOBS}
multithread_jobs = ${polish_threads}
genome = ./genome.fa  #genome file
genome_size = auto
workdir = ./nextpolish_out # 指定输出文件夹
polish_options = -p {multithread_jobs}


[hifi_option]
hifi_fofn = ./hifi.fofn ## 写有hifi测序数据的文件
hifi_options = -min_read_len 10k -max_depth 100
hifi_minimap2_options = -x  map-hifi -t {multithread_jobs}
EOF

printf '%s\n' "$HIFI_READS" > hifi.fofn

ln -s "$POLISH_INPUT" genome.fa

nextPolish  nextpolish.cfg
