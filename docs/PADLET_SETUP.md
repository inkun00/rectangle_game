# 그림과 건물의 패들릿 전시 설정

그리기 모드의 판매 화면에서 사용자 이름, 그림 제목, 그림 설명을 작성합니다. 게임이 계산한 판매 가격과 완성된 그림의 PNG를 함께 저장하고 다음 보드에 등록합니다.

건축 모드에서는 의뢰 건물의 준공이 끝나거나 나만의 집이 시공 검사를 통과하면 패들릿에 등록할 수 있습니다. 사용자 이름, 건물 제목, 건물 설명을 작성하면 게임이 계산한 계약 금액 또는 실제 사용 재료비와 건물 PNG를 같은 보드에 등록합니다.

- 보드: [사각형 그림 전시관](https://padlet.com/inkun02/padlet-s025d52oqqhj786g8cry)
- 보드 ID: `s025d52oqqhj786g8cry`
- 게임 주소: <https://rectangle-game-iota.vercel.app/>

제목은 패들릿 게시물 제목으로, 사용자 이름·설명·게임 내 금액·작품 번호는 본문으로 들어갑니다. 금액의 단위는 게임과 같은 **원**이며 실제 결제 금액이 아닙니다. 첨부 파일은 게임 UI, 격자, 선택 표시를 제외한 960×600 PNG입니다.

## 운영 환경 설정

Vercel 프로젝트 `inkun05/rectangle-game`의 **Production 환경**에 다음 두 비밀 환경 변수를 설정하고 다시 배포합니다. 키를 Godot 코드, 브라우저 JavaScript, Git 파일에 넣지 않습니다.

| 환경 변수 | 값 |
| --- | --- |
| `PADLET_API_KEY` | 해당 보드 관리자 계정의 Padlet API 키 |
| `BLOB_READ_WRITE_TOKEN` | 아래에서 만든 **Private** Vercel Blob 저장소의 읽기·쓰기 토큰 |

Padlet 키는 [개발자 설정](https://padlet.com/dashboard/settings/developers)에서 생성합니다. 공개 API는 유료 개인 계정 또는 유료 Team/School 소속 계정이면서 대상 보드의 관리자일 때 사용할 수 있습니다. [Padlet 인증 안내](https://docs.padlet.dev/reference/authentication)

Vercel 프로젝트의 **Storage → Create Storage → Blob**에서 **Private** 저장소를 만들고 프로젝트에 연결합니다. 연결할 때 읽기·쓰기 토큰 환경 변수 추가 옵션을 선택합니다. 이미 다른 저장소가 연결돼 있다면 이 기능에 사용하는 private 저장소의 토큰이 `BLOB_READ_WRITE_TOKEN`에 들어가는지 확인합니다. 이 코드에서 두 환경 변수는 서버 함수만 사용합니다. [Vercel Blob 설정](https://vercel.com/docs/vercel-blob/using-blob-sdk)

처음 설정한 뒤 재배포해야 이미 실행 중인 서버 함수에도 환경 변수가 적용됩니다. Preview 환경에서 실제 전시관에 테스트 작품을 등록하지 않도록, Production 키를 Preview에 자동 복사하지 않습니다. 로컬 모의 검사는 실제 키 없이 실행됩니다.

서버는 지정된 보드에만 게시하고, 허용 목록에 있는 운영 도메인으로 첨부 주소를 만듭니다. 운영 도메인이 바뀌면 `api/_lib/padlet.cjs`의 허용 목록과 `scripts/export/padlet_uploader.gd`의 기본 주소를 확인합니다. 이미 게시된 PNG를 계속 제공하려면 해당 게시물의 도메인과 Blob 연결을 유지합니다.

## PNG를 등록하는 방식

Padlet 공개 API의 게시물 생성은 `attachment.url`을 받으며 PNG 바이너리를 직접 받는 업로드 기능은 문서화돼 있지 않습니다. 따라서 PNG 원본을 private Blob에 저장하고 다음 주소가 PNG만 공개하도록 합니다. [게시물 생성 문서](https://docs.padlet.dev/reference/add-post)

```text
https://rectangle-game-iota.vercel.app/api/artwork-image?id=<작품 번호 32자리>
```

이 URL을 패들릿의 이미지 첨부 주소로 보냅니다. 보드에서 그림을 계속 볼 수 있도록 Blob의 PNG와 이미지 제공 주소를 유지해야 합니다. JSON 제출 기록과 환경 변수는 이 주소로 조회할 수 없습니다.

패들릿이 표시하는 계정 작성자는 API 키 소유자입니다. 학생이 입력한 사용자 이름은 게시물 본문에 표시하는 자기소개 이름이며, 패들릿 계정 인증을 대신하지 않습니다. 이 보드에는 현재 별도 사용자 정의 필드가 없어 본문에 요청된 항목을 명시합니다. API가 돌려주는 `pending_moderation` 상태는 등록 성공과 승인 대기를 구분하여 게임에 전달합니다. [게시물 응답 형식](https://docs.padlet.dev/reference/post-object)

## 서버 동작과 재시도

`POST /api/padlet-artworks`는 다음 JSON을 받습니다.

```json
{
  "id": "0123456789abcdef0123456789abcdef",
  "author": "사각이",
  "title": "사각형 마을",
  "description": "여러 사각형으로 우리 마을을 만들었어요.",
  "price": 2600,
  "png_base64": "PNG 파일의 base64 문자열"
}
```

- 이름 1~40자, 제목 1~80자, 설명 1~1,000자를 받습니다. 공백만 입력한 값과 제어 문자는 거절합니다.
- 그림은 `kind`를 생략하며, 가격은 정수 100~8,000,000원입니다. 의뢰 건물은 `kind`가 `commission`이고 계약 금액은 100,000,000~260,000,000원입니다. 나만의 집은 `kind`가 `my_house`이고 실제 재료비는 100~1,250,000,000원입니다. 공개 서버는 값의 형식과 범위를 확인하며 클라이언트 게임을 다시 실행해서 금액을 재계산하지 않습니다.
- JSON 요청은 3,300,000바이트 이하, PNG는 2,400,000바이트 이하입니다. PNG 서명, 정확한 크기, 디코딩 결과와 CRC를 확인합니다.
- 작품 번호는 32자리 소문자 16진수입니다. 처음 제출한 종류·이름·제목·설명·금액·PNG 해시를 번호에 묶고, 같은 번호로 다른 내용을 보내면 409로 거절합니다. 기존 그림의 번호와 해시는 그대로 쓸 수 있습니다.
- 최초 기록은 같은 경로 덮어쓰기 금지로 만들고, 상태 변경은 Blob의 ETag `ifMatch`로 처리합니다. JSON 상태는 private Blob `get(useCache: false)`로 최신 값을 읽습니다. [일관된 읽기](https://vercel.com/changelog/vercel-blob-now-supports-consistent-reads-on-private-storage)

| 저장 상태 | 재시도 동작 |
| --- | --- |
| `prepared` | 아직 패들릿 게시를 시작하지 않았으므로 PNG 저장부터 이어서 시도 |
| `posting` | 진행 중에는 기다리고, 응답 유실 가능성이 있으면 보드 조회로 결과 확인 |
| `unknown` | 첨부 URL 또는 작품 번호가 같은 게시물을 찾아 결과 복구 |
| `rejected` | 패들릿이 명시적으로 거절한 요청으로, 설정 수정 또는 제한 시간 경과 후 재시도 |
| `published` | 저장한 게시물 링크를 반환하고 추가 게시물 생성 없음 |

Padlet의 공개 문서에는 게시물 생성의 idempotency 키가 없습니다. POST 응답이 끊기면 실제 등록 여부를 즉시 알 수 없으므로 같은 게시물을 무조건 다시 만들지 않습니다. `GET /v1/boards/{board_id}?include=posts`로 기존 게시물을 확인합니다. [보드 조회](https://docs.padlet.dev/reference/get-board-by-id)

**확인되지 않는 결과의 수동 복구:** 첫 POST가 Padlet에 도달하지 않았지만 응답도 받지 못한 경우에는 조회를 반복해도 게시물이 나오지 않을 수 있습니다. 15분 뒤에는 게임이 선생님에게 확인을 요청하는 문구를 표시합니다. 운영자는 작품 번호로 보드를 검색하고, 등록됐으면 게임에서 다시 확인합니다. 등록되지 않았음을 확인한 경우에만 private Blob의 해당 `padlet/submissions/<id>.json`을 관리 도구로 `prepared` 상태로 바꾼 후 동일한 작품을 재시도합니다. 다른 작품 번호를 임의로 만들거나 `posting` 기록을 무조건 지우면 중복 등록이 생길 수 있습니다. 문서화된 외부 API 제약 때문에 이 모호한 경우의 완전 자동 재게시와 정확히 한 번 등록을 동시에 보장할 수는 없습니다.

## 공개 접속과 요청 제한

이 기능은 게임 사용자가 각자의 Padlet 계정으로 로그인하지 않고 전시관에 작품을 보내는 공개 제출 기능입니다. 다른 웹사이트의 브라우저 Origin은 거절하고 운영 사이트 및 현재 Vercel 배포 주소만 허용합니다. 네이티브 Godot는 Origin이 없으므로 허용합니다. 따라서 Origin/CORS 검사는 사용자 인증이 아닙니다.

private Blob의 조건부 카운터로 IP당 분당 120건, 전체 분당 180건의 유효 제출 요청까지 허용합니다. 이는 학급에서 같은 인터넷을 쓰는 경우를 고려한 제한이며, 여러 서버 인스턴스에서도 공유됩니다. IP는 API 키와 함께 해시한 식별자로만 카운터 경로에 사용합니다. PNG 공개 조회는 CDN 캐시를 사용합니다. Padlet 자체 제한은 IP당 분당 250 API 요청입니다. [Padlet 오류·제한](https://docs.padlet.dev/reference/error-handling)

등록 승인 여부, 공개 범위와 콘텐츠 확인은 Padlet 보드 설정에서 정합니다. 공개 제출이 불필요해지면 Vercel에서 `PADLET_API_KEY`를 제거하고 재배포하여 새 업로드를 중지할 수 있습니다. 기존 PNG를 유지하려면 Blob 토큰과 이미지 제공 함수는 유지합니다.

## 확인 방법

```powershell
npm ci
npm test
powershell -ExecutionPolicy Bypass -File tools/run_tests.ps1
```

`npm test`는 메모리 Blob과 모의 Padlet 응답으로 정상 등록, PNG 원본 전달, 잘못된 입력, 동시 등록, 재시도, 응답 유실, 승인 대기, 요청 제한을 확인합니다. 실제 보드에 글을 쓰지 않습니다. `postinstall`은 `node_modules/.gdignore`를 만들어 서버 패키지가 Godot 리소스로 수입되지 않도록 합니다.

실제 API 키와 private Blob 연결 후에는 승인된 예시 작품으로 다음 흐름을 별도로 확인해야 합니다: 판매 화면 입력 → PNG 저장 → 등록 진행 → 패들릿의 이름·제목·설명·가격·이미지 확인 → 새로고침 후 중복 없이 등록 상태 복구. 모의 검사 성공만으로 이 실제 연동 검사가 완료된 것은 아닙니다.
