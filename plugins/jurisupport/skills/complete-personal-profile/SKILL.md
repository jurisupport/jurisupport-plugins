---
description: Complete a private personal lawyer profile from lawyer-selected local records, create a standalone personal profile file, and optionally prepare a JuriSupport upload draft.
---

# Complete Personal Profile

You help a lawyer complete their own personal profile in their own Claude Code environment.

This is primarily a private personal profile completion workflow. It creates a standalone `jurisupport-personal-profile.md` file for the lawyer. A JuriSupport upload draft is optional and only happens when the lawyer wants to put the completed profile on JuriSupport.

This workflow does not publish, approve, rank, recommend, or expose the lawyer in public search.

## Boundaries

- Treat this as a personal profile completion tool first.
- Do not assume JuriSupport upload is the goal. The lawyer may only want a private profile file.
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
오늘은 내 개인 프로필만 완성할까요, 아니면 JuriSupport에 올릴 draft까지 같이 만들까요?
자료는 사건 폴더 경로, 판결문 파일, 작성서류 폴더, 또는 직접 요약한 내용을 알려주세요.
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

### 8. Personal Profile File

Always create `jurisupport-personal-profile.md` before any JuriSupport upload draft or handoff:

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

Use this file as the lawyer's private working profile even if they never upload anything to JuriSupport.

### 9. Optional JuriSupport Draft JSON

Only create `jurisupport-profile-draft.json` if the lawyer asked for a JuriSupport upload draft or confirms they want one after reading the personal profile file.

Create `jurisupport-profile-draft.json` using:

```json
{
  "profileVersion": "0.2",
  "sourceMode": "local_files",
  "lawyerIdentity": {
    "lawyerId": null,
    "displayName": "",
    "firmName": ""
  },
  "sourceInventory": [],
  "observedPractice": {
    "practiceAreas": [],
    "problemTypes": [],
    "workPatterns": []
  },
  "intendedPractice": {
    "preferredMatters": [],
    "excludedMatters": [],
    "regions": [],
    "consultationModes": [],
    "languages": ["ko"]
  },
  "publicProfile": {
    "headline": "",
    "bio": "",
    "problemFit": [],
    "preConsultationMaterials": [],
    "strengthCards": []
  },
  "internalEvidenceMap": [],
  "compliance": {
    "riskFlags": ["needs_lawyer_approval"],
    "reviewNotes": [],
    "publicationVerdict": "needs_review"
  },
  "lawyerApprovalRequired": true,
  "registrationReadiness": "needs_review"
}
```

`internalEvidenceMap` may be empty in the public plugin. If used, keep it generalized and avoid identifiers.

### 10. Profile Review Markdown

Create `jurisupport-profile-review.md`:

```markdown
# JuriSupport Upload Draft Review

## Sources Reviewed
## Observed Work Patterns
## Intended Consultation Fit
## Public Profile Draft
## Strength Cards
## Useful Pre-Consultation Materials
## Information Excluded For Privacy
## Review Needed Before Putting This On JuriSupport
```

### 11. Upload Handoff

Do not upload automatically. If the lawyer asks to put the draft on JuriSupport, use `/jurisupport:upload-to-jurisupport`.
