#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file HIFI_READS
require_file ONT_READS


mkdir -p $workdir/05.hifiONT_assembly_hifiasm
cd $workdir/05.hifiONT_assembly_hifiasm

hifiasm -o hifiONT \
-t ${threads} \
--ul "$ONT_READS" \
"$HIFI_READS"

# 筛选以s开头的行，输出
awk '/^S/{print ">"$2; print $3}' hifiONT.bp.p_ctg.gfa > hifiONT.fa

#   hifi.asm.bp.r_utg.gfa: haplotype-resolved raw unitig graph，记录所有的单倍型
#   hifi.asm.bp.p_utg.gfa: 在raw unitig graph基础上过滤小的bubble，
#   hifi.asm.bp.p_ctg.gfa: 主要contig的assembly graph
#   hifi.asm.bp.hap1.p_ctg.gfa: haplotype1的部分分型的contig graph
#   hifi.asm.bp.hap2.p_ctg.gfa: haplotype2的部分分型的contig graph
#  GFA 格式是一种制表符分隔的文本格式，用于描述一组序列及其重叠。行的第一个字段标识行的类型。标题行以 H 开头。 Segment行以 S 开头。 链接行以 L 开头。
# Segment: a continuous sequence or subsequence.
 # --write-paf f 和 --write-ec: 这些选项允许用户输出错误校正后的read（以PAF格式）和读取重叠信息。这有助于用户进一步分析和调试组装过程
