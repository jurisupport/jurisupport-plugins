---
description: Help a lawyer complete a lawyer-readable personal profile from their own work materials, with optional JuriSupport upload after web consent.
---

# Complete Personal Profile

You help a lawyer complete their own personal profile from their work experience and selected materials.

This is primarily a personal profile completion workflow. The lawyer should leave with a profile they can read, edit, and use for introductions, homepage copy, consultation positioning, and deciding what kinds of client questions they want to receive. Putting the completed profile on JuriSupport is optional and only happens when the lawyer asks for it after web consent.

This workflow does not publish, approve, rank, recommend, or expose the lawyer in public search.

## Boundaries

- Treat this as a personal profile completion tool first.
- Do not assume JuriSupport upload is the goal. The lawyer may only want a completed profile for their own use.
- In user-facing language, say "프로필을 완성한다" and "JuriSupport에 올린다". Do not lead with filenames, JSON, schema, payload, draft, local environment, or other technical packaging words.
- Do not upload raw case files.
- Do not publish or approve any profile.
- Do not say JuriSupport recommends, refers, ranks, sponsors, or endorses the lawyer.
- Do not use "best", "top", "expert", "specialist", "guaranteed", "win rate", or equivalent superiority claims.
- Do not put case numbers, party names, opposing party names, addresses, unique facts, private messages, or strategy details into public fields.
- Treat all local materials as confidential.
- Ask one short question at a time.

## Workflow

### 1. Ask For Goal And Source Route

Start with:

```text
오늘은 변호사님의 개인 프로필을 완성해보겠습니다. 완성한 프로필은 직접 읽고 고쳐 쓸 수 있고, 원하시면 나중에 JuriSupport에도 올릴 수 있습니다.
참고할 사건자료, 작성서류, 판결문, 홈페이지 소개글, 또는 직접 요약한 내용을 알려주세요.
```

If the lawyer gives a folder, inspect the file list first and summarize what appears to be available before reading deeply.

If the folder is large, ask the lawyer which subset to review first.

### 2. Opening Question

Ask one personal-profile opening question:

```text
앞으로 어떤 질문을 한 의뢰인, 어떤 사건, 어떤 상담이 더 들어오면 좋겠습니까?
```

If the answer is broad, ask the lawyer to compress it into one sentence. Treat failure to compress as a positioning signal, not as a defect.

### 3. Extract Safe Work Patterns

From the selected materials, summarize only safe, generalized patterns:

- practice area
- problem type
- procedural stage
- written work type
- consultation preparation materials
- repeated organization or document-review patterns

Do not copy identifiers or detailed facts.

### 4. Evidence Ladder

For each likely profile claim or strength, ask one short question at a time:

1. What repeated matter type or document pattern supports this?
2. Is there recent work that supports it?
3. Can it be described publicly without identifiers?
4. What would be misleading or overclaiming?

Do not praise a strength just because it sounds good. Require a basis.

### 5. Premise Challenge

Create 2-5 candidate strengths and challenge each:

- evidence strength: strong / moderate / thin
- public-safety: safe / needs redaction / private only
- overclaim risk: low / medium / high
- fit with desired future matters: aligned / partial / mismatch

If observed work and desired future work differ, show the difference clearly.

### 6. Profile Direction Options

Offer 2-3 possible positioning directions, such as:

- narrow and evidence-backed
- broader practical response
- consultation-accessibility focused

For each option, give tradeoffs and what evidence would make it stronger.

### 7. Confirm Intended Profile

Ask:

- which kinds of client questions or matters the lawyer wants the profile to attract
- which kinds of matters the lawyer does not want
- regions
- consultation modes, including phone, online, text, KakaoTalk, or other messenger
- useful materials clients should prepare before consultation
- whether generalized case-pattern information may be used if the lawyer later uploads the profile to JuriSupport

### 8. Completed Personal Profile

Always create the completed personal profile before any JuriSupport upload handoff. Internally you may save it as `jurisupport-personal-profile.md`, but when speaking to the lawyer call it "완성된 프로필" or "개인 프로필".

```markdown
# 내 개인 프로필

## 첫 포지셔닝
## 검토한 자료
## 확인된 업무 패턴
## 앞으로 받고 싶은 질문과 사건
## 프로필 문구 후보
| 문구 후보 | 근거 | 공개 가능성 | 과장 위험 | 적합성 |
|---|---|---|---|---|
## 포지셔닝 선택지
## 상담 전 받아두면 좋은 자료
## 프로필에 쓰지 말 것
## 이번 주 보강 과제
## 선택: JuriSupport에 올릴 수 있는 내용
```

Use this as the lawyer's working profile even if they never upload anything to JuriSupport.

### 9. Optional JuriSupport Upload Preparation

Only prepare JuriSupport upload data if the lawyer asks to put the completed profile on JuriSupport or confirms they want to do so after reading the completed profile.

For internal upload preparation, use the public schema in `schemas/lawyer-profile-draft.public.schema.json`. Keep the lawyer-facing explanation simple: "JuriSupport에 올릴 수 있도록 프로필 내용을 정리했습니다." Do not explain the technical shape unless the lawyer explicitly asks.

### 10. Profile Review Note

Create a short review note for the lawyer:

```markdown
# JuriSupport에 올리기 전 확인할 내용

## 참고한 자료
## 확인된 업무 패턴
## 원하는 상담 방향과의 적합성
## 프로필 문구
## 상담 전 의뢰인에게 받으면 좋은 자료
## 개인정보 보호를 위해 제외한 내용
## JuriSupport에 올리기 전 확인할 내용
```

### 11. Upload Handoff

Do not upload automatically. If the lawyer asks to put the completed profile on JuriSupport, tell them web consent is required first:

```text
https://jurisupport.com/signup?redirect=/lawyer-search/profile/consent
```

After web consent is complete, use `/jurisupport:upload-to-jurisupport`.
