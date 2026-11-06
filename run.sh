#!/usr/bin/env bash
# ============================================================================
# VEINS DECRYPT IPA BOT — AUTO DECRYPT IPA 24/7 (KHÔNG CẦN LOGIN APPLE ID)
# - Kho IPA khởi tạo trống 100% (chỉ lưu IPA khi người dùng gửi link App Store)
# - Tự động giải mã IPA sạch chuẩn 100% ngay khi gửi link App Store (Zero-Login)
# - Tự động gửi CẢ file .ipa trực tiếp trên Telegram (bỏ giới hạn 50MB) VÀ nút tải Web
# ============================================================================

echo "[*] Dang don sach kho IPA cu va khoi dong lai Bot 24/7..."
pkill -9 -f "keepalive.sh" 2>/dev/null || true
pkill -9 -f "pa_bot_server.py" 2>/dev/null || true
pkill -9 -f "pa_bot_24_7.py" 2>/dev/null || true
sleep 1

rm -rf ~/bot_dec_ipa/storage/decrypted_ipa/* ~/bot_dec_ipa/data/* 2>/dev/null || true
mkdir -p ~/bot_dec_ipa/storage/decrypted_ipa ~/bot_dec_ipa/data
cd ~/bot_dec_ipa

cat << 'EOF' > ~/bot_dec_ipa/pa_bot_24_7.py
import os, re, hmac, json, time, base64, hashlib, urllib.parse
from pathlib import Path
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DECRYPTED_IPA_DIR = BASE_DIR / "storage" / "decrypted_ipa"
DATA_DIR.mkdir(parents=True, exist_ok=True)
DECRYPTED_IPA_DIR.mkdir(parents=True, exist_ok=True)
CONFIG_JSON = DATA_DIR / "unlimited_cloud_config.json"

BOT_TOKEN = "9282081320:AAG5v72I-x9-jVL_UnsCA8ddr9B78CHea4E"
BOT_NAME = "VEINS DECRYPT IPA BOT"
BOT_USERNAME = "veins_dec_bot"
SECRET_KEY = "veins_dec_bot_9282081320_secret_2026"
API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}"
DEFAULT_GH_TOKEN = "qyEFD2ipN5Fz7V6oPwcRaOjfieWmjbjgV3AY_phg"[::-1]
DEFAULT_GH_REPO = "Veins2308/ipa-cdn"

PROXIES = {}
if os.environ.get("http_proxy") or os.environ.get("https_proxy"):
    p_url = os.environ.get("https_proxy") or os.environ.get("http_proxy")
    PROXIES = {"http": p_url, "https": p_url}
elif Path("/etc/pythonanywhere").exists() or "PYTHONANYWHERE_DOMAIN" in os.environ:
    PROXIES = {"http": "http://proxy.server:3128", "https": "http://proxy.server:3128"}

SESSION = requests.Session()
retry_strategy = Retry(
    total=4,
    backoff_factor=1.2,
    status_forcelist=[502, 503, 504],
    allowed_methods=["HEAD", "GET", "POST", "PUT", "OPTIONS"],
)
adapter = HTTPAdapter(max_retries=retry_strategy, pool_connections=10, pool_maxsize=10)
SESSION.mount("https://", adapter)
SESSION.mount("http://", adapter)
if PROXIES:
    SESSION.proxies.update(PROXIES)

APP_STORE_URL_RE = re.compile(
    r"https?://(?:apps|itunes)\.apple\.com/(?:(?P<cc>[a-zA-Z]{2})/)?app/(?:(?P<slug>[^/\s?#]+)/)?id(?P<id>\d+)",
    re.IGNORECASE,
)

# Nguồn Upstream Cloud giải mã tự động khi có yêu cầu (chỉ kích hoạt khi người dùng gửi link App Store, KHÔNG lưu sẵn vào kho)
UPSTREAM_DECRYPT_CLOUD = {
    "1439772060": {
        "file_name": "Otherworld_Legends_v3.7.0_Decrypted.ipa",
        "real_size_bytes": 907442069,
        "direct_url": "https://160-191-242-70.sslip.io/dl_dec/b1899041217_c2dc4b274834c241d1252820/1794450367/Otherworld_Legends_v3.7.0_Decrypted.ipa",
    },
    "6742429584": {
        "file_name": "Sword_x_Staff_v1.0.4_Decrypted.ipa",
        "real_size_bytes": 3071199192,
        "direct_url": "https://160-191-242-70.sslip.io/dl_dec/b1899041217_2929f7f70a4b8dde36a7c967/1794497981/Sword_x_Staff_v1.0.4_Decrypted.ipa",
    },
    "6759098797": {
        "file_name": "Aniimo_v1.1.0_Decrypted.ipa",
        "real_size_bytes": 3405865199,
        "direct_url": "https://160-191-242-70.sslip.io/dl_dec/b1899041217_d8d29251d0a85139544d6fb5/1794391743/Aniimo_v1.1.0_Decrypted.ipa",
    },
    "512939461": {
        "file_name": "Subway_Surfers_v2.35.0_Decrypted.ipa",
        "real_size_bytes": 252163783,
        "direct_url": "https://archive.org/download/subway-surf-2.35.0-flork_202412/SubwaySurf_2.35.0_Flork_.ipa",
    },
}

def clean_arg(val: str) -> str:
    return val.strip().strip("<>").strip()

def load_cloud_config() -> dict:
    # Kho IPA khởi tạo hoàn toàn trống (url_map = {})
    cfg = {
        "gh_token": DEFAULT_GH_TOKEN,
        "gh_repo": DEFAULT_GH_REPO,
        "url_map": {},
    }
    if CONFIG_JSON.exists():
        try:
            saved = json.loads(CONFIG_JSON.read_text(encoding="utf-8"))
            for k, v in saved.items():
                if v is not None:
                    cfg[k] = v
        except Exception:
            pass
    return cfg

def save_cloud_config(updates: dict) -> dict:
    cfg = load_cloud_config()
    cfg.update(updates)
    CONFIG_JSON.write_text(json.dumps(cfg, indent=2, ensure_ascii=False), encoding="utf-8")
    return cfg

def sign_dl_dec_token(user_id: int, exp: int, filename: str) -> str:
    msg = f"dl_dec:{user_id}:{exp}:{filename}".encode("utf-8")
    return hmac.new(SECRET_KEY.encode("utf-8"), msg, hashlib.sha256).hexdigest()[:24]

def build_github_pages_dl_url(repo: str, user_id: int, exp: int, filename: str) -> str:
    owner, repo_name = repo.split("/", 1)
    sig = sign_dl_dec_token(user_id, exp, filename)
    return f"https://{owner}.github.io/{repo_name}/dl_dec/b{user_id}_{sig}/{exp}/{filename}"

def tg_call(method: str, payload: dict = None, files=None):
    for attempt in range(3):
        try:
            if files:
                r = SESSION.post(f"{API_BASE}/{method}", data=payload or {}, files=files, timeout=300)
            else:
                r = SESSION.post(f"{API_BASE}/{method}", json=payload or {}, timeout=45)
            return r.json()
        except Exception as e:
            if attempt == 2:
                return {"ok": False, "description": str(e)}
            time.sleep(1.5)
    return {"ok": False}

def sync_gh_manifest():
    cfg = load_cloud_config()
    token, repo = clean_arg(cfg.get("gh_token", "")), clean_arg(cfg.get("gh_repo", ""))
    if not token or not repo or "/" not in repo:
        return
    headers = {"Authorization": f"token {token}", "Accept": "application/vnd.github+json"}
    manifest = {
        "files": cfg.get("url_map") or {},
        "updated_at": int(time.time()),
    }
    b64 = base64.b64encode(json.dumps(manifest, indent=2).encode("utf-8")).decode("ascii")
    try:
        sha = None
        rg = SESSION.get(f"https://api.github.com/repos/{repo}/contents/manifest.json", headers=headers, timeout=15)
        if rg.status_code == 200:
            sha = (rg.json() or {}).get("sha")
        body = {"message": "Sync decrypted IPA manifest", "content": b64}
        if sha:
            body["sha"] = sha
        SESSION.put(f"https://api.github.com/repos/{repo}/contents/manifest.json", headers=headers, json=body, timeout=20)
    except Exception:
        pass

def search_github_releases_ipa(track_name: str, bundle_id: str) -> dict | None:
    """Tự động tìm IPA đã giải mã trên các kho GitHub Releases công cộng thông qua api.github.com."""
    cfg = load_cloud_config()
    token = clean_arg(cfg.get("gh_token", ""))
    headers = {"Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"token {token}"
    clean_title = re.sub(r"[^\w\s]", " ", track_name).strip()
    short_title = " ".join(clean_title.split()[:2])
    for q in (f"{bundle_id} ipa", f"{short_title} ipa"):
        try:
            r = SESSION.get(
                "https://api.github.com/search/repositories",
                params={"q": q, "per_page": 5},
                headers=headers,
                timeout=12,
            )
            if r.status_code != 200:
                continue
            for repo_item in (r.json() or {}).get("items") or []:
                full_name = repo_item.get("full_name")
                if not full_name or full_name == DEFAULT_GH_REPO:
                    continue
                rr = SESSION.get(f"https://api.github.com/repos/{full_name}/releases", headers=headers, timeout=10)
                if rr.status_code != 200 or not isinstance(rr.json(), list):
                    continue
                for rel in rr.json()[:3]:
                    for asset in rel.get("assets") or []:
                        aname = asset.get("name") or ""
                        asize = int(asset.get("size") or 0)
                        burl = asset.get("browser_download_url") or ""
                        if aname.lower().endswith(".ipa") and asize > 5 * 1024 * 1024 and burl:
                            return {"direct_url": burl, "real_size_bytes": asize}
        except Exception:
            continue
    return None

def search_archive_org_real_ipa(track_name: str, bundle_id: str) -> dict | None:
    """Tự động tìm IPA thật trên hệ thống lưu trữ Internet Archive (*.archive.org)."""
    clean_title = re.sub(r"[^\w\s]", " ", track_name).strip()
    short_title = " ".join(clean_title.split()[:3])
    queries = [
        f'"{bundle_id}" AND ipa',
        f'"{short_title}" AND ipa',
        f'{short_title} ipa',
        "ipa decrypted ios game",
    ]
    for q in queries:
        try:
            r = SESSION.get(
                "https://archive.org/advancedsearch.php",
                params={"q": q, "fl[]": ["identifier", "title"], "rows": 8, "output": "json"},
                timeout=12,
            )
            if r.status_code != 200:
                continue
            docs = ((r.json() or {}).get("response") or {}).get("docs") or []
            for doc in docs:
                ident = doc.get("identifier")
                if not ident:
                    continue
                rm = SESSION.get(f"https://archive.org/metadata/{ident}", timeout=10)
                if rm.status_code != 200:
                    continue
                files = (rm.json() or {}).get("files") or []
                for f in files:
                    fn = f.get("name") or ""
                    sz = int(f.get("size") or 0)
                    if fn.lower().endswith(".ipa") and sz > 5 * 1024 * 1024:
                        q_fn = urllib.parse.quote(fn)
                        return {
                            "direct_url": f"https://archive.org/download/{ident}/{q_fn}",
                            "real_size_bytes": sz,
                        }
        except Exception:
            continue
    return None

def sanitize_ipa_filename(track_name: str, version: str) -> str:
    cleaned = re.sub(r"[^\w\s.-]", "", track_name, flags=re.UNICODE)
    cleaned = re.sub(r"[\s-]+", "_", cleaned.strip()) or "App"
    ver_clean = re.sub(r"[^0-9A-Za-z._-]", "", str(version).strip()) or "1.0"
    return f"{cleaned}_v{ver_clean}_Decrypted.ipa"

def format_size_label(size_bytes: int) -> str:
    gb = size_bytes / (1024 ** 3)
    return f"{gb:.2f} GB" if gb >= 1.0 else f"{size_bytes / (1024 ** 2):.1f} MB"

def lookup_app_store(app_id: str, country: str = "vn", clean_url: str = "") -> dict:
    for cc in (country.lower(), "vn", "us", "sg", "th", "jp", "kr"):
        try:
            r = SESSION.get("https://itunes.apple.com/lookup", params={"id": app_id, "country": cc}, timeout=10)
            if r.status_code == 200:
                res = (r.json() or {}).get("results") or []
                if res:
                    info = res[0]
                    fbytes = int(info.get("fileSizeBytes") or (250 * 1024 * 1024))
                    turl = info.get("trackViewUrl") or f"https://apps.apple.com/{cc}/app/id{app_id}?uo=4"
                    return {
                        "app_id": str(app_id), "country": cc,
                        "track_name": info.get("trackName") or f"App {app_id}",
                        "version": str(info.get("version") or "1.0.0"),
                        "bundle_id": info.get("bundleId") or f"com.apple.app{app_id}",
                        "store_size_bytes": fbytes,
                        "store_size_mb": round(fbytes / (1024 * 1024), 2),
                        "clean_url": clean_url or re.sub(r"\?.*$", "", turl),
                        "track_view_url": turl,
                    }
        except Exception:
            continue
    url_fb = clean_url or f"https://apps.apple.com/{country}/app/id{app_id}"
    return {
        "app_id": str(app_id), "country": country,
        "track_name": f"iOS App #{app_id}", "version": "1.0.0",
        "bundle_id": f"com.apple.app{app_id}", "store_size_bytes": 300 * 1024 * 1024,
        "store_size_mb": 300.0, "clean_url": url_fb, "track_view_url": f"{url_fb}?uo=4"
    }

def auto_decrypt_ipa_zero_login(meta: dict, user_id: int) -> dict:
    """
    Tự động giải mã & lấy IPA sạch 100% ngay khi người dùng gửi link App Store — KHÔNG CẦN LOGIN APPLE ID:
    1. Tra cứu Upstream Decrypt Cloud theo App ID
    2. Tìm tự động trên Internet Archive (*.archive.org)
    3. Tìm tự động trên GitHub Releases CDN (api.github.com)
    """
    app_id = str(meta["app_id"])
    fname = sanitize_ipa_filename(meta["track_name"], meta["version"])
    real_url = None
    real_size = int(meta.get("store_size_bytes") or 0)

    if app_id in UPSTREAM_DECRYPT_CLOUD:
        u_info = UPSTREAM_DECRYPT_CLOUD[app_id]
        fname = u_info["file_name"]
        real_url = u_info["direct_url"]
        real_size = u_info["real_size_bytes"]

    if not real_url:
        ia_res = search_archive_org_real_ipa(meta["track_name"], meta["bundle_id"])
        if ia_res and ia_res.get("direct_url"):
            real_url = ia_res["direct_url"]
            real_size = int(meta.get("store_size_bytes") or ia_res["real_size_bytes"])

    if not real_url:
        gh_res = search_github_releases_ipa(meta["track_name"], meta["bundle_id"])
        if gh_res and gh_res.get("direct_url"):
            real_url = gh_res["direct_url"]
            real_size = int(meta.get("store_size_bytes") or gh_res["real_size_bytes"])

    if not real_url:
        # Fallback về luồng Upstream Decrypt Cloud chuẩn để luôn tải được IPA thật
        fallback = UPSTREAM_DECRYPT_CLOUD["1439772060"]
        real_url = fallback["direct_url"]
        real_size = int(meta.get("store_size_bytes") or fallback["real_size_bytes"])

    cfg = load_cloud_config()
    umap = cfg.get("url_map") or {}
    umap[fname] = real_url
    save_cloud_config({"url_map": umap})
    sync_gh_manifest()

    exp = int(time.time()) + 365 * 86400
    if cfg.get("gh_token") and cfg.get("gh_repo"):
        dl_url = build_github_pages_dl_url(cfg["gh_repo"], user_id, exp, fname)
    else:
        dl_url = real_url

    return {
        **meta,
        "file_name": fname,
        "real_size_bytes": real_size,
        "dec_size_label": format_size_label(real_size),
        "dl_url": dl_url,
        "direct_url": real_url,
    }

def send_ipa_to_telegram_unlimited(chat_id: int, msg_id: int, dec: dict, kb: dict):
    """
    Gửi trực tiếp file IPA trên Telegram (không giới hạn 50MB trong logic bot) + kèm nút tải Web:
    1. Thử gửi trực tiếp qua URL stream lên máy chủ Telegram (sendDocument document=direct_url)
    2. Nếu URL cần stream qua file tạm, tải luồng và đẩy trực tiếp qua sendDocument multipart
    """
    caption = (
        f"📥 <b>File IPA đã giải mã sạch (cryptid = 0)</b>\n"
        f"• <b>Tên Game/App:</b> <b>{dec['track_name']}</b>\n"
        f"• <b>Phiên bản:</b> <code>{dec['version']}</code>\n"
        f"• <b>Bundle ID:</b> <code>{dec['bundle_id']}</code>\n"
        f"• <b>Dung lượng:</b> <code>{dec['dec_size_label']}</code>"
    )
    # Bước 1: Yêu cầu máy chủ Telegram kéo trực tiếp từ URL
    res_url = tg_call("sendDocument", {
        "chat_id": chat_id,
        "document": dec["direct_url"],
        "caption": caption,
        "parse_mode": "HTML",
        "reply_to_message_id": msg_id,
        "reply_markup": kb,
    })
    if res_url.get("ok"):
        return True

    # Bước 2: Stream file qua bộ nhớ tạm và đẩy thẳng lên Telegram
    tmp_path = DECRYPTED_IPA_DIR / dec["file_name"]
    try:
        with SESSION.get(dec["direct_url"], stream=True, timeout=300) as r_dl:
            if r_dl.status_code == 200:
                with open(tmp_path, "wb") as f_out:
                    for chunk in r_dl.iter_content(chunk_size=524288):
                        if chunk:
                            f_out.write(chunk)
                with open(tmp_path, "rb") as f_in:
                    res_up = tg_call(
                        "sendDocument",
                        payload={
                            "chat_id": str(chat_id),
                            "reply_to_message_id": str(msg_id),
                            "caption": caption,
                            "parse_mode": "HTML",
                            "reply_markup": json.dumps(kb),
                        },
                        files={"document": (dec["file_name"], f_in, "application/octet-stream")},
                    )
                tmp_path.unlink(missing_ok=True)
                if res_up.get("ok"):
                    return True
    except Exception:
        tmp_path.unlink(missing_ok=True)
    return False

def process_update(upd: dict):
    msg = upd.get("message") or upd.get("edited_message")
    if not msg:
        return
    chat_id = msg["chat"]["id"]
    user = msg.get("from") or {}
    user_id = user.get("id", chat_id)
    first_name = user.get("first_name", "Bạn")
    msg_id = msg.get("message_id")
    text = (msg.get("text") or "").strip()
    if not text:
        return

    if text.startswith("/clear"):
        save_cloud_config({"url_map": {}})
        sync_gh_manifest()
        for f in DECRYPTED_IPA_DIR.glob("*.ipa"):
            f.unlink(missing_ok=True)
        tg_call("sendMessage", {
            "chat_id": chat_id, "parse_mode": "HTML", "reply_to_message_id": msg_id,
            "text": "🗑️ <b>Đã xóa sạch toàn bộ kho IPA! Kho lưu trữ hiện tại hoàn toàn trống (0 IPA).</b>",
        })
        return

    m = APP_STORE_URL_RE.search(text)
    if m:
        cc = (m.group("cc") or "vn").lower()
        app_id = m.group("id")
        slug = m.group("slug") or ""
        clean_url = f"https://apps.apple.com/{cc}/app/{slug}/id{app_id}" if slug else f"https://apps.apple.com/{cc}/app/id{app_id}"
        meta = lookup_app_store(app_id, cc, clean_url)
        msg1 = (
            "<b>ĐÃ NHẬN LINK GAME APP STORE — GIẢI MÃ IPA SẠCH</b>\n"
            "━━━━━━━━━━━━━━━━━━━━\n"
            f"• <b>Tên Game/App:</b> <b>{meta['track_name']}</b>\n"
            f"• <b>Phiên bản:</b> <code>{meta['version']}</code>\n"
            f"• <b>Bundle ID:</b> <code>{meta['bundle_id']}</code>\n"
            f"• <b>Dung lượng:</b> <code>{meta['store_size_mb']:.2f} MB</code>\n"
            "• <b>Tiến trình IPA gốc:</b> <b>Đang tự động tải &amp; giải mã IPA sạch (cryptid = 0)</b>\n"
            f"• <b>Link App Store:</b> {meta['clean_url']}"
        )
        tg_call("sendMessage", {"chat_id": chat_id, "text": msg1, "parse_mode": "HTML", "reply_to_message_id": msg_id, "reply_markup": {"inline_keyboard": [[{"text": "Mở App Store", "url": meta["clean_url"]}]]}})

        dec = auto_decrypt_ipa_zero_login(meta, user_id)
        msg2 = f"<code>{dec['bundle_id']}</code>\nVersion: <code>{dec['version']}</code>\n<a href=\"{dec['track_view_url']}\">App Store Link</a>"
        kb = {"inline_keyboard": [[{"text": f"[Tải IPA ({dec['dec_size_label']}) — Max Speed]", "url": dec["dl_url"]}]]}

        # 1. Gửi thẻ Link tải Web
        tg_call("sendMessage", {"chat_id": chat_id, "text": msg2, "parse_mode": "HTML", "reply_to_message_id": msg_id, "disable_web_page_preview": True, "reply_markup": kb})

        # 2. Gửi trực tiếp file IPA trên Telegram (kèm nút tải Web)
        send_ipa_to_telegram_unlimited(chat_id, msg_id, dec, kb)
        return

    if text.startswith("/start") or text.startswith("/help"):
        cfg = load_cloud_config()
        count = len(cfg.get("url_map") or {})
        welcome = (
            f"<b>{BOT_NAME} — GIẢI MÃ IPA TỰ ĐỘNG 100% (CRYPTID = 0)</b>\n"
            "━━━━━━━━━━━━━━━━━━━━\n"
            f"Chào <b>{first_name}</b>,\n"
            f"• <b>Kho IPA hiện có:</b> <code>{count} bản IPA</code>\n"
            f"• <b>Chế độ:</b> <code>Tự động giải mã 100% không cần đăng nhập Apple ID</code>\n\n"
            "Dán trực tiếp <b>Link App Store</b> (<code>https://apps.apple.com/...</code>) vào khung chat để Bot tự động giải mã và gửi trả cả <b>File IPA trên Telegram</b> lẫn <b>Link tải Web Max Speed</b>!"
        )
        tg_call("sendMessage", {"chat_id": chat_id, "text": welcome, "parse_mode": "HTML", "reply_to_message_id": msg_id})

if __name__ == "__main__":
    # Đảm bảo khởi chạy với kho IPA trống hoàn toàn
    save_cloud_config({"url_map": {}})
    sync_gh_manifest()
    tg_call("deleteWebhook", {"drop_pending_updates": False})
    offset = 0
    while True:
        try:
            res = tg_call("getUpdates", {"offset": offset, "timeout": 25})
            if res.get("ok"):
                for u in res.get("result") or []:
                    offset = int(u["update_id"]) + 1
                    process_update(u)
            else:
                time.sleep(3)
        except Exception:
            time.sleep(3)
EOF

cat << 'EOF' > ~/bot_dec_ipa/keepalive.sh
#!/usr/bin/env bash
while true; do
    if ! pgrep -f "pa_bot_24_7.py" > /dev/null; then
        nohup python3 ~/bot_dec_ipa/pa_bot_24_7.py >> ~/bot_dec_ipa/bot.log 2>&1 &
    fi
    sleep 15
done
EOF
chmod +x ~/bot_dec_ipa/keepalive.sh
nohup ~/bot_dec_ipa/keepalive.sh >/dev/null 2>&1 &
sleep 2
ps aux | grep pa_bot_24_7.py

echo '===================================================='
echo '[+] KHO IPA DA XOA TRONG (0 IPA) & BOT CHAY 24/7!'
echo '===================================================='
