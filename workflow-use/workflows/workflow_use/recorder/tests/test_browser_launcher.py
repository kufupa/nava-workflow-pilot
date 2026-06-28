"""Tests for recorder Chrome launch configuration (no browser-use agent stack)."""

import pathlib

import pytest

from workflow_use.recorder.browser_launcher import build_recorder_chromium_args


def test_build_recorder_chromium_args_loads_only_recorder_extension(tmp_path: pathlib.Path):
	ext_dir = tmp_path / 'chrome-mv3'
	ext_dir.mkdir()

	args = build_recorder_chromium_args(ext_dir)
	ext_resolved = str(ext_dir.resolve())

	assert f'--load-extension={ext_resolved}' in args
	assert f'--disable-extensions-except={ext_resolved}' in args
	assert '--no-default-browser-check' in args
	assert '--no-first-run' in args


def test_build_recorder_chromium_args_does_not_enable_browser_use_default_extensions(tmp_path: pathlib.Path):
	"""Recorder must not pull in uBlock / cookie extensions via browser-use profile."""
	ext_dir = tmp_path / 'chrome-mv3'
	ext_dir.mkdir()

	args = build_recorder_chromium_args(ext_dir)
	joined = ' '.join(args)

	assert 'enable-extensions' not in joined
	assert 'uBlock' not in joined
	assert sum(1 for a in args if a.startswith('--load-extension=')) == 1


def test_build_recorder_chromium_args_includes_linux_flags_on_linux(tmp_path, monkeypatch):
	ext_dir = tmp_path / 'chrome-mv3'
	ext_dir.mkdir()
	monkeypatch.setattr('workflow_use.recorder.browser_launcher.sys.platform', 'linux')

	args = build_recorder_chromium_args(ext_dir)

	assert '--no-sandbox' in args
	assert '--disable-dev-shm-usage' in args


def test_browser_process_env_merges_with_os_environ(monkeypatch):
	import os

	monkeypatch.setenv('HOME', '/home/ubuntu')
	monkeypatch.setenv('DISPLAY', ':10')
	from workflow_use.recorder.browser_launcher import _browser_process_env

	env = _browser_process_env()
	assert env['HOME'] == '/home/ubuntu'
	assert env['DISPLAY'] == ':10'

