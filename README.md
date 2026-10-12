# 🔺 Triangle Art (트라이앵글 아트)

> **삼각형만으로 펼쳐지는 무한한 디지털 기하학 아트 게임**  
> Godot 4.x 기반으로 제작된 웹/데스크톱 인터랙티브 기하학 아트 & 퍼즐 챌린지 게임입니다.

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-478cbf?logo=godotengine&logoColor=white)](https://godotengine.org)
[![Vercel Deployment](https://img.shields.io/badge/Vercel-Deployed-black?logo=vercel&logoColor=white)](https://vercel.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ 주요 기능 (Key Features)

### 1. 정밀 기하학 드로잉 시스템
- **순수 기하학적 진실의 원천**: 모든 삼각형은 3개의 정점 좌표(`vertex_a`, `vertex_b`, `vertex_c`)와 로컬 변환을 수학적으로 엄밀히 연산.
- **자석 정점 스냅 (Magnetic Snap)**: 인접한 삼각형의 정점에 마우스가 다가가면 부드럽게 결합되는 스냅 효과.
- **15° 회전 스냅 & 각도 피드백**: 최상단 꼭짓점 앵커 기반 회전 핸들과 모서리 회전 영역 지원.
- **다중 선택 & 그룹화 (`Ctrl+G`)**: 여러 삼각형을 한 묶음으로 묶어 일체화 회전 및 크기 조절.
- **최근 60개 작업 실행 취소/다시 실행 (Undo/Redo, `Ctrl+Z`, `Ctrl+Y`)**: 편집 작업을 커맨드 패턴으로 기록.

### 2. 퍼즐 챌린지 모드 (Puzzle Challenge Mode)
- **실시간 일치도 평가기 (`PuzzleEvaluator`)**: 도안의 실루엣을 샘플링해 플레이어가 배치한 삼각형과의 일치도를 0~100%로 평가. 도안 갤러리의 **도전하기** 버튼으로 시작.
- **3-Star 레이팅 & 클리어 연출**: 90% 이상 일치 시 황금 승리 배너, 축하 팡파레, 80여 개의 물리 기반 삼각 컨페티 파티클 폭죽 발사!
- **30종 도안 라이브러리**: 초급·중급·고급 각 10종.

### 3. 상용 인디 게임급 프리미엄 UI / UX
- **다크 글래스모피즘 캡슐 HUD**: 모뉴먼트 밸리(Monument Valley) & 타운스케이퍼(Townscaper) 감성의 미려한 반투명 플로팅 HUD.
- **플로팅 독 컬러 팔레트**: 하단 스와치 바, 호버 스케일업 및 네온 링 발광 애니메이션.
- **도화지 규격 프리셋**: 1:1 정사각, 16:9 와이드, A4 비율 등 자유로운 캔버스 설정.
- **순수 절차적 PCM 사운드 엔진**: 외부 에셋 없이 100% 코드로 합성된 16비트 모노 오디오 효과음 및 상단 음소거 토글 버튼(`🔊`/`🔇`).

### 4. 내보내기 & 프로젝트 저장
- **PNG 고화질 이미지 내보내기**: 격자와 UI 없이 순수 아트워크만 투명 배경/캔버스 배경으로 저장.
- **프로젝트 파일 저장/열기 (`.triart` / `.json`)**: 작업 중인 아트워크의 모든 기하 정보를 무손실 저장 및 복원.

---

## 🚀 빠른 시작 (Getting Started)

### 웹에서 즉시 플레이 (Live Demo)
👉 **[https://triangle-art.vercel.app](https://triangle-art.vercel.app)** 에서 별도 설치 없이 웹 브라우저로 즉시 플레이할 수 있습니다.

### 로컬 실행 (Godot 4.x)
```bash
# 저장소 클론
git clone https://github.com/inkun00/triangle-art.git
cd triangle-art

# Godot 4 에디터로 실행
godot --editor .
```

### 테스트 스위트 실행
```powershell
powershell -File tools/run_tests.ps1
```

### 빌드 및 배포
빌드에는 Godot 4, Python과 `fontTools`가 필요합니다. 전체 폰트 원본은 `tools/font_sources/korean_font_full.ttf.xz`에 무손실 압축으로 보관됩니다. 빌드 시 원본을 메모리에서 복원하고 화면 문구에 필요한 글자만 추려 웹과 Windows 패키지에 넣습니다.

Godot은 `PATH`, WinGet 설치 위치 또는 CreatorTemp에서 자동으로 찾습니다. 다른 위치에 설치했다면 `GODOT_EXE` 환경 변수나 각 스크립트의 `-GodotExe` 옵션으로 실행 파일을 지정할 수 있습니다. Python도 `-PythonExe` 옵션으로 지정할 수 있습니다.

```powershell
python -m pip install -r tools/requirements-font.txt

# 웹 빌드 내보내기
powershell -File tools/export_web.ps1

# 설치된 Godot으로 실행하는 가벼운 윈도우 패키지 내보내기
powershell -File tools/export_desktop.ps1
```

웹 내보내기는 Godot 리소스를 다시 가져온 뒤 파일 내용에 따라 WASM·PCK·스크립트의 이름을 정합니다. WASM과 PCK는 gzip 압축 파일로 저장하며, 브라우저에서 원래 바이트로 복원하여 실행합니다. 최신 브라우저의 기본 압축 해제 기능을 우선 사용하고, 지원하지 않으면 동봉된 pako 2.2.0을 사용합니다. 일반 정적 서버에서도 실행되며, 별도의 `Content-Encoding` 설정은 필요하지 않습니다. 손상된 파일은 오류 안내로 연결되며, 배포 폴더에는 호환용 코드의 라이선스도 함께 포함됩니다.

`vercel.json`은 내용에 따라 이름이 바뀌는 파일들에 장기 캐시를 적용합니다. 새 빌드를 배포할 때는 `build/web` 폴더 전체를 함께 배포해야 합니다. 로컬에서는 `python tools/serve_web.py`를 실행하고 `http://localhost:8080`에 접속합니다.

Windows 패키지는 `build/windows/Run_TriangleArt.bat`으로 실행합니다. 동일한 Godot 설치를 공유하여 게임마다 큰 엔진 실행 파일을 복사하지 않으므로, 실행할 PC에도 Godot 4가 설치되어 있어야 합니다. 패키지에서 테스트·빌드 산출물·개발 도구를 제외하고, 아이콘은 픽셀과 해상도를 유지하면서 무손실 압축합니다.

### 용량 최적화 결과

소스와 배포 파일 합계는 약 **64.4 MB → 18.3 MB (71.5% 감소)**입니다. Git 이력과 다시 생성되는 Godot 캐시는 이 수치에서 제외합니다.

| 주요 파일 | 기존 용량 | 최적화 후 |
| --- | ---: | ---: |
| 웹 엔진 WASM | 39,513,091 B | 10,054,758 B |
| 전체 폰트 원본 | 13,459,196 B | 5,972,552 B |
| Windows PCK | 9,403,432 B | 538,856 B |

게임 기능 테스트 1,662개와 웹 빌드 도구 테스트 6개를 통과했습니다. 실제 브라우저에서 기본·호환 압축 해제, 삼각형 추가, 프로젝트 저장, PNG 내보내기와 손상 파일 오류 안내를 확인했습니다.

---

## 🛠️ 기술 스택
- **Engine**: Godot Engine 4.x (GDScript)
- **Math & Core**: Pure Vector2 Analytic Geometry & Command Pattern
- **Platform**: Web (HTML5 / WebAssembly Single-Threaded), Windows Desktop
- **Deployment**: Vercel & GitHub
