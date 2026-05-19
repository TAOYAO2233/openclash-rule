#!/bin/bash

# ==============================================================================
# 脚本名称: sshkey_manager.sh
# 描述: 独立于科技lion脚本的纯净版 SSH Key 密钥安全管理交互脚本
# ==============================================================================

# 定义全局色彩变量（继承自原脚本配色方案）
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_bai='\033[0m'
gl_kjlan='\033[96m'

# 获取系统 IP 地址函数
ip_address() {
    ipv4_address=$(curl -s https://ipinfo.io/ip && echo)
    if [ -z "$ipv4_address" ]; then
        ipv4_address=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || hostname -I | awk '{print $1}')
    fi
}

# 辅助函数：操作完成暂停提示
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo ""
    clear
}

# 密钥管理核心功能菜单
sshkey_panel() {
    while true; do
        clear
        echo -e "=== ${gl_kjlan}SSH Key 密钥管理面板${gl_bai} ==="
        echo "--------------------------------"
        echo -e "1. ${gl_lv}一键生成新 SSH 密钥对 (强烈推荐)${gl_bai}"
        echo "2. 从 GitHub 导入 SSH 公钥"
        echo "--------------------------------"
        echo "3. 关闭 SSH 密码登录 (仅允许密钥登录)"
        echo "4. 开启 SSH 密码登录"
        echo "--------------------------------"
        echo "0. 退出脚本"
        echo "--------------------------------"
        read -e -p "请输入你的选择: " choice
        case $choice in
            1)
                clear
                mkdir -p "${HOME}/.ssh"
                chmod 700 "${HOME}/.ssh"
                touch "${HOME}/.ssh/authorized_keys"
                
                # 原脚本使用高强度的 ed25519 算法生成，且密码留空实现免密登录
                ssh-keygen -t ed25519 -C "sshkey_manager@local" -f "${HOME}/.ssh/sshkey" -N ""
                
                # 自动将公钥注入到当前用户的授信名单
                cat "${HOME}/.ssh/sshkey.pub" >> "${HOME}/.ssh/authorized_keys"
                chmod 600 "${HOME}/.ssh/authorized_keys"
                
                ip_address
                echo ""
                echo -e "🎉 ${gl_lv}私钥信息已成功生成！${gl_bai}"
                echo -e "务必在下方复制出全部内容并保存，可本地新建文件命名为: ${gl_huang}${ipv4_address}_ssh.key${gl_bai}"
                echo "此文件将作为今后 SSH 登录此服务器的唯一凭证。"
                echo "------------------------------------------------------------------------"
                cat "${HOME}/.ssh/sshkey"
                echo "------------------------------------------------------------------------"
                break_end
                ;;
                
            2)
                clear
                read -e -p "请输入你的 GitHub 用户名: " github_user
                if [ -n "$github_user" ]; then
                    mkdir -p "${HOME}/.ssh"
                    chmod 700 "${HOME}/.ssh"
                    touch "${HOME}/.ssh/authorized_keys"
                    
                    echo "正在从 GitHub 拉取 ${github_user} 的公钥..."
                    # 动态请求 GitHub API 提取用户的公钥数据
                    curl -s "https://github.com/${github_user}.keys" >> "${HOME}/.ssh/authorized_keys"
                    chmod 600 "${HOME}/.ssh/authorized_keys"
                    echo -e "${gl_lv}已成功将 GitHub 上的公钥导入到当前服务器的 authorized_keys 中。${gl_bai}"
                else
                    echo "用户名不能为空。"
                fi
                break_end
                ;;
                
            3)
                clear
                echo -e "${gl_huang}警告：在关闭密码登录之前，请确保你已经成功配置并测试过密钥登录！${gl_bai}"
                read -e -p "你确定要禁用密码登录，切换为纯密钥登录吗？(y/n): " confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    # 检查系统中 sshd_config 文件的参数并做安全转换
                    if [ -f /etc/ssh/sshd_config ]; then
                        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                        sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
                        
                        # 兼容部分发行版包含的子配置文件
                        if [ -d /etc/ssh/sshd_config.d ]; then
                            sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/* 2>/dev/null
                        fi
                        
                        # 重启服务使其生效
                        if command -v systemctl &>/dev/null; then
                            sudo systemctl restart ssh || sudo systemctl restart sshd
                        else
                            sudo service ssh restart || sudo service sshd restart
                        fi
                        echo -e "${gl_lv}SSH 密码登录已禁用，现已仅允许密钥验证。${gl_bai}"
                    else
                        echo "未找到 /etc/ssh/sshd_config 配置文件。"
                    fi
                fi
                break_end
                ;;
                
            4)
                clear
                if [ -f /etc/ssh/sshd_config ]; then
                    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
                    if [ -d /etc/ssh/sshd_config.d ]; then
                        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config.d/* 2>/dev/null
                    fi
                    
                    if command -v systemctl &>/dev/null; then
                        sudo systemctl restart ssh || sudo systemctl restart sshd
                    else
                        sudo service ssh restart || sudo service sshd restart
                    fi
                    echo -e "${gl_lv}SSH 密码登录已重新开启。${gl_bai}"
                else
                    echo "未找到 /etc/ssh/sshd_config 配置文件。"
                fi
                break_end
                ;;
                
            0)
                clear
                echo "感谢使用！"
                exit 0
                ;;
                
            *)
                echo "无效的选择，请重新输入。"
                sleep 1
                ;;
        esac
    done
}

# 脚本入口执行
sshkey_panel