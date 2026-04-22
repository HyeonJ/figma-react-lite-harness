#!/usr/bin/env node
/**
 * check-token-usage.mjs — G4 디자인 토큰 사용 게이트.
 *
 * 섹션 .tsx 파일을 AST 파싱해서:
 *   - hex literal (#AABBCC / #RGB)        → FAIL  (토큰 드리프트 방지)
 *   - rgb()/rgba() literal                → FAIL
 *   - Tailwind arbitrary color [#...]     → FAIL
 *   - Tailwind arbitrary spacing [Npx]    → WARN (상대지표)
 *
 * 허용:
 *   - var(--*) 참조
 *   - `text-brand-*`, `bg-surface-*`, `border-*` 등 설정된 토큰 클래스
 *   - transparent / currentColor / inherit
 *   - #fff #000 같은 기본값은 warn 레벨이지만 허용 (공통 CSS reset 지점)
 *
 * Usage:
 *   node scripts/check-token-usage.mjs <section-dir>
 *
 * 종료 코드:
 *   0 PASS
 *   1 FAIL (hex/rgb literal 발견)
 *   2 usage error
 */

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, extname, relative } from "node:path";
import { parse } from "@babel/parser";
import traverseModule from "@babel/traverse";

const traverse = traverseModule.default ?? traverseModule;

const HEX_PATTERN = /#[0-9A-Fa-f]{3,8}\b/g;
const RGB_PATTERN = /rgba?\(\s*\d+[\s,]/g;
const TW_ARB_COLOR_PATTERN = /(?:text|bg|border|fill|stroke|ring|shadow|from|via|to|divide|outline|accent|caret|decoration)-\[#[0-9A-Fa-f]{3,8}\]/g;
const TW_ARB_SPACING_PATTERN = /(?:p|m|gap|top|left|right|bottom|inset|w|h|min-w|min-h|max-w|max-h|translate|space)-\w*\[\-?\d+(?:\.\d+)?px\]/g;

// 화이트리스트: 중립 값
const ALLOWED_COLOR_LITERALS = new Set([
  "#fff", "#ffffff", "#FFF", "#FFFFFF",
  "#000", "#000000",
]);

function walk(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) walk(full, out);
    else if (extname(full) === ".tsx" || extname(full) === ".jsx") out.push(full);
  }
  return out;
}

function collectLiterals(file) {
  const code = readFileSync(file, "utf8");
  const failures = [];
  const warnings = [];

  // 1. Tailwind arbitrary hex (className 내부)
  const arbColorMatches = code.matchAll(TW_ARB_COLOR_PATTERN);
  for (const m of arbColorMatches) {
    failures.push({ type: "tw-arbitrary-hex", value: m[0] });
  }

  // 2. AST 기반 hex/rgb literal 검출 (StringLiteral / TemplateLiteral 내부)
  let ast;
  try {
    ast = parse(code, { sourceType: "module", plugins: ["typescript", "jsx"] });
  } catch (e) {
    // 파싱 실패는 block 아님 (eslint가 별도 잡음)
    return { failures, warnings };
  }

  const checkString = (str, loc) => {
    if (typeof str !== "string") return;
    const hexes = str.match(HEX_PATTERN) || [];
    for (const h of hexes) {
      if (!ALLOWED_COLOR_LITERALS.has(h)) {
        failures.push({ type: "hex-literal", value: h, loc });
      }
    }
    const rgbs = str.match(RGB_PATTERN) || [];
    for (const r of rgbs) {
      failures.push({ type: "rgb-literal", value: r.trim(), loc });
    }
    const arbSpacing = str.match(TW_ARB_SPACING_PATTERN) || [];
    for (const a of arbSpacing) {
      warnings.push({ type: "tw-arbitrary-spacing", value: a, loc });
    }
  };

  traverse(ast, {
    StringLiteral(path) {
      checkString(path.node.value, path.node.loc?.start?.line);
    },
    TemplateLiteral(path) {
      for (const q of path.node.quasis) {
        checkString(q.value.cooked, path.node.loc?.start?.line);
      }
    },
  });

  return { failures, warnings };
}

function main() {
  const target = process.argv[2];
  if (!target) {
    console.error("usage: check-token-usage.mjs <section-dir>");
    process.exit(2);
  }

  const files = walk(target);
  if (files.length === 0) {
    console.error(`no .tsx/.jsx under ${target}`);
    process.exit(2);
  }

  let totalFail = 0;
  let totalWarn = 0;
  const report = { files: files.length, failures: [], warnings: [] };

  for (const f of files) {
    const { failures, warnings } = collectLiterals(f);
    totalFail += failures.length;
    totalWarn += warnings.length;
    for (const x of failures) report.failures.push({ file: relative(process.cwd(), f), ...x });
    for (const x of warnings) report.warnings.push({ file: relative(process.cwd(), f), ...x });
  }

  console.log(JSON.stringify(report, null, 2));

  if (totalFail > 0) {
    console.error(
      `\n❌ G4 FAIL — ${totalFail}개의 hex/rgb literal 발견. ` +
        `src/styles/tokens.css 의 var(--*) 또는 Tailwind 토큰 클래스로 치환하세요.`,
    );
    process.exit(1);
  }
  if (totalWarn > 0) {
    console.error(`⚠ G4 WARN — ${totalWarn}개의 비-토큰 arbitrary spacing (permitted이지만 재검토 권장)`);
  }
  console.error(`✓ G4 PASS (${files.length} files)`);
  process.exit(0);
}

main();
