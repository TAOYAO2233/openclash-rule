#!/bin/bash

# ==============================================================================
# 脚本名称: Video Master Tool v3.0 (Path Aware Edition)
# 功能列表:
#   0. 指定工作目录 (新增)
#   1. 无损拼接 (Stream Copy)
#   2. MP4 封装转换 (Web Optimized)
#   3. 选择性删除
# ==============================================================================

# --- 全局变量 ---
TARGET_EXT="flv"             # 默认处理的文件扩展名
LIST_FILE="concat_list.txt"  # 临时列表文件名
CURRENT_WORK_DIR=""          # 当前工作目录变量

# --- 基础工具函数 ---

check_dependency() {
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "\033[31m[Critical Error] 未检测到 FFmpeg。请先安装。\033[0m"
        exit 1
    fi
}

# --- 新增核心函数: 初始化工作目录 ---
init_workspace() {
    clear
    echo "=========================================="
    echo "      Video Master - 初始化设置           "
    echo "=========================================="
    echo "请输入视频所在的文件夹路径 (绝对路径):"
    echo "例如: /home/user/downloads/videos"
    echo -e "\033[36m[提示] 直接按回车 (Enter) 将使用当前目录\033[0m"
    echo "------------------------------------------"
    
    read -p "路径 > " user_path

    # 1. 处理空输入：默认为当前目录
    if [ -z "$user_path" ]; then
        user_path=$(pwd)
    fi

    # 2. 路径校验逻辑
    if [ ! -d "$user_path" ]; then
        echo -e "\033[31m[Error] 路径不存在或不是一个目录: $user_path\033[0m"
        echo "脚本即将退出..."
        exit 1
    fi

    # 3. 切换工作目录 (Context Switch)
    cd "$user_path" || { echo "无法进入目录"; exit 1; }
    
    # 更新全局变量以便显示
    CURRENT_WORK_DIR=$(pwd)
    echo -e "\033[32m[Success] 已锁定工作目录: $CURRENT_WORK_DIR\033[0m"
    sleep 1
}

# 打印文件列表 (基于当前工作目录)
print_file_list() {
    files=()
    shopt -s nullglob
    for f in *."$TARGET_EXT"; do files+=("$f"); done
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        echo -e "\033[33m[Warning] 在 $CURRENT_WORK_DIR 未找到 .$TARGET_EXT 文件。\033[0m"
        return 1
    fi

    echo "------------------------------------------------"
    echo "   目录: $CURRENT_WORK_DIR"
    echo "   文件列表 (按名称排序)"
    echo "------------------------------------------------"
    local idx=1
    for f in "${files[@]}"; do
        size=$(du -h "$f" | cut -f1)
        printf "[%2d] %s \t(%s)\n" "$idx" "$f" "$size"
        ((idx++))
    done
    echo "------------------------------------------------"
    return 0
}

# 解析用户选择
parse_selection() {
    selected_indices=()
    for part in $1; do
        if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
            start=${part%-*}
            end=${part#*-}
            for ((i=start; i<=end; i++)); do selected_indices+=("$i"); done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            selected_indices+=("$part")
        fi
    done
}

# --- 业务功能模块 ---

# 1. 拼接
task_concat() {
    print_file_list || return
    echo -e "\033[36m[模式 1] 拼接视频 (Stream Copy)\033[0m"
    read -p "请输入文件编号 (如 1 2 3): " selection
    parse_selection "$selection"

    if [ ${#selected_indices[@]} -lt 2 ]; then echo "[Info] 需至少2个文件"; return; fi

    > "$LIST_FILE"
    count=0
    first_file=""

    for idx in "${selected_indices[@]}"; do
        real_idx=$((idx-1))
        file="${files[$real_idx]}"
        if [ -n "$file" ]; then
            echo "file '$PWD/$file'" >> "$LIST_FILE"
            if [ $count -eq 0 ]; then first_file="$file"; fi
            ((count++))
        fi
    done

    # 日期提取算法
    date_str=$(echo "$first_file" | grep -oE '[0-9]{4}[-_.]?[0-9]{2}[-_.]?[0-9]{2}' | head -n 1)
    [ -z "$date_str" ] && date_str="Merged_$(date +%Y%m%d)"
    output_name="${date_str}_merged.${TARGET_EXT}"

    echo "[Info] 正在拼接..."
    ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -c copy "$output_name"
    
    [ $? -eq 0 ] && rm "$LIST_FILE" && echo -e "\033[32m[OK] 保存为: $output_name\033[0m"
    read -p "按回车继续..."
}

# 2. 转换 MP4
task_convert() {
    print_file_list || return
    echo -e "\033[36m[模式 2] 转 MP4 (+faststart Web优化)\033[0m"
    read -p "请输入文件编号: " selection
    parse_selection "$selection"

    if [ ${#selected_indices[@]} -eq 0 ]; then return; fi

    for idx in "${selected_indices[@]}"; do
        real_idx=$((idx-1))
        file="${files[$real_idx]}"
        if [ -n "$file" ]; then
            base_name="${file%.*}"
            output_name="${base_name}.mp4"
            echo "正在转换: $file -> $output_name"
            ffmpeg -y -i "$file" -c copy -movflags +faststart "$output_name" < /dev/null
        fi
    done
    echo -e "\033[32m[OK] 转换结束\033[0m"
    read -p "按回车继续..."
}

# 3. 删除
task_delete() {
    print_file_list || return
    echo -e "\033[31m[模式 3] 删除文件 (不可恢复)\033[0m"
    read -p "请输入编号: " selection
    parse_selection "$selection"
    
    if [ ${#selected_indices[@]} -eq 0 ]; then return; fi

    del_list=()
    for idx in "${selected_indices[@]}"; do
        real_idx=$((idx-1))
        f="${files[$real_idx]}"
        [ -n "$f" ] && del_list+=("$f")
    done

    echo "将删除 ${#del_list[@]} 个文件。"
    read -p "确认? (yes): " confirm
    if [ "$confirm" == "yes" ]; then
        for f in "${del_list[@]}"; do rm "$f"; echo "[Deleted] $f"; done
    fi
    read -p "按回车继续..."
}

# --- 主程序入口 ---
check_dependency

# [核心步骤] 在进入主循环前，先设定工作目录
init_workspace

while true; do
    clear
    echo "=========================================="
    echo "      Video Master v3.0 (Path Aware)      "
    echo "=========================================="
    echo " 当前目录: $CURRENT_WORK_DIR"
    echo "------------------------------------------"
    echo " 1. 拼接视频 (Concat ${TARGET_EXT})"
    echo " 2. 转换 MP4 (Web Optimized)"
    echo " 3. 删除文件 (Delete)"
    echo " 4. 切换目录 (Change Dir)"
    echo " 5. 退出 (Exit)"
    echo "=========================================="
    read -p "选择: " opt
    case $opt in
        1) task_concat ;;
        2) task_convert ;;
        3) task_delete ;;
        4) init_workspace ;; # 允许中途切换目录
        5) exit 0 ;;
        *) ;;
    esac
done