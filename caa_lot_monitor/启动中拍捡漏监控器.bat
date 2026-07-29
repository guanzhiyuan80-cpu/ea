@echo off
chcp 65001 >nul
cd /d "%~dp0"
python "中拍捡漏监控器.py"
pause
