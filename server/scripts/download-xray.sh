#!/bin/bash

# 下载 Xray 二进制文件的脚本
# 支持 Windows、macOS、Linux 平台

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取最新版本
get_latest_version() {
    local api_url="https://api.github.com/repos/XTLS/Xray-core/releases/latest"
    local version=$(curl -s "$api_url" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$version"
}

# 获取系统信息
get_system_info() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case $arch in
        x86_64)
            arch="64"
            ;;
        arm64|aarch64)
            arch="arm64-v8a"
            ;;
        armv7l)
            arch="arm32-v7a"
            ;;
        *)
            echo -e "${RED}不支持的架构: $arch${NC}"
            exit 1
            ;;
    esac
    
    case $os in
        linux)
            os="linux"
            ;;
        darwin)
            os="macos"
            ;;
        *)
            echo -e "${RED}不支持的操作系统: $os${NC}"
            exit 1
            ;;
    esac
    
    echo "${os}-${arch}"
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    
    echo -e "${YELLOW}正在下载: $url${NC}"
    
    if command -v wget >/dev/null 2>&1; then
        wget -O "$output" "$url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$output" "$url"
    else
        echo -e "${RED}错误: 需要 wget 或 curl 来下载文件${NC}"
        exit 1
    fi
}

# 解压文件
extract_file() {
    local file="$1"
    local output_dir="$2"
    
    echo -e "${YELLOW}正在解压: $file${NC}"
    
    if [[ "$file" == *.zip ]]; then
        if command -v unzip >/dev/null 2>&1; then
            unzip -o "$file" -d "$output_dir"
        else
            echo -e "${RED}错误: 需要 unzip 来解压文件${NC}"
            exit 1
        fi
    elif [[ "$file" == *.tar.gz ]]; then
        if command -v tar >/dev/null 2>&1; then
            tar -xzf "$file" -C "$output_dir"
        else
            echo -e "${RED}错误: 需要 tar 来解压文件${NC}"
            exit 1
        fi
    else
        echo -e "${RED}错误: 不支持的文件格式${NC}"
        exit 1
    fi
}

# 主函数
main() {
    echo -e "${GREEN}开始下载 Xray 二进制文件...${NC}"
    
    # 获取最新版本
    echo -e "${YELLOW}正在获取最新版本...${NC}"
    local version=$(get_latest_version)
    echo -e "${GREEN}最新版本: $version${NC}"
    
    # 获取系统信息
    local system_info=$(get_system_info)
    echo -e "${GREEN}系统信息: $system_info${NC}"
    
    # 构建下载 URL
    local filename="Xray-${system_info}.zip"
    local download_url="https://github.com/XTLS/Xray-core/releases/download/${version}/${filename}"
    
    # 创建目录
    local bin_dir="./bin"
    local temp_dir="./temp"
    mkdir -p "$bin_dir" "$temp_dir"
    
    # 下载文件
    local temp_file="$temp_dir/$filename"
    download_file "$download_url" "$temp_file"
    
    # 解压文件
    extract_file "$temp_file" "$temp_dir"
    
    # 移动二进制文件
    local xray_binary="$temp_dir/xray"
    if [[ -f "$xray_binary" ]]; then
        mv "$xray_binary" "$bin_dir/"
        chmod +x "$bin_dir/xray"
        echo -e "${GREEN}成功安装 Xray 到 $bin_dir/xray${NC}"
    else
        echo -e "${RED}错误: 未找到 xray 二进制文件${NC}"
        exit 1
    fi
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}下载完成！${NC}"
}

# 运行主函数
main "$@"
