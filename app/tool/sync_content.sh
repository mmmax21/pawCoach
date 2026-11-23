#!/usr/bin/env bash
# 把仓库根 content/ 下的 YAML 内容库复制进 app/assets/content/，
# 供 Flutter 打包进 assets。构建或内容库更新后运行一次。
#
# 用法：
#   cd app && tool/sync_content.sh
#   或在任意目录：bash app/tool/sync_content.sh
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$(cd "$APP_DIR/.." && pwd)/content"
DST="$APP_DIR/assets/content"

if [ ! -d "$SRC" ]; then
  echo "content 目录不存在: $SRC" >&2
  exit 1
fi

rm -rf "$DST"
mkdir -p "$DST/skills" "$DST/issues"
cp "$SRC"/skills/*.yaml "$DST/skills/"
cp "$SRC"/issues/*.yaml "$DST/issues/"
cp "$SRC/badges.yaml" "$SRC/care_calendar.yaml" "$SRC/VERSION.md" "$DST/"
# 内容库 v1.2 起：AI 健康拦截词表与检索词表（M3）
cp "$SRC/ai_guard.yaml" "$SRC/ai_terms.yaml" "$DST/"
# 内容库 v1.3 起：视频纠错检测规则（M5）
cp "$SRC/video_checks.yaml" "$DST/"
# 内容库 v1.4 起：常见问题（可缺省）
if [ -f "$SRC/faq.yaml" ]; then cp "$SRC/faq.yaml" "$DST/"; fi
# 内容库 v1.6 起：身体信号（可缺省）
if [ -f "$SRC/body_signals.yaml" ]; then cp "$SRC/body_signals.yaml" "$DST/"; fi

# 生成清单，Flutter 不能枚举 assets 目录，启动时按清单逐个读取。
{
  echo "# 由 tool/sync_content.sh 自动生成，不要手改"
  echo "skills:"
  for f in "$DST"/skills/*.yaml; do echo "  - $(basename "$f")"; done
  echo "issues:"
  for f in "$DST"/issues/*.yaml; do echo "  - $(basename "$f")"; done
} > "$DST/manifest.yaml"

echo "已同步：技能 $(ls "$DST"/skills | wc -l | tr -d ' ') 个，问题行为 $(ls "$DST"/issues | wc -l | tr -d ' ') 个 → $DST"
