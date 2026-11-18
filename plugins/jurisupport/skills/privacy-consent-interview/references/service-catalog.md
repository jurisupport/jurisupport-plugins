# 서비스 조사 카탈로그

예시 사무소 구성 서비스의 공개 자료 조사 결과다. **확인일: 2026-11-18.** 확인일이 6개월을 넘었거나 사용자의 요금제가 아래 행에 없으면 SKILL.md 5절대로 다시 조사한다. 여기 없는 서비스는 항상 조사한다.

이 표는 공개 자료 요약이다. 사무소 상품에 적용된다는 판단은 사용자가 요금제를 확인한 뒤에만 한다.

## 쥬리서포트

| 항목 | 내용 | 출처 |
|---|---|---|
| 처리방침 | 2026. 8. 27. 시행본. 상품별 조건 구분 없음 | https://jurisupport.com/privacy |
| 재수탁자 | PortOne, KG이니시스, Google(Gemini API), Anthropic(Claude API), Supabase, Upstash, SOLAPI, AWS, Vercel 등 | 같음 |
| 보관 | 이용계약 종료·탈퇴 후 3개월. Gemini 입력 55일, Claude 입력 30일 이내 삭제 | 같음 |
| 처리 국가 | DB·AWS 서울. Supabase 운영사 싱가포르 법인. Gemini·Claude·Vercel 미국 | 같음 |
| 국외 재수탁자 연락처 | Supabase Pte. Ltd. privacy@supabase.com / Vercel Inc. privacy@vercel.com, 440 N Barranca Avenue #4133 Covina, CA 91723 | https://supabase.com/privacy , https://vercel.com/legal/privacy-policy |

## 원드라이브

| 항목 | 개인용 | 업무용(Microsoft 365) | 출처 |
|---|---|---|---|
| 재수탁자 | 계열사·자회사 및 대신 업무를 하는 공급업체. 개별 목록 공개 없음 | Service Trust Portal 목록(원문 미확인) | https://www.microsoft.com/ko-kr/privacy/privacystatement |
| 학습 | 제품 개선·개발을 위해 LLM 등 AI 모델 개발·학습·미세조정에 사용자 데이터를 쓸 수 있음. 원드라이브 파일 제외 문구 없음(광고만 제외) | 계약 조항이 처리방침보다 우선 | 같음 |
| 사람의 검토 | 자동화 시스템 학습을 위해 일부 결과를 원본과 대조해 수동 검토 | 미조사 | 같음 |
| 보관 | 사용자가 삭제할 때까지 | 미조사 | 같음 |
| 처리 국가 | 사용자 지역(대한민국 데이터센터 있음), 미국, 백업은 다른 지역 | 한국 테넌트는 파일을 한국에 저장 | 같음 / learn.microsoft.com m365-dr-product-terms |
| 연락처 | Microsoft Corporation, One Microsoft Way, Redmond, Washington 98052, +1 (425) 882 8080, https://go.microsoft.com/fwlink/?linkid=2126612. 처리방침에 국내대리인 표시 없음 | | 같음 |

## 지메일·제미나이 (Google Workspace)

| 항목 | 내용 | 출처 |
|---|---|---|
| 계약 법인 | 청구지가 아시아·태평양이면 Google Asia Pacific Pte. Ltd.(호주·인도·뉴질랜드 제외) | https://cloud.google.com/terms/google-entity |
| 재수탁자 | Workspace 핵심 서비스 목록. Gemini 앱은 핵심 서비스에 포함 | https://workspace.google.com/terms/subprocessors.html , https://workspace.google.com/terms/user_features.html |
| 학습·사람의 검토 | 관리 콘솔 고지: 「허가 없이 인적 검토자가 콘텐츠를 검토하거나 도메인 외부에서 모델 학습에 콘텐츠를 사용하지 않습니다」 | Workspace 관리 콘솔, https://support.google.com/a/answer/15706919 |
| 보관 | 삭제 지시 후 최대 180일. Gemini 앱 대화 자동 삭제는 관리자가 정하거나 사용자 선택으로 둘 수 있음 | https://cloud.google.com/terms/data-processing-addendum , https://knowledge.workspace.google.com/admin/gemini/generative-ai-in-google-workspace-privacy-hub |
| 처리 국가 | Google 또는 하위처리자가 시설을 운영하는 국가 | DPA |
| 연락처 | googlekrsupport@google.com / 국내대리인 주식회사 디에이전트, 서울 종로구 새문안로5가길 28 광화문플래티넘 1116호, 02-737-0346, google_da_kr@dagent.co.kr | https://cloud.google.com/terms/cloud-privacy-notice |
| 개인 계정(@gmail.com) | 삭제 후 2개월, 백업 최대 6개월. 본문 학습 여부 원문 미확인 | https://policies.google.com/technologies/retention |

## 클로드 (Anthropic)

| 항목 | 개인용(Free·Pro·Max) | 상업용(Team·Enterprise·API) | 출처 |
|---|---|---|---|
| 학습 | 기본 사용, 설정으로 끔. 꺼도 안전성 플래그·피드백 대화는 학습에 쓸 수 있음 | 고객 콘텐츠 학습 안 함 | https://www.anthropic.com/legal/privacy , https://www.anthropic.com/legal/commercial-terms |
| 보관 | 삭제 후 30일. 학습 허용 시 최대 5년. 위반 플래그 2년 | 30일 이내 삭제. 위반 플래그 2년 | 같음 |
| 사람의 검토 | 분류기 탐지 대화는 안전팀 검토 | DPA 최소권한·접근기록 | support.claude.com 8325621 |
| 재수탁자 | https://trust.anthropic.com/subprocessors | 같음 | |
| 처리 국가 | 미국 등, 표준계약조항 | 같음 | https://www.anthropic.com/legal/data-processing-addendum |
| 연락처 | Anthropic PBC, privacy@anthropic.com / 국내대리인 앤트로픽코리아 유한회사, 서울시 강남구 테헤란로 152, 41층, 02-734-0940, anthropic_privacy@kimchang.com | | https://www.anthropic.com/legal/privacy |

## GPT (OpenAI)

| 항목 | 개인용(Free·Go·Plus·Pro) | Business·Enterprise·API | 출처 |
|---|---|---|---|
| 학습 | 기본 사용, 「모델 개선」 끄면 제외. 피드백 대화는 학습 가능. 임시 채팅은 학습 안 함 | 기본 학습 안 함 | https://openai.com/ko-KR/policies/kr-privacy-policy/ (2026. 9. 10.) |
| 보관 | 삭제 후 30일. 정책 위반 차단·법적 보관·결제 기록·삭제 감사 기록은 더 오래. 비식별화된 학습 콘텐츠는 삭제 대상 아님 | 관리자 설정, 삭제분 30일. API 30일, ZDR 가능 | 같음 / https://openai.com/enterprise-privacy/ |
| 사람의 검토 | 인가 직원과 서비스 제공자가 남용·보안 조사, 지원, 법적 문제, 모델 개선(옵트아웃 제외)을 위해 접근. 접근 기록 | Business·API는 남용 검토 목적. Enterprise는 사고·허락·법적 요구 시 | https://help.openai.com/en/articles/7039943-data-usage-for-consumer-services-faq |
| 재수탁자 | 한국 부록 4절 목록 | https://openai.com/policies/sub-processor-list/ | 한국 부록(2026. 3. 27.) |
| 처리 국가 | 미국 국외 서버 및 수탁자 소재 국가 | 같음 | 한국 부록 4절 |
| 연락처 | OpenAI OpCo, L.L.C.(1455 Third Street, San Francisco, CA 94158), privacy@openai.com / 국내대리인(개인정보 보호법 제31조의2) 오픈에이아이코리아 유한회사, 서울특별시 강남구 테헤란로 518, 10층, 02-722-3599, privacykorea@openai.com | | 한국 부록 9·10절 |

## 권익침해 구제기관 (처리방침 구제방법 조항)

개인정보 분쟁조정위원회 1833-6972(www.kopico.go.kr), 한국인터넷진흥원 개인정보침해 신고센터 118(privacy.kisa.or.kr), 경찰청 182(ecrm.police.go.kr). 출처는 OpenAI 한국 부록 8절이다. 기관 공식 사이트와는 대조하지 않았다.
