#!/bin/bash
# 双击运行：把当前目录推送到你的 GitHub 仓库，触发云端编译
# 如果提示「无法打开」，先在终端执行：chmod +x "推送到 GitHub.command"

cd "$(dirname "$0")" || exit 1

echo "==============================================="
echo " 把教材工程推送到 GitHub"
echo "==============================================="
echo ""

if ! command -v git >/dev/null 2>&1; then
  echo "❌ 没找到 git。终端执行 xcode-select --install 装上命令行工具后再试。"
  read -r -p "按回车关闭"
  exit 1
fi

if [ ! -d .git ]; then
  echo "▶ 这个目录还不是 git 仓库，准备初始化…"
  git init -q
fi

# 检查 git 身份
if [ -z "$(git config user.name)" ]; then
  read -r -p "第一次提交，请输入一个名字（随便填，比如你的昵称）: " GN
  git config user.name "$GN"
fi
if [ -z "$(git config user.email)" ]; then
  read -r -p "再输入一个邮箱（随便填，只用于提交记录）: " GE
  git config user.email "$GE"
fi

echo ""
echo "▶ 先看看这次会提交哪些文件（.github 是隐藏目录，也会被包含）："
git add -A
git status --short | head -30
echo "  （共 $(git status --short | wc -l | tr -d ' ') 个文件）"
echo ""
read -r -p "没问题就按回车继续，否则按 Ctrl+C 退出: " _

git commit -q -m "Agent 就业教材 iOS 版" 2>/dev/null || echo "（没有新变化，跳过提交）"
git branch -M main

echo ""
echo "现在需要你填 GitHub 仓库地址。"
echo "先在浏览器里新建一个空仓库（不要勾选 README / .gitignore），"
echo "然后把它给的地址粘到这里，形如："
echo "   https://github.com/你的用户名/仓库名.git"
echo ""
read -r -p "仓库地址: " URL

if [ -z "$URL" ]; then
  echo "没填地址，退出。"
  read -r -p "按回车关闭"
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$URL"
else
  git remote add origin "$URL"
fi

echo ""
echo "▶ 正在推送…（第一次会让你输入 GitHub 的用户名和 token）"
echo "  注意：GitHub 现在不接受账号密码，要填 Personal Access Token。"
echo "  没有的话看 路2-云端编译与侧载.md 里的说明。"
echo ""

if git push -u origin main; then
  echo ""
  echo "✅ 推送成功！"
  echo ""
  echo "接下来："
  echo "  1. 打开 https://github.com/你的用户名/仓库名/actions"
  echo "  2. 等「云端编译 IPA」跑完（约 3-6 分钟）"
  echo "  3. 在该页面底部下载 AgentBook-ipa 产物，解压得到 AgentBook.ipa"
  echo "  4. 用 AltStore 装到 iPhone"
else
  echo ""
  echo "❌ 推送失败。常见原因："
  echo "   - 仓库地址写错（要以 .git 结尾）"
  echo "   - 没有登录凭据 / token 无效"
  echo "   - 仓库是新建的但勾了 README，导致远程有内容冲突"
  echo ""
  echo "  如果是第三种，执行下面这行再来一次："
  echo "      git pull --rebase origin main"
fi

echo ""
read -r -p "按回车关闭窗口"
