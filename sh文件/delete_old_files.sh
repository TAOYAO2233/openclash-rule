#!/bin/bash

# 指定文件夹路径
TARGET_DIR="/home/docker/alist/biliup/backup/"
# 指定日志文件路径
LOG_FILE="/root/.shjiaoben/delete_log.txt"
# 指定多个关键词
KEYWORDS=("keyword1" "keyword2" "keyword3")  # 将此处的关键词替换为你的关键词

# 获取当前时间
current_time=$(date +"%Y-%m-%d %H:%M:%S")

# 删除修改时间超过25小时的文件，并记录到日志
find "$TARGET_DIR" -type f -mmin +1800 -exec sh -c '
  for file do
    echo "$0: 删除文件: $file" >> '"$LOG_FILE"'
    rm -f "$file"
  done
' "$current_time" {} +

# 检查并删除包含多个关键词的文件
for keyword in "${KEYWORDS[@]}"; do
  find "$TARGET_DIR" -type f -name "*$keyword*" -exec sh -c '
    for file do
      echo "$0: 删除包含关键词 $1 的文件: $file" >> '"$LOG_FILE"'
      rm -f "$file"
    done
  ' "$current_time" "$keyword" {} +
done

# 如果需要删除空文件夹，可以取消注释下面一行
# find "$TARGET_DIR" -type d -empty -exec rmdir {} \;