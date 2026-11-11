# 웹 리소스 분리와 초기 다운로드

2026-11-10 로컬 빌드 기준이다. 이미지·영상의 픽셀, 해상도, 소리와 기존 게임 기능을 유지하고 다운로드 시점과 전송 압축만 바꾼다. 이 문서는 운영 사이트에 이미 배포되었다는 의미가 아니다.

## 내려받는 시점

처음에는 엔진과 시작 화면·공통 UI·코드가 들어 있는 core PCK만 받는다. 원래 웹 배포물 약 55.04MB에서 초기 파일 예산은 약 **18.27MB**로 줄었다. 이 예산에는 Brotli 엔진·core와 HTML·JS·로딩 배경·아이콘 등 모든 시작 화면 파일을 보수적으로 합산했다. HTTP 헤더는 제외하며 실제 브라우저 요청량은 캐시와 HTML/JS 압축에 따라 달라진다.

| 자료 | Brotli 크기 | 처음 내려받는 시점 |
| --- | ---: | --- |
| 엔진 + core | 17.25MB | 웹 앱 시작 |
| 그림 배경·명화 도해 | 3.63MB | 그림 그리기에 처음 들어갈 때 |
| 건축 재료·배지 | 5.93MB | 집 짓기에 처음 들어갈 때 |
| 모험 환경물·지역 배경 | 9.71MB | 공방에서 월드로 처음 들어갈 때 |
| 귀향 행성 이미지 | 1.82MB | 우주선 제작에 처음 들어갈 때 |
| 오프닝 영상 | 13.84MB | **이야기 시작**을 누를 때 |

MB는 1,000,000바이트 기준이다. 오프닝을 건너뛰면 영상 팩을 요청하지 않는다. 재생 준비 중에는 기존 건너뛰기·Esc를 사용할 수 있고, 실패하면 다시 시도하거나 건너뛸 수 있다. 일시정지·음소거·재시청도 유지한다. 웹 오디오를 사용자의 클릭에서 먼저 활성화한 뒤 비동기로 영상을 준비한다.

그림·건축·우주선 화면도 자료가 준비된 뒤 처음 생성한다. 준비 중 다른 화면으로 이동하거나 취소한 요청의 늦은 응답은 현재 화면을 바꾸지 않는다. 학습·공방·홈에서 쓰는 초상화·도구·종이·공통 UI와 홈 카드 이미지는 core에 있어 기존 표시 품질을 유지한다.

모든 기능과 영상을 사용하는 사람의 최종 전송량이 초기 예산과 같은 것은 아니다. 별도 팩을 실제로 사용하는 만큼 추가로 받는다.

## 파일과 런타임 계약

`tools/prepare_web_release.py`가 Godot이 만든 전체 웹 PCK를 읽고 `tools/web_resource_packs.py`로 다음 그룹에 나눈다.

`core`, `drawing`, `construction`, `adventure`, `space`, `opening`

PCK 안의 리소스 바이트는 다시 인코딩하지 않는다. `.import`와 해당 `.ctex`는 같은 팩에 넣으며, 파일 이름이 같은 다른 폴더의 이미지도 전체 경로로 구분한다. 모든 원래 리소스는 정확히 한 팩에 남아야 빌드가 성공한다. core에는 코드·장면·폰트·공통 시작 자산이 들어가고 Windows 내보내기에는 분리를 적용하지 않는다.

빌드가 `index.html`의 엔진 스크립트 앞에 다음 형태의 manifest를 넣는다.

```javascript
window.QUAD_RESOURCE_PACKS = {
  version: 1,
  packs: {
    drawing: {
      url: "feature-drawing-<SHA256 앞 12자리>.pck",
      sha256: "<압축 해제한 PCK의 전체 SHA-256>",
      bytes: 3665348,
      br_url: "feature-drawing-<hash>.pck.br",
      gzip_url: "feature-drawing-<hash>.pck.gz"
    }
  }
};
```

해시와 크기는 빌드에서 실제 값으로 채워진다. 논리 URL인 `.pck`와 `.wasm` 원본은 배포하지 않고 `.br`·`.gz` 표현만 보관한다. `delivery-report.json`에 실제 해시·원래 크기·두 압축 크기·그룹별 리소스 수와 초기 바이너리 예산이 기록된다.

GDScript는 `await WebResourcePacks.ensure("drawing")`처럼 요청한다. JS 브리지는 `QuadResourcePacks.download(feature, callback)`과 `cancel(feature)`을 제공한다. 중복 요청은 공유하며 내려받은 ArrayBuffer의 크기와 SHA-256을 확인한 뒤 `user://web-resource-packs`에 저장하고 `ProjectSettings.load_resource_pack()`으로 마운트한다. 비정상·부분 다운로드를 게임 자산으로 사용하지 않는다.

## Brotli와 캐시

`Brotli==1.2.1`의 품질 6과 gzip 품질 9를 사용하며, 두 결과를 다시 해제해 원본과 바이트가 같은지 빌드에서 확인한다. 엔진은 기존 gzip 10.05MB에서 Brotli 8.18MB로 줄었다. 이미 압축된 이미지·영상 팩에서는 차이가 작고 일부 팩은 gzip 쪽이 조금 작을 수 있다.

브라우저는 `.br` 응답에 `Content-Encoding: br`가 있으면 직접 해제한다. 이 헤더가 없거나 Brotli 요청을 사용할 수 없으면 로더가 `.gz`로 전환하고 기존 스트림 해제기 또는 동봉된 디코더를 사용한다. 잘못된 응답으로 빈 화면에 갇히지 않도록 기존 로딩 오류·재시도 화면을 유지한다.

`engine-*`, `art-*`, `feature-*`는 해시가 들어간 이름과 1년 `immutable` 캐시를 사용한다. 기능 자료가 바뀌지 않으면 코드나 문구를 수정해도 해당 기능 팩 이름은 같다. 브라우저 HTTP 캐시와 검증한 기기 내 PCK 캐시를 재사용한다. 브라우저 데이터 삭제나 저장소 정리 후에는 다시 받을 수 있다. 저장 게임의 기존 파일명·버전·게임 ID는 바꾸지 않는다.

## 빌드·배포·로컬 확인

Python 의존성은 `tools/requirements-web.txt`에 고정한다. 폰트 도구도 이 파일에서 함께 설치한다.

```powershell
python -m pip install -r tools/requirements-web.txt
python tools/test_web_resource_packs.py
python tools/ci_build_tests.py
powershell -File tools/run_tests.ps1
powershell -File tools/export_web.ps1
node --test tools/test_loading_shell.cjs tools/test_resource_delivery.cjs
python tools/serve_web.py
```

`tools/serve_web.py`는 Brotli·캐시·격리 헤더가 있는 HTTP 미리보기 서버다. 다른 단순 정적 서버에서는 Brotli 헤더를 설정하거나 gzip 대체 경로를 함께 제공해야 한다. [Vercel 배포 설정](DEPLOYMENT.md)의 `.br` 응답 헤더를 유지하며 `.br` 파일을 이미 해제한 상태로 다시 Brotli라고 표시하지 않는다. gzip 대체 파일과 라이선스도 함께 올린다.

Windows·에디터는 전체 오프라인 자산을 유지한다. 웹의 추가 다운로드 manifest가 없는 환경에서는 네트워크 팩 요청을 하지 않고 기존 자산 경로를 사용한다.

## 확인한 보존 항목

현재 분리한 웹 PCK들의 합집합은 Windows 전체 PCK와 같은 리소스 309개다. 플랫폼별 엔진 캐시 파일 2개를 제외한 모든 리소스 바이트가 같다. 이전 패키지와 비교해 텍스처 86개의 크기와 RGBA가 같고, 오프닝 OGV도 바이트가 같다. 상세 해시·크기 비교는 외부 검증 폴더의 `lazy-package-comparison.json`에 보관한다.

브라우저 검증에서는 깨끗한 캐시에서 시작할 때 `feature-*` 요청이 없는지, 오프닝 건너뛰기·기능 진입·취소·오프라인 실패·재시도·재방문 캐시·기존 저장 복원을 확인한다. Godot 전체 검사와 실제 브라우저 검사 결과는 작업 마지막의 검증 로그를 기준으로 한다.

## 완료 검증

- Godot 전체 검사 **15,596개 통과**, 실패·엔진 오류·경고 0건.
- 로딩 셸·리소스 전송 Node 검사 **20개**, PCK 분리·압축 및 빌드 초기화 Python 검사 **17개** 통과.
- 깨끗한 Chrome의 최초 실제 전송량 **18,204,647바이트**. 기능 팩 요청은 0건이며 오프닝 건너뛰기에도 영상 요청이 없다.
- 실제 브라우저에서 그림·건축·우주선 다운로드와 실패 후 재시도, 다운로드한 기능 재사용을 확인했다.
- 모험 진입 시에만 모험 팩을 받고, 페이지를 새로고침한 뒤에도 검증한 기기 내 팩을 사용해 같은 모험 팩을 다시 요청하지 않았다.
- 오프닝 실제 재생 검사 **21개** 통과: 재생 클릭, 음성 출력, 일시정지·재개, 음소거·복구, 55초 자연 종료, 건너뛰기·Esc, 재시청 캐시, 다운로드 취소와 503 실패 후 재시도.
- Brotli 응답을 사용할 수 없고 `DecompressionStream`도 없는 상황을 재현해 동봉된 gzip 디코더로 엔진·core·그림 팩을 실행했다.
- 소스 폴더 밖에서 Windows 전체 PCK를 실행해 홈·그림·건축·우주선·공방·월드를 확인했다. 데스크톱은 추가 다운로드가 없다.

의도적으로 주입한 404·503 응답은 복구 검사의 일부다. 정상 경로에 앱·JavaScript 오류가 없었다. 검증용 브라우저와 HTTP 서버는 검사 후 종료한다. 상세 로그·스크린샷·패키지 비교는 외부 격리 폴더의 `verification/`에 있으며 운영 사이트 배포는 수행하지 않았다.
