#!/bin/bash

# 起始时间戳（自动计算）
start=$(date -d "2024-01-20 20:00:00" +%s)

# 截止时间戳（自动计算）
end_timestamp=$(date -d "2024-11-27 00:00:00" +%s)

# 当前时间戳
current=$(date +%s)

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
  echo "Processing from $start to $end"

  # 导出命令
  output_file="/home/tdl/tdl-export${counter}.json"
  tdl chat export -c 1586431363 -o ${output_file} -i $start,$end --all --pool 0 

  #1586431363 频道ID(mijianqiangjian)

  # 更新起始时间戳
  start=$end

  # 递增计数器
  counter=$((counter + 1))
done
