import contextlib
import importlib.util
import io
import pathlib
import unittest
from types import SimpleNamespace
from unittest import mock


HELPER_PATH = (
    pathlib.Path(__file__).resolve().parents[1]
    / "touch-guard@marcus-friction.github.io"
    / "helper.py"
)
spec = importlib.util.spec_from_file_location("touch_guard_helper", HELPER_PATH)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class HelperTests(unittest.TestCase):
    def test_only_pure_touchscreens_are_selected(self):
        properties = {
            "/dev/input/event1": "ID_INPUT_TOUCHSCREEN=1\n",
            "/dev/input/event2": (
                "ID_INPUT_TOUCHSCREEN=1\nID_INPUT_KEYBOARD=1\n"
            ),
            "/dev/input/event3": "ID_INPUT_TOUCHPAD=1\n",
        }

        def udev_info(command, **_kwargs):
            return SimpleNamespace(returncode=0, stdout=properties[command[-1]])

        with mock.patch.object(helper.glob, "glob", return_value=list(properties)), \
                mock.patch.object(helper.subprocess, "run", side_effect=udev_info), \
                mock.patch.object(helper.os, "stat", return_value=SimpleNamespace(st_rdev=13)):
            self.assertEqual(helper.touchscreen_nodes(), {"/dev/input/event1": 13})

    def test_failed_grab_closes_device(self):
        with mock.patch.object(helper.os, "open", return_value=42), \
                mock.patch.object(helper.fcntl, "ioctl", side_effect=OSError("busy")), \
                mock.patch.object(helper.os, "close") as close:
            with self.assertRaises(OSError):
                helper.grab("/dev/input/event1")
            close.assert_called_once_with(42)

    def test_stdin_eof_releases_grab(self):
        selector = mock.Mock()
        selector.select.return_value = [1]
        output = io.StringIO()
        with mock.patch.object(helper.os, "geteuid", return_value=0), \
                mock.patch.object(helper, "touchscreen_nodes", return_value={"/dev/input/event1": 13}), \
                mock.patch.object(helper, "grab", return_value=42), \
                mock.patch.object(helper.selectors, "DefaultSelector", return_value=selector), \
                mock.patch.object(helper.os, "read", return_value=b""), \
                mock.patch.object(helper.os, "close") as close, \
                contextlib.redirect_stdout(output):
            self.assertEqual(helper.run(), 0)
        self.assertIn("READY 1", output.getvalue())
        close.assert_called_once_with(42)


if __name__ == "__main__":
    unittest.main()
