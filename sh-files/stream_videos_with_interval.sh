#!/bin/bash

# ================= 配置区域 =================
CONFIG_FILE="$HOME/.stream_config"
FILES_PER_PAGE=10
LOG_DIR="/var/log/stream_logs/"
# 确保日志文件名合法，避免空格
LOG_FILE="${LOG_DIR}stream_log_$(date +'%Y%m%d_%H%M%S').log"
INTERVAL=10
LOOP=false
# ===========================================

# 支持的视频文件扩展名说明
declare -A FILE_TYPES
FILE_TYPES=(
  [mp4]="MP4 - 通用格式"
  [avi]="AVI - 老旧格式"
  [mkv]="MKV - 多轨道封装"
  [mov]="MOV - Apple格式"
  [flv]="FLV - 流媒体格式"
  [wmv]="WMV - 微软格式"
  [webm]="WebM - Web格式"
)

RTMP_URL=""
VIDEO_DIR=""

# 创建日志目录
mkdir -p "$LOG_DIR"

# 获取配置值的函数
get_config_value() {
  local key="$1"
  if [ -f "$CONFIG_FILE" ]; then
    grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2
  fi
}

# 设置配置值的函数
set_config_value() {
  local key="$1"
  local value="$2"
  if grep -q "^$key=" "$CONFIG_FILE"; then
    sed -i "s|^$key=.*|$key=$value|" "$CONFIG_FILE"
  else
    echo "$key=$value" >> "$CONFIG_FILE"
  fi
}

# 初始化配置
initialize_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "配置文件不存在，正在初始化..."
    read -rp "请输入 RTMP 服务器地址 (格式: rtmp://server/live/stream-key): " RTMP_URL
    echo "RTMP_URL=$RTMP_URL" > "$CONFIG_FILE"
    read -rp "请输入视频文件目录: " VIDEO_DIR
    echo "VIDEO_DIR=$VIDEO_DIR" >> "$CONFIG_FILE"
  fi
}

# 加载配置
load_config() {
  RTMP_URL=$(get_config_value "RTMP_URL")
  VIDEO_DIR=$(get_config_value "VIDEO_DIR")
}

# 显示当前配置
display_and_ask_update() {
  echo "========================================"
  echo "当前推流地址: $RTMP_URL"
  echo "视频源目录:   $VIDEO_DIR"
  echo "========================================"
  read -rp "是否修改配置？(y/n) [默认n]: " update_choice
  if [[ $update_choice =~ ^[yY]$ ]]; then
    read -rp "请输入新的完整 RTMP 地址: " new_url
    [ -n "$new_url" ] && set_config_value "RTMP_URL" "$new_url"
    
    read -rp "请输入新的视频目录: " new_dir
    [ -n "$new_dir" ] && set_config_value "VIDEO_DIR" "$new_dir"
    
    load_config
  fi
}

# 【优化】获取视频文件 - 失败时返回 1 而不是 exit
get_video_files() {
  local selected_ext="$1"
  # 检查目录是否存在
  if [ ! -d "$VIDEO_DIR" ]; then
      echo "错误：目录 $VIDEO_DIR 不存在！"
      return 1
  fi

  echo "正在扫描文件，请稍候..."
  if [[ "$selected_ext" == "all" ]]; then
    mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.flv" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" -o -name "*.wmv" -o -name "*.webm" \) | sort)
  else
    mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -type f -name "*.$selected_ext" | sort)
  fi
  
  if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
      return 1 # 没找到文件，返回错误代码，由主循环处理
  fi
}

# 文件类型选择
select_file_type() {
  echo "----------------------------------------"
  echo "选择要扫描的文件类型："
  local index=1
  local ext_keys=("${!FILE_TYPES[@]}") # 获取所有键
  
  for ext in "${ext_keys[@]}"; do
    echo "$index) $ext (${FILE_TYPES[$ext]})"
    ((index++))
  done
  echo "$index) 全部类型"
  
  read -rp "请输入选项数字 [默认全部]: " choice
  if [[ -z $choice || $choice -eq $index ]]; then
      get_video_files "all"
  elif [[ $choice =~ ^[0-9]+$ ]] && (( choice > 0 && choice < index )); then
      local selected_ext="${ext_keys[$((choice-1))]}"
      get_video_files "$selected_ext"
  else
      get_video_files "all"
  fi
}

# 【优化】扫描循环逻辑 - 没找到文件时允许重试
scan_files_loop() {
  while true; do
    select_file_type
    
    # 检查是否找到了文件
    if [ ${#VIDEO_FILES[@]} -gt 0 ]; then
      echo "成功找到 ${#VIDEO_FILES[@]} 个视频文件。"
      break
    else
      echo "----------------------------------------"
      echo "警告：在目录 [$VIDEO_DIR] 中未找到任何视频文件！"
      echo "请选择下一步操作："
      echo "r) 重新选择文件类型 (Retry)"
      echo "c) 修改视频目录路径 (Change Directory)"
      echo "q) 退出脚本 (Quit)"
      read -rp "请输入选项 [默认r]: " retry_opt
      
      case $retry_opt in
        c|C)
           read -rp "请输入新的视频目录: " new_dir
           if [ -n "$new_dir" ]; then
               set_config_value "VIDEO_DIR" "$new_dir"
               load_config
               echo "目录已更新，准备重新扫描..."
           fi
           ;;
        q|Q)
           echo "已退出。"
           exit 0
           ;;
        *)
           echo "准备重新扫描..."
           ;;
      esac
    fi
    echo "----------------------------------------"
  done
}

# 显示列表并选择
list_and_select_videos() {
  local page=1
  local total_pages
  local num_files=${#VIDEO_FILES[@]}
  
  while true; do
    total_pages=$(( (num_files + FILES_PER_PAGE - 1) / FILES_PER_PAGE ))
    clear
    echo "=== 视频文件列表 (页码: $page / $total_pages | 总数: $num_files) ==="
    
    local start=$(( (page - 1) * FILES_PER_PAGE ))
    local end=$(( start + FILES_PER_PAGE - 1 ))
    [ $end -ge $num_files ] && end=$(( num_files - 1 ))

    for i in $(seq "$start" "$end"); do
      filename=$(basename "${VIDEO_FILES[$i]}")
      echo "$((i + 1))) $filename"
    done
    
    echo "----------------------------------------"
    echo "操作指令："
    echo "[n] 下一页  [p] 上一页  [a] 全选所有"
    echo "[数字] 选择特定文件 (例如: 1,3,5-7)"
    echo "[q] 退出"
    echo "----------------------------------------"
    
    read -rp "请输入指令: " input
    
    case $input in
      q|Q) exit 0 ;;
      a|A) 
        SELECTED_FILES=("${VIDEO_FILES[@]}")
        break 
        ;;
      n|N) 
        if (( page < total_pages )); then ((page++)); fi 
        ;;
      p|P) 
        if (( page > 1 )); then ((page--)); fi 
        ;;
      *)
        if [[ "$input" =~ ^[0-9,\-]+$ ]]; then
            IFS=',' read -r -a inputs <<< "$input"
            SELECTED_FILES=()
            for item in "${inputs[@]}"; do
                if [[ $item =~ ([0-9]+)-([0-9]+) ]]; then
                    for ((j=${BASH_REMATCH[1]}; j<=${BASH_REMATCH[2]}; j++)); do
                        idx=$((j-1))
                        if (( idx >= 0 && idx < num_files )); then
                            SELECTED_FILES+=("${VIDEO_FILES[$idx]}")
                        fi
                    done
                else
                    idx=$((item-1))
                    if (( idx >= 0 && idx < num_files )); then
                        SELECTED_FILES+=("${VIDEO_FILES[$idx]}")
                    fi
                fi
            done
            
            if [ ${#SELECTED_FILES[@]} -gt 0 ]; then
                break
            else
                read -rp "输入无效或未选中文件，按回车继续..." 
            fi
        fi
        ;;
    esac
  done
}

# 询问循环
ask_loop() {
  read -rp "是否循环推流？(y/n) [默认n]: " loop_choice
  [[ $loop_choice =~ ^[yY]$ ]] && LOOP=true
}

# 推流主逻辑
stream_videos() {
  local total_files=${#SELECTED_FILES[@]}
  if [[ $total_files -eq 0 ]]; then
    # 这里其实理论上不会走到，因为 list_and_select_videos 保证了选择
    echo "未选择文件，退出。"
    exit 1
  fi
  
  echo "----------------------------------------"
  echo "推流模式选择："
  echo "1) 快速模式 (-c copy) : CPU占用低，要求源文件为 h264/aac"
  echo "2) 兼容模式 (-c:v libx264...) : CPU占用高，兼容所有格式"
  read -rp "请选择 [默认1]: " stream_mode
  
  local ffmpeg_opts="-c copy"
  if [[ "$stream_mode" == "2" ]]; then
      ffmpeg_opts="-c:v libx264 -preset veryfast -b:v 3000k -maxrate 3000k -bufsize 6000k -c:a aac -b:a 128k -ar 44100"
  fi

  while true; do
    local current_index=1
    for video in "${SELECTED_FILES[@]}"; do
      echo "正在分析文件时长..."
      local duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nk=1:nw=1 "$video" | awk '{printf "%d", $1}')
      [ -z "$duration" ] && duration=0
      local duration_fmt=$(printf '%02d:%02d:%02d' $((duration/3600)) $(((duration%3600)/60)) $((duration%60)))
      
      echo -e "\n=== 开始推流 ($current_index/$total_files) ==="
      echo "文件: $(basename "$video")"
      echo "时长: $duration_fmt"
      echo "模式: $ffmpeg_opts"
      
      local progress_file=$(mktemp)
      ffmpeg -re -i "$video" $ffmpeg_opts -f flv "$RTMP_URL" -progress "$progress_file" >> "$LOG_FILE" 2>&1 &
      local pid=$!
      
      while kill -0 $pid 2>/dev/null; do
        if [[ -f $progress_file ]]; then
          local ms=$(grep -a "out_time_ms=" "$progress_file" | tail -n 1 | cut -d= -f2)
          if [[ "$ms" =~ ^[0-9]+$ ]]; then
             local sec=$((ms / 1000000))
             local pct=0
             [ $duration -gt 0 ] && pct=$((sec * 100 / duration))
             local elap_fmt=$(printf '%02d:%02d:%02d' $((sec/3600)) $(((sec%3600)/60)) $((sec%60)))
             echo -ne "\r>> 进度: $elap_fmt / $duration_fmt ($pct%)  "
          fi
        fi
        sleep 1
      done
      
      rm -f "$progress_file"
      echo -e "\n完成."
      sleep "$INTERVAL"
      ((current_index++))
    done
    
    if [[ $LOOP == false ]]; then break; fi
    echo "=== 列表播放结束，正在重新开始循环 ==="
    sleep 2
  done
}

# 执行流程
initialize_config
load_config
display_and_ask_update

# 【修改】调用新的扫描循环
scan_files_loop 

list_and_select_videos
ask_loop
stream_videos