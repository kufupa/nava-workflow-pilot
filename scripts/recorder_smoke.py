"""Live smoke: launch recorder Chrome, auto-close, verify clean exit (no hang)."""

import asyncio
import pathlib
import sys

from workflow_use.recorder.browser_launcher import run_recorder_browser_until_closed

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXT_DIR = ROOT / 'workflow-use' / 'extension' / '.output' / 'chrome-mv3'
USER_DATA_DIR = ROOT / 'workflow-use' / 'workflows' / 'workflow_use' / 'recorder' / 'user_data_dir_smoke'


async def main() -> int:
	if not EXT_DIR.is_dir():
		print(f'FAIL: extension not built at {EXT_DIR}')
		return 1

	context_holder: list = []

	async def on_ready(ctx):
		context_holder.append(ctx)
		print('OK: Playwright recorder browser opened')

	async def auto_close():
		await asyncio.sleep(6)
		if context_holder:
			print('OK: auto-closing browser (smoke test)')
			await context_holder[0].close()

	closer = asyncio.create_task(auto_close())
	try:
		await asyncio.wait_for(
			run_recorder_browser_until_closed(EXT_DIR, USER_DATA_DIR, on_context_ready=on_ready),
			timeout=30,
		)
	except asyncio.TimeoutError:
		print('FAIL: recorder browser did not close within 30s')
		return 1
	finally:
		closer.cancel()

	print('OK: smoke test passed — browser opened and closed cleanly')
	return 0


if __name__ == '__main__':
	sys.exit(asyncio.run(main()))
