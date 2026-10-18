# genomeT2T 0.1.0 配置要点

当需要创建、调整或核对 TOML 时读取。本说明按随附 wheel 的实际接口编写；其他版本以对应帮助和源码为准。

## 两种配置入口

Python 命令读取 TOML，临时转成有引用保护的 Bash 配置传入脚本。无需同时维护 TOML 和 `config.sh`。只有直接执行仓库根目录的旧 `.sh` 入口才使用 `config.sh`。

`init` 不覆盖已有文件。路径和参数应写入用户的项目目录，不能写入技能目录或随附 wheel。TOML 不执行 Shell；多个选项适合用字符串数组表达：

```toml
[pipeline]
workdir = "/work/myt2t"
datadir = "/work/data"
database = "/work/database"
scriptsdir = "/work/script"
threads = 16
HIFI_READS = "/work/data/sample.hifi.fq.gz"
QUAL_MODULES = ["stats", "busco"]
TRNASCAN_OPTIONS = ["-E", "-G"]

[docker]
workdir = "./results"
datadir = "./data"
database = "./database"
helpers = ""
assembly_image = "omicsclass/genome-t2t:v1.0"
annotation_image = "omicsclass/genome-annotation:v1.0"
```

这是路径与类型示例，运行 BUSCO 仍需填写 `BUSCO_LINEAGES`。可以填写多个所选谱系，如字符串数组，但名称和数据库版本必须与已准备的 lineage 相符。

## 所选步骤需要的信息

| 字段 | 判断和单位 |
| --- | --- |
| `threads` | 正整数；不是自动内存预算 |
| `GENOME_SIZE` | bp 正整数；不要填 `146m` 形式。用于 NextDenovo/NG50 的目标估计 |
| `PLOIDY` / `KMER_SIZE` | 样本倍性与 k-mer 长度；应有样本依据 |
| `CHROMOSOME_COUNT` | Hi-C 分组使用的预期单倍体染色体数 |
| `NEXTDENOVO_JOBS` / `NEXTPOLISH_JOBS` | 并发任务数，不超过 threads；单任务线程由总线程分配，内存还需另行判断 |
| `HIC_ENZYME` / `HIC_PREPROCESS_ENZYME` / `HIC_RE_SITE` | ALLHiC 名称、预处理名称、识别序列；三项要对应真实建库方案 |
| `REPEAT_TAXON` / `EGGNOG_TAX_SCOPE` / `BUSCO_LINEAGES` | 分类数据库参数，不能从其他样本照搬 |
| `POLISH_INPUT` / `INPUT_CONTIGS` / `SCAFFOLD_CONTIGS` / `SCAFFOLD_FASTA` / `FINAL_ASSEMBLY` | 各阶段显式输入；切换组装分支后逐项核对，不能继续沿用默认分支输出路径 |
| `REF_GENOME` / `REF_GFF` | 同一参考版本、坐标和序列 ID 一致；供参考挂载和 Liftoff 使用 |
| `HOMOLOGY_REFERENCES` | 无表头 TSV：唯一参考 ID、基因组 FASTA、protein-coding GFF3。第二列不是蛋白 FASTA |
| `TRUSTED_TRANSCRIPTS` | 可选可信目标转录本；不可默认把近缘物种 CDS 当成目标物种全长证据 |
| `QUAL_MODULES` | 从 stats、mapping、merqury、lai、busco 中明确选择；不同模块需要不同数据与工具 |

未使用步骤保留的 `REPLACE_ME` 不阻止当前步骤；对用户实际要运行的步骤，必须补齐对应字段。`repeats` 需要先有 LAI 产物，不能只跑 `assess` 的默认 stats/busco 就假定上游已齐。

## 路径和挂载

- Docker：分析输入使用容器路径，四个分析目录不能含空白字符；宿主机可用 `C:/T2T/data` 之类路径。先确认 Docker 运行在哪台主机，bind mount 使用的是 daemon 主机路径。
- Local：相对文件路径以 TOML 所在目录解析；程序在当前软件环境中执行。
- `helpers` 仅在确有完整辅助脚本目录时设置。挂到 `scriptsdir` 会遮住镜像原有目录，不能以空目录代替缺失的辅助程序。
- 挂载结果目录和输入/数据库目录需要预先存在；检查输入名、宿主机路径到容器路径的对应关系，不通过更改无关系统配置来掩盖路径错误。
- 质量检查有明确边界：Docker 的 `validate --check-files` 不证明镜像里全部程序可运行；实际命令仍可能报告数据库、工具或上游产物缺失。
