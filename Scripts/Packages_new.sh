#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg/name，可选，pkg为从大杂烩中单独提取包名插件；name为重命名为包名"

# 主题（仅保留 argon）
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"

# 代理插件
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

# SmartDNS
UPDATE_PACKAGE "smartdns" "pymumu/openwrt-smartdns" "master" ""
UPDATE_PACKAGE "luci-app-smartdns" "pymumu/luci-app-smartdns" "master" ""

# 修复 smartdns 哈希校验：拉取最新源码后更新 Makefile 中的 PKG_SOURCE_VERSION 和 PKG_VERSION
# smartdns 使用 PKG_SOURCE_PROTO:=git，需更新 PKG_SOURCE_VERSION（commit hash）
# PKG_MIRROR_HASH 无法预计算，直接删除让构建系统从源 URL 下载
# 注意：脚本运行在 package/ 目录下（UPDATE_PACKAGE 用 ../feeds/ 可佐证），直接用相对路径
SMARTDNS_DIR="./openwrt-smartdns"
SMARTDNS_MK="$SMARTDNS_DIR/Makefile"
if [ -f "$SMARTDNS_MK" ] && [ -d "$SMARTDNS_DIR" ]; then
  SMARTDNS_COMMIT=$(cd "$SMARTDNS_DIR" && git rev-parse HEAD 2>/dev/null)
  SMARTDNS_VERSION=$(cd "$SMARTDNS_DIR" && git describe --tags --abbrev=0 2>/dev/null || echo "")
  if [ -z "$SMARTDNS_VERSION" ]; then
    SMARTDNS_VERSION=$(cd "$SMARTDNS_DIR" && git log -1 --format='%cd' --date=format:'%Y.%m.%d' 2>/dev/null)
  fi
  if [ -n "$SMARTDNS_COMMIT" ]; then
    echo "修复 smartdns: PKG_SOURCE_VERSION -> $SMARTDNS_COMMIT"
    sed -i "s/^PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$SMARTDNS_COMMIT/" "$SMARTDNS_MK" 2>/dev/null || true
    sed -i "s/^PKG_VERSION:=.*/PKG_VERSION:=$SMARTDNS_VERSION/" "$SMARTDNS_MK" 2>/dev/null || true
    # 删除 PKG_MIRROR_HASH 行，避免旧哈希校验失败
    sed -i "/^PKG_MIRROR_HASH:=/d" "$SMARTDNS_MK" 2>/dev/null || true
    echo "smartdns Makefile 哈希修复完成"
  fi
else
  echo "警告: 未找到 smartdns Makefile ($SMARTDNS_MK)，跳过哈希修复"
fi

# 网络测速
UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"

# 常用插件
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "gecoosac luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "luci-app-airoha-npu" "bingoguo93/luci-app-airoha-npu" "main"
UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"
UPDATE_PACKAGE "luci-app-tailscale-community" "Tokisaki-Galaxy/luci-app-tailscale-community" "master" "" "luci-app-tailscale-community"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
