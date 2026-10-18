#!/usr/bin/env bash
# 在 Docker 所在的 Linux 宿主机运行；分析脚本在容器中运行。
set -Ee -o pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mode=${1:-help}
assembly_image=${ASSEMBLY_IMAGE:-omicsclass/genome-t2t:v1.0}
annotation_image=${ANNOTATION_IMAGE:-omicsclass/genome-annotation:v1.0}
case "$mode" in
    pull) docker pull "$assembly_image"; docker pull "$annotation_image"; exit ;;
    assembly) image=$assembly_image; container=${CONTAINER_NAME:-t2t} ;;
    annotation) image=$annotation_image; container=${CONTAINER_NAME:-anno} ;;
    *) printf '用法：bash 00.docker.sh {pull|assembly|annotation}\n宿主机目录：HOST_WORKDIR HOST_DATADIR HOST_DATABASE，可选 HOST_HELPERS。\n'; exit 0 ;;
esac
for key in HOST_WORKDIR HOST_DATADIR HOST_DATABASE; do
    [[ -n "${!key:-}" && "${!key}" == /* && -d "${!key}" ]] || { printf '请设置已存在的宿主机绝对目录：%s\n' "$key" >&2; exit 1; }
done
mounts=(--mount "type=bind,src=$repo_dir,dst=/work/genomeT2T"
    --mount "type=bind,src=$HOST_WORKDIR,dst=/work/myt2t"
    --mount "type=bind,src=$HOST_DATADIR,dst=/work/data"
    --mount "type=bind,src=$HOST_DATABASE,dst=/work/database")
if [[ -n "${HOST_HELPERS:-}" ]]; then
    [[ "$HOST_HELPERS" == /* && -d "$HOST_HELPERS" ]] || { printf 'HOST_HELPERS 必须为现有绝对目录\n' >&2; exit 1; }
    mounts+=(--mount "type=bind,src=$HOST_HELPERS,dst=/work/script")
fi
docker run -it --name "$container" "${mounts[@]}" -w /work/genomeT2T "$image" /bin/bash
