# 사각형 월드 배포

GitHub 저장소는 `inkun00/rectangle_game`, Vercel 프로젝트는 `inkun05/rectangle-game`입니다. 기존 `triangle-art` 프로젝트와 별도로 배포합니다.

## 새 버전 올리기

프로젝트 폴더에서 테스트를 통과시킨 뒤 웹 파일을 다시 만듭니다.

```powershell
powershell -File tools/run_tests.ps1
powershell -File tools/export_web.ps1
```

Godot 실행 파일을 자동으로 찾지 못하면 `-GodotExe`를 지정합니다. 한글 폰트 처리에는 Python과 `tools/requirements-font.txt`의 패키지가 필요하며, 다른 Python을 사용하려면 `-PythonExe`를 지정합니다.

변경한 소스와 `build/web` 결과물을 함께 커밋하고 GitHub에 올린 뒤, Vercel CLI로 배포합니다.

```powershell
git push origin main
npx vercel --prod
```

최초 설정에서는 Vercel에 로그인한 뒤 아래 명령으로 기존 프로젝트를 선택합니다.

```powershell
npx vercel login
npx vercel link --project rectangle-game --scope inkun05
```

`.vercel`과 `.env.local`은 로컬 연결·인증 파일이며 커밋하지 않습니다.

## 배포 설정

루트 `vercel.json`은 이미 만들어진 `build/web`을 정적 사이트로 제공합니다. Vercel 서버에서는 Godot 빌드나 패키지 설치를 실행하지 않습니다. `.vercelignore`는 CLI 업로드 대상을 웹 결과물과 설정으로 제한합니다.

엔진과 게임 데이터는 내용이 바뀔 때 파일명이 바뀌므로 장기 캐시를 사용할 수 있습니다. 압축된 `.wasm.gz`와 `.pck.gz`는 게임 로더가 직접 해제합니다. 이 파일에 `Content-Encoding: gzip`을 추가하지 마세요. 생성 그래픽과 외부 코드의 라이선스 문서는 웹 결과물에도 포함됩니다.

배포 후에는 첫 화면의 한글, 공방 → 월드 이동, 물건 수집, 대화창, 새로고침 후 저장 복원을 확인합니다.

## GitHub 자동 배포

현재 Vercel 계정에는 GitHub 로그인 연결이 없어 저장소 자동 연결이 완료되지 않았습니다. GitHub에 올리는 것과 Vercel CLI 배포는 각각 정상적으로 사용할 수 있습니다. 자동 배포를 사용하려면 Vercel 계정 설정에서 GitHub 로그인 연결을 추가한 뒤 다음 명령을 실행합니다.

```powershell
npx vercel git connect https://github.com/inkun00/rectangle_game.git
```

이후에도 게임 소스를 수정할 때는 새 `build/web`을 생성해 함께 올려야 합니다.

설정 근거: [Vercel 정적 프로젝트 설정](https://vercel.com/docs/project-configuration/vercel-json), [CLI 배포](https://vercel.com/docs/cli/deploy).
