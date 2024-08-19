#!/bin/bash

# 配置文件路径
CONFIG_FILE="$HOME/.stream_config"

# 加密密码
ENCRYPTION_PASSWORD="yourpassword"

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
    sed -i "s/^$key=.*/$key=$value/" "$CONFIG_FILE"
  else
    echo "$key=$value" >> "$CONFIG_FILE"
  fi
}

# 询问用户输入并保存配置
prompt_and_save_config() {
  local prompt_message="$1"
  local key="$2"
  local current_value="$3"

  read -rp "$prompt_message (当前值: $current_value): " new_value
  if [[ -n "$new_value" ]]; then
    set_config_value "$key" "$new_value"
  fi
}

# 初始化配置文件（如果不存在）
initialize_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "配置文件不存在，正在初始化..."
    read -rp "请输入 RTMP 服务器地址和流密钥 (格式: rtmp://server/live/stream-key): " RTMP_URL
    read -rsp "请输入流密钥（隐藏输入）: " STREAM_KEY
    echo
    read -rp "请输入视频文件目录: " VIDEO_DIR

    # 保存到配置文件
    echo "RTMP_URL=\"$RTMP_URL\"" > "$CONFIG_FILE"
    echo "STREAM_KEY=\"$(echo "$STREAM_KEY" | openssl enc -aes-256-cbc -base64 -pass pass:$ENCRYPTION_PASSWORD)\"" >> "$CONFIG_FILE"
    echo "VIDEO_DIR=\"$VIDEO_DIR\"" >> "$CONFIG_FILE"

    echo "配置已保存到 $CONFIG_FILE"
  fi
}

# 加载配置
load_config() {
  RTMP_URL=$(get_config_value "RTMP_URL")
  STREAM_KEY=$(echo "$(get_config_value "STREAM_KEY")" | openssl enc -aes-256-cbc -d -base64 -pass pass:$ENCRYPTION_PASSWORD)
  VIDEO_DIR=$(get_config_value "VIDEO_DIR")
}

# 显示当前配置
show_config() {
  echo "当前 RTMP 服务器地址: $RTMP_URL"
  echo -n "流密钥: "
  echo "$STREAM_KEY"
  echo "视频文件目录: $VIDEO_DIR"
}

# 主程序
initialize_config
load_config

# 显示当前配置
show_config

# 询问用户是否更新配置
while true; do
  read -rp "是否要更新配置？(y/n): " update_config
  case "$update_config" in
    y|Y )
      # 询问用户是否更改 RTMP 服务器地址和流密钥
      while true; do
        read -rp "是否要更改 RTMP 服务器地址和流密钥？(y/n): " change_rtmp
        case "$change_rtmp" in
          y|Y )
            prompt_and_save_config "请输入新的 RTMP 服务器地址" "RTMP_URL" "$RTMP_URL"
            read -rsp "请输入新的流密钥（隐藏输入）: " NEW_STREAM_KEY
            echo
            set_config_value "STREAM_KEY" "$(echo "$NEW_STREAM_KEY" | openssl enc -aes-256-cbc -base64 -pass pass:$ENCRYPTION_PASSWORD)"
            load_config
            break
            ;;
          n|N )
            break
            ;;
          * )
            echo "无效选择，请输入 'y' 或 'n'。"
            ;;
        esac
      done

      # 询问用户是否更改视频文件目录
      while true; do
        read -rp "是否要更改视频文件目录？(y/n): " change_dir
        case "$change_dir" in
          y|Y )
            prompt_and_save_config "请输入新的视频文件目录" "VIDEO_DIR" "$VIDEO_DIR"
            load_config
            break
            ;;
          n|N )
            break
            ;;
          * )
            echo "无效选择，请输入 'y' 或 'n'。"
            ;;
        esac
      done
      break
      ;;
    n|N )
      break
      ;;
    * )
      echo "无效选择，请输入 'y' 或 'n'。"
      ;;
  esac
done

# 日志文件目录和文件名
LOG_DIR="/var/log/stream_logs/"
LOG_FILE="${LOG_DIR}stream_log_$(date +'%Y%m%d_%H%M%S').log"

# 是否循环播放
LOOP_PLAYBACK=true

# 视频之间的间隔（秒）
INTERVAL=10

# 每页显示的文件数量
FILES_PER_PAGE=10

# 支持的文件扩展名
SUPPORTED_EXTENSIONS=("mp4" "flv" "mkv" "avi" "mov")

# 创建日志目录（如果不存在）
mkdir -p "$LOG_DIR"

# 检查是否存在支持的视频文件
get_video_files() {
  local selected_ext="$1"
  if [[ "$selected_ext" == "all" ]]; then
    mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.flv" -o -name "*.mkv" -o -name "*.avi" -o -name "*.mov" \) -print)
  else
    mapfile -t VIDEO_FILES < <(find "$VIDEO_DIR" -type f -name "*.$selected_ext" -print)
  fi
}

# 文件类型选择
select_file_type() {
  echo "选择要推流的文件类型："
  PS3="请选择文件类型（输入数字）: "
  select opt in "${SUPPORTED_EXTENSIONS[@]}" "全部选择"; do
    case $REPLY in
      [1-$((${#SUPPORTED_EXTENSIONS[@]}+1))])
        if [[ "$opt" == "全部选择" ]]; then
          get_video_files "all"
        else
          get_video_files "$opt"
        fi
        break
        ;;
      *)
        echo "无效选择，请重新选择。"
        ;;
    esac
  done
}

# 显示视频文件列表并获取用户输入
list_and_select_videos() {
  local page=1
  local total_pages=$(( (${#VIDEO_FILES[@]} + FILES_PER_PAGE - 1) / FILES_PER_PAGE ))

  while true; do
    clear
    echo "可用的视频文件（第 $page 页，共 $total_pages 页）："
    for ((i=(page-1)*FILES_PER_PAGE; i<page*FILES_PER_PAGE && i<${#VIDEO_FILES[@]}; i++)); do
      echo "$((i + 1))) ${VIDEO_FILES[$i]}"
    done
    echo "$(( ${#VIDEO_FILES[@]} + 1 ))) 选择所有视频"
    ((page > 1)) && echo "↑) 上一页"
    ((page < total_pages)) && echo "↓) 下一页"
    echo "输入视频文件编号（多个用逗号分隔），或按上下箭头键选择页面："

    read -r -n 1 key
    case "$key" in
      $'\x1b')
        read -r -n 2 key
        [[ "$key" == "[A" && $page -gt 1 ]] && page=$((page - 1))
        [[ "$key" == "[B" && $page -lt $total_pages ]] && page=$((page + 1))
        ;;
      [0-9]*)
        user_input="$key"
        read -r -t 0.1 -n 1 additional_input
        while [[ -n $additional_input ]]; do
          user_input+="$additional_input"
          read -r -t 0.1 -n 1 additional_input
        done

        if (( user_input == ${#VIDEO_FILES[@]} + 1 )); then
          SELECTED_FILES=("${VIDEO_FILES[@]}")
          break
        elif [[ $user_input =~ ^[0-9]+(,[0-9]+)*$ ]]; then
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
          [[ ${#SELECTED_FILES[@]} -gt 0 ]] && break
        else
          echo "无效选择，请重新选择。"
        fi
        ;;
      *)
        echo "无效选择，请重新选择。"
        ;;
    esac
  done
}

# 询问用户是否要自定义推流顺序
ask_custom_order() {
  while true; do
    read -rp "是否要自定义推流视频的顺序？(y/n): " choice
    case "$choice" in
      y|Y ) customize_stream_order; break ;;
      n|N ) ORDERED_FILES=("${SELECTED_FILES[@]}"); break ;;
      * ) echo "无效选择，请输入 'y' 或 'n'。" ;;
    esac
  done
}

# 让用户自定义推流视频的顺序
customize_stream_order() {
  while true; do
    clear
    echo "选择的文件："
    for i in "${!SELECTED_FILES[@]}"; do
      echo "$((i + 1))) ${SELECTED_FILES[$i]}"
    done
    read -rp "输入推流顺序（用逗号分隔）或直接按回车使用默认顺序：" order_input

    if [[ -z $order_input ]]; then
      ORDERED_FILES=("${SELECTED_FILES[@]}")
      break
    elif [[ $order_input =~ ^[0-9]+(,[0-9]+)*$ ]]; then
      IFS=',' read -r -a indices <<< "$order_input"
      ORDERED_FILES=()
      for index in "${indices[@]}"; do
        ((index--))
        if (( index >= 0 && index < ${#SELECTED_FILES[@]} )); then
          ORDERED_FILES+=("${SELECTED_FILES[$index]}")
        else
          echo "无效的编号 $((index + 1))"
        fi
      done
      [[ ${#ORDERED_FILES[@]} -eq ${#SELECTED_FILES[@]} ]] && break
    else
      echo "选择的顺序无效，请重新输入。"
    fi
  done
}

# 推流函数
stream_videos() {
  while true; do
    for file in "${ORDERED_FILES[@]}"; do
      echo "开始直播 $file ..." | tee -a "$LOG_FILE"

      ffmpeg -re -i "$file" -c copy -f flv "$RTMP_URL" -loglevel verbose 2>>"$LOG_FILE"

      if (( $? == 0 )); then
        echo "视频 $file 直播完成。" | tee -a "$LOG_FILE"
      else
        echo "直播过程中发生错误，尝试重新连接..." | tee -a "$LOG_FILE"
      fi

      echo "等待 $INTERVAL 秒..." | tee -a "$LOG_FILE"
      sleep "$INTERVAL"
    done

    $LOOP_PLAYBACK || break
    echo "开始新的循环..." | tee -a "$LOG_FILE"
  done
}

# 主程序
select_file_type

if (( ${#VIDEO_FILES[@]} == 0 )); then
  echo "未找到任何支持的视频文件。" | tee -a "$LOG_FILE"
  exit 1
fi

list_and_select_videos
ask_custom_order
stream_videos