#!/bin/bash

# 配置文件路径
CONFIG_FILE="$HOME/.stream_config"
FILES_PER_PAGE=15 # 每页显示的文件数量
LOG_FILE="stream.log"
INTERVAL=10 # 推流间隔，秒
TEMP_FILE="/tmp/streaming_temp_file.tmp" # 临时文件路径

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

# 分割 RTMP 地址和流密钥
parse_rtmp_url() {
  local url="$1"
  local base_url=$(echo "$url" | sed 's:/[^/]*$::')
  local stream_key=$(echo "$url" | awk -F'/' '{print $NF}')
  echo "$base_url"
  echo "$stream_key"
}

# 格式化并隐藏流密钥中间部分
format_stream_key() {
  local stream_key="$1"
  local visible_length=6
  local hidden_length=$(( ${#stream_key} - 2 * visible_length ))
  if (( hidden_length > 0 )); then
    echo "${stream_key:0:$visible_length}***${stream_key: -$visible_length}"
  else
    echo "$stream_key"
  fi
}

# 询问用户输入并保存配置
prompt_and_save_config() {
  local prompt_message="$1"
  local key="$2"
  local current_value="$3"

  local base_url stream_key
  read -r base_url stream_key <<< "$(parse_rtmp_url "$current_value")"
  
  local formatted_key=$(format_stream_key "$stream_key")
  read -rp "$prompt_message (当前值: $base_url/$formatted_key): " new_value
  
  if [[ -n "$new_value" ]]; then
    set_config_value "$key" "$new_value"
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
  local base_url stream_key
  read -r base_url stream_key <<< "$(parse_rtmp_url "$RTMP_URL")"
  local formatted_key=$(format_stream_key "$stream_key")
  echo "*** 当前配置 ***"
  echo "RTMP 服务器地址: $base_url"
  echo "流密钥: $formatted_key"
  echo "视频文件目录: $VIDEO_DIR"
  read -rp "是否要更新配置？(y/n): " update_choice
  if [[ $update_choice =~ ^[yY]$ ]]; then
    # 分开输入 RTMP 服务器地址和流密钥
    read -rp "请输入新的 RTMP 服务器地址: " new_base_url
    read -rp "请输入新的流密钥: " new_stream_key
    set_config_value "RTMP_URL" "$new_base_url/$new_stream_key"
    
    read -rp "请输入新的视频文件目录: " new_video_dir
    set_config_value "VIDEO_DIR" "$new_video_dir"
    
    load_config
  fi
}

# 获取视频文件
get_video_files() {
  local selected_ext="$1"
  local ext_pattern="*.$selected_ext"
  if [[ "$selected_ext" == "all" ]]; then
    ext_pattern="*.{mp4,flv,mkv,avi,mov,wmv,webm}"
  fi

  # 输出调试信息
  echo "查找文件模式: $ext_pattern"
  echo "视频文件目录: $VIDEO_DIR"

  mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.flv" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" -o -name "*.wmv" -o -name "*.webm" \))
  
  # 输出找到的文件
  echo "找到的视频文件："
  for file in "${VIDEO_FILES[@]}"; do
    local size=$(du -h "$file" | cut -f1)
    local duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nk=1:nw=1 "$file")
    echo "${file} (大小: $size, 时长: ${duration}s)"
  done
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
    read -rp "请选择文件类型（输入数字）: " choice
    if [[ $choice =~ ^[0-9]+$ ]]; then
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

# 询问是否自定义排序
ask_custom_sort() {
  read -rp "是否要自定义排序？(y/n): " custom_sort
  if [[ $custom_sort =~ ^[yY]$ ]]; then
    echo "请选择排序规则："
    echo "1) 按文件大小排序：大小"
    echo "2) 按时长排序：时长"
    echo "3) 手动排序：手动"
    
    read -rp "请输入排序规则编号（输入数字）: " sort_choice

    case "$sort_choice" in
      1)
        VIDEO_FILES=($(printf '%s\n' "${VIDEO_FILES[@]}" | xargs -I {} sh -c 'du -b "{}" | cut -f1,2 | sort -n | cut -f2-'))
        ;;
      2)
        VIDEO_FILES=($(printf '%s\n' "${VIDEO_FILES[@]}" | xargs -I {} sh -c 'ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nk=1:nw=1 "{}" | awk "{print $1 \" {}\"}"' | sort -n | awk '{print $2}'))
        ;;
      3)
        echo "请输入手动排序的文件编号（用逗号分隔）："
        read -r manual_order
        local manual_list=($(echo "$manual_order" | tr ',' '\n'))
        VIDEO_FILES=($(printf '%s\n' "${manual_list[@]}" | xargs -I {} sh -c 'echo "{}"'))
        ;;
      *)
        echo "无效的排序规则，使用默认顺序。"
        ;;
    esac
  fi
}


# 手动排序功能
manual_sort() {
  echo "请输入文件编号和排序顺序，用空格分隔（例如 '1 3 2' 表示文件1、文件3、文件2的顺序）："
  read -r manual_order
  local ordered_files=()
  for index in $manual_order; do
    index=$((index - 1))
    if ((index >= 0 && index < ${#VIDEO_FILES[@]})); then
      ordered_files+=("${VIDEO_FILES[$index]}")
    else
      echo "无效的文件编号: $((index + 1))"
    fi
  done
  VIDEO_FILES=("${ordered_files[@]}")
}

# 列出视频文件并选择
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
      local file="${VIDEO_FILES[$i]}"
      local size=$(du -h "$file" | cut -f1)
      local duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=nk=1:nw=1 "$file")
      echo "$((i + 1))) $file (大小: $size, 时长: ${duration}s)"
    done
    echo "a) 选择所有视频"
    echo "↑/↓) 上一页/下一页"
    echo "q) 退出"

    read -rp "输入视频文件编号（多个用逗号分隔），按回车确认，或按上下箭头键选择页面： " user_input
    if [[ "$user_input" == "q" ]]; then
      echo "退出程序。"
      exit 0
    elif [[ "$user_input" == "a" ]]; then
      ask_custom_sort
      SELECTED_FILES=("${VIDEO_FILES[@]}")
      break
    elif [[ "$user_input" =~ ^[0-9,]+$ ]]; then
      IFS=',' read -r -a indices <<< "$user_input"
      SELECTED_FILES=()
      local index
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
    elif [[ "$user_input" == "↑" && page > 1 ]]; then
      ((page--))
    elif [[ "$user_input" == "↓" && page < total_pages ]]; then
      ((page++))
    else
      echo "无效选择，请重新选择。"
    fi
  done
}

# 开始推流
start_streaming() {
  if [[ ${#SELECTED_FILES[@]} -eq 0 ]]; then
    echo "没有选择任何文件。"
    return
  fi

  local base_url stream_key formatted_key
  read -r base_url stream_key <<< "$(parse_rtmp_url "$RTMP_URL")"
  formatted_key=$(format_stream_key "$stream_key")
  
  echo "推流地址: ${base_url}/${formatted_key}"
  echo "开始推流..."

  for file in "${SELECTED_FILES[@]}"; do
    echo "推流文件: $file"
    ffmpeg -re -i "$file" -c copy -f flv "${base_url}/${stream_key}" &>> "$LOG_FILE"
    echo "文件推流完毕，等待 $INTERVAL 秒..."
    sleep "$INTERVAL"
  done

  echo "所有文件推流完毕。"
}

# 清理临时文件
cleanup() {
  if [[ -f "$TEMP_FILE" ]]; then
    rm "$TEMP_FILE"
  fi
}

# 主程序
main() {
  initialize_config
  load_config
  display_and_ask_update
  select_file_type
  list_and_select_videos
  start_streaming
  cleanup
}

# 执行主程序
main
