"""
Step 1 — Authenticate ONCE in a real (headed) browser and save the session.

Run this on YOUR machine (it opens a visible Chromium window):

    python bluebooks_auth.py --config config.json

A browser opens on the BlueBooksOnline home page. Log in normally. When you
can see your subscribed content, come back to the terminal and press Enter.
The authenticated storage state (cookies + localStorage) is written to
`auth_state_path` so the crawler can reuse it headlessly.

Because the site expires sessions after ~15 min of inactivity, re-run this
whenever the crawler reports an auth-expired state.
"""
import argparse
import json
import sys
from playwright.sync_api import sync_playwright
from project_paths import DEFAULT_CONFIG, load_config


def main() -> int:
    ap = argparse.ArgumentParser(description="Save an authenticated BlueBooksOnline session.")
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    ap.add_argument("--wait-seconds", type=int,
                    help="Allow this many seconds for login instead of waiting for terminal input")
    args = ap.parse_args()
    if args.wait_seconds is not None and args.wait_seconds <= 0:
        ap.error("--wait-seconds must be positive")
    cfg = load_config(args.config)

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        ctx = browser.new_context()
        page = ctx.new_page()
        page.set_default_navigation_timeout(cfg.get("nav_timeout_ms", 30000))
        page.goto(cfg["base_url"] + "/home")

        print("\n" + "=" * 68)
        print(">>> Log in manually in the browser window that just opened.")
        if args.wait_seconds is not None:
            print(f">>> Complete login within {args.wait_seconds} seconds.")
            print(">>> The session will then be saved automatically; no Enter key is needed.")
        else:
            print(">>> Once you can see your subscribed content, return here.")
            print(">>> Press Enter to capture the authenticated session.")
        print("=" * 68 + "\n")
        if args.wait_seconds is not None:
            page.wait_for_timeout(args.wait_seconds * 1000)
        else:
            try:
                input()
            except EOFError:
                page.wait_for_timeout(cfg.get("login_wait_seconds", 120) * 1000)

        ctx.storage_state(path=cfg["auth_state_path"])
        print(f"[ok] Saved authenticated state -> {cfg['auth_state_path']}")
        browser.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
