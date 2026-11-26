#!/usr/bin/env python3
"""Fullscreen frosted-glass blur backdrop for Clarity Eye-Care on Wayland/Hyprland."""

import signal
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")

from gi.repository import Gdk, Gtk, GtkLayerShell  # noqa: E402


def register_hyprland_blur():
    """Enable GPU Kawase blur on the clarity-blur layer surface if running Hyprland."""
    try:
        subprocess.run(
            [
                "hyprctl",
                "eval",
                'hl.layer_rule({ match = { namespace = "^clarity-blur$" }, blur = true, ignore_alpha = 0 })',
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=1,
        )
    except Exception:
        pass


def create_backdrop(monitor):
    win = Gtk.Window()
    win.set_decorated(False)
    win.set_app_paintable(True)

    screen = win.get_screen()
    visual = screen.get_rgba_visual()
    if visual is not None and screen.is_composited():
        win.set_visual(visual)

    GtkLayerShell.init_for_window(win)
    GtkLayerShell.set_namespace(win, "clarity-blur")
    GtkLayerShell.set_layer(win, GtkLayerShell.Layer.TOP)
    GtkLayerShell.set_monitor(win, monitor)
    GtkLayerShell.set_exclusive_zone(win, -1)
    GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.NONE)

    for edge in (
        GtkLayerShell.Edge.TOP,
        GtkLayerShell.Edge.BOTTOM,
        GtkLayerShell.Edge.LEFT,
        GtkLayerShell.Edge.RIGHT,
    ):
        GtkLayerShell.set_anchor(win, edge, True)

    def on_draw(_widget, cr):
        # Translucent dark frost tint; Hyprland applies GPU blur behind this surface
        cr.set_source_rgba(0.05, 0.06, 0.09, 0.58)
        cr.set_operator(1)  # CAIRO_OPERATOR_SOURCE
        cr.paint()
        return False

    win.connect("draw", on_draw)
    win.show_all()
    return win


def main():
    signal.signal(signal.SIGTERM, lambda *_: Gtk.main_quit())
    signal.signal(signal.SIGINT, lambda *_: Gtk.main_quit())

    register_hyprland_blur()

    display = Gdk.Display.get_default()
    if display is None:
        sys.exit(0)

    windows = []
    n_monitors = display.get_n_monitors()
    for i in range(n_monitors):
        monitor = display.get_monitor(i)
        if monitor is not None:
            windows.append(create_backdrop(monitor))

    if windows:
        Gtk.main()


if __name__ == "__main__":
    main()
