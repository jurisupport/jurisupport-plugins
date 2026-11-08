@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
py -3 -c "import sys; sys.exit(sys.version_info.major != 3)" >nul 2>&1
if not errorlevel 1 (
  set "JURI_PY=py -3"
  goto menu
)
python -c "import sys; sys.exit(sys.version_info.major != 3)" >nul 2>&1
if not errorlevel 1 (
  set "JURI_PY=python"
  goto menu
)
echo Python 3을 찾지 못했습니다. Claude에 Python 설치 도움을 요청하세요.
pause
exit /b 1

:menu
echo.
echo JuriSupport - korean-law 설정
echo 1. 플러그인 설치 (Claude 실행 파일 자동 찾기)
echo 2. OC 입력창 열기
echo 3. OC 저장 여부 확인 (값은 표시하지 않음)
echo Q. 종료
choice /C 123Q /N /M "선택: "
if errorlevel 4 exit /b 0
if errorlevel 3 goto check
if errorlevel 2 goto configure
if errorlevel 1 goto install
exit /b 1

:install
%JURI_PY% scripts\configure_korean_law.py --install
goto result
:configure
%JURI_PY% scripts\configure_korean_law.py
goto result
:check
%JURI_PY% scripts\configure_korean_law.py --check
:result
if errorlevel 1 echo 작업이 완료되지 않았습니다. 위 안내를 확인하세요.
pause
goto menu
