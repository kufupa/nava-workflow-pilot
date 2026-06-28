/**
 * Headed record smoke: capture example.com for ~15s, no stdin narration.
 * Used by scripts/imprint-smoke.sh overnight validation.
 */
import { resolve } from 'node:path';
import { record } from '../imprint/src/imprint/record.ts';

const pilotRoot = resolve(import.meta.dir, '..');
process.env.IMPRINT_HOME ??= resolve(pilotRoot, 'imprint-data');

const ctrl = new AbortController();
const timer = setTimeout(() => ctrl.abort(), 15_000);

try {
  const result = await record({
    site: 'nava-smoke',
    url: 'https://example.com',
    noNarration: true,
    signal: ctrl.signal,
  });
  console.log('[imprint-record-smoke] session:', result.sessionPath);
  console.log('[imprint-record-smoke] count:', result.count);
  if (!result.sessionPath) {
    throw new Error('no sessionPath returned');
  }
} finally {
  clearTimeout(timer);
}
