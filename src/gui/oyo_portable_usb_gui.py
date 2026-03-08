#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import GLib, Gtk


APP_TITLE = "oYo Portable USB Creator"


class MainWindow(Gtk.ApplicationWindow):
    def __init__(self, app: Gtk.Application, cli_path: str):
        super().__init__(application=app, title=APP_TITLE)

        self.cli_path = cli_path
        self.selected_iso = ""
        self.selected_device = ""
        self.create_process = None
        self.iso_dialog = None
        self.doctor_ok = False
        self.last_doctor_device = ""
        self.last_doctor_iso = ""

        self.set_default_size(980, 760)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        root.set_margin_top(20)
        root.set_margin_bottom(20)
        root.set_margin_start(20)
        root.set_margin_end(20)
        self.set_child(root)

        # タイトル
        title = Gtk.Label()
        title.set_xalign(0)
        title.set_markup("<span size='xx-large' weight='bold'>oYo Portable USB Creator</span>")
        root.append(title)

        desc = Gtk.Label(
            label="open.Yellow.os / Debian系 live ISO を BIOS/UEFI 両対応の persistence 付きUSBに作成します。"
        )
        desc.set_xalign(0)
        desc.set_wrap(True)
        root.append(desc)

        # ISO選択
        iso_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        root.append(iso_row)

        iso_label = Gtk.Label(label="ISO ファイル")
        iso_label.set_xalign(0)
        iso_label.set_size_request(110, -1)
        iso_row.append(iso_label)

        self.iso_entry = Gtk.Entry()
        self.iso_entry.set_hexpand(True)
        self.iso_entry.set_editable(False)
        iso_row.append(self.iso_entry)

        self.iso_button = Gtk.Button(label="参照")
        self.iso_button.connect("clicked", self.on_pick_iso)
        iso_row.append(self.iso_button)

        # USBデバイス選択
        dev_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        root.append(dev_row)

        dev_label = Gtk.Label(label="USB デバイス")
        dev_label.set_xalign(0)
        dev_label.set_size_request(110, -1)
        dev_row.append(dev_label)

        self.device_dropdown = Gtk.DropDown.new_from_strings(["(なし)"])
        self.device_dropdown.set_hexpand(True)
        self.device_dropdown.connect("notify::selected", self.on_device_changed)
        dev_row.append(self.device_dropdown)

        self.reload_button = Gtk.Button(label="再読み込み")
        self.reload_button.connect("clicked", self.on_reload_devices)
        dev_row.append(self.reload_button)

        # 操作ボタン
        button_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        root.append(button_row)

        self.doctor_button = Gtk.Button(label="doctor 実行")
        self.doctor_button.connect("clicked", self.on_run_doctor)
        self.doctor_button.set_sensitive(False)
        button_row.append(self.doctor_button)

        self.create_button = Gtk.Button(label="Portable USB 作成")
        self.create_button.connect("clicked", self.on_run_create)
        self.create_button.set_sensitive(False)
        button_row.append(self.create_button)

        # 進捗
        self.progress = Gtk.ProgressBar()
        self.progress.set_hexpand(True)
        self.progress.set_fraction(0.0)
        root.append(self.progress)

        self.status_label = Gtk.Label(label="準備完了")
        self.status_label.set_xalign(0)
        root.append(self.status_label)

        # doctor結果
        doctor_frame = Gtk.Frame(label="doctor 結果")
        doctor_frame.set_hexpand(True)
        doctor_frame.set_vexpand(True)
        root.append(doctor_frame)

        self.doctor_view = Gtk.TextView()
        self.doctor_view.set_editable(False)
        self.doctor_view.set_cursor_visible(False)
        self.doctor_view.set_monospace(True)
        self.doctor_buffer = self.doctor_view.get_buffer()

        doctor_scroll = Gtk.ScrolledWindow()
        doctor_scroll.set_hexpand(True)
        doctor_scroll.set_vexpand(True)
        doctor_scroll.set_child(self.doctor_view)
        doctor_frame.set_child(doctor_scroll)

        # createログ
        log_frame = Gtk.Frame(label="create ログ")
        log_frame.set_hexpand(True)
        log_frame.set_vexpand(True)
        root.append(log_frame)

        self.log_view = Gtk.TextView()
        self.log_view.set_editable(False)
        self.log_view.set_cursor_visible(False)
        self.log_view.set_monospace(True)
        self.log_buffer = self.log_view.get_buffer()

        self.log_scroll = Gtk.ScrolledWindow()
        self.log_scroll.set_hexpand(True)
        self.log_scroll.set_vexpand(True)
        self.log_scroll.set_child(self.log_view)
        log_frame.set_child(self.log_scroll)

        self.device_items = []
        self.load_devices()

    # -----------------------------
    # 汎用
    # -----------------------------
    def set_status(self, text: str) -> None:
        self.status_label.set_text(text)

    def scroll_log_to_bottom(self):
        vadj = self.log_scroll.get_vadjustment()
        if vadj is not None:
            GLib.idle_add(vadj.set_value, vadj.get_upper() - vadj.get_page_size())

    def append_log(self, text: str) -> None:
        end = self.log_buffer.get_end_iter()
        self.log_buffer.insert(end, text + "\n")
        self.scroll_log_to_bottom()

    def set_doctor_text(self, text: str) -> None:
        self.doctor_buffer.set_text(text)

    def invalidate_doctor_result(self):
        self.doctor_ok = False
        self.last_doctor_iso = ""
        self.last_doctor_device = ""
        self.update_action_state()

    def update_action_state(self) -> None:
        iso_ok = bool(self.selected_iso)
        dev_ok = bool(self.selected_device)
        busy = self.create_process is not None

        doctor_ready = (
            self.doctor_ok
            and self.last_doctor_iso == self.selected_iso
            and self.last_doctor_device == self.selected_device
        )

        self.doctor_button.set_sensitive(iso_ok and dev_ok and not busy)
        self.create_button.set_sensitive(iso_ok and dev_ok and doctor_ready and not busy)
        self.iso_button.set_sensitive(not busy)
        self.reload_button.set_sensitive(not busy)
        self.device_dropdown.set_sensitive(not busy)

    def show_error(self, title: str, message: str) -> None:
        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            buttons=Gtk.ButtonsType.OK,
            message_type=Gtk.MessageType.ERROR,
            text=f"{title}\n\n{message}",
        )
        dialog.connect("response", lambda d, _r: d.destroy())
        dialog.show()

    def show_info(self, title: str, message: str) -> None:
        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            buttons=Gtk.ButtonsType.OK,
            message_type=Gtk.MessageType.INFO,
            text=f"{title}\n\n{message}",
        )
        dialog.connect("response", lambda d, _r: d.destroy())
        dialog.show()

    def confirm_create(self):
        message = (
            "選択したUSBデバイスの内容はすべて消去されます。\n\n"
            f"ISO:\n  {self.selected_iso}\n\n"
            f"USBデバイス:\n  {self.selected_device}\n\n"
            "続行しますか？"
        )

        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            buttons=Gtk.ButtonsType.OK_CANCEL,
            message_type=Gtk.MessageType.WARNING,
            text=f"Portable USB を作成します\n\n{message}",
        )

        result_holder = {"ok": False}
        loop = GLib.MainLoop()

        def on_response(d, response):
            result_holder["ok"] = (response == Gtk.ResponseType.OK)
            d.destroy()
            loop.quit()

        dialog.connect("response", on_response)
        dialog.show()
        loop.run()

        return result_holder["ok"]

    def run_cli_json(self, args, use_pkexec: bool = False):
        if use_pkexec:
            cmd = ["pkexec", self.cli_path] + args
        else:
            cmd = [self.cli_path] + args

        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)

    def format_doctor_result(self, data):
        result = data.get("result", "")
        device = data.get("device", "")
        iso = data.get("iso", "")
        mode = data.get("mode", "")
        checks = data.get("checks", [])

        device_info = data.get("device_info", {}) or {}
        size = device_info.get("size", "")
        model = device_info.get("model", "")

        lines = []

        if result == "DOCTOR_OK":
            lines.append("診断結果: OK")
        else:
            lines.append(f"診断結果: {result}")

        lines.append("")
        lines.append("ISO")
        lines.append(f"  {iso}")
        lines.append("")
        lines.append("USBデバイス")
        if size or model:
            lines.append(f"  {device} {size} {model}".rstrip())
        else:
            lines.append(f"  {device}")
        lines.append("")
        lines.append("ブートモード")
        if mode == "UEFI_AND_BIOS":
            lines.append("  UEFI + BIOS")
        else:
            lines.append(f"  {mode}")
        lines.append("")
        lines.append("確認項目")

        check_names = {
            "COMMANDS": "必要コマンド",
            "ISO": "ISO",
            "DEVICE": "デバイス",
            "CAPACITY": "容量",
            "LIVE_FILES": "live ファイル",
        }

        for c in checks:
            label = check_names.get(c, c)
            lines.append(f"  ✓ {label}")

        return "\n".join(lines)

    # -----------------------------
    # ISO選択
    # -----------------------------
    def on_pick_iso(self, _button):
        self.iso_dialog = Gtk.FileChooserNative.new(
            "ISO を選択",
            self,
            Gtk.FileChooserAction.OPEN,
            "選択",
            "キャンセル",
        )

        filter_iso = Gtk.FileFilter()
        filter_iso.set_name("ISO files")
        filter_iso.add_pattern("*.iso")
        self.iso_dialog.add_filter(filter_iso)

        filter_all = Gtk.FileFilter()
        filter_all.set_name("All files")
        filter_all.add_pattern("*")
        self.iso_dialog.add_filter(filter_all)

        self.iso_dialog.connect("response", self.on_pick_iso_response)
        self.iso_dialog.show()

    def on_pick_iso_response(self, dialog, response):
        try:
            if response == Gtk.ResponseType.ACCEPT:
                file_obj = dialog.get_file()
                if file_obj is not None:
                    path = file_obj.get_path() or ""
                    self.selected_iso = path
                    self.iso_entry.set_text(path)
                    self.invalidate_doctor_result()
                    self.set_doctor_text("")
        finally:
            dialog.destroy()
            self.iso_dialog = None
            self.update_action_state()

    # -----------------------------
    # デバイス一覧
    # -----------------------------
    def load_devices(self) -> None:
        self.set_status("USBデバイス一覧を取得しています")
        try:
            devices = self.run_cli_json(["list-devices", "--json"])
        except subprocess.CalledProcessError as e:
            self.device_items = []
            self.device_dropdown.set_model(Gtk.StringList.new(["(なし)"]))
            self.selected_device = ""
            self.update_action_state()
            detail = e.stderr.strip() if e.stderr else str(e)
            self.show_error("デバイス一覧取得に失敗しました", detail)
            self.set_status("デバイス一覧取得に失敗しました")
            return
        except Exception as e:
            self.device_items = []
            self.device_dropdown.set_model(Gtk.StringList.new(["(なし)"]))
            self.selected_device = ""
            self.update_action_state()
            self.show_error("デバイス一覧取得に失敗しました", str(e))
            self.set_status("デバイス一覧取得に失敗しました")
            return

        self.device_items = devices

        if not devices:
            self.device_dropdown.set_model(Gtk.StringList.new(["(なし)"]))
            self.device_dropdown.set_selected(0)
            self.selected_device = ""
            self.set_status("USBデバイスが見つかりません")
            self.update_action_state()
            return

        labels = []
        for item in devices:
            label = f"{item.get('device', '')} {item.get('size', '')} {item.get('model', '')}".strip()
            labels.append(label)

        self.device_dropdown.set_model(Gtk.StringList.new(labels))
        self.device_dropdown.set_selected(0)
        self.selected_device = devices[0].get("device", "")
        self.set_status("準備完了")
        self.update_action_state()

    def on_reload_devices(self, _button):
        self.invalidate_doctor_result()
        self.set_doctor_text("")
        self.load_devices()

    def on_device_changed(self, dropdown, _pspec):
        idx = dropdown.get_selected()
        if idx == Gtk.INVALID_LIST_POSITION:
            self.selected_device = ""
        elif 0 <= idx < len(self.device_items):
            self.selected_device = self.device_items[idx].get("device", "")
        else:
            self.selected_device = ""

        self.invalidate_doctor_result()
        self.set_doctor_text("")
        self.update_action_state()

    # -----------------------------
    # doctor
    # -----------------------------
    def on_run_doctor(self, _button):
        if not self.selected_iso or not self.selected_device:
            self.show_error("入力不足", "ISOファイルとUSBデバイスを選択してください。")
            return

        self.set_status("doctor を実行しています")
        self.set_doctor_text("doctor 実行中...")
        self.update_action_state()

        def worker():
            try:
                data = self.run_cli_json(
                    ["doctor", "--iso", self.selected_iso, "--device", self.selected_device, "--json"],
                    use_pkexec=True,
                )

                pretty = self.format_doctor_result(data)

                def done_ok():
                    self.doctor_ok = True
                    self.last_doctor_iso = self.selected_iso
                    self.last_doctor_device = self.selected_device
                    self.set_doctor_text(pretty)
                    self.set_status("doctor 完了")
                    self.update_action_state()
                    return False

                GLib.idle_add(done_ok)

            except subprocess.CalledProcessError as e:
                detail = e.stderr.strip() if e.stderr else str(e)

                def done_ng():
                    self.doctor_ok = False
                    self.last_doctor_iso = ""
                    self.last_doctor_device = ""
                    self.set_doctor_text(f"doctor 失敗:\n{detail}")
                    self.set_status("doctor 失敗")
                    self.show_error("doctor に失敗しました", detail)
                    self.update_action_state()
                    return False

                GLib.idle_add(done_ng)

            except Exception as e:
                def done_ex():
                    self.doctor_ok = False
                    self.last_doctor_iso = ""
                    self.last_doctor_device = ""
                    self.set_doctor_text(f"doctor 失敗:\n{e}")
                    self.set_status("doctor 失敗")
                    self.show_error("doctor に失敗しました", str(e))
                    self.update_action_state()
                    return False

                GLib.idle_add(done_ex)

        threading.Thread(target=worker, daemon=True).start()

    # -----------------------------
    # create
    # -----------------------------
    def on_run_create(self, _button):
        if not self.selected_iso or not self.selected_device:
            self.show_error("入力不足", "ISOファイルとUSBデバイスを選択してください。")
            return

        if not self.doctor_ok:
            self.show_error("doctor 未実行", "先に doctor を実行して問題がないことを確認してください。")
            return

        if not self.confirm_create():
            return

        self.progress.set_fraction(0.0)
        self.log_buffer.set_text("")
        self.set_status("create を開始しています")
        self.update_action_state()

        cmd = [
            "pkexec",
            self.cli_path,
            "create",
            "--iso",
            self.selected_iso,
            "--device",
            self.selected_device,
            "--yes",
            "--force",
        ]

        try:
            self.create_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
        except Exception as e:
            self.create_process = None
            self.update_action_state()
            self.show_error("create の開始に失敗しました", str(e))
            self.set_status("create の開始に失敗しました")
            return

        threading.Thread(target=self.read_create_output, daemon=True).start()

    def read_create_output(self):
        proc = self.create_process
        if proc is None or proc.stdout is None:
            return

        for line in proc.stdout:
            text = line.rstrip("\n")

            def update_line(t=text):
                self.append_log(t)

                if t.startswith("PROGRESS:"):
                    parts = t.split(":", 2)
                    if len(parts) >= 3:
                        try:
                            pct = int(parts[1])
                        except ValueError:
                            pct = 0
                        msg = parts[2]
                        self.progress.set_fraction(max(0, min(100, pct)) / 100.0)
                        self.set_status(msg)

                elif t.startswith("RESULT:SUCCESS"):
                    self.progress.set_fraction(1.0)
                    self.set_status("完了しました")

                return False

            GLib.idle_add(update_line)

        rc = proc.wait()

        def finish():
            self.create_process = None
            self.update_action_state()

            if rc == 0:
                self.set_status("Portable USB 作成が完了しました")
                self.progress.set_fraction(1.0)
                self.show_info(
                    "完了",
                    "Portable USB の作成が完了しました。\n\n"
                    "このUSBは BIOS / UEFI 両対応・persistence 対応です。"
                )
            else:
                self.set_status("Portable USB 作成に失敗しました")
                self.show_error("作成に失敗しました", "create ログを確認してください。")

            return False

        GLib.idle_add(finish)


class App(Gtk.Application):
    def __init__(self, cli_path: str):
        super().__init__(application_id="jp.openyellowos.oyoportableusbcreator")
        self.cli_path = cli_path

    def do_activate(self):
        win = self.props.active_window
        if win is None:
            win = MainWindow(self, self.cli_path)
        win.present()


def resolve_cli_path(argv):
    if len(argv) >= 3 and argv[1] == "--cli":
        return argv[2]

    env_cli = os.environ.get("OYO_PORTABLE_USB_CLI")
    if env_cli:
        return env_cli

    installed_cli = "/usr/lib/oyo-portable-usb-creator/oyo-portable-usb-cli"
    if os.path.exists(installed_cli):
        return installed_cli

    repo_cli = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "bin", "oyo-portable-usb-cli")
    )
    return repo_cli


def main():
    cli_path = resolve_cli_path(sys.argv)
    app = App(cli_path)
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
