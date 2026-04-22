# CLAUDE.md — figma-react-lite 하네스 프로젝트 규칙

이 파일은 **bootstrap.sh로 생성된 실제 프로젝트 루트에 복사**되어 Claude Code가 읽는다.

## 핵심 원칙

1. **작업 단위 = 섹션.** 한 섹션 = 한 브랜치 = 한 커밋
2. **디자인 토큰이 진실의 원천.** `src/styles/tokens.css`를 쓰고, hex literal 직접 기입 금지
3. **게이트 PASS 없이 커밋 금지.** G4/G5/G6/G8 전부 통과 필요
4. **Figma 에셋은 REST API로 다운로드.** CSS 유니코드로 대체 금지
5. **Framelink MCP 호출 금지** (영구 폐기)

## 하네스 트리거

Figma URL 제공 / "섹션 구현" / "페이지 진행" / "다음 섹션" 요청 시 **`figma-react-lite` 스킬을 반드시 사용**하라.

## 섹션 파일 편집 규칙

- `src/components/sections/**` 파일 수정은 `section-worker` 워커에 위임. 오케스트레이터 직접 편집 금지
- 예외 (직접 편집 OK):
  - `src/components/layout/` (공통 Header/Footer)
  - `src/styles/` (global CSS, 단 tokens.css / fonts.css는 extract-tokens.sh만이 쓴다)
  - `src/App.tsx`, `src/routes/`, `tests/`, `scripts/`

## Figma 채널

| 용도 | 도구 |
|---|---|
| baseline PNG / 에셋 | `scripts/figma-rest-image.sh` (필수 채널) |
| 노드 구조 | `get_design_context` 섹션당 1회 또는 REST `/v1/files/.../nodes` |
| 토큰 | `docs/token-audit.md` (extract-tokens.sh 결과) |

## 게이트 (차단)

| G | 도구 | 의미 |
|---|---|---|
| G4 | `check-token-usage.mjs` | hex literal / 토큰 외 색상 금지 |
| G5 | `eslint` (jsx-a11y) | 시맨틱 HTML, a11y |
| G6 | `check-text-ratio.mjs` | 텍스트 baked-in raster 차단 |
| G8 | `check-text-ratio.mjs` | JSX에 literal text 존재 (i18n 가능) |

실행: `bash scripts/measure-quality.sh <section> <section-dir>`

## 모드 판별

1. Figma URL / "디자인 구현" 키워드 → Figma 모드 (`figma-react-lite` 스킬)
2. 그 외 프론트 작업 → 일반 React/Tailwind 규칙

## 참조 문서

- `docs/workflow.md` — 1페이지 워크플로
- `docs/team-playbook.md` — 팀 협업
- `docs/project-context.md` — 프로젝트별 Figma Node ID / 페이지 구성
- `docs/token-audit.md` — 자동 생성된 토큰 인벤토리
- `PROGRESS.md` — 진행 상황 진실의 원천
