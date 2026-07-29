import json
import os
import queue
import re
import threading
import time
import webbrowser
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from pathlib import Path
from tkinter import END, BOTH, LEFT, RIGHT, X, Y, BooleanVar, DoubleVar, IntVar, StringVar, Tk, Toplevel
from tkinter import messagebox, ttk

try:
    import winsound
except ImportError:
    winsound = None

from playwright.sync_api import Error as PlaywrightError
from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
from playwright.sync_api import sync_playwright


APP_DIR = Path(__file__).resolve().parent
PROFILE_DIR = APP_DIR / "browser_profile"
SETTINGS_FILE = APP_DIR / "settings.json"
LOG_FILE = APP_DIR / "monitor.log"


@dataclass
class LotCandidate:
    title: str
    current_price: str = ""
    start_price: str = ""
    bid_count: str = ""
    remaining: str = ""
    end_time: str = ""
    url: str = ""
    status: str = ""
    raw: str = ""


def now_text():
    return datetime.now().strftime("%H:%M:%S")


def append_log(text):
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as f:
        f.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {text}\n")


def safe_float(text):
    if text is None:
        return None
    cleaned = re.sub(r"[^\d.]", "", str(text).replace(",", ""))
    if not cleaned:
        return None
    try:
        return float(cleaned)
    except ValueError:
        return None


def parse_remaining_seconds(text):
    if not text:
        return None
    text = text.replace("：", ":").replace(" ", "")
    m = re.search(r"(\d+)\s*天\s*(\d+)\s*[小时时]\s*(\d+)\s*分\s*(\d+)\s*秒", text)
    if m:
        d, h, minute, sec = [int(x) for x in m.groups()]
        return d * 86400 + h * 3600 + minute * 60 + sec
    m = re.search(r"(\d+)\s*[小时时]\s*(\d+)\s*分\s*(\d+)\s*秒", text)
    if m:
        h, minute, sec = [int(x) for x in m.groups()]
        return h * 3600 + minute * 60 + sec
    m = re.search(r"(\d+):(\d+):(\d+)", text)
    if m:
        h, minute, sec = [int(x) for x in m.groups()]
        return h * 3600 + minute * 60 + sec
    m = re.search(r"(\d+)\s*分\s*(\d+)\s*秒", text)
    if m:
        minute, sec = [int(x) for x in m.groups()]
        return minute * 60 + sec
    m = re.search(r"(\d+)\s*秒", text)
    if m:
        return int(m.group(1))
    return None


def parse_datetime_seconds(text):
    patterns = [
        r"(20\d{2}[-/]\d{1,2}[-/]\d{1,2}\s+\d{1,2}:\d{2}:\d{2})",
        r"(20\d{2}[-/]\d{1,2}[-/]\d{1,2}\s+\d{1,2}:\d{2})",
    ]
    for pattern in patterns:
        m = re.search(pattern, text)
        if not m:
            continue
        value = m.group(1).replace("/", "-")
        for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
            try:
                end_time = datetime.strptime(value, fmt)
                return max(0, int((end_time - datetime.now()).total_seconds())), value
            except ValueError:
                pass
    return None, ""


def first_match(text, patterns):
    for pattern in patterns:
        m = re.search(pattern, text, re.S)
        if m:
            return re.sub(r"\s+", " ", m.group(1)).strip()
    return ""


def extract_lot_from_text(text, url=""):
    compact = re.sub(r"\s+", " ", text).strip()
    lines = [x.strip() for x in text.splitlines() if x.strip()]
    title = ""
    for line in lines:
        if len(line) >= 5 and not re.search(r"(起拍|当前|保证金|报名|围观|出价|竞价|结束|剩余|评估|加价)", line):
            title = line[:80]
            break
    if not title:
        title = compact[:80] if compact else "未识别标题"

    bid_count = first_match(compact, [
        r"(?:出价次数|竞价次数|报价次数|出价|竞价)\D{0,8}(\d+)\s*(?:次|人)?",
        r"(?:无人出价|暂无出价)",
    ])
    if bid_count in ("无人出价", "暂无出价"):
        bid_count = "0"

    current_price = first_match(compact, [
        r"(?:当前价|当前价格|现价|最高价|成交价)\D{0,12}([¥￥]?\s*[\d,.]+(?:\.\d+)?)",
        r"(?:价格)\D{0,12}([¥￥]?\s*[\d,.]+(?:\.\d+)?)",
    ])
    start_price = first_match(compact, [
        r"(?:起拍价|起拍价格|起始价)\D{0,12}([¥￥]?\s*[\d,.]+(?:\.\d+)?)",
    ])

    remaining = first_match(compact, [
        r"(?:距结束|剩余时间|剩余|结束倒计时)\D{0,8}((?:\d+天)?\d{1,2}[:：]\d{2}[:：]\d{2})",
        r"(?:距结束|剩余时间|剩余|结束倒计时)\D{0,8}((?:\d+天)?\d+[小时时]\d+分\d+秒)",
        r"(?:距结束|剩余时间|剩余|结束倒计时)\D{0,8}(\d+分\d+秒)",
        r"(\d{1,2}[:：]\d{2}[:：]\d{2})",
    ])
    seconds = parse_remaining_seconds(remaining)
    end_seconds, end_time = parse_datetime_seconds(compact)
    if seconds is None:
        seconds = end_seconds
    if not remaining and seconds is not None:
        remaining = str(timedelta(seconds=seconds))

    status = []
    bids_int = int(bid_count) if bid_count.isdigit() else None
    cur = safe_float(current_price)
    start = safe_float(start_price)
    if bids_int == 0 or (bids_int is None and cur is not None and start is not None and cur == start):
        status.append("疑似无人出价")
    if seconds is not None:
        status.append(f"剩余{seconds}秒")
    return LotCandidate(
        title=title,
        current_price=current_price,
        start_price=start_price,
        bid_count=bid_count,
        remaining=remaining,
        end_time=end_time,
        url=url,
        status=" / ".join(status),
        raw=text[:1000],
    )


def split_page_blocks(page_text, links):
    blocks = []
    for chunk in re.split(r"\n\s*\n|\r\n\s*\r\n", page_text):
        chunk = chunk.strip()
        if len(chunk) < 20:
            continue
        if re.search(r"(起拍价|当前价|出价|竞价|距结束|剩余|结束时间)", chunk):
            blocks.append((chunk, ""))

    if len(blocks) <= 1:
        lines = [line.strip() for line in page_text.splitlines() if line.strip()]
        window = []
        for line in lines:
            window.append(line)
            joined = "\n".join(window[-12:])
            if re.search(r"(起拍价|当前价|出价|竞价|距结束|剩余|结束时间)", joined) and len(joined) > 40:
                blocks.append((joined, ""))
                window = []

    for link in links:
        text = link.get("text") or ""
        href = link.get("href") or ""
        if "lotId=" in href or "lots" in href:
            blocks.append((text, href))

    dedup = []
    seen = set()
    for raw, href in blocks:
        key = re.sub(r"\s+", "", raw)[:180] + href
        if key not in seen:
            seen.add(key)
            dedup.append((raw, href))
    return dedup[:300]


class CaaMonitor:
    def __init__(self, app_queue):
        self.queue = app_queue
        self.playwright = None
        self.context = None
        self.page = None
        self.running = False
        self.thread = None
        self.alerted = set()

    def log(self, text):
        append_log(text)
        self.queue.put(("log", f"{now_text()} {text}"))

    def ensure_browser(self, url):
        if self.playwright is None:
            self.playwright = sync_playwright().start()
        if self.context is None:
            PROFILE_DIR.mkdir(parents=True, exist_ok=True)
            try:
                self.context = self.playwright.chromium.launch_persistent_context(
                    str(PROFILE_DIR),
                    headless=False,
                    locale="zh-CN",
                    viewport={"width": 1420, "height": 900},
                    args=["--disable-blink-features=AutomationControlled"],
                )
            except PlaywrightError as exc:
                raise RuntimeError(f"浏览器启动失败：{exc}")
            self.page = self.context.pages[0] if self.context.pages else self.context.new_page()
            self.log("浏览器已启动，请在打开的窗口正常登录/查看拍卖页。")
        if url and (not self.page.url or self.page.url == "about:blank"):
            self.page.goto(url, wait_until="domcontentloaded", timeout=30000)

    def open_url(self, url):
        self.ensure_browser(url)
        if url:
            self.page.goto(url, wait_until="domcontentloaded", timeout=30000)
            self.log("已打开目标页面。")

    def scan_once(self, url=""):
        self.ensure_browser(url)
        if url and url not in self.page.url:
            self.page.goto(url, wait_until="domcontentloaded", timeout=30000)
        try:
            self.page.wait_for_load_state("domcontentloaded", timeout=10000)
        except PlaywrightTimeoutError:
            pass
        self.page.wait_for_timeout(800)
        data = self.page.evaluate(
            """() => {
                const text = document.body ? document.body.innerText : '';
                const title = document.title || '';
                const links = Array.from(document.querySelectorAll('a[href]')).map(a => ({
                    text: (a.innerText || a.textContent || '').trim(),
                    href: a.href
                }));
                return {title, text, links, url: location.href};
            }"""
        )
        text = data.get("text", "")
        if "安全提示" in text or len(text.strip()) < 10:
            self.log("当前页面没有可读标的内容，可能停在安全提示/登录页；请在浏览器里手动进入可见的拍卖列表或标的页。")
            return []
        blocks = split_page_blocks(text, data.get("links", []))
        if not blocks:
            blocks = [(text, data.get("url", ""))]
        lots = [extract_lot_from_text(raw, href or data.get("url", "")) for raw, href in blocks]
        self.log(f"扫描完成，识别到 {len(lots)} 条候选内容。")
        return lots

    def start_loop(self, config_getter):
        if self.running:
            return
        self.running = True
        self.thread = threading.Thread(target=self._loop, args=(config_getter,), daemon=True)
        self.thread.start()

    def stop_loop(self):
        self.running = False
        self.log("监控已停止。")

    def _loop(self, config_getter):
        while self.running:
            try:
                config = config_getter()
                lots = self.scan_once(config["url"])
                self.queue.put(("lots", lots))
                self.check_alerts(lots, config)
                sleep_seconds = max(2, config["interval"])
            except Exception as exc:
                self.log(f"扫描出错：{exc}")
                sleep_seconds = 5
            for _ in range(sleep_seconds):
                if not self.running:
                    break
                time.sleep(1)

    def check_alerts(self, lots, config):
        near_seconds = config["near_seconds"]
        max_price = config["max_price"]
        only_unbid = config["only_unbid"]
        for lot in lots:
            if not is_candidate(lot, near_seconds, max_price, only_unbid):
                continue
            key = (lot.title, lot.url, lot.remaining, lot.current_price)
            if key in self.alerted:
                continue
            self.alerted.add(key)
            self.queue.put(("alert", lot))

    def close(self):
        self.running = False
        try:
            if self.context:
                self.context.close()
        finally:
            self.context = None
            if self.playwright:
                self.playwright.stop()
                self.playwright = None


def is_unbid(lot):
    if lot.bid_count == "0":
        return True
    cur = safe_float(lot.current_price)
    start = safe_float(lot.start_price)
    return cur is not None and start is not None and cur == start


def is_candidate(lot, near_seconds, max_price, only_unbid):
    if only_unbid and not is_unbid(lot):
        return False
    price = safe_float(lot.current_price or lot.start_price)
    if max_price > 0 and price is not None and price > max_price:
        return False
    seconds = parse_remaining_seconds(lot.remaining)
    if seconds is None:
        m = re.search(r"剩余(\d+)秒", lot.status)
        if m:
            seconds = int(m.group(1))
    return seconds is not None and seconds <= near_seconds


class App:
    def __init__(self, root):
        self.root = root
        self.root.title("中拍捡漏监控器 - 只提醒不出价")
        self.root.geometry("1180x720")
        self.queue = queue.Queue()
        self.monitor = CaaMonitor(self.queue)
        self.lots = []

        self.url_var = StringVar()
        self.interval_var = IntVar(value=5)
        self.near_var = IntVar(value=60)
        self.max_price_var = DoubleVar(value=0)
        self.only_unbid_var = BooleanVar(value=True)
        self.status_var = StringVar(value="就绪")

        self.load_settings()
        self.build_ui()
        self.root.after(200, self.process_queue)
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    def build_ui(self):
        frame = ttk.Frame(self.root, padding=10)
        frame.pack(fill=BOTH, expand=True)

        row = ttk.Frame(frame)
        row.pack(fill=X)
        ttk.Label(row, text="中拍页面地址").pack(side=LEFT)
        ttk.Entry(row, textvariable=self.url_var).pack(side=LEFT, fill=X, expand=True, padx=8)
        ttk.Button(row, text="打开浏览器", command=self.open_browser).pack(side=LEFT, padx=2)
        ttk.Button(row, text="扫描一次", command=self.scan_once).pack(side=LEFT, padx=2)
        ttk.Button(row, text="开始监控", command=self.start_monitor).pack(side=LEFT, padx=2)
        ttk.Button(row, text="停止", command=self.stop_monitor).pack(side=LEFT, padx=2)

        opts = ttk.Frame(frame)
        opts.pack(fill=X, pady=8)
        ttk.Label(opts, text="刷新秒").pack(side=LEFT)
        ttk.Spinbox(opts, from_=2, to=120, width=6, textvariable=self.interval_var).pack(side=LEFT, padx=6)
        ttk.Label(opts, text="临近结束秒").pack(side=LEFT)
        ttk.Spinbox(opts, from_=1, to=3600, width=8, textvariable=self.near_var).pack(side=LEFT, padx=6)
        ttk.Label(opts, text="最高预算(0=不限)").pack(side=LEFT)
        ttk.Entry(opts, width=10, textvariable=self.max_price_var).pack(side=LEFT, padx=6)
        ttk.Checkbutton(opts, text="只看无人出价/起拍价", variable=self.only_unbid_var).pack(side=LEFT, padx=10)
        ttk.Label(opts, textvariable=self.status_var, foreground="#0b7").pack(side=RIGHT)

        columns = ("status", "title", "current", "start", "bids", "remaining", "end", "url")
        self.tree = ttk.Treeview(frame, columns=columns, show="headings", height=18)
        headers = {
            "status": "状态",
            "title": "标的/候选内容",
            "current": "当前价",
            "start": "起拍价",
            "bids": "出价",
            "remaining": "剩余",
            "end": "结束时间",
            "url": "链接",
        }
        widths = {"status": 150, "title": 300, "current": 90, "start": 90, "bids": 60, "remaining": 100, "end": 140, "url": 220}
        for col in columns:
            self.tree.heading(col, text=headers[col])
            self.tree.column(col, width=widths[col], anchor="w")
        self.tree.pack(fill=BOTH, expand=True)
        self.tree.bind("<Double-1>", lambda _e: self.open_selected())

        buttons = ttk.Frame(frame)
        buttons.pack(fill=X, pady=6)
        ttk.Button(buttons, text="打开选中标的", command=self.open_selected).pack(side=LEFT)
        ttk.Button(buttons, text="复制选中详情", command=self.copy_selected).pack(side=LEFT, padx=6)

        log_frame = ttk.LabelFrame(frame, text="运行日志")
        log_frame.pack(fill=X, pady=4)
        self.log_text = ttk.Treeview(log_frame, columns=("time", "text"), show="headings", height=5)
        self.log_text.heading("time", text="时间")
        self.log_text.heading("text", text="内容")
        self.log_text.column("time", width=80)
        self.log_text.column("text", width=1000)
        self.log_text.pack(fill=X)

    def get_config(self):
        self.save_settings()
        return {
            "url": self.url_var.get().strip(),
            "interval": int(self.interval_var.get()),
            "near_seconds": int(self.near_var.get()),
            "max_price": float(self.max_price_var.get() or 0),
            "only_unbid": bool(self.only_unbid_var.get()),
        }

    def load_settings(self):
        if SETTINGS_FILE.exists():
            try:
                data = json.loads(SETTINGS_FILE.read_text(encoding="utf-8"))
                self.url_var.set(data.get("url", ""))
                self.interval_var.set(data.get("interval", 5))
                self.near_var.set(data.get("near_seconds", 60))
                self.max_price_var.set(data.get("max_price", 0))
                self.only_unbid_var.set(data.get("only_unbid", True))
            except Exception:
                pass

    def save_settings(self):
        data = self.get_settings_data()
        SETTINGS_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def get_settings_data(self):
        return {
            "url": self.url_var.get().strip(),
            "interval": int(self.interval_var.get()),
            "near_seconds": int(self.near_var.get()),
            "max_price": float(self.max_price_var.get() or 0),
            "only_unbid": bool(self.only_unbid_var.get()),
        }

    def run_bg(self, func):
        def wrapped():
            try:
                func()
            except Exception as exc:
                self.queue.put(("log", f"{now_text()} 操作失败：{exc}"))
        threading.Thread(target=wrapped, daemon=True).start()

    def open_browser(self):
        self.run_bg(lambda: self.monitor.open_url(self.url_var.get().strip()))

    def scan_once(self):
        def job():
            lots = self.monitor.scan_once(self.url_var.get().strip())
            self.queue.put(("lots", lots))
        self.run_bg(job)

    def start_monitor(self):
        self.monitor.start_loop(self.get_config)
        self.status_var.set("监控中")

    def stop_monitor(self):
        self.monitor.stop_loop()
        self.status_var.set("已停止")

    def process_queue(self):
        try:
            while True:
                kind, payload = self.queue.get_nowait()
                if kind == "log":
                    self.add_log(payload)
                elif kind == "lots":
                    self.update_lots(payload)
                elif kind == "alert":
                    self.show_alert(payload)
        except queue.Empty:
            pass
        self.root.after(200, self.process_queue)

    def add_log(self, line):
        parts = line.split(" ", 1)
        t = parts[0]
        msg = parts[1] if len(parts) > 1 else line
        self.log_text.insert("", 0, values=(t, msg))
        children = self.log_text.get_children()
        for item in children[100:]:
            self.log_text.delete(item)

    def update_lots(self, lots):
        self.lots = lots
        for item in self.tree.get_children():
            self.tree.delete(item)
        config = self.get_config()
        sorted_lots = sorted(
            lots,
            key=lambda lot: (
                not is_candidate(lot, config["near_seconds"], config["max_price"], config["only_unbid"]),
                not is_unbid(lot),
                safe_float(lot.current_price or lot.start_price) or 999999999,
            ),
        )
        for idx, lot in enumerate(sorted_lots):
            tag = "hit" if is_candidate(lot, config["near_seconds"], config["max_price"], config["only_unbid"]) else ""
            self.tree.insert(
                "",
                END,
                iid=str(idx),
                values=(lot.status, lot.title, lot.current_price, lot.start_price, lot.bid_count, lot.remaining, lot.end_time, lot.url),
                tags=(tag,),
            )
        self.tree.tag_configure("hit", background="#fff3c4")
        self.status_var.set(f"最近扫描 {len(lots)} 条，{now_text()}")

    def selected_lot(self):
        sel = self.tree.selection()
        if not sel:
            return None
        idx = int(sel[0])
        visible_values = self.tree.item(sel[0], "values")
        for lot in self.lots:
            if lot.title == visible_values[1] and lot.url == visible_values[7]:
                return lot
        return None

    def open_selected(self):
        lot = self.selected_lot()
        if not lot or not lot.url:
            messagebox.showinfo("提示", "当前选中项没有可打开链接。")
            return
        webbrowser.open(lot.url)

    def copy_selected(self):
        lot = self.selected_lot()
        if not lot:
            return
        text = json.dumps(asdict(lot), ensure_ascii=False, indent=2)
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        self.add_log(f"{now_text()} 已复制选中详情。")

    def show_alert(self, lot):
        if winsound:
            winsound.MessageBeep(winsound.MB_ICONEXCLAMATION)
        popup = Toplevel(self.root)
        popup.title("发现疑似捡漏标的")
        popup.geometry("560x260")
        ttk.Label(popup, text="发现疑似无人竞拍且临近结束的标的", font=("", 12, "bold")).pack(fill=X, padx=14, pady=10)
        text = (
            f"标的：{lot.title}\n"
            f"当前价：{lot.current_price or '-'}    起拍价：{lot.start_price or '-'}    出价：{lot.bid_count or '-'}\n"
            f"剩余：{lot.remaining or '-'}    结束：{lot.end_time or '-'}\n"
            f"链接：{lot.url or '-'}"
        )
        ttk.Label(popup, text=text, wraplength=520, justify=LEFT).pack(fill=BOTH, expand=True, padx=14)
        bar = ttk.Frame(popup)
        bar.pack(fill=X, padx=14, pady=12)
        ttk.Button(bar, text="打开页面", command=lambda: webbrowser.open(lot.url) if lot.url else None).pack(side=LEFT)
        ttk.Button(bar, text="关闭", command=popup.destroy).pack(side=RIGHT)

    def on_close(self):
        self.save_settings()
        try:
            self.monitor.close()
        except Exception:
            pass
        self.root.destroy()


def main():
    APP_DIR.mkdir(parents=True, exist_ok=True)
    root = Tk()
    try:
        root.tk.call("source", "azure.tcl")
        root.tk.call("set_theme", "light")
    except Exception:
        pass
    App(root)
    root.mainloop()


if __name__ == "__main__":
    main()
