#!/bin/bash

# 配置文件路径
CONFIG_DIR="/home/tdl"
CHAT_LIST_FILE="${CONFIG_DIR}/chat_list.txt"
HASH_FILE="${CONFIG_DIR}/chat_list_hash.txt"
OUTPUT_DIR="${CONFIG_DIR}/exports"

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
NC='\033[35m' # 无颜色

# 初始化环境
initialize() {
    mkdir -p "$OUTPUT_DIR"
    touch "$CHAT_LIST_FILE" "$HASH_FILE"
}

# 生成聊天列表
update_chat_list() {
    echo -e "${YELLOW}正在生成聊天列表...${NC}"
    if ! tdl chat ls > "$CHAT_LIST_FILE"; then
        echo -e "${RED}错误：无法生成聊天列表，请检查tdl配置${NC}" >&2
        exit 1
    fi
    
    if [ ! -s "$CHAT_LIST_FILE" ]; then
        echo -e "${RED}错误：生成的聊天列表为空，请检查：\n1. tdl权限\n2. 账户是否加入频道${NC}" >&2
        exit 1
    fi
    
    new_hash=$(md5sum "$CHAT_LIST_FILE" | awk '{print $1}')
    echo "$new_hash" > "$HASH_FILE"
    echo -e "${GREEN}聊天列表已更新${NC}"
}

# 验证聊天列表
verify_chat_list() {
    [ ! -f "$CHAT_LIST_FILE" ] && update_chat_list
    [ ! -s "$CHAT_LIST_FILE" ] && update_chat_list
    
    current_hash=$(md5sum "$CHAT_LIST_FILE" | awk '{print $1}')
    if [ "$(cat "$HASH_FILE" 2>/dev/null)" != "$current_hash" ]; then
        echo -e "${YELLOW}检测到聊天列表变化${NC}"
        update_chat_list
    fi
}

# 读取时间戳（增加时区处理）
read_timestamp() {
    while true; do
        read -p "$1" input
        if timestamp=$(TZ=UTC date -d "$input" +%s 2>/dev/null); then
            echo "$timestamp"
            return
        else
            echo -e "${RED}无效时间格式，请使用YYYY-MM-DD HH:MM:SS格式${NC}"
        fi
    done
}

# 增强版频道选择
select_channel() {
    mapfile -t channels < "$CHAT_LIST_FILE"
    declare -A id_map
    
    # 构建ID映射表
    for i in "${!channels[@]}"; do
        id=$(awk '{print $1}' <<< "${channels[$i]}")
        id_map["$id"]="$i"
    done

    # 显示列表（强制先显示）
    echo -e "\n${CYAN}可用聊天列表：${NC}"
    printf "%4s | %-16s | %s\n" "序号" "频道ID" "频道名称"
    printf "%s\n" "--------------------------------------------------------"
    for i in "${!channels[@]}"; do
        id=$(awk '{print $1}' <<< "${channels[$i]}")
        name=$(cut -d' ' -f2- <<< "${channels[$i]}" | sed 's/\[\w\+\]$//')
        printf "%4d | %-16s | %s\n" $((i+1)) "$id" "$name"
    done

    # 输入处理
    while true; do
        echo -ne "\n${YELLOW}请选择输入方式：\n"
        echo -e "1. 使用序号选择 (1-${#channels[@]})"
        echo -e "2. 直接输入频道ID"
        read -p "请输入选项 [1/2]: " method

        case $method in
            1)
                while true; do
                    read -p "请输入列表序号: " num
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#channels[@]} ]; then
                        selected_id=$(awk '{print $1}' <<< "${channels[$((num-1))]}")
                        break 2
                    else
                        echo -e "${RED}无效序号，有效范围: 1-${#channels[@]}${NC}"
                    fi
                done
                ;;
            2)
                while true; do
                    read -p "请输入频道ID: " input_id
                    if [ -n "${id_map["$input_id"]}" ]; then
                        selected_id="$input_id"
                        break 2
                    else
                        echo -e "${RED}未找到该频道ID，请检查输入${NC}"
                    fi
                done
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                ;;
        esac
    done

    echo -e "${GREEN}已选择频道ID: ${selected_id}${NC}"
    echo "$selected_id"
}

# 修复时间配置
configure_time() {
    PS3="请选择时间模式："
    options=(
        "使用默认时间范围 (2024-01-10至2024-11-30)"
        "自定义时间范围"
        "退出"
    )
    
    select opt in "${options[@]}"; do
        case $opt in
            "使用默认时间范围 (2024-01-10至2024-11-30)")
                start=$(TZ=UTC date -d "2024-01-10 20:00:00" +%s)
                end=$(TZ=UTC date -d "2024-11-30 00:00:00" +%s)
                break
                ;;
            "自定义时间范围")
                start=$(read_timestamp "请输入开始时间 (YYYY-MM-DD HH:MM:SS): ")
                end=$(read_timestamp "请输入结束时间 (YYYY-MM-DD HH:MM:SS): ")
                break
                ;;
            "退出")
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                ;;
        esac
    done

    # 增强时间验证
    if [ -z "$start" ] || [ -z "$end" ]; then
        echo -e "${RED}错误：时间参数不能为空${NC}" >&2
        exit 1
    fi

    if [ $end -le $start ]; then
        echo -e "${RED}错误：结束时间必须晚于开始时间${NC}" >&2
        exit 1
    fi
    echo "$start $end"
}

# 增强导出逻辑
perform_export() {
    local id=$1
    local start=$2
    local end=$3
    local count=$4

    # 验证时间有效性
    if [ -z "$start" ] || [ -z "$end" ] || [ $end -le $start ]; then
        echo -e "${RED}错误：无效时间范围${NC}"
        return 1
    fi

    output="${OUTPUT_DIR}/${id}_$(date -d "@$start" '+%Y%m%d')_${count}.json"
    echo -e "\n${BLUE}正在导出第${count}个时段...${NC}"
    echo -e "时间范围: $(date -d "@$start" '+%F %T') 至 $(date -d "@$end" '+%F %T')"

    if tdl chat export -c "$id" -o "$output" -i "$start,$end" --all --pool 0; then
        echo -e "${GREEN}导出成功 → ${output}${NC}"
        return 0
    else
        echo -e "${RED}导出失败，尝试缩短时间范围...${NC}"
        
        # 按天分段重试
        retry_start=$start
        retry_count=1
        success_count=0
        while [ $retry_start -lt $end ]; do
            retry_end=$((retry_start + 86400)) # 1天
            [ $retry_end -gt $end ] && retry_end=$end
            
            retry_output="${output%.*}_retry${retry_count}.json"
            if tdl chat export -c "$id" -o "$retry_output" -i "$retry_start,$retry_end"; then
                echo -e "${GREEN}分段导出成功 → ${retry_output}${NC}"
                ((success_count++))
                retry_start=$retry_end
            else
                echo -e "${RED}严重错误：无法导出该时段数据，已跳过${NC}"
                return 1
            fi
            ((retry_count++))
        done
        
        [ $success_count -gt 0 ] && return 0
        return 1
    fi
}

# 主程序
main() {
    initialize
    verify_chat_list
    
    echo -e "\n${CYAN}====== Telegram数据导出工具 ======${NC}"
    
    # 选择频道（强制先显示列表）
    channel_id=$(select_channel)
    
    # 配置时间
    read -r start_time end_time <<< $(configure_time)
    
    # 显示配置摘要
    echo -e "\n${BLUE}====== 导出配置 ======${NC}"
    echo -e "频道ID  : ${channel_id}"
    echo -e "开始时间: $(date -d "@$start_time" '+%F %T')"
    echo -e "结束时间: $(date -d "@$end_time" '+%F %T')"
    echo -e "输出目录: ${OUTPUT_DIR}"
    echo -e "${BLUE}======================${NC}"
    
    # 分时段导出
    counter=1
    current_start=$start_time
    
    while [ $current_start -lt $end_time ]; do
        # 修复时间计算逻辑
        current_end=$(date -d "@$current_start +2 months" +%s)
        current_end=$((current_end > end_time ? end_time : current_end))
        
        if ! perform_export "$channel_id" $current_start $current_end $counter; then
            echo -e "${RED}导出进程终止，请检查错误日志${NC}"
            exit 1
        fi
        
        current_start=$current_end
        ((counter++))
    done

    echo -e "\n${GREEN}====== 全部导出完成 ======${NC}"
    echo -e "输出文件保存在: ${CYAN}${OUTPUT_DIR}${NC}"
}

# 执行主程序
main