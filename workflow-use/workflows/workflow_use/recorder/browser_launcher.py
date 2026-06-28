"""Launch Chrome for human teach sessions without browser-use agent CDP management."""

from __future__ import annotations

import asyncio
import os
import pathlib
import sys
from typing import Awaitable, Callable, Optional

from playwright.async_api import BrowserContext, Playwright, async_playwright

from workflow_use.recorder.profile import get_recorder_user_data_dir, prepare_recorder_profile_dir

LINUX_CHROMIUM_ARGS = [
	'--no-sandbox',
	'--disable-dev-shm-usage',
	'--disable-gpu',
]


def _needs_linux_chromium_args() -> bool:
	return sys.platform == 'linux'


def build_recorder_chromium_args(ext_dir: pathlib.Path) -> list[str]:
	"""Chrome args that load only the workflow recorder extension."""
	ext_resolved = str(ext_dir.resolve())
	args = [
		f'--disable-extensions-except={ext_resolved}',
		f'--load-extension={ext_resolved}',
		'--no-default-browser-check',
		'--no-first-run',
	]
	if _needs_linux_chromium_args():
		args.extend(LINUX_CHROMIUM_ARGS)
	return args


def _browser_process_env() -> dict[str, str]:
	"""Merge parent env with display/Playwright overrides (Playwright env= replaces, not merges)."""
	env = dict(os.environ)
	for key in ('DISPLAY', 'XAUTHORITY', 'DBUS_SESSION_BUS_ADDRESS', 'PLAYWRIGHT_BROWSERS_PATH'):
		val = os.environ.get(key, '').strip()
		if val:
			env[key] = val
	return env


async def run_recorder_browser_until_closed(
	ext_dir: pathlib.Path,
	user_data_dir: pathlib.Path | None = None,
	*,
	on_context_ready: Optional[Callable[[BrowserContext], Awaitable[None]]] = None,
) -> None:
	"""Open headed Chrome with the recorder extension; block until the user closes it."""
	profile_dir = prepare_recorder_profile_dir(user_data_dir)
	chromium_args = build_recorder_chromium_args(ext_dir)

	async with async_playwright() as playwright:
		context = await _launch_recorder_context(playwright, profile_dir, chromium_args)
		try:
			if on_context_ready:
				await on_context_ready(context)
			if not context.pages:
				await context.new_page()
			await _wait_until_browser_closed(context)
		finally:
			try:
				await context.close()
			except Exception:
				pass


async def _launch_recorder_context(
	playwright: Playwright,
	user_data_dir: pathlib.Path,
	chromium_args: list[str],
) -> BrowserContext:
	launch_kwargs: dict = {
		'headless': False,
		'args': chromium_args,
		'viewport': None,
		'ignore_default_args': ['--disable-extensions'],
	}
	launch_kwargs['env'] = _browser_process_env()

	return await playwright.chromium.launch_persistent_context(
		str(user_data_dir.resolve()),
		**launch_kwargs,
	)


async def _wait_until_browser_closed(context: BrowserContext) -> None:
	"""Poll until all pages are gone (user closed the browser window)."""
	while context.pages:
		await asyncio.sleep(0.5)
