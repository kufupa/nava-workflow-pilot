"""HTTP ingestion accepts raw extension payloads (not final WorkflowDefinitionSchema)."""

from fastapi.testclient import TestClient

from workflow_use.recorder.service import RecordingService


def test_event_endpoint_accepts_navigation_only_workflow():
	service = RecordingService()
	client = TestClient(service.app)

	response = client.post(
		'/event',
		json={
			'type': 'WORKFLOW_UPDATE',
			'timestamp': 1,
			'payload': {
				'name': 'Recorded Workflow (Semantic)',
				'description': 'Recorded on test',
				'version': '1.0',
				'input_schema': [],
				'steps': [{'type': 'navigation', 'url': 'https://example.com', 'description': 'Navigate to https://example.com'}],
			},
		},
	)

	assert response.status_code == 202


def test_event_endpoint_accepts_empty_steps_on_stop_flush():
	service = RecordingService()
	client = TestClient(service.app)

	response = client.post(
		'/event',
		json={
			'type': 'WORKFLOW_UPDATE',
			'timestamp': 1,
			'payload': {
				'name': 'Recorded Workflow (Semantic)',
				'description': 'empty',
				'version': '1.0',
				'input_schema': [],
				'steps': [],
			},
		},
	)

	assert response.status_code == 202
