@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
py -3 -c "import sys; sys.exit(sys.version_info.major != 3)" >nul 2>&1
if not errorlevel 1 (
  py -3 scripts\configure_credentials.py
  goto done
)
python -c "import sys; sys.exit(sys.version_info.major != 3)" >nul 2>&1
if not errorlevel 1 (
  python scripts\configure_credentials.py
  goto done
)
echo Python 3을 찾지 못했습니다. Claude에 설치 도움을 요청하세요.
:done
pause
