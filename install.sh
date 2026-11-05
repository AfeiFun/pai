#!/usr/bin/env bash
# pai 安装：skill 装到 ~/.claude/skills/pai，命令装到 ~/.local/bin（pai-run / paimodel / pai-m）
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/pai"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$SKILL_DIR" "$BIN_DIR"
cp "$SRC/skill/SKILL.md" "$SKILL_DIR/"
if [[ -f "$SKILL_DIR/models.json" ]]; then
  echo "保留已有的 $SKILL_DIR/models.json（新模板在 $SRC/skill/models.json）"
else
  cp "$SRC/skill/models.json" "$SKILL_DIR/"
  chmod 600 "$SKILL_DIR/models.json"
fi

for f in pai-run paimodel; do
  cp "$SRC/bin/$f" "$BIN_DIR/$f"
  chmod +x "$BIN_DIR/$f"
done
ln -sf paimodel "$BIN_DIR/pai-m"

echo "已安装：$SKILL_DIR 和 $BIN_DIR/{pai-run,paimodel,pai-m}"
echo
echo "依赖检查："
for c in claude python3 jq; do
  if command -v "$c" >/dev/null 2>&1; then echo "  ✓ $c"; else echo "  ✗ $c"; fi
done
[[ -x /Applications/Otty.app/Contents/MacOS/otty-cli ]] && echo "  ✓ Otty" || echo "  ✗ Otty（必需：pai-run 只在 Otty 里分屏）"
DSH="/Applications/DeepSeek Harness.app/Contents/Resources/runtime/cli/bin/dsh"
[[ -x "$DSH" ]] && echo "  ✓ DeepSeek Harness（dsh）" || echo "  ✗ DeepSeek Harness（只有 deepseek-dsh 条目需要）"
command -v zstd >/dev/null 2>&1 && echo "  ✓ zstd" || echo "  ✗ zstd（可选：deepseek-dsh 的 OBSERVED 读会话记录用，brew install zstd）"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo; echo "⚠️  $BIN_DIR 不在 PATH 里，往 ~/.zshrc 加：export PATH=\"\$HOME/.local/bin:\$PATH\"" ;; esac
echo
echo "下一步：export OPENCODE_GO_API_KEY=<你的 opencode go key>（或填进 $SKILL_DIR/models.json 的 api_key）"
