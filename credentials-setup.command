#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
if command -v python3 >/dev/null 2>&1; then
  python3 scripts/configure_credentials.py
else
  echo 'Python 3을 찾지 못했습니다. Claude에 설치 도움을 요청하세요.'
fi
read -r -p '종료하려면 Enter를 누르세요: ' _
