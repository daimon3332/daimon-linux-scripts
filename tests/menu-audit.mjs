import fs from 'node:fs';
import {spawnSync} from 'node:child_process';

const sourcePath = process.env.DAIMON_TEST_SOURCE || 'linux-toolbox.sh';
const source = Buffer.from(fs.readFileSync(sourcePath, 'utf8').replace(/\r/g, ''));
function parse(input) {
  const parsed = spawnSync(process.argv[2] || 'shfmt', ['-ln', 'bash', '-tojson'], {
    input, encoding: 'utf8', maxBuffer: 128 * 1024 * 1024,
  });
  if (parsed.status !== 0) throw new Error(parsed.stderr || 'shfmt is required');
  return JSON.parse(parsed.stdout);
}
const cases = [];
let embedded = 0;
function walk(node, fn = 'CLI', buffer = source, label = '') {
  if (!node || typeof node !== 'object') return;
  const text = item => buffer.subarray(item.Pos.Offset, item.End.Offset).toString();
  if (node.Type === 'FuncDecl') fn = node.Name.Value;
  if (node.Hdoc?.Parts?.every(part => part.Type === 'Lit')) {
    const script = node.Hdoc.Parts.map(part => part.Value).join('');
    if (script.startsWith('#!/bin/bash')) {
      const syntax = spawnSync(process.env.BASH_BIN || 'bash', ['-n'], {input: script, encoding: 'utf8'});
      if (syntax.status !== 0) throw new Error(syntax.stderr);
      embedded++;
      const body = Buffer.from(script);
      walk(parse(body), 'CLI', body, `${label}embedded@${node.Pos.Line}/`);
    }
  }
  if (node.Type === 'CaseClause') {
    const patterns = node.Items.map(item => item.Patterns.map(text));
    const numeric = patterns.flat().some(pattern => /^\d+$/.test(pattern));
    const cli = fn === 'CLI' && text(node.Word) === '$1';
    if ((numeric || cli) && patterns.flat().every(pattern =>
      /^(?:[\p{L}\p{N}_.-]+|\*|""|'')$/u.test(pattern))) {
      cases.push({fn: label + fn, line: node.Pos.Line, selector: text(node.Word), patterns});
    }
  }
  for (const [key, value] of Object.entries(node)) {
    if (key === 'Pos' || key === 'End') continue;
    if (Array.isArray(value)) value.forEach(child => walk(child, fn, buffer, label));
    else if (value && typeof value === 'object') walk(value, fn, buffer, label);
  }
}
walk(parse(source));
const commands = ['set -eu'];
let checks = 0;
for (const [index, entry] of cases.entries()) {
  commands.push(`case_${index}() { case "$1" in`);
  for (const [branch, patterns] of entry.patterns.entries()) {
    commands.push(`${patterns.join('|')}) printf '%s' '${branch}' ;;`);
  }
  commands.push('esac; }');
  for (const [branch, patterns] of entry.patterns.entries()) {
    for (const pattern of patterns) {
      const input = pattern === '*' ? '__invalid_audit_input__' : pattern.replace(/["']/g, '');
      commands.push(`[ "$(case_${index} '${input}')" = '${branch}' ] || { echo 'Shadowed branch: ${entry.fn}:${entry.line}:${pattern}'; exit 1; }`);
      checks++;
    }
  }
}
// Only case patterns execute. Branch bodies never run on the host.
const result = spawnSync(process.env.BASH_BIN || 'bash', ['--noprofile', '--norc'], {
  input: commands.join('\n'), encoding: 'utf8', maxBuffer: 8 * 1024 * 1024,
});
if (result.status !== 0) throw new Error(result.stdout + result.stderr);
if (process.argv.includes('--inventory')) {
  console.log('Function\tLine\tSelector\tOption\tCoverage');
  for (const entry of cases) {
    for (const patterns of entry.patterns) {
      for (const pattern of patterns) {
        console.log(`${entry.fn}\t${entry.line}\t${entry.selector}\t${pattern}\tpattern-dispatch-only`);
      }
    }
  }
}
console.log(`PASS ${checks} patterns in ${cases.length} case blocks; ${embedded} embedded Bash scripts parsed; handler side effects are not executed`);
