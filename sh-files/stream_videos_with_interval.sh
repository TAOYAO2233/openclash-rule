#!/bin/bash

# 配置文件路径
CONFIG_FILE="$HOME/.stream_config"
FILES_PER_PAGE=10 # 每页显示的文件数量
LOG_DIR="/var/log/stream_logs/"
LOG_FILE="${LOG_DIR}stream_log_$(date +'%Y%m%d_%H%M%S').log"
INTERVAL=10 # 推流间隔，秒
LOOP=false # 是否循环推流

# 支持的视频文件扩展名及说明
declare -A FILE_TYPES
FILE_TYPES=(
  [mp4]="MP4 (.mp4) - 通用格式，支持高质量的视频和音频，广泛用于流媒体和下载。"
  [avi]="AVI (.avi) - 一种较旧的格式，支持高质量视频，但文件通常较大。"
  [mkv]="MKV (.mkv) - 高度灵活的格式，支持多种音频和字幕轨道，常用于存储高质量的视频内容。"
  [mov]="MOV (.mov) - 苹果公司开发的格式，通常用于高质量视频，广泛用于视频编辑。"
  [flv]="FLV (.flv) - 用于流媒体视频的格式，曾经在Flash视频中非常流行。"
  [wmv]="WMV (.wmv) - 微软开发的视频格式，通常用于Windows平台。"
  [webm]="WebM (.webm) - 开放格式，专为Web视频流媒体设计，支持现代浏览器。"
)

# RTMP 服务器地址和流密钥
RTMP_URL=""

# 视频文件目录
VIDEO_DIR=""

# 创建日志目录（如果不存在）
mkdir -p "$LOG_DIR"

# 获取配置值的函数
get_config_value() {
  local key="$1"
  grep "^$key=" "$CONFIG_FILE" | cut -d'=' -f2
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

# 初始化配置文件（如果不存在）
initialize_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "配置文件不存在，正在初始化..."
    read -rp "请输入 RTMP 服务器地址和流密钥 (格式: rtmp://server/live/stream-key): " RTMP_URL
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

# 显示当前配置并询问是否更新
display_and_ask_update() {
  local base_url stream_key formatted_key
  read -r base_url stream_key <<< "$(parse_rtmp_url "$RTMP_URL")"
  formatted_key=$(format_stream_key "$stream_key")
  echo "*** 当前配置 ***"
  echo "RTMP 服务器地址: $base_url"
  echo "流密钥: $formatted_key"
  echo "视频文件目录: $VIDEO_DIR"
  read -rp "是否要更新配置？(y/n): " update_choice
  if [[ $update_choice =~ ^[yY]$ ]]; then
    read -rp "请输入新的 RTMP 服务器地址: " new_base_url
    read -rp "请输入新的流密钥: " new_stream_key
    set_config_value "RTMP_URL" "$new_base_url/$new_stream_key"
    
    read -rp "请输入新的视频文件目录: " new_video_dir
    set_config_value "VIDEO_DIR" "$new_video_dir"
    
    load_config
  fi
}

# 分割 RTMP 地址和流密钥
parse_rtmp_url() {
  local url="$1"
  local base_url=$(echo "$url" | sed 's:/[^/]*$::')
  local stream_key=$(echo "$url" | awk -F'/' '{print $NF}')
  echo "$base_url"
  echo "$stream_key"
}

# 不再隐藏流密钥，直接返回
format_stream_key() {
  local stream_key="$1"
  echo "$stream_key"
}

# 获取视频文件
get_video_files() {
  local selected_ext="$1"
  local ext_pattern="*.$selected_ext"
  if [[ "$selected_ext" == "all" ]]; then
    ext_pattern="*.{mp4,flv,mkv,avi,mov,wmv,webm}"
  fi

  mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.flv" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" -o -name "*.wmv" -o -name "*.webm" \))
}

# 文件类型选择
select_file_type() {
  echo "选择要推流的文件类型："
  local index=1
  for ext in "${!FILE_TYPES[@]}"; do
    echo "$index) ${FILE_TYPES[$ext]}"
    ((index++))
  done
  echo "$index) 全部选择"
  
  while true; do
    read -rp "请选择文件类型（输入数字，回车默认全部选择）: " choice
    if [[ -z $choice ]]; then
      # 没有输入，默认选择全部
      get_video_files "all"
      break
    elif [[ $choice =~ ^[0-9]+$ ]]; then
      if (( choice == index )); then
        get_video_files "all"
        break
      elif (( choice > 0 && choice < index )); then
        local selected_ext=$(printf '%s\n' "${!FILE_TYPES[@]}" | sed -n "${choice}p")
        get_video_files "$selected_ext"
        break
      else
        echo "无效选择，请重新选择。"
      fi
    else
      echo "无效选择，请重新选择。"
    fi
  done
}

# 获取视频文件信息并缓存
cache_video_info() {
  video_info=()
  for file in "${VIDEO_FILES[@]}"; do
    size=$(du -h "$file" | cut -f1)
    duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nk=1:nw=1 "$file" | awk '{printf "%d", $1}')
    video_info+=("$file (大小: $size, 时长: ${duration}s)")
  done
}

# 显示视频文件列表并获取用户输入
list_and_select_videos() {
  local page=1
  local total_pages
  local num_files=${#VIDEO_FILES[@]}
  total_pages=$(( (num_files + FILES_PER_PAGE - 1) / FILES_PER_PAGE ))

  while true; do
    clear
    echo "可用的视频文件（第 $page 页，共 $total_pages 页）："

    local start=$(( (page - 1) * FILES_PER_PAGE ))
    local end=$(( start + FILES_PER_PAGE - 1 ))
    end=$(( end < num_files ? end : num_files - 1 ))

    for i in $(seq "$start" "$end"); do
      echo "$((i + 1))) ${video_info[$i]}"
    done
    
    echo "a) 选择所有视频"
    echo "↑/↓) 上一页/下一页"
    echo "q) 退出"
    
    # 新增输入提示
    echo "输入视频文件编号（多个用逗号分隔），按回车确认，或按上下箭头键选择页面："
	
    # 读取单个字符输入
    read -s -n 1 key

    case $key in
      q)
        echo "退出程序。"
        exit 0
        ;;
      a)
        SELECTED_FILES=("${VIDEO_FILES[@]}")
        break
        ;;
      A) # 上一页（↑ 键）
        if (( page > 1 )); then
          ((page--))
        fi
        ;;
      B) # 下一页（↓ 键）
        if (( page < total_pages )); then
          ((page++))
        fi
        ;;
      [0-9])
        # 获取数字并允许用户输入多选，例如：1,3,5
        read -p "$key" -e user_input
        IFS=',' read -r -a indices <<< "$key$user_input"
        SELECTED_FILES=()
        for index in "${indices[@]}"; do
          index=$((index - 1))
          if ((index >= 0 && index < ${#VIDEO_FILES[@]})); then
            SELECTED_FILES+=("${VIDEO_FILES[$index]}")
          else
            echo "无效的文件编号: $((index + 1))"
          fi
        done
        if [[ ${#SELECTED_FILES[@]} -eq 0 ]]; then
          echo "没有选择任何有效的视频文件。"
          continue
        fi
        break
        ;;
    esac
  done

  # 自定义排序部分保持不变
  if [[ ${#SELECTED_FILES[@]} -gt 1 ]]; then
    read -rp "是否自定义排序？(y/n): " sort_choice
    if [[ $sort_choice =~ ^[yY]$ ]]; then
      echo "请输入自定义排序的文件编号，用逗号分隔："
      read -rp "输入文件编号（例如：1,3,2）： " custom_sort
      IFS=',' read -r -a sorted_indices <<< "$custom_sort"
      SELECTED_FILES=()
      for index in "${sorted_indices[@]}"; do
        index=$((index - 1))
        if ((index >= 0 && index < ${#VIDEO_FILES[@]})); then
          SELECTED_FILES+=("${VIDEO_FILES[$index]}")
        else
          echo "无效的文件编号: $((index + 1))"
        fi
      done
    fi
  fi
}


# 询问是否循环推流
ask_loop() {
  read -rp "是否要循环推流？(y/n): " loop_choice
  if [[ $loop_choice =~ ^[yY]$ ]]; then
    LOOP=true
  fi
}

# 推流视频函数
stream_videos() {
  local file_index=1
  local total_files=${#SELECTED_FILES[@]}
  if [[ $total_files -eq 0 ]]; then
    echo "没有选择任何视频文件，退出程序。" | tee -a "$LOG_FILE"
    exit 1
  fi

  while [[ $LOOP == true || $file_index -le $total_files ]]; do
    for video in "${SELECTED_FILES[@]}"; do
      local duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nk=1:nw=1 "$video" | awk '{printf "%d", $1}')
      local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $(((duration%3600)/60)) $((duration%60)))
      
      echo "开始推流视频: $video (进度: $file_index/$total_files, 时长: $duration_formatted)" | tee -a "$LOG_FILE"
      
      # 创建一个临时文件用于存储进度信息
      local progress_file=$(mktemp)
      
      # 推流并输出进度到临时文件
      ffmpeg -re -i "$video" -c copy -f flv "$RTMP_URL" -progress "$progress_file" 2>> "$LOG_FILE" &
      
      # 获取进程ID
      local ffmpeg_pid=$!
      
      # 实时读取并显示进度
      while kill -0 $ffmpeg_pid 2>/dev/null; do
        if [[ -f $progress_file ]]; then
          local progress=$(grep -E '^out_time_ms=' "$progress_file" | tail -1)
          if [[ -n $progress ]]; then
            local out_time_ms=$(echo "$progress" | cut -d'=' -f2)
            local out_time_sec=$((out_time_ms / 1000000))
            local elapsed_formatted=$(printf '%02d:%02d:%02d' $((out_time_sec/3600)) $(((out_time_sec%3600)/60)) $((out_time_sec%60)))
            local remaining_sec=$((duration - out_time_sec))
            local remaining_formatted=$(printf '%02d:%02d:%02d' $((remaining_sec/3600)) $(((remaining_sec%3600)/60)) $((remaining_sec%60)))
            echo -ne "\r推流进度: $elapsed_formatted / $duration_formatted (剩余: $remaining_formatted)"
          fi
        fi
        sleep 1
      done
      
      # 删除临时文件
      rm -f "$progress_file"
      
      echo "" # 换行
      echo "完成推流视频: $video (进度: $file_index/$total_files)" | tee -a "$LOG_FILE"
      sleep "$INTERVAL"
      ((file_index++))
    done
    if [[ $LOOP == false ]]; then
      break
    fi
  done
}



# 主程序部分调用缓存函数
initialize_config
load_config
display_and_ask_update
select_file_type
cache_video_info  # 添加此步骤来缓存视频信息
list_and_select_videos
ask_loop
stream_videos