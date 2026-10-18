---
name: genome-t2t
description: 配置、检查和运行 genomeT2T 的 Python/Docker 基因组组装、评估与注释流程，解释对应运行日志和结果。用于操作 genomeT2T 包、它的 TOML 配置或同名流程脚本；不用于无关的通用生物学问答。
---

# GenomeT2T 组装助手

把用户的数据和目标转成明确的配置及流程步骤，执行已获授权的工作，并依据真实产物解释结果。此技能附带 `genomet2t 0.1.0`，生信分析仍由外部软件或 Docker 镜像执行。

## 入口

使用 Python 3.11+ 运行本技能目录下的 `scripts/launch.py`，后面直接跟 genomeT2T 子命令。启动器从 `assets/` 中读取随附 wheel，在临时目录加载，不安装全局 Python 包、不下载代码。先用 `--version` 确认入口；Python 缺失时明确说明，不能把 WindowsApps 的 Python 占位程序当成有效解释器。

```bash
python /path/to/genome-t2t/scripts/launch.py --version
python /path/to/genome-t2t/scripts/launch.py stages
```

将示例中的技能目录替换为本 `SKILL.md` 所在目录。用户明确指定另一版 genomeT2T 时，使用其指定环境并检查该版本的帮助，不能静默替换成随附版本。

## 依据请求行动

- **配置或方案**：定位用户已有 TOML，保留实际样本和镜像选择；没有配置时用 `init` 创建，不覆盖已有文件。按需阅读 [配置说明](references/configuration.md)。只索取所选步骤必需且无法从现有数据确定的信息。例如单独 HiFi 组装不需要用户提供 Hi-C 或近缘参考。
- **选择流程**：根据已有 reads、已完成的产物及用户目标选分支。阅读 [流程衔接](references/routing.md) 处理混合组装、挂载或注释依赖；用 `stages` 获取完整入口名。编号不是自动依赖图。
- **检查或执行**：对用户选定的步骤运行 `validate --stage`，必要时加 `--check-files`；随后用 `run ... --dry-run`核对镜像、输入和挂载。若用户已经授权实际运行，检查通过后继续执行，不把预览当成需要再次确认的审批。只要求预览/检查时不要启动分析。
- **排错或解释结果**：定位 `.genomet2t/runs/<运行编号>/run.json` 和该步骤日志，先解释首个实际失败点。结合输出文件定位问题；需要软件版本特有行为时核对官方说明，不能凭模板推断某个命令已经成功。

```bash
python /path/to/genome-t2t/scripts/launch.py init /project/genomeT2T.toml
python /path/to/genome-t2t/scripts/launch.py validate --config /project/genomeT2T.toml --stage hifi --check-files
python /path/to/genome-t2t/scripts/launch.py run hifi --config /project/genomeT2T.toml --dry-run
python /path/to/genome-t2t/scripts/launch.py run hifi --config /project/genomeT2T.toml
```

## 操作要点

- 默认 Docker 执行；宿主机需要可用的 Docker Linux 容器环境，镜像内部需要对应工具。已有 Linux 生信环境也可以选择 `--executor local`。不能把“包能导入”报告成“生信软件和数据库已齐备”。
- TOML 中 `[pipeline]` 的 Docker 分析路径为容器绝对路径；`[docker]` 是宿主机路径，相对路径以 TOML 所在目录为基准。宿主机有文件不等于容器能读到文件。
- `validate` 不选步骤仅检查基础配置；Docker 模式的 `--check-files` 检查宿主机挂载目录，不进入镜像验证全部输入/数据库。预览不启动 Docker，也不能证明组装结果正确。启动器生成的预览含临时路径；真正运行时重新调用 `launch.py run`，不要直接复用预览里的裸 Docker 命令。
- 不根据历史拟南芥示例猜测目标物种、倍性、染色体数、基因组大小、Hi-C 酶切位点、BUSCO 谱系或参考文件。未用到的模板字段不必为了当前步骤填满。
- `hic-prepare` 和 `hic-finalize` 必须分开；后者依赖人工保存的 `groups.review.assembly` 及真实的 `CHROMOSOME_MAP`。不能按序列顺序凭空假定染色体对应关系。
- `filter` 没有污染参考时只复制所选组装。不能为得到“干净基因组”自动删除 rDNA 或所有重复 contig。检查污染匹配证据再解释筛选结果。
- 失败后保留日志和已有产物；先明确失败原因及重跑目录的影响，再重试，不在同一目录盲目连续重跑。此包没有自动断点续跑。修正应围绕当前失败和用户目标，不替用户更换生物学方案。
- 报告包含配置位置、实际步骤、退出状态、日志和结果位置。区分已执行、仅预览、尚缺数据及需人工处理；名称包含 T2T 不等于产物已达到 T2T，也不能把候选端粒/着丝粒检测或 BUSCO 分数单独当成完整验证。

创建此技能本身不要求发布 GitHub、上传测序数据或运行整套分析；以用户当前请求决定这些动作。
