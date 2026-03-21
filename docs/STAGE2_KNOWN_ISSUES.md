# Stage 2 알려진 이슈

## 2.1 integration_test 5건 실패
- **원인**: AppState.initialize()가 실제 모듈 인스턴스를 생성하면서 ScoreLibrary가 파일시스템 접근 필요. 테스트 환경에서 './smartscore_data' 디렉터리 미존재.
- **해결 방향**: AppState에 테스트용 팩토리 메서드 추가 (AppState.forTesting()) 또는 ScoreLibrary에 in-memory 모드 추가
- **심각도**: 낮음 (프로덕션 기능 무관, 테스트 환경 전용)
- **트랙**: Stage 2.1 안정화

## 2.2 기존 실패 24건
(Module K, F, E 기존 이슈 — Phase 1 잔여)
