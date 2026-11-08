# 토큰·인증키·비밀번호 입력창

설치 중 필요한 비밀값은 **입력창 또는 해당 서비스의 공식 화면**에서 등록합니다. 채팅, 터미널의 텍스트 질문, 명령행 인자, 설정 파일 직접 편집으로 값을 요구하지 않습니다. 입력창이 실행되지 않으면 해당 설정만 대기로 남기고 화면 연결을 복구합니다.

## 입력창 열기

- Windows: 저장소의 [credentials-setup.cmd](../credentials-setup.cmd)를 직접 실행합니다.
- macOS: [credentials-setup.command](../credentials-setup.command)를 실행합니다.
- Claude가 실행할 때는 저장소 루트에서 다음 명령을 사용합니다. 서비스 선택창에서 대상을 고르면 그 값의 입력창이 열립니다.

```bash
python3 scripts/configure_credentials.py
```

Windows에서는 `py -3 scripts/configure_credentials.py`를 사용합니다. 실행할 서비스가 정해져 있으면 `--service`로 선택할 수 있습니다. **비밀값을 명령 뒤에 붙이지 않습니다.**

```bash
python3 scripts/configure_credentials.py --service jurisupport
python3 scripts/configure_credentials.py --service gemini
python3 scripts/configure_credentials.py --service korean-law
```

## 대상과 저장 위치

| 선택 항목 / `--service` | 받는 값 | 연결되는 기존 저장 방식 |
|---|---|---|
| `jurisupport` | JuriSupport MCP 토큰 | Claude 사용자 MCP 설정. 다른 서버 설정을 보존하며, Codex 등 다른 클라이언트의 등록까지 완료됐다고 간주하지 않음 |
| `korean-law` | 법제처 OC | 기존 Claude 플러그인 민감 설정 입력. [기존 OC 전용 도구](../scripts/configure_korean_law.py)도 계속 사용 가능 |
| `law-forms` | 법제처 OC | law-forms의 `config.json`에 `LAW_OC` 설정. 한국법 플러그인과 별도 저장소이므로 필요하면 각각 등록 |
| `gemini` | Gemini API 키 | `~/.jurisupport/secrets.env`의 `GEMINI_API_KEY`. legal-books와 case-records가 함께 사용하는 키이며 `legal-books`는 이 항목의 별칭 |
| `case-records` | 로컬 검색 서버 API 토큰 | 기존 `~/.jurisupport/case-records.token`. 설치기가 이미 생성한 정상 토큰은 보존하고, 사용자가 변경할 때만 등록 |
| `ecourt-cert` | Windows 공동인증서 암호 | 설치된 ecourt-cli의 DPAPI 암호화 도구 → `.env`의 `ECFS_CERT_PW_ENC` |
| `ecourt-telegram` | Windows ecourt 알림용 Telegram 봇 토큰 | 같은 DPAPI 방식으로 `TELEGRAM_BOT_TOKEN_ENC` 저장 |
| `ecfs-cert` | macOS 전자소송 공동인증서 암호 | 기존 `~/.config/k-skill/secrets.env` SOPS 금고의 `ECFS_CERT_PW` |
| `ecfs-gmail` | macOS 송달 알림용 Gmail 앱 비밀번호 | 같은 SOPS 금고의 `GMAIL_APP_PW`. Google 계정 로그인 비밀번호와 구분 |
| `telegram` | Claude Telegram 채널 봇 토큰 | Claude 설정 루트의 `channels/telegram/.env`에 `TELEGRAM_BOT_TOKEN` 설정 |
| `law-login`, `jurisupport-login` | 해당 사이트의 로그인 비밀번호 | 공식 로그인 화면을 외부 브라우저로 열어 그 입력란에서 처리. 이 도구에 별도 비밀번호 사본을 저장하지 않음 |

Claude 설정 루트는 `CLAUDE_CONFIG_DIR`를 사용하는 경우 그 경로를 따릅니다. toolkit별 경로 설정이 있는 경우 도구가 지원하는 실제 위치를 확인합니다. 이름이 같은 토큰이라도 소비하는 앱이 다르면 저장 위치가 다릅니다. 예를 들어 ecourt용 암호화 토큰과 Claude Telegram 채널 토큰은 서로 대체되지 않습니다.

기존 legal-books 검색 서버에는 별도 API 인증 토큰이 없으며, Gemini 키를 사용하는 현재 구현을 따릅니다. 이를 위해 사용하지 않는 토큰을 새로 만들지 않습니다.

## 비밀번호·본인인증은 실제 서비스 화면에서

법제처·JuriSupport·Google·lbox 등의 로그인 비밀번호는 **현재 PC의 외부 브라우저에서 공식 사이트 입력란**으로 받습니다. 비밀번호 자동완성이나 서비스의 기존 보호 입력 UI가 있으면 그것을 사용합니다. 로그인 화면을 열었다는 사실만으로 인증됐다고 하지 않습니다.

Claude는 화면 이동·일반 정보 작성·등록 후 확인을 이어갑니다. 도구가 안전한 로컬 직접 전달을 지원하지 않으면 비밀번호를 읽어서 `fill` 명령이나 도구 호출 인자로 넘기지 않습니다. 인증번호·CAPTCHA·약관 선택은 서비스 화면에서 사용자가 처리합니다. 운영체제 관리자 암호는 운영체제의 승인창을 사용합니다.

## 설치 과정에서 적용하는 규칙

1. 비밀값을 묻는 단계 전에 기존 등록 여부부터 확인합니다. 정상 설정이 있으면 다시 입력받거나 재발급하지 않습니다.
2. 값이 없으면 해당 입력창을 엽니다. 취소·빈 입력을 삭제 요청으로 해석하지 않으며 기존 설정을 보존합니다.
3. 외부 설치기가 터미널 입력을 요구하면 먼저 이 도구나 서비스의 보호 UI로 등록하고 설치기를 재개합니다. 연결 가능한 저장 방식이 없으면 설정 대기로 남깁니다. 콘솔 입력·`--header`·`-Set KEY=VALUE` 같은 방식으로 비밀값을 대신 전달하지 않습니다.
4. Gemini 키를 저장했다고 외부 임베딩 전송에 동의한 것은 아닙니다. 사건·서적 인덱싱, 알림 발송, 전자소송 제출, 예약 실행은 별도 요청 범위를 따릅니다.
5. DPAPI 또는 SOPS 암호화 도구가 없거나 실패하면 저장하지 않습니다. 평문 저장으로 자동 전환하지 않습니다. 기존 설치의 금고·키 파일을 삭제하거나 새로 생성해 덮어쓰지 않습니다.
6. 설치된 외부 앱의 실제 읽기 경로도 확인합니다. 일부 오래된 ecourt 알림 도구는 암호화 토큰을 읽지 못할 수 있으므로, 등록만으로 모든 알림 기능이 작동한다고 보고하지 않습니다.

## 저장 확인과 실제 동작 확인

API 키·토큰 저장 상태는 다음처럼 확인합니다. 결과에는 값이 아니라 등록 여부만 나와야 합니다.

```bash
python3 scripts/configure_credentials.py --service jurisupport --check
python3 scripts/configure_credentials.py --service korean-law --check
```

웹 로그인 항목은 실제 외부 브라우저의 로그인 상태로 확인합니다. 설정 저장 성공과 실제 인증·조회 성공은 별도입니다. 서버가 공용 키로도 응답하면 조회 성공만으로 본인 키 사용을 증명하지 않습니다. 실제 인증은 공개 테스트 질의 등 필요한 최소 범위에서 수행하고, 입력값·설정 원문·인증 화면을 보고서에 남기지 않습니다.

**입력창 사용과 저장 암호화는 다릅니다.** Claude 설정·Gemini 환경 파일·law-forms 설정·로컬 토큰 파일은 기존 프로그램과 호환되는 보호된 로컬 파일이며 평문일 수 있습니다. ecourt 인증서 암호·지원 토큰은 Windows DPAPI, ecfs 자격증명은 기존 SOPS 금고를 사용합니다. 전부 암호화됐다고 설명하지 않습니다.
