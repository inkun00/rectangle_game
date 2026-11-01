# 이미지 배포 용량 최적화

2026-11-01. 고해상도 원화의 픽셀 크기와 원본 PNG를 보존하고 실제 게임에 포함되는 Godot 텍스처와 웹 로딩 배경을 압축했다.

## 압축 기준

- 불투명 HD 배경 9개와 건축 재료 시트 8개: Godot `compress/mode=1`, `compress/lossy_quality=0.95`. 원본과 픽셀 단위로 동일한 무손실 방식은 아니며, 화면의 세부와 색 경계를 비교해 선택한 고품질 WebP다.
- 투명 환경물·주민·아이템·도구·UI·배지·종이: 무손실 유지. `process/size_limit=0`, 알파 처리, 아틀라스 좌표와 표시 크기를 바꾸지 않았다.
- 그림 배경 30개: 기존 품질 0.85 설정 유지. SVG 학습 도해와 사용자의 사각형 작품에는 이미지 압축을 적용하지 않는다.
- 공통 WebP 인코더 노력 설정: `compression_method=4`, `lossless_compression_factor=100.0`. 무손실 압축의 픽셀·알파는 보존하고 인코딩 시간을 더 사용한다.
- 웹 로딩 배경: 1672×941 원본에서 품질 0.95 WebP로 한 번 인코딩한다. 이미 압축한 게임 텍스처를 재압축하지 않는다. 버튼 PNG는 무손실 유지한다.

원본 PNG와 생성 출처 메타데이터를 남긴다. 원본 PNG만 재압축해도 게임 다운로드는 거의 줄지 않는다. 배포 파일에 들어가는 `.ctex`는 이미 WebP를 내장하기 때문이다. 엔진과 게임 데이터의 gzip·해시 파일명·오류 복구·라이선스 배포는 기존 방식대로 유지한다.

## 실측 결과

MB는 1,000,000바이트 기준이다. [바이트 단위 측정값과 화질 지표](IMAGE_SIZE_OPTIMIZATION.json).

| 대상 | 이전 | 이후 | 감소 |
| --- | ---: | ---: | ---: |
| 웹 게임 데이터 `.pck.gz` | 50.88MB | 27.86MB | 45.2% |
| 웹 로딩 배경 | 2.39MB | 0.55MB | 76.9% |
| Windows 게임 데이터 `.pck` | 51.21MB | 27.97MB | 45.4% |
| 배포 비트맵 텍스처 64개 | 49.48MB | 26.24MB | 47.0% |

64개 원본의 SHA-256과 이미지 크기가 모두 동일하다. 무손실로 남긴 17개 텍스처는 디코딩한 RGBA 픽셀의 SHA-256이 이전 배포본과 정확히 일치한다. 이 17개는 인코더 노력 설정만으로 3.76% 작아졌다. 불투명 HD 17개는 73.27% 작아졌다.

원본과 실제 Godot 압축 결과의 대표 화질 지표는 마을 PSNR 34.91dB/SSIM 0.9548, 설원 38.16dB/0.9646, 재료 A 38.68dB/0.9679, 파란 지붕 41.65dB/0.9754다. SSIM은 원본 RGB8, Gaussian 가중치·sigma 1.5로 계산했다. 실제 1920×1080 월드 6개 지역·재료 확대와 1366×768 브라우저 홈→공방→예시 조립→월드→가방에서 색 경계·실루엣·한글·투명 여백을 확인했다. 눈에 띄는 압축 결함을 발견하지 못했다.

## 재현

`powershell -File tools/run_tests.ps1`, `powershell -File tools/export_web.ps1`, `powershell -File tools/export_desktop.ps1`, `node --test tools/test_loading_shell.cjs`.

검증: Godot 전체 검사 9,523개 통과, 오류·경고 0건. 웹 로딩 셸 검사 8개 통과. Web/Windows 내보내기 성공. 별도 브라우저 세션에서 새 WebP의 실제 크기 1672×941, 게임 데이터와 엔진 다운로드, 홈→공방→예시 조립→월드→가방을 확인했고 실패한 요청과 콘솔 오류는 없었다.

전역 WebP 설정은 기존 텍스처의 캐시 키에 포함되지 않는다. 기존 체크아웃에서 노력 설정만 변경했다면 영향을 받는 `.godot/imported` 텍스처 캐시를 재생성해야 한다. 추적 중인 `.png.import`와 원본은 삭제하지 않는다. 새 체크아웃은 프로젝트 설정으로 바로 가져온다.

기술 근거: [Godot 4.7 WebP 설정](https://github.com/godotengine/godot/blob/4.7/doc/classes/ProjectSettings.xml#L3505), [WebP 인코더의 품질·무손실 처리](https://github.com/godotengine/godot/blob/4.7/modules/webp/webp_common.cpp#L39), [텍스처 캐시 설정](https://github.com/godotengine/godot/blob/4.7/editor/import/resource_importer_texture.cpp#L1012).
