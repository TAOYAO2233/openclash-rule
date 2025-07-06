#!/bin/bash

# 指定要处理的文件夹路径
SOURCE_DIR="/home/docker/alist/biliup/backup"
# 设置最大同时运行的转码任务数
MAX_JOBS=2
# 指定日志文件的路径
LOG_FILE="/home/docker/alist/biliup/backup/conversion.log"

# 记录脚本开始执行的时间
echo "转换开始于 $(date)" >> "$LOG_FILE"

# 遍历文件夹中的所有 .flv 文件
for flv_file in "$SOURCE_DIR"/*.flv; do
    # 如果没有匹配的 .flv 文件，跳过处理
    [ -e "$flv_file" ] || continue

    # 构造输出文件的名称（将 .flv 扩展名替换为 .mp4）
    mp4_file="${flv_file%.flv}.mp4"

    # 检查当前运行的任务数，如果达到 MAX_JOBS，则等待
    while [ $(jobs | wc -l) -ge $MAX_JOBS ]; do
        sleep 1
    done

    # 使用 ffmpeg 进行转码，并记录转换过程
    echo "正在将 $flv_file 转码为 $mp4_file" >> "$LOG_FILE"
    if nice -n 10 ffmpeg -i "$flv_file" -c:v libx264 -c:a aac "$mp4_file" >> "$LOG_FILE" 2>&1; then
        # 转码成功，删除原始 .flv 文件
        rm "$flv_file"
        echo "成功将 $flv_file 转码为 $mp4_file，并删除原文件" >> "$LOG_FILE"
    else
        echo "转码 $flv_file 时出错" >> "$LOG_FILE"
    fi
done

# 等待所有后台任务完成
wait

# 记录脚本结束执行的时间
echo "转换结束于 $(date)" >> "$LOG_FILE"
echo "---------------------------------" >> "$LOG_FILE"