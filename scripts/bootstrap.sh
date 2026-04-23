#!/usr/bin/env bash
# bootstrap.sh — figma-react-lite 원샷 프로젝트 셋업.
#
# 수행:
#   1. templates/vite-react-ts 스캐폴드 현재 디렉토리에 복사
#   2. package.json / index.html / PROGRESS.md 템플릿 치환
#   3. .claude/ (agents + skills) 복사
#   4. scripts/ 자체 복사 (extract-tokens / measure-quality / figma-rest-image 등)
#   5. docs/workflow.md + team-playbook.md + project-context.md 복사
#   6. CLAUDE.md 복사
#   7. npm install 실행
#   8. extract-tokens.sh <fileKey> 자동 호출
#   9. git init + 초기 커밋
#
# Usage:
#   bash bootstrap.sh <figma-url> [project-name] [--component-url <url>]
#
# 인자:
#   figma-url         Figma 파일 URL (figma.com/design/<fileKey>/... 또는 fileKey 단독)
#   project-name      (선택) package.json name, default: 현재 디렉토리명
#
# 옵션:
#   --component-url <url>   Figma Component/Design System 페이지 URL.
#                           지정 시 토큰 추출이 그 페이지만 스캔 + 레이어명 기반 네이밍.
#                           미지정 시 전체 파일 스캔 (fallback).
#                           URL 예: https://figma.com/design/ABC/x?node-id=10-5282
#
# 환경변수:
#   FIGMA_TOKEN     필수 (extract-tokens 호출용)
#   HARNESS_DIR     (선택) figma-react-lite-harness 위치. 미지정 시 이 스크립트 위치 기반 자동 탐지

set -u

FIGMA_URL=""
PROJECT_NAME=""
COMPONENT_URL=""

# 인자 파싱: 옵션 + positional 혼합
while [ $# -gt 0 ]; do
  case "$1" in
    --component-url)
      COMPONENT_URL="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    -*)
      echo "ERROR: unknown option $1" >&2
      exit 2
      ;;
    *)
      if [ -z "$FIGMA_URL" ]; then
        FIGMA_URL="$1"
      elif [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME="$1"
      else
        echo "ERROR: too many positional args" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

PROJECT_NAME="${PROJECT_NAME:-$(basename "$PWD")}"

if [ -z "$FIGMA_URL" ]; then
  echo "usage: bootstrap.sh <figma-url-or-fileKey> [project-name] [--component-url <url>]" >&2
  echo "  예 (기본):            bootstrap.sh https://figma.com/design/ABC123/Project my-project" >&2
  echo "  예 (Component 지정):  bootstrap.sh https://figma.com/design/ABC123/Project my-project \\" >&2
  echo "                        --component-url https://figma.com/design/ABC123/Project?node-id=10-5282" >&2
  exit 2
fi

# fileKey 추출
if [[ "$FIGMA_URL" =~ figma\.com/(design|file)/([^/]+) ]]; then
  FILE_KEY="${BASH_REMATCH[2]}"
else
  # URL이 아니면 fileKey 그대로
  FILE_KEY="$FIGMA_URL"
  FIGMA_URL="https://www.figma.com/design/${FILE_KEY}"
fi

# Component URL에서 node-id 추출 (있으면)
COMPONENT_NODE_ID=""
if [ -n "$COMPONENT_URL" ]; then
  if [[ "$COMPONENT_URL" =~ node-id=([0-9]+-[0-9]+) ]]; then
    COMPONENT_NODE_ID="${BASH_REMATCH[1]/-/:}"
  elif [[ "$COMPONENT_URL" =~ ^[0-9]+[-:][0-9]+$ ]]; then
    # 순수 nodeId 문자열
    COMPONENT_NODE_ID="${COMPONENT_URL/-/:}"
  else
    echo "WARN: --component-url 에서 node-id 추출 실패. Component 모드 스킵." >&2
  fi
fi

echo "[bootstrap] fileKey=${FILE_KEY} project=${PROJECT_NAME}"
if [ -n "$COMPONENT_NODE_ID" ]; then
  echo "[bootstrap] component-page nodeId=${COMPONENT_NODE_ID}"
fi

# HARNESS_DIR 결정
if [ -z "${HARNESS_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  HARNESS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

if [ ! -d "$HARNESS_DIR/templates/vite-react-ts" ]; then
  echo "ERROR: HARNESS_DIR 에 templates/vite-react-ts 없음: $HARNESS_DIR" >&2
  exit 3
fi

# ---------- 환경 선행 체크 (doctor.sh) ----------
# 필수 도구가 없으면 bootstrap 중단. 선택 도구 경고는 무시.
# --skip-project: bootstrap은 빈 프로젝트 디렉토리에서 실행되므로 §5 프로젝트 체크 생략.
if [ -f "$HARNESS_DIR/scripts/doctor.sh" ]; then
  echo "[bootstrap] 선행 환경 체크 (doctor.sh --skip-project)"
  if ! bash "$HARNESS_DIR/scripts/doctor.sh" --skip-project 2>&1 | tee /tmp/bootstrap-doctor.log | tail -20; then
    echo "" >&2
    echo "ERROR: 필수 환경 미비. 위 출력의 [✗] 항목을 해결한 후 재실행하세요." >&2
    echo "  docs/SETUP.md 참고." >&2
    exit 4
  fi
  echo ""
fi

# 현재 디렉토리 비어있는지 확인 (node_modules 제외)
EXISTING=$(find . -maxdepth 1 -mindepth 1 ! -name node_modules ! -name ".git" 2>/dev/null | wc -l)
if [ "$EXISTING" -gt 0 ]; then
  echo "WARN: 현재 디렉토리 비어있지 않음. 파일 덮어쓰기 가능성." >&2
  echo "  계속하려면 3초 안에 Ctrl+C 로 취소하거나 Enter." >&2
  read -t 3 -r || true
fi

# ---------- 1. 템플릿 복사 ----------
echo "[bootstrap] 1/9 템플릿 복사"
cp -r "$HARNESS_DIR/templates/vite-react-ts/." .

# ---------- 2. 템플릿 치환 ----------
echo "[bootstrap] 2/9 템플릿 placeholder 치환"
# package.json name
if [ -f package.json ]; then
  node -e "
    const fs=require('fs');
    const p=JSON.parse(fs.readFileSync('package.json','utf8'));
    p.name='${PROJECT_NAME}'.toLowerCase().replace(/[^a-z0-9-]/g,'-');
    fs.writeFileSync('package.json', JSON.stringify(p,null,2)+'\n');
  "
fi
# index.html title
if [ -f index.html ]; then
  sed -i.bak "s/{PROJECT_NAME}/${PROJECT_NAME}/g" index.html && rm -f index.html.bak
fi
# PROGRESS.md 템플릿 → PROGRESS.md
if [ -f PROGRESS.md.tmpl ]; then
  sed -e "s|{PROJECT_NAME}|${PROJECT_NAME}|g" \
      -e "s|{FIGMA_URL}|${FIGMA_URL}|g" \
      -e "s|{FILE_KEY}|${FILE_KEY}|g" \
      PROGRESS.md.tmpl > PROGRESS.md
  rm -f PROGRESS.md.tmpl
fi

# ---------- 3. .claude/ 복사 ----------
echo "[bootstrap] 3/9 .claude/ agents + skills 복사"
mkdir -p .claude
cp -r "$HARNESS_DIR/.claude/agents" .claude/
cp -r "$HARNESS_DIR/.claude/skills" .claude/

# ---------- 4. scripts/ 복사 (프로젝트에서도 직접 호출할 수 있도록) ----------
echo "[bootstrap] 4/9 scripts/ 복사"
mkdir -p scripts/_lib
cp "$HARNESS_DIR/scripts/_lib/load-figma-token.sh" scripts/_lib/
cp "$HARNESS_DIR/scripts/figma-rest-image.sh" scripts/
cp "$HARNESS_DIR/scripts/extract-tokens.sh" scripts/
cp "$HARNESS_DIR/scripts/_extract-tokens-analyze.mjs" scripts/
cp "$HARNESS_DIR/scripts/check-text-ratio.mjs" scripts/
cp "$HARNESS_DIR/scripts/check-token-usage.mjs" scripts/
cp "$HARNESS_DIR/scripts/measure-quality.sh" scripts/
cp "$HARNESS_DIR/scripts/doctor.sh" scripts/
cp "$HARNESS_DIR/scripts/setup-figma-token.sh" scripts/
chmod +x scripts/*.sh scripts/*.mjs scripts/_lib/*.sh 2>/dev/null || true

# ---------- 5. docs/ 복사 ----------
echo "[bootstrap] 5/9 docs/ 복사"
mkdir -p docs
cp "$HARNESS_DIR/docs/workflow.md" docs/
cp "$HARNESS_DIR/docs/team-playbook.md" docs/
# project-context.md.tmpl → project-context.md (치환)
if [ -f "$HARNESS_DIR/docs/project-context.md.tmpl" ]; then
  sed -e "s|{PROJECT_NAME}|${PROJECT_NAME}|g" \
      -e "s|{FIGMA_URL}|${FIGMA_URL}|g" \
      -e "s|{FILE_KEY}|${FILE_KEY}|g" \
      "$HARNESS_DIR/docs/project-context.md.tmpl" > docs/project-context.md
fi

# ---------- 6. CLAUDE.md 복사 ----------
echo "[bootstrap] 6/9 CLAUDE.md 복사"
cp "$HARNESS_DIR/CLAUDE.md" CLAUDE.md

# ---------- 7. npm install ----------
echo "[bootstrap] 7/9 npm install (오래 걸릴 수 있음)"
if command -v npm >/dev/null 2>&1; then
  npm install --loglevel=error 2>&1 | tail -20 || echo "  ⚠ npm install 실패 — 수동 실행 필요"
else
  echo "  ⚠ npm 미설치 — Node 18+ 설치 후 'npm install' 수동 실행"
fi

# ---------- 8. extract-tokens 자동 호출 ----------
echo "[bootstrap] 8/9 extract-tokens.sh 실행 (Figma 토큰 추출)"
# _lib/load-figma-token.sh 은 scripts/ 복사 직후 사용 가능
if [ -f "scripts/_lib/load-figma-token.sh" ]; then
  . scripts/_lib/load-figma-token.sh
fi

if [ -z "${FIGMA_TOKEN:-}" ]; then
  echo "  ⚠ FIGMA_TOKEN 미설정 — 토큰 추출 스킵"
  echo "  설정: bash scripts/setup-figma-token.sh"
  if [ -n "$COMPONENT_NODE_ID" ]; then
    echo "  이후 수동 재실행: bash scripts/extract-tokens.sh ${FILE_KEY} --component-page ${COMPONENT_NODE_ID}"
  else
    echo "  이후 수동 재실행: bash scripts/extract-tokens.sh ${FILE_KEY}"
  fi
else
  if [ -n "$COMPONENT_NODE_ID" ]; then
    bash scripts/extract-tokens.sh "$FILE_KEY" --component-page "$COMPONENT_NODE_ID" \
      || echo "  ⚠ extract-tokens 실패 — 수동 재시도 필요"
  else
    bash scripts/extract-tokens.sh "$FILE_KEY" \
      || echo "  ⚠ extract-tokens 실패 — 수동 재시도 필요"
  fi
fi

# ---------- 9. git init + 초기 커밋 ----------
echo "[bootstrap] 9/9 git init + 초기 커밋"
if [ ! -d .git ]; then
  git init -q
fi
git add -A 2>/dev/null || true
git commit -q -m "chore: bootstrap from figma-react-lite-harness (fileKey ${FILE_KEY})" || echo "  (이미 커밋된 상태)"

echo ""
echo "=================================="
echo "✓ bootstrap 완료"
echo ""
echo "⚠⚠⚠ 중요 — Claude Code 세션 재시작 필수 ⚠⚠⚠"
echo ""
echo "  이 bootstrap을 Claude Code 세션 안에서 실행했다면,"
echo "  방금 생성된 .claude/agents/section-worker.md 는 현재 세션의 Agent"
echo "  레지스트리에 반영되지 않습니다 (세션 시작 시점에 동결됨)."
echo ""
echo "  반드시 다음 순서를 지키세요:"
echo "  1. 현재 Claude 세션에서 /exit"
echo "  2. 같은 디렉토리에서 'claude --dangerously-skip-permissions' 재시작"
echo "     (하네스 자율 흐름을 위해 권한 프롬프트 스킵 플래그 권장)"
echo "  3. 새 세션에서 'figma-react-lite 스킬로 첫 페이지 진행' 지시"
echo ""
echo "  이 단계를 건너뛰면 'Agent type section-worker not found' 에러가 나며,"
echo "  오케스트레이터가 규칙을 위반한 채 직접 구현으로 전환할 수 있습니다."
echo ""
echo "=================================="
echo "다음 단계 (세션 재시작 후):"
echo "  1. docs/token-audit.md 를 열어 토큰 검토"
echo "  2. docs/project-context.md 에 페이지 Node ID 채우기"
echo "  3. npm run dev 로 dev 서버 기동 (선택)"
echo "  4. Claude Code 세션에서:"
echo "     \"figma-react-lite 스킬로 첫 페이지 진행\""
echo ""
