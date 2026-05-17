---
name: legal-books
description: 사무소 보유 법률서적(교과서)을 하이브리드 검색하여 출처와 함께 인용. 로컬 SQLite + Gemini 임베딩 기반. 책이 0권일 때는 검색 시도하지 말고 사용자에게 추가 안내.
license: MIT
metadata:
  category: legal
  locale: ko-KR
---

# 법률서적 검색 스킬 (legal-books)

법률 질문이나 서면 검토 시, 사무소 보유 서적을 하이브리드 검색으로 참조한다.

## When to use

- "교과서 바탕으로 판단해"
- "법적 쟁점 분석해줘"
- "이 서면 교과서로 검토해줘"
- 법률 질문에 근거 있는 답변이 필요할 때

## 사전 확인

검색 전 반드시 서버 상태 확인:

```bash
curl -s http://localhost:8766/health
```

- 서버 미응답 → 사용자에게 서버 실행 요청
- `books: 0` → 사용자에게 책 추가 안내 (`guides/02_book_scanning.md`)
- `books: N>0` → 검색 진행

## 검색 API

```bash
curl -s -X POST http://localhost:8766/search \
  -H "Content-Type: application/json" \
  -d '{"query": "검색어", "top_k": 5}'
```

응답:
```json
{
  "query": "...",
  "results": [
    {
      "book_id": "001",
      "author": "곽윤직",
      "title": "민법총칙",
      "edition": "제9판",
      "page": 234,
      "chunk_text": "...",
      "score": 0.87
    }
  ]
}
```

## 인용 규칙 (필수)

답변에 인용할 때:

1. **저자·서명·판·페이지** 모두 표기
2. **직접인용("...")**은 chunk_text와 글자 단위 일치 검증
3. 일치 안 되면 간접인용 (요지 정리)
4. 본문에 "**판례**" 사용 금지 → "판결" 또는 "판단"
5. 영문 약어 첫 등장 시 풀어쓰기 + 한글 의미 병기

## 예시 답변 패턴

> 본건 쟁점인 시효 완성 후 채무승인의 법적 성격에 관하여, 곽윤직 『민법총칙』 (제9판, 박영사, 2018) pp. 234~236에서는 "시효 완성 사실을 알면서 채무를 승인하는 경우 시효이익 포기에 해당한다"고 설명하고 있으며, 같은 책 p. 237에서는 "시효 완성 사실을 모르고 한 승인도 사정에 따라 시효이익 포기로 평가될 수 있다"는 판단을 소개하고 있다.

## 책이 없을 때

DB가 비어 있거나 관련 결과 없음:

> 현재 사무소 서적 DB에 본 쟁점에 직접 답할 자료가 없습니다.
> `~/jurisupport-plugins/guides/02_book_scanning.md`를 참조하여 관련 서적을 추가해 주세요.
> 또는 본 답변은 일반 법리 추정으로 진행하되, 인용 출처를 명시하지 않습니다.

## 추가 도구

- 책 추가: `~/jurisupport-plugins/toolkit/legal-books/scripts/add_book.sh`
- 서버 관리: `~/jurisupport-plugins/toolkit/legal-books/scripts/server.sh {start|stop|restart|status}`
- 가이드: `~/jurisupport-plugins/guides/02_book_scanning.md`
