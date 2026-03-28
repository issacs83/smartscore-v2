# SmartScore v2 — 프로젝트 평가 보고서

| 항목 | 내용 |
|------|------|
| 평가일 | 2026-03-28 |
| 평가자 | Claude (evaluator agent) |
| 대상 | SmartScore v2 Phase 1-3 |

## 프로젝트 현황

| 지표 | 값 |
|------|-----|
| Python 파일 | 10개 (omr_server) |
| Dart 파일 | 64개 (build_unified/lib) |
| Git 커밋 | 31개 |
| API 엔드포인트 | 14개 |
| 문서 | 13개 |
| 에이전트 투입 | 12개 (8 완료, 4 대기) |

## KPI 스코어카드

| KPI | 목표 | 실제 | 달성 |
|-----|------|------|------|
| OMR 음표 인식 | >200/page | 890/page (Zeus) | ✅ 445% |
| OMR 속도 | <60s | 42s | ✅ |
| 렌더링 성공률 | 100% | 100% (Verovio) | ✅ |
| MusicXML 수리 | 자동 | music21 30마디/스코어 | ✅ |
| 데이터 영구저장 | 필수 | Hive/IndexedDB | ✅ |
| 다중 이미지 선택 | 필수 | Gallery multi-select | ✅ |
| 오디오 지연 | <200ms | ~70ms (설계) | ⏳ 미검증 |
| iOS/Android 빌드 | 필수 | dart:html 미제거 | ❌ |
| 테스트 커버리지 | 80% | ~0% | ❌ |
| CORS 보안 | 제한 | 와일드카드 | ⚠️ |

## Phase별 상세 평가

### Phase 1: OMR + Rendering (100% ✅, 9/10)

**달성:**
- FastAPI 비동기 서버 (ThreadPoolExecutor)
- server.py 모놀리스 → app.py + omr_engine.py + renderer.py 분리
- Verovio Python 렌더링 (LilyPond fallback)
- Hive/IndexedDB 영구저장
- 갤러리 다중선택 + 카메라 촬영
- HttpRequest timeout 300s
- music21 corpus 15,026 scores
- IMSLP 프록시

**미달:**
- dart:html 직접 사용 (크로스플랫폼 차단)

### Phase 2: OMR Accuracy Improvement (100% ✅, 8/10)

**달성:**
- OMR 엔진 5종 비교: homr, oemer, SMT++, Zeus, LEGATO
- Zeus (OLiMPiC) fine-tuning: SER 108.8% → 67.2%
- 카메라 시뮬레이션 augmentation: 4,314 샘플
- 시스템 분리 알고리즘: morphological staff detection
- 전처리 v3: perspective correction, shadow removal, divide-by-background
- music21 MusicXML 자동 수리
- 앙상블 OMR (homr + oemer)
- Verovio error detection + fallback

**미달:**
- 원본 100% 일치 미달성 (현실적으로 90%+ 목표)
- GPU OMR 미활성 (onnxruntime-gpu aarch64 미지원)
- LEGATO 미테스트 (Meta Llama 접근 대기)

### Phase 3: Audio Recognition (70% ⏳, 7/10)

**달성:**
- Timing Map Generator (백엔드 API)
- Reference Feature Generator (CENS, 백엔드)
- JS Audio Bridge (Web Audio API 마이크 캡처)
- Dart Audio Capture Interface (조건부 import)
- CENS Chroma Extractor (순수 Dart FFT)
- OTW Score Follower (순수 Dart)
- Follow Controller (위치 스무딩, 자동 페이지 전환)
- Performance Screen UI (풀스크린, 핸즈프리)

**미달:**
- 실제 오디오 캡처 테스트 미수행
- FluidSynth/timidity 설치 미확인
- Reference features 서버 생성 미검증
- E2E 통합 테스트 없음

## 잘된 점 (What Went Well)

1. **연구 기반 의사결정**: 20+ 논문 참조, WAC 2024 OTW 논문 기반 설계
2. **엔진 비교 체계적**: 5종 OMR 비교 → Zeus 선정 근거 명확
3. **모듈화**: Module A~H + K 구조, 백엔드 4개 모듈 분리
4. **문서화**: 개발보고서 1237줄 (VOC+SRS+SDS), 평가보고서
5. **빠른 프로토타이핑**: Phase 3 Step 1-9 2일 내 구현

## 개선 필요 (What Needs Improvement)

1. **테스트 부재**: 단위 테스트 0개 → TDD 도입 필요
2. **보안**: CORS 와일드카드, 업로드 검증 강화
3. **크로스플랫폼**: dart:html 제거 필수 (Phase 5)
4. **GPU 활용**: Jetson Orin CUDA 12.6 활용 미흡
5. **CI/CD**: 자동 빌드/테스트/배포 파이프라인 없음

## 교훈 (Lessons Learned)

1. **torch 버전 관리**: Jetson Orin sm_87 → NVIDIA 공식 wheel 필수
2. **전처리 양날의 검**: 깨끗한 이미지에서는 전처리가 오히려 정확도 저하
3. **이진화 주의**: DL 기반 OMR에 이진화 적용 시 정보 손실
4. **SMT++ vs homr**: 동일 모델명이라도 코드 버전 차이로 weight 불일치

## 권장 액션

| 우선순위 | 액션 | 담당 에이전트 | 예상 기간 |
|----------|------|-------------|----------|
| P0 | Phase 3 오디오 실제 테스트 | e2e-tester | 1일 |
| P0 | Phase 4 자동 페이지 전환 구현 | web-developer | 3일 |
| P1 | TDD 단위 테스트 작성 | tdd-guide | 3일 |
| P1 | CORS 보안 수정 | security-reviewer | 1일 |
| P2 | dart:html 제거 (Phase 5) | web-developer | 2일 |
| P2 | LEGATO 테스트 (Llama 승인 후) | ai-trainer | 2일 |
| P3 | CI/CD 파이프라인 구축 | devops-engineer | 2일 |
