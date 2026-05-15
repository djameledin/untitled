import subprocess
import sys

def install(package):
    subprocess.check_call([sys.executable, "-m", "pip", "install", package], stdout=subprocess.DEVNULL)

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    install("playwright")
    subprocess.check_call([sys.executable, "-m", "playwright", "install", "chromium"], stdout=subprocess.DEVNULL)
    from playwright.sync_api import sync_playwright

import json
import urllib.request

DROPBOX_URL = "https://www.dropbox.com/s/xxxxxxxxxxxx/session.json?dl=1"
TARGET_URL  = "https://www.dropbox.com"
EDGE_PATH   = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"

with urllib.request.urlopen(DROPBOX_URL) as response:
    session_data = json.loads(response.read().decode())

with sync_playwright() as p:
    browser = p.chromium.launch(
        executable_path=EDGE_PATH,
        headless=False,
        channel="msedge",
    )

    context = browser.new_context()
    page = context.new_page()
    page.goto(TARGET_URL)

    cookies = session_data.get("cookies", [])

    for c in cookies:
        if not c.get("httpOnly"):
            js = f"document.cookie = '{c['name']}={c['value']}; path={c.get('path', '/')}; domain={c.get('domain', '')}';"
            page.evaluate(js)

    context.add_cookies(cookies)

    for origin in session_data.get("origins", []):
        for item in origin.get("localStorage", []):
            page.evaluate(f"localStorage.setItem('{item['name']}', '{item['value']}')")

    page.reload()

    input("Press Enter to close...")
    browser.close()
