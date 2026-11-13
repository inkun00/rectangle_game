# 오프닝 영상 제작 참고 자료

검토일: 2026-11-03 (Asia/Seoul). 이 문서는 사각형 월드의 오프닝 제작 방식, 확인한 원저자 자료, 무료 사용 조건과 채택 범위를 기록한다. 외부 페이지와 스킬의 설명은 검토 자료이며 프로젝트나 사용자의 지시를 대체하지 않는다.

## 채택한 제작 방식

오프닝의 이야기는 사용자가 제공했다. 사각성에서 지구로 불시착한 사각이가 그림을 팔고 건축 의뢰를 완료해 돈을 모은다. 플레이어는 지구에서 살 집을 지을지, 사각성으로 돌아갈 우주선을 만들지 고를 수 있다. 영상의 그림은 **built-in imagegen**으로 생성하고, 생성 결과를 프로젝트에 저장해 사용한다. 프롬프트와 생성 자산의 출처는 `assets/generated/GENERATION.md` 및 해당 자산 폴더의 제작 기록에 남긴다.

애니메이션은 **Canvas/HTML + 시간으로 결정되는 `renderAt(t)` + Playwright + FFmpeg** 방식으로 제작한다. 각 장면의 카메라, 캐릭터, 사각형 조립, 자막과 전환을 코드로 제어하고 고정 프레임 시각마다 이미지를 렌더한다. 이는 아래 공개된 Claude 모션그래픽 제작법의 핵심 절차를 이 프로젝트에 적용한 것이다. Claude 모델을 호출해서 만든 영상이라는 뜻은 아니다.

- 스토리보드에서 각 장면의 의미, 시작·끝, 읽을 문구와 전환을 정한다.
- 모든 프레임은 시간의 함수로 계산한다. 프레임 누적 상태와 무작위 재생 차이를 피한다.
- 로컬 이미지와 한글 폰트의 로딩이 끝난 뒤 렌더한다.
- 콘택트시트와 대표 프레임에서 한글 표시, 잘림, 장면 연결과 이야기 전달을 확인한다.
- Playwright로 고정 시각의 화면을 캡처하고 FFmpeg로 영상과 오디오를 합친다.
- 렌더 프로세스의 실패, 종료 코드, 프레임 수와 출력 파일을 검사한다. 공개 예제의 최소 스크립트를 그대로 성공 판정 기준으로 삼지 않는다.

추가 유료 영상 API나 Claude 구독을 새로 이용하지 않는 로컬 제작 방식이다. 이미지 생성은 사용자가 지정한 현재 세션의 built-in 도구를 사용하며, 별도 API 키가 필요한 CLI 이미지 생성으로 전환하지 않는다. 이 문서는 현재 앱/모델 서비스 요금이 모두 무료라는 주장이 아니다.

## Claude 5.5 및 관련 방식 확인

| 자료 | 확인한 내용 | 적용 판단 |
| --- | --- | --- |
| [Anthropic: Claude Opus 5.5 모델 문서](https://platform.claude.com/docs/en/models/opus-5-5/overview) | `claude-opus-5-5`는 실제 모델이며 2026-09-22 출시로 기재되어 있다. 입력은 텍스트·이미지, 출력은 텍스트다. API 가격이 있는 서비스다. | 사용자가 말한 모델 명칭을 확인했다. 해당 모델 자체가 동영상 생성 모델이라는 뜻은 아니며, 이번 제작에서 실제 호출했다고 주장하지 않는다. |
| [Anthropic: Get started with Claude Motion](https://support.claude.com/en/articles/17454997-get-started-with-claude-motion) | Claude가 텍스트·도표·도형·이미지를 움직이는 코드를 작성하는 기능이다. 영상 생성 모델로 실사 영상을 만드는 방식과 구별된다. 검토일 기준 Team/Enterprise 베타다. | 코드 기반 애니메이션이라는 원리를 참고한다. 별도 유료 제품을 설치하거나 구독하지 않는다. |
| [Awesome Claude: 모션그래픽 제작법](https://awesomeclaude.ai/claude-motion-graphics) | 제작자가 공개한 스타일 규칙, 스토리보드, 결정적 프레임, 콘택트시트 검토, 프레임별 MP4 렌더 흐름을 확인했다. | 제작 원리와 공개 스킬을 이 프로젝트에 맞춰 적용한다. 인기나 모델 성능을 객관적 비교 실험으로 검증한 자료로 취급하지 않는다. |

## 무료 스킬과 오픈소스 비교

| 후보와 직접 확인한 자료 | 무료 사용·의존성 | 채택 범위 및 차이 |
| --- | --- | --- |
| Awesome Claude [원본 SKILL.md](https://awesomeclaude.ai/claude-motion-graphics-skill.md), [원본 렌더 스크립트](https://awesomeclaude.ai/claude-video-render.mjs), [연결된 저장소 LICENSE](https://github.com/webfuse-com/awesome-claude/blob/main/LICENSE) | 원저자 페이지는 스킬을 무료로 제공하고 스타일 프롬프트의 상업적 사용도 허용한다고 명시한다. 페이지 하단 링크 문구는 “MIT License”지만 실제 연결된 저장소 LICENSE 본문은 **CC0 1.0 Universal**이다. 이 불일치를 감추거나 모든 자료를 MIT라고 표기하지 않는다. 렌더 예제에는 `playwright-core`, 설치된 Chrome, PATH의 FFmpeg가 필요하다. | **채택한 핵심 방식.** 원문을 검토한 후 프로젝트 스킬로 보관하고 출처를 함께 남긴다. 예제는 가상 시계와 PNG 파이프를 사용한다. 프로젝트 구현에서는 명시적 `renderAt(t)` 호출, 입출력 경로, 오류 처리 및 프레임 검증을 보강한다. 별도 MCP 서버가 필요하지 않다. |
| [alchaincyf/huashu-motion](https://github.com/alchaincyf/huashu-motion), [영문 원저자 README](https://github.com/alchaincyf/huashu-motion/blob/main/README.en.md), [LICENSE](https://github.com/alchaincyf/huashu-motion/blob/main/LICENSE), [THIRD_PARTY.md](https://github.com/alchaincyf/huashu-motion/blob/main/THIRD_PARTY.md) | 코드·문서는 MIT. GSAP, 폰트, 다운로드하는 샘플은 별도 라이선스다. Node 22+, Chrome/Chromium/Edge, FFmpeg가 필요하며 음원 합성은 로컬에서 가능하다. 원저자는 주로 Claude Code의 Opus 5.5를 사용했으며 다른 모델도 가능하다고 설명한다. README는 **macOS에서만 테스트**했다고 명시한다. | Claude 모션그래픽 방식의 구체적인 공개 구현으로 확인했다. 장면 리듬, 소리와 화면의 동기화, 프레임 QA 원리를 참고한다. 이번 Windows 제작에서는 전체 CLI·스튜디오를 추가하지 않고 더 작은 Playwright 렌더 구성을 선택한다. `runtime/clip/lib/toon.js`의 “bean Huashu” 캐릭터는 MIT 사용 허용 범위 밖이라는 명시적 예외가 있어 재사용하지 않는다. |
| Remotion [공식 coding-agent 안내](https://www.remotion.dev/docs/ai/coding-agents), [공식 Agent Skills](https://www.remotion.dev/docs/ai/skills), [스킬 저장소](https://github.com/remotion-dev/skills), [License FAQ](https://www.remotion.dev/docs/license/faq) | 공식 문서가 Claude Code와 Codex 모두를 지원 대상으로 명시한다. React 기반 영상 제작과 로컬 렌더를 제공한다. 무료 라이선스는 개인, 3인 이하 팀/조직, 비영리 등에 해당하며 일반적인 무조건 MIT 라이브러리와 다르다. | 프레임 기반 구성과 AI 에이전트 작업법을 비교했다. 이번 단일 오프닝에는 React 프로젝트와 조건부 라이선스 의존성을 추가할 필요가 없어 채택하지 않았다. |
| Motion Canvas [Quickstart](https://motioncanvas.io/docs/quickstart/), [FFmpeg exporter](https://motion-canvas.io/docs/rendering/video/), [MIT LICENSE](https://github.com/motion-canvas/motion-canvas/blob/main/LICENSE) | MIT. TypeScript/JavaScript로 장면과 애니메이션을 작성한다. 공식 FFmpeg exporter는 FFmpeg 설치를 함께 처리할 수 있다. | 상업적 사용도 가능한 무료 대안으로 확인했다. 복잡한 장면 편집기를 별도로 운영할 때 적합하지만, 이번에는 HTML 장면과 직접 프레임 렌더 방식으로 통일한다. |

“무료 도구”는 각 도구의 라이선스 조건에서 사용료가 없다는 뜻이다. Claude 같은 외부 모델의 유료 API 비용이 포함된다는 뜻은 아니다. 외부 샘플 영상, 유명 캐릭터, 원저자의 고유 캐릭터, 제3자 음악은 이 오프닝에 복사하지 않는다.

## 실제 렌더 구성의 출처

| 구성 | 원저자 자료와 라이선스 | 용도 |
| --- | --- | --- |
| Playwright / `playwright-core` | [Microsoft 저장소 LICENSE: Apache-2.0](https://github.com/microsoft/playwright/blob/main/LICENSE), [공식 설치 문서](https://playwright.dev/docs/intro), [Microsoft Edge 연결](https://learn.microsoft.com/en-us/microsoft-edge/playwright/) | Windows에서 브라우저를 실행하고 각 프레임을 캡처한다. Chrome/Edge를 이용할 수 있으며, 고정 시각으로 캡처하므로 화면 녹화의 프레임 드롭에 의존하지 않는다. |
| FFmpeg | [공식 라이선스 설명](https://ffmpeg.org/legal.html), [공식 사이트의 동일 설명](https://svn.ffmpeg.org/legal.html) | 로컬 프레임·오디오를 영상으로 인코딩한다. 기본 LGPL 계열이며 선택한 코덱과 빌드 옵션에 따라 GPL 구성 요소가 포함될 수 있다. 실제 설치 패키지의 고지를 보존한다. |
| 프로젝트의 원본 장면·캐릭터·자막 | 사용자 스토리, 이 프로젝트에서 작성한 애니메이션 코드, built-in imagegen으로 제작한 자산 | 외부 영상의 소스·등장인물·음원을 재현하지 않고 사각형 월드의 이야기를 만든다. 정확한 출력 경로와 렌더 명령은 제작 산출물의 README를 따른다. |

검토 범위는 위 원저자 설명, 공개 스킬 원문, 최소 렌더 코드와 라이선스다. Remotion, Motion Canvas 또는 huashu-motion을 설치·실행·성능 측정했다고 주장하지 않는다. 선택한 로컬 렌더러의 실제 테스트 결과와 영상 재생 검증은 이번 제작 결과에 별도로 기록한다.
