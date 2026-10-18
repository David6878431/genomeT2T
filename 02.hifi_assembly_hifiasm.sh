#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file HIFI_READS


mkdir -p $workdir/02.hifi_assembly_hifiasm
cd $workdir/02.hifi_assembly_hifiasm

hifiasm -o hifi.asm  -t ${threads} "$HIFI_READS"
awk '/^S/{print ">"$2; print $3}' hifi.asm.bp.p_ctg.gfa > hifi.fa

# 仅有HiFi数据
# 运行结束后生成的一系列文件中，我们只需要关注如下几项 (prefix表示前缀）
#
#   hifi.asm.bp.r_utg.gfa: haplotype-resolved raw unitig graph，记录所有的单倍型
#   hifi.asm.bp.p_utg.gfa: 在raw unitig graph基础上过滤小的bubble，
#   hifi.asm.bp.p_ctg.gfa: 主要contig的assembly graph
#   hifi.asm.bp.hap1.p_ctg.gfa: haplotype1的部分分型的contig graph
#   hifi.asm.bp.hap2.p_ctg.gfa: haplotype2的部分分型的contig graph
#  GFA 格式是一种制表符分隔的文本格式，用于描述一组序列及其重叠。行的第一个字段标识行的类型。标题行以 H 开头。 Segment行以 S 开头。 链接行以 L 开头。
# Segment: a continuous sequence or subsequence.
