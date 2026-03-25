# SmartScore v2 — 할일 목록

작성일: 2026-03-25

---

## 🔴 즉시 적용 (1-2주)

- [ ] **flutter_soloud** — Tone.js 대체, 네이티브 저지연 오디오 엔진
- [ ] **flutter_midi_pro + Salamander Grand Piano SF2** — 진짜 피아노 소리 MIDI 재생
- [ ] **IMSLP API 통합** — 210,000+ 무료 악보 인앱 검색/다운로드
- [ ] **Halbestunde OMR API** — 클라우드 OMR 대안 테스트 (REST API)
- [ ] **Verovio glyphnames.json 수정** — 복잡한 MusicXML 렌더링 크래시 해결
- [ ] **브라우저 캐시 문제** — 서비스 워커 완전 비활성화 또는 버전 관리
- [ ] **imported 악보 영구 저장** — localStorage 또는 IndexedDB (웹)
- [ ] **모바일 소리 테스트** — Tone.js → flutter_soloud 전환 후 검증

## 🟡 핵심 차별화 (1-2개월)

- [ ] **LEGATO SOTA OMR** — Meta Llama 승인 후 BTS SWIM 비교 테스트
- [ ] **Spotify Basic Pitch (TFLite)** — 온디바이스 Audio-to-MIDI (마이크 → MIDI)
- [ ] **flutter_detect_pitch** — 실시간 피치 감지 (연습 피드백)
- [ ] **Matchmaker Score Following** — 실시간 악보 위치 추적 (ISMIR 2025)
- [ ] **ReadScoreLib SDK** — PlayScore 상용 OMR (네이티브 iOS/Android)
- [ ] **alphaTab** — 기타 TAB 렌더링 확장
- [ ] **flutter_midi_command** — 외부 MIDI 키보드/페달 연결
- [ ] **FluidSynth FFI** — 고품질 다악기 합성 (피아노 외 관악/현악)
- [ ] **OMR 전처리 강화** — 워터마크 제거 UNet + DocTr 문서 보정
- [ ] **OMR 앙상블** — homr + Audiveris 결과 병합
- [ ] **드럼 타보 인식** — Percussion clef 감지 + drum map
- [ ] **가사 OCR** — 스태프 아래 텍스트 추출 + 음표 연결
- [ ] **코드 네임 OCR** — 스태프 위 텍스트 추출 + regex 파싱

## 🟢 고급 기능 (2-4개월)

- [ ] **AirPods 헤드턴 페이지 넘기기** — CoreMotion API (iOS)
- [ ] **IMSLP 인앱 통합** — Piascore 스타일 악보 브라우저
- [ ] **Hooktheory API** — 코드 진행 분석/추천
- [ ] **music21 서버** — 자동 조옮김, 화성 분석
- [ ] **AI 반주 생성** — Suno/Udio API 연동 (프리미엄)
- [ ] **실시간 협업** — Firebase/Supabase 앙상블 악보 공유
- [ ] **자동 세로 스크롤** — BPM 연동 텔레프롬프터 모드
- [ ] **Half-page turn** — forScore 스타일 페이지 절반 넘김
- [ ] **얼굴 제스처 페이지 넘김** — ML Kit 윙크 감지 (Piascore 스타일)
- [ ] **주석 레이어** — 연습용/공연용 주석 분리 (forScore 스타일)
- [ ] **iOS/iPad 빌드** — TestFlight 배포
- [ ] **Android APK** — Play Store 배포
- [ ] **다크 모드 / 세피아 모드** — 야간 연주 지원

## 🔵 연구/실험 (장기)

- [ ] **TrOMR / SMT++ 벤치마크** — LEGATO와 정확도 비교
- [ ] **온디바이스 OMR** — ONNX Runtime + homr 모델 TFLite 변환
- [ ] **Audio-informed OMR** — 오디오 녹음 + OMR 결과 융합
- [ ] **YourMT3+** — 서버사이드 멀티트랙 전사
- [ ] **커스텀 OMR 데이터셋** — MuseScore 합성 데이터로 fine-tuning

---

## 완료된 항목

- [x] Verovio JS 악보 렌더링 (demo scores)
- [x] MIDI 재생 (Tone.js FM 합성)
- [x] MusicXML 파일 임포트 (웹)
- [x] homr OMR 엔진 서버 구축
- [x] LilyPond 서버사이드 렌더링 (MusicXML → PNG)
- [x] OMR 전처리 (워터마크 제거 + CLAHE + deskew)
- [x] 이미지 스캔 + 카메라 촬영 UI
- [x] 로딩 팝업 (진행률 + 스핀)
- [x] 비-XML 파일 거부 메시지
- [x] PRD, UI_SPEC, 경쟁분석 문서
- [x] 30개+ 경쟁 앱 분석
