# main.py
# Eagle Eye - assets/eagle_eye_data.json generator
# - 5 jobs only: taxi, delivery, restaurant, retail, hotel
# - Writes assets/eagle_eye_data.json
# - Robust: still generates output even if Gemini/Open-Meteo/JMA fails

import os
import json
import time
import re
import urllib.request
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

# =========================
# Settings
# =========================
API_KEY = os.environ.get("GEMINI_API_KEY")  # optional
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

JST = timezone(timedelta(hours=9), "JST")

RUN_DAYS = int(os.environ.get("RUN_DAYS", "90"))  # total days to output
AI_DAYS = int(os.environ.get("AI_DAYS", "7"))     # first N days try AI output

MAX_WORKERS = int(os.environ.get("MAX_WORKERS", "4"))  # keep modest for CI

OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "assets", "eagle_eye_data.json")

# Jobs fixed to 5 (MVP)
JOB_KEYS = ["taxi", "delivery", "restaurant", "retail", "hotel"]

# --- 2026 Holidays (Japan) ---
HOLIDAYS_2026 = {
    "2026-01-01", "2026-01-12", "2026-02-11", "2026-02-23", "2026-03-20",
    "2026-04-29", "2026-05-03", "2026-05-04", "2026-05-05", "2026-05-06",
    "2026-07-20", "2026-08-11", "2026-09-21", "2026-09-22", "2026-09-23",
    "2026-10-12", "2026-11-03", "2026-11-23", "2026-11-24"
}

# --- Areas (30) ---
TARGET_AREAS = {
    "hakodate": { "name": "北海道 函館", "jma_code": "014100", "amedas_code": "23411", "lat": 41.7687, "lon": 140.7288, "feature": "観光・夜景・海鮮。冬は雪の影響大。クルーズ船寄港地。" },
    "sapporo": { "name": "北海道 札幌", "jma_code": "016000", "amedas_code": "14163", "lat": 43.0618, "lon": 141.3545, "feature": "北日本最大の歓楽街ススキノ。雪まつり等のイベント。" },
    "sendai": { "name": "宮城 仙台", "jma_code": "040000", "amedas_code": "34392", "lat": 38.2682, "lon": 140.8694, "feature": "東北のビジネス拠点。国分町の夜間需要。" },
    "tokyo_marunouchi": { "name": "東京 丸の内・東京駅", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6812, "lon": 139.7671, "feature": "日本のビジネス中心地。出張・接待・富裕層需要。" },
    "tokyo_ginza": { "name": "東京 銀座・新橋", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6701, "lon": 139.7630, "feature": "夜の接待需要とサラリーマンの聖地。高級店多し。" },
    "tokyo_shinjuku": { "name": "東京 新宿・歌舞伎町", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6914, "lon": 139.7020, "feature": "世界一の乗降客数と眠らない街。タクシー需要最強。" },
    "tokyo_shibuya": { "name": "東京 渋谷・原宿", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6580, "lon": 139.7016, "feature": "若者とインバウンド、IT企業の街。トレンド発信地。" },
    "tokyo_roppongi": { "name": "東京 六本木・赤坂", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6641, "lon": 139.7336, "feature": "富裕層、外国人、メディア関係者の夜の移動。" },
    "tokyo_ikebukuro": { "name": "東京 池袋", "jma_code": "130000", "amedas_code": "44132", "lat": 35.7295, "lon": 139.7109, "feature": "埼玉方面への玄関口、サブカルチャー。" },
    "tokyo_shinagawa": { "name": "東京 品川・高輪", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6285, "lon": 139.7397, "feature": "リニア・新幹線拠点。ホテルとビジネス需要。" },
    "tokyo_ueno": { "name": "東京 上野", "jma_code": "130000", "amedas_code": "44132", "lat": 35.7141, "lon": 139.7741, "feature": "北の玄関口、美術館、アメ横。観光客多し。" },
    "tokyo_asakusa": { "name": "東京 浅草", "jma_code": "130000", "amedas_code": "44132", "lat": 35.7119, "lon": 139.7983, "feature": "インバウンド観光の絶対王者。人力車や食べ歩き。" },
    "tokyo_akihabara": { "name": "東京 秋葉原・神田", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6983, "lon": 139.7731, "feature": "オタク文化とビジネスの融合。電気街。" },
    "tokyo_omotesando": { "name": "東京 表参道・青山", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6652, "lon": 139.7123, "feature": "ファッション、富裕層のランチ・買い物需要。" },
    "tokyo_ebisu": { "name": "東京 恵比寿・代官山", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6467, "lon": 139.7101, "feature": "オシャレな飲食需要、タクシー利用率高め。" },
    "tokyo_odaiba": { "name": "東京 お台場・有明", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6278, "lon": 139.7745, "feature": "ビッグサイトのイベント、観光、デートスポット。" },
    "tokyo_toyosu": { "name": "東京 豊洲・湾岸", "jma_code": "130000", "amedas_code": "44132", "lat": 35.6568, "lon": 139.7960, "feature": "タワマン住民の生活需要と市場関係。" },
    "tokyo_haneda": { "name": "東京 羽田空港エリア", "jma_code": "130000", "amedas_code": "44166", "lat": 35.5494, "lon": 139.7798, "feature": "旅行・出張客の送迎需要。天候による遅延影響。" },
    "chiba_maihama": { "name": "千葉 舞浜(ディズニー)", "jma_code": "120000", "amedas_code": "45156", "lat": 35.6329, "lon": 139.8804, "feature": "ディズニーリゾート。イベントと天候への依存度極大。" },
    "kanagawa_yokohama": { "name": "神奈川 横浜", "jma_code": "140000", "amedas_code": "46106", "lat": 35.4437, "lon": 139.6380, "feature": "みなとみらい観光とビジネスが融合。中華街。" },
    "aichi_nagoya": { "name": "愛知 名古屋", "jma_code": "230000", "amedas_code": "51106", "lat": 35.1815, "lon": 136.9066, "feature": "トヨタ系ビジネスと独自の飲食文化。車社会。" },
    "osaka_kita": { "name": "大阪 キタ (梅田)", "jma_code": "270000", "amedas_code": "62078", "lat": 34.7025, "lon": 135.4959, "feature": "西日本最大のビジネス街兼繁華街。地下街発達。" },
    "osaka_minami": { "name": "大阪 ミナミ (難波)", "jma_code": "270000", "amedas_code": "62078", "lat": 34.6655, "lon": 135.5011, "feature": "インバウンド人気No.1。食い倒れの街。" },
    "osaka_hokusetsu": { "name": "大阪 北摂", "jma_code": "270000", "amedas_code": "62078", "lat": 34.7809, "lon": 135.4624, "feature": "伊丹空港/新幹線・ビジネス・高級住宅街。" },
    "osaka_bay": { "name": "大阪 ベイエリア(USJ)", "jma_code": "270000", "amedas_code": "62078", "lat": 34.6654, "lon": 135.4323, "feature": "USJや海遊館。海風強くイベント依存度高い。" },
    "osaka_tennoji": { "name": "大阪 天王寺・阿倍野", "jma_code": "270000", "amedas_code": "62078", "lat": 34.6477, "lon": 135.5135, "feature": "ハルカス/通天閣。新旧文化の融合。" },
    "kyoto_shijo": { "name": "京都 四条河原町", "jma_code": "260000", "amedas_code": "61286", "lat": 35.0037, "lon": 135.7706, "feature": "世界最強の観光都市。インバウンド需要が桁違い。" },
    "hyogo_kobe": { "name": "兵庫 神戸(三宮)", "jma_code": "280000", "amedas_code": "63518", "lat": 34.6946, "lon": 135.1956, "feature": "オシャレな港町。観光とビジネス。" },
    "hiroshima": { "name": "広島", "jma_code": "340000", "amedas_code": "67437", "lat": 34.3853, "lon": 132.4553, "feature": "平和公園・宮島。欧米系インバウンド多い。" },
    "fukuoka": { "name": "福岡 博多・中洲", "jma_code": "400000", "amedas_code": "82182", "lat": 33.5902, "lon": 130.4017, "feature": "アジアの玄関口。屋台文化など夜の需要が強い。" },
    "okinawa_naha": { "name": "沖縄 那覇", "jma_code": "471000", "amedas_code": "91197", "lat": 26.2124, "lon": 127.6809, "feature": "国際通り。観光客メイン。台風等の天候影響大。" },
}

# =========================
# Utilities
# =========================
def _weekday_ja(dt: datetime) -> str:
    return ["月", "火", "水", "木", "金", "土", "日"][dt.weekday()]

def _date_label(dt: datetime) -> str:
    return dt.strftime("%m月%d日") + f" ({_weekday_ja(dt)})"

def round10_percent(v):
    try:
        x = float(v)
        x = int(round(x))
        x = max(0, min(100, x))
        x = int(round(x / 10.0) * 10)
        return f"{x}%"
    except Exception:
        return "-"

def extract_json_block(text: str) -> str:
    # try extract first {...} block
    m = re.search(r"\{.*\}", text, re.DOTALL)
    return m.group(0) if m else text

def get_weather_emoji_jma(code):
    try:
        c = int(code)
        if c in [100, 101, 123, 124, 0]:
            return "☀️"
        if c in [102, 103, 104, 105, 106, 107, 108, 110, 111, 112, 1, 2, 3]:
            return "🌤️"
        if c in [200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 45, 48]:
            return "☁️"
        if 300 <= c < 350:
            return "☔"
        if c in [51, 53, 55, 61, 63, 65, 80, 81, 82]:
            return "☔"
        if 350 <= c < 500:
            return "☃️"
        if c in [71, 73, 75, 77, 85, 86]:
            return "☃️"
        if c >= 95:
            return "⛈️"
    except Exception:
        pass
    return "☁️"

def get_weather_emoji_openmeteo(code):
    try:
        c = int(code)
        if c == 0:
            return "☀️"
        if c in [1, 2, 3]:
            return "🌤️" if c in [1, 2] else "☁️"
        if c in [45, 48]:
            return "☁️"
        if c in [51, 53, 55, 56, 57]:
            return "☔"
        if c in [61, 63, 65, 66, 67]:
            return "☔"
        if c in [71, 73, 75, 77, 85, 86]:
            return "☃️"
        if c in [80, 81, 82]:
            return "☔"
        if c in [95, 96, 99]:
            return "⛈️"
    except Exception:
        pass
    return "☁️"

# =========================
# 2.1-2.3 patch: normalize high/low from timeline
# =========================
def normalize_high_low_from_timeline(day_obj: dict) -> None:
    tl = day_obj.get("timeline")
    if not tl:
        return
    highs = []
    lows = []
    for key in ("morning", "daytime", "night"):
        s = tl.get(key) or {}
        # "6℃" "最高6℃" どっちでも拾えるように数字だけ取る
        import re
        def p(x):
          if not x: return None
          m = re.search(r"-?\d+", str(x))
          return int(m.group(0)) if m else None

        h = p(s.get("temp_high")) or p(s.get("temp"))
        l = p(s.get("temp_low")) or p(s.get("temp"))
        if h is not None: highs.append(h)
        if l is not None: lows.append(l)

    if highs and lows:
        day_obj.setdefault("weather_overview", {})
        day_obj["weather_overview"]["high"] = f"最高{max(highs)}℃"
        day_obj["weather_overview"]["low"]  = f"最低{min(lows)}℃"

# =========================
# JMA / AMeDAS
# =========================
def get_amedas_daily_stats(amedas_code: str):
    """today 0:00 ~ now from 1h data: {max, min}"""
    if not amedas_code:
        return None
    today_str = datetime.now(JST).strftime("%Y%m%d")
    url = f"https://www.jma.go.jp/bosai/amedas/data/point/{amedas_code}/{today_str}_1h.json"
    try:
        with urllib.request.urlopen(url, timeout=10) as res:
            data = json.loads(res.read().decode("utf-8"))
        temps = []
        for _, vals in data.items():
            if isinstance(vals, dict) and "temp" in vals:
                t = vals["temp"][0] if isinstance(vals["temp"], list) and vals["temp"] else None
                if t is not None:
                    temps.append(float(t))
        if temps:
            return {"max": max(temps), "min": min(temps)}
    except Exception:
        return None
    return None

def get_jma_forecast_data(area_code: str):
    """
    returns (daily_db, warning_text)
    daily_db[YYYY-MM-DD] = {"code":..., "rain_raw":[...], "temp_raw":[...], "temp_summary":{"min":..,"max":..}}
    """
    forecast_url = f"https://www.jma.go.jp/bosai/forecast/data/forecast/{area_code}.json"
    warning_url = f"https://www.jma.go.jp/bosai/warning/data/warning/{area_code}.json"

    daily_db = {}
    warning_text = "特になし"

    # forecast
    try:
        with urllib.request.urlopen(forecast_url, timeout=15) as res:
            data = json.loads(res.read().decode("utf-8"))

        # short term details in data[0]
        ts_weather = data[0]["timeSeries"][0]
        codes = ts_weather["areas"][0]["weatherCodes"]
        dates_w = ts_weather["timeDefines"]
        for i, d in enumerate(dates_w):
            date_key = d.split("T")[0]
            daily_db.setdefault(date_key, {})
            daily_db[date_key]["code"] = codes[i]

        # pops
        if len(data[0]["timeSeries"]) > 1:
            ts_rain = data[0]["timeSeries"][1]
            pops = ts_rain["areas"][0].get("pops", [])
            dates_r = ts_rain.get("timeDefines", [])
            for i, d in enumerate(dates_r):
                date_key = d.split("T")[0]
                if date_key not in daily_db:
                    continue
                daily_db[date_key].setdefault("rain_raw", [])
                if i < len(pops):
                    daily_db[date_key]["rain_raw"].append(pops[i])

        # temps time series
        if len(data[0]["timeSeries"]) > 2:
            ts_temp = data[0]["timeSeries"][2]
            temps = ts_temp["areas"][0].get("temps", [])
            dates_t = ts_temp.get("timeDefines", [])
            for i, d in enumerate(dates_t):
                date_key = d.split("T")[0]
                if date_key not in daily_db:
                    continue
                daily_db[date_key].setdefault("temp_raw", [])
                if i < len(temps):
                    daily_db[date_key]["temp_raw"].append(temps[i])

        # weekly in data[1]
        if len(data) > 1:
            weekly = data[1]["timeSeries"]
            dates_wk = weekly[0]["timeDefines"]
            w_codes = weekly[0]["areas"][0]["weatherCodes"]
            w_pops = weekly[0]["areas"][0].get("pops", [])
            w_min = weekly[1]["areas"][0].get("tempsMin", [])
            w_max = weekly[1]["areas"][0].get("tempsMax", [])

            for i, d in enumerate(dates_wk):
                date_key = d.split("T")[0]
                daily_db.setdefault(date_key, {})
                if "code" not in daily_db[date_key] and i < len(w_codes):
                    daily_db[date_key]["code"] = w_codes[i]

                if i < len(w_pops) and w_pops[i] not in ("-", "", None):
                    daily_db[date_key].setdefault("rain_raw", [w_pops[i]])

                tmin = w_min[i] if i < len(w_min) and w_min[i] not in ("", None) else None
                tmax = w_max[i] if i < len(w_max) and w_max[i] not in ("", None) else None
                if tmin is not None or tmax is not None:
                    daily_db[date_key]["temp_summary"] = {"min": tmin, "max": tmax}

    except Exception as e:
        print(f"JMA Parse Error ({area_code}): {e}")

    # warning
    try:
        with urllib.request.urlopen(warning_url, timeout=8) as res:
            w_data = json.loads(res.read().decode("utf-8"))
        if isinstance(w_data, dict) and "warnings" in w_data:
            for w in w_data["warnings"]:
                if w.get("status") not in ["発表なし", "解除"]:
                    warning_text = "気象警報・注意報 発表中"
                    break
    except Exception:
        pass

    return daily_db, warning_text

# =========================
# Open-Meteo (hourly)
# =========================
def fetch_openmeteo_hourly(lat: float, lon: float, days: int = 7):
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={lat}&longitude={lon}"
        "&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,weathercode"
        "&timezone=Asia%2FTokyo"
        f"&forecast_days={days}"
    )
    try:
        res = requests.get(url, timeout=15)
        if res.status_code == 200:
            return res.json()
    except Exception:
        return None
    return None

def build_slot_weather(openmeteo_json, target_dt: datetime):
    if not openmeteo_json:
        return None

    hourly = openmeteo_json.get("hourly", {})
    times = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    hums = hourly.get("relative_humidity_2m", [])
    pops = hourly.get("precipitation_probability", [])
    wcodes = hourly.get("weathercode", [])

    date_str = target_dt.strftime("%Y-%m-%d")
    idxs = [i for i, t in enumerate(times) if isinstance(t, str) and t.startswith(date_str)]
    if not idxs:
        return None

    def slot_pack(start_h, end_h, prefer_hour):
        ids = []
        for gi in idxs:
            try:
                hh = int(times[gi].split("T")[1].split(":")[0])
            except Exception:
                continue
            if start_h <= hh < end_h:
                ids.append(gi)

        if not ids:
            return {"weather":"☁️","temp":"-","temp_high":"-","temp_low":"-","humidity":"-","rain":"-","wcode":None}

        # representative hour
        best_k = None
        best_diff = 10**9
        for gi in ids:
            try:
                hh = int(times[gi].split("T")[1].split(":")[0])
                d = abs(hh - prefer_hour)
                if d < best_diff:
                    best_diff = d
                    best_k = gi
            except Exception:
                pass

        tvals = []
        for gi in ids:
            try:
                tvals.append(float(temps[gi]))
            except Exception:
                pass
        t_high = round(max(tvals)) if tvals else None
        t_low = round(min(tvals)) if tvals else None

        t_rep = None
        if best_k is not None:
            try:
                t_rep = round(float(temps[best_k]))
            except Exception:
                t_rep = None
        if t_rep is None and tvals:
            t_rep = round(sum(tvals)/len(tvals))

        hvals = []
        for gi in ids:
            try:
                hvals.append(float(hums[gi]))
            except Exception:
                pass
        h_rep = None
        if best_k is not None:
            try:
                h_rep = float(hums[best_k])
            except Exception:
                h_rep = None
        if h_rep is None and hvals:
            h_rep = sum(hvals)/len(hvals)

        pvals = []
        for gi in ids:
            try:
                pvals.append(float(pops[gi]))
            except Exception:
                pass
        p_max = max(pvals) if pvals else None

        wcode_val = None
        if best_k is not None:
            try:
                wcode_val = int(wcodes[best_k])
            except Exception:
                wcode_val = None
        emoji = get_weather_emoji_openmeteo(wcode_val) if wcode_val is not None else "☁️"

        return {
            "weather": emoji,
            "temp": f"{t_rep}℃" if t_rep is not None else "-",
            "temp_high": f"{t_high}℃" if t_high is not None else "-",
            "temp_low": f"{t_low}℃" if t_low is not None else "-",
            "humidity": round10_percent(h_rep) if h_rep is not None else "-",
            "rain": round10_percent(p_max) if p_max is not None else "-",
            "wcode": wcode_val
        }

    return {
        "morning": slot_pack(6, 12, 9),
        "daytime": slot_pack(12, 18, 15),
        "night": slot_pack(18, 24, 21),
    }

# =========================
# Gemini (optional)
# =========================
def _post_json(url, headers, payload, timeout=60, retry=3, backoff=2.0):
    for i in range(retry):
        try:
            res = requests.post(url, headers=headers, json=payload, timeout=timeout)
            if res.status_code == 200:
                return res.json()
        except Exception:
            pass
        time.sleep(backoff ** i)
    return None

def call_gemini_search(prompt: str):
    if not API_KEY:
        return None
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={API_KEY}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "tools": [{"googleSearch": {}}],
        "generationConfig": {"temperature": 0.4}
    }
    data = _post_json(url, headers, payload, timeout=75, retry=3)
    if not data:
        return None
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except Exception:
        return None

def call_gemini_json(prompt: str):
    if not API_KEY:
        return None
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={API_KEY}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.3, "responseMimeType": "application/json"}
    }
    data = _post_json(url, headers, payload, timeout=75, retry=3)
    if not data:
        return None
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except Exception:
        return None

# =========================
# Event/Traffic (AI_DAYS)
# =========================
def fetch_event_traffic_7days(area_name: str, days: int):
    """
    Returns dict[YYYY-MM-DD] = "bullets text"
    If unavailable -> all empty
    """
    today = datetime.now(JST).date()
    date_keys = [(today + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(days)]

    if not API_KEY:
        return {d: "" for d in date_keys}

    search_prompt = (
        "あなたはプロの調査員です。\n"
        f"対象エリア: {area_name}\n"
        f"期間: {date_keys[0]} から {date_keys[-1]}（{days}日）\n\n"
        "次の情報を、日付ごとに整理して検索してまとめてください。\n"
        "優先順位:\n"
        "1) 交通: 鉄道/バス/航空の遅延・運休、道路の通行止め、規制、渋滞、事故\n"
        "2) イベント: ライブ/スポーツ/展示会/祭り等（中止/変更も）\n"
        "3) 注意情報: 大雪/強風/警報級など交通に影響しうる情報\n\n"
        "出力は「日付見出し + 箇条書き」形式で、必ず全日分を作ること。\n"
        "日付が分からない情報は「不明」にまとめること。\n"
        "フェイクは書かない。曖昧なら「未確認」と明記。\n"
    )
    text = call_gemini_search(search_prompt)
    if not text:
        return {d: "" for d in date_keys}

    json_prompt = (
        "次の文章を解析して、期間内の日数分を必ず埋めたJSONに変換してください。\n"
        "キーは日付(YYYY-MM-DD)、値はその日のEvent/Traffic要約（箇条書き文字列、改行OK）。\n"
        f"期間: {date_keys[0]} から {date_keys[-1]}\n"
        "文章:\n"
        + text
        + "\n\n"
        "出力はこのJSONのみ:\n"
        + "{\n"
        + ",\n".join([f'  "{d}": "..."' for d in date_keys])
        + "\n}\n"
    )
    jtxt = call_gemini_json(json_prompt)
    if not jtxt:
        return {d: "" for d in date_keys}

    try:
        j = json.loads(extract_json_block(jtxt))
        out = {}
        for d in date_keys:
            out[d] = (j.get(d) or "").strip()
        return out
    except Exception:
        return {d: "" for d in date_keys}

def to_facts_list(event_traffic_text: str, max_items=6):
    if not event_traffic_text:
        return []
    lines = []
    for raw in event_traffic_text.splitlines():
        s = raw.strip()
        if not s:
            continue
        s = re.sub(r"^[\-\•\*・\u2022]+\s*", "", s)
        if not s:
            continue
        if s.startswith(("202", "203")):
            continue
        if s == "特段の検索結果なし":
            continue
        lines.append(s)

    uniq = []
    seen = set()
    for s in lines:
        if s in seen:
            continue
        seen.add(s)
        uniq.append(s)
    return uniq[:max_items]

# =========================
# Weather choose helpers
# =========================
def decide_high_low(area_data, day_data, is_today: bool):
    summary = (day_data or {}).get("temp_summary", {}) or {}
    high_val = summary.get("max")
    low_val = summary.get("min")

    t_raw = (day_data or {}).get("temp_raw", []) or []
    valid_t = []
    for x in t_raw:
        try:
            valid_t.append(float(x))
        except Exception:
            pass
    if valid_t:
        if high_val is None:
            high_val = max(valid_t)
        if low_val is None:
            low_val = min(valid_t)

    if is_today:
        am = get_amedas_daily_stats(area_data.get("amedas_code", ""))
        if am:
            if low_val is None or float(low_val) > am["min"]:
                low_val = am["min"]
            if high_val is None or am["max"] > float(high_val):
                high_val = am["max"]

    str_high = f"{round(float(high_val))}" if high_val is not None else "-"
    str_low = f"{round(float(low_val))}" if low_val is not None else "-"
    return str_high, str_low

def decide_rain_display_jma(day_data):
    r_raw = (day_data or {}).get("rain_raw", []) or []
    if not r_raw:
        return "-"
    try:
        vals = [int(x) for x in r_raw if x not in ("-", "", None)]
        return f"{max(vals)}%" if vals else "-"
    except Exception:
        return "-"

def decide_rain_am_pm(slot_weather, jma_fallback="-"):
    if slot_weather:
        am = slot_weather.get("morning", {}).get("rain", "-")
        pm = slot_weather.get("daytime", {}).get("rain", "-")
        ng = slot_weather.get("night", {}).get("rain", "-")
        if am != "-" or pm != "-" or ng != "-":
            return am, pm, ng
    return jma_fallback, jma_fallback, jma_fallback

# =========================
# Rank (simple)
# =========================
def base_rank_for_date(target_dt: datetime):
    date_str = target_dt.strftime("%Y-%m-%d")
    # default C
    rank = "C"
    # Fri/Sat -> B (soft)
    if target_dt.weekday() in (4, 5):
        rank = "B"
    if date_str in HOLIDAYS_2026:
        rank = "B"
    next_day = (target_dt + timedelta(days=1)).strftime("%Y-%m-%d")
    if next_day in HOLIDAYS_2026:
        rank = "B"
    return rank

# =========================
# Long-term fallback (safe)
# =========================
def get_long_term_text_safe(area_name: str):
    # Keep short & stable. If Gemini available, enrich.
    base = (
        f"エリア: {area_name}\n"
        "向こう数ヶ月は季節の変わり目で天候が変動しやすい時期です。\n"
        "雨・強風・寒暖差で移動需要や外出行動がブレるため、当日朝の最新情報を前提に運用してください。\n"
    )
    if not API_KEY:
        return base

    prompt = (
        f"エリア: {area_name}\n"
        "向こう3ヶ月の気象傾向と主要イベントの傾向をGoogle検索し、"
        "自然な日本語の短い文章でまとめて。\n"
        "JSON形式は禁止。Markdownテキストのみ。\n"
    )
    res = call_gemini_search(prompt)
    return res.strip() if res else base

def build_long_term_day(target_dt: datetime, long_term_text: str):
    full_date = _date_label(target_dt)
    rank = base_rank_for_date(target_dt)

    # Minimal structure that main.dart expects
    wo = {
        "condition": "☁️",
        "high": "-",
        "low": "-",
        "rain": "-",
        "rain_am": None,
        "rain_pm": None,
        "rain_night": None,
        "warning": "-"
    }

    return {
        "date": full_date,
        "is_long_term": True,
        "rank": rank,
        "weather_overview": wo,
        "event_traffic_facts": [],
        "peak_windows": {k: "" for k in JOB_KEYS},
        "job_actions": {k: "" for k in JOB_KEYS},
        "daily_schedule_and_impact": f"【{target_dt.strftime('%m月%d日')}の長期予測】\n\n■長期傾向\n{long_term_text}\n",
        "timeline": None,
        "confidence": 0
    }

# =========================
# AI day generation (optional)
# =========================
def generate_ai_day(area_data, target_dt: datetime, jma_day_data, warning_text: str, slot_weather, event_traffic_text: str):
    """
    Returns dict aligned with main.dart model.
    If Gemini unavailable/fails -> returns None (caller will fallback).
    """
    if not API_KEY:
        return None

    date_str = target_dt.strftime("%Y-%m-%d")
    full_date = _date_label(target_dt)

    w_code = (jma_day_data or {}).get("code", "200")
    w_emoji = get_weather_emoji_jma(w_code)

    now_dt = datetime.now(JST)
    is_today = (target_dt.date() == now_dt.date())

    high, low = decide_high_low(area_data, jma_day_data or {}, is_today=is_today)

    jma_rain_fallback = decide_rain_display_jma(jma_day_data or {})
    if not slot_weather:
        slot_weather = {
            "morning": {"weather": w_emoji, "temp": "-", "temp_high": "-", "temp_low": "-", "humidity": "-", "rain": jma_rain_fallback, "wcode": None},
            "daytime": {"weather": w_emoji, "temp": "-", "temp_high": "-", "temp_low": "-", "humidity": "-", "rain": jma_rain_fallback, "wcode": None},
            "night": {"weather": w_emoji, "temp": "-", "temp_high": "-", "temp_low": "-", "humidity": "-", "rain": jma_rain_fallback, "wcode": None},
        }

    rain_am, rain_pm, rain_ng = decide_rain_am_pm(slot_weather, jma_fallback=jma_rain_fallback)
    rain_display = f"午前{rain_am} / 午後{rain_pm}"

    facts_list = to_facts_list(event_traffic_text, max_items=6)
    facts_text_for_ai = "\n".join([f"- {x}" for x in facts_list]) if facts_list else "(特段の情報なし)"

    # Build facts block (safe; no braces complexity)
    facts_block = "\n".join([
        "[Area]",
        area_data["name"],
        f"特徴: {area_data.get('feature','')}",
        "",
        "[Date]",
        f"{date_str} / {full_date}",
        "",
        "[Weather Overview]",
        f"天気: {w_emoji} (JMA code {w_code})",
        f"最高: {high}℃ / 最低: {low}℃",
        f"降水（Open-Meteo/10%丸め）: 午前{rain_am} / 午後{rain_pm} / 夜{rain_ng}",
        f"警報注意報: {warning_text}",
        "",
        "[Time Slots Weather]（Open-Meteo/10%丸め）",
        f"朝(06-12): {slot_weather['morning']['weather']} / 気温 {slot_weather['morning']['temp']}（高{slot_weather['morning']['temp_high']} 低{slot_weather['morning']['temp_low']}）/ 湿度 {slot_weather['morning']['humidity']} / 降水 {slot_weather['morning']['rain']}",
        f"昼(12-18): {slot_weather['daytime']['weather']} / 気温 {slot_weather['daytime']['temp']}（高{slot_weather['daytime']['temp_high']} 低{slot_weather['daytime']['temp_low']}）/ 湿度 {slot_weather['daytime']['humidity']} / 降水 {slot_weather['daytime']['rain']}",
        f"夜(18-24): {slot_weather['night']['weather']} / 気温 {slot_weather['night']['temp']}（高{slot_weather['night']['temp_high']} 低{slot_weather['night']['temp_low']}）/ 湿度 {slot_weather['night']['humidity']} / 降水 {slot_weather['night']['rain']}",
        "",
        "[Event & Traffic Facts]",
        facts_text_for_ai
    ])

    # Prepare a schema hint without f-string braces troubles
    schema_hint = {
        "date": full_date,
        "is_long_term": False,
        "rank": "S/A/B/C",
        "weather_overview": {
            "condition": w_emoji,
            "high": f"最高{high}℃",
            "low": f"最低{low}℃",
            "rain": rain_display,
            "rain_am": rain_am,
            "rain_pm": rain_pm,
            "rain_night": rain_ng,
            "warning": warning_text
        },
        "event_traffic_facts": ["(max 6)"],
        "peak_windows": {k: "" for k in JOB_KEYS},
        "job_actions": {k: "" for k in JOB_KEYS},
        "daily_schedule_and_impact": "レポート本文（改行OK。最後に職業別要点を含める）",
        "timeline": {
            "morning": {
                "weather": slot_weather["morning"]["weather"],
                "temp": slot_weather["morning"]["temp"],
                "temp_high": slot_weather["morning"]["temp_high"],
                "temp_low": slot_weather["morning"]["temp_low"],
                "humidity": slot_weather["morning"]["humidity"],
                "rain": slot_weather["morning"]["rain"],
                "advice": {k: "" for k in JOB_KEYS}
            },
            "daytime": {
                "weather": slot_weather["daytime"]["weather"],
                "temp": slot_weather["daytime"]["temp"],
                "temp_high": slot_weather["daytime"]["temp_high"],
                "temp_low": slot_weather["daytime"]["temp_low"],
                "humidity": slot_weather["daytime"]["humidity"],
                "rain": slot_weather["daytime"]["rain"],
                "advice": {k: "" for k in JOB_KEYS}
            },
            "night": {
                "weather": slot_weather["night"]["weather"],
                "temp": slot_weather["night"]["temp"],
                "temp_high": slot_weather["night"]["temp_high"],
                "temp_low": slot_weather["night"]["temp_low"],
                "humidity": slot_weather["night"]["humidity"],
                "rain": slot_weather["night"]["rain"],
                "advice": {k: "" for k in JOB_KEYS}
            }
        },
        "confidence": 0
    }

    prompt = (
        "あなたは世界トップクラスの戦略コンサルタントです。\n"
        "以下の事実セットから、5つの職業（taxi/delivery/restaurant/retail/hotel）向けに、\n"
        "「その職業の意思決定が変わる」具体的な提案を作ってください。\n\n"
        "【ルール】\n"
        "- フェイク禁止。事実セットにない固有名詞を勝手に作らない。\n"
        "- 曖昧なら「未確認」と明記。\n"
        "- 断定の命令口調は禁止。\n"
        "- 一般論だけは禁止。必ず事実セット（天候/交通/イベント）に結びつける。\n"
        "- peak_windows / timeline.*.advice / job_actions は必ず全職業キーを埋める。\n"
        "- job_actions は「職業別の打ち手（要点）」として各職業1行で高密度（区切りは「｜」推奨）。\n\n"
        "【出力はJSONのみ】\n"
        "次のスキーマを満たすこと（キー追加は可。ただし最低限これを満たす）。\n\n"
        + json.dumps(schema_hint, ensure_ascii=False, indent=2)
        + "\n\n【レポート本文（daily_schedule_and_impact）に含めるべき構成】\n"
        "- ■Event & Traffic（事実セットの範囲で段落分けして要約）\n"
        "- ■総括（その日全体の読み：短め）\n"
        "- ■職業別の打ち手（要点）\n"
        "  ・タクシー: ...\n"
        "  ・デリバリー: ...\n"
        "  ・飲食店: ...\n"
        "  ・小売: ...\n"
        "  ・ホテル: ...\n\n"
        "【事実セット】\n"
        + facts_block
    )

    res = call_gemini_json(prompt)
    if not res:
        return None

    try:
        j = json.loads(extract_json_block(res))
    except Exception:
        return None

    # ---- sanitize & ensure schema for main.dart ----
    j.setdefault("date", full_date)
    j.setdefault("is_long_term", False)
    j.setdefault("rank", base_rank_for_date(target_dt))

    wo = j.get("weather_overview") or {}
    wo.setdefault("condition", w_emoji)
    wo.setdefault("high", f"最高{high}℃")
    wo.setdefault("low", f"最低{low}℃")
    wo.setdefault("rain", rain_display)
    wo.setdefault("rain_am", rain_am)
    wo.setdefault("rain_pm", rain_pm)
    wo.setdefault("rain_night", rain_ng)
    wo.setdefault("warning", warning_text)
    j["weather_overview"] = wo

    et = j.get("event_traffic_facts")
    if not isinstance(et, list):
        et = facts_list
    j["event_traffic_facts"] = [str(x).strip() for x in et if str(x).strip()][:6]

    pw = j.get("peak_windows") or {}
    for k in JOB_KEYS:
        pw.setdefault(k, "")
    j["peak_windows"] = {k: str(pw.get(k, "")).strip() for k in JOB_KEYS}

    ja = j.get("job_actions") or {}
    for k in JOB_KEYS:
        ja.setdefault(k, "")
    j["job_actions"] = {k: str(ja.get(k, "")).strip() for k in JOB_KEYS}

    j.setdefault("daily_schedule_and_impact", "")

    tl = j.get("timeline")
    if not isinstance(tl, dict):
        tl = {}
    for slot_name in ["morning", "daytime", "night"]:
        slot_src = tl.get(slot_name) if isinstance(tl.get(slot_name), dict) else {}
        base = slot_weather.get(slot_name, {})
        slot_src["weather"] = str(slot_src.get("weather") or base.get("weather") or "☁️")
        slot_src["temp"] = str(slot_src.get("temp") or base.get("temp") or "-")
        slot_src["temp_high"] = str(slot_src.get("temp_high") or base.get("temp_high") or "-")
        slot_src["temp_low"] = str(slot_src.get("temp_low") or base.get("temp_low") or "-")
        slot_src["humidity"] = str(slot_src.get("humidity") or base.get("humidity") or "-")
        slot_src["rain"] = str(slot_src.get("rain") or base.get("rain") or "-")

        advice = slot_src.get("advice") if isinstance(slot_src.get("advice"), dict) else {}
        for k in JOB_KEYS:
            advice.setdefault(k, "")
        slot_src["advice"] = {k: str(advice.get(k, "")).strip() for k in JOB_KEYS}
        tl[slot_name] = slot_src
    j["timeline"] = tl

    # ★差し込み：timelineの温度から日次の最高/最低を正規化（main.dart側の表示安定化）
    normalize_high_low_from_timeline(j)

    conf = j.get("confidence")
    j["confidence"] = int(conf) if isinstance(conf, (int, float)) else 0

    return j

# =========================
# Area processing
# =========================
def process_single_area(item):
    area_key, area_data = item
    print(f"\n📍 {area_data['name']} 開始", flush=True)

    daily_db, warning_text = get_jma_forecast_data(area_data["jma_code"])
    om = fetch_openmeteo_hourly(area_data["lat"], area_data["lon"], days=AI_DAYS)
    facts_by_date = fetch_event_traffic_7days(area_data["name"], AI_DAYS)
    long_term_text = get_long_term_text_safe(area_data["name"])

    area_forecasts = []
    today_dt = datetime.now(JST)

    for i in range(RUN_DAYS):
        target_dt = today_dt + timedelta(days=i)
        date_key = target_dt.strftime("%Y-%m-%d")

        if i < AI_DAYS:
            day_data = daily_db.get(date_key, {})
            slot_weather = build_slot_weather(om, target_dt)
            et_text = (facts_by_date.get(date_key) or "").strip()

            print(f"🤖 {area_data['name']} / {date_key} ", end="", flush=True)
            ai = generate_ai_day(
                area_data=area_data,
                target_dt=target_dt,
                jma_day_data=day_data,
                warning_text=warning_text,
                slot_weather=slot_weather,
                event_traffic_text=et_text
            )
            if ai:
                print("OK", flush=True)
                area_forecasts.append(ai)
            else:
                print("NG → fallback", flush=True)
                area_forecasts.append(build_long_term_day(target_dt, long_term_text))
        else:
            area_forecasts.append(build_long_term_day(target_dt, long_term_text))

    print(f"✅ {area_data['name']} 完了", flush=True)
    return area_key, area_forecasts

# =========================
# Main
# =========================
def main():
    today = datetime.now(JST)
    print(f"🦅 Eagle Eye (assets writer) 起動: {today.strftime('%Y/%m/%d %H:%M')}", flush=True)

    out_dir = os.path.dirname(OUTPUT_PATH)
    os.makedirs(out_dir, exist_ok=True)

    master_data = {}
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(process_single_area, item) for item in TARGET_AREAS.items()]
        for future in as_completed(futures):
            try:
                key, data = future.result()
                master_data[key] = data
            except Exception as e:
                print(f"Err: {e}", flush=True)

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)

    print(f"\n✅ 保存完了: {OUTPUT_PATH}", flush=True)
    print("✅ 全工程完了", flush=True)

if __name__ == "__main__":
    main()
