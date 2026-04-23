# workflow.md — figma-react-lite 1페이지 워크플로

## 4 Phase

```
[Phase 1] 부트스트랩     (1회, bootstrap.sh 한 줄)
[Phase 2] 페이지 분해    (페이지 시작 시, 오케 직접)
[Phase 3] 섹션 루프      (섹션마다 워커 1회)
[Phase 4] 페이지 통합    (페이지 완료 시, 오케 직접)
```

## Phase 1 — 부트스트랩

```bash
# 기본
bash scripts/bootstrap.sh <figma-url> [project-name]

# Component/Design System 페이지가 따로 있는 경우 (권장)
bash scripts/bootstrap.sh <figma-url> [project-name] \
  --component-url <figma-component-page-url>
```

자동 수행:
1. Vite + React + TS + Tailwind + Router 스캐폴드
2. `scripts/extract-tokens.sh <fileKey> [--component-page <nodeId>]` 호출
   - Component URL 있으면 그 페이지만 스캔 + 레이어명 기반 네이밍 (품질 ↑)
   - 없으면 전체 파일 빈도 스캔 + 휴리스틱 네이밍 (fallback)
3. `tokens.css` / `fonts.css` / `tailwind.config.ts @theme` 생성
4. `docs/token-audit.md` 리포트 (mode: `component` / `full` 명시)
5. `docs/project-context.md` 템플릿
6. `PROGRESS.md` 초기화

**종료 조건**: `docs/token-audit.md` 존재 + `src/styles/tokens.css` 존재 + dev 서버 기동 확인.

### Component 페이지 모드 식별법

Figma 파일의 **페이지 목록** (왼쪽 사이드바)을 보고 다음 이름 중 하나가 있으면 Component 페이지일 확률 높음:
- `Components`, `Design System`, `Tokens`, `DS`, `UI Kit`, `Styles`, `Foundations`

해당 페이지를 클릭한 상태에서 URL의 `node-id=10-5282` 부분을 복사 (또는 그 URL 전체를 `--component-url` 로 전달). 없으면 생략 가능 — fallback 모드로 작동.

## Phase 2 — 페이지 분해

오케스트레이터가 직접 수행:
1. 페이지 Node ID 확인 (`docs/project-context.md`)
2. `get_metadata` 또는 REST `/v1/files/{key}/nodes?ids=<pageNodeId>&depth=3`
3. 12K 초과 / 이질 에셋 3+ / 반복 자식 3+ / blend transform 3+ 조건이면 서브섹션 분할
4. 섹션 + 페이지 전체 baseline PNG:
   ```bash
   scripts/figma-rest-image.sh <fileKey> <pageNodeId> figma-screenshots/{page}-full.png --scale 2
   scripts/figma-rest-image.sh <fileKey> <sectionNodeId> figma-screenshots/{page}-{section}.png --scale 2
   ```
5. `PROGRESS.md`에 섹션 목록 추가
6. **사용자 승인 대기**: "이대로 진행?"

## Phase 3 — 섹션 루프

각 섹션마다 `section-worker` 1회 호출. 워커가 4단계를 자체 완료:

```
1. 리서치      → plan/{section}.md (컴포넌트 트리 + 에셋 표 + 사용 토큰)
2. 에셋 수집   → src/assets/{section}/
3. 구현        → src/components/sections/{page}/{Section}.tsx + preview route
4. 품질 게이트 → scripts/measure-quality.sh (G4/G5/G6/G8)
```

**워커 반환 처리**:
- PASS → 자동 커밋 + PROGRESS.md 체크 + 다음 섹션
- FAIL (워커 자체 1회 재시도 후) → 사용자 개입: Opus 승격 / 수동 / 스킵 / 재분할

### 섹션 진행 순서

1. 공통 레이아웃 (Header / Footer)
2. Phase 2 식별 신규 공통 컴포넌트
3. 페이지 섹션 (위→아래)

## Phase 4 — 페이지 통합

페이지 섹션 모두 완료 후:
1. 실제 라우트 (`/`, `/about` 등) 1920 fullpage 캡처
2. 육안 검증: 섹션 정렬 / 가로 스크롤 / 섹션 간 간격 / z-index
3. (선택) Lighthouse: `bash scripts/measure-quality.sh {page}-full {page-dir}`
4. 반응형 375/768/1440 눈으로 확인
5. PROGRESS.md 페이지 완료 체크

## 섹션 작성 규칙 (절대)

| 규칙 | 위반 시 |
|---|---|
| hex literal 금지 (`#2D5A27` 직접 기입) | G4 FAIL |
| `<div onClick>` 금지 → `<button>` | G5 FAIL |
| 텍스트를 `<img alt="긴 문장">`에 밀어넣기 금지 | G6 FAIL |
| JSX에 literal text 있어야 함 (alt/aria 제외) | G8 FAIL |
| SVG 패턴: 부모 div + 원본 사이즈 img | (관례) |
| Figma REST PNG에 CSS rotate/blend/bg 재적용 금지 | (관례, 이중 효과) |
| 플러그인 덤프 absolute 그대로 이식 금지 | (관례, flex/grid 재구성) |

## 커밋 메시지

성공:
```
feat(section): {page}-{section} 구현 (G4-G8 PASS)
```

Opus 승격 후:
```
feat(section): {page}-{section} 구현 (G4-G8 PASS, opus-assist)
```

## 멈춤 지점 (사용자 개입)

1. Phase 2 분해 승인
2. 섹션 2회 FAIL 후 선택지

그 외는 모두 자율.

## Figma 쿼터

- Figma REST Images API: 분당 수천 req — 실질 무제한
- Figma MCP `get_design_context`: 섹션당 1회
- Figma MCP `get_variable_defs`: 페이지당 1회 이하 (Enterprise 전용 제약)

## 실패 대응

| 증상 | 원인 | 대응 |
|---|---|---|
| G4 FAIL | hex literal 섞임 | tokens.css의 `var(--*)` 또는 Tailwind 토큰 클래스로 치환 |
| G5 FAIL | `<div onClick>` | `<button>`, `<a>` 시맨틱 요소로 교체 |
| G6 FAIL | 텍스트 raster 안티패턴 | `<img alt="긴 텍스트">` 대신 `<h2>`/`<p>`/`<li>` |
| G8 FAIL | JSX에 텍스트 없음 | 사용자 가시 텍스트를 JSX 트리에 |
| Figma MCP 쿼터 소진 | 월 한도 초과 | REST `/v1/files/{key}/nodes` 로 대체 |
| FIGMA_TOKEN 미설정 | env var 없음 | Windows PowerShell User scope / Unix export |
