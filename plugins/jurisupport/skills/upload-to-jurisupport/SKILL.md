---
description: 변호사가 확인한 완성 프로필을 웹 동의 확인 후 JuriSupport 검토 대기 상태로 올립니다. 공개 승인이나 노출은 하지 않습니다.
---

# Upload To JuriSupport

Put a completed personal profile on JuriSupport only when the lawyer explicitly asks.

This workflow receives the completed profile prepared by `/jurisupport:complete-personal-profile`. It never publishes a profile and never approves public exposure by itself.

Web consent is mandatory. Do not treat chat confirmation as upload consent. In user-facing language, say "완성한 프로필을 JuriSupport에 올린다". Do not lead with filenames, JSON, payload, package, draft, schema, or other technical packaging words unless troubleshooting requires it.

The lawyer must complete the JuriSupport web consent page first:

```text
https://jurisupport.com/signup?redirect=/lawyer-search/profile/consent
```

## Hard Gates

Proceed only if:

1. A completed profile exists or the lawyer pasted the completed profile content.
2. The lawyer has completed the web consent page at `/lawyer-search/profile/consent`.
3. The lawyer confirms the completed profile may be uploaded to JuriSupport.
4. The environment has the JuriSupport MCP tool `upload_lawyer_search_profile_draft`, or the lawyer wants a reviewer handoff note.

If any gate is missing, explain what is missing and stop before upload.

## MCP Upload

If `upload_lawyer_search_profile_draft` is available:

1. Read the completed profile and the internal upload data if present.
2. Confirm it contains `lawyerApprovalRequired: true`.
3. Confirm it does not include raw case files or identifiers in public fields.
4. Call `upload_lawyer_search_profile_draft` with the prepared profile data.
5. If the tool returns `PROFILE_UPLOAD_CONSENT_REQUIRED`, stop and tell the lawyer to complete the web consent page. Do not retry until consent is recorded.
6. Report that the profile was received by JuriSupport and is waiting for review. Do not emphasize technical IDs unless the lawyer asks.

## Manual Package

If MCP is unavailable, prepare a concise reviewer handoff note in plain Korean with:

- the completed profile text
- the consultation areas and desired client questions
- privacy exclusions
- notes that need JuriSupport review

Do not mark the profile public.
