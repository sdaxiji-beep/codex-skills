#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function getArgValue(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1 || index + 1 >= process.argv.length) {
    return "";
  }
  return process.argv[index + 1];
}

function makeDiag({ severity = "info", code, message, file = "", source = "ast-shadow" }) {
  return { severity, code, message, file, source };
}

function readInputPayload() {
  const inputPath = getArgValue("--input");
  if (!inputPath) {
    return {
      ok: false,
      diagnostics: [makeDiag({ severity: "error", code: "missing_input", message: "Missing --input argument." })],
      parser_available: false,
      parser_name: "none",
    };
  }

  try {
    const raw = fs.readFileSync(inputPath, "utf8");
    return { ok: true, raw };
  } catch (error) {
    return {
      ok: false,
      diagnostics: [
        makeDiag({
          severity: "error",
          code: "read_input_failed",
          message: `Failed to read input file: ${error.message}`,
          file: inputPath,
        }),
      ],
      parser_available: false,
      parser_name: "none",
    };
  }
}

async function loadAcorn() {
  try {
    const mod = await import("acorn");
    return { available: true, parser: mod.Parser };
  } catch {
    return { available: false, parser: null };
  }
}

function validateWxmlSurface(content, filePath, diagnostics) {
  const bannedHtml = /<\s*(div|span|a|img|p|ul|li)\b/gi;
  if (bannedHtml.test(content)) {
    diagnostics.push(
      makeDiag({
        severity: "warn",
        code: "wxml_html_tag_detected",
        message: "Potential unsupported HTML tags detected in WXML.",
        file: filePath,
      })
    );
  }
}

function validateWxmlStructure(content, filePath, diagnostics) {
  const voidTags = new Set(["image", "input", "icon", "progress", "checkbox", "radio", "switch", "slider"]);
  const tagRegex = /<\s*(\/)?\s*([a-zA-Z][\w-]*)\b[^>]*(\/?)>/g;
  const stack = [];

  let match;
  while ((match = tagRegex.exec(content)) !== null) {
    const isClosing = Boolean(match[1]);
    const tagName = String(match[2] || "").toLowerCase();
    const selfClosing = (match[3] || "") === "/";
    const isVoid = voidTags.has(tagName);

    if (isClosing) {
      if (stack.length === 0) {
        diagnostics.push(
          makeDiag({
            severity: "error",
            code: "wxml_unmatched_close_tag",
            message: `Found closing tag without opening pair: </${tagName}>.`,
            file: filePath,
          })
        );
        continue;
      }

      const openTag = stack.pop();
      if (openTag !== tagName) {
        diagnostics.push(
          makeDiag({
            severity: "error",
            code: "wxml_tag_mismatch",
            message: `Tag mismatch: expected </${openTag}> but found </${tagName}>.`,
            file: filePath,
          })
        );
      }
      continue;
    }

    if (!selfClosing && !isVoid) {
      stack.push(tagName);
    }
  }

  while (stack.length > 0) {
    const tag = stack.pop();
    diagnostics.push(
      makeDiag({
        severity: "error",
        code: "wxml_unclosed_tag",
        message: `Unclosed tag detected: <${tag}>.`,
        file: filePath,
      })
    );
  }
}

function validateWxmlDirectiveSemantics(content, filePath, diagnostics) {
  const tagRegex = /<\s*([a-zA-Z][\w-]*)\b([^>]*)>/g;
  let match;
  while ((match = tagRegex.exec(content)) !== null) {
    const tagName = String(match[1] || "").toLowerCase();
    const attrText = String(match[2] || "");

    if (tagName.startsWith("/")) {
      continue;
    }

    const hasWxFor = /\bwx:for\s*=/.test(attrText);
    const hasWxKey = /\bwx:key\s*=/.test(attrText);
    const hasWxIf = /\bwx:if\s*=/.test(attrText);
    const hasWxElif = /\bwx:elif\s*=/.test(attrText);
    const hasWxElseBare = /\bwx:else\b(?!\s*=)/.test(attrText);
    const hasWxElseAssigned = /\bwx:else\s*=/.test(attrText);

    if (hasWxFor && !hasWxKey) {
      diagnostics.push(
        makeDiag({
          severity: "error",
          code: "wxml_wx_for_missing_key",
          message: "wx:for requires wx:key for stable list rendering.",
          file: filePath,
        })
      );
    }

    if (hasWxElseAssigned) {
      diagnostics.push(
        makeDiag({
          severity: "error",
          code: "wxml_wx_else_has_value",
          message: "wx:else must not have an assigned value.",
          file: filePath,
        })
      );
    }

    const conditionalCount = [hasWxIf, hasWxElif, hasWxElseBare || hasWxElseAssigned].filter(Boolean).length;
    if (conditionalCount > 1) {
      diagnostics.push(
        makeDiag({
          severity: "error",
          code: "wxml_conditional_conflict",
          message: "A node cannot declare multiple conditional directives (wx:if / wx:elif / wx:else) at once.",
          file: filePath,
        })
      );
    }
  }
}

function validateJsAst(content, filePath, parser, diagnostics) {
  try {
    parser.parse(content, { ecmaVersion: "latest", sourceType: "script" });
  } catch (error) {
    diagnostics.push(
      makeDiag({
        severity: "error",
        code: "js_parse_error",
        message: `JavaScript parse failed: ${error.message}`,
        file: filePath,
      })
    );
  }
}

function validateJsConstructorParity(content, filePath, diagnostics) {
  const isPagePath = /^pages\//.test(filePath);
  const isComponentPath = /^components\//.test(filePath);
  const hasPageCtor = /\bPage\s*\(/.test(content);
  const hasComponentCtor = /\bComponent\s*\(/.test(content);

  if (isPagePath && hasComponentCtor) {
    diagnostics.push(
      makeDiag({
        severity: "error",
        code: "js_constructor_mismatch_page",
        message: "Page file uses Component() constructor.",
        file: filePath,
      })
    );
  }

  if (isComponentPath && hasPageCtor) {
    diagnostics.push(
      makeDiag({
        severity: "error",
        code: "js_constructor_mismatch_component",
        message: "Component file uses Page() constructor.",
        file: filePath,
      })
    );
  }
}

async function main() {
  const input = readInputPayload();
  if (!input.ok) {
    process.stdout.write(JSON.stringify(input));
    process.exit(0);
  }

  let bundle;
  const diagnostics = [];
  try {
    bundle = JSON.parse(input.raw);
  } catch (error) {
    process.stdout.write(
      JSON.stringify({
        ok: false,
        parser_available: false,
        parser_name: "none",
        diagnostics: [
          makeDiag({
            severity: "error",
            code: "json_parse_error",
            message: `Payload JSON parse failed: ${error.message}`,
          }),
        ],
      })
    );
    process.exit(0);
  }

  const files = Array.isArray(bundle.files) ? bundle.files : [];
  const acornState = await loadAcorn();
  const forceError = process.env.WECHAT_AST_TEST_FORCE_ERROR === "1";
  const forceWarning = process.env.WECHAT_AST_TEST_FORCE_WARNING === "1";

  if (!acornState.available) {
    diagnostics.push(
      makeDiag({
        severity: "info",
        code: "acorn_unavailable",
        message: "Optional parser 'acorn' is not installed. JS AST checks skipped.",
      })
    );
  }

  if (forceError) {
    diagnostics.push(
      makeDiag({
        severity: "error",
        code: "forced_ast_error",
        message: "Forced AST error for hybrid gate tests.",
      })
    );
  }

  if (forceWarning) {
    diagnostics.push(
      makeDiag({
        severity: "warn",
        code: "forced_ast_warning",
        message: "Forced AST warning for severity policy tests.",
      })
    );
  }

  for (const file of files) {
    const filePath = typeof file.path === "string" ? file.path : "";
    const content = typeof file.content === "string" ? file.content : "";
    if (!filePath || !content) {
      diagnostics.push(
        makeDiag({
          severity: "warn",
          code: "invalid_file_entry",
          message: "File entry missing path or content.",
          file: filePath,
        })
      );
      continue;
    }

    const ext = path.extname(filePath).toLowerCase();
    if (ext === ".js") {
      if (acornState.available) {
        validateJsAst(content, filePath, acornState.parser, diagnostics);
      }
      validateJsConstructorParity(content, filePath, diagnostics);
    } else if (ext === ".wxml") {
      validateWxmlSurface(content, filePath, diagnostics);
      validateWxmlStructure(content, filePath, diagnostics);
      validateWxmlDirectiveSemantics(content, filePath, diagnostics);
    }
  }

  const output = {
    ok: true,
    parser_available: acornState.available,
    parser_name: acornState.available ? "acorn" : "none",
    diagnostics,
  };

  process.stdout.write(JSON.stringify(output));
  process.exit(0);
}

main();
