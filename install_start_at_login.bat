@echo off
:: Check for elevation
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting elevated permissions...
    set "SCRIPT_PATH=%~f0"
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c \"%SCRIPT_PATH%\"' -Verb runAs"
    exit /b
)

:: Define full path to PowerShell script
set "TASK_SCRIPT_PATH=%~dp0install_start_at_login.ps1"
powershell -ExecutionPolicy Bypass -File "%TASK_SCRIPT_PATH%"
echo Task 'ComfyUI_AutoLaunch' created successfully to run at startup.
pause
