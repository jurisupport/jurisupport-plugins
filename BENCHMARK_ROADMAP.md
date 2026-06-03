# 벤치마킹 로드맵 — 오픈소스 법률 에이전트 → jurisupport-plugins

> 벤치마크 소스 (아이디어 차용, 코드 포크 안 함, 깨끗한 MIT):
> - [anthropics/claude-for-legal](https://github.com/anthropics/claude-for-legal) (Apache-2.0) — 실무영역별 플러그인·단위 스킬 구조
> - [crealwork/yc-office-hours](https://github.com/crealwork/yc-office-hours) — 반아첨 압박질문·구조화 평결 (→ `mock-hearing`으로 이미 적용)
> 대상: 본 레포(`jurisupport-plugins`) / 현재 플러그인: `jurisupport`
> 갱신: 2026-05-30 (v2 — `mock-hearing` 반영) / 상태: **검토용**
> 채택 방향(사용자 선택): A. 송무 스킬 보강 + B. 실무영역 확장 (스케줄 에이전트 보류)
> 라이선스 전략: **아이디어만 차용 + 전부 직접 구현**. 코드 포크 없음 → Apache 의무·상표 리스크 0

---

## 0. 현재까지 진척 (Done)

| 항목 | 출처 | 상태 |
|---|---|---|
| `mock-hearing` (모의변론, 검증 스킬) | yc-office-hours | ✅ **완료** (4파일 멀티구조, brief-protocol Phase 3-5 연계) |
| `BENCHMARK_ROADMAP.md` | — | ✅ 이 문서 |

`mock-hearing` 적용으로 사용자가 처음 제시한 4개 방향(모의변론 스킬 / 반아첨 어조 / 멀티파일화 / 구조화 평결)이 한 스킬에 통합 완료. **검증(critique) 축**이 먼저 채워졌다. 남은 로드맵은 그 검증 스킬에 **먹일 산출물을 만드는 생산 축**과 **실무영역 확장**이다.

---

## 1. 스킬 아키텍처 (mock-hearing 반영, 중복 해소의 핵심)

스킬을 두 축으로 나눈다. 이 구분이 A2 claim-chart와 mock-hearing의 중복을 해소한다.

```
                  [생산 스킬]                        [검증 스킬]
        산출물을 만든다 (정본 후보)            산출물을 두들긴다 (제출 전 약점)

  chronology ──┐
  claim-chart ─┤
  deposition ──┼──▶  brief-protocol  ──(Phase 3 통과)──▶  mock-hearing
  demand ──────┤      (서면 정본화)                       (요건매트릭스로 공격)
  evidence ────┘                                          │
                                                  평결 REINFORCE/REFRAME
                                                          │
                                                          ▼
                                              보강 과제 → brief-protocol Phase 2 회귀
```

- **생산 스킬** = 사건기록을 가공해 *남는 산출물*(연표·쟁점표·신문사항·신청서)을 만든다. brief-protocol의 재료이자, mock-hearing의 공격 대상.
- **검증 스킬** = `mock-hearing` (완료). 산출물을 *두들기되 정본화·발송하지 않는다*.

### A2 claim-chart ↔ mock-hearing 요건사실 매트릭스: 중복 아님
| | claim-chart (생산) | mock-hearing 요건매트릭스 (검증) |
|---|---|---|
| 성격 | **남는 정본 후보** (쟁점정리표, 서면·기일에 활용) | **일회성 공격 도구** (그 자리에서 빈칸=약점 찾고 폐기) |
| 방향 | 양측 주장·증거를 *중립 정리* | 우리 약점을 *적대적으로 추궁* |
| 흐름 | claim-chart **산출물 →** mock-hearing이 **입력으로 받아 공격** | claim-chart가 있으면 매트릭스 채우기를 건너뛰고 바로 공격 |

→ 둘은 경쟁이 아니라 **파이프라인**. claim-chart를 만들면 mock-hearing이 더 빠르고 날카로워진다.

### 신규 스킬 공통 컨벤션 (mock-hearing이 모범 사례)
1. **멀티파일 구조** — 복잡 스킬은 `SKILL.md` + 보조파일(템플릿·체크리스트·예시)로 분리, cross-ref `[..](file.md)` 연결
2. **MD 우선 / Hard Gate / 2단 인용검증 / 하우스스타일 / 전자제출 금지선** — 기존 plugin 정책 그대로
3. **데이터 흐름 명시** — 각 스킬은 "무엇을 입력받아 무엇을 남기고, 누가 그걸 쓰는가"를 SKILL.md에 적는다 (brief-protocol·mock-hearing과의 연계)
4. **플레이북 실경로 사용** — 사건기록·작성문서·CSV 인덱스는 `CLAUDE.md §5`의 실제 사용자 경로를 따른다. OneDrive나 `~/Documents/사건`을 고정값으로 박지 않는다.

---

## 2. Phase A — 송무 생산 스킬 (mock-hearing에 먹일 재료)

우선순위는 **mock-hearing·brief-protocol 양쪽에 가장 많이 먹히는 산출물** 순.

### A1. `chronology` — 사실관계 연표 ⭐ 최우선
| 항목 | 내용 |
|---|---|
| 출처 | claude-for-legal litigation-legal `chronology` |
| 무엇 | 사건기록에서 일자 있는 사실을 추출 → 시계열 표(근거증거 병기) |
| **양축 효용** | brief-protocol "사실관계" 항목 + mock-hearing 쟁점사다리/요건매트릭스의 사실 기반 |
| 입력 | 사건번호 → `CLAUDE.md §5`의 사건기록 디렉토리/JuriSupport/CSV 인덱스 |
| 출력 | MD 표: `일자 \| 사실 \| 행위주체 \| 근거(갑/을호증, 제목) \| 다툼유무`. 날짜 이스케이프(`2025\. 6. 20.`) |
| 멀티파일? | 단일 SKILL.md로 충분 (보조파일 불필요) |
| 공수 | 0.5일, 신규 코드 0 |

### A2. `claim-chart` — 쟁점정리표 ⭐ 최우선 (mock-hearing 입력원)
| 항목 | 내용 |
|---|---|
| 출처 | claude-for-legal `claim-chart` (특허 chart → 민사 쟁점정리 재해석) |
| 무엇 | 쟁점별 `원고주장 \| 피고주장 \| 관련증거 \| 법령·판결 \| 우리입장·입증부담` 표 |
| **양축 효용** | brief-protocol 쟁점 추출 산출물을 표로 고정 + **mock-hearing이 이 표를 받아 빈칸·약한칸 공격** |
| 중복 해소 | §1 표 참조 — 생산물(claim-chart) → 검증(mock-hearing) 파이프라인 |
| 인용 | 법령·판결 칸은 korean-law(1차)+법고을(2차) 검증 통과분만 |
| 출력 | MD 표 (명시 시 xlsx). "판례"→"판결", 당사자 이름 병기, 서증 제목 병기 |
| 공수 | 0.5~1일 |

### A3. `deposition-prep` — 증인신문사항
| 항목 | 내용 |
|---|---|
| 출처 | litigation-legal `deposition-prep` |
| 무엇 | 증인별 주신문/반대신문 사항 + 입증취지 + 예상답변 + 탄핵자료 |
| 연계 | A1 연표·A2 쟁점표를 입력. mock-hearing HEARING 모드(석명·구두주장 예측)와 짝 |
| 멀티파일? | `SKILL.md` + `question-templates.md`(신문유형별 템플릿) 권장 |
| 주의 | 유도신문 제한(민사소송규칙) 규칙화 |
| 공수 | 1일 |

### A4. `demand-letter` — 내용증명·최고서
| 항목 | 내용 |
|---|---|
| 출처 | litigation-legal `demands` |
| 무엇 | 제소 전 내용증명·최고서·통지서. 청구원인·이행기한·법적 경고 |
| 하우스스타일 | 다른 대표자/조직 암시 금지, 경어체, em-dash 금지 |
| 공수 | 0.5일 |

### A5. `evidence-motion` — 증거수집 신청서
| 항목 | 내용 |
|---|---|
| 출처 | litigation-legal `subpoena-triage` → 한국 증거수집 |
| 무엇 | 입증사항별 최적 경로 추천 + 신청서 초안 |
| 핵심규칙(메모리) | **사실조회보다 공적 기관 문서제출명령 우선** |
| 연계 | mock-hearing 보강과제(Phase 5)가 자주 "이 입증 보강" → 이 스킬로 직결 |
| 공수 | 1일 |

---

## 3. Phase B — 실무영역 확장 (멀티 플러그인)

`jurisupport-plugins`(복수형)인데 `jurisupport` 하나뿐. claude-for-legal식 실무영역별 플러그인으로 확장. 마켓플레이스는 이미 멀티 지원.

### B1. `jamun-legal` — 자문·계약검토 (권장 1순위)
| 항목 | 내용 |
|---|---|
| 출처 | `commercial-legal` + `corporate-legal` |
| 시장성 | jurisupport.com 상업 제품엔 송무보다 수요층(인하우스·기업자문) 넓음 |
| 핵심 스킬 | `contract-review`(독소조항·대안조항), `nda-triage`, `legal-opinion`, `clause-library`, 자문용 `cold-start-interview` |
| 검증 축 재사용 | **mock-hearing의 반아첨 어조·구조화 평결을 계약검토에 이식** → `contract-review`도 "이 조항 상대가 어떻게 악용?"식 적대 검토 가능 |
| 산출 | 조항별 위험도(상/중/하) 코멘트 표. 명시 시 docx 트랙변경(점 글머리 금지) |
| 공수 | 3~5일 |

### B2. `hyeongsa-legal` — 형사 (선택 2순위)
| 항목 | 내용 |
|---|---|
| 출처 | claude-for-legal 무대응 → 한국 특화 차별점 |
| 근거 메모리 | `feedback_prosecution_record_request` 등 존재 |
| 핵심 스킬 | `record-request`(기록열람등사), `defense-brief`(변론요지서), `sentencing`(양형자료), `bail-petition`(보석청구서) |
| 공수 | 3~5일 |

> 권장: B1 먼저 (상업 확장성·기존 인프라 재사용률). mock-hearing 검증 패턴까지 이식하면 차별화.

---

## 4. Phase C — 공통 인프라 (저비용·고효과)

| 항목 | 출처 | 내용 | 공수 |
|---|---|---|---|
| C1. CONNECTORS.md | claude-for-legal `CONNECTORS.md` | korean-law·법고을·lbox·JuriSupport·gcal/gmail/텔레그램 커넥터 문서화(용도·인증·자동/수동) | 0.5일 |
| C2. 스킬 린트 CI | `scripts/validate.py`, `lint-tool-scope.py` | SKILL.md frontmatter·멀티파일 cross-ref·도구 스코프 검증 | 1일 |
| C3. 잡-타이틀 명명 | 70+ named agents | 스킬에 발견성 별칭("증거 분석관"·"계약 검토관"). mock-hearing="모의변론관" | 0.5일 |
| C4. README em-dash 정리 | (mock-hearing 적용결과 남은결정) | 플러그인 README 스킬목록 `—` 구분자 일괄 교체(메모리 em-dash 금지와 충돌) | 0.2일 |
| C5. 표 산출 xlsx 옵션 | corporate-legal `tabular-review` | 연표·쟁점표·계약검토표 xlsx 출력 (사용자 명시 시에만) | 1일 |

> 보류(미선택): 스케줄 에이전트(판례속보·기일 watcher). 인프라(gcal/gmail/텔레그램/schedule) 이미 보유, 추후 ROI 최고.

---

## 5. 우선순위·공수 종합 (v2)

| 순위 | 항목 | 공수 | 근거 |
|---|---|---|---|
| ✅ done | mock-hearing | — | 검증 축 완료 |
| 1 | **A1 chronology + A2 claim-chart** | ~1.5일 | mock-hearing·brief-protocol 양쪽에 먹임, 신규코드 0, 즉시 체감 |
| 2 | C4 README em-dash 정리 | 0.2일 | 이미 발생한 미결사항, 즉시 처리 |
| 3 | A3 deposition-prep | 1일 | mock-hearing HEARING 모드와 짝 |
| 4 | A5 evidence-motion + A4 demand-letter | 1.5일 | mock-hearing 보강과제 직결 |
| 5 | C1 CONNECTORS + C3 잡타이틀 | 1일 | 저비용 정비 |
| 6 | **B1 jamun-legal** (검증패턴 이식 포함) | 3~5일 | 실무영역 확장 |
| 7 | C2 린트 / B2 형사 / C5 xlsx | 선택 | 수요 따라 |

---

## 6. 다음 액션 (제안)

mock-hearing 실사용 피드백을 본 뒤 1차 스프린트 착수. 기본 제안:
1. **A1 `chronology` + A2 `claim-chart`** 작성 — 둘 다 mock-hearing이 받아먹을 산출물 (파이프라인 완성)
2. brief-protocol Phase 2에 연표·쟁점표 선택 호출 연결 (mock-hearing 연계는 이미 Phase 3-5에 있음)
3. C4 README em-dash 정리 (덤)
4. 검증 후 A3~A5 → B1

각 스킬은 작성 전 SKILL.md 설계(입력·산출물·데이터흐름·멀티파일 여부)를 한 번 더 확인받고 진행한다.
