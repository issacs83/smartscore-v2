# iPad 실기기 테스트 가이드

## 1. Flutter Web 실행 방법

### 방법 A: 로컬 Windows에서 Flutter Web 서버 실행 (권장)
```powershell
# 1. smartscore_v2 폴더의 통합 빌드 프로젝트로 이동
cd C:\Users\issac\Desktop\JunTech\moveOnToNext\smartscore_v2

# 2. Flutter Web 개발 서버 실행 (모든 네트워크 인터페이스에서 접속 허용)
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080

# 또는 빌드 후 정적 파일 서빙
flutter build web --release
cd build/web
python -m http.server 8080 --bind 0.0.0.0
```

### 방법 B: VS Code에서 실행
1. VS Code에서 smartscore_build 폴더 열기
2. `.vscode/launch.json` 생성:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "SmartScore Web",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": ["--web-hostname", "0.0.0.0", "--web-port", "8080"]
    }
  ]
}
```
3. F5로 실행

### iPad에서 접속
```
http://<Windows PC IP>:8080
```

Windows IP 확인:
```powershell
ipconfig | findstr /i "IPv4"
```

예: `http://192.168.1.100:8080`

## 2. Module C 복원 서버 실행 (별도 터미널)

```powershell
cd C:\Users\issac\Desktop\JunTech\moveOnToNext\smartscore_v2\modules\C_score_image_restoration
python server.py --host 0.0.0.0 --port 8081
```

API 엔드포인트:
- `GET http://<IP>:8081/api/health` — 서버 상태 확인
- `POST http://<IP>:8081/api/restore` — 이미지 복원 (multipart/form-data)
- `GET http://<IP>:8081/api/images/<path>` — 복원 결과 이미지 접근

## 3. iPad Safari/Chrome 테스트 체크리스트

### Stage 1 — 기본 앱 흐름
- [ ] 메인 화면 (/) 정상 로딩
- [ ] 라이브러리 목록 표시
- [ ] 악보 뷰어 화면 진입 (/viewer/:id)
- [ ] 설정 화면 진입 및 3탭 전환 (/settings)
- [ ] 디버그 화면 진입 및 5탭 전환 (/debug)
- [ ] 캡처 화면 진입 (/capture)

### Stage 1 — 터치 UX
- [ ] 스크롤 부드러움 (60fps 목표)
- [ ] 탭 전환 반응 속도 (<200ms)
- [ ] 뒤로가기 네비게이션
- [ ] 다크모드/라이트모드 전환
- [ ] iPad landscape/portrait 회전 대응

### Stage 2 — 이미지 복원 비교 UI
- [ ] 사진 촬영 또는 갤러리에서 악보 이미지 선택
- [ ] 복원 파이프라인 실행 및 진행률 표시
- [ ] 원본 ↔ 복원본 슬라이더 비교
- [ ] 중간 단계별 결과 확인 (6단계)
- [ ] Quality Score 수치 표시
- [ ] 복원 결과 저장

### 성능 기준
- [ ] 초기 로딩: < 3초 (Wi-Fi 기준)
- [ ] 화면 전환: < 300ms
- [ ] 이미지 복원: < 5초 (1000x1500px 기준)

## 4. Web에서 제한되는 기능 목록

| 기능 | 네이티브 | Web | 대안 |
|------|----------|-----|------|
| **카메라 촬영** | ✅ 직접 촬영 | ✅ MediaDevices API | 정상 동작 |
| **갤러리 접근** | ✅ image_picker | ✅ file input | 정상 동작 |
| **BT 페달 연결** | ✅ BLE | ❌ 불가 | 키보드 단축키로 대체 |
| **MIDI 입력** | ✅ 네이티브 | 🟡 Web MIDI API | Chrome만 지원 |
| **로컬 파일 저장** | ✅ 직접 저장 | 🟡 다운로드 방식 | File System Access API |
| **SQLite DB** | ✅ sqflite | ❌ 불가 | IndexedDB 또는 메모리 |
| **백그라운드 오디오** | ✅ 가능 | 🟡 제한적 | 탭 포커스 필요 |
| **오디오 캡처** | ✅ 네이티브 | ✅ getUserMedia | Chrome/Safari 지원 |
| **PDF 렌더링** | ✅ 가능 | 🟡 pdf.js 필요 | 별도 라이브러리 |
| **푸시 알림** | ✅ 가능 | 🟡 제한적 | Service Worker |

### Stage 1에서 Web 제한 영향
- **sqflite**: Web에서 동작 안 함 → **인메모리 저장소로 fallback 필요**
- **path_provider**: Web에서 다른 경로 반환 → **조건부 import 필요**
- **file_picker**: Web에서 HTML input으로 fallback → **정상 동작**

### 권장 수정 (Web 호환)
1. `sqflite` → `sqflite_common_ffi_web` 또는 인메모리 Map으로 대체
2. `path_provider` → `kIsWeb` 체크 후 웹 스토리지 경로 사용
3. BT/MIDI → Web에서는 키보드 단축키만 활성화

## 5. 빠른 시작 순서

```
1. Windows 터미널 1: flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
2. Windows 터미널 2: python server.py --host 0.0.0.0 --port 8081
3. iPad Safari: http://<PC_IP>:8080
4. 테스트 체크리스트 순서대로 진행
```
