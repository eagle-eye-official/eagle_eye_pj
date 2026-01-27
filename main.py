import os
import json
import time
import urllib.request
import urllib.error
import re
from datetime import datetime, timedelta, timezone
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

# =========================
# 設定
# =========================
API_KEY = os.environ.get("GEMINI_API_KEY")
JST = timezone(timedelta(hours=9), "JST")

RUN_DAYS = 90
AI_DAYS = 7

MAX_WORKERS = 4  # 並列しすぎるとGemini/APIで詰まりやすいので控えめ推奨
GEMINI_MODEL = "gemini-2.5-flash"

# 都市部など「分割エリア」は日次概況をOpen-Meteo優先にする（体感差を縮める）
URBAN_SPLIT_AREAS = {
    "tokyo_marunouchi", "tokyo_ginza", "tokyo_shinjuku", "tokyo_shibuya", "tokyo_roppongi",
    "tokyo_ikebukuro", "tokyo_shinagawa", "tokyo_ueno", "tokyo_asakusa", "tokyo_akihabara",
    "tokyo_omotesando", "tokyo_ebisu", "tokyo_odaiba", "tokyo_toyosu", "tokyo_haneda",
    "osaka_kita", "osaka_minami", "osaka_hokusetsu", "osaka_bay", "osaka_tennoji",
}

# --- 2026年 祝日定義 ---
HOLIDAYS_2026 = {
    "2026-01-01", "2026-01-12", "2026-02-11", "2026-02-23", "2026-03-20",
    "2026-04-29", "2026-05-03", "2026-05-04", "2026-05-05", "2026-05-06",
    "2026-07-20", "2026-08-11", "2026-09-21", "2026-09-22", "2026-09-23",
    "2026-10-12", "2026-11-03", "2026-11-23", "2026-11-24"
}

# --- 戦略的30地点定義（そのまま使用） ---
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
# 共通: リトライ付きHTTP
# =========================
def _urlopen_json(url, timeout=15, retry=3, backoff=1.8):
    for i in range(retry):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as res:
                return json.loads(res.read().decode("utf-8"))
        except Exception:
            if i == retry - 1:
                break
            time.sleep(backoff ** i)
    return None

def _requests_get_json(url, timeout=15, retry=3, backoff=1.8):
    for i in range(retry):
        try:
            res = requests.get(url, timeout=timeout)
            if res.status_code == 200:
                return res.json()
        except Exception:
            pass
        if i < retry - 1:
            time.sleep(backoff ** i)
    return None

# =========================
# 天気アイコン
# =========================
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
    today_str = datetime.now(JST).strftime("%Y%m%d")
    url = f"https://www.jma.go.jp/bosai/amedas/data/point/{amedas_code}/{today_str}_1h.json"
    data = _urlopen_json(url, timeout=10, retry=3, backoff=1.7)
    if not data:
        return None

    temps = []
    for _, vals in data.items():
        if isinstance(vals, dict) and "temp" in vals and vals["temp"][0] is not None:
            temps.append(vals["temp"][0])
    if temps:
        return {"max": max(temps), "min": min(temps)}
    return None

# =========================
# JMA 予報（従来のdaily_db構造を維持）
# =========================
def get_jma_forecast_data(area_code):
    forecast_url = f"https://www.jma.go.jp/bosai/forecast/data/forecast/{area_code}.json"
    warning_url = f"https://www.jma.go.jp/bosai/warning/data/warning/{area_code}.json"

    daily_db = {}

    data = _urlopen_json(forecast_url, timeout=15, retry=3, backoff=1.8)
    if data:
        try:
            # 詳細（data[0]）
            ts_weather = data[0]["timeSeries"][0]
            codes = ts_weather["areas"][0]["weatherCodes"]
            dates_w = ts_weather["timeDefines"]
            for i, d in enumerate(dates_w):
                date_key = d.split("T")[0]
                daily_db.setdefault(date_key, {})
                daily_db[date_key]["code"] = codes[i]

            # 降水確率（細かい時間帯のpopsが入る）
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
                w_pops = weekly[0]["areas"][0]["pops"]
                w_min = weekly[1]["areas"][0]["tempsMin"]
                w_max = weekly[1]["areas"][0]["tempsMax"]

                for i, d in enumerate(dates_wk):
                    date_key = d.split("T")[0]
                    daily_db.setdefault(date_key, {})
                    daily_db[date_key].setdefault("code", w_codes[i])

                    if i < len(w_pops) and w_pops[i] != "-":
                        daily_db[date_key].setdefault("rain_raw", [w_pops[i]])

                    tmin = w_min[i] if i < len(w_min) and w_min[i] != "" else None
                    tmax = w_max[i] if i < len(w_max) and w_max[i] != "" else None
                    if tmin is not None or tmax is not None:
                        daily_db[date_key]["temp_summary"] = {"min": tmin, "max": tmax}
        except Exception as e:
            print(f"JMA Parse Error ({area_code}): {e}")

    warning_text = "特になし"
    w_data = _urlopen_json(warning_url, timeout=8, retry=2, backoff=1.6)
    if w_data and isinstance(w_data, dict) and "warnings" in w_data:
        for w in w_data.get("warnings", []):
            if w.get("status") not in ["発表なし", "解除"]:
                warning_text = "気象警報・注意報 発表中"
                break

    return daily_db, warning_text

# =========================
# Open-Meteo（時間帯別の気温/湿度/降水確率/天気コード）
# =========================
def fetch_openmeteo_hourly(lat, lon, days=7):
    """
    Open-Meteoからhourlyを取得（無料/キー不要）
    取得項目: temperature_2m, relative_humidity_2m, precipitation_probability, weathercode
    """
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={lat}&longitude={lon}"
        "&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,weathercode"
        "&timezone=Asia%2FTokyo"
        f"&forecast_days={days}"
    )
    return _requests_get_json(url, timeout=15, retry=3, backoff=1.8)

def build_openmeteo_daily_summary(openmeteo_json, target_date):
    """
    Open-Meteoから日次概況（最高/最低/降水確率最大/代表天気）を作成。
    都市分割エリアの「体感差」対策として日次カードにも使える。
    """
    if not openmeteo_json:
        return None

    hourly = openmeteo_json.get("hourly", {})
    times = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    pops = hourly.get("precipitation_probability", [])
    wcodes = hourly.get("weathercode", [])

    date_str = target_date.strftime("%Y-%m-%d")
    idxs = [i for i, t in enumerate(times) if t.startswith(date_str)]
    if not idxs:
        return None

    tvals = []
    pvals = []
    rep_idx = None
    rep_diff = 999

    for i in idxs:
        # 代表は15時付近優先
        try:
            hh = int(times[i].split("T")[1].split(":")[0])
            d = abs(hh - 15)
            if d < rep_diff:
                rep_diff = d
                rep_idx = i
        except:
            pass

        try:
            tvals.append(float(temps[i]))
        except:
            pass
        try:
            pvals.append(int(pops[i]))
        except:
            pass

    if not tvals:
        return None

    high = round(max(tvals))
    low = round(min(tvals))
    rain = f"{max(pvals)}%" if pvals else "-"

    wcode_val = None
    if rep_idx is not None:
        try:
            wcode_val = int(wcodes[rep_idx])
        except:
            wcode_val = None

    emoji = get_weather_emoji_openmeteo(wcode_val) if wcode_val is not None else "☁️"

    return {
        "condition": emoji,
        "high": high,
        "low": low,
        "rain": rain,
        "wcode": wcode_val,
    }

def build_slot_weather(openmeteo_json, target_date):
    """
    target_dateの日付に対して、朝/昼/夜の代表値を作る
    - temp: 9時/15時/21時付近（なければ平均）
    - humidity: 同様
    - rain: precipitation_probability の最大（リスク表現）
    - emoji: weathercode から
    """
    if not openmeteo_json:
        return None

    hourly = openmeteo_json.get("hourly", {})
    times = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    hums = hourly.get("relative_humidity_2m", [])
    pops = hourly.get("precipitation_probability", [])
    wcodes = hourly.get("weathercode", [])

    date_str = target_date.strftime("%Y-%m-%d")
    idxs = [i for i, t in enumerate(times) if t.startswith(date_str)]
    if not idxs:
        return None

    hours = []
    for i in idxs:
        try:
            hh = int(times[i].split("T")[1].split(":")[0])
            hours.append(hh)
        except:
            hours.append(None)

    def slot_pack(start_h, end_h, prefer_hour):
        ids = [idxs[i] for i in range(len(idxs)) if hours[i] is not None and start_h <= hours[i] < end_h]
        if not ids:
            return {"weather": "☁️", "temp": "-", "humidity": "-", "rain": "-", "wcode": None}

        # prefer時刻付近の代表を取る
        k_rep = None
        best = None
        for k in ids:
            try:
                hh = int(times[k].split("T")[1].split(":")[0])
                d = abs(hh - prefer_hour)
                if best is None or d < best:
                    best = d
                    k_rep = k
            except:
                pass

        temp_val = None
        hum_val = None
        wcode_val = None

        if k_rep is not None:
            try:
                temp_val = round(float(temps[k_rep]))
            except:
                temp_val = None
            try:
                hum_val = int(round(float(hums[k_rep])))
            except:
                hum_val = None
            try:
                wcode_val = int(wcodes[k_rep])
            except:
                wcode_val = None

        # fallback: 平均
        if temp_val is None:
            tv = []
            for k in ids:
                try:
                    tv.append(float(temps[k]))
                except:
                    pass
            if tv:
                temp_val = round(sum(tv) / len(tv))

        if hum_val is None:
            hv = []
            for k in ids:
                try:
                    hv.append(float(hums[k]))
                except:
                    pass
            if hv:
                hum_val = int(round(sum(hv) / len(hv)))

        # rain: 最大
        rv = []
        for k in ids:
            try:
                rv.append(int(pops[k]))
            except:
                pass
        rain_max = max(rv) if rv else None

        emoji = get_weather_emoji_openmeteo(wcode_val) if wcode_val is not None else "☁️"

        return {
            "weather": emoji,
            "temp": f"{temp_val}℃" if temp_val is not None else "-",
            "humidity": f"{hum_val}%" if hum_val is not None else "-",
            "rain": f"{rain_max}%" if rain_max is not None else "-",
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
        if i < retry - 1:
            time.sleep(backoff ** i)
    return None

def call_gemini_search(prompt):
    """GoogleSearch tool を使ってテキスト取得"""
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
    """JSON出力（検索ツールなし）"""
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
# 7日分のEvent/Trafficを「1回の検索」でまとめて取る
# =========================
def fetch_event_traffic_7days(area_name):
    """
    各エリアにつき、検索は1回で7日分のイベント/交通を拾う。
    返り値: dict[YYYY-MM-DD] = "箇条書きテキスト"
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
"""
    # 検索失敗時は軽くリトライ（検索は重いので控えめ）
    text = None
    for _ in range(2):
        text = call_gemini_search(search_prompt)
        if text:
            break
        time.sleep(2)

    if not text:
        return {d: "特段の検索結果なし" for d in dates}

    json_prompt = f"""
次の文章を解析して、期間内7日分を必ず埋めたJSONに変換してください。
キーは日付(YYYY-MM-DD)、値はその日のEvent/Traffic要約（箇条書き文字列、改行OK）。
期間: {dates[0]} から {dates[-1]}
文章:
{text}

出力はこのJSONのみ:
{{
  "{dates[0]}": "...",
  ...
  "{dates[-1]}": "..."
}}
"""
    jtxt = None
    for _ in range(2):
        jtxt = call_gemini_json(json_prompt)
        if jtxt:
            break
        time.sleep(2)

    if not jtxt:
        return {d: "特段の検索結果なし" for d in dates}

    try:
        j = json.loads(extract_json_block(jtxt))
        for d in dates:
            j.setdefault(d, "特段の検索結果なし")
        return j
    except:
        return {d: "特段の検索結果なし" for d in dates}

def make_event_traffic_facts(text, limit=8):
    """
    Event/Traffic文章から、UIで使える「重要事実」箇条書きを抽出。
    """
    if not text or not isinstance(text, str):
        return []

    lines = []
    for raw in text.split("\n"):
        s = raw.strip()
        if not s:
            continue
        # 箇条書きっぽいものを優先
        if s.startswith(("・", "-", "•", "＊", "*")):
            s = s.lstrip("・-•＊* ").strip()
        # 見出しっぽいのは除外
        if s in ("不明", "特段の検索結果なし"):
            continue
        if len(s) < 6:
            continue
        lines.append(s)

    # 重複排除（ざっくり）
    uniq = []
    seen = set()
    for s in lines:
        k = re.sub(r"\s+", "", s)
        if k in seen:
            continue
        seen.add(k)
        uniq.append(s)

    return uniq[:limit]

# =========================
# 気温（最高/最低）を決定（JMA + AMeDAS補正 / 都市分割はOpen-Meteo優先）
# =========================
def decide_high_low(area_key, area_data, target_date, jma_day_data, is_today, om_daily):
    """
    高/低:
      - 都市分割: Open-Meteo日次優先（体感差対策）
      - それ以外: JMA(週間temp_summary→temp_raw補完) 優先
      - 今日だけ: AMeDAS実測で補正
    """
    high_val = None
    low_val = None

    prefer_openmeteo = (area_key in URBAN_SPLIT_AREAS)

    # 1) Open-Meteo優先（都市分割）
    if prefer_openmeteo and om_daily:
        high_val = om_daily.get("high")
        low_val = om_daily.get("low")

    # 2) JMAベース
    summary = jma_day_data.get("temp_summary", {}) if jma_day_data else {}
    if high_val is None:
        high_val = summary.get("max")
    if low_val is None:
        low_val = summary.get("min")

    # temp_raw補完
    t_raw = jma_day_data.get("temp_raw", []) if jma_day_data else []
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

    # 3) 今日のみ: AMeDASで補正（最高/最低）
    if is_today:
        amedas_stats = get_amedas_daily_stats(area_data.get("amedas_code", ""))
        if amedas_stats:
            actual_min = amedas_stats["min"]
            actual_max = amedas_stats["max"]
            if low_val is None or (float(low_val) > actual_min):
                low_val = actual_min
            if high_val is None or (actual_max > float(high_val)):
                high_val = actual_max

    str_high = f"{round(float(high_val))}" if high_val is not None else "-"
    str_low = f"{round(float(low_val))}" if low_val is not None else "-"
    return str_high, str_low

def decide_rain_display(area_key, jma_day_data, om_daily):
    """
    降水確率の代表:
      - 都市分割: Open-Meteo日次優先
      - それ以外: JMA rain_raw のmax
      - 欠けたらある方
    """
    prefer_openmeteo = (area_key in URBAN_SPLIT_AREAS)

    jma_val = "-"
    r_raw = jma_day_data.get("rain_raw", []) if jma_day_data else []
    if r_raw:
        try:
            vals = [int(x) for x in r_raw if x not in ("-", "", None)]
            if vals:
                jma_val = f"{max(vals)}%"
        except:
            pass

    om_val = "-"
    if om_daily and om_daily.get("rain") and om_daily.get("rain") != "-":
        om_val = om_daily.get("rain")

    if prefer_openmeteo:
        return om_val if om_val != "-" else jma_val
    else:
        return jma_val if jma_val != "-" else om_val

def decide_overview_condition(area_key, jma_day_data, om_daily):
    """
    日次カードの天気アイコン:
      - 都市分割: Open-Meteo優先
      - それ以外: JMA優先
    """
    jma_code = (jma_day_data or {}).get("code", "200")
    jma_emoji = get_weather_emoji_jma(jma_code)

    om_emoji = om_daily.get("condition") if om_daily else None

    if area_key in URBAN_SPLIT_AREAS and om_emoji:
        return om_emoji, {"jma_code": jma_code, "openmeteo_wcode": om_daily.get("wcode")}
    return jma_emoji, {"jma_code": jma_code, "openmeteo_wcode": om_daily.get("wcode") if om_daily else None}

# =========================
# 休日判定（長期ランク用）
# =========================
def base_rank_for_date(target_date):
    date_str = target_date.strftime("%Y-%m-%d")
    rank = "C"
    if target_date.weekday() in (4, 5):
        rank = "B"
    if date_str in HOLIDAYS_2026:
        rank = "B"
    next_day = (target_date + timedelta(days=1)).strftime("%Y-%m-%d")
    if next_day in HOLIDAYS_2026:
        rank = "B"
    return rank

# =========================
# AI生成（1日ぶん：5職業×朝昼夜）
# =========================
JOB_KEYS = ["taxi", "delivery", "restaurant", "retail", "hotel"]

def generate_ai_day(
    area_key,
    area_data,
    target_date,
    jma_day_data,
    warning_text,
    slot_weather,
    om_daily,
    event_traffic_text
):
    """
    1日分のJSONを一発で生成（検索はしない）
    - timelineの weather/temp/humidity/rain を時間帯ごとに別にセット
    - adviceは taxi/delivery/restaurant/retail/hotel で分ける
    - レポート欄は「Event&Traffic」「総括」のみ（職業別の打ち手は別フィールドへ）
    """
    if not API_KEY:
        return None

    date_str = target_date.strftime("%Y-%m-%d")
    date_display = target_date.strftime("%m月%d日")
    weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
    full_date = f"{date_display} ({weekday_str})"

    today_dt = datetime.now(JST)
    is_today = (target_date.date() == today_dt.date())

    # 日次概況（条件/高低/降水）
    condition_emoji, code_info = decide_overview_condition(area_key, jma_day_data or {}, om_daily)
    high, low = decide_high_low(area_key, area_data, target_date, jma_day_data or {}, is_today=is_today, om_daily=om_daily)
    rain_display = decide_rain_display(area_key, jma_day_data or {}, om_daily)

    # 時間帯天気（Open-Meteo）
    if not slot_weather:
        slot_weather = {
            "morning": {"weather": condition_emoji, "temp": "-", "humidity": "-", "rain": rain_display, "wcode": None},
            "daytime": {"weather": condition_emoji, "temp": "-", "humidity": "-", "rain": rain_display, "wcode": None},
            "night": {"weather": condition_emoji, "temp": "-", "humidity": "-", "rain": rain_display, "wcode": None},
        }

    # UI用 重要事実
    facts_list = make_event_traffic_facts(event_traffic_text, limit=8)

    data_sources = {
        "warning": "JMA",
        "overview": "Open-Meteo (urban split)" if area_key in URBAN_SPLIT_AREAS else "JMA(+AMeDAS today)",
        "today_temp_correction": "AMeDAS (today only)",
        "time_slots": "Open-Meteo",
        "event_traffic": "Gemini+GoogleSearch",
        "notes": "Urban split areas prioritize Open-Meteo for daily overview to reduce intra-city mismatch."
    }

    # AIに渡す“事実セット”（短く・ブレない）
    facts = f"""
[Area]
{area_data['name']}
特徴: {area_data.get('feature','')}

[Date]
{date_str} / {full_date}

[Weather Overview]
天気: {condition_emoji}
最高: {high}℃ / 最低: {low}℃
降水確率(代表): {rain_display}
警報注意報: {warning_text}

[Time Slots Weather]
朝(06-12): {slot_weather['morning']['weather']} / 気温 {slot_weather['morning']['temp']} / 湿度 {slot_weather['morning']['humidity']} / 降水確率 {slot_weather['morning']['rain']}
昼(12-18): {slot_weather['daytime']['weather']} / 気温 {slot_weather['daytime']['temp']} / 湿度 {slot_weather['daytime']['humidity']} / 降水確率 {slot_weather['daytime']['rain']}
夜(18-24): {slot_weather['night']['weather']} / 気温 {slot_weather['night']['temp']} / 湿度 {slot_weather['night']['humidity']} / 降水確率 {slot_weather['night']['rain']}

[Event & Traffic Facts]
{event_traffic_text}
"""

    # 意思決定テンプレ（固定でブレ抑制）
    prompt = f"""
あなたは世界トップクラスの戦略コンサルタントです。
以下の事実セットから、5つの職業（taxi/delivery/restaurant/retail/hotel）向けに、
「その職業の今日の意思決定が変わる」具体的な提案を作ってください。

【重要ルール】
- フェイク禁止。事実セットにない固有名詞は勝手に作らない。
- 曖昧な場合は「未確認」「可能性」と明記。
- 命令口調禁止（〜すべき禁止、〜するとよいでしょう などはOK）
- 結論ファースト。短く明確に。
- ランク判定: 平日は原則B/C寄り。ただし大規模イベント/深刻な交通麻痺が明確ならA/Sも可。

【出力はJSONのみ】
次のスキーマで出力せよ。

{{
  "date": "{full_date}",
  "is_long_term": false,
  "rank": "S/A/B/C",
  "weather_overview": {{
    "condition": "{condition_emoji}",
    "high": "最高{high}℃",
    "low": "最低{low}℃",
    "rain": "{rain_display}",
    "warning": "{warning_text}"
  }},
  "today_action": "今日の一手（提案）を1〜2行で。箇条書きでも可。職業は明示しない短文も可。",
  "event_traffic_facts": ["重要事実の箇条書き（最大8本）"],
  "job_actions": {{
    "taxi": "タクシーの今日の打ち手（短文）",
    "delivery": "配送の今日の打ち手（短文）",
    "restaurant": "飲食の今日の打ち手（短文）",
    "retail": "小売の今日の打ち手（短文）",
    "hotel": "ホテル観光の今日の打ち手（短文）"
  }},
  "peak_windows": {{
    "taxi": "ピーク時間（例: 07-10 / 18-22 など短く）",
    "delivery": "ピーク時間（短く）",
    "restaurant": "ピーク時間（短く）",
    "retail": "ピーク時間（短く）",
    "hotel": "ピーク時間（短く）"
  }},
  "daily_schedule_and_impact": "【{date_display}のレポート】\\n\\n**■Event & Traffic**\\n(事実セットのEvent&Trafficを要約)\\n\\n**■総括**\\n(地域全体の読み)",
  "timeline": {{
    "morning": {{
      "weather": "{slot_weather['morning']['weather']}",
      "temp": "{slot_weather['morning']['temp']}",
      "humidity": "{slot_weather['morning']['humidity']}",
      "rain": "{slot_weather['morning']['rain']}",
      "advice": {{
        "taxi": "...",
        "delivery": "...",
        "restaurant": "...",
        "retail": "...",
        "hotel": "..."
      }}
    }},
    "daytime": {{
      "weather": "{slot_weather['daytime']['weather']}",
      "temp": "{slot_weather['daytime']['temp']}",
      "humidity": "{slot_weather['daytime']['humidity']}",
      "rain": "{slot_weather['daytime']['rain']}",
      "advice": {{
        "taxi": "...",
        "delivery": "...",
        "restaurant": "...",
        "retail": "...",
        "hotel": "..."
      }}
    }},
    "night": {{
      "weather": "{slot_weather['night']['weather']}",
      "temp": "{slot_weather['night']['temp']}",
      "humidity": "{slot_weather['night']['humidity']}",
      "rain": "{slot_weather['night']['rain']}",
      "advice": {{
        "taxi": "...",
        "delivery": "...",
        "restaurant": "...",
        "retail": "...",
        "hotel": "..."
      }}
    }}
  }},
  "confidence": 0
}}

【事実セット】
{facts}
"""

    res = call_gemini_json(prompt)
    if not res:
        return None

    try:
        j = json.loads(extract_json_block(res))

        # safety: 欠けてたら埋める（既存アプリ互換を守る）
        j.setdefault("date", full_date)
        j.setdefault("is_long_term", False)
        j.setdefault("rank", "C")
        j.setdefault("weather_overview", {
            "condition": condition_emoji,
            "high": f"最高{high}℃",
            "low": f"最低{low}℃",
            "rain": rain_display,
            "warning": warning_text
        })
        j.setdefault("daily_schedule_and_impact", f"【{date_display}のレポート】\n\n**■Event & Traffic**\n{event_traffic_text}\n\n**■総括**\n未確認情報が多い場合は慎重な運用を。")
        j.setdefault("timeline", slot_weather)
        j.setdefault("confidence", 0)

        # 追加フィールド（互換を壊さない）
        j.setdefault("data_sources", data_sources)
        j.setdefault("event_traffic_facts", facts_list)

        # job_actions/peak_windows/today_action の最低保証
        j.setdefault("today_action", "")
        j.setdefault("job_actions", {k: "" for k in JOB_KEYS})
        j.setdefault("peak_windows", {k: "" for k in JOB_KEYS})

        # コード情報を残す（デバッグ/説明用）
        j.setdefault("debug_codes", code_info)

        return j
    except:
        return None

# =========================
# 長期（8日目以降）は従来通りテキスト（AI検索はしない）
# =========================
def get_long_term_text_safe(area_name):
    prompt = f"""
エリア: {area_name}
向こう3ヶ月の気象傾向とイベントをGoogle検索し、
「〜でしょう。」「〜が予定されています。」という自然な日本語の文章でまとめて。
JSON形式や辞書形式の出力は禁止。読みやすいMarkdownテキストのみ出力せよ。
"""
    res = None
    for _ in range(2):
        res = call_gemini_search(prompt)
        if res:
            break
        time.sleep(2)
    if not res:
        return "長期予報データの取得に失敗しました。平年並みの傾向を参考にしてください。"
    return res

def get_smart_forecast(target_date, long_term_text):
    date_display = target_date.strftime("%m月%d日")
    weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
    full_date = f"{date_display} ({weekday_str})"

    rank = base_rank_for_date(target_date)

    return {
        "date": full_date,
        "is_long_term": True,
        "rank": rank,
        "weather_overview": {"condition": "☁️", "high": "-", "low": "-", "rain": "-", "warning": "-"},
        "daily_schedule_and_impact": f"【{date_display}の長期予測】\n\n**■Event & Traffic**\n詳細は直近の予測をご確認ください。\n\n**■長期傾向**\n{long_term_text}",
        "timeline": None,
        "confidence": 0,
        "data_sources": {"long_term": "Gemini+GoogleSearch (coarse)"}
    }

# =========================
# エリア単位の処理（取得失敗時もエリア単位でリトライ）
# =========================
def process_single_area(item):
    area_key, area_data = item
    print(f"\n📍 {area_data['name']} 開始", flush=True)

    # 1) 予報（JMA） - 空ならリトライ
    daily_db, warning_text = {}, "特になし"
    for attempt in range(2):
        daily_db, warning_text = get_jma_forecast_data(area_data["jma_code"])
        if daily_db:
            break
        time.sleep(2 ** attempt)

    # 2) 時間帯別（Open-Meteo）
    om = None
    for attempt in range(2):
        om = fetch_openmeteo_hourly(area_data["lat"], area_data["lon"], days=AI_DAYS)
        if om:
            break
        time.sleep(2 ** attempt)

    # 3) 7日分のEvent&Traffic（検索は重いので軽リトライ）
    facts_by_date = fetch_event_traffic_7days(area_data["name"])

    # 4) 長期テキスト
    long_term_text = get_long_term_text_safe(area_data["name"])

    area_forecasts = []
    today_dt = datetime.now(JST)

    for i in range(RUN_DAYS):
        target_date = (today_dt + timedelta(days=i))
        date_key = target_date.strftime("%Y-%m-%d")

        if i < AI_DAYS:
            day_data = daily_db.get(date_key, {})
            slot_weather = build_slot_weather(om, target_date) if om else None
            om_daily = build_openmeteo_daily_summary(om, target_date) if om else None

            et_text = facts_by_date.get(date_key, "特段の検索結果なし")

            print(f"🤖 {area_data['name']} / {date_key} ", end="", flush=True)
            data = generate_ai_day(
                area_key=area_key,
                area_data=area_data,
                target_date=target_date,
                jma_day_data=day_data,
                warning_text=warning_text,
                slot_weather=slot_weather,
                om_daily=om_daily,
                event_traffic_text=et_text
            )
            if data:
                print("OK", flush=True)
                area_forecasts.append(data)
            else:
                print("NG → long_term fallback", flush=True)
                area_forecasts.append(get_smart_forecast(target_date, long_term_text))
        else:
            area_forecasts.append(get_smart_forecast(target_date, long_term_text))

    print(f"✅ {area_data['name']} 完了", flush=True)
    return area_key, area_forecasts

# =========================
# main
# =========================
if __name__ == "__main__":
    today = datetime.now(JST)
    print(f"🦅 Eagle Eye v5.1 (Retry+UrbanSplitOM+Jobs5+Facts+Peak) 起動: {today.strftime('%Y/%m/%d %H:%M')}", flush=True)

    master_data = {}
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = [executor.submit(process_single_area, item) for item in TARGET_AREAS.items()]
        for future in as_completed(futures):
            try:
                key, data = future.result()
                master_data[key] = data
            except Exception as e:
                print(f"Err: {e}", flush=True)

    with open("eagle_eye_data.json", "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)

    print("\n✅ 全工程完了", flush=True)
