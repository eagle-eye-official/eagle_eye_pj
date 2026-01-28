import os
import json
import time
import urllib.request
import re
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

# =========================
# 設定
# =========================
API_KEY = os.environ.get("GEMINI_API_KEY")
JST = timezone(timedelta(hours=9), "JST")

RUN_DAYS = 90   # 90日ぶん生成
AI_DAYS = 7     # 直近7日だけAI（イベント/交通も反映）
MAX_WORKERS = 4

GEMINI_MODEL = "gemini-2.5-flash"

# Flutter 側は assets/eagle_eye_data.json を読む
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "assets", "eagle_eye_data.json")

# --- 2026年 祝日定義（必要なら増やしてOK） ---
HOLIDAYS_2026 = {
    "2026-01-01", "2026-01-12", "2026-02-11", "2026-02-23", "2026-03-20",
    "2026-04-29", "2026-05-03", "2026-05-04", "2026-05-05", "2026-05-06",
    "2026-07-20", "2026-08-11", "2026-09-21", "2026-09-22", "2026-09-23",
    "2026-10-12", "2026-11-03", "2026-11-23", "2026-11-24"
}

# =========================
# 職業キー（5つ固定：Flutterと一致）
# =========================
JOB_KEYS = ["taxi", "delivery", "restaurant", "retail", "hotel"]

JOB_LABELS_JA = {
    "taxi": "タクシー",
    "delivery": "デリバリー",
    "restaurant": "飲食店",
    "retail": "小売",
    "hotel": "ホテル観光",
}

# =========================
# 戦略的30地点定義（そのまま使用）
# =========================
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
# 小物ユーティリティ
# =========================
def round10_percent(v):
    """0-100の数値を10%単位に丸めて文字列 '70%' で返す"""
    try:
        x = int(round(float(v)))
        x = max(0, min(100, x))
        x = int(round(x / 10.0) * 10)
        return f"{x}%"
    except:
        return "-"

def get_weather_emoji_jma(code):
    """JMA weather code → emoji（簡易）"""
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
    except:
        pass
    return "☁️"

def get_weather_emoji_openmeteo(code):
    """Open-Meteo weathercode → emoji（ざっくり）"""
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
    except:
        pass
    return "☁️"

# =========================
# AMeDAS（今日の実測で最高/最低補正）
# =========================
def get_amedas_daily_stats(amedas_code):
    """
    今日0時〜現在の1時間値から 最高/最低 を算出
    """
    if not amedas_code:
        return None
    today_str = datetime.now(JST).strftime("%Y%m%d")
    url = f"https://www.jma.go.jp/bosai/amedas/data/point/{amedas_code}/{today_str}_1h.json"
    try:
        with urllib.request.urlopen(url, timeout=10) as res:
            data = json.loads(res.read().decode("utf-8"))
        temps = []
        for _, vals in data.items():
            if isinstance(vals, dict) and "temp" in vals and vals["temp"][0] is not None:
                temps.append(vals["temp"][0])
        if temps:
            return {"max": max(temps), "min": min(temps)}
    except:
        pass
    return None

# =========================
# JMA 予報
# =========================
def get_jma_forecast_data(area_code):
    forecast_url = f"https://www.jma.go.jp/bosai/forecast/data/forecast/{area_code}.json"
    warning_url = f"https://www.jma.go.jp/bosai/warning/data/warning/{area_code}.json"

    daily_db = {}

    try:
        with urllib.request.urlopen(forecast_url, timeout=15) as res:
            data = json.loads(res.read().decode("utf-8"))

        # 詳細（data[0]）
        ts_weather = data[0]["timeSeries"][0]
        codes = ts_weather["areas"][0]["weatherCodes"]
        dates_w = ts_weather["timeDefines"]
        for i, d in enumerate(dates_w):
            date_key = d.split("T")[0]
            daily_db.setdefault(date_key, {})
            daily_db[date_key]["code"] = codes[i]

        # 降水確率
        if len(data[0]["timeSeries"]) > 1:
            ts_rain = data[0]["timeSeries"][1]
            pops = ts_rain["areas"][0]["pops"]
            dates_r = ts_rain["timeDefines"]
            for i, d in enumerate(dates_r):
                date_key = d.split("T")[0]
                if date_key not in daily_db:
                    continue
                daily_db[date_key].setdefault("rain_raw", [])
                daily_db[date_key]["rain_raw"].append(pops[i])

        # 気温（時系列）
        if len(data[0]["timeSeries"]) > 2:
            ts_temp = data[0]["timeSeries"][2]
            temps = ts_temp["areas"][0]["temps"]
            dates_t = ts_temp["timeDefines"]
            for i, d in enumerate(dates_t):
                date_key = d.split("T")[0]
                if date_key not in daily_db:
                    continue
                daily_db[date_key].setdefault("temp_raw", [])
                daily_db[date_key]["temp_raw"].append(temps[i])

        # 週間（data[1]）
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
                daily_db[date_key].setdefault("code", w_codes[i])

                if i < len(w_pops) and w_pops[i] not in ("-", "", None):
                    daily_db[date_key].setdefault("rain_raw", [w_pops[i]])

                tmin = w_min[i] if i < len(w_min) and w_min[i] not in ("", None) else None
                tmax = w_max[i] if i < len(w_max) and w_max[i] not in ("", None) else None
                if tmin is not None or tmax is not None:
                    daily_db[date_key]["temp_summary"] = {"min": tmin, "max": tmax}

    except Exception as e:
        print(f"JMA Parse Error ({area_code}): {e}")

    warning_text = "特になし"
    try:
        with urllib.request.urlopen(warning_url, timeout=5) as res:
            w_data = json.loads(res.read().decode("utf-8"))
        if "warnings" in w_data:
            for w in w_data["warnings"]:
                if w.get("status") not in ["発表なし", "解除"]:
                    warning_text = "気象警報・注意報 発表中"
                    break
    except:
        pass

    return daily_db, warning_text

# =========================
# Open-Meteo（時間帯別）
# =========================
def fetch_openmeteo_hourly(lat, lon, days=7):
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
    except:
        pass
    return None

def build_slot_weather(openmeteo_json, target_date):
    if not openmeteo_json:
        return None

    hourly = openmeteo_json.get("hourly", {})
    times = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    hums = hourly.get("relative_humidity_2m", [])
    pops = hourly.get("precipitation_probability", [])
    wcodes = hourly.get("weathercode", [])

    date_str = target_date.strftime("%Y-%m-%d")
    idxs = [i for i, t in enumerate(times) if isinstance(t, str) and t.startswith(date_str)]
    if not idxs:
        return None

    hours = []
    for i in idxs:
        try:
            hh = int(times[i].split("T")[1].split(":")[0])
        except:
            hh = None
        hours.append(hh)

    def slot_pack(start_h, end_h, prefer_hour):
        ids = []
        for local_i, global_i in enumerate(idxs):
            hh = hours[local_i]
            if hh is None:
                continue
            if start_h <= hh < end_h:
                ids.append(global_i)

        if not ids:
            return {
                "weather": "☁️",
                "temp": "-",
                "temp_high": "-",
                "temp_low": "-",
                "humidity": "-",
                "rain": "-",
                "wcode": None
            }

        best_k = None
        best_diff = 999
        for k in ids:
            try:
                hh = int(times[k].split("T")[1].split(":")[0])
                d = abs(hh - prefer_hour)
                if d < best_diff:
                    best_diff = d
                    best_k = k
            except:
                pass

        tvals = []
        for k in ids:
            try:
                tvals.append(float(temps[k]))
            except:
                pass
        t_high = round(max(tvals)) if tvals else None
        t_low = round(min(tvals)) if tvals else None

        t_rep = None
        if best_k is not None:
            try:
                t_rep = round(float(temps[best_k]))
            except:
                t_rep = None
        if t_rep is None and tvals:
            t_rep = round(sum(tvals) / len(tvals))

        hvals = []
        for k in ids:
            try:
                hvals.append(float(hums[k]))
            except:
                pass
        h_rep = None
        if best_k is not None:
            try:
                h_rep = float(hums[best_k])
            except:
                h_rep = None
        if h_rep is None and hvals:
            h_rep = sum(hvals) / len(hvals)

        pvals = []
        for k in ids:
            try:
                pvals.append(float(pops[k]))
            except:
                pass
        p_max = max(pvals) if pvals else None

        wcode_val = None
        if best_k is not None:
            try:
                wcode_val = int(wcodes[best_k])
            except:
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
# Gemini 呼び出し（リトライ付き）
# =========================
def _post_json(url, headers, payload, timeout=60, retry=3, backoff=2.0):
    for i in range(retry):
        try:
            res = requests.post(url, headers=headers, json=payload, timeout=timeout)
            if res.status_code == 200:
                return res.json()
        except:
            pass
        time.sleep(backoff ** i)
    return None

def call_gemini_search(prompt):
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
    except:
        return None

def call_gemini_json(prompt):
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
    except:
        return None

def extract_json_block(text):
    try:
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if match:
            return match.group(0)
    except:
        pass
    return text

# =========================
# Event/Traffic（7日まとめ）
# =========================
def fetch_event_traffic_7days(area_name):
    """
    返り値: dict[YYYY-MM-DD] = "箇条書きテキスト"
    何も取れなかった日は空文字にする（Flutter側の「今日の判断材料」を出さないため）
    """
    today = datetime.now(JST).date()
    dates = [(today + timedelta(days=i)).strftime("%Y-%m-%d") for i in range(AI_DAYS)]

    search_prompt = f"""
あなたはプロの調査員です。
対象エリア: {area_name}
期間: {dates[0]} から {dates[-1]}（7日）

次の情報を、日付ごとに整理して徹底的に検索してまとめてください。
優先順位:
1) 交通: JR/地下鉄/私鉄/バス/航空の遅延・運休、道路の通行止め、規制、渋滞、事故
2) イベント: ライブ/スポーツ/展示会/祭り等（開催中止/変更も）
3) 注意情報: 大雪/強風/警報級など、交通に影響しうる情報

出力は「日付見出し + 箇条書き」形式で、必ず7日分を作ること。
日付が分からない情報は該当日付に入れず「不明」枠にまとめること。
フェイクは書かない。曖昧なら「未確認」と明記。
""".strip()

    text = call_gemini_search(search_prompt)
    if not text:
        return {d: "" for d in dates}

    json_prompt = f"""
次の文章を解析して、期間内7日分を必ず埋めたJSONに変換してください。
キーは日付(YYYY-MM-DD)、値はその日のEvent/Traffic要約（箇条書き文字列、改行OK）。
期間: {dates[0]} から {dates[-1]}
文章:
{text}

出力はこのJSONのみ:
{{
  "{dates[0]}": "...",
  "...": "...",
  "{dates[-1]}": "..."
}}
""".strip()

    jtxt = call_gemini_json(json_prompt)
    if not jtxt:
        return {d: "" for d in dates}

    try:
        j = json.loads(extract_json_block(jtxt))
        for d in dates:
            v = (j.get(d) or "").strip()
            j[d] = v
        return j
    except:
        return {d: "" for d in dates}

def to_facts_list(event_traffic_text, max_items=6):
    """
    Geminiが返した箇条書きテキストを、Flutter用の List[str] に正規化
    - 空なら [] を返す（セクションを出さないため）
    """
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
# 気温 / 降水
# =========================
def decide_high_low(area_data, day_data, is_today):
    summary = day_data.get("temp_summary", {}) if day_data else {}
    high_val = summary.get("max")
    low_val = summary.get("min")

    t_raw = day_data.get("temp_raw", []) if day_data else []
    valid_t = []
    for x in t_raw:
        try:
            valid_t.append(float(x))
        except:
            pass
    if valid_t:
        if high_val is None:
            high_val = max(valid_t)
        if low_val is None:
            low_val = min(valid_t)

    if is_today:
        amedas_stats = get_amedas_daily_stats(area_data.get("amedas_code", ""))
        if amedas_stats:
            actual_min = amedas_stats["min"]
            actual_max = amedas_stats["max"]
            if low_val is None or (low_val > actual_min):
                low_val = actual_min
            if high_val is None or (actual_max > high_val):
                high_val = actual_max

    str_high = f"{round(float(high_val))}" if high_val is not None else "-"
    str_low = f"{round(float(low_val))}" if low_val is not None else "-"
    return str_high, str_low

def decide_rain_display_jma(day_data):
    r_raw = day_data.get("rain_raw", []) if day_data else []
    rain_val = "-"
    if r_raw:
        try:
            vals = [int(x) for x in r_raw if x not in ("-", "", None)]
            if vals:
                rain_val = f"{max(vals)}%"
        except:
            pass
    return rain_val

def decide_rain_am_pm(slot_weather, jma_fallback="-"):
    if slot_weather:
        am = slot_weather.get("morning", {}).get("rain", "-")
        pm = slot_weather.get("daytime", {}).get("rain", "-")
        ng = slot_weather.get("night", {}).get("rain", "-")
        if am != "-" or pm != "-":
            return am, pm, ng
    return jma_fallback, jma_fallback, jma_fallback

# =========================
# 休日判定（長期ランク用）
# =========================
def base_rank_for_date(target_date):
    date_str = target_date.strftime("%Y-%m-%d")
    rank = "C"
    # 金土をB（雑に需要が上がりやすい扱い）
    if target_date.weekday() in (4, 5):
        rank = "B"
    if date_str in HOLIDAYS_2026:
        rank = "B"
    next_day = (target_date + timedelta(days=1)).strftime("%Y-%m-%d")
    if next_day in HOLIDAYS_2026:
        rank = "B"
    return rank

# =========================
# 長期テキスト
# =========================
def get_long_term_text_safe(area_name):
    start = datetime.now(JST).date()
    end = (start + timedelta(days=RUN_DAYS)).strftime("%Y-%m-%d")
    prompt = f"""
エリア: {area_name}
期間: {start.strftime("%Y-%m-%d")} から {end}（約3ヶ月）

この期間の気象傾向（気温・降水・強風/雪/台風等）と、代表的な季節イベント傾向をGoogle検索して、
自然な日本語の文章で短くまとめてください。
JSON形式や辞書形式の出力は禁止。読みやすいMarkdownテキストのみ出力。
""".strip()
    res = call_gemini_search(prompt)
    if not res:
        return "長期予報データの取得に失敗しました。平年並みの傾向を参考にしてください。"
    return res

def build_long_term_day(target_date, long_term_text):
    date_display = target_date.strftime("%m月%d日")
    weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
    full_date = f"{date_display} ({weekday_str})"

    rank = base_rank_for_date(target_date)

    return {
        "date": full_date,
        "is_long_term": True,
        "rank": rank,
        "weather_overview": {
            "condition": "☁️",
            "high": "-",
            "low": "-",
            "rain": "-",
            "rain_am": "-",
            "rain_pm": "-",
            "rain_night": "-",
            "warning": "-"
        },
        "event_traffic_facts": [],
        "peak_windows": {k: "" for k in JOB_KEYS},
        "job_actions": {k: "" for k in JOB_KEYS},
        "daily_schedule_and_impact": f"【{date_display}の長期予測】\n\n■長期傾向\n{long_term_text}\n",
        "timeline": None,
        "confidence": 0
    }

# =========================
# AI生成（1日ぶん）
# =========================
def generate_ai_day(area_data, target_date, jma_day_data, warning_text, slot_weather, event_traffic_text):
    """
    Flutter(main.dart)のスキーマに合わせたJSONをGeminiで生成する（5職業固定）
    - peak_windows / job_actions / timeline.*.advice は全職業キー必須
    - event_traffic_facts は最大6、無ければ []
    """
    if not API_KEY:
        return None

    date_str = target_date.strftime("%Y-%m-%d")
    date_display = target_date.strftime("%m月%d日")
    weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
    full_date = f"{date_display} ({weekday_str})"

    w_code = (jma_day_data or {}).get("code", "200")
    w_emoji = get_weather_emoji_jma(w_code)

    now_dt = datetime.now(JST)
    is_today = (target_date.date() == now_dt.date())

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

    facts = (
        f"[Area]\n{area_data['name']}\n特徴: {area_data.get('feature','')}\n\n"
        f"[Date]\n{date_str} / {full_date}\n\n"
        f"[Weather Overview]\n"
        f"天気: {w_emoji} (JMA code {w_code})\n"
        f"最高: {high}℃ / 最低: {low}℃\n"
        f"降水（Open-Meteo/10%丸め）: 午前{rain_am} / 午後{rain_pm} / 夜{rain_ng}\n"
        f"警報注意報: {warning_text}\n\n"
        f"[Time Slots Weather]（Open-Meteo/10%丸め）\n"
        f"朝(06-12): {slot_weather['morning']['weather']} / 気温 {slot_weather['morning']['temp']}（高{slot_weather['morning']['temp_high']} 低{slot_weather['morning']['temp_low']}）/ 湿度 {slot_weather['morning']['humidity']} / 降水 {slot_weather['morning']['rain']}\n"
        f"昼(12-18): {slot_weather['daytime']['weather']} / 気温 {slot_weather['daytime']['temp']}（高{slot_weather['daytime']['temp_high']} 低{slot_weather['daytime']['temp_low']}）/ 湿度 {slot_weather['daytime']['humidity']} / 降水 {slot_weather['daytime']['rain']}\n"
        f"夜(18-24): {slot_weather['night']['weather']} / 気温 {slot_weather['night']['temp']}（高{slot_weather['night']['temp_high']} 低{slot_weather['night']['temp_low']}）/ 湿度 {slot_weather['night']['humidity']} / 降水 {slot_weather['night']['rain']}\n\n"
        f"[Event & Traffic Facts]\n{facts_text_for_ai}\n"
    )

    # JSONスキーマ例は dict→json.dumps で安全に混ぜる（f-string事故回避）
    schema_example = {
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
            "warning": warning_text,
        },
        "event_traffic_facts": [],
        "peak_windows": {k: "" for k in JOB_KEYS},
        "job_actions": {k: "" for k in JOB_KEYS},
        "daily_schedule_and_impact": "読みやすいレポート本文（改行OK。最後に職業別の要点も入れる）",
        "timeline": {
            "morning": {
                "weather": slot_weather["morning"]["weather"],
                "temp": slot_weather["morning"]["temp"],
                "temp_high": slot_weather["morning"]["temp_high"],
                "temp_low": slot_weather["morning"]["temp_low"],
                "humidity": slot_weather["morning"]["humidity"],
                "rain": slot_weather["morning"]["rain"],
                "advice": {k: "" for k in JOB_KEYS},
            },
            "daytime": {
                "weather": slot_weather["daytime"]["weather"],
                "temp": slot_weather["daytime"]["temp"],
                "temp_high": slot_weather["daytime"]["temp_high"],
                "temp_low": slot_weather["daytime"]["temp_low"],
                "humidity": slot_weather["daytime"]["humidity"],
                "rain": slot_weather["daytime"]["rain"],
                "advice": {k: "" for k in JOB_KEYS},
            },
            "night": {
                "weather": slot_weather["night"]["weather"],
                "temp": slot_weather["night"]["temp"],
                "temp_high": slot_weather["night"]["temp_high"],
                "temp_low": slot_weather["night"]["temp_low"],
                "humidity": slot_weather["night"]["humidity"],
                "rain": slot_weather["night"]["rain"],
                "advice": {k: "" for k in JOB_KEYS},
            },
        },
        "confidence": 0,
    }
    schema_text = json.dumps(schema_example, ensure_ascii=False, indent=2)

    prompt = f"""
あなたは世界トップクラスの戦略コンサルタントです。
以下の事実セットから、職業ごとに「意思決定が変わる」具体策を作ってください。

【ルール】
- フェイク禁止。事実セットにない固有名詞を勝手に作らない。
- 曖昧なら「未確認」と明記。
- 命令口調は禁止。
- 一般論だけは禁止。必ず事実セット（天候/交通/イベント）に結びつける。
- peak_windows / job_actions / timeline.*.advice は必ず全職業キー（taxi/delivery/restaurant/retail/hotel）を埋める。
- event_traffic_facts は最大6つ。無ければ []。

【出力はJSONのみ】
次のスキーマを満たすJSONを返してください（例）:
{schema_text}

【daily_schedule_and_impact に含める構成】
- ■Event & Traffic（事実セットの範囲で段落分け要約）
- ■総括（短め）
- ■職業別の打ち手（要点）
  ・タクシー:
  ・デリバリー:
  ・飲食店:
  ・小売:
  ・ホテル観光:

【事実セット】
{facts}
""".strip()

    res = call_gemini_json(prompt)
    if not res:
        return None

    try:
        j = json.loads(extract_json_block(res))

        # --- 最低限の安全埋め（Flutter側で落ちないように） ---
        j.setdefault("date", full_date)
        j.setdefault("is_long_term", False)
        j.setdefault("rank", "C")

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

            # 天気/温度などは Open-Meteo を優先して固定
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
        j["confidence"] = int(j.get("confidence") or 0)
        return j
    except:
        return None

# =========================
# エリア単位の処理
# =========================
def process_single_area(item):
    area_key, area_data = item
    print(f"\n📍 {area_data['name']} 開始", flush=True)

    daily_db, warning_text = get_jma_forecast_data(area_data["jma_code"])
    om = fetch_openmeteo_hourly(area_data["lat"], area_data["lon"], days=AI_DAYS)
    facts_by_date = fetch_event_traffic_7days(area_data["name"])
    long_term_text = get_long_term_text_safe(area_data["name"])

    area_forecasts = []
    today_dt = datetime.now(JST)

    for i in range(RUN_DAYS):
        target_date = (today_dt + timedelta(days=i))
        date_key = target_date.strftime("%Y-%m-%d")

        if i < AI_DAYS:
            day_data = daily_db.get(date_key, {})
            slot_weather = build_slot_weather(om, target_date)
            et_text = (facts_by_date.get(date_key) or "").strip()

            print(f"🤖 {area_data['name']} / {date_key} ", end="", flush=True)
            data = generate_ai_day(
                area_data=area_data,
                target_date=target_date,
                jma_day_data=day_data,
                warning_text=warning_text,
                slot_weather=slot_weather,
                event_traffic_text=et_text
            )
            if data:
                print("OK", flush=True)
                area_forecasts.append(data)
            else:
                print("NG → long_term fallback", flush=True)
                area_forecasts.append(build_long_term_day(target_date, long_term_text))
        else:
            area_forecasts.append(build_long_term_day(target_date, long_term_text))

    print(f"✅ {area_data['name']} 完了", flush=True)
    return area_key, area_forecasts

# =========================
# main
# =========================
if __name__ == "__main__":
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
