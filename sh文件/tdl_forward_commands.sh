#!/bin/bash

# 文件计数器
counter=8
# 文件路径模板
base_path="${1:-/home/tdl/tdl-export}" # 默认路径为 /home/tdl/tdl-export
# 并发数量
parallel=4 # 并行处理任务数

while true; do
  # 构造文件名
  file="${base_path}${counter}.json"

  if [ -f "$file" ]; then
    # 并行执行 tdl forward 命令
    (
      if tdl forward --from "$file" --to https://t.me/jxudgdv --desc --reconnect-timeout 0; then
        echo "Successfully forwarded: $file"
      else
        echo "Failed to forward: $file" >> error.log
      fi
    ) &
    
    # 控制并发数量
    if (( counter % parallel == 0 )); then
      wait # 等待当前批次完成
    fi
  else
    # 文件不存在，结束循环
    echo "No more files to process. Stopping at file: $file"
    break
  fi

  # 增加计数器
  counter=$((counter + 1))
done

# 等待所有后台任务完成
wait
