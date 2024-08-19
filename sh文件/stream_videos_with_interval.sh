#!/bin/bash

# 配置文件路径
CONFIG_FILE="$HOME/.stream_config"
FILES_PER_PAGE=15 # 每页显示的文件数量
LOG_FILE="stream.log"
INTERVAL=10 # 推流间隔，秒

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
  echo "*** 当前配置 ***"
  echo "RTMP 服务器地址: $base_url"
  echo "流密钥: $(format_stream_key "$stream_key")"
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
  printf '%s\n' "${VIDEO_FILES[@]}"
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

# 显示视频文件列表并获取用户输入
list_and_select_videos() {
  local page=1
  local total_pages=$(( (${#VIDEO_FILES[@]} + FILES_PER_PAGE - 1) / FILES_PER_PAGE ))

  while true; do
    clear
    echo "可用的视频文件（第 $page 页，共 $total_pages 页）："
    local start_index=$(( (page-1)*FILES_PER_PAGE ))
    local end_index=$(( page*FILES_PER_PAGE - 1 ))
    for ((i=start_index; i<=end_index && i<${#VIDEO_FILES[@]}; i++)); do
      echo "$((i + 1))) ${VIDEO_FILES[$i]}"
    done
    echo "$(( ${#VIDEO_FILES[@]} + 1 )) 选择所有视频"
    ((page > 1)) && echo "↑) 上一页"
    ((page < total_pages)) && echo "↓) 下一页"
    echo "输入视频文件编号（多个用逗号分隔），按回车确认，或按上下箭头键选择页面："

    read -r user_input

    if [[ -z "$user_input" ]]; then
      echo "没有选择任何视频文件。"
      continue
    elif [[ "$user_input" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
      IFS=',' read -r -a indices <<< "$user_input"
      SELECTED_FILES=()
      for index in "${indices[@]}"; do
        ((index--))
        if (( index >= 0 && index < ${#VIDEO_FILES[@]} )); then
          SELECTED_FILES+=("${VIDEO_FILES[$index]}")
        else
          echo "无效的编号 $((index + 1))"
        fi
      done

      if [[ ${#SELECTED_FILES[@]} -eq 0 ]]; then
        echo "没有选择任何有效的视频文件。"
        continue
      fi

      break
    elif (( user_input == ${#VIDEO_FILES[@]} + 1 )); then
      SELECTED_FILES=("${VIDEO_FILES[@]}")
      break
    else
      echo "无效选择，请重新选择。"
    fi
  done

  # 处理选择后的逻辑
  if [[ ${#SELECTED_FILES[@]} -eq 1 ]]; then
    # 只有一个文件时询问是否立即推流
    while true; do
      read -rp "只有一个视频文件被选择。是否立即开始推流？(y/n): " start_choice
      case "$start_choice" in
        [yY]) ORDERED_FILES=("${SELECTED_FILES[@]}")
              break ;;
        [nN]) exit ;;
        *) echo "无效选择，请输入 'y' 或 'n'。" ;;
      esac
    done
  else
    # 选择多个文件时询问是否排序
    while true; do
      read -rp "是否要自定义推流视频的顺序？(y/n): " order_choice
      case "$order_choice" in
        [yY])
          customize_stream_order
          break
          ;;
        [nN])
          ORDERED_FILES=("${SELECTED_FILES[@]}")
          break
          ;;
        *)
          echo "无效选择，请输入 'y' 或 'n'。"
          ;;
      esac
    done
  fi
}

# 自定义推流顺序
customize_stream_order() {
  echo "当前选择的视频文件："
  for ((i=0; i<${#SELECTED_FILES[@]}; i++)); do
    echo "$((i + 1))) ${SELECTED_FILES[$i]}"
  done
  
  while true; do
    read -rp "请输入视频文件的排序顺序（例如: 2,1,3）: " order
    IFS=',' read -r -a order_indices <<< "$order"
    ORDERED_FILES=()
    for index in "${order_indices[@]}"; do
      ((index--))
      if (( index >= 0 && index < ${#SELECTED_FILES[@]} )); then
        ORDERED_FILES+=("${SELECTED_FILES[$index]}")
      else
        echo "无效的编号 $((index + 1))"
        ORDERED_FILES=()
        break
      fi
    done

    if [[ ${#ORDERED_FILES[@]} -eq ${#SELECTED_FILES[@]} ]]; then
      break
    else
      echo "排序无效，请重新输入。"
    fi
  done
}

# 处理推流任务
process_streaming() {
  local index=1
  for video in "${ORDERED_FILES[@]}"; do
    echo "开始推流视频文件: $video"
    ffmpeg -re -i "$video" -c:v copy -c:a aac -strict experimental -f flv "$RTMP_URL" >> "$LOG_FILE" 2>&1
    sleep "$INTERVAL"
    ((index++))
  done
}

# 主脚本执行流程
initialize_config
load_config
display_and_ask_update

# 选择文件类型
select_file_type

# 列出并选择视频文件
list_and_select_videos

# 处理推流
process_streaming
