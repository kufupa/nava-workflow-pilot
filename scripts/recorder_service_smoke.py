"""Live smoke: RecordingService exits when browser closes without workflow events."""

import asyncio
import sys

from workflow_use.recorder.service import RecordingService


async def main() -> int:
	service = RecordingService()

	async def auto_finalize():
		await asyncio.sleep(2)
		await service._finalize_recording('SmokeTest')

	service.browser_task = asyncio.create_task(auto_finalize())
	service.recording_complete_event.clear()

	try:
		await asyncio.wait_for(service.recording_complete_event.wait(), timeout=5)
	except asyncio.TimeoutError:
		print('FAIL: service hung waiting for recording_complete_event')
		return 1

	print('OK: RecordingService unblocked without workflow events')
	return 0


if __name__ == '__main__':
	sys.exit(asyncio.run(main()))
