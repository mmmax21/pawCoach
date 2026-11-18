# 来源

本目录由队友的独立项目 PawCoach 整合而来（2026-11-18）。

- 原路径：`/Users/maxlou/Documents/ChatGPT/1121黑客松-凌霄方案/pawCoach`
- 原仓库提交：`df2227c`（2026-11-17，"常见口令默认表"），另含当时未提交的 `Dockerfile`、`compose.yaml`、`.dockerignore`
- 未复制：git 历史、`data/`（本地视频、模型缓存、数据库）、`results/`、虚拟环境与缓存

整合后的改动以本仓库提交记录为准。队友原项目若有后续更新，需要手动比对合并。

## 运行环境

本机 conda 环境 `pawcoach`（Python 3.12），已装 requirements.txt + requirements-b.txt + pytest、conda-forge 的 ffmpeg。
运行前先 `conda activate pawcoach`，否则找不到 ffmpeg。检测权重放在 `video_service/data/models/yolov8n.pt`。
