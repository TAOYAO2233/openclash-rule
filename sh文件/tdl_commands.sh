#!/bin/bash

# 起始时间戳
start=1640707200
# 当前时间戳
current=$(date +%s)
# 间隔两个月的秒数
interval=$((60 * 24 * 60 * 60))
# 文件计数器
counter=1

while [ $start -lt $current ]
do
  end=$((start + interval))
  if [ $end -gt $current ]; then
    end=$current
  fi

  # 导出命令
  output_file="/home/tdl/tdl-export${counter}.json"
  tdl chat export -c 1586431363 -o ${output_file} -i $start,$end --all --pool 0 #1TB(jav高清)


#1586431363 为频道ID(jav高清)
  # 更新起始时间戳
  start=$end
  # 递增计数器
  counter=$((counter + 1))
done
