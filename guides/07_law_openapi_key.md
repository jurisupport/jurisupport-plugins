# 법제처 Open API 인증키 발급 가이드

> korean-law MCP가 법령·판례를 조회하려면 법제처 Open API 인증키, 즉 `OC` 값이 필요합니다.
> 발급은 무료이고, 처음 한 번만 해두면 됩니다.

---

## 1분 요약

1. [국가법령정보 공동활용](https://open.law.go.kr/LSO/openApi/guideList.do)에 접속합니다.
2. 오른쪽 위 **로그인**을 누릅니다. 계정이 없으면 **사용자 가입**을 먼저 합니다.
3. 왼쪽 메뉴에서 **OPEN API 신청**을 누릅니다.
4. 신청서를 저장합니다. 사용 목적은 `Claude Code korean-law MCP 법령·판례 검증`처럼 적으면 됩니다.
5. 왼쪽 메뉴에서 **API인증키관리**를 열고 **현재 API인증키(OC)** 값을 복사합니다.
6. `install.sh` 또는 `korean-law` 설치 프롬프트에 그 값을 붙여넣습니다.

공식 사이트에서 키 이름은 보통 `API인증키`, `OC`, `현재 API인증키(OC)`로 표시됩니다.

---

## 신청서에 무엇을 쓰나

개인 변호사·사무소 내부 사용이면 아래처럼 적으면 충분합니다.

| 항목 | 예시 |
|---|---|
| 사용 목적 | Claude Code에서 법령·판례 원문 확인 및 인용 검증 |
| 활용 서비스 | 법령 본문 조회, 판례 목록/본문 조회 |
| 이용 형태 | 개인 PC 또는 사무소 내부 업무용 |
| 사이트/도메인 | 없으면 `개인 PC 로컬 사용` 또는 사무소 홈페이지 주소 |
| 비고 | `korean-law-mcp`로 법제처 Open API를 호출 |

사이트 화면 구성이 바뀌어도 핵심은 같습니다. **OPEN API 신청을 먼저 완료한 뒤 API인증키관리에서 OC를 확인**하면 됩니다.

---

## 설치할 때 입력

전체 설치 중 이런 문구가 나오면 방금 복사한 `OC` 값을 입력합니다.

```text
법제처 API 키
> API 키:
```

Claude Code 플러그인 수동 설치 중에도 같은 값을 넣습니다.

```text
/plugin marketplace add chrisryugj/korean-law-mcp
/plugin install korean-law@korean-law-marketplace
```

설치가 끝난 뒤 Claude Code에서 확인:

```text
/mcp
```

`korean-law`가 보이면 다음처럼 테스트합니다.

```text
korean-law MCP로 민법 제750조 본문을 확인해줘.
```

---

## 급할 때 임시 진행

강의나 데모처럼 당장 발급이 막힌 경우에는 공식 샘플값 `test`로 설치를 넘길 수 있습니다.

```bash
claude mcp add --transport stdio --scope user \
  --env LAW_OC=test \
  korean-law -- npx -y korean-law-mcp@latest
```

다만 `test`는 실사용 보장용 키가 아닙니다. 실제 사건 검증 전에는 반드시 본인 `OC`로 교체하세요.

교체는 기존 등록을 지우고 다시 등록하는 방식이 가장 단순합니다.

```bash
claude mcp remove korean-law
claude mcp add --transport stdio --scope user \
  --env LAW_OC=<본인_OC> \
  korean-law -- npx -y korean-law-mcp@latest
```

---

## 자주 막히는 지점

| 증상 | 해결 |
|---|---|
| `API 신청을 먼저 진행해주세요` | 왼쪽 메뉴 **OPEN API 신청**을 먼저 저장한 뒤 **API인증키관리**로 갑니다. |
| `사용자 정보 검증 실패` | 키 오타를 확인하고, 최신 `korean-law-mcp`를 사용합니다. 최신 버전은 법제처가 요구하는 `Referer` 헤더를 자동으로 붙입니다. |
| 플러그인 설치가 GitHub `Permission denied (publickey)`로 실패 | 터미널에서 `git config --global url."https://github.com/".insteadOf "git@github.com:"` 실행 후 다시 설치합니다. |
| Node 버전 오류 | `node --version`이 20.19 이상인지 확인합니다. 낮으면 Node LTS를 업데이트합니다. |

문의가 필요하면 법제처 공동활용 사이트 하단의 **사용신청 및 이용문의: 02-2109-6446** 번호를 참고하세요.
