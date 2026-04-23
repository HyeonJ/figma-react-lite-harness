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

### 🔒 사용자 nodeId 절대 준수 (최우선)

사용자가 URL/nodeId 를 명시적으로 제공하면 그 nodeId 가 **구현 대상 확정**.
오케는 다른 nodeId 로 임의 전환 / 자체 탐색 금지. 이름이 `Planning` 같이 기획용
뉘앙스여도 그대로 사용. **명백한 구조 이상** (빈 페이지, 타입 불일치, 404) 시에만
사용자에게 재확인 질문. 상세: `SKILL.md` Phase 2.

### 절차

오케스트레이터가 직접 수행:
1. 페이지 Node ID 확인 (`docs/project-context.md` 의 "사용자 지정 시작 nodeId" 필드)
2. `get_metadata` 또는 REST `/v1/files/{key}/nodes?ids=<pageNodeId>&depth=3`
3. 12K 초과 / 이질 에셋 3+ / 반복 자식 3+ / blend transform 3+ 조건이면 서브섹션 분할
4. **반응형 프레임 감지** (페이지별로 Tablet/Mobile 디자인이 따로 있는지 확인):

   **감지 단서 4종**:
   - **프레임 이름 키워드**: `Home / Desktop`, `Home-Mobile`, `Home (Tablet)`, `About Desktop 1920`
   - **프레임 너비**: 1920/1440/1280 = Desktop · 768/1024 = Tablet · 375/390/360 = Mobile
   - **Figma 페이지 분리**: `Desktop Pages` / `Mobile Pages` 같은 별도 페이지
   - **섹션 변종**: 같은 섹션명의 뷰포트별 복제 (예: `Home Hero (Desktop)` + `Home Hero (Mobile)`)

   감지 결과를 `docs/project-context.md` 의 페이지 테이블 3개 컬럼에 기록:
   - Desktop Node ID (필수)
   - Tablet Node ID (선택)
   - Mobile Node ID (선택)

   감지 실패 시 "⚠ 감지 실패 — 수동 확인 필요" 표기. 사용자 승인 시 명시적으로 재확인.

5. 섹션 + 페이지 전체 baseline PNG:
   ```bash
   # Desktop (기본, 필수)
   scripts/figma-rest-image.sh <fileKey> <pageNodeId> figma-screenshots/{page}-full.png --scale 2
   scripts/figma-rest-image.sh <fileKey> <sectionNodeId> figma-screenshots/{page}-{section}.png --scale 2

   # Tablet / Mobile (반응형 프레임 감지된 경우만, 페이지 전체만 선행 확보)
   scripts/figma-rest-image.sh <fileKey> <tabletPageNodeId> figma-screenshots/{page}-full-tablet.png --scale 2
   scripts/figma-rest-image.sh <fileKey> <mobilePageNodeId> figma-screenshots/{page}-full-mobile.png --scale 2
   ```
   섹션별 Tablet/Mobile PNG는 **Phase 3 워커가 섹션 구현 시 확보** (오케는 페이지 전체만).

6. `PROGRESS.md`에 섹션 목록 추가 (반응형 감지 상태 표기 포함)
7. **사용자 승인 대기**: "이대로 진행?"

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
1. 실제 라우트 (`/`, `/about` 등) **1920 fullpage** 캡처 (Desktop pixel-perfect 검증)
2. Desktop 육안 검증: 섹션 정렬 / 가로 스크롤 / 섹션 간 간격 / z-index
3. **375px Mobile / 768px Tablet 뷰포트로도 훑어봄** (육안 — pixel-perfect 아님, 깨짐 확인):
   - 가로 스크롤 유발 요소 없음 (`body.scrollWidth > viewport.width` 체크)
   - 큰 타이포 overflow 없음
   - 이미지 비율 왜곡 없음
   - Nav 햄버거 동작 (Mobile)
   - 버튼/링크 터치 타겟 44px 이상
4. **뷰포트별 검증 분해** (부분 Tier 2 대응):
   페이지는 뷰포트 3종 각각 독립 판정. `project-context.md` 의 페이지 테이블 기준:

   | 뷰포트 | nodeId 제공됨 (Tier 2) | nodeId 없음 (Tier 1) |
   |---|---|---|
   | Desktop (1920 또는 Figma spec) | 캡처 vs Figma `figma-screenshots/{page}-full.png` 육안 비교 | (기본 — 항상 Tier 2) |
   | Tablet (768) | 캡처 vs `{page}-full-tablet.png` 육안 비교 | 깨짐 체크만 (가로 스크롤·overflow·텍스트 잘림) |
   | Mobile (375) | 캡처 vs `{page}-full-mobile.png` 육안 비교 | 깨짐 체크만 (위 동일) |

   예: Desktop + Mobile 만 있는 페이지 = Tablet 은 Tier 1 깨짐 체크만, Mobile 은 Tier 2 Figma 비교.
   디자인 의도 벗어나는 부분 발견 시 해당 섹션 수정.
5. (선택) Lighthouse: `bash scripts/measure-quality.sh {page}-full {page-dir}`
6. PROGRESS.md 페이지 완료 체크

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
