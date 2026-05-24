# 데이터 보호 Hook 수동 설치

> `install.sh`가 자동 설치하지만, 수동 설치가 필요한 경우 아래 절차를 따르세요.

---

## 1. Hook 실행 권한 부여

```bash
chmod +x ~/jurisupport-plugins/hooks/pretool_data_protection.sh
```

## 2. 의존성 확인

```bash
# jq 설치 (Hook이 JSON 파싱에 사용)
brew install jq        # macOS
sudo apt install jq    # Linux
```

## 3. Claude Code 설정에 등록

`~/.claude/settings.json` 파일을 편집하여 다음 항목을 추가합니다.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "WebFetch|WebSearch|mcp__google-workspace__gmail_send.*|mcp__google-workspace__chat_.*|mcp__claude_ai_Gmail__.*|mcp__claude_ai_Google_Drive__search_files|mcp__plugin_telegram_telegram__reply",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/jurisupport-plugins/hooks/pretool_data_protection.sh"
          }
        ]
      }
    ]
  }
}
```

기존 settings.json에 다른 hook 설정이 있으면 `PreToolUse` 배열에 위 객체를 추가하세요.

## 4. 검증

새 Claude Code 세션을 열고 다음을 입력:

```
인터넷에서 "홍길동 700101-1234567" 키워드로 검색해줘
```

다음과 같은 경고가 출력되면 정상 작동:

```
⚠️ 데이터 보호 Hook 차단
감지: 주민등록번호 (RRN)
```

---

## 트러블슈팅

- **Hook이 작동하지 않음**: `~/.claude/settings.json` 문법 오류 확인 (`jq . ~/.claude/settings.json`로 검증)
- **jq 오류**: `brew install jq` 또는 `apt install jq` (jq가 없으면 외부 전송 후보 호출은 차단됩니다)
- **권한 오류**: `chmod +x ...pretool_data_protection.sh`
- **Hook 우회 필요 시 (테스트용)**: settings.json에서 해당 hook 항목을 일시 주석 처리하세요.
