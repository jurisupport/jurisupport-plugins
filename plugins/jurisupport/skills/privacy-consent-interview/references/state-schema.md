# state.json 형식

큰 상태 기계가 아니다. 아래 키만 쓴다. 값이 없으면 키를 생략해도 된다.

```json
{
  "version": 1,
  "phase": "intake",
  "turn": 3,
  "services": {
    "jurisupport": {
      "name": "쥬리서포트",
      "kind": "case_management",
      "facts": {
        "purpose": {"status": "confirmed", "value": "사건관리", "quote": "사건관리는 쥬리서포트", "turn": 1},
        "data":    {"status": "confirmed", "value": "의뢰인 인적사항(주민등록번호 포함), 사건정보 일체", "quote": "의뢰인의 인적사항(주민번호 포함), 사건정보 일체 제공", "turn": 2},
        "product": {"status": "not_needed", "reason": "상품별 처리 조건 차이 없음(조사 결과)"}
      }
    },
    "claude": {
      "name": "클로드",
      "kind": "ai",
      "facts": {
        "purpose": {"status": "confirmed", "value": "법률 업무 보조", "quote": "ai는 클로드를 이용해요", "turn": 1},
        "data":    {"status": "confirmed", "value": "(쥬리서포트와 같은 정보)", "ref": "services.jurisupport.facts.data", "quote": "ai에도 동일한 정보 제공", "turn": 2},
        "product": {"status": "needed"}
      }
    }
  },
  "office": {
    "sensitive": {"status": "needed"},
    "provision": {"status": "needed"},
    "identity":  {"status": "deferred", "note": "초안에서 빈칸으로 요청"}
  },
  "asked": [
    {"turn": 1, "topic": "services.list", "question": "…"},
    {"turn": 2, "topic": "service.jurisupport.purpose+data;service.claude.purpose+data", "question": "…"}
  ],
  "research": [
    {"id": "claude.retention", "service": "claude", "topic": "보관기간", "status": "done",
     "source_url": "https://…", "applies_to": "팀·기업용·API", "finding": "…(원문 요지)", "turn": 1},
    {"id": "jurisupport.subprocessors", "service": "jurisupport", "topic": "재수탁자", "status": "failed",
     "reason": "공식 처리방침에서 하위처리자 목록을 찾지 못함", "turn": 1}
  ],
  "legal_review": [
    {"id": "rrn.external", "item": "주민등록번호를 사건관리 서비스·AI에 입력", "check": "주민등록번호 처리 제한 조문과 예외 해당 여부", "turn": 2}
  ],
  "proposals": {"consultationRetention": "(기본 문안)"},
  "manual_overrides": {"privacyRightsChannel": "(사용자가 직접 쓴 문구)"},
  "turn_log": [
    {"turn": 2, "answer_topics": ["service.jurisupport.data", "service.claude.data"],
     "new_facts": ["service.jurisupport.data", "service.claude.data(ref)"],
     "corrections": [], "failures": [{"kind": "external_source_missing", "item": "jurisupport.subprocessors"}],
     "next_topic": "service.claude.product", "reason": "Claude는 개인용·상업용 약관의 보관·학습 조건이 다르다",
     "skipped_topics": ["service.jurisupport.data: confirmed"]}
  ]
}
```

## 규칙

- 사실 상태: `confirmed` · `unknown_by_user` · `not_applicable` · `needed` · `deferred` · `not_needed`(조사 결과 물을 필요 없음).
- 정정: 기존 객체를 `history` 배열에 옮기고 새 값을 쓴다. `{"status":"confirmed","value":"이름","history":[{…이전값…}],"turn":7}`.
- `ref`로 연결한 사실은 원 사실이 정정되면 함께 바뀌는지 판단해야 한다. 사용자가 한쪽만 정정하면 `ref`를 끊고 값을 복사해 둔다.
- `turn_log`는 검증 기록이다. 사용자 화면에 그대로 출력하지 않는다.
- 실제 식별번호·의뢰인 이름은 저장하지 않는다.
