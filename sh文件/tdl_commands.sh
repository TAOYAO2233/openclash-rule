#!/bin/bash

# 定义聊天列表文件路径和哈希文件路径
chat_list_file="/home/tdl/chat_list.txt"
hash_file="/home/tdl/chat_list_hash.txt"

# 生成聊天列表并计算哈希值
update_chat_list() {
  echo "正在生成聊天列表..."
  tdl chat ls > "$chat_list_file"
  new_hash=$(md5sum "$chat_list_file" | awk '{print $1}')
  echo "$new_hash" > "$hash_file"
  echo "聊天列表已更新并保存到 $chat_list_file"
}

# 检查文件是否发生变化
check_chat_list() {
  if [ ! -f "$chat_list_file" ]; then
    echo "聊天列表文件不存在，重新生成..."
    update_chat_list
    return
  fi

  # 计算当前文件哈希值
  current_hash=$(md5sum "$chat_list_file" | awk '{print $1}')

  # 如果哈希文件不存在或哈希值不同，则更新文件
  if [ ! -f "$hash_file" ] || [ "$(cat $hash_file)" != "$current_hash" ]; then
    echo "聊天列表文件已发生变化，重新生成..."
    update_chat_list
  else
    echo "聊天列表文件未发生变化，使用现有文件。"
  fi
}

# 检查聊天列表
check_chat_list

# 显示聊天列表并提示选择频道 ID
echo "聊天列表："
cat -n "$chat_list_file"
echo
echo "请输入对应的频道 ID："
read -p "频道 ID: " channel_id

# 检查输入的频道 ID 是否在文件中
if ! grep -q "$channel_id" "$chat_list_file"; then
  echo "错误：频道 ID 不存在，请重新运行脚本并输入有效的频道 ID。"
  exit 1
fi

# 配置时间模式
echo "请选择时间模式："
echo "1. 使用默认的起始时间和截止时间"
echo "2. 自定义起始时间和截止时间"
read -p "输入选项（1或2）: " time_mode

# 配置时间参数
case "$time_mode" in
  1)
    # 使用默认时间
    default_start="2024-01-10 20:00:00"
    default_end="2024-11-30 00:00:00"
    start=$(date -d "$default_start" +%s)
    end_timestamp=$(date -d "$default_end" +%s)
    ;;
  2)
    # 自定义起始时间和截止时间
    read -p "请输入起始时间（格式：YYYY-MM-DD HH:MM:SS）: " custom_start
    read -p "请输入截止时间（格式：YYYY-MM-DD HH:MM:SS）: " custom_end
    start=$(date -d "$custom_start" +%s)
    end_timestamp=$(date -d "$custom_end" +%s)
    ;;
  *)
    echo "无效选项，请重新运行脚本。"
    exit 1
    ;;
esac

# 输出时间范围和频道信息
echo "频道 ID：$channel_id"
echo "起始时间：$(date -d @$start '+%Y-%m-%d %H:%M:%S')"
echo "截止时间：$(date -d @$end_timestamp '+%Y-%m-%d %H:%M:%S')"

# 间隔两个月的秒数
interval=$((60 * 24 * 60 * 60))

# 文件计数器
counter=1

# 循环直到起始时间超过截止时间
while [ $start -lt $end_timestamp ]
do
  end=$((start + interval))

  # 如果结束时间超过截止时间，使用截止时间
  if [ $end -gt $end_timestamp ]; then
    end=$end_timestamp
  fi

  # 输出当前处理的时间段
  echo "Processing from $(date -d @$start '+%Y-%m-%d %H:%M:%S') to $(date -d @$end '+%Y-%m-%d %H:%M:%S')"

  # 导出命令
  output_file="/home/tdl/tdl-export${counter}.json"
  tdl chat export -c $channel_id -o ${output_file} -i $start,$end --all --pool 0 

  # 更新起始时间戳
  start=$end

  # 递增计数器
  counter=$((counter + 1))
done

echo "导出完成！"
