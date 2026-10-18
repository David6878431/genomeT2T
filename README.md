# genomeT2T

现在也提供可安装的 Python 包 `genomet2t`（Python 3.11+），统一管理配置、步骤选择、Docker 调用和运行日志。Python 包会携带现有 Shell 分析脚本，组装和注释仍由镜像中的生信软件执行。

## Python 包安装与运行

在本仓库目录安装，或从提供的 wheel 文件安装：

```bash
python -m pip install .
# 或：python -m pip install genomet2t-0.1.0-py3-none-any.whl
genomet2t --version
genomet2t stages
genomet2t init genomeT2T.toml
```

`init` 生成 TOML 配置，不会覆盖已有文件。修改 `[pipeline]` 中的样本参数，以及 `[docker]` 中的宿主机目录。相对宿主机目录以 TOML 所在目录为基准；Docker 模式的分析输入路径应为容器内的绝对路径。

```toml
[pipeline]
threads = 16
HIFI_READS = "/work/data/sample.hifi.fq.gz"

[docker]
workdir = "./results"
datadir = "./data"
database = "./database"
helpers = ""
assembly_image = "omicsclass/genome-t2t:v1.0"
annotation_image = "omicsclass/genome-annotation:v1.0"
```

以上展示 HiFi 单独组装所需的关键配置；完整模板由 `init` 生成。输入 FASTQ 应放到宿主机 `data` 目录，映射后才是 `/work/data/sample.hifi.fq.gz`。先准备这些目录，再检查和运行：

```bash
mkdir -p results data database
genomet2t validate --config genomeT2T.toml --stage hifi --check-files
genomet2t run hifi --config genomeT2T.toml --dry-run
genomet2t run hifi --config genomeT2T.toml
```

Windows 用户可使用 Python 3.11+ 和 Docker Desktop 的 Linux 容器模式；宿主机目录可在 TOML 中写成 `C:/T2T/data` 一类路径，并使用 PowerShell 的 `New-Item -ItemType Directory` 准备目录。配置中的容器路径仍为 `/work/...`。Windows 宿主机使用 Docker 执行时不需要安装 Bash。

常用命令：

| 命令 | 作用 |
| --- | --- |
| `genomet2t init` | 生成 TOML 配置模板 |
| `genomet2t stages` | 列出 26 个流程入口及使用的镜像类别 |
| `genomet2t validate --stage ont` | 检查所选步骤的必要参数、数值和线程预算 |
| `genomet2t run hybrid filter --dry-run` | 按指定顺序预览步骤和实际 argv，不启动分析 |
| `genomet2t run hifi` | 默认使用 Docker 执行所选步骤 |
| `genomet2t run hifi --executor local` | 在当前 Linux 环境调用 Bash 和已安装的软件 |
| `genomet2t run hifi --log-dir ./logs` | 为本次运行单独保存日志与 JSON 状态记录 |

Docker 模式会为每个步骤建立临时容器并自动选择组装或注释镜像，退出后删除该容器；分析结果保存在挂载的 `workdir`。用户修改过镜像时，可覆盖 `[docker]` 中对应的 image 参数。辅助脚本在镜像中不存在时，再填写 `helpers` 将完整辅助脚本目录挂到容器的 `scriptsdir`；空值会保留镜像原有目录。

每次运行的默认日志位于 TOML 文件旁的 `.genomet2t/runs/<运行编号>/`，包含各步骤日志和 `run.json`；任何步骤失败后，后续步骤停止运行并返回失败状态。该入口不自动猜测依赖、不自动选择组装分支、不自动断点续跑；请明确指定步骤，并在重跑前处理对应输出目录中的旧文件。`validate --check-files` 在 Docker 模式仅检查宿主机挂载目录，在 local 模式检查所选步骤的显式输入文件；容器内程序和数据库的完整性由实际运行进一步检查。`--dry-run` 会明确标注临时配置路径占位符，只用于预览。

Hi-C 的人工校正阶段须分两次运行，中间在 Juicebox 中完成检查，并设置 `CHROMOSOME_MAP`：

```bash
genomet2t run hic-prepare --config genomeT2T.toml
# 人工校正并保存 workdir/08.Chromhic/groups.review.assembly 后：
genomet2t run hic-finalize --config genomeT2T.toml
```

如果在已有 Docker 容器或 Linux 软件环境内部使用本包，安装 Python 3.11+ 后加 `--executor local`；所有输入和输出路径按该环境设置。本包没有额外 Python 运行时依赖，但不会替代 hifiasm、NextDenovo、PASA 等外部软件和数据库的安装。

Python API 也可导入：`from genomet2t import load_config, get_stage`，执行入口为 `genomet2t.runner.run_stages`。开发时可用 `python -m pip install -e .`；`python -m unittest discover -s tests -p 'test_*.py'` 运行包级测试。

TOML 是 Python 命令的配置格式。下文的 `config.sh` 和 `00.docker.sh` 用于直接运行旧 Shell 入口；两种入口可以选择其中一种。Python 命令会将 TOML 转为临时 Shell 配置并传入分析步骤，无需手动再维护一份 `config.sh`。

面向真核生物的 T2T 基因组组装与注释脚本。流程按阶段运行，支持 HiFi、ONT、Illumina、Hi-C 和 RNA-seq 数据；每个样本的路径、物种信息和分析参数集中写在 `config.sh`，运行脚本会在所需参数或文件缺失时停止并报错。

本仓库提供流程脚本，不包含测序数据、参考基因组、数据库、容器镜像或第三方辅助程序。脚本主要按 `omicsclass/genome-t2t:v1.0` 和 `omicsclass/genome-annotation:v1.0` 镜像中的软件布局编写；运行前要确认所用镜像具备相应软件和数据库。`/share/work/biosoft` 是原镜像中的软件目录，其他镜像需在配置中更新工具路径。

## Docker 使用

在安装并运行 Docker 的 Linux 宿主机上，进入本仓库目录。先为组装结果、输入数据和数据库准备宿主机目录：

```bash
mkdir -p "$HOME/T2T/myt2t" "$HOME/T2T/data" "$HOME/T2T/database"
export HOST_WORKDIR="$HOME/T2T/myt2t"
export HOST_DATADIR="$HOME/T2T/data"
export HOST_DATABASE="$HOME/T2T/database"
```

查看 `00.docker.sh` 的用法并下载镜像：

```bash
bash 00.docker.sh
bash 00.docker.sh pull
```

准备配置模板，并按下文填好 `config.sh`。配置文件在宿主机编辑并随仓库挂入容器；其中的测序数据和数据库路径应写成容器路径（默认 `/work/data/...` 和 `/work/database/...`）。

```bash
cp config.example.sh config.sh
```

启动组装环境：

```bash
bash 00.docker.sh assembly
```

需要使用注释镜像时，先正常退出当前容器，在宿主机运行：

```bash
bash 00.docker.sh annotation
```

脚本分别创建名为 `t2t` 和 `anno` 的交互式容器。停止后可用 `docker start -ai t2t` 或 `docker start -ai anno` 重新进入。宿主机目录通过 bind mount 映射到容器的 `/work/myt2t`、`/work/data` 和 `/work/database`，分析结果和数据库会写回对应目录。输入数据和数据库路径必须先存在；Docker bind mount 连接的是运行 Docker daemon 的主机路径。

如有随镜像提供、但不在本仓库中的 Perl、Python 或绘图辅助脚本，可按需把宿主机目录挂到 `/work/script`：

```bash
export HOST_HELPERS="$HOME/T2T/helpers"
bash 00.docker.sh assembly
```

只有在该目录包含脚本实际调用的辅助文件时才设置 `HOST_HELPERS`。它覆盖容器内的 `/work/script`，不要把空目录挂载到这里。容器以当前 Docker 默认用户运行；如遇到输出目录写入权限问题，应在宿主机先检查目录权限及容器 UID/GID。

## 统一配置

每个流程脚本都会从脚本所在目录读取 `config.sh`，所以可从任意工作目录运行。模板只需复制一次：

```bash
cp config.example.sh config.sh
```

在 `config.sh` 中先设置常用参数：

| 参数 | 含义 |
| --- | --- |
| `workdir` | 容器内的分析结果目录；应挂载到宿主机持久化存储 |
| `datadir` | 容器内输入数据目录 |
| `database` | 容器内的生物学数据库目录 |
| `scriptsdir` | 镜像或宿主机提供的辅助脚本目录 |
| `threads` | 常规步骤使用的线程数；高内存步骤需结合机器内存调整 |
| `species` | 目标物种基因 ID 前缀，仅用于依赖物种前缀的下游统计 |
| `GENOME_SIZE` | 目标基因组大小，单位为 bp 的正整数；供 NextDenovo 和 NG50 使用 |
| `PLOIDY`、`KMER_SIZE` | K-mer 分析所需的倍性和 k-mer 长度 |
| `CHROMOSOME_COUNT` | 预期单倍体染色体数，供 Hi-C 分组和共线性绘图使用 |
| `ILLUMINA_R1/R2`、`HIFI_READS`、`ONT_READS`、`RNASEQ_R1/R2`、`HIC_R1/R2` | 容器可见的各类测序文件路径；按实际数据修改 |
| `REF_GENOME`、`REF_GFF` | 可选近缘参考物种的基因组和注释；只在比较组装或 Liftoff 时需要 |
| `HOMOLOGY_REFERENCES` | GeMoMa 参考清单；TSV 每行依次为唯一参考 ID、基因组 FASTA 和 protein-coding GFF3，无表头 |
| `BUSCO_LINEAGES` | 空格分隔的 BUSCO lineage 名称；先在数据库中准备相应 lineage |
| `REPEAT_TAXON`、`REPEATMASKER_LIB` | RepeatMasker 数据库支持的分类名称和库文件 |
| `HIC_ENZYME`、`HIC_PREPROCESS_ENZYME`、`HIC_RE_SITE` | Hi-C 限制性内切酶的 ALLHiC 名称、预处理工具名称和识别序列 |
| `CONTAMINANT_FASTA` | 可选污染参考序列；留空时只复制输入组装，不执行自动污染过滤 |

模板中的文件名只是示例。准备的数据名称或样本类型不同，就更新对应路径。`REPEAT_TAXON`、BUSCO 谱系、eggNOG taxonomic scope、Hi-C 酶切位点、倍性、染色体数等生物学参数应按目标物种和实验方案填写，不能直接照搬示例。`REPEATMASKER_LIB`、`SPROT_CLEAN`、`UNIPROT_FASTA`、`UNIPROT_DIAMOND`、`BUSCO_PLOT` 及 `GEMOMA_JAR` 也必须指向本地真实存在的文件。

GeMoMa 的 `HOMOLOGY_REFERENCES` 格式示例：

```text
ref_a    /work/data/ref_a.genome.fa.gz    /work/data/ref_a.protein_coding.gff3
ref_b    /work/data/ref_b.genome.fa.gz    /work/data/ref_b.protein_coding.gff3
```

三列之间用 Tab 分隔，参考 ID 只可包含英文字母、数字、下划线和连字符，且不能重复。参考文件应使用**已经筛选为蛋白编码基因**的 GFF3，并与各自的基因组 FASTA 配套，染色体/序列 ID 和坐标应一致。目录路径不要包含空格，因为部分旧版生信工具仍要求无空格路径。

## 流程阶段

| 脚本 | 用途与要点 |
| --- | --- |
| `01.Kmer.sh` | Jellyfish 和 GenomeScope；需要 Illumina 双端数据及倍性、k-mer 参数 |
| `02.hifi_assembly_hifiasm.sh` | HiFi 单独组装 |
| `03.ONT_assembly_nextdenovo.sh` | ONT 单独组装；需要 genome size，`NEXTDENOVO_JOBS` 不可大于 `threads` |
| `04.ONT_polish_nextpolish.sh` | 使用已配置读长数据进行 NextPolish；需核对脚本的 FOFN 输入及 `NEXTPOLISH_JOBS` |
| `05.hifiONT_assembly_hifiasm.sh` | HiFi 与 ONT 混合组装；需同时提供两种长读长 |
| `06.merge_ragtag.sh` | 合并/比较 ONT、HiFi 组装结果；需先运行相应上游分支 |
| `07.rmimpurities.sh` | 选择组装结果并按可选污染参考筛查；需人工复核过滤结果 |
| `08.ChromSyn.sh` | 以近缘参考基因组比较共线性并做 RagTag scaffold |
| `08.Chromhic.sh prepare` | 将 Hi-C reads 比对到 contig 并运行 ALLHiC，准备供人工检查的分组结果 |
| `08.Chromhic.sh finalize` | 用户在 Juicebox 检查并保存 `groups.review.assembly` 后，重建并评估最终序列 |
| `09.gapfill.sh`、`10.polish_nextpolish.sh` | 填补 gap 及后续纠错；按配置选定输入 FASTA 和 reads |
| `11.Centromere.sh`、`12.Telomere.sh` | 着丝粒和端粒区域分析；调节所用工具、物种分组及周期阈值 |
| `13.qualAssess.sh` | 按 `QUAL_MODULES` 运行质量评估模块，如 `stats`、`mapping`、`merqury`、`lai`、`busco`；所选模块的测序数据和数据库须预先齐备 |
| `14.Repeat.sh`、`15.ncRNA.sh` | 重复序列与 ncRNA 注释；需配置分类数据库及辅助程序 |
| `16.GeMoMa.sh`、`17.liftoff.sh` | 选择一个或多个近缘物种作为同源注释参考，或迁移近缘注释；参考必须在配置中明确给出 |
| `18.PASA.sh`、`19.EVM.sh`、`20.PASA_update.sh` | RNA-seq 组装、注释证据整合和 PASA 更新；按需求提供 RNA-seq 或可信全长转录本 |
| `21.genefunction.sh`、`22.MCScanX_circos.sh` | 基因功能注释、共线性及 Circos 图 |
| `23.gene_stat.sh`、`24.BUSCO.sh` | 基因模型统计和蛋白 BUSCO 评估 |

这些阶段不是无条件的单线流水线。根据实际测序类型选择 02、03 或 05 等组装分支；Hi-C 的 Juicebox 校正需要人工参与；比较组装和基因注释迁移只有在准备了配套参考数据时才运行。每个编号脚本会写入 `workdir` 下相应的编号目录。不要在没有检查前一阶段输出的情况下跳过阶段顺序。

## 运行示例

在容器中且已完成配置、数据挂载后，逐步运行实际需要的阶段：

```bash
bash 01.Kmer.sh
bash 05.hifiONT_assembly_hifiasm.sh
bash 07.rmimpurities.sh
bash 08.Chromhic.sh prepare
# 手动检查与修正 Juicebox 文件后：
bash 08.Chromhic.sh finalize
```

示例展示脚本调用方式，不代表所有样本都要运行这些步骤。所有文件路径必须在当前容器可见，结果写入 `workdir` 挂载目录。

## 审核和可复现性

提交前先检查 `config.sh`、`data/`、参考文件及分析产物；仓库的 `.gitignore` 会排除本地配置、测序文件、数据库、结果、日志和二进制输出。只提交通用脚本、配置模板和说明。脚本提供的是分析模板，测序参数、软件版本、数据库版本和物种数据库选择仍应根据自己的样本记录并复核。

运行轻量配置检查：

```bash
bash tests/config_smoke.sh
```

测试会用命令替身检查参数传递、配置错误和 Docker 挂载参数，不会运行真实生信软件，也不能验证实际组装结果。
