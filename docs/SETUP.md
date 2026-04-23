# SETUP.md — figma-react-lite 환경 셋업

팀원 온보딩 가이드. 새 PC에서 처음 하네스를 쓸 때 순서대로 진행.

**소요 시간**: 15~25분 (Claude Code / Node 미설치 시 포함)

---

## 체크리스트 요약

```
□ 1. 시스템 도구      Node 18+ / bash / git / curl
□ 2. Claude Code CLI
□ 3. Figma MCP 등록
□ 4. Figma PAT 발급 + FIGMA_TOKEN 등록
□ 5. 하네스 리포 clone
□ 6. doctor.sh 로 전체 확인
□ 7. (선택) gh CLI / lhci
```

---

## §1. 시스템 도구

| 도구 | 설치 방법 |
|------|-----------|
| **Node 18+** | [nodejs.org](https://nodejs.org) LTS (v20+) 다운로드. nvm/volta 써도 무방 |
| **bash** | Windows: [Git for Windows](https://git-scm.com/download/win) 에 Git Bash 포함 / macOS·Linux: 기본 포함 |
| **git** | 위 Git for Windows 또는 `brew install git` / `apt install git` |
| **curl** | 대부분 내장. 없으면 OS 패키지 매니저 |

확인:
```bash
node -v        # v20.x.x 이상
npm -v
bash --version
git --version
curl --version
```

---

## §2. Claude Code CLI

### Windows
[Claude Code 공식 설치 가이드](https://docs.claude.com/ko/docs/claude-code/overview) 를 따라 CLI 설치.

### macOS / Linux
```bash
# 공식 인스톨러 (예시 — 실제 명령은 공식 문서 확인)
npm install -g @anthropic-ai/claude-code
# 또는 brew install anthropic/claude/claude-code
```

### 로그인
```bash
claude
# 최초 실행 시 브라우저 OAuth 또는 API 키 입력 안내
```

요금제 확인:
- **Max $200 (20x)**: Opus 여유
- **Max $100 (5x)**: Sonnet 기본 권장
- **Pro $20**: Sonnet 전용 권장

확인:
```bash
claude --version    # 0.x.x
```

---

## §3. Figma MCP 등록

`figma-developer-mcp` (NPM 기반, 공식 Figma 연동) 를 Claude Code에 등록.

> **전제**: §4 에서 `FIGMA_TOKEN` 을 먼저 등록해야 MCP가 제대로 동작. 순서상 §4 먼저 한 뒤 §3 로 돌아와도 OK.

### 등록 명령 (한 줄)

```bash
claude mcp add figma-developer-mcp -- npx -y figma-developer-mcp --figma-api-key=$FIGMA_TOKEN --stdio
```

Windows Git Bash에서는 `$FIGMA_TOKEN` 전개가 동작. PowerShell에서는 `$env:FIGMA_TOKEN`.

### 확인

```bash
claude mcp list
```

출력에 `figma-developer-mcp` 가 보이면 OK.

### 세션 내 사용 가능 도구

| 도구 | 용도 |
|---|---|
| `get_design_context` | 섹션 노드의 코드/구조/스타일 힌트 |
| `get_metadata` | 파일/페이지의 노드 트리 |
| `get_variable_defs` | 디자인 토큰 (Variables API, Enterprise 전용 제약) |

### 쿼터 주의

- Figma Starter 플랜: 월 6 tool call
- Pro 이상: 여유
- 쿼터 소진 시 REST API (`/v1/files/{key}/nodes?ids=<nodeId>&depth=3`) 로 대체 가능 (하네스가 자동 폴백)

---

## §4. Figma PAT 발급 + FIGMA_TOKEN 등록

### 4.1 PAT 발급 (Figma 웹에서)

1. https://www.figma.com/developers/api#access-tokens 열기
2. Figma 로그인 → Settings → Security → Personal access tokens
3. **"Generate new token"** 클릭
4. 이름: `figma-react-lite-harness` (또는 임의)
5. Expiration: 90일 권장 (장기는 30일)
6. 스코프: **File content → Read only** 만 체크
7. 생성된 토큰 (`figd_...` 로 시작) **즉시 복사** (다시 볼 수 없음)

### 4.2 전역 env var 등록 — 자동

```bash
bash scripts/setup-figma-token.sh
```

이 대화형 스크립트가:
1. 토큰 입력 받기 (화면에 표시되지 않음)
2. `curl /v1/me` 로 smoke test
3. OS별 전역 등록:
   - Windows: PowerShell User scope (`[Environment]::SetEnvironmentVariable(..., 'User')`)
   - macOS/Linux: `~/.zshrc` 또는 `~/.bashrc` 에 `export` 추가

### 4.3 전역 env var 등록 — 수동 (스크립트 실패 시)

**Windows PowerShell**:
```powershell
[Environment]::SetEnvironmentVariable('FIGMA_TOKEN', 'figd_여기에토큰', 'User')
```

**macOS / Linux**:
```bash
echo 'export FIGMA_TOKEN=figd_여기에토큰' >> ~/.zshrc   # 또는 ~/.bashrc
source ~/.zshrc
```

### 4.4 적용 확인

**새 터미널을 열어야** 적용됨.

```bash
# Windows Git Bash
powershell -Command "[Environment]::GetEnvironmentVariable('FIGMA_TOKEN', 'User')" | head -c 20

# Unix
printenv FIGMA_TOKEN | head -c 20
```

`figd_` 로 시작하는 20자 정도가 보이면 OK.

### 4.5 보안 주의

- PAT는 **로컬 전용**. git 커밋·로그·스크립트에 평문 노출 금지
- 다른 사람과 공유 PC 쓰면 User scope만 사용 (Machine scope 금지)
- 유출 의심 시 즉시 Figma Settings → 해당 토큰 Revoke 후 재발급

---

## §5. 하네스 리포 clone

```bash
# 개인 작업 공간에 clone
git clone https://github.com/HyeonJ/figma-react-lite-harness.git ~/workspace/figma-react-lite-harness

# 또는 Windows
git clone https://github.com/HyeonJ/figma-react-lite-harness.git C:/Dev/Workspace/figma-react-lite-harness
```

주의: **하네스 리포는 템플릿이지 작업 디렉토리가 아니다.** 실제 프로젝트는 별도 디렉토리에 만들고, 하네스의 `bootstrap.sh` 가 필요한 파일을 그곳으로 복사한다.

---

## §6. doctor.sh 최종 확인

```bash
bash ~/workspace/figma-react-lite-harness/scripts/doctor.sh
```

출력 예시:
```
1/5 시스템 도구
  [✓] Node                   v20.11.0
  [✓] npm                    10.2.4
  [✓] bash                   5.2.21
  [✓] git                    2.45.0
  [✓] curl                   설치됨
2/5 Claude Code
  [✓] Claude Code CLI        0.x.x
  [✓] Figma MCP              등록됨
3/5 Figma 인증
  [✓] FIGMA_TOKEN            figd_A...
  [✓] Figma API 연결         alice@example.com
4/5 선택 도구
  [✓] gh CLI                 로그인됨
  [⚠] @lhci/cli              미설치 (G7 Lighthouse 스킵됨)
```

필수 항목 전부 `[✓]` 면 준비 완료. `[✗]` 있으면 해결 명령어 보고 조치.

---

## §7. 선택 도구

### gh CLI (GitHub 리포 자동 생성)

```bash
# 설치
# Windows: winget install GitHub.cli
# macOS:   brew install gh
# Linux:   https://cli.github.com

# 로그인
gh auth login
```

없어도 하네스 동작. 단 `bootstrap` 이후 리포 생성 + push 를 수동으로 해야 함.

### @lhci/cli + lighthouse (G7 Lighthouse 게이트)

```bash
# 프로젝트에서 (bootstrap 후)
npm install -D @lhci/cli lighthouse
```

없으면 G7 스킵 (경고만). G4/G5/G6/G8 는 영향 없음.

---

## 실제 사용으로 진입

셋업 완료 후:

```bash
# 1. 신규 프로젝트 디렉토리
mkdir ~/workspace/my-new-project
cd ~/workspace/my-new-project

# 2. Claude Code 세션
claude

# 3. 세션 안에서 README.md §1 부트스트랩 프롬프트 복붙
```

이후는 루트 [README.md](../README.md) §1~§5 참조.

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| `FIGMA_TOKEN: unbound variable` | env 적용 안 된 새 터미널 세션 | 새 Git Bash / 터미널 재오픈 |
| `Figma API 인증 실패` | PAT 만료 또는 revoke | Figma 웹에서 재발급 + `setup-figma-token.sh` 재실행 |
| `claude mcp list` 에 figma 없음 | MCP 등록 실패 | §3 명령 재실행. `claude mcp remove figma-developer-mcp` 후 재등록 |
| `extract-tokens.sh` 에서 JSON 파싱 에러 | 파일 접근 권한 없음 또는 fileKey 오타 | URL 다시 확인, PAT 권한 확인 |
| Claude Code에서 MCP 응답 없음 | Figma MCP 서버 프로세스 문제 | Claude Code 재시작 |
| bootstrap 후 빌드 실패 | Node 버전 문제 | Node 18+ 확인, `node_modules/` 지우고 재설치 |

## 관련 문서

- [`../README.md`](../README.md) — 부트스트랩/페이지/섹션 프롬프트 모음
- [`workflow.md`](./workflow.md) — 4 Phase 상세
- [`team-playbook.md`](./team-playbook.md) — 브랜치/PR/리뷰 규약
