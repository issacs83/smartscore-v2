# 테스트 샘플 등록 방식 가이드

## 검토된 접근 방식

### 1. Seed Data (자동 로드)
- 앱 최초 실행 시 `test_assets/`의 샘플을 자동으로 ScoreLibrary에 등록
- **장점**: 별도 조작 불필요, 항상 테스트 데이터 존재
- **단점**: 프로덕션 빌드에 테스트 데이터가 포함될 위험, 사용자 라이브러리를 오염시킴

### 2. Debug 메뉴 (수동 로드) — 권장
- Debug 화면에서 "테스트 샘플 로드" 버튼을 통해 수동으로 등록
- **장점**: 테스트 환경과 프로덕션 환경 분리, 필요할 때만 로드, 선택적 로드 가능
- **단점**: 테스트마다 수동 조작 필요 (자동화 가능)

### 3. Sample Import 버튼 (캡처 화면)
- 캡처 화면에 "샘플 가져오기" 버튼 추가
- **장점**: 사용자 흐름에 자연스럽게 통합
- **단점**: UI 복잡도 증가, 프로덕션에 불필요한 버튼 노출

## 권장: Debug 메뉴 방식

테스트 단계에서는 **Debug 메뉴** 방식이 가장 적합합니다.

### 동작 흐름

```
1. 앱 실행 (Debug 모드)
2. Settings 화면 > "Debug" 탭 진입
3. "테스트 샘플" 섹션 표시
4. "샘플 목록 새로고침" 버튼
   → test_assets/sample_manifest.json 로드
   → 등록 가능한 샘플 목록 표시
5. 각 샘플 옆에 "로드" / "삭제" 버튼
   → "로드" 클릭 시:
     a. original/ 폴더의 페이지 이미지를 앱 저장소에 복사
     b. metadata/score_info.json 읽어 ScoreEntry 생성
     c. ScoreLibrary에 등록
     d. 상태 표시: "로드됨"
   → "삭제" 클릭 시:
     a. ScoreLibrary에서 해당 항목 제거
     b. 복사된 이미지 파일 삭제
     c. 상태 표시: "미등록"
6. "전체 로드" / "전체 삭제" 버튼으로 일괄 처리
```

### 구현 위치

```
modules/A_app_shell/lib/screens/debug_screen.dart
  └─ TestSampleSection 위젯 추가
     ├─ _loadManifest()    — manifest 파일 읽기
     ├─ _loadSample()      — 개별 샘플 로드
     ├─ _removeSample()    — 개별 샘플 삭제
     └─ _loadAllSamples()  — 전체 로드
```

### 자동 테스트 연동

```dart
// 테스트 코드에서 직접 호출 가능
final loader = TestSampleLoader(manifestPath: 'test_assets/sample_manifest.json');
await loader.loadSample('beethoven_op14_no2_mov1');

// 테스트 완료 후 정리
await loader.removeAllSamples();
```

### Debug 모드 분리

```dart
// config.dart에서 Debug 모드 제어
class AppConfig {
  static const bool enableTestSamples = bool.fromEnvironment(
    'ENABLE_TEST_SAMPLES',
    defaultValue: false,
  );
}
```

프로덕션 빌드 시 `--dart-define=ENABLE_TEST_SAMPLES=false`로 테스트 샘플 기능을 완전히 비활성화할 수 있습니다.
