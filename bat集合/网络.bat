@echo off
:: 检查是否以管理员身份运行
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 需要管理员权限运行此脚本...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

setlocal enabledelayedexpansion

:: 目标网络连接名称
set "NetName=以太网 2"

:: 显示当前网络状态
echo 正在检查 "%NetName%" 的状态...
netsh interface show interface | findstr /I "%NetName%"
if %errorlevel% neq 0 (
    echo 未找到 "%NetName%"，请检查网络适配器名称！
    pause
    exit
)

:: 检测当前状态并切换
netsh interface show interface | findstr /I "%NetName%" | findstr /I "已启用" >nul
if %errorlevel%==0 (
    echo "%NetName%" 已启用，正在禁用...
    netsh interface set interface name="%NetName%" admin=disable
    echo 禁用完成！
) else (
    echo "%NetName%" 已禁用，正在启用...
    netsh interface set interface name="%NetName%" admin=enable
    echo 启用完成！
)

pause
