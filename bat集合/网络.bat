@echo off
chcp 65001 >nul
title TAOYAO接口切换器

:: 直接尝试切换网络状态，不做权限检查
:: 检查接口状态并切换
netsh interface show interface name="TAOYAO" | findstr "Enabled" >nul
if %errorlevel% equ 0 (
    echo TAOYAO当前已启用，正在禁用...
    netsh interface set interface name="TAOYAO" admin=disable
    if %errorlevel% equ 0 (
        echo 操作成功：TAOYAO已禁用
    ) else (
        echo 操作失败，请以管理员身份运行此脚本
    )
) else (
    echo TAOYAO当前已禁用，正在启用...
    netsh interface set interface name="TAOYAO" admin=enable
    if %errorlevel% equ 0 (
        echo 操作成功：TAOYAO已启用
    ) else (
        echo 操作失败，请以管理员身份运行此脚本
    )
)

timeout /t 3 /nobreak >nul