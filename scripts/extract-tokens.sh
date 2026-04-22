#!/usr/bin/env bash
# extract-tokens.sh — Figma 파일에서 디자인 토큰 추출 후 프로젝트에 주입.
#
# 산출:
#   src/styles/tokens.css    — :root { --brand-*, --surface-*, --text-*, --space-*, --radius-* }
#   src/styles/fonts.css     — @font-face 블록 (감지된 폰트 family만)
#   docs/token-audit.md      — 추출 요약 (색상 N / 폰트 M / spacing K / radius L)
#   tmp/figma-raw.json       — REST /v1/files 원본 (디버깅용)
#
# 전략:
#   1. get_variable_defs 있으면 사용 (Enterprise 플랜)
#   2. REST /v1/files?depth=4 로 fill/stroke/TEXT/cornerRadius tally (폴백, 모든 플랜)
#
# Usage:
#   bash scripts/extract-tokens.sh <fileKey> [pageNodeId]
#
# 인자:
#   fileKey      Figma URL /design/<fileKey>/... 의 fileKey
#   pageNodeId   (선택) 특정 페이지 노드만 스캔. 없으면 파일 전체
#
# 환경변수:
#   FIGMA_TOKEN  Figma Personal Access Token (필수)

set -u

FILE_KEY="${1:-}"
PAGE_ID="${2:-}"

if [ -z "$FILE_KEY" ]; then
  echo "usage: extract-tokens.sh <fileKey> [pageNodeId]" >&2
  exit 2
fi

# FIGMA_TOKEN 로드
if [ -z "${FIGMA_TOKEN:-}" ]; then
  if command -v powershell >/dev/null 2>&1; then
    FIGMA_TOKEN=$(powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('FIGMA_TOKEN', 'User')" 2>/dev/null | tr -d '\r\n')
  fi
fi

if [ -z "${FIGMA_TOKEN:-}" ]; then
  echo "ERROR: FIGMA_TOKEN 미설정." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p src/styles docs tmp

# ---------- Figma REST /v1/files 호출 ----------
if [ -n "$PAGE_ID" ]; then
  NODE_ID_NORM="${PAGE_ID/-/:}"
  URL="https://api.figma.com/v1/files/${FILE_KEY}/nodes?ids=${NODE_ID_NORM}&depth=4"
else
  URL="https://api.figma.com/v1/files/${FILE_KEY}?depth=4"
fi

echo "[extract-tokens] fetch $URL"
curl -sS -H "X-Figma-Token: ${FIGMA_TOKEN}" "$URL" > tmp/figma-raw.json

if ! node -e "JSON.parse(require('fs').readFileSync('tmp/figma-raw.json','utf8'))" 2>/dev/null; then
  echo "ERROR: Figma 응답이 유효한 JSON 아님." >&2
  head -c 500 tmp/figma-raw.json >&2
  exit 3
fi

# ---------- Node 기반 분석 ----------
node "${SCRIPT_DIR}/_extract-tokens-analyze.mjs" tmp/figma-raw.json

echo ""
echo "[extract-tokens] 완료"
echo "  - src/styles/tokens.css"
echo "  - src/styles/fonts.css"
echo "  - docs/token-audit.md"
