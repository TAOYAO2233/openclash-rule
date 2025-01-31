#!/bin/bash

# 默认起始时间和截止时间（2020-01-01 00:00:00 到 2024-12-30 23:59:59）
default_start="2020-01-01 00:00:00"
default_end="2024-12-30 23:59:59"

# 时间格式转换为时间戳的函数
date_to_timestamp() {
  date -d "$1" +%s
}

# 获取当前时间戳
current=$(date +%s)

# 默认起始和截止时间戳
start_timestamp=$(date_to_timestamp "$default_start")
end_timestamp=$(date_to_timestamp "$default_end")

# 选择时间
echo "1. 使用默认时间（$default_start 到 $default_end）"
echo "2. 使用默认起始时间（$default_start），自定义截止时间"
echo "3. 自定义起始时间和截止时间"
echo "请选择时间选项："
read time_choice

case $time_choice in
  1)
    # 使用默认时间
    start_timestamp=$start_timestamp
    end_timestamp=$end_timestamp
    ;;
  2)
    # 使用默认起始时间，自定义截止时间
    echo "请输入截止时间（默认：$default_end）："
    read end_input
    if [ -z "$end_input" ]; then
      end_timestamp=$end_timestamp
    else
      end_timestamp=$(date_to_timestamp "$end_input")
    fi
    ;;
  3)
    # 自定义起始时间和截止时间
    echo "请输入起始时间（默认：$default_start）："
    read start_input
    if [ -z "$start_input" ]; then
      start_timestamp=$start_timestamp
    else
      start_timestamp=$(date_to_timestamp "$start_input")
    fi

    echo "请输入截止时间（默认：$default_end）："
    read end_input
    if [ -z "$end_input" ]; then
      end_timestamp=$end_timestamp
    else
      end_timestamp=$(date_to_timestamp "$end_input")
    fi
    ;;
  *)
    echo "无效选择，退出脚本。"
    exit 1
    ;;
esac

# 列出聊天列表并打印
echo "正在列出所有聊天频道..."
tdl chat ls | sort

# 选择频道
echo "请选择频道（1：通过序号，2：通过频道 ID）："
read choice

# 获取频道 ID
if [ "$choice" -eq 1 ]; then
  echo "请输入频道序号："
  read channel_number
  # 获取频道 ID
  channel_id=$(tdl chat ls | sed -n "${channel_number}p" | awk '{print $1}')
elif [ "$choice" -eq 2 ]; then
  echo "请输入频道 ID："
  read channel_id
else
  echo "无效选择，退出脚本。"
  exit 1
fi

# 时间间隔，默认两个月
interval=$((60 * 24 * 60 * 60))

# 文件计数器
counter=1

# 导出聊天记录
start=$start_timestamp
while [ $start -lt $end_timestamp ]
do
  end=$((start + interval))
  if [ $end -gt $end_timestamp ]; then
    end=$end_timestamp
  fi

  # 导出命令
  output_file="/home/tdl/tdl-export${counter}.json"
  echo "导出时间段: $(date -d @$start) 到 $(date -d @$end)"
  tdl chat export -c "$channel_id" -o "$output_file" -i "$start,$end" --all

  # 更新起始时间戳
  start=$end
  # 递增计数器
  counter=$((counter + 1))
done

echo "导出完成。"
