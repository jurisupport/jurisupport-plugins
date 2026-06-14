# 오프라인 법령 전문 스냅샷 인덱스

이 폴더는 법제처 Open API 키(`LAW_OC`) 발급 전 시연·실습을 위한 법령 전문 스냅샷이다.

- 기준일: 2026-06-14
- 생성 도구: `korean-law-mcp` 4.4.1
- 출처: 법제처 Open API
- 용도: 설치 직후 실습, 강의, 네트워크 장애 시 제한적 예시 작성
- 한계: 실제 사건 서면, 제출 예정 문서, 의뢰인 제공 의견서에는 그대로 쓰지 않는다. 제출 전 `korean-law` MCP 또는 국가법령정보센터에서 최신 조문을 재검증한다.

## Core

| 법령 | 파일 | MST | 시행일 |
|---|---|---:|---|
| 대한민국헌법 | `core/constitution.md` | 61603 | 1988-02-25 |
| 민법 | `core/civil-act.md` | 284415 | 2026-03-17 |
| 민사소송법 | `core/civil-procedure-act.md` | 252393 | 2025-07-12 |
| 형법 | `core/criminal-act.md` | 284025 | 2026-03-12 |
| 형사소송법 | `core/criminal-procedure-act.md` | 269945 | 2025-09-19 |
| 상법 | `core/commercial-act.md` | 284143 | 2026-03-06 |

## 주요 특별형법

| 법령 | 파일 | MST | 시행일 |
|---|---|---:|---|
| 특정범죄 가중처벌 등에 관한 법률 | `special-criminal/aggravated-specific-crimes-act.md` | 270397 | 2025-07-02 |
| 특정경제범죄 가중처벌 등에 관한 법률 | `special-criminal/aggravated-economic-crimes-act.md` | 199773 | 2018-03-20 |
| 폭력행위 등 처벌에 관한 법률 | `special-criminal/violence-punishment-act.md` | 178989 | 2016-01-06 |
| 성폭력범죄의 처벌 등에 관한 특례법 | `special-criminal/sexual-violence-punishment-act.md` | 277347 | 2025-10-01 |
| 아동ㆍ청소년의 성보호에 관한 법률 | `special-criminal/child-youth-sex-protection-act.md` | 279715 | 2026-05-12 |
| 스토킹범죄의 처벌 등에 관한 법률 | `special-criminal/stalking-punishment-act.md` | 252483 | 2024-01-12 |
| 마약류 관리에 관한 법률 | `special-criminal/narcotics-control-act.md` | 277145 | 2026-01-02 |
| 도로교통법 | `special-criminal/road-traffic-act.md` | 281875 | 2026-04-02 |
| 교통사고처리 특례법 | `special-criminal/traffic-accident-act.md` | 268077 | 2025-06-04 |
| 가정폭력범죄의 처벌 등에 관한 특례법 | `special-criminal/domestic-violence-act.md` | 270787 | 2025-10-23 |
| 성매매알선 등 행위의 처벌에 관한 법률 | `special-criminal/prostitution-punishment-act.md` | 257487 | 2024-01-01 |
| 아동복지법 | `special-criminal/child-welfare-act.md` | 279707 | 2026-05-12 |
| 공직선거법 | `special-criminal/election-act.md` | 286451 | 2026-06-02 |
| 조세범 처벌법 | `special-criminal/tax-offenses-act.md` | 224875 | 2021-01-01 |
| 부정경쟁방지 및 영업비밀보호에 관한 법률 | `special-criminal/trade-secret-act.md` | 277201 | 2026-05-28 |
| 저작권법 | `special-criminal/copyright-act.md` | 283335 | 2026-05-11 |
| 변호사법 | `special-criminal/attorney-at-law-act.md` | 228089 | 2021-01-05 |
| 자본시장과 금융투자업에 관한 법률 | `special-criminal/capital-markets-act.md` | 273695 | 2026-03-17 |
| 정보통신망 이용촉진 및 정보보호 등에 관한 법률 | `special-criminal/it-network-act.md` | 277377 | 2025-10-01 |
| 개인정보 보호법 | `special-criminal/privacy-act.md` | 270351 | 2025-10-02 |
| 전자금융거래법 | `special-criminal/electronic-financial-transactions-act.md` | 280277 | 2025-12-16 |
| 범죄수익은닉의 규제 및 처벌 등에 관한 법률 | `special-criminal/crime-proceeds-act.md` | 238751 | 2022-01-04 |

## 운영 원칙

- 이 스냅샷은 "법령 조회 도구가 전혀 안 보이는" 설치 직후 시연을 살리기 위한 안전망이다.
- 판례는 포함하지 않는다. 판례 검증은 `korean-law` MCP 또는 `beopgoeul-search`가 복구된 뒤 진행한다.
- 법 개정 가능성이 있는 분야, 특히 형사·선거·금융·개인정보 영역은 실습 답변에도 재검증 필요 문구를 붙인다.
