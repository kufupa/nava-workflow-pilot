import asyncio
import json
import pathlib
from typing import Optional

import uvicorn
from fastapi import FastAPI
from playwright.async_api import BrowserContext

from workflow_use.recorder.browser_launcher import run_recorder_browser_until_closed
from workflow_use.recorder.profile import get_recorder_user_data_dir, prepare_recorder_profile_dir
from workflow_use.recorder.views import (
	HttpRecordingStoppedEvent,
	HttpWorkflowUpdateEvent,
	RecordedWorkflowPayload,
	RecorderEvent,
)

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
EXT_DIR = SCRIPT_DIR.parent.parent.parent / 'extension' / '.output' / 'chrome-mv3'
USER_DATA_DIR = get_recorder_user_data_dir()


class RecordingService:
	def __init__(self):
		self.event_queue: asyncio.Queue[RecorderEvent] = asyncio.Queue()
		self.last_workflow_update_event: Optional[HttpWorkflowUpdateEvent] = None
		self._browser_context: Optional[BrowserContext] = None

		self.final_workflow_output: Optional[RecordedWorkflowPayload] = None
		self.recording_complete_event = asyncio.Event()
		self.final_workflow_processed_lock = asyncio.Lock()
		self.final_workflow_processed_flag = False

		self.app = FastAPI(title='Temporary Recording Event Server')
		self.app.add_api_route('/event', self._handle_event_post, methods=['POST'], status_code=202)

		self.uvicorn_server_instance: Optional[uvicorn.Server] = None
		self.server_task: Optional[asyncio.Task] = None
		self.browser_task: Optional[asyncio.Task] = None
		self.event_processor_task: Optional[asyncio.Task] = None

	async def _handle_event_post(self, event_data: RecorderEvent):
		if isinstance(event_data, HttpWorkflowUpdateEvent):
			self.last_workflow_update_event = event_data
			step_count = len(event_data.payload.steps) if event_data.payload.steps else 0
			print(f'[Service] Workflow update received ({step_count} steps).')
		await self.event_queue.put(event_data)
		return {'status': 'accepted', 'message': 'Event queued for processing'}

	async def _process_event_queue(self):
		print('[Service] Event processing task started.')
		try:
			while True:
				event = await self.event_queue.get()
				print(f'[Service] Event Received: {event.type}')
				if isinstance(event, HttpWorkflowUpdateEvent):
					pass
				elif isinstance(event, HttpRecordingStoppedEvent):
					print('[Service] RecordingStoppedEvent received, processing final workflow...')
					await self._finalize_recording('RecordingStoppedEvent')
				self.event_queue.task_done()
		except asyncio.CancelledError:
			print('[Service] Event processing task cancelled.')
		except Exception as e:
			print(f'[Service] Error in event processing task: {e}')

	async def _finalize_recording(self, trigger_reason: str) -> None:
		"""Capture workflow if present and always unblock capture_workflow waiters."""
		should_close_browser = False
		async with self.final_workflow_processed_lock:
			if self.final_workflow_processed_flag:
				return

			self.final_workflow_processed_flag = True
			if self.last_workflow_update_event:
				payload = self.last_workflow_update_event.payload
				if payload.steps:
					print(f'[Service] Capturing final workflow ({len(payload.steps)} steps, trigger: {trigger_reason}).')
					self.final_workflow_output = payload
				else:
					print(f'[Service] Workflow update had no steps (Trigger: {trigger_reason}).')
			else:
				print(f'[Service] No workflow captured (Trigger: {trigger_reason}).')

			print('[Service] Setting recording_complete_event.')
			self.recording_complete_event.set()
			should_close_browser = trigger_reason == 'RecordingStoppedEvent'

		if should_close_browser and self._browser_context:
			print('[Service] Attempting to close browser due to RecordingStoppedEvent...')
			try:
				await self._browser_context.close()
				print('[Service] Browser close command issued.')
			except Exception as e_close:
				print(f'[Service] Error closing browser on recording stop: {e_close}')
			finally:
				self._browser_context = None

	async def _launch_browser_and_wait(self):
		print(f'[Service] Attempting to load extension from: {EXT_DIR}')
		if not EXT_DIR.exists() or not EXT_DIR.is_dir():
			print(f'[Service] ERROR: Extension directory not found: {EXT_DIR}')
			await self._finalize_recording('ExtensionMissing')
			return

		prepare_recorder_profile_dir(USER_DATA_DIR)
		print(f'[Service] Using browser user data directory: {USER_DATA_DIR}')
		print('[Service] Starting Playwright recorder browser (no browser-use agent CDP)...')

		async def on_context_ready(context: BrowserContext) -> None:
			self._browser_context = context

		try:
			await run_recorder_browser_until_closed(
				EXT_DIR,
				USER_DATA_DIR,
				on_context_ready=on_context_ready,
			)
			print('[Service] Recorder browser closed by user.')
		except asyncio.CancelledError:
			print('[Service] Browser task cancelled.')
			if self._browser_context:
				try:
					await self._browser_context.close()
				except Exception:
					pass
			raise
		except Exception as e:
			print(f'[Service] Error in browser task: {e}')
		finally:
			print('[Service] Browser task finalization.')
			self._browser_context = None
			await self._finalize_recording('BrowserTaskEnded')

	async def capture_workflow(self) -> Optional[RecordedWorkflowPayload]:
		print('[Service] Starting capture_workflow session...')
		self.last_workflow_update_event = None
		self.final_workflow_output = None
		self.recording_complete_event.clear()
		self.final_workflow_processed_flag = False
		self._browser_context = None

		self.event_processor_task = asyncio.create_task(self._process_event_queue())
		self.browser_task = asyncio.create_task(self._launch_browser_and_wait())

		config = uvicorn.Config(self.app, host='127.0.0.1', port=7331, log_level='warning', loop='asyncio')
		self.uvicorn_server_instance = uvicorn.Server(config)
		self.server_task = asyncio.create_task(self.uvicorn_server_instance.serve())
		print('[Service] Uvicorn server task started.')

		try:
			print('[Service] Waiting for recording to complete...')
			await self.recording_complete_event.wait()
			print('[Service] Recording complete event received. Proceeding to cleanup.')
		except asyncio.CancelledError:
			print('[Service] capture_workflow task was cancelled externally.')
		finally:
			print('[Service] Starting cleanup phase...')

			if self.uvicorn_server_instance and self.server_task and not self.server_task.done():
				print('[Service] Signaling Uvicorn server to shut down...')
				self.uvicorn_server_instance.should_exit = True
				try:
					await asyncio.wait_for(self.server_task, timeout=5)
				except asyncio.TimeoutError:
					print('[Service] Uvicorn server shutdown timed out. Cancelling task.')
					self.server_task.cancel()
				except asyncio.CancelledError:
					pass
				except Exception as e_server_shutdown:
					print(f'[Service] Error during Uvicorn server shutdown: {e_server_shutdown}')

			if self.browser_task and not self.browser_task.done():
				print('[Service] Waiting for browser task to finish...')
				try:
					await asyncio.wait_for(self.browser_task, timeout=15)
				except asyncio.TimeoutError:
					print('[Service] Browser task timed out. Cancelling...')
					self.browser_task.cancel()
					try:
						await self.browser_task
					except asyncio.CancelledError:
						pass
				except asyncio.CancelledError:
					pass
				except Exception as e_browser_wait:
					print(f'[Service] Error awaiting browser task: {e_browser_wait}')

			if self._browser_context:
				print('[Service] Ensuring browser is closed in cleanup...')
				try:
					await self._browser_context.close()
				except Exception as e_browser_close:
					print(f'[Service] Error closing browser in final cleanup: {e_browser_close}')

			if self.event_processor_task and not self.event_processor_task.done():
				print('[Service] Cancelling event processor task...')
				self.event_processor_task.cancel()
				try:
					await self.event_processor_task
				except asyncio.CancelledError:
					pass
				except Exception as e_ep_cancel:
					print(f'[Service] Error awaiting cancelled event processor task: {e_ep_cancel}')

			print('[Service] Cleanup phase complete.')

		if self.final_workflow_output:
			print('[Service] Returning captured workflow.')
		else:
			print('[Service] No workflow captured or an error occurred.')
		return self.final_workflow_output


async def main_service_runner():
	service = RecordingService()
	workflow_data = await service.capture_workflow()
	if workflow_data:
		print('\n--- CAPTURED WORKFLOW DATA (from main_service_runner) ---')
		try:
			print(workflow_data.model_dump_json(indent=2))
		except AttributeError:
			print(json.dumps(workflow_data, indent=2))
		print('-----------------------------------------------------')
	else:
		print('No workflow data was captured by the service.')


if __name__ == '__main__':
	try:
		asyncio.run(main_service_runner())
	except KeyboardInterrupt:
		print('Service runner interrupted by user.')
