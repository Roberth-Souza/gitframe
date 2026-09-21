"""Entry point: the QML overlay plus the single backend object behind it."""

from __future__ import annotations

import os
import signal
import socket
import sys
from pathlib import Path

from PySide6.QtCore import QSocketNotifier
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from gitframe.backend import Backend
from gitframe.single_instance import SingleInstance

ROOT = Path(__file__).resolve().parent
APP_ID = "gitframe"

# Where the distro's Qt keeps the `org.kde.layershell` QML module and the
# layer-shell Wayland plugin.
SYSTEM_QT_QML = "/usr/lib/qt6/qml"
SYSTEM_QT_PLUGINS = "/usr/lib/qt6/plugins"


def _prepend_system_qt_paths() -> None:
    """Let a pip-installed PySide6 find the system layer-shell module.

    pip's PySide6 bundles its own Qt and only searches its own directories.
    A distro `pyside6` already searches these, so this is a no-op there. It
    only works when the system Qt matches the bundled one.
    """
    for var, path in (
        ("QT_PLUGIN_PATH", SYSTEM_QT_PLUGINS),
        ("QML_IMPORT_PATH", SYSTEM_QT_QML),
        ("QML2_IMPORT_PATH", SYSTEM_QT_QML),
    ):
        if os.path.isdir(path):
            existing = os.environ.get(var, "")
            os.environ[var] = path + (os.pathsep + existing if existing else "")


def _quit_on_signal(
    app: QGuiApplication,
) -> tuple[socket.socket, socket.socket, QSocketNotifier]:
    """Quit the Qt loop on SIGTERM / SIGINT - the second launch's toggle.

    Qt's C++ loop does not yield to Python, so a plain handler would only run
    on the next event. The signal writes a byte to a socket the loop watches
    instead. The returned objects must stay referenced while the app runs.
    """
    reader, writer = socket.socketpair()
    reader.setblocking(False)
    writer.setblocking(False)
    signal.set_wakeup_fd(writer.fileno())

    notifier = QSocketNotifier(reader.fileno(), QSocketNotifier.Type.Read)

    def drain_and_quit() -> None:
        try:
            reader.recv(64)
        except OSError:
            pass
        app.quit()

    notifier.activated.connect(drain_and_quit)
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: None)
    return reader, writer, notifier


def main() -> int:
    # A second launch closes the overlay that is already up, and opens nothing.
    instance = SingleInstance()
    if not instance.acquire():
        return 0

    _prepend_system_qt_paths()

    app = QGuiApplication(sys.argv)
    app.setApplicationName(APP_ID)
    app.setDesktopFileName(APP_ID)
    signal_guard = _quit_on_signal(app)

    engine = QQmlApplicationEngine()
    engine.addImportPath(str(ROOT / "qml"))
    engine.addImportPath(SYSTEM_QT_QML)
    backend = Backend()
    # The cache is read before the QML is built, so the first frame already
    # carries the last snapshot instead of fading in over an empty window.
    backend.start()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(ROOT / "qml" / "Main.qml")
    if not engine.rootObjects():
        print(
            "gitframe: the window failed to load. It is a wlr-layer-shell overlay: "
            "install layer-shell-qt and run it on a compositor that supports "
            "the protocol (Hyprland, Sway, river, niri, ...).",
            file=sys.stderr,
        )
        return 1

    try:
        return app.exec()
    finally:
        del signal_guard
        instance.release()


if __name__ == "__main__":
    sys.exit(main())
