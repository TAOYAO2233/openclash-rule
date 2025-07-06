@echo off
chcp 65001 >nul
title TAOYAO接口切换器

REM 检查接口状态
netsh interface show interface name="TAOYAO" | findstr "Enabled" >nul

REM 根据状态执行相应操作
if %errorlevel% equ 0 (
    echo TAOYAO当前已启用，正在禁用...
    netsh interface set interface name="TAOYAO" admin=disable
    
    REM 再次检查以确认状态
    timeout /t 1 /nobreak >nul
    netsh interface show interface name="TAOYAO" | findstr "Enabled" >nul
    if %errorlevel% neq 0 (
        echo 操作成功：TAOYAO已禁用
    ) else (
        echo 操作可能失败，TAOYAO仍处于启用状态
    )
) else (
    echo TAOYAO当前已禁用，正在启用...
    netsh interface set interface name="TAOYAO" admin=enable
    
    REM 再次检查以确认状态
    timeout /t 1 /nobreak >nul
    netsh interface show interface name="TAOYAO" | findstr "Enabled" >nul
    if %errorlevel% equ 0 (
        echo 操作成功：TAOYAO已启用
    ) else (
        echo 操作可能失败，TAOYAO仍处于禁用状态
    )
)

pause