# SmartScore v2 테스트 샘플 자산

## 개요

이 디렉토리는 SmartScore v2의 각 모듈(Renderer, Restoration, OMR 등)을 검증하기 위한 테스트 악보 샘플을 관리합니다. 모든 샘플은 퍼블릭 도메인 악보를 기반으로 합니다.

## 폴더 구조

```
test_assets/
  sample_manifest.json          — 전체 샘플 목록 및 메타데이터
  README.md                     — 이 파일
  SAMPLE_REGISTRATION.md        — 샘플 등록 방식 가이드
  <작곡가_곡명>/
    original/                   — 원본 파일 (PDF, 페이지 이미지, MusicXML)
    rendered_pages/             — 렌더러 출력 기대값
    restoration_expected/       — 이미지 복원 출력 기대값
    metadata/                   — 악보 메타데이터 (JSON)
    VERIFICATION_CHECKLIST.md   — 검증 체크리스트
```

## 각 하위 폴더 용도

| 폴더 | 용도 | 파일 형식 |
|------|------|-----------|
| `original/` | 테스트에 사용할 원본 소스 파일. 스캔 이미지, PDF, MusicXML 등 | `.png`, `.pdf`, `.musicxml` |
| `rendered_pages/` | F_score_renderer 모듈의 출력과 비교할 기대 결과물 | `.png` |
| `restoration_expected/` | C_score_image_restoration 모듈의 복원 기대 결과물 | `.png` |
| `metadata/` | 악보의 음악적 정보와 테스트 기대값 정의 | `.json` |

## 샘플 사용 방법

### 앱에서 로드 (Debug 메뉴)

1. 앱을 Debug 모드로 실행
2. Settings > Debug 화면으로 이동
3. "테스트 샘플 로드" 버튼 클릭
4. `sample_manifest.json`에 등록된 샘플 목록에서 선택
5. 선택한 샘플이 ScoreLibrary에 자동 등록됨

### CLI 테스트

```bash
# Renderer 테스트
dart test test/f_score_renderer/ --test-assets=test_assets/

# Restoration 테스트
python -m pytest modules/C_score_image_restoration/test/ \
  --sample-dir=test_assets/beethoven_op14_no2/

# 전체 통합 테스트
dart test test/ --test-assets=test_assets/
```

## 새 샘플 추가 방법

1. **폴더 생성**: `test_assets/<작곡가_곡명>/` 하위에 `original/`, `rendered_pages/`, `restoration_expected/`, `metadata/` 폴더를 만듭니다.

2. **메타데이터 작성**: `metadata/score_info.json`과 `metadata/test_expectations.json`을 작성합니다. 기존 샘플의 형식을 참고하세요.

3. **원본 파일 배치**: `original/` 폴더에 페이지 이미지(`page_001.png` ~ `page_NNN.png`)와 가능하면 MusicXML 파일을 넣습니다.

4. **매니페스트 등록**: `sample_manifest.json`에 새 샘플 항목을 추가합니다.
   ```json
   {
     "id": "unique_sample_id",
     "path": "폴더명",
     "composer": "작곡가",
     "title": "곡명",
     "instrument": "악기",
     "pages": 페이지수,
     "tests": ["renderer", "restoration", "omr"],
     "status": "active",
     "added_date": "YYYY-MM-DD"
   }
   ```

5. **검증 체크리스트 작성**: `VERIFICATION_CHECKLIST.md`를 작성합니다.

6. **테스트 실행**: 전체 테스트를 실행하여 새 샘플이 정상 로드되는지 확인합니다.

## 검증 체크리스트 (공통)

- [ ] `sample_manifest.json`에 등록됨
- [ ] `metadata/score_info.json` 존재 및 유효
- [ ] `metadata/test_expectations.json` 존재 및 유효
- [ ] `original/` 폴더에 페이지 이미지 존재
- [ ] 페이지 이미지 해상도가 최소 800x1100 이상
- [ ] 모든 JSON 파일이 파싱 가능
- [ ] 퍼블릭 도메인 또는 사용 허가 확인

## 현재 등록된 샘플

| ID | 작곡가 | 곡명 | 페이지 | 상태 |
|----|--------|------|--------|------|
| `beethoven_op14_no2_mov1` | Beethoven | Piano Sonata No. 10, Op. 14 No. 2 — I. Allegro | 6 | active |
