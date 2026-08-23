# hermes-webui（合并镜像构建仓）

把 [nesquena/hermes-webui](https://github.com/nesquena/hermes-webui)（官方 webui 镜像）与
[nousresearch/hermes-agent](https://github.com/NousResearch/hermes-agent)（官方 agent 源码）
合并为**单容器镜像**，发布到 `ghcr.io/jazzzzmaybe/hermes-webui:latest`。

- webui 的容器 init 会在 `/opt/hermes` 查找 agent 源码（含 `pyproject.toml` 即命中），
  启动时自动 `uv pip install` 进容器 venv——因此合并镜像单容器即可跑完整 agent，无需源码卷。
- 每日 UTC 18:30（北京时间 02:30）自动重建，两个上游均在构建时刻拉取最新版，
  webui+agent 版本在**同一次构建内原子配对**，不存在版本 skew。
- 构建失败不推送新 tag，下游（watchtower）继续使用旧镜像，无回滚风险。

Unraid 使用方式：Portainer stack 贴 `compose.yml`，watchtower 自动更新。
