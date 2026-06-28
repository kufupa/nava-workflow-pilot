"""Tests for shared recorder profile paths."""

from workflow_use.recorder.profile import (
	DEFAULT_USER_DATA_DIR,
	get_recorder_user_data_dir,
	prepare_recorder_profile_dir,
)


def test_default_user_data_dir_is_under_recorder_package():
	assert get_recorder_user_data_dir() == DEFAULT_USER_DATA_DIR.resolve()


def test_recorder_user_data_dir_respects_env_override(tmp_path, monkeypatch):
	custom = tmp_path / 'custom-profile'
	monkeypatch.setenv('RECORDER_USER_DATA_DIR', str(custom))

	assert get_recorder_user_data_dir() == custom.resolve()


def test_prepare_recorder_profile_dir_clears_stale_singleton_lock(tmp_path):
	profile = tmp_path / 'profile'
	profile.mkdir()
	(profile / 'SingletonLock').write_text('stale', encoding='utf-8')

	prepared = prepare_recorder_profile_dir(profile)

	assert prepared == profile.resolve()
	assert not (profile / 'SingletonLock').exists()
