# Module C ↔ Flutter 브릿지 사양서

SmartScore v2에서 Python 기반 Module C (Score Image Restoration)를 Flutter 앱에서 호출하고 결과를 표시하기 위한 통합 사양.

---

## 1. 입력 이미지 형식

### 지원 형식

| 항목 | 사양 |
|------|------|
| 파일 형식 | JPEG (.jpg, .jpeg), PNG (.png) |
| 색상 공간 | RGB, RGBA, Grayscale |
| 최소 해상도 | 200 x 200 px |
| 최대 해상도 | 10,000 x 10,000 px (100 MP) |
| 최대 파일 크기 | 50 MB (HTTP 서버 제한) |
| dtype | uint8 (0-255) |

### 권장 촬영 조건

- 해상도: 2000 x 2800 px 이상 (A4 기준 약 300 DPI)
- 조명: 균일한 조명, 그림자/플래시 최소화
- 각도: 정면 촬영 (기울기 30도 이내)
- 초점: 선명한 이미지 (Laplacian variance > 100)

---

## 2. 출력 파일 목록

### 최종 출력

| 파일명 | 설명 | 형식 |
|--------|------|------|
| `binary_final.png` | 이진화된 최종 이미지 (전경=255, 배경=0) | PNG, uint8, (H,W), {0,255} |
| `grayscale_final.png` | 기하 보정 후 그레이스케일 이미지 | PNG, uint8, (H,W), [0,255] |
| `quality_score.json` | 품질 점수 및 메타데이터 | JSON |

### 중간 단계 출력 (`save_intermediates=true` 시)

| 파일명 | 파이프라인 단계 | 설명 |
|--------|----------------|------|
| `page_detected.png` | Step 1 | 페이지 경계 감지 시각화 (녹색 사각형) |
| `perspective.png` | Step 2 | 원근 보정 후 이미지 |
| `deskewed.png` | Step 3-4 | 기울기 보정 후 이미지 |
| `grayscale.png` | Step 5 | 그레이스케일 변환 결과 |
| `shadow_removed.png` | Step 6 | 그림자 제거 후 이미지 |
| `contrast.png` | Step 7 | 대비 향상 후 이미지 |
| `binary.png` | Step 8 | 이진화 결과 |

---

## 3. Metadata JSON 구조

`quality_score.json` 파일 구조:

```json
{
  "timestamp": "2026-03-21T14:30:00.000000",
  "input_image": "score_photo.jpg",
  "input_shape": [2800, 2000, 3],
  "output_shape": [2750, 1980],
  "quality_score": 0.823,
  "quality_components": {
    "contrast_ratio": 0.95,
    "sharpness": 0.78,
    "line_straightness": 0.85,
    "noise_level": 0.72,
    "coverage": 0.88,
    "binarization_quality": 0.91
  },
  "skew_angle_degrees": 1.35,
  "page_detected": true,
  "processing_time_ms": 1245.67,
  "step_times_ms": {
    "detect_page_bounds": 45.2,
    "correct_perspective": 23.1,
    "detect_skew": 67.8,
    "correct_skew": 18.3,
    "convert_grayscale": 5.1,
    "remove_shadows": 89.4,
    "enhance_contrast": 12.6,
    "binarize": 965.2,
    "compute_quality": 18.9
  },
  "options": {
    "perspective_correction": true,
    "deskew": true,
    "shadow_removal": true,
    "contrast_enhancement": true,
    "binarization_method": "sauvola",
    "sauvola_k": 0.2
  },
  "intermediate_images": {
    "bounds_visualization": "page_detected.png",
    "after_perspective": "perspective.png",
    "after_deskew": "deskewed.png",
    "grayscale": "grayscale.png",
    "after_shadow_removal": "shadow_removed.png",
    "after_contrast": "contrast.png",
    "binary": "binary.png"
  },
  "output_paths": {
    "binary": "./restoration_output/binary_final.png",
    "grayscale": "./restoration_output/grayscale_final.png"
  }
}
```

---

## 4. Quality Score 정의

### 총합 공식

```
quality_score = 0.25 * contrast_ratio
             + 0.20 * sharpness
             + 0.20 * line_straightness
             + 0.15 * noise_level
             + 0.10 * coverage
             + 0.10 * binarization_quality
```

### 개별 컴포넌트

| 컴포넌트 | 가중치 | 측정 방법 | 범위 |
|----------|--------|-----------|------|
| `contrast_ratio` | 0.25 | 전경/배경 간 강도 차이 | [0.0, 1.0] |
| `sharpness` | 0.20 | Laplacian 분산 (값/500으로 정규화) | [0.0, 1.0] |
| `line_straightness` | 0.20 | Hough 선 각도 분산 (낮을수록 좋음) | [0.0, 1.0] |
| `noise_level` | 0.15 | 고주파 필터 에너지 역수 | [0.0, 1.0] |
| `coverage` | 0.10 | 전경 픽셀 비율 (15-50%가 최적) | [0.0, 1.0] |
| `binarization_quality` | 0.10 | Otsu/Adaptive와의 일치도 평균 | [0.0, 1.0] |

### 점수 해석

| 점수 범위 | 등급 | UI 색상 | OMR 예상 정확도 |
|-----------|------|---------|-----------------|
| 0.90 - 1.00 | 우수 (Excellent) | 녹색 | > 95% |
| 0.75 - 0.89 | 양호 (Good) | 녹색 | 85-95% |
| 0.60 - 0.74 | 보통 (Fair) | 노란색 | 70-85% |
| 0.40 - 0.59 | 부족 (Poor) | 주황색 | 50-70% |
| 0.00 - 0.39 | 사용 불가 (Unusable) | 빨간색 | < 50% |

---

## 5. 실패 코드 정의

| 코드 | 상수명 | 조건 | 심각도 | Flutter 처리 |
|------|--------|------|--------|-------------|
| `E-C01` | `IMAGE_TOO_SMALL` | 이미지 크기 < 200x200 | 치명적 | 재촬영 요청 다이얼로그 |
| `E-C02` | `IMAGE_TOO_LARGE` | 이미지 > 100MP | 치명적 | 다운샘플링 제안 |
| `E-C03` | `PAGE_NOT_FOUND` | 페이지 경계 미감지 | 경고 | 원근 보정 건너뜀, 계속 진행 |
| `E-C04` | `EXCESSIVE_BLUR` | Laplacian 분산 < 100 | 경고 | quality_score < 0.3, 사용자 경고 |
| `E-C05` | `EXCESSIVE_GLARE` | 밝은 픽셀(>250) > 30% | 경고 | quality_score < 0.3, 사용자 경고 |
| `E-C06` | `LOW_CONTRAST` | 전경-배경 차이 < 30 | 경고 | 대비 향상 자동 적용 |
| `E-C07` | `PARTIAL_CUT` | 경계 코너가 이미지 밖 >20% | 경고 | 원근 보정 건너뜀, 사용자 경고 |
| `E-C08` | `PROCESSING_TIMEOUT` | 처리 시간 > 30초 | 치명적 | 타임아웃 에러 표시 |
| `E-C99` | `UNEXPECTED_ERROR` | 예외 발생 | 치명적 | 일반 에러 메시지 표시 |

### Flutter 측 에러 처리 의사코드

```dart
void handleRestorationResult(Map<String, dynamic> result) {
  if (result['failure_reason'] != null) {
    final code = result['failure_reason'].substring(0, 5); // "E-C01"
    switch (code) {
      case 'E-C01':
      case 'E-C02':
        showRetakeDialog('이미지 크기가 적합하지 않습니다. 다시 촬영해주세요.');
        break;
      case 'E-C08':
        showErrorSnackbar('처리 시간이 초과되었습니다. 다시 시도해주세요.');
        break;
      default:
        showErrorSnackbar('복원 실패: ${result['failure_reason']}');
    }
    return;
  }

  if (result['quality_score'] < 0.3) {
    showWarningDialog('이미지 품질이 낮습니다. 다시 촬영을 권장합니다.');
  }
}
```

---

## 6. Flutter에서 Python Module C 호출 방식

### 방식 비교 요약

```
+------------------+------------------+------------------+------------------+
|                  | Option A         | Option B         | Option C         |
|                  | HTTP Server      | Process.run      | FFI              |
+------------------+------------------+------------------+------------------+
| 구현체           | server.py        | restore.py       | dart:ffi         |
| 통신 방식        | HTTP POST        | 프로세스 실행     | 직접 호출         |
| 지연 시간        | 중간 (네트워크)   | 높음 (프로세스)   | 낮음 (메모리)     |
| 구현 난이도      | 낮음             | 낮음              | 높음             |
| iPad 호환성      | O (로컬 서버)     | X (제한적)        | X (현재 불가)    |
| 상태 관리        | 서버가 관리       | 무상태           | 앱 내 관리       |
| 권장 시점        | MVP / 1차 구현    | 데스크탑 테스트   | 향후 최적화      |
+------------------+------------------+------------------+------------------+
```

### Option A: HTTP Server (권장 - 1차 구현)

Module C의 `server.py`를 로컬에서 실행하고, Flutter에서 HTTP로 호출하는 방식.

**아키텍처:**

```
+-------------------+     HTTP POST      +-------------------+
|                   | -----------------> |                   |
|   Flutter App     |   multipart/form   |   Python Server   |
|   (iPad/Desktop)  |   + query params   |   (server.py)     |
|                   | <----------------- |   port: 8888      |
|                   |     JSON response  |                   |
+-------------------+                    +-------------------+
        |                                        |
        v                                        v
  Module B에 저장                          OpenCV 파이프라인
  (ScoreEntry.versions)                   (restoration_engine.py)
```

**엔드포인트:**

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `GET` | `/api/health` | 서버 상태 확인 |
| `POST` | `/api/restore` | 이미지 복원 요청 |
| `GET` | `/api/images/{filename}` | 결과 이미지 다운로드 |

**요청 형식 (POST /api/restore):**

```
Content-Type: multipart/form-data
Body: image file (field name: "image")

Query Parameters:
  ?perspective=true    원근 보정 활성화
  &deskew=true         기울기 보정 활성화
  &shadows=true        그림자 제거 활성화
  &contrast=true       대비 향상 활성화
  &binarization=sauvola 이진화 방식
```

**응답 형식:**

```json
{
  "success": true,
  "quality_score": 0.823,
  "quality_components": { ... },
  "skew_angle": 1.35,
  "page_detected": true,
  "processing_time_ms": 1245.67,
  "step_times_ms": { ... },
  "output_images": {
    "binary": "/api/images/binary_final.png",
    "grayscale": "/api/images/grayscale_final.png"
  },
  "intermediate_images": {
    "bounds_visualization": "/api/images/page_detected.png",
    "after_perspective": "/api/images/perspective.png",
    ...
  }
}
```

**Flutter 호출 예시:**

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class RestorationService {
  static const String baseUrl = 'http://127.0.0.1:8888';

  Future<Map<String, dynamic>> restoreImage(
    List<int> imageBytes,
    String fileName, {
    bool perspective = true,
    bool deskew = true,
    bool shadows = true,
    bool contrast = true,
    String binarization = 'sauvola',
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/restore'
      '?perspective=$perspective'
      '&deskew=$deskew'
      '&shadows=$shadows'
      '&contrast=$contrast'
      '&binarization=$binarization'
    );

    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes(
      'image', imageBytes, filename: fileName,
    ));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    return json.decode(body) as Map<String, dynamic>;
  }

  Future<List<int>> downloadImage(String imagePath) async {
    final response = await http.get(Uri.parse('$baseUrl$imagePath'));
    return response.bodyBytes;
  }
}
```

**장점:**
- 구현이 간단하고 이미 `server.py`가 존재
- Flutter와 Python 간 의존성 분리
- 서버를 별도 머신에서 실행 가능 (향후 클라우드 확장 용이)
- CORS 지원으로 웹 빌드에서도 사용 가능

**단점:**
- 네트워크 오버헤드 (이미지 전송)
- Python 서버를 별도로 실행/관리해야 함
- iPad에서 Python 런타임 직접 실행 불가 (Mac/PC에서 서버 실행 필요)

---

### Option B: Process.run (데스크탑 테스트용)

Flutter에서 `restore.py` CLI를 직접 실행하는 방식.

**Flutter 호출 예시:**

```dart
import 'dart:io';
import 'dart:convert';

class RestorationCLI {
  final String pythonPath;
  final String restorePyPath;

  RestorationCLI({
    this.pythonPath = 'python3',
    required this.restorePyPath,
  });

  Future<Map<String, dynamic>> restoreImage(
    String inputImagePath,
    String outputDir, {
    bool perspective = true,
    bool deskew = true,
    bool shadows = true,
    bool contrast = true,
    String binarization = 'sauvola',
  }) async {
    final args = [
      restorePyPath,
      inputImagePath,
      '--output-dir', outputDir,
      if (!perspective) '--no-perspective',
      if (!deskew) '--no-deskew',
      if (!shadows) '--no-shadows',
      if (!contrast) '--no-contrast',
      '--binarization', binarization,
    ];

    final result = await Process.run(pythonPath, args);

    if (result.exitCode != 0) {
      throw Exception('Restoration failed: ${result.stderr}');
    }

    // 결과 JSON 읽기
    final jsonFile = File('$outputDir/quality_score.json');
    final jsonStr = await jsonFile.readAsString();
    return json.decode(jsonStr) as Map<String, dynamic>;
  }
}
```

**장점:**
- 서버 실행 불필요 (단발성 호출)
- 디버깅 용이 (stdout/stderr 직접 확인)
- 파일 시스템 기반으로 결과 접근 간단

**단점:**
- 프로세스 시작 오버헤드 (Python 인터프리터 로딩 ~1초)
- iOS/iPad에서 사용 불가 (Process.run 미지원)
- 데스크탑 전용 (macOS, Windows, Linux)
- 매 호출마다 OpenCV 재로딩

---

### Option C: FFI (향후 최적화)

`dart:ffi`를 통해 C/C++ 래퍼로 OpenCV를 직접 호출하는 방식.

**현재 상태:** 미구현. Python 코드를 C++로 포팅하거나, PyBind11 래퍼를 만들어야 함.

**장점:**
- 최소 지연 시간 (프로세스/네트워크 오버헤드 없음)
- 메모리 효율적 (이미지 복사 최소화)
- iOS/iPad에서도 동작 가능

**단점:**
- 구현 난이도 매우 높음
- OpenCV C++ 빌드 + 크로스 컴파일 필요
- 유지보수 부담 증가
- Python 알고리즘과 C++ 구현 동기화 필요

**권장:** MVP에서는 Option A (HTTP Server)를 사용하고, 성능 최적화가 필요한 시점에 Option C를 검토.

---

## 7. 결과를 앱에서 표시하는 흐름

### 전체 데이터 흐름

```
사용자                Flutter App              Module B            Module C
  |                      |                       |                    |
  |  1. 이미지 촬영/선택  |                       |                    |
  |--------------------->|                       |                    |
  |                      |  2. 원본 저장          |                    |
  |                      |  (originalImage)      |                    |
  |                      |---------------------->|                    |
  |                      |                       |                    |
  |                      |  3. 복원 요청          |                    |
  |                      |  (HTTP POST)          |                    |
  |                      |---------------------------------------------->|
  |                      |                       |                    |
  |                      |           로딩 인디케이터 표시                |
  |  <loading spinner>   |                       |                    |
  |                      |                       |                    |
  |                      |  4. 결과 수신          |                    |
  |                      |  (JSON + 이미지)       |                    |
  |                      |<----------------------------------------------|
  |                      |                       |                    |
  |                      |  5. 복원본 저장         |                    |
  |                      |  (restoredImage)      |                    |
  |                      |---------------------->|                    |
  |                      |                       |                    |
  |  6. 비교 화면 표시    |                       |                    |
  |<---------------------|                       |                    |
```

### 단계별 상세

#### Step 1: 사용자가 이미지 촬영/선택

```dart
// CaptureScreen에서 이미지 소스 선택
// - 카메라 촬영 (image_picker 플러그인)
// - 갤러리에서 선택
// - 파일 시스템에서 선택 (file_picker)
final imageBytes = await pickImage();
final fileName = 'score_${DateTime.now().millisecondsSinceEpoch}.jpg';
```

#### Step 2: Module B에 원본 저장 (VersionType.originalImage)

```dart
// ScoreEntry 생성 및 원본 이미지 저장
final entry = ScoreEntry(
  title: fileName,
  sourceType: SourceType.image,
);

final updatedEntry = entry.addVersion(
  VersionType.originalImage,
  VersionInfo(
    filePath: savedFilePath,
    createdAt: DateTime.now().toUtc(),
    sizeBytes: imageBytes.length,
  ),
);

await library.addEntry(updatedEntry);
```

#### Step 3: Module C 호출 (HTTP POST)

```dart
final restorationService = RestorationService();
final result = await restorationService.restoreImage(
  imageBytes, fileName,
  perspective: settings.perspectiveEnabled,
  deskew: settings.deskewEnabled,
  shadows: settings.shadowRemovalEnabled,
  contrast: settings.contrastEnabled,
  binarization: settings.binarizationMethod,
);
```

#### Step 4: 결과 수신

```dart
if (result['success'] == true) {
  final qualityScore = result['quality_score'] as double;
  final binaryImagePath = result['output_images']['binary'] as String;
  final grayscaleImagePath = result['output_images']['grayscale'] as String;

  // 이미지 다운로드
  final binaryBytes = await restorationService.downloadImage(binaryImagePath);
  final grayscaleBytes = await restorationService.downloadImage(grayscaleImagePath);
}
```

#### Step 5: Module B에 복원본 저장 (VersionType.restoredImage)

```dart
// 복원된 이미지를 로컬에 저장
final restoredPath = await saveToLocal(binaryBytes, 'restored_$fileName');

final updatedEntry = entry.addVersion(
  VersionType.restoredImage,
  VersionInfo(
    filePath: restoredPath,
    createdAt: DateTime.now().toUtc(),
    sizeBytes: binaryBytes.length,
    metadata: {
      'quality_score': qualityScore,
      'skew_angle': result['skew_angle'],
      'processing_time_ms': result['processing_time_ms'],
      'quality_components': result['quality_components'],
    },
  ),
);
```

#### Step 6: UI에 원본/복원본 비교 표시

```dart
// ScoreViewerScreen에서 비교 모드 표시
// 원본 이미지와 복원된 이미지를 나란히 또는 오버레이로 표시
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ComparisonView(
    originalImage: originalImageBytes,
    restoredImage: binaryBytes,
    qualityScore: qualityScore,
    qualityComponents: result['quality_components'],
    intermediates: result['intermediate_images'],
  ),
));
```

---

## 8. iPad에서의 UI 연결 포인트

### 화면 레이아웃 (가로 모드, 분할 뷰)

```
+-----------------------------------------------------------------------+
|  SmartScore                              [설정] [닫기]                  |
+-----------------------------------------------------------------------+
|                          |                                             |
|   +-------------------+ |  +---------------------------------------+  |
|   |                   | |  |                                       |  |
|   |   원본 이미지      | |  |   복원된 이미지 (binary/grayscale)     |  |
|   |                   | |  |                                       |  |
|   |                   | |  |                                       |  |
|   |                   | |  |                                       |  |
|   +-------------------+ |  +---------------------------------------+  |
|                          |                                             |
|  +-----------------------------------------------------------------------+
|  | Quality Score: 0.823  [=============================    ] 82.3%    |  |
|  +-----------------------------------------------------------------------+
|  |                                                                     |  |
|  | 세부 점수:                                                          |  |
|  | contrast    [========================]  0.95                        |  |
|  | sharpness   [===================]       0.78                        |  |
|  | straightness[=====================]     0.85                        |  |
|  | noise       [=================]         0.72                        |  |
|  | coverage    [======================]    0.88                        |  |
|  | binarization[=======================]   0.91                        |  |
|  +-----------------------------------------------------------------------+
+-----------------------------------------------------------------------+
|  [원근 보정: ON] [기울기 보정: ON] [그림자 제거: ON] [대비 향상: ON]      |
|  [이진화: Sauvola v]   [중간 단계 보기]   [다시 처리]                    |
+-----------------------------------------------------------------------+
```

### UI 컴포넌트 상세

#### 8.1 원본 이미지 표시

```dart
/// 원본 이미지를 표시하는 위젯
/// ScoreEntry의 VersionType.originalImage에서 로드
class OriginalImageView extends StatelessWidget {
  final VersionInfo originalVersion;
  // Image.file() 또는 Image.memory()로 표시
  // 핀치 줌/팬 지원 (InteractiveViewer)
}
```

- `ScoreEntry.getVersion(VersionType.originalImage)`에서 파일 경로 획득
- `InteractiveViewer`로 줌/팬 지원
- 촬영 시점, 파일 크기 등 메타데이터 오버레이

#### 8.2 복원된 binary/grayscale 표시

```dart
/// 복원 결과를 토글 가능하게 표시
/// binary: 흑백 이진 이미지 (음표/오선 확인용)
/// grayscale: 보정된 그레이스케일 (세밀한 확인용)
class RestoredImageView extends StatelessWidget {
  final Uint8List binaryImage;
  final Uint8List grayscaleImage;
  final bool showBinary; // 토글: binary vs grayscale
}
```

- 토글 버튼으로 binary/grayscale 전환
- binary: 최종 이진화 결과 (오선, 음표 확인)
- grayscale: 기하 보정된 그레이스케일 (세부 확인)

#### 8.3 Quality Score 시각화 (게이지/바)

```dart
/// 품질 점수를 시각적으로 표시하는 위젯
class QualityScoreGauge extends StatelessWidget {
  final double overallScore;        // 0.0 - 1.0
  final Map<String, double> components;

  Color _getScoreColor(double score) {
    if (score >= 0.90) return Colors.green;
    if (score >= 0.75) return Colors.green.shade300;
    if (score >= 0.60) return Colors.yellow.shade700;
    if (score >= 0.40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLabel(double score) {
    if (score >= 0.90) return '우수';
    if (score >= 0.75) return '양호';
    if (score >= 0.60) return '보통';
    if (score >= 0.40) return '부족';
    return '사용 불가';
  }
}
```

- 전체 점수: 원형 게이지 또는 큰 프로그레스 바
- 개별 컴포넌트: 수평 바 차트 (각각 라벨 + 바 + 수치)
- 색상 코딩: 녹색/노란색/주황색/빨간색
- 점수 < 0.3일 때 "다시 촬영" 버튼 자동 표시

#### 8.4 Intermediate 단계별 비교 슬라이더

```dart
/// 중간 처리 단계를 슬라이더로 비교할 수 있는 위젯
class IntermediateComparisonSlider extends StatefulWidget {
  final Map<String, Uint8List> intermediateImages;
  // 단계: original → page_detected → perspective → deskewed
  //       → grayscale → shadow_removed → contrast → binary
}
```

- 좌우 슬라이드로 "처리 전" vs "처리 후" 비교
- 단계 선택 드롭다운 또는 스텝 인디케이터
- 각 단계의 처리 시간(ms) 표시
- 파이프라인 시각화:

```
  원본 → 페이지감지 → 원근보정 → 기울기보정 → 그레이스케일
   |         |           |          |            |
   v         v           v          v            v
  [img]    [img]       [img]      [img]        [img]

  → 그림자제거 → 대비향상 → 이진화 → 최종결과
       |           |         |         |
       v           v         v         v
     [img]       [img]     [img]     [img]
```

#### 8.5 복원 옵션 설정

```dart
/// 복원 옵션을 설정할 수 있는 패널
class RestorationOptionsPanel extends StatefulWidget {
  // 토글 스위치:
  //   - 원근 보정 (enable_perspective_correction)
  //   - 기울기 보정 (enable_deskew)
  //   - 그림자 제거 (enable_shadow_removal)
  //   - 대비 향상 (enable_contrast_enhancement)
  //
  // 드롭다운:
  //   - 이진화 방식: Sauvola / Otsu / Adaptive
  //
  // 슬라이더:
  //   - Sauvola K 값: 0.1 - 0.5 (기본값: 0.2)
  //
  // 버튼:
  //   - [다시 처리] → 변경된 옵션으로 Module C 재호출
  //   - [기본값 복원] → 모든 옵션 초기화
}
```

- 각 토글을 변경하면 실시간 미리보기는 하지 않음 (처리 시간이 1-2초)
- "다시 처리" 버튼을 눌러야 Module C 재호출
- 옵션 변경 시 이전 결과와 새 결과 비교 가능

---

## 9. Module B와의 데이터 저장 연동

### VersionType 매핑

| Module C 출력 | Module B VersionType | 설명 |
|---------------|---------------------|------|
| 원본 이미지 | `VersionType.originalImage` | 촬영/선택한 원본 |
| binary_final.png | `VersionType.restoredImage` | 이진화된 복원 결과 |

### metadata 저장

`VersionInfo.metadata`에 Module C 결과 메타데이터를 저장:

```dart
VersionInfo(
  filePath: restoredImagePath,
  createdAt: DateTime.now().toUtc(),
  sizeBytes: restoredBytes.length,
  metadata: {
    'quality_score': 0.823,
    'quality_components': {
      'contrast_ratio': 0.95,
      'sharpness': 0.78,
      'line_straightness': 0.85,
      'noise_level': 0.72,
      'coverage': 0.88,
      'binarization_quality': 0.91,
    },
    'skew_angle': 1.35,
    'page_detected': true,
    'processing_time_ms': 1245.67,
    'restoration_options': {
      'perspective': true,
      'deskew': true,
      'shadows': true,
      'contrast': true,
      'binarization': 'sauvola',
    },
  },
);
```

---

## 10. 서버 관리

### 서버 시작/종료

```bash
# 서버 시작
cd modules/C_score_image_restoration/
python server.py --host 127.0.0.1 --port 8888

# 헬스 체크
curl http://127.0.0.1:8888/api/health
```

### Flutter 앱에서 서버 상태 확인

```dart
class RestorationService {
  Future<bool> isServerAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
```

### 보안 설정

| 항목 | 환경 변수 | 기본값 |
|------|----------|--------|
| CORS Origin | `CORS_ORIGIN` | `http://localhost:8080` |
| API Token | `RESTORATION_API_TOKEN` | (빈 문자열 = 인증 없음) |
| 최대 업로드 크기 | (하드코딩) | 50 MB |

---

## 부록: 향후 확장 계획

1. **클라우드 서버 배포**: `server.py`를 Docker 컨테이너로 패키징하여 클라우드에서 실행
2. **WebSocket 지원**: 실시간 처리 진행률 표시 (현재는 HTTP 요청/응답만 지원)
3. **배치 처리**: 여러 페이지를 한 번에 처리하는 UI 지원
4. **캐싱**: 동일 이미지에 대한 중복 처리 방지 (해시 기반)
5. **FFI 마이그레이션**: 성능 임계점 도달 시 Option C로 전환

---

## 버전 이력

| 버전 | 날짜 | 변경 사항 |
|------|------|-----------|
| 1.0 | 2026-03-21 | 최초 작성 |
