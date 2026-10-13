# hermes-webui（合并镜像构建仓）

把 [nesquena/hermes-webui](https://github.com/nesquena/hermes-webui)（官方 webui 镜像）与
[nousresearch/hermes-agent](https://github.com/NousResearch/hermes-agent)（官方 agent 源码）
合并为**单容器镜像**，发布到 `ghcr.io/jazzzzmaybe/hermes-webui:latest`。

- webui 的容器 init 会在 `/opt/hermes` 查找 agent 源码（含 `pyproject.toml` 即命中），
  启动时自动 `uv pip install` 进容器 venv——因此合并镜像单容器即可跑完整 agent，无需源码卷。
- 每日 UTC 18:30（北京时间 02:30）自动重建，两个上游均在构建时刻拉取最新版，
  webui+agent 版本在**同一次构建内原子配对**，不存在版本 skew。
- 构建失败不推送新 tag，下游（watchtower）继续使用旧镜像，无回滚风险。
- **agent v0.21.6+ 起，依赖以密封运行时 `/opt/hermes/.venv` 随 agent 镜像发布**：合并镜像必须
  保留该目录，并把容器内 WebUI 启动解释器指向它（`pm-runtime` 的 3.14 store python）。删掉它
  会导致「服务能启动、界面能开，但每条会话报 `AIAgent not available`」——Dockerfile 已带
  构建期自检（版本断言 + 依赖导入探针 + init 启动行 grep），上游改动不再静默坏掉。

Unraid 使用方式：Portainer stack 贴 `compose.yml`，watchtower 自动更新。
