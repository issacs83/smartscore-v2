# SmartScore v2 iPad 테스트 결과 기록서

---

## 1. 테스트 환경 정보

| 항목 | 내용 |
|------|------|
| **테스트 일자** | YYYY-MM-DD |
| **테스트 시간** | HH:MM ~ HH:MM |
| **테스터 이름** | |
| **iPad 모델** | (예: iPad Pro 12.9" 6세대) |
| **iPadOS 버전** | (예: iPadOS 17.4) |
| **브라우저** | (예: Safari 17.4) |
| **서버 OS** | (예: Windows 11 / macOS 14.3) |
| **Python 버전** | (예: 3.11.7) |
| **네트워크 환경** | (예: WiFi 5GHz, 같은 공유기) |
| **서버 IP:포트** | (예: 192.168.0.10:8888) |
| **Flutter Web 포트** | (예: 8080) |

---

## 2. 테스트 이미지 정보

| 번호 | 파일명 | 해상도 | 파일 크기 | 설명 |
|------|--------|--------|----------|------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |
| 5 | | | | |

---

## 3. 기능 테스트 결과

### 3.1 서버 연결

| 번호 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 서버 health check 성공 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 2 | 서버 주소 설정 후 연결 상태 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |

### 3.2 이미지 입력

| 번호 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | iPad 카메라로 악보 촬영 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 2 | iPad 갤러리에서 이미지 선택 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 3 | 파일 앱에서 이미지 가져오기 | :white_large_square: 통과 / :white_large_square: 실패 | |

### 3.3 이미지 복원 처리

| 번호 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 이미지 업로드 및 복원 요청 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 2 | 로딩 메시지 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 3 | 복원 결과 수신 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 4 | 비교 탭 자동 전환 | :white_large_square: 통과 / :white_large_square: 실패 | |

### 3.4 결과 확인 (탭별)

| 번호 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 원본 탭 이미지 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 2 | 복원 탭 이진화 이미지 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 3 | 이진화/그레이스케일 전환 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 4 | 비교 탭 슬라이더 동작 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 5 | 품질 탭 종합 점수 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 6 | 품질 탭 컴포넌트 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 7 | 처리 단계별 시간 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |

### 3.5 옵션 및 재처리

| 번호 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 옵션 패널 펼치기/접기 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 2 | 각 토글 옵션 동작 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 3 | 이진화 방식 변경 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 4 | 옵션 변경 후 재처리 | :white_large_square: 통과 / :white_large_square: 실패 | |

### 3.6 에러 처리

| 번호 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 서버 중단 시 에러 메시지 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 2 | 연결 거부 시 에러 메시지 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 3 | 타임아웃 시 에러 메시지 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 4 | "다시 시도" 버튼 가시성 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 5 | "다시 시도" 버튼 동작 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 6 | "돌아가기" 버튼 동작 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 7 | 에러 코드 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |

### 3.7 이미지 크기 관련

| 번호 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 20MB 초과 이미지 경고 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 2 | 50MB 초과 이미지 거부 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 3 | 경고 후 정상 처리 진행 | :white_large_square: 통과 / :white_large_square: 실패 | |

---

## 4. UI/UX 테스트 결과

| 번호 | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 태블릿 가로 모드 레이아웃 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 2 | 태블릿 세로 모드 레이아웃 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 3 | 가로/세로 전환 시 안정성 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 4 | 이미지 핀치 줌 동작 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 5 | 이미지 팬(드래그) 동작 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 6 | 비교 슬라이더 터치 반응성 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 7 | 품질 바 시각화 정확성 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 8 | 로딩 인디케이터 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 9 | 라이트 모드 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |
| 10 | 다크 모드 전환 및 표시 | :white_large_square: 통과 / :white_large_square: 실패 | |

---

## 5. 성능 테스트 결과

| 번호 | 항목 | 기준 | 측정값 | 결과 |
|------|------|------|--------|------|
| 1 | 복원 처리 시간 | <15초 | 초 | :white_large_square: 통과 / :white_large_square: 실패 |
| 2 | 이미지 다운로드 시간 | <5초 | 초 | :white_large_square: 통과 / :white_large_square: 실패 |
| 3 | Health check 응답 시간 | <3초 | 초 | :white_large_square: 통과 / :white_large_square: 실패 |
| 4 | 메모리 사용량 (단일 처리) | 안정적 | MB | :white_large_square: 통과 / :white_large_square: 실패 |
| 5 | 메모리 사용량 (5회 반복) | 누수 없음 | MB | :white_large_square: 통과 / :white_large_square: 실패 |

---

## 6. 스크린샷 첨부

### 6.1 정상 동작 스크린샷

| 화면 | 스크린샷 |
|------|----------|
| 원본 탭 | (스크린샷 첨부) |
| 복원 탭 (이진화) | (스크린샷 첨부) |
| 복원 탭 (그레이스케일) | (스크린샷 첨부) |
| 비교 탭 | (스크린샷 첨부) |
| 품질 탭 | (스크린샷 첨부) |
| 옵션 패널 | (스크린샷 첨부) |

### 6.2 에러 상태 스크린샷

| 화면 | 스크린샷 |
|------|----------|
| 서버 연결 오류 | (스크린샷 첨부) |
| 타임아웃 오류 | (스크린샷 첨부) |
| 이미지 크기 경고 | (스크린샷 첨부) |
| 이미지 크기 초과 오류 | (스크린샷 첨부) |

---

## 7. 발견된 버그/이슈

| 번호 | 심각도 | 항목 | 증상 | 재현 절차 | 비고 |
|------|--------|------|------|----------|------|
| 1 | 높음/중간/낮음 | | | | |
| 2 | 높음/중간/낮음 | | | | |
| 3 | 높음/중간/낮음 | | | | |

---

## 8. 개선 제안

| 번호 | 영역 | 제안 내용 | 우선순위 |
|------|------|----------|----------|
| 1 | | | 높음/중간/낮음 |
| 2 | | | 높음/중간/낮음 |
| 3 | | | 높음/중간/낮음 |

---

## 9. 종합 판정

| 항목 | 결과 |
|------|------|
| **기능 테스트** | :white_large_square: 통과 / :white_large_square: 조건부 통과 / :white_large_square: 불합격 |
| **UI/UX 테스트** | :white_large_square: 통과 / :white_large_square: 조건부 통과 / :white_large_square: 불합격 |
| **성능 테스트** | :white_large_square: 통과 / :white_large_square: 조건부 통과 / :white_large_square: 불합격 |
| **종합 판정** | :white_large_square: **통과** / :white_large_square: **조건부 통과** / :white_large_square: **불합격** |

### 조건부 통과 사유 (해당 시):


### 불합격 사유 (해당 시):


---

**테스터 서명**: ___________________

**검토자 서명**: ___________________

**일자**: YYYY-MM-DD
