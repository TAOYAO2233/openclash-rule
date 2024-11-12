#!/bin/bash

# 文件计数器
counter=1
# 文件路径模板
base_path="/storage1024/docker/alist/TDL/tdl-export"

while true
do
  # 构造文件名
  file="${base_path}${counter}.json"

  # 检查文件是否存在
  if [ -f "$file" ]; then
    # 执行 forward 命令
    tdl forward --from "$file" --to https://t.me/taoyaod2233 --desc --reconnect-timeout 0
    # 增加计数器
    counter=$((counter + 1))
  else
    # 如果文件不存在，结束循环
    break
  fi
done