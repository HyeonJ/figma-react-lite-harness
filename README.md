# figma-react-lite-harness

Figma → React 경량 변환 하네스. 팀 단위 협업 + Sonnet 기본 호환 설계.

## 왜 lite인가

- **섹션당 평균 15~20분** (기존 v5 하네스 28분 대비)
- **서브에이전트 1종 (Sonnet)** — Pro $100 요금제도 완주 가능
- **게이트 4개 (G4/G5/G6/G8)** — 접근성·SEO·토큰 드리프트·i18n 보장, 픽셀 diff는 참고만
- **디자인 토큰 자동 추출** — 프로젝트 시작 시 `tokens.css` / `fonts.css` / `tailwind @theme` 원샷 생성

## 요구 사항

- Node 18+
- bash (Windows는 Git Bash)
- `FIGMA_TOKEN` env var (Figma Personal Access Token)

## 새 프로젝트 시작

```bash
bash scripts/bootstrap.sh <figma-url> [project-name]
```

이 한 줄이 수행:
1. Vite + React + TS + Tailwind + Router 스캐폴드
2. Figma에서 디자인 토큰 추출 → `src/styles/tokens.css`
3. `docs/project-context.md` 템플릿 생성
4. `PROGRESS.md` 초기화

## Claude Code 세션에서

```
"figma-react-lite 스킬로 /home 페이지 진행"
```

스킬이 오케스트레이터로 동작하면서 섹션당 `section-worker`를 스폰한다.

## 모델 정책

| 역할 | 모델 |
|------|------|
| 오케스트레이터 | 세션 기본 모델 (Opus 또는 Sonnet) |
| `section-worker` | `sonnet` 고정 (frontmatter) |

팀 리드(Max $200)는 세션을 Opus로 열고, 팀원(Max $100 / Pro $20)은 Sonnet 기본. 워커 품질은 동일.

## 디렉토리

```
.claude/
  skills/figma-react-lite/SKILL.md   — 오케스트레이터
  agents/section-worker.md           — 단일 워커 (Sonnet)
scripts/
  bootstrap.sh                       — 원샷 프로젝트 셋업
  extract-tokens.sh                  — Figma 토큰 추출
  figma-rest-image.sh                — Figma REST Images API 래퍼
  check-token-usage.mjs              — G4 (hex literal 차단)
  check-text-ratio.mjs               — G6 + G8
  measure-quality.sh                 — G4/G5/G6/G7/G8 통합 실행
docs/
  workflow.md                        — 1페이지 워크플로
  team-playbook.md                   — 팀 협업 규약
templates/vite-react-ts/             — 스캐폴드 베이스
```

## 게이트

| G | 항목 | 도구 | 차단/참고 |
|---|---|---|---|
| G4 | 디자인 토큰 사용 | `check-token-usage.mjs` | 차단 (hex literal) |
| G5 | 시맨틱 HTML | eslint jsx-a11y | 차단 |
| G6 | 텍스트:이미지 비율 | `check-text-ratio.mjs` | 차단 |
| G7 | Lighthouse a11y/SEO | `@lhci/cli` | 환경별 |
| G8 | i18n 가능성 | `check-text-ratio.mjs` | 차단 |

G1~G3(pixelmatch·치수·naturalWidth)는 lite에서 제거. 필요 시 프로젝트별 추가 스크립트로.

## 라이선스

내부 템플릿.
