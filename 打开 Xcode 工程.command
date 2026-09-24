#!/bin/bash
# 双击这个文件，直接用 Xcode 打开教材工程
# 如果提示「无法打开」，先在终端执行：chmod +x "打开 Xcode 工程.command"

DIR="$(cd "$(dirname "$0")" && pwd)"
PROJ="$DIR/AgentBook/AgentBook.xcodeproj"

echo "==============================================="
echo " Agent 就业教材 · iOS 工程"
echo "==============================================="

if [ ! -d "$PROJ" ]; then
  echo "找不到工程：$PROJ"
  read -r -p "按回车关闭"
  exit 1
fi

if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
  echo ""
  echo "⚠️  检测到还没安装 Xcode（目前只有命令行工具）。"
  echo "    请先到 App Store 搜索 Xcode 下载安装，装完打开一次。"
  echo ""
  echo "    安装完成后重新双击本文件即可。"
  echo ""
  read -r -p "按回车关闭"
  exit 1
fi

echo "正在打开工程…"
open "$PROJ"
echo ""
echo "接下来在 Xcode 里做两件事："
echo "  1. 左侧点蓝色 AgentBook → TARGETS → AgentBook → Signing & Capabilities"
echo "  2. Team 选你的 Apple ID；Bundle Identifier 改成 com.你的英文名.agentbook"
echo ""
echo "然后插上 iPhone，顶部选中你的设备，按 ⌘R。"
sleep 3
