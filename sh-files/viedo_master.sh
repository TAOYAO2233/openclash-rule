#!/bin/bash

# ==============================================================================
# 脚本名称: Video Master Tool v5.0 (Smart Path Memory)
# 更新亮点: 
#   1. 输入路径时自动填充当前路径，支持直接编辑修改，无需重打。
#   2. 修复了空路径回退逻辑。
# ==============================================================================

# --- 全局变量 ---
TARGET_EXT="flv"             
LIST_FILE="concat_list.txt"  
CURRENT_WORK_DIR=""          

# --- 基础工具函数 ---

check_dependency() {
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "\033[31m[Critical Error] 未检测到 FFmpeg。请先安装。\033[0m"
        exit 1
    fi
}

# --- 核心升级: 带记忆功能的路径设置 ---
init_workspace() {
    clear
    echo "=========================================="
    echo "      Video Master - 路径设置             "
    echo "=========================================="
    
    # 获取当前 Shell 上下文中的目录
    # 如果是第一次运行，它是脚本所在目录；如果是切换，它是上一次的目录
    current_default=$(pwd)
    
    echo "请输入/修改视频所在的文件夹路径:"
    echo -e "\033[36m[提示] 路径已为您预填，可直接编辑或按回车确认。\033[0m"
    echo "------------------------------------------"
    
    # --- 关键修改: 使用 -e -i 实现预填充 ---
    # 这会在提示符后直接显示当前路径，并允许您修改它
    read -e -i "$current_default" -p "路径 > " user_path

    # 容错：如果用户不小心清空了整行并回车，仍然默认为当前目录
    if [ -z "$user_path" ]; then
        user_path="$current_default"
    fi

    # 校验逻辑
    if [ ! -d "$user_path" ]; then
        echo -e "\033[31m[Error] 路径不存在: $user_path\033[0m"
        echo "请检查拼写是否正确。"
        read -p "按回车重试..."
        init_workspace # 递归调用重试
        return
    fi

    # 切换目录
    cd "$user_path" || { echo "无法进入目录"; exit 1; }
    
    # 更新全局变量
    CURRENT_WORK_DIR=$(pwd)
    echo -e "\033[32m[Success] 工作目录已锁定: $CURRENT_WORK_DIR\033[0m"
    sleep 0.5
}

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

parse_selection() {
    selected_indices=()
    for part in $1; do
        if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
            start=${part%-*}
            end=${part#*-}
            for ((i=start; i<=end; i++)); do selected_indices+=("$i"); done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            if [ "$part" -ne 0 ]; then selected_indices+=("$part"); fi
        fi
    done
}

# --- 业务功能 ---

task_concat() {
    print_file_list || return
    echo -e "\033[36m[模式 1] 拼接视频\033[0m"
    read -p "请输入文件编号 (输入 0 或回车返回菜单): " selection

    if [ -z "$selection" ] || [ "$selection" == "0" ]; then return; fi

    parse_selection "$selection"
    if [ ${#selected_indices[@]} -lt 2 ]; then 
        echo "[Info] 选择文件不足。"
        read -p "按回车继续..." 
        return
    fi

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

    date_str=$(echo "$first_file" | grep -oE '[0-9]{4}[-_.]?[0-9]{2}[-_.]?[0-9]{2}' | head -n 1)
    [ -z "$date_str" ] && date_str="Merged_$(date +%Y%m%d)"
    output_name="${date_str}_merged.${TARGET_EXT}"

    echo "[Info] 正在拼接..."
    ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -c copy "$output_name"
    
    [ $? -eq 0 ] && rm "$LIST_FILE" && echo -e "\033[32m[OK] 保存为: $output_name\033[0m"
    read -p "按回车返回菜单..."
}

task_convert() {
    print_file_list || return
    echo -e "\033[36m[模式 2] 转 MP4 (+faststart)\033[0m"
    read -p "请输入文件编号 (输入 0 或回车返回菜单): " selection

    if [ -z "$selection" ] || [ "$selection" == "0" ]; then return; fi

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
    read -p "按回车返回菜单..."
}

task_delete() {
    print_file_list || return
    echo -e "\033[31m[模式 3] 删除文件\033[0m"
    read -p "请输入编号 (输入 0 或回车返回菜单): " selection
    
    if [ -z "$selection" ] || [ "$selection" == "0" ]; then return; fi

    parse_selection "$selection"
    if [ ${#selected_indices[@]} -eq 0 ]; then return; fi

    del_list=()
    for idx in "${selected_indices[@]}"; do
        real_idx=$((idx-1))
        f="${files[$real_idx]}"
        [ -n "$f" ] && del_list+=("$f")
    done

    echo "----------------------------------------"
    echo "即将删除 ${#del_list[@]} 个文件："
    for f in "${del_list[@]}"; do echo " - $f"; done
    echo "----------------------------------------"

    read -p "输入 'yes' 确认删除: " confirm
    if [ "$confirm" == "yes" ]; then
        for f in "${del_list[@]}"; do rm "$f"; echo "[Deleted] $f"; done
    fi
    read -p "按回车返回菜单..."
}

# --- 主程序入口 ---
check_dependency
init_workspace

while true; do
    clear
    echo "=========================================="
    echo "      Video Master v5.0 (Smart Path)      "
    echo "=========================================="
    echo " 当前目录: $CURRENT_WORK_DIR"
    echo "------------------------------------------"
    echo " 1. 拼接视频 (Concat ${TARGET_EXT})"
    echo " 2. 转换 MP4 (Web Optimized)"
    echo " 3. 删除文件 (Delete)"
    echo " 4. 切换目录 (当前已记忆)"
    echo " 5. 退出 (Exit)"
    echo "=========================================="
    read -p "选择: " opt
    case $opt in
        1) task_concat ;;
        2) task_convert ;;
        3) task_delete ;;
        4) init_workspace ;; 
        5) echo "Bye!"; exit 0 ;;
        *) ;;
    esac
done