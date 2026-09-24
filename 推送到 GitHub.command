#!/bin/bash
# 双击运行：把教材工程推送到 GitHub，触发云端编译
# 远程仓库已经配好了，所以这里只需要一次推送 + 一次登录

cd "$(dirname "$0")" || exit 1

echo "==============================================="
echo " 推送教材工程到 GitHub"
echo "==============================================="
echo ""

if ! command -v git >/dev/null 2>&1; then
  echo "❌ 没找到 git。终端执行 xcode-select --install 装上命令行工具后再试。"
  read -r -p "按回车关闭"
  exit 1
fi

URL="$(git remote get-url origin 2>/dev/null)"
if [ -z "$URL" ]; then
  echo "远程仓库还没配置。请先在终端里执行："
  echo "    git remote add origin https://github.com/你的用户名/仓库名.git"
  read -r -p "按回车关闭"
  exit 1
fi

echo "目标仓库 : $URL"
echo "本地状态 : $(git status --short | wc -l | tr -d ' ') 个未提交改动，共 $(git ls-files | wc -l | tr -d ' ') 个文件"
echo ""

# 有未提交改动就先提交掉
if [ -n "$(git status --short)" ]; then
  git add -A
  git commit -q -m "更新教材内容" 2>/dev/null && echo "✔ 已提交本地改动"
fi

echo "-----------------------------------------------"
echo "接下来会弹出登录提示，请按下面的说明填："
echo ""
echo "  Username : 你的 GitHub 用户名（就是 z660081-symzhy 这种）"
echo "  Password : 粘贴 Personal Access Token，不是登录密码！"
echo ""
echo "  还没有 token？按这个路径生成（全程 60 秒）："
echo "    1. 浏览器打开 github.com 并登录"
echo "    2. 右上角头像 → Settings"
echo "    3. 左侧拉到最底 → Developer settings"
echo "    4. Personal access tokens → Tokens (classic) → Generate new token (classic)"
echo "    5. 勾选 repo（只要勾这一个）→ 有效期选 90 days → 点最下面 Generate token"
echo "    6. 复制页面上那串 ghp_ 开头的字符（只显示这一次，关掉就没了）"
echo "    7. 回到这里，粘到 Password 位置（输入时不显示字符，正常）"
echo ""
echo "  Mac 会把它存进钥匙串，以后就不用了。"
echo "-----------------------------------------------"
echo ""
read -r -p "准备好了就按回车开始推送…" _

if git push -u origin main; then
  echo ""
  echo "==============================================="
  echo " ✅ 推送成功！"
  echo "==============================================="
  echo ""
  echo "接下来："
  echo "  1. 打开 https://github.com/z660081-symzhy/Newbie-agentbook-ios/actions"
  echo "  2. 等「云端编译 IPA」跑完（约 3-6 分钟，黄点变绿勾）"
  echo "  3. 点进这次运行，页面最下方 Artifacts 下载 AgentBook-ipa.zip"
  echo "  4. 解压得到 AgentBook.ipa，用 AltStore 装到手机"
  echo ""
  echo "别忘了 iPhone 上要打开「开发者模式」："
  echo "  设置 → 隐私与安全性 → 最下面 → 开发者模式 → 打开 → 重启"
else
  echo ""
  echo "❌ 推送失败。对号入座："
  echo ""
  echo "  Authentication failed         → token 不对或没勾 repo 权限，重新生成一个"
  echo "  updates were rejected          → 远程仓库里有内容（建仓库时勾了 README），执行："
  echo "                                   git pull --rebase origin main"
  echo "                                   然后再双击本文件"
  echo "  Could not resolve host         → 网络问题，检查能不能打开 github.com"
  echo "  Support for password auth...   → 你填的可能是登录密码，要用 token"
  echo ""
  echo "  如果看不懂报错，把上面几行原文发我，我帮你判断。"
fi

echo ""
read -r -p "按回车关闭窗口"
