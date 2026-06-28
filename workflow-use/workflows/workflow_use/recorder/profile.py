"""Shared recorder browser profile paths (record + replay)."""

from __future__ import annotations

import os
import pathlib

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
DEFAULT_USER_DATA_DIR = SCRIPT_DIR / 'user_data_dir'

# Stale Chrome singleton files left after a crash block the next launch.
_STALE_LOCK_NAMES = ('SingletonLock', 'SingletonSocket', 'SingletonCookie')


def get_recorder_user_data_dir() -> pathlib.Path:
	"""Pilot Chrome profile — cookies/sessions persist across record and replay runs."""
	override = os.environ.get('RECORDER_USER_DATA_DIR', '').strip()
	if override:
		return pathlib.Path(override).expanduser().resolve()
	return DEFAULT_USER_DATA_DIR.resolve()


def prepare_recorder_profile_dir(profile_dir: pathlib.Path | None = None) -> pathlib.Path:
	"""Ensure profile dir exists and remove stale Chrome singleton locks from crashed runs."""
	dir_path = profile_dir or get_recorder_user_data_dir()
	dir_path.mkdir(parents=True, exist_ok=True)
	for name in _STALE_LOCK_NAMES:
		lock = dir_path / name
		if lock.exists():
			try:
				lock.unlink()
			except OSError:
				pass
	return dir_path
