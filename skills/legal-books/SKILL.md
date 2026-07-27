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

- 서버 미응답 → 직접 `~/legal-books/scripts/server.sh start` 실행 후 2초 대기, health 재확인. 그래도 실패하면 `~/legal-books/logs/server.log` 마지막 줄과 함께 사용자에게 보고
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
      "page_end": 235,
      "chunk_text": "...",
      "score": 0.87
    }
  ],
  "warnings": [
    "semantic embedding unavailable; used FTS only: ..."
  ]
}
```

`warnings`가 있어도 `results`가 있으면 로컬 FTS5 검색 결과로 사용할 수 있다. 단, 의미 검색이 빠진 상태이므로 쟁점어를 바꿔 추가 검색한다.

## 검색 전략 (상한)

- `top_k`는 5를 기본으로 한다.
- 쿼리는 쟁점당 **최대 4회** (기본 검색 1회 + 쟁점어 변형 최대 3회).
- 새 쿼리의 상위 결과가 이전 검색 결과와 겹치기 시작하면 상한 전이라도 즉시 중단하고 종합으로 넘어간다.
- 4회 안에 관련 결과가 없으면 추가 변형을 시도하지 말고 "책이 없을 때" 절차를 따른다.

## 종합 규칙 (여러 책·여러 판이 검색될 때)

- 같은 책의 여러 판이 검색되면 **최신판만 인용**한다. 구판에만 있는 서술은 "구판(제N판)에서는 ~"으로 구분해 표기할 때만 사용.
- 저자 간 견해가 대립하면 **양쪽을 병기**하고, 가능하면 어느 쪽이 통설·판례(판결) 입장인지 표시한다.
- 견해 간 비중을 정할 때는 최신판·최신 서술에 가중치를 둔다.

## 인용 규칙 (필수)

답변에 인용할 때:

1. **저자·서명·판·페이지** 모두 표기. `page_end`가 `page`와 다르면 "pp. 234~235"처럼 범위로 표기
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

- 책 추가: `~/legal-books/scripts/add_book.sh`
- 재인덱싱: `~/legal-books/scripts/reindex.sh [--book-id 001]`
- 서버 관리: `~/legal-books/scripts/server.sh {start|stop|restart|status}`
- 가이드: `~/jurisupport-plugins/guides/02_book_scanning.md`
