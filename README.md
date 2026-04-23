# figma-react-lite-harness

Figma → React 경량 변환 하네스. 팀 단위 협업 + Sonnet 기본 호환 설계.

## 왜 lite인가

- **섹션당 평균 15~20분** (기존 v5 하네스 28분 대비)
- **서브에이전트 1종 (Sonnet)** — Pro $100 요금제도 완주 가능
- **게이트 4개 (G4/G5/G6/G8)** — 접근성·SEO·토큰 드리프트·i18n 보장. 픽셀 diff는 참고만
- **디자인 토큰 자동 추출** — 프로젝트 시작 시 `tokens.css` / `fonts.css` 원샷 생성

## 요구 사항

최소: **Node 18+ · Claude Code CLI · FIGMA_TOKEN**

설치 상세 / Figma MCP 등록 / 토큰 발급 가이드는 **[docs/SETUP.md](./docs/SETUP.md)** 참고 (소요 15~25분).

환경 확인:
```bash
bash scripts/doctor.sh
```

---

## 사용 흐름 (요약)

```
1. 이 하네스 리포 clone
2. 신규 프로젝트 디렉토리 생성 → cd
3. Claude Code 세션 열기
4. 아래 §1 부트스트랩 프롬프트 복붙 (Figma URL만 본인 것으로 교체)
5. 부트스트랩 완료 후 §2 또는 §3 프롬프트 선택
   - §2 전체 자율 모드: 모든 페이지 끝까지 완주
   - §3 단계별: 페이지/섹션 단위로 끊어 진행
6. 필요 시 §4 에스컬레이션 / §5 유지보수 프롬프트
```

---

## §1. 부트스트랩 (새 프로젝트 초기화)

### 사전 준비

> Windows에서는 **PowerShell / cmd / Git Bash 어느 셸에서든** 동일하게 실행 가능. `.sh` 호출은 내부적으로 `bash.exe` (Git for Windows 설치 시 자동 PATH 등록)가 처리. 자세한 셸별 명령 대조는 [docs/SETUP.md §8](./docs/SETUP.md#8-windows-셸별-명령어-대조).

> **경로 표기 규약** — `$HOME/workspace/...` 는 **예시**. 본인 경로로 자유롭게 교체.
> - macOS / Linux / Git Bash / **Windows PowerShell**: `$HOME/workspace/` 그대로 동작 (셸이 자동 전개 → 각 OS 홈 경로)
> - **Windows cmd**: `bash xxx.sh` 명령은 OK (bash.exe 내부에서 `$HOME` 전개). `mkdir`·`cd` 같은 cmd 네이티브 명령은 `%USERPROFILE%\workspace\...` 로 치환 필요
> - cmd 사용자는 가급적 **PowerShell 또는 Git Bash** 권장

```bash
# 0. 환경 셋업 (최초 1회) — 상세는 docs/SETUP.md
#    Node / Claude Code CLI / Figma MCP / FIGMA_TOKEN 준비

# 1. 하네스 clone (한 번만) — 본인 원하는 위치로 교체 가능
git clone https://github.com/HyeonJ/figma-react-lite-harness.git "$HOME/workspace/figma-react-lite-harness"

# 2. (최초 1회) FIGMA_TOKEN 등록 — 대화형
bash "$HOME/workspace/figma-react-lite-harness/scripts/setup-figma-token.sh"

# 3. 환경 확인
bash "$HOME/workspace/figma-react-lite-harness/scripts/doctor.sh"

# 4. 신규 프로젝트 디렉토리
mkdir "$HOME/workspace/my-new-project"
cd "$HOME/workspace/my-new-project"

# 5. Claude Code 세션 오픈
claude --dangerously-skip-permissions
```

> **`--dangerously-skip-permissions` 사용 이유**: 하네스가 섹션마다 파일 생성·git 커밋·bash 스크립트 호출을 반복하므로 권한 프롬프트가 자주 뜸. 로컬 개발 환경에서 자동화 흐름을 유지하기 위해 플래그 권장. 공유 환경이나 신뢰할 수 없는 프롬프트 실행 시엔 플래그 없이 사용.

### 프롬프트 — 부트스트랩 위임

Claude 세션에 아래를 복붙 (Figma URL만 본인 것으로 교체):

```
하네스 리포의 README.md를 읽고
(경로 예시: $HOME/workspace/figma-react-lite-harness/README.md —
 본인이 clone한 경로로 교체),
아래 Figma URL로 bootstrap.sh를 실행해서 이 디렉토리에 프로젝트를 초기화해줘.

Figma URL: https://www.figma.com/design/ABC123XYZ/MyProject

완료 조건:
- Vite + React + TS + Tailwind + Router 스캐폴드
- extract-tokens.sh 자동 실행 → src/styles/tokens.css 생성
- docs/token-audit.md 생성 후 요약 보고
- PROGRESS.md 초기화
- git init + 초기 커밋

완료 후 docs/token-audit.md 요약만 보여줘 — 다음 Phase는 내가 이어서 지시할게.
```

Claude가 수행하는 것:
1. 하네스 README/docs 읽기
2. `bash <하네스경로>/scripts/bootstrap.sh <figma-url>` 실행
3. 토큰 추출 결과 요약 보고

**산출물**: `src/styles/tokens.css` / `fonts.css` / `docs/token-audit.md` / `docs/project-context.md` / `PROGRESS.md` / Vite 스캐폴드

### ⚠ 부트스트랩 직후 **반드시 Claude 세션 재시작**

bootstrap.sh 가 `.claude/agents/section-worker.md` 와 `.claude/skills/figma-react-lite/` 를 프로젝트에 복사하지만, Claude Code는 **세션 시작 시점**에만 에이전트/스킬 레지스트리를 스캔합니다. 같은 세션에서 바로 §2·§3 프롬프트를 호출하면 `Agent type 'section-worker' not found` 에러가 나며, 최악의 경우 오케스트레이터가 규칙을 위반한 채 직접 구현으로 전환합니다.

**필수 절차**:
```bash
# 부트스트랩 완료 후 현재 세션에서
/exit

# 같은 디렉토리에서 재시작
claude --dangerously-skip-permissions
```

재시작 후 새 세션에서 §2 또는 §3 프롬프트 진입.

---

## §2. 전체 자율 모드 (모든 페이지 한 번에 완주)

부트스트랩 완료 후, 사용자 개입 최소로 전체를 완주시키는 프롬프트:

```
figma-react-lite 스킬로 이 Figma 파일의 전체 페이지를 끝까지 구현해줘.

진행 규칙:
1. docs/project-context.md 에 페이지 Node ID가 비어있으면 먼저 Figma에서
   페이지 트리를 get_metadata로 가져와 채워라
2. 각 페이지마다 Phase 2(섹션 분해)를 수행하고, 분해 결과만 한 번 내게 보여줘
3. 사용자 승인 받은 후엔 섹션들을 자율적으로 section-worker로 하나씩 구현
4. 각 섹션 완료 시 자동 커밋 (feat(section): ... (G4-G8 PASS))
5. 섹션 2회 FAIL 시에만 멈추고 나에게 (a) Opus 승격 (b) 스킵 (c) 재분할 선택지 제시
6. 페이지 완료 시 Phase 4 통합 검증 실행 후 다음 페이지로
7. 전체 완주 후 PROGRESS.md 최종 상태 요약

가급적 질문 없이 끝까지 진행해라. 중간 확인은 Phase 2 분해 승인만 받고
나머지는 자율 판단으로 완주해.
```

### 모드 특징

| 장점 | 단점 |
|---|---|
| 사용자 개입 2~5회 (페이지 수만큼) | 중간에 잘못된 판단 시 수정량 커짐 |
| 하루 이내 완주 가능 | FAIL 섹션 누적 시 tech-debt 유사 상태 |
| 긴 시간 자리 비워도 OK | Phase 2 분해가 애매하면 재조정 필요 |

**추천 시점**: 단순한 마케팅 사이트, 명확한 Figma 디자인, 시간 제약 큰 경우

---

## §3. 단계별 모드 (페이지/섹션 단위로 확인하며 진행)

프로덕션 품질 원하거나 검수를 꼼꼼히 하고 싶을 때.

### §3.1 페이지 1개만 진행

```
figma-react-lite 스킬로 /home 페이지를 구현해줘.

1. docs/project-context.md 에서 Home 페이지 Node ID 확인
   (없으면 내게 URL 달라고 해)
2. Phase 2 섹션 분해 → 분해 결과를 PROGRESS.md에 반영하고 나에게 보여줘 (승인 대기)
3. 내가 승인하면 섹션들을 위에서 아래 순서로 section-worker로 스폰
4. 섹션마다 G4/G5/G6/G8 PASS 확인 후 자동 커밋
5. Home의 모든 섹션 완료 시 Phase 4 통합 검증
6. 완료 후 다음 페이지는 내가 별도 지시할게
```

### §3.2 섹션 1개만 진행

```
figma-react-lite 스킬로 home-hero 섹션만 구현해줘.

- Figma Node ID: 265:1086 (docs/project-context.md 참고)
- section-worker 1회 스폰
- G4-G8 PASS 확인 후 자동 커밋
- 실패 시 멈추고 원인 보고

완료 후 내게 결과 JSON만 한 줄 요약해줘.
```

### §3.3 공통 컴포넌트 먼저

섹션 진입 전 Header/Footer 등 재사용 컴포넌트부터:

```
figma-react-lite 스킬로 공통 레이아웃 컴포넌트부터 진행해줘.

1. Header (NavBar) - 5 페이지 공통
2. Footer - 5 페이지 공통

각각 section-worker로 스폰, G4-G8 PASS 확인 후 자동 커밋.
완료 시 src/components/layout/ 에 배치되어야 함.
```

### §3.4 여러 페이지 순차

```
figma-react-lite 스킬로 다음 페이지들을 순서대로 구현해줘:

1. /home
2. /about
3. /menu

각 페이지마다:
- Phase 2 분해 후 나에게 한 번만 승인 받기
- 승인 후 섹션 자율 구현
- 페이지 완료 시 Phase 4 통합 검증

한 페이지 끝나면 다음 페이지로 바로 이어가. 중간 보고는 간단히.
```

---

## §4. 에스컬레이션 / 실패 처리

### §4.1 섹션 FAIL 후 Opus 승격

워커가 2회 FAIL로 멈춘 상태에서:

```
방금 FAIL 난 {section-name} 을 Opus로 재시도해줘.

section-worker를 model: opus 로 오버라이드하여 스폰.
retry_count: 1 로 명시 (지난 실패 원인을 prompt에 포함).
G4-G8 PASS 후 자동 커밋 메시지에 (opus-assist) 포함.
```

### §4.2 섹션 스킵 (후순위로 미루기)

```
{section-name} 은 일단 스킵하고 다음으로 넘어가줘.

- PROGRESS.md 에 해당 섹션을 [~] (보류) 표기 + 주석으로 사유
- 페이지 통합 검증 시 이 섹션 부재 처리 확인
- 다음 섹션 계속 진행
```

### §4.3 섹션 재분할

```
{section-name} 을 서브섹션으로 재분할해줘.

- 이질 에셋 3+ / 반복 자식 3+ 조건 재확인
- 서브섹션 2~3개로 쪼개기
- 각각 section-worker로 개별 스폰
- 원래 섹션은 "wrapper"로 imports + layout div만 남김
```

---

## §5. 유지보수 프롬프트

### §5.1 토큰 재추출 (디자인 변경 시)

```
Figma 디자인이 업데이트됐어. 토큰을 재추출하고 영향 분석해줘.

1. 현재 tokens.css 를 임시 백업:
   cp src/styles/tokens.css /tmp/tokens-before.css
2. scripts/extract-tokens.sh <fileKey> 재실행
3. src/styles/tokens.css / fonts.css 변경 사항 diff 출력
4. 기존 섹션 영향 분석 (G4 --diff 모드):
   node scripts/check-token-usage.mjs src/components/sections --diff /tmp/tokens-before.css
5. 영향받는 섹션 리스트가 나오면:
   - 각 섹션에 대해 measure-quality.sh 재실행 → 이상 없으면 OK
   - 색·간격 시각 차이 있으면 해당 섹션 plan 갱신 후 재작업
6. docs/token-audit.md 갱신
7. 별도 커밋: chore(tokens): Figma 업데이트 반영 (영향 N개 섹션 재검증)
```

### §5.2 기존 프로젝트에 하네스 적용 (마이그레이션)

```
이 프로젝트는 이미 일부 구현돼 있어. figma-react-lite 하네스를 적용해줘.

1. 기존 자산 유지: src/, public/, 완성된 섹션
2. 교체: .claude/, scripts/, CLAUDE.md, docs/workflow.md, docs/team-playbook.md
   (하네스 리포에서 복사)
3. docs/project-context.md 는 기존 내용 보존 (수동 병합)
4. PROGRESS.md 는 기존 진행 상황 유지 + lite 형식으로 재구조화
5. 기존 plan/ research/ 디렉토리는 git에서 untracked 상태로 남겨둠 (삭제 안 함)
6. 적용 후 남은 섹션을 lite 게이트(G4/G5/G6/G8)로 이어서 진행
```

### §5.3 품질 게이트 일괄 재검증

여러 섹션의 게이트를 한 번에 돌려보고 싶을 때:

```
완성된 모든 섹션에 대해 measure-quality.sh를 일괄 실행하고 결과 요약해줘.

대상: src/components/sections/ 하위 모든 디렉토리
출력: 섹션별 G4/G5/G6/G8 PASS/FAIL 표 + FAIL 목록
FAIL 섹션이 있으면 tests/quality/{section}.json 경로 함께 표기
```

---

## 모델 정책

| 역할 | 모델 |
|------|------|
| 오케스트레이터 (메인 세션) | 세션 기본 모델 (Opus 또는 Sonnet) |
| `section-worker` | `sonnet` 고정 (frontmatter) |

- 팀 리드(Max $200) → 세션을 Opus로 오픈하면 판단 품질 +
- 팀원(Max $100 / Pro $20) → Sonnet 기본으로 완주 가능
- 세션 중 `/model opus` ↔ `/model sonnet` 전환 가능

---

## 디렉토리

```
.claude/
  skills/figma-react-lite/SKILL.md   — 오케스트레이터
  agents/section-worker.md           — 단일 워커 (Sonnet)
scripts/
  bootstrap.sh                       — 원샷 프로젝트 셋업 (doctor 선행)
  doctor.sh                          — 환경 점검 (Node/Claude/MCP/토큰)
  setup-figma-token.sh               — PAT 대화형 등록
  extract-tokens.sh                  — Figma 토큰 추출
  _extract-tokens-analyze.mjs        — 토큰 분석 로직 (node)
  figma-rest-image.sh                — Figma REST Images API 래퍼
  check-token-usage.mjs              — G4 (hex literal 차단)
  check-text-ratio.mjs               — G6 + G8
  measure-quality.sh                 — G4/G5/G6/G7/G8 통합 실행
  _lib/load-figma-token.sh           — FIGMA_TOKEN 로드 공용 헬퍼
docs/
  SETUP.md                           — 환경 셋업 가이드 (신규 온보딩)
  workflow.md                        — 1페이지 워크플로
  team-playbook.md                   — 팀 협업 규약
  project-context.md.tmpl            — 프로젝트별 Figma 맥락 템플릿
templates/vite-react-ts/             — 스캐폴드 베이스 (bootstrap.sh가 복사)
CLAUDE.md                            — bootstrap.sh가 프로젝트 루트에 복사
```

## 게이트

| G | 항목 | 도구 | 차단/참고 |
|---|---|---|---|
| G4 | 디자인 토큰 사용 | `check-token-usage.mjs` | 차단 (hex literal) |
| G5 | 시맨틱 HTML | eslint jsx-a11y | 차단 |
| G6 | 텍스트:이미지 비율 | `check-text-ratio.mjs` | 차단 |
| G7 | Lighthouse a11y/SEO | `@lhci/cli` | 환경별 |
| G8 | i18n 가능성 | `check-text-ratio.mjs` | 차단 |

G1~G3 (pixelmatch·치수·naturalWidth)는 lite에서 제거. 필요 시 프로젝트별 추가 스크립트.

---

## 참고 문서

- `CLAUDE.md` — 프로젝트 규칙 (bootstrap 후 프로젝트 루트에 복사됨)
- `docs/workflow.md` — 4 Phase 상세 워크플로
- `docs/team-playbook.md` — 브랜치/PR/리뷰 규약
- `docs/project-context.md` — 프로젝트별 Figma Node ID / 공통 컴포넌트 카탈로그

## 라이선스

내부 템플릿.
