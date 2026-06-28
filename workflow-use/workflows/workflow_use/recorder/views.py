from typing import Any, Literal, Union

from pydantic import BaseModel, Field

from workflow_use.schema.views import WorkflowDefinitionSchema

# --- Event Payloads ---


class RecordingStatusPayload(BaseModel):
	message: str


class RecordedWorkflowPayload(BaseModel):
	"""Loose in-flight recording from the extension (before semantic build).

	Unlike WorkflowDefinitionSchema, allows empty steps and no trailing extract step.
	"""

	workflow_analysis: str | None = None
	name: str = 'Recorded Workflow (Semantic)'
	description: str = ''
	version: str = '1.0'
	default_wait_time: float | None = 0.1
	steps: list[dict[str, Any]] = Field(default_factory=list)
	input_schema: list[Any] = Field(default_factory=list)


# --- Main Event Models (mirroring HttpEvent types from message-bus-types.ts) ---


class BaseHttpEvent(BaseModel):
	timestamp: int


class HttpWorkflowUpdateEvent(BaseHttpEvent):
	type: Literal['WORKFLOW_UPDATE'] = 'WORKFLOW_UPDATE'
	payload: RecordedWorkflowPayload


class HttpRecordingStartedEvent(BaseHttpEvent):
	type: Literal['RECORDING_STARTED'] = 'RECORDING_STARTED'
	payload: RecordingStatusPayload


class HttpRecordingStoppedEvent(BaseHttpEvent):
	type: Literal['RECORDING_STOPPED'] = 'RECORDING_STOPPED'
	payload: RecordingStatusPayload


# Union of all possible event types received by the recorder
RecorderEvent = Union[
	HttpWorkflowUpdateEvent,
	HttpRecordingStartedEvent,
	HttpRecordingStoppedEvent,
]
