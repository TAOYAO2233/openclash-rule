#!/bin/bash

# ==============================================================================
# 脚本名称: sshkey_manager.sh
# 描述: 包含完整6大密钥操作与SSH安全配置的纯净版管理脚本
# ==============================================================================

# 定义全局色彩变量
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_bai='\033[0m'
gl_kjlan='\033[96m'
gl_hong='\033[31m'

# 初始化环境函数
init_env() {
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
    touch "${HOME}/.ssh/authorized_keys"
    chmod 600 "${HOME}/.ssh/authorized_keys"
}

# 获取系统 IP 地址函数
ip_address() {
    ipv4_address=$(curl -s https://ipinfo.io/ip && echo)
    if [ -z "$ipv4_address" ]; then
        ipv4_address=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' || hostname -I | awk '{print $1}')
    fi
}

# 辅助函数：操作完成暂停提示
break_end() {
    echo ""
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
        echo -e "${gl_huang}将会生成密钥对，更安全的方式SSH登录${gl_bai}"
        echo "--------------------------------------------------------"
        echo -e "1. 生成新密钥对                     2. 手动输入已有公钥"
        echo -e "3. 从 GitHub 导入已有公钥           4. 从 URL 导入已有公钥"
        echo -e "5. 编辑公钥文件 (authorized_keys)   6. 查看本机密钥"
        echo "--------------------------------------------------------"
        echo -e "7. ${gl_hong}关闭 SSH 密码登录 (仅限密钥)${gl_bai}     8. 开启 SSH 密码登录"
        echo "--------------------------------------------------------"
        echo "0. 退出脚本"
        echo "--------------------------------------------------------"
        read -e -p "请输入你的选择: " choice
        case $choice in
            1)
                clear
                init_env
                echo "正在生成高安全性 Ed25519 密钥对..."
                # 使用 ed25519 算法生成，且密码留空
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
                init_env
                echo "请输入您已有的 SSH 公钥 (以 ssh-rsa 或 ssh-ed25519 等开头):"
                read -e -p "> " custom_pubkey
                if [ -n "$custom_pubkey" ]; then
                    echo "$custom_pubkey" >> "${HOME}/.ssh/authorized_keys"
                    chmod 600 "${HOME}/.ssh/authorized_keys"
                    echo -e "${gl_lv}公钥已成功追加到授权文件中！${gl_bai}"
                else
                    echo -e "${gl_hong}输入为空，取消操作。${gl_bai}"
                fi
                break_end
                ;;
                
            3)
                clear
                init_env
                read -e -p "请输入你的 GitHub 用户名: " github_user
                if [ -n "$github_user" ]; then
                    echo "正在从 GitHub 拉取 ${github_user} 的公钥..."
                    curl -s "https://github.com/${github_user}.keys" >> "${HOME}/.ssh/authorized_keys"
                    chmod 600 "${HOME}/.ssh/authorized_keys"
                    echo -e "${gl_lv}已成功从 GitHub 导入公钥。${gl_bai}"
                else
                    echo -e "${gl_hong}用户名不能为空。${gl_bai}"
                fi
                break_end
                ;;

            4)
                clear
                init_env
                read -e -p "请输入公钥文件的完整 URL 路径: " pubkey_url
                if [ -n "$pubkey_url" ]; then
                    echo "正在从 URL 下载公钥..."
                    curl -sSf "$pubkey_url" >> "${HOME}/.ssh/authorized_keys"
                    if [ $? -eq 0 ]; then
                        chmod 600 "${HOME}/.ssh/authorized_keys"
                        echo -e "${gl_lv}已成功从 URL 导入公钥。${gl_bai}"
                    else
                        echo -e "${gl_hong}下载失败，请检查 URL 是否有效。${gl_bai}"
                    fi
                else
                    echo -e "${gl_hong}URL 不能为空。${gl_bai}"
                fi
                break_end
                ;;

            5)
                clear
                init_env
                echo "即将打开 nano 编辑器编辑 authorized_keys 文件..."
                echo "提示：编辑完成后按 Ctrl+O 保存，按 Ctrl+X 退出。"
                sleep 2
                if command -v nano &>/dev/null; then
                    nano "${HOME}/.ssh/authorized_keys"
                else
                    vi "${HOME}/.ssh/authorized_keys"
                fi
                break_end
                ;;

            6)
                clear
                echo -e "=== ${gl_kjlan}当前服务器已授信的公钥列表 (.ssh/authorized_keys)${gl_bai} ==="
                echo "------------------------------------------------------------------------"
                if [ -f "${HOME}/.ssh/authorized_keys" ] && [ -s "${HOME}/.ssh/authorized_keys" ]; then
                    cat "${HOME}/.ssh/authorized_keys"
                else
                    echo "当前没有配置任何授权公钥。"
                fi
                echo "------------------------------------------------------------------------"
                break_end
                ;;
                
            7)
                clear
                echo -e "${gl_huang}警告：在关闭密码登录之前，请确保你已经成功配置并测试过密钥登录！${gl_bai}"
                read -e -p "你确定要禁用密码登录，切换为纯密钥登录吗？(y/n): " confirm
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    if [ -f /etc/ssh/sshd_config ]; then
                        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
                        sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
                        
                        if [ -d /etc/ssh/sshd_config.d ]; then
                            sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/* 2>/dev/null
                        fi
                        
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
                
            8)
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

# 运行脚本
sshkey_panel