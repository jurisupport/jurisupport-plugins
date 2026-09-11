# Claude Code / Codex 호환성 확인

확인일: 2026-09-12. 대상: JuriSupport 0.2.12 소스. 검사 명령은 저장소 루트에서 실행한다.

## 변경 내용

- `install.sh`, `bootstrap.sh`, 선택 toolkit 설치기는 `--host claude|codex|both` 또는 `JURISUPPORT_HOST`를 받는다. Windows bootstrap은 `-PluginHost`와 같은 환경변수를 받는다.
- Codex만 선택하면 Claude 설치·실행·설정 폴더 생성을 하지 않는다. 기존 마켓플레이스 소스를 보존하고 Git 소스만 갱신하며 로컬 소스는 그대로 사용한다.
- 기본 Codex 설치는 핵심 플러그인과 보조 스킬 5개를 등록한다. 검색 프로그램·DB·MCP·사용자 인증은 필요한 경우 별도로 설정한다. Python CSV 헬퍼는 Python 3이 있어야 실행한다.
- 8개 핵심 스킬은 동봉된 `references/runtime.md`를 읽는다. 질문·파일·스킬 경로는 현재 호스트의 기능을 사용하고 모델·추론 설정은 세션에서 상속한다.
- 현재 판결 도구(`search_decisions`, `get_decision_text`)를 지원하고 구형 도구는 실제 제공되는 경우에만 사용한다.
- 명시적으로 승인된 초안·검증·출력 작업은 중간 승인 때문에 멈추지 않는다. 대화형 진행 요청, 법률 근거 검증, 외부 작업 승인, 프로필 웹 동의, 사용자 직접 법원 제출 경계는 유지한다.
- 기존 미커밋 변경과 사용자 플레이북·계정 설정은 보존했다. 개인 계정이나 토큰을 플러그인에 포함하지 않았다.

## 실행 확인

| 실행 환경 | 결과 | 확인한 범위 |
|---|---|---|
| Codex CLI 0.154.0 / GPT-6 Astra | 통과 | 읽기 전용 가상 사건 조회, 도구 선택, 동의·완료 조건 |
| Codex CLI 0.154.0 / GPT-5.6 Sol | 통과 | 동일 시나리오 |
| Claude Code 2.1.269 / Claude Opus 5 | 통과 | 공개 패키지를 `--plugin-dir`로 로드하고 동일 가상 자료의 헬퍼 실행 |
| Codex CLI 0.145.0 / GPT-6 Astra | 실행 거절 | 모델 실행 전에 더 최신 CLI 필요 오류. 플러그인 오류와 구분 |

모델 검사는 실제 CSV 헬퍼가 실행됐는지와 응답을 함께 확인했다. 아래 조건을 세 모델 모두 만족했다.

1. 가상 사건번호·사건명을 정확히 조회했다.
2. Codex 경로에 Claude를 추가 설치하거나, 경로가 주어진 단발성 조회에 전체 사무소 인터뷰를 요구하지 않았다.
3. 제공된 통합 판결 도구명을 선택했다.
4. 오프라인 법령만으로 실무 검증 완료를 주장하지 않았다.
5. 채팅 승인만으로 웹 동의 없는 프로필 업로드를 허용하지 않았다.
6. 초안 작성 작업의 완료를 실제 법원 제출 때까지 미루지 않았다.

Codex 실행 검사는 실제 마켓플레이스 설치를 바꾸지 않고 공개 패키지의 스킬 파일을 읽어 수행했다. 두 GPT 모델은 시험에서 `low` 추론 설정을 사용했다. 배포 스킬 자체는 이 값을 강제하지 않는다.

## 회귀·구조 검사

- Bash 회귀 검사 11개, Python 패키지·사건기록·법원양식 검사 3개, PowerShell AST·가짜 호스트 검사 1개: 총 15개 통과. 별도 저장소로 이전된 legal-books 검사는 해당 저장소에서 관리한다.
- 공식 Codex 플러그인 검사 및 8개 `SKILL.md` 형식 검사: 통과.
- 공개 파일만 복사한 Claude 패키지 검사: 경고 없이 통과. 사용자 로컬 `CLAUDE.md`는 배포 대상에서 제외했다.
- 변경된 Bash 문법, Python 검사 스크립트 문법, `git diff --check`: 통과.
- 가짜 호스트 검사는 Codex 단독·Claude·공동 선택, 기존 Git/로컬 마켓플레이스, 오류 전달, 공백/Windows 경로, 선택한 스킬 위치만 변경하는지 확인한다. 공동 제거에서 Codex 실패가 Claude 정리를 막지 않고 최종 실패 코드로 보고되는지도 확인한다.

재현 명령:

```bash
bash tests/install_host_test.sh
python3 tests/host_compatibility_test.py
pwsh -NoProfile -File tests/windows_install_host_test.ps1
python3 tests/model_compatibility_smoke.py --output-dir .omx/reports/compatibility
```

모델 실행 검사는 인증된 최신 Codex CLI와 해당 모델 사용 권한이 필요하며 사용량이 발생한다. `--codex <실행파일>`과 `--models <모델...>`로 시험 대상을 지정할 수 있다.

## 남은 검증 범위

- 실제 신규 Windows/Linux 장비의 전체 설치, 모든 법률 업무·MCP 버전·추론 설정·계정 정책 조합까지 검증한 것은 아니다.
- Claude용 데이터 보호 Hook은 Codex에서 동일하게 실행되지 않는다. Codex의 권한·승인 정책과 공통 스킬 규칙을 적용한다.
- 배포 버전은 GitHub의 `v0.2.12` 태그·릴리스에서 확인한다. 설치 후 신규 작업에서 실제 스킬 로딩과 필요한 MCP 인증을 확인해야 한다. 계정별 인증 성공을 패키지 검사만으로 보증하지 않는다.
