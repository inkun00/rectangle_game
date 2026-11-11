# 사각형 월드 배포

GitHub 저장소는 `inkun00/rectangle_game`, Vercel 프로젝트는 `inkeuns-projects-872d3d68/rectangle-game`입니다. 운영 주소는 **https://rectangle-game-snowy.vercel.app/**입니다.

## 소스만 올려 자동 배포하기

`build/`를 커밋하지 않습니다. 연결된 GitHub 저장소의 `main`에 소스를 올리면 Vercel이 `vercel.json`의 `python3 tools/ci_build.py`를 실행해 `build/web`을 새로 만듭니다. 기존 Vercel Git 연결을 그대로 사용하므로 GitHub Actions용 배포 토큰은 필요하지 않습니다. 이 변경을 아직 원격에 올리지 않은 상태에서는 기존 운영 사이트가 바뀌지 않습니다.

빌드 스크립트는 Godot **4.7.2 stable** Linux x86_64 에디터와 같은 버전의 웹 내보내기 템플릿을 공식 배포처에서 받아 SHA-256을 확인합니다. 템플릿 패키지는 HTTP 범위 요청으로 필요한 웹 파일 약 21MB만 읽습니다. 범위 요청을 지원하지 않는 서버에서는 전체 공식 패키지를 받아 해시를 검사하는 방식으로 전환합니다. 도구 캐시는 체크아웃 밖의 `~/.cache/rectangle-game-build`에 저장하며 `RECTANGLE_BUILD_CACHE`로 바꿀 수 있습니다.

Vercel 빌드 이미지의 Python 3.12와 `tools/requirements-web.txt`에 고정된 폰트·Brotli 도구를 사용해 한글 폰트를 준비하고, 리소스 가져오기·로딩 화면 생성·웹 내보내기·기능별 PCK 분리·전송 압축을 차례로 실행합니다. Godot 오류나 경고가 있으면 빌드를 실패 처리합니다. Vercel의 프로젝트 Build Command를 별도로 덮어쓴 설정이 있다면 저장소의 `vercel.json` 값을 사용하도록 맞춰야 합니다.

새 체크아웃에서 Godot이 폰트를 가져오기 전에 프로젝트 테마가 생성될 폰트 캐시를 먼저 찾는 경우가 있습니다. 첫 가져오기가 정상 종료했고 메시지가 정확히 이 한글 폰트 캐시 누락에만 해당할 때 한 번 다시 가져옵니다. 두 번째 실행은 오류·경고 없이 종료해야 하며, 다른 오류가 섞여 있으면 즉시 실패합니다.

## GitHub 검사와 다운로드 산출물

`.github/workflows/build.yml`은 `main` push, PR, 수동 실행에서 Python 3.12와 Node 22를 준비하고 다음을 실행합니다.

```sh
python tools/ci_build_tests.py
python tools/test_web_resource_packs.py
python tools/ci_build.py --test --desktop
node --test tools/test_loading_shell.cjs tools/test_resource_delivery.cjs
```

기존 Godot 전체 검사까지 통과한 웹 파일과 Windows PCK 패키지는 Actions 실행의 **Artifacts**에서 받을 수 있습니다. 보관 기간은 14일이며 장기 공유할 버전은 별도 릴리스에 보관합니다. Windows 패키지는 Godot 엔진을 포함하지 않으므로 실행 PC에 Godot 4가 필요합니다. 워크플로는 배포나 Git push를 수행하지 않습니다.

## 로컬에서 확인하기

기존 PowerShell 명령도 계속 사용할 수 있습니다.

```powershell
powershell -File tools/run_tests.ps1
powershell -File tools/export_web.ps1
powershell -File tools/export_desktop.ps1
```

또는 Godot 4.7.2 경로를 지정해 CI와 같은 빌드를 실행할 수 있습니다. Windows에서는 Godot을 먼저 설치합니다.

```powershell
python tools/ci_build.py --godot 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --test --desktop
```

검사 후 필요하면 기존 Vercel CLI로 **소스**를 업로드할 수 있습니다. `.vercelignore`가 게임 소스·폰트·빌드 도구를 포함하고 로컬 결과물·캐시·제작 원본을 제외합니다. `--prebuilt` 옵션은 사용하지 않습니다. 이 프로젝트의 `build/web`은 Vercel Build Output API의 `.vercel/output` 형식과 다릅니다.

```powershell
npx vercel login
npx vercel link --project rectangle-game --scope inkeuns-projects-872d3d68
npx vercel --prod
```

`.vercel`과 `.env*`는 로컬 연결·인증 파일이며 커밋하지 않습니다. 새 계정에 프로젝트를 연결해야 할 때만 `npx vercel git connect https://github.com/inkun00/rectangle_game.git`를 사용합니다.

## 포함 파일과 배포 후 확인

오프닝 재생용 OGV와 실제 사용 중인 그래픽은 소스 저장소에 남습니다. 생성 원본·영상 제작 산출물·스크린샷의 외부 보관과 복원 절차는 [저장소 용량 관리](REPOSITORY_STORAGE.md)를 참고하세요. `tools/opening` 등 보관한 제작 도구는 일상 게임 빌드에 필요하지 않습니다.

처음에는 엔진과 core 게임 데이터만 내려받고, 그림·건축·모험·우주선 자료는 사용할 때 받습니다. 오프닝은 **이야기 시작**을 누를 때만 받으며 건너뛰기에는 영상 요청이 없습니다. 현재 로컬 초기 파일 예산은 약 18.27MB이며, 실제 전송량은 캐시와 서버 압축에 따라 달라집니다. [리소스 분리·용량·캐시 계약](WEB_DELIVERY.md)을 참고하세요.

엔진·core·기능 팩은 내용 해시가 들어간 이름과 기존 장기 캐시를 사용합니다. `.br`에는 `Content-Encoding: br`가 필요하며, `vercel.json`이 이 헤더와 WASM의 MIME을 설정합니다. Brotli를 사용할 수 없는 정적 호스트에는 로더가 해제하는 `.gz` 대체 경로가 있으므로 두 표현을 함께 배포합니다. 바뀌지 않은 기능 팩의 파일명을 임의로 바꾸지 마세요. 라이선스와 생성 그래픽 고지 문서도 결과물에 포함합니다.

배포 후 첫 화면의 한글, 오프닝 시작·일시정지·음소거·건너뛰기·재시청, 그림 그리기·집 짓기·우주선 제작·모험 이동, 판매·구매, 공방→월드 이동, 물건 수집·대화, 새로고침 후 저장 복원을 확인합니다. 깨끗한 브라우저 캐시와 기존 캐시 양쪽에서 요청 실패와 콘솔 오류도 확인합니다.

공식 근거: [Godot 4.7.2 배포 파일](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable), [Vercel 빌드 이미지](https://vercel.com/docs/builds/build-image), [Vercel 프로젝트 설정](https://vercel.com/docs/project-configuration/vercel-json), [GitHub Actions와 Vercel](https://vercel.com/kb/guide/how-can-i-use-github-actions-with-vercel).
