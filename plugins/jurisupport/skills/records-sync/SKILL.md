---
name: records-sync
description: 사건기록 폴더와 작성서류 폴더를 함께 읽어 case-records DB에 동기화한다. 사건번호 기준으로 두 저장소를 묶고, 기본값으로 주장서면과 신청서면만 파싱해 의견서·준비서면 작성 때 과거 기록을 참고할 수 있게 한다.
license: MIT
metadata:
  category: legal
  locale: ko-KR
---

# Records Sync

사건기록 폴더(받은 자료)와 작성서류 폴더(우리 서면)를 `case-records` 로컬 DB에 함께 인덱싱한다.

## 원칙

- 원본 파일은 복사하지 않는다.
- DB에는 텍스트 청크, 원본 경로, 출처(`record`/`draft`), 문서분류(`argument`/`application`)만 저장한다.
- 기본값은 주장서면·신청서면만 파싱한다. 증거·계약서·등본까지 필요하다는 명시 요청이 있으면 `--doc-scope all`.
- 외부 임베딩은 명시 요청 없이는 켜지 않는다.

## 실행

1. `~/case-records/scripts/sync_records.sh` 존재 확인. 없으면 `bash toolkit/case-records/install.sh` 또는 `~/jurisupport-plugins/toolkit/case-records/install.sh` 실행 안내.
2. 경로는 `CLAUDE.md §5`의 사건기록 디렉토리와 작성문서 디렉토리를 우선 사용한다.
3. 경로가 없으면 사용자에게 두 경로만 짧게 물어본다.
4. 실행:

```bash
~/case-records/scripts/sync_records.sh \
  --record-root "<사건기록 디렉토리>" \
  --draft-root "<작성서류 디렉토리>"
```

전체 문서를 넣어야 할 때만:

```bash
~/case-records/scripts/sync_records.sh \
  --record-root "<사건기록 디렉토리>" \
  --draft-root "<작성서류 디렉토리>" \
  --doc-scope all
```

## 확인

```bash
curl -s http://localhost:8767/health
~/case-records/scripts/search_case_records.py "소멸시효" --top-k 3 --doc-category argument
```

## 포맷

- PDF, DOCX, MD, TXT: 기본 처리
- HWPX: zip/xml로 로컬 처리
- DOC: `textutil` 또는 `antiword`가 있으면 처리
- HWP: `hwpjs`가 있으면 처리
