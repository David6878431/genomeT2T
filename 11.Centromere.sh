#!/usr/bin/env bash
set -Ee -o pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/env.sh"
require_file FINAL_ASSEMBLY


mkdir -p $workdir/11.Centromere
cd $workdir/11.Centromere

ln -s "$FINAL_ASSEMBLY" ./genome.fa

"$CENTROMINER" \
 -i genome.fa -p cent_out -n "$CENTROMERE_MIN" -m "$CENTROMERE_MAX" -t ${threads}
# -n MIN_PERIOD 一个着丝粒重复单元的最小长度Min period to be consider as centromere repeat monomer. Default: 100
# -m MAX_PERIOD  一个着丝粒重复单元的最大长度Max period to be consider as centromere repeat monomer. Default: 200

# 结果的${prefix}.best.candidate每个染色体上的最佳候选着丝粒，以及相应的单体
