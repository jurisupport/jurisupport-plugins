# jurisupport-plugins

> **변호사용 클로드코드 통합 패키지** — 한국 송무 자동화의 표준 워크플로우
>
> 쥬리서포트 주식회사 ([jurisupport.com](https://jurisupport.com))

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-lightgrey)
![Locale](https://img.shields.io/badge/Locale-ko--KR-red)
![Claude Code](https://img.shields.io/badge/Claude%20Code-Required-orange)

---

## 한 줄 요약

사건폴더를 던지면 **사실관계 정리 → 쟁점 추출 → 법령·판례 검증 → 준비서면 초안·완성본까지** 자동 작성합니다. 모든 단계에 변호사 책임 검증을 거치며, 의뢰인 정보는 본 패키지의 데이터 보호 Hook이 외부 유출을 자동 차단합니다.

---

## ⚠️ 가장 먼저 읽어야 할 것

| 문서 | 소요 시간 | 내용 |
|---|---|---|
| **[guides/00_security.md](guides/00_security.md)** | 5분 | 의뢰인 정보 보호 원칙 (필독) |
| **[COLD_START.md](COLD_START.md)** | 30분 | 설치 → 첫 사건까지 한 페이지 가이드 |

---

## 빠른 시작

```bash
git clone https://github.com/jurisupport/jurisupport-plugins.git
cd jurisupport-plugins
./install.sh
```

설치 후 첫 사건폴더에서:

```bash
cd ~/사건/내사건폴더
claude
```

```
/songmu-legal:cold-start-interview      # 최초 1회: 사무소 플레이북 학습
/songmu-legal:brief-protocol            # 준비서면 작성 표준 절차
```

---

## 무엇이 들어 있나

| 구성요소 | 역할 | 의존성 |
|---|---|---|
| **songmu-legal 플러그인** | 사건 인테이크 → 준비서면 자동 작성 표준 절차 | korean-law MCP (공개) |
| **데이터 보호 Hook** | 외부 API 호출 시 의뢰인 정보 자동 감지·차단 | jq |
| **lbox-guide 스킬** | lbox.kr 판례 검색 워크플로우 (수동·약관 준수) | lbox.kr 유료 계정 |
| **beopgoeul-search 스킬 + toolkit** | 법고을(lx.scourt.go.kr) 판례 **자동 검색** (Selenium) | Chrome + Python 3.9+ |
| **legal-books 스킬 + toolkit** | 사무소 보유 법률서적(교과서) 검색 | 사용자 보유 서적 스캔·OCR·임베딩 |
| **case-records 스킬 + toolkit** | 사무소 과거 사건 검색 | 사용자 과거 사건폴더 |
| **사건정보 관리표 템플릿** | JuriSupport 미사용 시 엑셀/CSV 사건관리 | 없음 |

---

## 지원 환경

| OS | 지원 | 비고 |
|---|---|---|
| macOS (Apple Silicon / Intel) | ✅ 완전 지원 | 권장 |
| Linux (Ubuntu 22.04+) | ✅ 완전 지원 | |
| Windows | ⏳ 추후 지원 | WSL2로 Linux 환경 사용 권장 |

---

## 사전 준비물

1. **클로드 Pro 또는 Max 계정** (월 20달러 이상) — https://claude.ai/upgrade
2. **클로드코드 설치** — https://docs.claude.com/claude-code
3. **Homebrew** (macOS) 또는 apt (Linux)
4. **Python 3.9+** (3.10+ 권장)
5. **Google Gemini API 키** (무료 한도 충분) — https://aistudio.google.com/apikey
   - legal-books·case-records 임베딩 생성용 (해당 toolkit 설치 시만)
6. **Google Chrome** — beopgoeul-search toolkit용 (Selenium)

---

## 설치 단계 (install.sh 8단계)

| 단계 | 내용 | 필수/선택 |
|---|---|---|
| 1 | 의존성 확인 (Python, jq, git, Claude Code) | 필수 |
| 2 | 데이터 보호 Hook 설치 | 필수 |
| 3 | songmu-legal 플러그인 등록 | 필수 |
| 4 | lbox-guide 스킬 설치 | 필수 |
| 5 | 사건정보 관리표 템플릿 복사 (~/사건/) | 권장 |
| 6 | legal-books 검색 서버 설치 | 선택 (책 스캔 후) |
| 7 | case-records 검색 서버 설치 | 선택 (사건폴더 인덱싱) |
| 8 | beopgoeul-search 자동 검색 toolkit 설치 | 선택 (Chrome 필요) |

부분 설치: [INSTALL_PARTIAL.md](INSTALL_PARTIAL.md) 참조.

---

## 사용 시작 (콜드스타트)

설치 후 다음 순서로 시작합니다. 자세한 단계: **[COLD_START.md](COLD_START.md)** 참조.

1. **[guides/00_security.md](guides/00_security.md) 정독** (5분)
2. **[guides/01_jurisupport_alt.md](guides/01_jurisupport_alt.md)** — JuriSupport 미사용 시 사건정보 관리법 (10분)
3. **첫 사건 시도** — `/songmu-legal:cold-start-interview` 실행하여 사무소 플레이북 작성
4. **첫 준비서면 작성** — `/songmu-legal:brief-protocol` 실행

---

## 문서 인덱스

### 가이드 (guides/)

| 파일 | 내용 |
|---|---|
| [00_security.md](guides/00_security.md) | 의뢰인 정보 보호 원칙 (필독) |
| [01_jurisupport_alt.md](guides/01_jurisupport_alt.md) | JuriSupport 미사용 — CSV 사건정보표 활용 |
| [02_book_scanning.md](guides/02_book_scanning.md) | 법률서적 스캔·OCR·임베딩 (legal-books) |
| [03_case_records.md](guides/03_case_records.md) | 과거 사건폴더 정리·DB화 (case-records) |
| [04_lbox_workflow.md](guides/04_lbox_workflow.md) | lbox.kr 직접 검색 워크플로우 |
| [05_beopgoeul_workflow.md](guides/05_beopgoeul_workflow.md) | 법고을 직접 검색 워크플로우 (수동) |
| [06_precedent_search.md](guides/06_precedent_search.md) | 판례 검색 통합 — 법고을 자동 → lbox 폴백 |

### 메타

| 파일 | 내용 |
|---|---|
| [COLD_START.md](COLD_START.md) | 설치 → 첫 사건까지 한 페이지 가이드 |
| [INSTALL_PARTIAL.md](INSTALL_PARTIAL.md) | 부분 설치 (구성요소별) |
| [PUBLISH.md](PUBLISH.md) | (관리자용) GitHub 배포 절차 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 기여 가이드 |
| [SECURITY.md](SECURITY.md) | 보안 정책 |
| [LICENSE](LICENSE) | MIT + 한국어 면책 |

---

## 라이선스 및 책임 면책

MIT License. 본 패키지의 코드·문서·템플릿은 자유롭게 사용·수정·배포할 수 있습니다.

다만 **다음은 본 패키지와 무관하며, 사용 변호사 본인의 절대적 책임**입니다.

- 클로드코드가 생성한 결과물의 정확성·법적 적합성 검증
- 의뢰인 정보 보호·비밀유지의무 (변호사윤리장전·개인정보보호법)
- 법원·의뢰인·상대방 제출·전달 전 최종 검토
- 데이터 보호 Hook은 보조 수단이며 완전한 유출 방지를 보장하지 아니함

---

## 쥬리서포트 (JuriSupport)

본 패키지는 **쥬리서포트 주식회사**가 한국 송무 변호사 커뮤니티에 기여하기 위해 공개 배포합니다.

- 홈페이지: [jurisupport.com](https://jurisupport.com)
- 이슈·문의: [GitHub Issues](https://github.com/jurisupport/jurisupport-plugins/issues)
- 보안 신고: admin@jurisupport.com (공개 issue 금지)
- 회사 소개: 한국 변호사·법무법인 전용 사건 관리 SaaS

### 본 패키지가 권장하는 통합

JuriSupport SaaS와 연동하면 사건·문서·기일·할일·증거를 통합 관리할 수 있습니다.
SaaS 미사용 시에도 CSV 사건정보 관리표로 동등한 기능을 활용할 수 있습니다 ([01_jurisupport_alt.md](guides/01_jurisupport_alt.md) 참조).

---

## 기여

PR·이슈 환영합니다. 다만 **의뢰인 정보·API 키 누출 방지**가 최우선 원칙이며, 본 저장소는 한국 송무 실무에 특화되어 있습니다. 자세한 사항은 [CONTRIBUTING.md](CONTRIBUTING.md) 참조.
