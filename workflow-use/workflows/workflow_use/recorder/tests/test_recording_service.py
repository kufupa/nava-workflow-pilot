"""Tests for RecordingService session lifecycle (no hang on empty recording)."""

import asyncio

import pytest

from workflow_use.recorder.service import RecordingService


@pytest.mark.asyncio
async def test_finalize_recording_signals_complete_without_workflow():
	service = RecordingService()

	await service._finalize_recording('BrowserTaskEnded')

	assert service.recording_complete_event.is_set()
	assert service.final_workflow_output is None


@pytest.mark.asyncio
async def test_finalize_recording_captures_workflow_when_present():
	from workflow_use.recorder.views import HttpWorkflowUpdateEvent, RecordedWorkflowPayload

	service = RecordingService()
	payload = RecordedWorkflowPayload(
		name='test',
		description='test workflow',
		version='1.0.0',
		steps=[{'type': 'navigation', 'url': 'https://example.com'}],
		input_schema=[],
	)
	service.last_workflow_update_event = HttpWorkflowUpdateEvent(timestamp=1, payload=payload)

	await service._finalize_recording('RecordingStoppedEvent')

	assert service.recording_complete_event.is_set()
	assert service.final_workflow_output is payload


@pytest.mark.asyncio
async def test_finalize_recording_is_idempotent():
	service = RecordingService()

	await service._finalize_recording('BrowserTaskEnded')
	await service._finalize_recording('BrowserTaskEnded')

	assert service.recording_complete_event.is_set()


@pytest.mark.asyncio
async def test_finalize_recording_ignores_empty_step_payload():
	from workflow_use.recorder.views import HttpWorkflowUpdateEvent, RecordedWorkflowPayload

	service = RecordingService()
	payload = RecordedWorkflowPayload(name='empty', steps=[])
	service.last_workflow_update_event = HttpWorkflowUpdateEvent(timestamp=1, payload=payload)

	await service._finalize_recording('RecordingStoppedEvent')

	assert service.recording_complete_event.is_set()
	assert service.final_workflow_output is None


@pytest.mark.asyncio
async def test_capture_workflow_unblocks_when_browser_task_ends_without_events():
	service = RecordingService()

	async def fake_browser_task():
		await service._finalize_recording('BrowserTaskEnded')

	service.browser_task = asyncio.create_task(fake_browser_task())
	service.recording_complete_event.clear()

	await asyncio.wait_for(service.recording_complete_event.wait(), timeout=1.0)
