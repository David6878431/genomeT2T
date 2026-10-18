# 根据数据和已有产物选择流程

在选择分支、衔接输入或解释缺失依赖时读取。完整入口名称以启动器的 `stages` 输出为准；不要把所有编号脚本自动串成一次分析。

| 数据/目标 | 入口 | 衔接条件 |
| --- | --- | --- |
| Illumina 的基因组特征估计 | `kmer` | 双端数据及倍性；结果用于后续参数判断 |
| 仅 HiFi 组装 | `hifi` | 配置 HIFI_READS；无需假定 ONT 或 Hi-C 存在 |
| ONT 组装与纠错 | `ont`、按数据决定是否 `ont-polish` | ont 要求 GENOME_SIZE。当前 ont-polish 模板明确要求 HiFi、ONT、Illumina 文件；缺少时不能直接运行它或声称支持该纠错组合 |
| HiFi + ONT 混合组装 | `hybrid` | 两类长读长均存在；后续 INPUT_CONTIGS 要指向所选 hybrid 输出 |
| 对比或合并已有组装 | `merge` | 原脚本依赖对应 HiFi、ONT 纠错等结果；不是自动发现的通用合并入口 |
| 污染筛查/输出选择 | `filter` | INPUT_CONTIGS 为实际所选组装。CONTAMINANT_FASTA 留空时只复制，不执行自动去重 |
| 有近缘参考的挂载 | `scaffold` | REF_GENOME、SCAFFOLD_CONTIGS、CHROMOSOME_COUNT；评估参考偏差，不能替代独立 Hi-C 证据 |
| Hi-C 挂载 | `hic-prepare`，人工 Juicebox，再 `hic-finalize` | 样本 contig、Hi-C 双端、酶名与识别序列、辅助工具；人工结果和 CHROMOSOME_MAP 不可伪造 |
| 填 gap 与最终纠错 | `gapfill`、`polish` | gapfill 选择 reads/assembly 模式；分别核对 SCAFFOLD_FASTA、ONT_READS/RACON 或 GAPFILL_ASSEMBLY。polish 需明确 POLISH_INPUT |
| 组装质量与结构检测 | `assess`、`centromere`、`telomere` | FINAL_ASSEMBLY 对应最终版本；模块和生物学阈值取决于物种/数据 |
| 重复序列与 ncRNA | `repeats`、`ncrna` | repeats 需要 assess 的 lai 输出及数据库；ncrna 依赖 Repeat 结果、Rfam、RNAmmer/tRNAscan 适配参数 |
| 同源与迁移注释 | `gemoma`、`liftoff` | 参考清单/参考 FASTA+GFF 坐标配套；Liftoff 染色体对应清单是可选显式证据，不能按编号猜测 |
| 转录证据与模型整合 | `pasa`、`evm`、`pasa-update` | RNA-seq、repeat 掩盖基因组及已生成的同源/迁移注释；EVM 原脚本依赖 GeMoMa、Liftoff 和 PASA 结果 |
| 下游注释/统计 | `function`、`circos`、`gene-stats`、`busco` | 依赖最终 GFF、蛋白和所选数据库；按实际结果位置检查 |

## 运行与结果解释

多个入口只按用户指定顺序运行，不自动补齐所有依赖。检查上游结果的实际文件及版本，尤其注意手动选择组装、填 gap 和最终纠错后的路径更新。

日志默认位于 TOML 旁的 `.genomet2t/runs/`。查看 `run.json` 的 status、各 stage 的 returncode 和 log。某一步失败会停止后续步骤；尚未出现的步骤不能报告为完成。重跑前检查已有输出；该版本没有自动续跑，也不保证重复执行同一目录是幂等的。

N50/NG50、reads 支持度、Merqury、BUSCO、LAI、Hi-C 热图及端粒/着丝粒候选支持不同结论。使用真实输出并注明样本和数据库版本；仅凭包名称、零退出码或某个单项分数，不能声称获得完整 T2T 基因组。
