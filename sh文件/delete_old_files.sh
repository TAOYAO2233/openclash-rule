#!/bin/bash

# 指定文件夹路径
TARGET_DIR="/home/docker/alist/biliup/backup/"

# 删除修改时间在2天前的文件
find "$TARGET_DIR" -type f -mtime +1 -exec rm -f {} \;

# 如果需要删除空文件夹，可以取消注释下面一行
# find "$TARGET_DIR" -type d -empty -exec rmdir {} \;