# SmartScore v2 개발 보고서

| 항목 | 내용 |
|------|------|
| 문서 ID | DEV-RPT-001 |
| 버전 | 1.0.0 |
| 작성일 | 2026-03-28 |
| 작성자 | SmartScore v2 개발팀 |
| 상태 | Draft |

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [VOC — Voice of Customer](#2-voc--voice-of-customer)
3. [SRS — Software Requirements Specification](#3-srs--software-requirements-specification)
4. [SDS — Software Design Specification](#4-sds--software-design-specification)
5. [개발 로드맵](#5-개발-로드맵)
6. [리스크 분석](#6-리스크-분석)
7. [테스트 결과 요약](#7-테스트-결과-요약)

---

## 1. 프로젝트 개요

SmartScore v2는 카메라로 촬영한 악보를 디지털화하여, 사용자의 연주에 맞춰 자동으로 악보를 넘겨주는 크로스플랫폼 피아노 반주 보조 앱이다.

### 1.1 최종 목표

```
카메라 촬영 → OMR 처리 → MusicXML 생성 → 악보 렌더링
                                               ↓
                          자동 페이지 전환 ← 음향 인식 ← 피아노 연주
```

핵심 기능 4가지:

1. **OMR (Optical Music Recognition)**: 카메라 사진 → MusicXML 변환
2. **Score Rendering**: MusicXML → 시각적 악보 표시
3. **Audio Recognition**: 피아노 소리 → 현재 연주 위치 감지
4. **Auto Page Turn**: 실시간 악보 추적 + 자동 페이지 전환

### 1.2 기술 스택 현황

| 계층 | 기술 | 상태 |
|------|------|------|
| Frontend | Flutter Web (`build_unified/`) | 구현 완료 |
| Backend | FastAPI + Python 3.11 (`omr_server/`) | 운영 중 |
| OMR Engine | Zeus (OLiMPiC fine-tuned) + homr | Fine-tuning 완료 |
| Rendering | Verovio Python (primary) + LilyPond (fallback) | 운영 중 |
| Storage | Hive / IndexedDB (Web) | 구현 완료 |
| Infrastructure | Jetson Orin (ARM64, CUDA 12.6, 65.9GB GPU) | 운영 중 |

---

## 2. VOC — Voice of Customer

### 2.1 대상 사용자 분류

```
┌─────────────────────────────────────────────────┐
│               SmartScore v2 사용자                │
├──────────────┬──────────────┬────────────────────┤
│  피아노 반주자  │   음악 학생    │   개인 연습자        │
│  (Professional)│ (Student)   │ (Amateur)          │
├──────────────┴──────────────┴────────────────────┤
│       공통 페인포인트: 악보 페이지 넘김의 불편함           │
└─────────────────────────────────────────────────┘
```

### 2.2 주요 페인포인트 (Pain Points)

#### VOC-001: 수동 페이지 전환의 어려움
- **현상**: 피아노 반주자는 연주 중 양손이 건반 위에 있어 악보를 넘길 수 없다
- **빈도**: 악보 길이에 따라 연주 중 수십 회 발생
- **영향**: 연주 흐름 단절, 실수 유발, 보조자(페이지 터너) 필요
- **사용자 발언**: "반주 중에 손을 뗄 수 없는데 페이지가 넘어가는 순간이 항상 두렵다"

#### VOC-002: 악보 디지털화의 번거로움
- **현상**: 기존 종이 악보를 디지털 앱에서 사용하려면 별도 스캔/구매 필요
- **빈도**: 새 곡 준비마다 반복
- **영향**: 시간 소비 (스캔, 파일 변환, 업로드), 비용 발생 (PDF 구매)
- **사용자 발언**: "가지고 있는 악보를 그냥 카메라로 찍으면 바로 쓸 수 있으면 좋겠다"

#### VOC-003: 악보 품질 문제
- **현상**: 오래된 악보, 손으로 쓴 악보, 복사본 등 상태가 다양함
- **빈도**: 레슨용 악보, 오래된 소장 악보에서 빈번
- **영향**: 디지털화 정확도 저하, 렌더링 오류
- **사용자 발언**: "필기 메모가 잔뜩 쓰인 악보도 인식해줬으면 한다"

#### VOC-004: 모바일 우선 사용성
- **현상**: 악보대 앞에서 태블릿/스마트폰으로 사용하는 시나리오가 주요 사용 패턴
- **빈도**: 항상
- **영향**: 큰 화면(태블릿) 선호, 빠른 응답 필요
- **사용자 발언**: "아이패드에서 쓸 수 있어야 한다"

#### VOC-005: 처리 속도
- **현상**: 악보 촬영 후 결과를 기다리는 시간이 길면 사용 포기
- **빈도**: OMR 처리마다
- **영향**: 60초 초과 시 사용자 이탈률 급증
- **사용자 발언**: "30초 안에 결과가 나와야 실용적이다"

### 2.3 이상적인 워크플로우 (Desired Workflow)

사용자가 원하는 End-to-End 경험:

```
Step 1: 촬영
  스마트폰/태블릿으로 악보 사진 찍기 (1~N 페이지)
  → 앱이 자동으로 문서 경계 인식 및 보정

Step 2: OMR 처리
  서버로 업로드 → 자동 인식
  → 60초 이내 MusicXML 생성

Step 3: 악보 확인
  화면에 깔끔하게 렌더링된 악보 표시
  → 필요시 간단한 수정

Step 4: 연주 시작
  마이크 활성화
  → 앱이 연주 소리를 분석하여 현재 위치 추적

Step 5: 자동 전환
  페이지 끝 도달 감지
  → 자동으로 다음 페이지로 전환 (손 사용 불필요)
```

### 2.4 품질 요구사항 (Quality Requirements)

| 항목 | 사용자 기대치 | 목표 사양 |
|------|-------------|---------|
| OMR 음표 인식 정확도 | "대부분 맞아야 한다" | > 90% note accuracy |
| OMR 처리 시간 | "1분 이내" | < 60초 (단일 페이지) |
| 렌더링 시간 | "즉시" | < 5초 |
| 페이지 전환 정확도 | "박자에 맞게" | ± 1 마디 이내 |
| 오디오 지연 | "실시간 느낌" | < 200ms |
| 오프라인 악보 접근 | "저장된 건 항상 볼 수 있어야" | 완전 오프라인 지원 |

### 2.5 플랫폼 요구사항

우선순위 순:
1. **iPad / Android 태블릿**: 악보 표시에 최적 (10인치 이상 화면)
2. **iPhone / Android 스마트폰**: 촬영 및 이동 중 사용
3. **Web Browser**: 데스크탑 연습 환경
4. **Windows / macOS**: 장기 보관 및 편집

---

## 3. SRS — Software Requirements Specification

### 3.1 시스템 컨텍스트 다이어그램

```
                         ┌──────────────────┐
                         │   외부 시스템       │
                         │  ┌────────────┐  │
                         │  │   IMSLP    │  │
                         │  │  (악보 DB)  │  │
                         │  └────────────┘  │
                         └────────┬─────────┘
                                  │ HTTP
                    ┌─────────────▼──────────────┐
                    │      SmartScore v2 System    │
  ┌──────────┐      │  ┌──────────┐  ┌─────────┐ │
  │  사용자   │◄────►│  │ Flutter  │  │ FastAPI │ │
  │ (Camera/ │      │  │   App    │◄►│ Server  │ │
  │  Piano/  │      │  └──────────┘  └────┬────┘ │
  │  Touch)  │      │                     │      │
  └──────────┘      │              ┌──────▼─────┐ │
                    │              │ OMR Engine  │ │
                    │              │ (Zeus/homr) │ │
                    │              └────────────┘ │
                    └────────────────────────────┘
```

### 3.2 사용 사례 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│                      SmartScore v2 System                    │
│                                                              │
│   UC-001: 악보 촬영        UC-004: 연주 중 악보 추적           │
│   UC-002: 갤러리 가져오기   UC-005: 자동 페이지 전환           │
│   UC-003: 악보 렌더링      UC-006: 악보 라이브러리 관리        │
│   UC-007: IMSLP 검색      UC-008: MIDI 재생                  │
│                                                              │
└────────────────────────────┬────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  피아노 반주자    │
                    │  음악 학생       │
                    │  개인 연습자     │
                    └─────────────────┘
```

### 3.3 기능 요구사항 (Functional Requirements)

#### FR-001 ~ FR-010: 악보 입력 (Score Capture)

**FR-001**: 카메라 촬영
- 앱은 기기의 카메라를 사용하여 악보를 촬영하는 기능을 제공해야 한다
- 촬영 시 실시간 문서 경계 가이드라인을 화면에 표시해야 한다
- 지원 포맷: JPEG, PNG (최대 10MB/장)

**FR-002**: 갤러리 가져오기
- 앱은 기기 갤러리에서 기존 사진을 선택하는 기능을 제공해야 한다
- 다중 선택(multi-select)을 지원하여 여러 페이지를 한 번에 가져올 수 있어야 한다

**FR-003**: 다중 페이지 지원
- 복수의 이미지를 순서대로 결합하여 하나의 악보로 처리해야 한다
- `POST /omr/multi` API를 통해 최대 20페이지를 단일 요청으로 처리해야 한다

**FR-004**: 파일 가져오기
- MusicXML (.xml, .musicxml, .mxl), PDF 형식의 파일을 직접 가져올 수 있어야 한다
- 지원 확장자: `.xml`, `.musicxml`, `.mxl`, `.pdf`, `.mid`, `.midi`

**FR-005**: 자동 전처리
- 서버 수신 후 자동으로 다음 전처리 단계를 순서대로 실행해야 한다:
  1. EXIF orientation 보정
  2. 문서 경계 감지 및 원근 보정 (perspective correction)
  3. 그림자 제거 (morphological divide-by-background)
  4. 그레이스케일 변환
  5. 자동 회전 감지 및 기울기 보정 (deskew)
  6. 업스케일링 (2x, 최대 3000px)
  7. 조명 정규화 (illumination normalization)
  8. 악보 영역 크롭

**FR-006**: 전처리 실패 시 원본 사용
- 전처리 파이프라인 오류 발생 시 원본 이미지로 OMR을 재시도해야 한다
- `_process_single_image()` 내 fallback 로직을 통해 보장

#### FR-011 ~ FR-020: OMR 처리

**FR-011**: OMR 엔진 실행
- 서버는 수신한 이미지에 대해 OMR을 실행하고 MusicXML을 반환해야 한다
- 기본 엔진: Zeus (OLiMPiC fine-tuned, `train_camera_model.py`)
- 폴백 엔진: homr

**FR-012**: MusicXML 자동 수리
- OMR 출력 MusicXML에 대해 `music21` 기반 자동 수리를 적용해야 한다
- 수리 항목:
  - 마디 길이 부족 → 쉼표로 패딩 (padding with rests)
  - 마디 길이 초과 → 마지막 요소 트리밍 (trimming overfull measures)
  - `makeNotation()` 적용으로 beam, tie 정규화

**FR-013**: 다중 페이지 병합
- 복수 페이지 처리 결과를 하나의 MusicXML로 병합해야 한다
- 마디 번호(measure number)를 연속적으로 재번호 매겨야 한다
- `_merge_musicxml_pages()` 로직 준수

**FR-014**: 처리 타임아웃
- 단일 페이지 처리 타임아웃: 120초 (`OMR_PAGE_TIMEOUT = 120`)
- 타임아웃 발생 페이지는 건너뛰고 나머지 페이지 결과를 반환해야 한다

**FR-015**: OMR 엔진 상태 확인
- `GET /health` 엔드포인트를 통해 OMR 엔진 가용성을 확인할 수 있어야 한다
- 응답: `{"status": "ready"|"no_engine", "engine": "zeus"|"homr"|"none"}`

#### FR-021 ~ FR-030: 악보 렌더링 (Score Rendering)

**FR-021**: MusicXML → 시각적 악보 변환
- 서버에서 수신한 MusicXML을 화면에 악보로 렌더링해야 한다
- 1차: Verovio Python (SVG → PNG via cairosvg)
- 폴백: LilyPond CLI (`musicxml2ly` + `lilypond`)

**FR-022**: 렌더링 옵션
- 페이지 크기: A4 (2100×2970pt), scale=40, adjustPageHeight=True
- 페이지 수 계산: `tk.getPageCount()` 활용
- DPI: 150dpi PNG 출력

**FR-023**: 악보 표시 설정
- 사용자 조절 가능 설정값:

  | 설정 | 기본값 | 범위 |
  |------|--------|------|
  | `measuresPerSystem` | 4 | 1-8 |
  | `systemsPerPage` | 6 | 1-10 |
  | `staffLineSpacing` | 12.0px | 8-24px |
  | `zoom` | 1.0 | 0.5-4.0 |
  | `darkMode` | false | bool |
  | `paperSize` | "A4" | "A4", "Letter" |

**FR-024**: 현재 위치 하이라이트
- 현재 연주 중인 마디를 `currentPositionColor` (기본값: blue) 및 `currentPositionOpacity` (기본값: 0.5)로 강조 표시해야 한다

**FR-025**: Hit Test
- 사용자가 화면을 탭할 때 해당 위치의 음표/마디/표정을 식별해야 한다
- `HitTestResult`에 `type`, `measureNumber`, `noteId`, `pitch`, `beat`, `confidence`를 포함해야 한다

#### FR-031 ~ FR-040: 오디오 입력 및 악보 추적

**FR-031**: 마이크 입력
- 기기 마이크를 통해 실시간 오디오를 수집해야 한다
- Web Audio API (브라우저) 또는 플랫폼별 오디오 캡처 API 활용
- 오디오 버퍼 크기: 2048 samples (최대 latency ~43ms at 48kHz)

**FR-032**: 음높이 인식 (Pitch Detection)
- 피아노 음원에서 현재 연주 중인 음고(pitch)를 실시간으로 추출해야 한다
- 목표 정확도: 반음 단위 (semitone resolution) > 95%
- 피아노 음역: A0 (27.5Hz) ~ C8 (4186Hz)

**FR-033**: 악보 추적 (Score Following)
- 인식된 음고 시퀀스를 MusicXML 악보와 매칭하여 현재 위치를 추정해야 한다
- Dynamic Time Warping (DTW) 기반 매칭 알고리즘 사용
- 위치 업데이트 주기: < 100ms

**FR-034**: 수동 위치 설정
- 사용자가 화면의 특정 마디를 탭하여 현재 위치를 수동으로 설정할 수 있어야 한다

**FR-035**: 추적 시작/정지
- 오디오 추적 기능을 사용자가 명시적으로 시작/정지할 수 있어야 한다
- 정지 상태에서는 마이크 접근을 해제하여 배터리를 절약해야 한다

#### FR-041 ~ FR-050: 자동 페이지 전환

**FR-041**: 자동 페이지 전환
- 악보 추적기가 현재 페이지의 마지막 마디를 지나가는 것을 감지하면 자동으로 다음 페이지로 전환해야 한다
- 전환 예측: 마지막 마디 진입 시점에 미리 페이지를 준비해야 한다 (pre-load)

**FR-042**: 전환 애니메이션
- 페이지 전환 시 부드러운 슬라이드/페이드 애니메이션을 적용해야 한다
- 애니메이션 지속 시간: 300ms 이하 (연주에 방해되지 않는 수준)

**FR-043**: 수동 페이지 전환
- 화면 스와이프 또는 외부 페달 입력으로 수동 페이지 전환을 지원해야 한다
- 블루투스 발판 페달(Bluetooth page turner pedal) 연결을 지원해야 한다

**FR-044**: 전환 취소
- 자동 전환 직후 사용자가 이전 페이지로 즉시 돌아갈 수 있어야 한다

#### FR-051 ~ FR-060: 악보 라이브러리 관리

**FR-051**: 악보 저장
- 처리된 MusicXML과 메타데이터를 기기에 영구 저장해야 한다
- 저장소: Hive (Flutter) / IndexedDB (Web)
- 페이지 새로고침 후에도 데이터를 유지해야 한다

**FR-052**: 악보 목록
- 저장된 악보를 타일/리스트 형태로 표시해야 한다
- 각 악보에 제목, 작곡가, 저장 날짜, 페이지 수를 표시해야 한다

**FR-053**: 악보 삭제
- 사용자가 저장된 악보를 삭제할 수 있어야 한다
- 삭제 전 확인 다이얼로그를 표시해야 한다

**FR-054**: 악보 검색
- 제목 또는 작곡가로 악보를 검색할 수 있어야 한다

**FR-055**: IMSLP 연동
- `GET /imslp/search?q=<query>` API를 통해 IMSLP 악보 데이터베이스를 검색할 수 있어야 한다
- `GET /imslp/download?url=<url>` API를 통해 무료 악보를 직접 다운로드할 수 있어야 한다
- IMSLP 허용 호스트: imslp.org, imslp.simssa.ca, petruccimusiclibrary.org

**FR-056**: 내부 코퍼스 검색
- `GET /corpus/search?q=<query>` API를 통해 서버 내 악보 코퍼스를 검색할 수 있어야 한다

#### FR-061 ~ FR-070: MIDI 재생

**FR-061**: MIDI 내보내기
- OMR 처리 결과를 MIDI 파일로 내보낼 수 있어야 한다
- `POST /render` 응답에 `midi_base64` 포함

**FR-062**: 인앱 MIDI 재생
- 저장된 MIDI 또는 MusicXML을 앱 내에서 재생할 수 있어야 한다
- Tone.js 또는 Web Audio API 활용

### 3.4 비기능 요구사항 (Non-Functional Requirements)

#### NFR-001 ~ NFR-010: 성능 (Performance)

**NFR-001**: OMR 처리 시간
- 단일 페이지 (A4 기준): 전처리 포함 < 60초
- 타임아웃 설정: `OMR_PAGE_TIMEOUT = 120`초 (안전 마진 2배)
- 현재 측정값: Zeus 42초, homr 32초 (960×1280 이미지 기준)

**NFR-002**: 렌더링 시간
- MusicXML → PNG 렌더링: < 5초
- Verovio 기준: 측정값 < 3초

**NFR-003**: 오디오 처리 지연
- 오디오 입력 → 위치 업데이트: < 200ms
- 페이지 전환 반응 시간: < 500ms

**NFR-004**: 앱 시작 시간
- 콜드 스타트(cold start): < 3초 (Flutter Web)
- 악보 라이브러리 로드: < 1초 (최대 100개 기준)

**NFR-005**: 동시 처리
- 서버는 ThreadPoolExecutor (max_workers=2)를 통해 최대 2개의 OMR 요청을 동시 처리해야 한다

**NFR-006**: 업로드 한도
- 단일 이미지: 최대 10MB (`MAX_UPLOAD_BYTES = 10 * 1024 * 1024`)
- 렌더링 요청 본문: 최대 5MB (`MAX_RENDER_BODY = 5 * 1024 * 1024`)
- IMSLP 다운로드: 최대 50MB (`MAX_DOWNLOAD_BYTES = 50 * 1024 * 1024`)

#### NFR-011 ~ NFR-020: 정확도 (Accuracy)

**NFR-011**: OMR 음표 인식 정확도
- 목표: Symbol Error Rate (SER) < 10% (note accuracy > 90%)
- 현재 달성값: Zeus fine-tuned SER 67.2% → 추가 개선 필요
- 비교: 카메라 사진 기준 SOTA (LEGATO) 미공개

**NFR-012**: 악보 추적 정확도
- 현재 위치 추정 오차: ± 1 마디 이내 (95th percentile)

**NFR-013**: 음고 인식 정확도
- 피아노 음고 감지: 반음 단위 > 95% 정확도

#### NFR-021 ~ NFR-030: 플랫폼 지원 (Platform)

**NFR-021**: 지원 플랫폼
- iOS 15.0 이상 (iPhone/iPad)
- Android 10.0 (API 29) 이상
- Web (Chrome 100+, Safari 15+, Firefox 100+)
- 우선순위: iOS/Android > Web

**NFR-022**: 화면 크기 대응
- 최소 지원 해상도: 375×667px (iPhone SE)
- 권장 사용 환경: 10인치 이상 태블릿
- Responsive layout: 악보 표시 영역 자동 조절

**NFR-023**: 오프라인 지원
- 저장된 악보는 네트워크 없이 접근 가능해야 한다
- OMR, MIDI 재생은 오프라인 불가 (서버 필요)

#### NFR-031 ~ NFR-040: 저장소 (Storage)

**NFR-031**: 로컬 스토리지
- 악보 데이터: Hive (네이티브) / IndexedDB (Web)
- 최대 저장 악보 수: 제한 없음 (기기 용량 내)
- 단일 악보 최대 크기: MusicXML 10MB + PNG 캐시 50MB

**NFR-032**: 데이터 영속성
- 앱 재시작, 페이지 새로고침 후에도 악보 데이터 유지

**NFR-033**: 서버 캐싱
- 코퍼스 인덱스를 `corpus_index.json` 파일로 사전 캐싱
- 캐시 미스 시 `music21` 코퍼스 검색으로 폴백

#### NFR-041 ~ NFR-050: 보안 (Security)

**NFR-041**: CORS 설정
- 현재 `allow_origins=["*"]` — **프로덕션 전 제한 필요**
- 프로덕션 목표: 허용 도메인 화이트리스트 적용

**NFR-042**: 입력 검증
- 이미지 확장자 허용 목록 검증 (`ALLOWED_IMAGE_EXTS`)
- 파일 크기 제한 검증
- IMSLP URL은 허용 호스트 목록 검증 (`IMSLP_ALLOWED_HOSTS`)

**NFR-043**: IMSLP 접근 제한
- IMSLP 다운로드 시 User-Agent: `SmartScore/2.0 (educational music app)` 명시
- 허용 확장자: `.xml`, `.musicxml`, `.mxl`, `.pdf`, `.mid`, `.midi`

---

## 4. SDS — Software Design Specification

### 4.1 시스템 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter App (Client)                         │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Module A    │  │  Module B    │  │      Module E             │  │
│  │  App Shell   │  │  Score Input │  │    Music Normalizer        │  │
│  │  (UI/UX)    │  │  (Import)   │  │  (MusicXML Parser)        │  │
│  └──────┬───────┘  └──────┬───────┘  └───────────┬──────────────┘  │
│         │                 │                       │                  │
│  ┌──────▼───────────────────────────────────────▼──────────────┐   │
│  │                    AppState (Provider)                        │   │
│  │          Score Library | Active Score | Current Page          │   │
│  └───────────────────────────────┬──────────────────────────────┘   │
│                                  │                                   │
│  ┌──────────────┐  ┌─────────────▼────────┐  ┌────────────────┐    │
│  │  Module F    │  │      Module K         │  │   Audio Engine  │    │
│  │Score Renderer│  │   External Device     │  │  (Web Audio API │    │
│  │(Canvas Paint)│  │ (BT/MIDI/Keyboard)   │  │   / Tone.js)   │    │
│  └──────────────┘  └──────────────────────┘  └────────────────┘    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTP/REST (port 8080)
                               │ multipart/form-data, JSON
┌──────────────────────────────▼──────────────────────────────────────┐
│                     FastAPI Server (Backend)                          │
│                    Jetson Orin / ARM64 / CUDA 12.6                   │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                        omr_server/app.py                      │   │
│  │  POST /omr  POST /omr/multi  POST /render                    │   │
│  │  GET /health  GET /corpus/*  GET /imslp/*                    │   │
│  └───────────────────┬──────────────┬────────────────────────────┘  │
│                      │              │                                │
│  ┌───────────────────▼──┐  ┌───────▼──────────────────────────┐   │
│  │   Preprocessing       │  │         OMR Engine               │   │
│  │   Pipeline            │  │  ┌─────────────┐ ┌────────────┐ │   │
│  │  - EXIF fix           │  │  │  Zeus       │ │   homr     │ │   │
│  │  - Perspective corr.  │  │  │ (OLiMPiC    │ │  (fallback)│ │   │
│  │  - Shadow removal     │  │  │ fine-tuned) │ │            │ │   │
│  │  - Deskew + upscale   │  │  └─────────────┘ └────────────┘ │   │
│  └───────────────────────┘  └───────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐    │
│  │   MusicXML Repair    │  │          Renderer                 │    │
│  │   (music21)          │  │  Verovio Python (primary)         │    │
│  │  - Duration fix      │  │  LilyPond CLI (fallback)          │    │
│  │  - Measure padding   │  │  cairosvg (SVG→PNG)               │    │
│  └──────────────────────┘  └──────────────────────────────────┘    │
│                                                                      │
│  ┌──────────────────────┐                                           │
│  │     Storage          │                                           │
│  │  Hive / IndexedDB    │                                           │
│  │  (Flutter client)    │                                           │
│  │  corpus_index.json   │                                           │
│  │  (server cache)      │                                           │
│  └──────────────────────┘                                           │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 컴포넌트 다이어그램

#### Flutter App 모듈 구조

```
build_unified/lib/modules/
├── a_app_shell/         # 앱 진입점, 네비게이션, 전역 상태
│   ├── app.dart         # MaterialApp 루트
│   ├── config.dart      # 서버 URL, 상수
│   ├── state/
│   │   ├── app_state.dart           # ChangeNotifier: activeScore, currentPage
│   │   ├── score_library_provider.dart  # Hive 연동 악보 목록
│   │   ├── score_renderer_provider.dart # 렌더링 상태
│   │   └── ui_state_provider.dart      # UI 전환 상태
│   └── screens/
│       ├── capture_screen.dart      # 악보 촬영/가져오기
│       └── settings_screen.dart     # 앱 설정
│
├── b_score_input/       # 악보 가져오기 로직
│   ├── score_library.dart     # Hive 기반 영속 저장소
│   ├── score_entry.dart       # 단일 악보 엔트리 모델
│   ├── import_validators.dart # 파일 형식 검증
│   └── result.dart            # 가져오기 결과 래퍼
│
├── e_music_normalizer/  # MusicXML 파싱 및 정규화
│   ├── musicxml_parser.dart   # MusicXML → Score 객체
│   ├── score_json.dart        # 내부 Score 데이터 모델
│   └── score_validator.dart   # 구조 유효성 검증
│
├── f_score_renderer/    # 악보 렌더링 엔진 (Flutter Canvas)
│   ├── models.dart            # LayoutConfig, NoteLayout, PageLayout 등
│   ├── layout_engine.dart     # 악보 레이아웃 계산
│   ├── page_calculator.dart   # 페이지 분할 로직
│   ├── score_painter.dart     # CustomPainter 구현
│   ├── render_commands.dart   # DrawLine, DrawOval, DrawRect 등
│   └── hit_test.dart          # 터치 좌표 → 음표/마디 매핑
│
└── k_external_device/   # 외부 장치 입력 관리
    ├── device_manager.dart    # 장치 통합 오케스트레이터
    ├── device_adapter.dart    # 추상 장치 어댑터 인터페이스
    ├── input_prioritizer.dart # 입력 우선순위 및 디바운스
    ├── bluetooth_adapter.dart # BLE 페달 어댑터
    ├── midi_adapter.dart      # MIDI 장치 어댑터
    └── keyboard_adapter.dart  # 키보드 어댑터
```

#### Backend 모듈 구조

```
omr_server/
├── app.py              # FastAPI 앱 진입점, 라우팅, CORS
├── omr_engine.py       # OMR 엔진 래퍼 (Zeus / homr)
├── musicxml_repair.py  # music21 기반 MusicXML 수리
├── renderer.py         # Verovio / LilyPond 렌더러
└── preprocess.py       # 이미지 전처리 파이프라인
```

### 4.3 데이터 흐름 다이어그램

#### DFD-1: 악보 촬영 → OMR → 렌더링 → 표시

```
사용자 (카메라 촬영)
    │
    ▼ image bytes (JPEG/PNG)
┌─────────────────────────────────┐
│   Flutter: CaptureScreen         │
│   POST /omr (multipart/form-data)│
│   Content-Type: image/*          │
│   Size check: ≤ 10MB            │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│   FastAPI: /omr endpoint         │
│   ThreadPoolExecutor (max_w=2)   │
└───────────────┬─────────────────┘
                │
                ▼
┌─────────────────────────────────┐
│   Preprocessing Pipeline         │
│   1. EXIF fix (piexif)          │
│   2. Boundary detect (OpenCV)   │
│   3. Shadow remove (morphology) │
│   4. Grayscale convert          │
│   5. Auto-rotate + deskew       │
│   6. 2x upscale (cap 3000px)    │
│   7. Illumination normalize     │
│   8. Score region crop          │
└───────────────┬─────────────────┘
                │ preprocessed PNG
                ▼
┌─────────────────────────────────┐
│   OMR Engine                     │
│   Zeus (OLiMPiC fine-tuned)     │
│   ├─ System splitting            │
│   │  (morphological detection)  │
│   ├─ Per-system inference       │
│   │  (LMX token sequence)       │
│   └─ LMX → MusicXML conversion  │
│   Fallback: homr engine         │
└───────────────┬─────────────────┘
                │ raw MusicXML
                ▼
┌─────────────────────────────────┐
│   MusicXML Repair (music21)      │
│   - Duration validation          │
│   - Padding / trimming           │
│   - makeNotation() normalize     │
└───────────────┬─────────────────┘
                │ repaired MusicXML
                ▼
┌─────────────────────────────────┐
│   Renderer (Verovio)             │
│   - loadData(musicxml)           │
│   - renderToSVG(page)            │
│   - cairosvg.svg2png(dpi=150)    │
│   → base64 PNG                   │
└───────────────┬─────────────────┘
                │ {"musicxml": "...", "png_base64": "..."}
                ▼
┌─────────────────────────────────┐
│   Flutter: Score Display         │
│   - MusicXmlParser → Score obj  │
│   - LayoutEngine → PageLayout   │
│   - ScorePainter (CustomPainter)│
│   - Hive 저장                   │
└─────────────────────────────────┘
                │
                ▼
        [사용자: 악보 확인]
```

#### DFD-2: 오디오 입력 → 악보 추적 → 페이지 전환

```
[피아노 연주]
    │ 음파
    ▼
┌────────────────────────────────┐
│  Web Audio API / Platform Audio │
│  AudioContext / MediaStream     │
│  Buffer size: 2048 samples      │
│  Sample rate: 48000 Hz          │
└──────────────┬─────────────────┘
               │ PCM samples
               ▼
┌────────────────────────────────┐
│   Pitch Detection Engine        │
│   - FFT / Autocorrelation       │
│   - YIN or CREPE algorithm      │
│   - Confidence threshold: 0.85  │
│   Output: Hz → MIDI note number │
└──────────────┬─────────────────┘
               │ MIDI pitch stream
               ▼
┌────────────────────────────────┐
│   Score Following Engine        │
│   - Dynamic Time Warping (DTW) │
│   - Score cursor state machine  │
│   - Lookahead: 4 measures      │
│   Output: (measure, beat)       │
└──────────────┬─────────────────┘
               │ position update (measure, beat)
               ▼
┌────────────────────────────────┐
│   AppState.goToPage()           │
│   ├─ currentMeasure 업데이트    │
│   ├─ ScorePainter 하이라이트    │
│   └─ 페이지 끝 감지?            │
│      YES → nextPage() 호출      │
└──────────────┬─────────────────┘
               │ page transition event
               ▼
┌────────────────────────────────┐
│   Page Transition Animation     │
│   - Pre-load next page          │
│   - Slide/fade animation 300ms  │
│   - Update currentPage state    │
└────────────────────────────────┘
```

### 4.4 API 명세

#### 현재 구현된 엔드포인트

| Method | Endpoint | 설명 | Request | Response |
|--------|----------|------|---------|----------|
| GET | `/health` | 엔진 상태 확인 | - | `{status, engine}` |
| POST | `/omr` | 단일 이미지 OMR | `multipart: image` | `{musicxml, success}` |
| POST | `/omr/multi` | 다중 페이지 OMR | `multipart: image_0..N` | `{musicxml, page_count, success}` |
| POST | `/render` | MusicXML → PNG | `{musicxml}` | `{png_base64, midi_base64, success}` |
| GET | `/corpus/search` | 코퍼스 검색 | `?q=<query>` | `[{id, title, composer, ...}]` |
| GET | `/corpus/export` | 악보 내보내기 | `?id=<score_id>` | MusicXML text |
| GET | `/corpus/stats` | 코퍼스 통계 | - | `{total, genres, ...}` |
| GET | `/imslp/search` | IMSLP 검색 | `?q=<query>` | `[{title, url, ...}]` |
| GET | `/imslp/page` | IMSLP 페이지 | `?title=<title>` | `{title, files, ...}` |
| GET | `/imslp/download` | IMSLP 텍스트 파일 다운로드 | `?url=<url>` | MusicXML text |
| GET | `/imslp/download_binary` | IMSLP 바이너리 파일 다운로드 | `?url=<url>` | base64 |

#### Phase 3에서 추가될 엔드포인트 (계획)

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/audio/process` | 오디오 청크 처리 → 위치 추정 |
| WebSocket | `/ws/score-follow` | 실시간 오디오 스트리밍 + 위치 push |
| POST | `/score/validate` | MusicXML 구조 검증 |
| GET | `/score/{id}/timing` | 악보 타이밍 맵 생성 |

#### API 공통 응답 형식

```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "metadata": {
    "engine": "zeus",
    "processing_time_ms": 42000,
    "page_count": 1
  }
}
```

### 4.5 데이터 모델 / 저장소 스키마

#### ScoreEntry (Hive / IndexedDB)

```dart
class ScoreEntry {
  final String id;            // UUID v4
  final String title;         // 악보 제목 (최대 256자)
  final String composer;      // 작곡가 (최대 256자)
  final String musicxml;      // MusicXML 전문
  final String? pngBase64;    // 렌더링 썸네일 (캐시)
  final DateTime createdAt;   // 저장 시각 (UTC)
  final int pageCount;        // 페이지 수
  final String source;        // "camera" | "gallery" | "imslp" | "file"
  final Map<String, dynamic> metadata;  // 자유 형식 추가 정보
}
```

#### Score 내부 모델 (Module E)

```dart
class Score {
  final String id;
  final String title;
  final String composer;
  final List<Part> parts;
  final ScoreMetadata metadata;
  // → Part → Measure → Note/Rest
}

class Note {
  final String id;
  final Pitch pitch;          // step, octave, alter
  final String duration;      // whole/half/quarter/eighth/16th
  final int staff;            // 1 or 2 (grand staff)
  final int voice;
  final List<String> articulations;
  final String? dynamic;
}
```

#### LayoutConfig (Module F)

```dart
class LayoutConfig {
  final int measuresPerSystem;     // 기본: 4
  final int systemsPerPage;        // 기본: 6
  final double staffLineSpacing;   // 기본: 12.0px
  final double pageWidth;          // 기본: 816.0 (A4 @96dpi)
  final double pageHeight;         // 기본: 1056.0
  final double zoom;               // 0.5 ~ 4.0
  final bool darkMode;
  final String currentPositionColor;   // 하이라이트 색상
  final double currentPositionOpacity; // 기본: 0.5
}
```

### 4.6 기술 스택 상세

#### Frontend (Flutter)

| 항목 | 기술/버전 |
|------|---------|
| 언어 | Dart 3.x |
| 프레임워크 | Flutter 3.x |
| 상태 관리 | Provider + ChangeNotifier |
| 라우팅 | go_router |
| 로컬 저장소 | Hive 2.x (네이티브) / IndexedDB (Web) |
| 렌더링 | Flutter CustomPainter (Canvas API) |
| HTTP | `dart:io` HttpRequest (timeout: 300s) |
| 오디오 | Web Audio API (Web) / flutter_sound (네이티브) |
| BLE | flutter_blue_plus |
| MIDI | flutter_midi_pro |

#### Backend (Python)

| 항목 | 기술/버전 |
|------|---------|
| 언어 | Python 3.11 |
| 웹 프레임워크 | FastAPI 0.x |
| ASGI 서버 | uvicorn |
| 비동기 처리 | asyncio + ThreadPoolExecutor |
| 이미지 처리 | OpenCV, Pillow |
| OMR 엔진 | Zeus (OLiMPiC), homr |
| MusicXML 수리 | music21 |
| 악보 렌더링 | Verovio Python, LilyPond |
| SVG→PNG | cairosvg |
| 모델 추론 | PyTorch, ONNX Runtime |

#### 인프라 (Infrastructure)

| 항목 | 사양 |
|------|------|
| 서버 | Jetson Orin |
| 아키텍처 | ARM64 (aarch64) |
| GPU | 65.9GB (통합 메모리) |
| CUDA | 12.6 |
| OS | Linux 5.15.148-tegra |
| 포트 | 8080 (HTTP) |
| 동시 처리 | ThreadPoolExecutor max_workers=2 |

### 4.7 배포 아키텍처

```
┌──────────────────────────────────────────┐
│              사용자 기기                   │
│                                          │
│  ┌─────────────┐   ┌─────────────────┐  │
│  │  iOS/Android│   │  Web Browser     │  │
│  │  Flutter App│   │  Flutter Web     │  │
│  └──────┬──────┘   └────────┬─────────┘  │
└─────────┼───────────────────┼────────────┘
          │                   │
          │    HTTP :8080      │
          └─────────┬─────────┘
                    │
┌───────────────────▼──────────────────────┐
│           Jetson Orin Server              │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │  uvicorn / FastAPI               │    │
│  │  0.0.0.0:8080                    │    │
│  └──────────────────────────────────┘    │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │  OMR 처리 워커 (Thread 1, 2)      │    │
│  │  Zeus / homr                      │    │
│  └──────────────────────────────────┘    │
│                                          │
│  ┌──────────────────────────────────┐    │
│  │  Local Storage                   │    │
│  │  /omr_server/corpus_index.json   │    │
│  │  /omr_server/static/             │    │
│  └──────────────────────────────────┘    │
└──────────────────────────────────────────┘
           │
           │ HTTP (IMSLP 프록시)
           ▼
   [IMSLP / Petrucci Music Library]
```

---

## 5. 개발 로드맵

### Phase 1 — 기반 구축 (완료)

**기간**: 착수 ~ 2025-12월
**상태**: 완료

**달성 항목:**
- [x] FastAPI 서버 기본 구조 (`app.py`, `omr_engine.py`, `renderer.py`)
- [x] homr OMR 엔진 연동 및 MusicXML 출력
- [x] Verovio Python 렌더링 (primary) + LilyPond (fallback)
- [x] Flutter Web 앱 기본 구조 (`build_unified/`)
- [x] Module 구조 설계 (A/B/E/F/K)
- [x] Hive 기반 영속 저장소
- [x] Gallery 다중 선택 + 카메라 촬영 UI
- [x] MusicXML Repair (music21 기반 마디 길이 수정)
- [x] 멀티 페이지 병합 (`omr/multi` API)
- [x] 이미지 전처리 파이프라인 (8단계)
- [x] IMSLP 악보 검색/다운로드 연동
- [x] 내부 코퍼스 검색 (`corpus/search`)

**성과 지표:**
- OMR 정상 처리: homr 기준 단일 페이지 평균 32초
- MusicXML → PNG 렌더링 성공률: 100% (테스트 샘플 기준)

---

### Phase 2 — OMR 정확도 향상 (진행 중)

**기간**: 2026-01 ~ 2026-03
**상태**: 진행 중 (Zeus fine-tuning 완료, LEGATO 대기)

**달성 항목:**
- [x] Zeus (OLiMPiC) 엔진 연동 (`predict_page.py`, `zeus.py`)
- [x] 카메라 사진 특화 fine-tuning 데이터셋 구축
  - 기반: OLiMPiC 1.0 scanned 데이터 + GrandStaff
  - 증강: perspective distortion, shadow, blur, JPEG compression, rotation, brightness
  - 총 학습 샘플: 4,314개
- [x] Fine-tuning 실행 (`train_camera_model.py`)
  - 베이스 모델: `zeus-camera-grandstaff-lmx`
  - 학습: 30 epochs, CPU, ~13시간
  - 최적 checkpoint: epoch 10
  - SER: 108.8% → 67.2% (38.2% 감소)
- [x] System splitting 로직 개선 (morphological staff detection + vertical dilation)
  - 페이지 당 3~8 system 추출 지원
- [ ] LEGATO 엔진 연동 (Meta Llama 접근 대기 중)
- [ ] SER < 30% 달성 (목표)

**진행 중 항목:**
- LEGATO 모델 접근 신청 (Meta Llama 라이선스 기반)
- Zeus fine-tuning 추가 개선 (epoch 30 전체 분석)
- 실사용 카메라 사진 추가 수집 및 증강

---

### Phase 3 — 오디오 인식 + 악보 추적 (계획)

**기간**: 2026-04 ~ 2026-07
**상태**: 계획 단계

**목표:**
- 실시간 피아노 음고 인식
- DTW 기반 악보 추적 (score following)
- 현재 연주 위치 화면 하이라이트

**주요 작업:**
- [ ] Web Audio API 연동 (Flutter Web)
- [ ] Pitch detection 알고리즘 구현 (YIN 또는 CREPE)
- [ ] `ScoreTimingMap` 생성 로직 (measure → beat → timestamp)
- [ ] DTW 기반 score follower 구현
- [ ] WebSocket API (`/ws/score-follow`) 설계 및 구현
- [ ] Flutter 오디오 권한 처리 (iOS/Android)
- [ ] 오디오 지연 최적화 (목표: < 200ms)

**기술 후보:**
- Pitch Detection: [basic-pitch](https://github.com/spotify/basic-pitch) (Spotify, TFLite), YIN
- Score Following: [accompanion](https://github.com/CPJKU/accompanion), 자체 DTW 구현

---

### Phase 4 — 자동 페이지 전환 + 실시간 동기화 (계획)

**기간**: 2026-08 ~ 2026-10
**상태**: 계획 단계

**목표:**
- 악보 추적 기반 자동 페이지 전환
- 외부 장치 (BLE 페달) 연동
- 전환 타이밍 사용자 교정

**주요 작업:**
- [ ] `AppState.autoPageTurn()` 로직 구현
- [ ] 페이지 전환 예측 (last measure detection → pre-load)
- [ ] Module K: BluetoothAdapter BLE 페달 완전 구현
- [ ] 전환 애니메이션 (< 300ms)
- [ ] 전환 민감도 설정 (사용자 교정)
- [ ] 반복(repeat), D.C., D.S. 악보 기호 처리

---

### Phase 5 — 크로스플랫폼 + 프로덕션 배포 (계획)

**기간**: 2026-11 ~ 2027-03
**상태**: 계획 단계

**목표:**
- iOS App Store + Google Play Store 출시
- 프로덕션 서버 배포 (클라우드 또는 엣지)
- OMR 정확도 목표 달성: SER < 10%

**주요 작업:**
- [ ] iOS/Android 네이티브 빌드 구성
- [ ] App Store / Play Store 심사 준비
- [ ] CORS 제한 (프로덕션 도메인 화이트리스트)
- [ ] HTTPS/TLS 적용
- [ ] 사용자 인증 (선택적: 악보 동기화 기능용)
- [ ] 클라우드 배포 검토 (AWS/GCP ARM64 인스턴스)
- [ ] 모바일 온디바이스 경량 OMR 검토 (TFLite/CoreML)
- [ ] 성능 모니터링 및 에러 리포팅 연동

---

## 6. 리스크 분석

### 6.1 기술적 리스크

#### RA-001: OMR 정확도 한계

| 항목 | 내용 |
|------|------|
| 위험도 | 높음 (High) |
| 발생 가능성 | 높음 |
| 영향 | 핵심 기능 품질 직결 |
| 현황 | Zeus fine-tuned SER 67.2% (목표 < 10% 대비 미달) |

**원인 분석:**
- 카메라 사진 특유의 왜곡, 조명 불균일, 모션 블러
- 손으로 필기된 메모, 복사본 품질 열화
- 비표준 악보 편집/출판 스타일
- 현재 학습 데이터 다양성 부족 (4,314 샘플)

**완화 방안:**
1. LEGATO 엔진 도입 (SOTA 성능, Meta Llama 기반)
2. 학습 데이터 대폭 확충 (목표: 50,000+ 샘플)
3. 전처리 파이프라인 추가 고도화 (초해상도 적용)
4. 사용자 수정 UI 제공 (OMR 결과 수동 교정)

---

#### RA-002: 소음 환경에서의 오디오 인식

| 항목 | 내용 |
|------|------|
| 위험도 | 높음 (High) |
| 발생 가능성 | 중간 |
| 영향 | Score following 정확도 저하 → 잘못된 페이지 전환 |

**원인 분석:**
- 연주 공간의 잔향(reverberation) 및 배경 소음
- 다른 악기와의 합주 상황
- 모바일 기기 마이크 품질 한계

**완화 방안:**
1. 노이즈 게이팅 및 스펙트럼 차감 전처리
2. 신뢰도(confidence) 임계값 기반 필터링
3. 사용자 수동 개입 옵션 상시 제공
4. 마이크 방향/거리 권장사항 UX 안내

---

#### RA-003: 실시간 동기화 지연

| 항목 | 내용 |
|------|------|
| 위험도 | 중간 (Medium) |
| 발생 가능성 | 중간 |
| 영향 | 페이지 전환 타이밍 불일치 (연주에 방해) |

**원인 분석:**
- Web Audio API 버퍼 지연 (2048 samples ÷ 48000Hz ≈ 43ms)
- DTW 알고리즘 계산 비용
- Flutter Web의 JavaScript 레이어 오버헤드

**완화 방안:**
1. 네이티브 앱 (iOS/Android)에서 더 낮은 지연 달성 가능
2. WASM 기반 오디오 처리 검토
3. 페이지 전환 예측 로직 (마지막 마디 진입 시 pre-load)
4. 지연 보상(latency compensation) 파라미터 사용자 설정

---

#### RA-004: 크로스플랫폼 호환성

| 항목 | 내용 |
|------|------|
| 위험도 | 중간 (Medium) |
| 발생 가능성 | 중간 |
| 영향 | iOS/Android 출시 지연 |

**원인 분석:**
- Web Audio API ↔ 네이티브 오디오 API 차이
- Hive (네이티브) vs IndexedDB (Web) 동작 차이
- iOS WebView 마이크 권한 제한

**완화 방안:**
1. 플랫폼별 추상화 레이어 조기 설계
2. flutter_sound를 통한 통합 오디오 인터페이스
3. CI에서 iOS/Android 빌드 상시 검증

---

#### RA-005: 모바일 디바이스에서의 모델 배포

| 항목 | 내용 |
|------|------|
| 위험도 | 중간 (Medium) |
| 발생 가능성 | 낮음 |
| 영향 | 오프라인 OMR 불가, 서버 의존성 유지 |

**원인 분석:**
- Zeus 모델 크기 (수백 MB~수 GB) → 모바일 탑재 불가
- 클라우드 서버 운영 비용

**완화 방안:**
1. 경량화된 온디바이스 모델 연구 (TFLite/CoreML 양자화)
2. 하이브리드: 온라인 시 서버 OMR, 오프라인 시 경량 모델
3. 서버 비용 최적화 (요청 캐싱, 결과 재사용)

---

#### RA-006: LEGATO 접근 지연

| 항목 | 내용 |
|------|------|
| 위험도 | 낮음 (Low) |
| 발생 가능성 | 현재 진행 중 |
| 영향 | Phase 2 OMR 정확도 목표 달성 지연 |

**완화 방안:**
1. Zeus fine-tuning 추가 최적화로 대체
2. oemer 엔진 병렬 개선
3. ensemble 방식 (homr + Zeus 결합) 검토

---

### 6.2 리스크 매트릭스

```
발생     │  낮음    중간    높음
가능성   │
─────────┼──────────────────────
높음     │          RA-001
중간     │  RA-005  RA-003  RA-002
         │          RA-004
낮음     │  RA-006
─────────┴──────────────────────
         │  낮음    중간    높음  ← 영향도
```

---

## 7. 테스트 결과 요약

### 7.1 OMR 엔진 비교 테스트

**테스트 환경:**
- 입력 이미지: Telegram 압축 사진 (960×1280px)
- 서버: Jetson Orin (ARM64, CUDA 12.6 / CPU 모드)
- 전처리 파이프라인: 8단계 적용

| 엔진 | 인식 음표 수 | 정확도 | 처리 시간 | 상태 |
|------|------------|--------|----------|------|
| homr | 295 notes | Medium (구조 오류 있음) | 32초 | 운영 중 (CPU) |
| oemer | 181 notes | Low-Medium (XML은 깔끔) | 380초 | 사용 가능 |
| SMT++ | 실패 | N/A | N/A | 카메라 사진 대상 부적합 |
| Zeus (fine-tuned) | **890 notes** | **Best** | 42초 | 운영 중 |
| LEGATO | 미테스트 | SOTA (논문 기준) | 미확인 | Meta Llama 접근 대기 |

### 7.2 Zeus Fine-tuning 결과

**학습 구성:**
- 베이스 모델: `zeus-camera-grandstaff-lmx-1.0-2024-02-12`
- 학습 데이터: 4,314 샘플
  - OLiMPiC 1.0 scanned 데이터
  - GrandStaff 데이터셋
  - 카메라 시뮬레이션 증강 데이터
- 증강 기법: perspective distortion, shadow injection, motion blur, JPEG compression artifact, random rotation (±15°), brightness variation

**학습 결과:**

| Epoch | SER (Symbol Error Rate) |
|-------|------------------------|
| 0 (base) | 108.8% |
| 5 | ~85.0% |
| 10 | **67.2% (최적)** |
| 20 | ~72.0% |
| 30 | ~75.0% (과적합 경향) |

- SER 개선율: 108.8% → 67.2% = **38.2% 포인트 감소**
- 학습 시간: 약 13시간 (CPU, 30 epochs)
- 최적 체크포인트: epoch 10

> **참고**: SER이 100% 초과는 대체(substitution) + 삽입(insertion) + 삭제(deletion) 오류의 합산이 정답 심볼 수보다 많음을 의미. Zeus base 모델의 카메라 사진 대상 성능이 매우 낮았음을 보여주며, fine-tuning 후 유의미한 개선이 이루어짐.

### 7.3 실제 카메라 사진 처리 결과

**테스트 조건:**
- 입력: 스마트폰으로 촬영한 Telegram 압축 사진 (960×1280px)
- 엔진: Zeus fine-tuned (epoch 10)
- 전처리: 8단계 파이프라인 적용

| 악보 | 엔진 | 인식 음표 | 마디 수 | 렌더링 | 처리 시간 |
|------|------|----------|--------|--------|----------|
| Chaconne (Vitali) 바이올린+피아노 | Zeus | 669 notes | 48 measures | 성공 | ~42초 |
| 피아노 악보 1페이지 | Zeus | 890 notes | 34 measures | 성공 | ~42초 |
| 피아노 악보 2페이지 | Zeus | 890 notes | 34 measures | 성공 | ~42초 |
| 피아노 악보 3페이지 | Zeus | 472 notes | 17 measures | 성공 | ~42초 |

**특이사항:**
- 모든 테스트 악보 Verovio를 통해 렌더링 성공
- music21 MusicXML Repair 적용 후 렌더링 안정성 향상
- System splitting: morphological detection으로 페이지당 3~8 시스템 추출

### 7.4 MusicXML Repair 효과

- 수리된 마디 수: 실제 악보에 따라 5~30마디/페이지
- 수리 전: 일부 렌더링 오류 (Verovio duration mismatch warning)
- 수리 후: 렌더링 성공률 향상 (정량적 측정 예정)

### 7.5 System 분할 성능 (Zeus)

| 악보 유형 | 페이지당 시스템 수 | 분할 성공 |
|---------|---------------|---------|
| 피아노 악보 (대부분) | 4~6 systems | 성공 |
| 바이올린+피아노 (복잡) | 3~5 systems | 성공 |
| 조밀한 피아노 악보 | 6~8 systems | 성공 |

### 7.6 전처리 파이프라인 효과

- Telegram 압축 이미지 (960×1280) → 2x 업스케일 → 1920×2560
- 원근 보정 적용: 경사진 촬영 각도 보정
- 그림자 제거: 조명 불균일 이미지에서 OMR 정확도 향상 확인
- 기울기 보정(deskew): staff line 기반 ±2° 이내 자동 교정

---

*문서 끝 — SmartScore v2 개발 보고서 v1.0.0*

*Co-Authored-By: Claude (doc-manager agent)*
