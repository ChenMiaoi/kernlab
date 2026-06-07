#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const repoRoot = path.resolve(__dirname, '..');
const workspace = fs.mkdtempSync(path.join(os.tmpdir(), 'kernlab-skills-'));
const linuxDir = path.join(workspace, 'linux');
fs.mkdirSync(linuxDir);

try {
  const result = spawnSync(process.execPath, [
    path.join(repoRoot, 'bin', 'create-kernlab.js'),
    '--linux-dir',
    linuxDir,
    '--support-submodules',
    '',
    '--dir',
    workspace
  ], { cwd: repoRoot, encoding: 'utf8' });

  assert.strictEqual(result.status, 0, result.stderr || result.stdout);

  const skillDir = path.join(workspace, '.codex', 'skills', 'kernlab-repo-guardrails');
  assert.ok(fs.existsSync(path.join(skillDir, 'SKILL.md')));
  assert.ok(fs.existsSync(path.join(skillDir, 'references', 'linux-kernel-patch-rules.md')));
  assert.match(
    fs.readFileSync(path.join(skillDir, 'SKILL.md'), 'utf8'),
    /Linux-kernel-compliant patches|Linux 内核 patch/
  );
} finally {
  fs.rmSync(workspace, { recursive: true, force: true });
}
