# Windows에서 korean-law 설치·OC 입력하기

JuriSupport 토큰·Gemini 키·전자소송 인증서 암호 등은 [credentials-setup.cmd](../credentials-setup.cmd)의 서비스 선택창에서 등록합니다. [통합 입력창 안내](09_credentials_ui.md)를 참고하세요. 아래 메뉴는 korean-law 플러그인 설치·OC 설정을 위한 기존 간편 메뉴입니다.

Claude가 설치를 진행할 수 있으면 그대로 맡기세요. 자동 모드가 외부 플러그인 설치를 차단하면 **채팅에서 다시 승인해도 실행되지 않을 수 있습니다.** Claude는 어떤 작업이 왜 막혔는지 설명해야 합니다. 조직에서 금지한 설치는 진행하지 말고 관리자에게 문의하세요.

## 먼저 앱의 플러그인 화면 확인

Claude 앱에서 현재 제공되는 플러그인 관리 화면을 엽니다. korean-law 마켓플레이스 추가·설치를 지원하면 그 화면의 승인 절차를 따르세요. 앱 버전마다 메뉴가 다르므로 보이지 않는 버튼을 찾느라 반복하지 않습니다.

## 저장소의 설정 메뉴 사용

1. 파일 탐색기에서 내려받은 `jurisupport-plugins` 폴더를 엽니다.
2. [korean-law-setup.cmd](../korean-law-setup.cmd)를 확인한 뒤 직접 실행합니다. 출처와 내용을 확인하지 않은 파일을 실행하지 마세요.
3. 메뉴에서 **플러그인 설치**를 선택합니다. 도구가 Claude CLI를 찾고 마켓플레이스·플러그인 등록을 진행합니다. 여러 후보 때문에 선택이 필요하다고 나오면 Claude에게 도움을 요청합니다.
4. 법제처 가입·API 신청은 [브라우저 초기설정 안내](07_law_openapi_key.md)에 따라 **현재 PC에서 보이는 외부 Chrome/Edge**에서 진행합니다.
5. 발급·지정한 OC가 준비되면 메뉴의 **OC 입력창**을 선택하고 팝업에 입력합니다. 채팅에 붙여넣지 않습니다.
6. 메뉴의 **설정 확인**으로 키 설정 상태를 확인하고, 새 Claude 세션에서 가이드의 점검 문구로 실제 조회를 확인합니다. 설정 저장은 조회 성공과 다릅니다.

이 메뉴는 사용자가 직접 실행하는 편의 도구입니다. 자동 승인 검사가 막은 명령을 에이전트가 이 메뉴로 대신 실행해 우회하는 용도로 사용하지 않습니다. 회사 정책·Windows 보안 경고를 무시하거나 해제하지 마세요.

## 메뉴를 실행할 수 없을 때: PowerShell

1. Windows 키를 누르고 `PowerShell`을 검색해 일반 실행합니다. 관리자 권한은 기본적으로 필요하지 않습니다.
2. 아래 첫 줄의 경로를 실제 저장소 폴더로 바꿔 붙여넣고 Enter를 누릅니다. 붙여넣기는 `Ctrl+V` 또는 창 안에서 마우스 오른쪽 클릭을 사용합니다.

```powershell
Set-Location -LiteralPath 'C:\내 저장소 경로\jurisupport-plugins'
py -3 scripts/configure_korean_law.py --install
```

OC 입력창과 설정 확인은 각각 다음 명령입니다.

```powershell
py -3 scripts/configure_korean_law.py
py -3 scripts/configure_korean_law.py --check
```

`py`를 찾지 못하면 이미 설치된 Python 3의 실행 경로를 확인합니다. 도구가 Claude를 찾지 못할 때만 확인한 경로를 `--claude 'C:\실제 경로\claude.exe'`로 지정합니다. 긴 실행 경로를 사용자가 추측할 필요는 없습니다.

오류가 나면 성공으로 넘기지 말고 **오류 문구와 어느 단계인지**만 Claude에게 알려 주세요. OC·비밀번호·설정 파일 전체는 보내지 마세요.
