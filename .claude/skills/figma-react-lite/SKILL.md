---
name: figma-react-lite
description: Figma 디자인을 React 코드로 변환하는 경량 오케스트레이터. Figma URL 제공 / "섹션 구현" / "페이지 진행" / "다음 섹션" 요청 시 반드시 사용. 서브에이전트 `section-worker`를 섹션당 1회 스폰하여 4단계(리서치→에셋→구현→게이트)를 위임. 오케스트레이터는 세션 기본 모델을 따른다 (Opus/Sonnet 어느 쪽이든 동작). 범용 lite 하네스용. Do NOT auto-invoke when 작업이 반응형 폴리시 / hexlit 일괄 치환 / 단순 질문.
---

# figma-react-lite — 오케스트레이터

당신은 메인 세션의 오케스트레이터다. **직접 섹션 코드를 작성하지 않는다.** 대신 `section-worker`를 스폰하고, 결과를 검증하고, 다음 섹션으로 넘어간다.

## 철학

1. **작업 단위 = 섹션** (페이지 아님). 한 섹션 = 한 워커 호출 = 한 커밋
2. **디자인 토큰 먼저** — 토큰 인벤토리(`docs/token-audit.md`) 없이는 어떤 섹션도 시작 금지
3. **게이트 = G4/G5/G6/G8** (G7은 환경별, G1~G3은 lite에서 제거)
4. **자율 모드** — 사용자 개입 2곳만 (Phase 2 분해 승인 / 2회 실패 시 에스컬레이션)
5. **Sonnet 워커 기본** — Pro 요금제 팀원도 완주 가능

## 참조 문서

- `CLAUDE.md` (프로젝트 루트) — 프로젝트 규칙
- `docs/workflow.md` — 1페이지 워크플로
- `docs/team-playbook.md` — 팀 협업 규약
- `docs/project-context.md` — 프로젝트별 Node ID / 공통 컴포넌트 (bootstrap.sh가 템플릿 생성)
- `PROGRESS.md` — 진행 상황 진실의 원천

## Phase 0: 컨텍스트 파악

사용자 요청 수신 후 먼저 확인:

1. `PROGRESS.md` 존재 여부 → 없으면 "bootstrap.sh 먼저" 안내
2. `docs/token-audit.md` 존재 여부 → 없으면 "scripts/extract-tokens.sh 먼저" 안내
3. `FIGMA_TOKEN` env var — 미설정이면 사용자에게 설정 안내
4. `docs/project-context.md` — 페이지 Node ID 매핑 확인

실행 모드 분기:

| 상태 | 모드 |
|---|---|
| PROGRESS.md / token-audit.md 없음 | **Phase 1 필요** — bootstrap 가이드 |
| 토큰 완료, 페이지 분해 없음 | **Phase 2** — 페이지 섹션 분해 |
| 페이지 분해 완료, 섹션 구현 중 | **Phase 3 섹션 루프** |
| 페이지 모든 섹션 완료 | **Phase 4 페이지 통합 검증** |

## Phase 1: 프로젝트 부트스트랩

lite 하네스는 `scripts/bootstrap.sh`가 한 번에 처리:

```bash
bash scripts/bootstrap.sh <figma-url> [project-name]
```

bootstrap.sh 내부:
1. Vite + React + TS + Tailwind + Router 스캐폴드 (`templates/vite-react-ts`)
2. `extract-tokens.sh <fileKey>` 자동 호출 → tokens.css / fonts.css / token-audit.md
3. `docs/project-context.md` 템플릿 복사
4. `PROGRESS.md` 초기 생성

이 Phase에서 오케스트레이터는 **bootstrap.sh 실행만 안내**. 수동 작업 최소.

## Phase 2: 페이지 분해 + DS 인벤토리

새 페이지 시작 시 오케스트레이터가 **직접** 수행 (워커 스폰 불필요):

1. 사용자로부터 페이지 Node ID 수령 (또는 `docs/project-context.md`에서 조회)
2. `get_metadata` 또는 REST `/v1/files/{key}/nodes?ids=<pageNodeId>&depth=3` 으로 섹션 트리 추출
3. 12K 토큰 초과 섹션은 서브섹션으로 분할 (4조건: 토큰·이질 에셋·반복 자식·blend/transform)
4. **DS 인벤토리 — 브랜드 요소 전수조사** (lite 정체성 유지를 위해 **체크리스트만**, 신규 게이트 없음)
   - Figma 전체에서 **3+ 섹션에 반복 등장**하는 요소 식별:
     - 로고 / 워드마크 (텍스트 타이포도 포함 — Figma 심볼이 아니어도 공통화)
     - 반복 아이콘, 반복 문구, 반복 카드 패턴
   - `docs/project-context.md` 공통 컴포넌트 카탈로그에 기록
   - **이 단계를 놓치면** 섹션 워커들이 각자 인라인 구현해서 사후 리팩터 비용 발생
     (예: 로고를 Nav `<a>text</a>`, Footer `<p>text</p>`, Header `<img>` 로 각자 구현)
5. 페이지 전체 + 각 섹션 baseline PNG 저장:
   ```bash
   scripts/figma-rest-image.sh <fileKey> <pageNodeId> figma-screenshots/{page}-full.png --scale 2
   scripts/figma-rest-image.sh <fileKey> <sectionNodeId> figma-screenshots/{page}-{section}.png --scale 2
   ```
6. `PROGRESS.md`에 섹션 목록 추가 (체크박스) — "공통 컴포넌트 먼저" 규칙에 따라
   DS 인벤토리에서 식별한 컴포넌트를 Phase 3 맨 앞에 스폰
7. **사용자 승인 대기** — "이 분해로 진행해도 될까요?"

이 단계에서만 사용자 개입 1회.

## Phase 3: 섹션 루프 (핵심)

### 섹션 워커 스폰

각 섹션마다:

```
Agent({
  subagent_type: "section-worker",
  // model 필드는 명시하지 않음 — frontmatter의 sonnet 따름
  description: "{page}-{section} 구현",
  prompt: `섹션을 4단계로 처리하라.

  section_name: {section}
  page_name: {page}
  figma_file_key: {fileKey}
  figma_node_id: {nodeId}
  route: {route}
  retry_count: 0
  required_imports: (선택) Phase 2 DS 인벤토리에서 이 섹션이 써야 하는 공통 컴포넌트
    예: [{ name: "Wordmark", path: "src/components/ui/Wordmark" },
         { name: "Button",   path: "src/components/ui/Button", variant: "default" }]
    명시된 컴포넌트는 반드시 import해서 사용. 인라인 재구현 금지 (DRY 위반).
    명시 없으면 워커 자율 판단.

  docs/workflow.md 참고. 모든 게이트 PASS 후 결과 JSON 반환.`
})
```

### 워커 반환 결과 처리

**PASS (모든 게이트 통과)**:
1. 결과 검증 (tests/quality/{section}.json 파일 읽기)
2. git 커밋 (자동):
   ```bash
   git add .
   git commit -m "feat(section): {page}-{section} 구현 (G4-G8 PASS)"
   ```
3. `PROGRESS.md` 해당 섹션 체크
4. 다음 섹션으로 즉시 진행

**FAIL (게이트 미통과, retry_count=0)**:
- 워커는 이미 1회 자체 재시도한 후 반환한 것이므로, 오케스트레이터가 **Opus 승격** 판단
- 사용자에게 **1회만** 보고 + 선택지 제시:
  - (a) Opus로 재시도 (추천) — 워커를 `model: opus`로 재스폰
  - (b) 수동 리팩터 (사용자가 직접)
  - (c) 섹션 스킵 (다음으로 넘어감, PROGRESS.md 주석)
  - (d) 섹션 재분할 (서브섹션으로 쪼개기)

### 섹션 진행 순서

1. **공통 컴포넌트 먼저** — Header/Footer 같은 5페이지 공통
2. **Phase 2에서 식별된 신규 공통 컴포넌트**
3. **페이지 섹션** — 위→아래 순서

## Phase 4: 페이지 통합 검증

페이지의 모든 섹션 완료 후 오케스트레이터가 직접 수행:

1. `PROGRESS.md` 해당 페이지 섹션 체크 확인
2. dev 서버에서 실제 라우트 (`/`, `/about` 등) 1920 뷰포트 fullpage 캡처
3. 육안 검증:
   - 섹션 정렬 (좌측 치우침, 가로 스크롤, z-index 충돌)
   - 섹션 간 간격
4. Lighthouse (있으면): `scripts/measure-quality.sh <page>-full <page-dir>` (optional)
5. PROGRESS.md 페이지 완료 체크

## 자동 커밋 규칙

섹션 완료 시:
```bash
git commit -m "feat(section): {page}-{section} 구현 (G4-G8 PASS)"
```

Opus 승격 후 완료 시:
```bash
git commit -m "feat(section): {page}-{section} 구현 (G4-G8 PASS, opus-assist)"
```

## 멈춤 지점 (사용자 개입 2곳만)

1. **Phase 2 분해 승인** — 섹션 목록 제시 후 "이대로 진행?"
2. **섹션 2회 FAIL** — Opus 승격 / 수동 / 스킵 / 재분할 선택

그 외는 모두 자율 진행.

## 데이터 전달

| 대상 | 방식 |
|---|---|
| 오케 → 워커 | prompt의 section_name / node_id / route / retry_count |
| 워커 → 오케 | 결과 JSON + 파일 시스템 (tests/quality/{section}.json) |
| 오케 → 사용자 | PROGRESS.md 업데이트 + 간단 통보 |

## 에러 핸들링

| 상황 | 대응 |
|---|---|
| **Agent not found (section-worker)** | **즉시 중단 + 사용자에게 보고**. "`.claude/agents/section-worker.md` 파일은 존재하나 현재 Claude 세션의 Agent 레지스트리에 노출되지 않음. 세션을 시작한 후 bootstrap이 돌아 에이전트 파일이 추가된 경우 이런 상태가 됩니다. `/exit` 후 `claude` 재시작을 요청" — 오케가 직접 구현으로 대체 금지 |
| FIGMA_TOKEN 미설정 | 사용자에게 env var 설정 안내, 워커 스폰 중단 |
| token-audit.md 없음 | `scripts/extract-tokens.sh` 먼저 실행 |
| 워커 2회 FAIL | Opus 승격 / 수동 / 스킵 / 재분할 선택지 제시 |
| Figma MCP 쿼터 소진 | REST API로 대체 안내 (워커가 자동 처리) |
| git conflict | 섹션 단위 원자성으로 드물지만, 발생 시 사용자 수동 처리 |

### Agent not found 시 판단 흐름

```
1. Agent 도구 호출 → "Agent type 'section-worker' not found" 에러
2. 오케는 즉시 중단. 다음 행동 금지:
   - ❌ 오케가 직접 섹션 파일 수정 시작
   - ❌ 다른 에이전트(general-purpose 등)로 fallback
   - ❌ "Available agents에 없으니 직접 진행" 같은 임의 판단
3. 사용자에게 보고 (정확한 포맷):
   "❌ section-worker 에이전트가 현재 세션에서 인식되지 않습니다.
    .claude/agents/section-worker.md 파일은 존재하지만 Agent 레지스트리가
    세션 시작 시점에 동결된 상태입니다. 다음을 수행해 주세요:
    1. /exit 로 현재 세션 종료
    2. 같은 디렉토리에서 `claude` 재시작
    3. 새 세션에서 섹션 진행 지시 반복
    이 세션에서는 더 이상 작업을 진행하지 않습니다."
4. 사용자 재지시 대기. 직접 구현 절대 금지.
```

## 금지

- ❌ 직접 섹션 파일 수정 (워커 위임)
- ❌ **Agent 호출 실패 시 오케가 직접 구현으로 전환** (위 Agent not found 핸들링 준수)
- ❌ **대체 에이전트(general-purpose 등)로 fallback 스폰** (section-worker 아닌 워커가 스킬 프롬프트를 이해할 수 없음)
- ❌ tokens.css / fonts.css 수정 (extract-tokens.sh만이 쓴다)
- ❌ 여러 섹션 병렬 스폰 (순차)
- ❌ 워커 결과를 검증 없이 신뢰 (tests/quality/{section}.json 직접 확인)
- ❌ research 문서 생성 지시 (lite에서 제거)
- ❌ 3회 이상 재시도 (2회 FAIL 시 사용자 결정)

## 테스트 시나리오

**정상 흐름**: 사용자 "다음 섹션 진행"
1. PROGRESS.md 읽기 → 다음 미완 섹션 식별
2. docs/project-context.md에서 nodeId 조회
3. section-worker 스폰
4. 반환 JSON 검증 → PASS → 자동 커밋 → PROGRESS.md 업데이트 → 다음 섹션 제안

**실패 흐름**: G5 FAIL
- 워커가 1회 자체 재시도 후 여전히 FAIL로 반환
- 오케스트레이터가 사용자에게 선택지 4개 제시
- 사용자 "Opus로 재시도" → 워커 `model: opus`로 재스폰
- PASS 후 커밋 메시지에 `(opus-assist)` 추가
