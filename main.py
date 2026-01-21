import os
import json
import time
import urllib.request
import urllib.error
import math
import re
from datetime import datetime, timedelta, timezone
import requests

# --- 設定 ---
API_KEY = os.environ.get("GEMINI_API_KEY")
JST = timezone(timedelta(hours=9), 'JST')

# --- 戦略的30地点定義 ---
TARGET_AREAS = {
    # --- 北海道・東北 ---
    "hakodate": { "name": "北海道 函館", "jma_code": "014100", "feature": "観光・夜景・海鮮。冬は雪の影響大。クルーズ船寄港地。" },
    "sapporo": { "name": "北海道 札幌", "jma_code": "016000", "feature": "北日本最大の歓楽街ススキノ。雪まつり等のイベント。" },
    "sendai": { "name": "宮城 仙台", "jma_code": "040000", "feature": "東北のビジネス拠点。国分町の夜間需要。" },
    # --- 東京・関東 ---
    "tokyo_marunouchi": { "name": "東京 丸の内・東京駅", "jma_code": "130000", "feature": "日本のビジネス中心地。出張・接待・富裕層需要。" },
    "tokyo_ginza": { "name": "東京 銀座・新橋", "jma_code": "130000", "feature": "夜の接待需要とサラリーマンの聖地。高級店多し。" },
    "tokyo_shinjuku": { "name": "東京 新宿・歌舞伎町", "jma_code": "130000", "feature": "世界一の乗降客数と眠らない街。タクシー需要最強。" },
    "tokyo_shibuya": { "name": "東京 渋谷・原宿", "jma_code": "130000", "feature": "若者とインバウンド、IT企業の街。トレンド発信地。" },
    "tokyo_roppongi": { "name": "東京 六本木・赤坂", "jma_code": "130000", "feature": "富裕層、外国人、メディア関係者の夜の移動。" },
    "tokyo_ikebukuro": { "name": "東京 池袋", "jma_code": "130000", "feature": "埼玉方面への玄関口、サブカルチャー。" },
    "tokyo_shinagawa": { "name": "東京 品川・高輪", "jma_code": "130000", "feature": "リニア・新幹線拠点。ホテルとビジネス需要。" },
    "tokyo_ueno": { "name": "東京 上野", "jma_code": "130000", "feature": "北の玄関口、美術館、アメ横。観光客多し。" },
    "tokyo_asakusa": { "name": "東京 浅草", "jma_code": "130000", "feature": "インバウンド観光の絶対王者。人力車や食べ歩き。" },
    "tokyo_akihabara": { "name": "東京 秋葉原・神田", "jma_code": "130000", "feature": "オタク文化とビジネスの融合。電気街。" },
    "tokyo_omotesando": { "name": "東京 表参道・青山", "jma_code": "130000", "feature": "ファッション、富裕層のランチ・買い物需要。" },
    "tokyo_ebisu": { "name": "東京 恵比寿・代官山", "jma_code": "130000", "feature": "オシャレな飲食需要、タクシー利用率高め。" },
    "tokyo_odaiba": { "name": "東京 お台場・有明", "jma_code": "130000", "feature": "ビッグサイトのイベント、観光、デートスポット。" },
    "tokyo_toyosu": { "name": "東京 豊洲・湾岸", "jma_code": "130000", "feature": "タワマン住民の生活需要と市場関係。" },
    "tokyo_haneda": { "name": "東京 羽田空港エリア", "jma_code": "130000", "feature": "旅行・出張客の送迎需要。天候による遅延影響。" },
    "chiba_maihama": { "name": "千葉 舞浜(ディズニー)", "jma_code": "120000", "feature": "ディズニーリゾート。イベントと天候への依存度極大。" },
    "kanagawa_yokohama": { "name": "神奈川 横浜", "jma_code": "140000", "feature": "みなとみらい観光とビジネスが融合。中華街。" },
    # --- 中部 ---
    "aichi_nagoya": { "name": "愛知 名古屋", "jma_code": "230000", "feature": "トヨタ系ビジネスと独自の飲食文化。車社会。" },
    # --- 関西 ---
    "osaka_kita": { "name": "大阪 キタ (梅田)", "jma_code": "270000", "feature": "西日本最大のビジネス街兼繁華街。地下街発達。" },
    "osaka_minami": { "name": "大阪 ミナミ (難波)", "jma_code": "270000", "feature": "インバウンド人気No.1。食い倒れの街。" },
    "osaka_hokusetsu": { "name": "大阪 北摂", "jma_code": "270000", "feature": "伊丹空港/新幹線・ビジネス・高級住宅街。" },
    "osaka_bay": { "name": "大阪 ベイエリア(USJ)", "jma_code": "270000", "feature": "USJや海遊館。海風強くイベント依存度高い。" },
    "osaka_tennoji": { "name": "大阪 天王寺・阿倍野", "jma_code": "270000", "feature": "ハルカス/通天閣。新旧文化の融合。" },
    "kyoto_shijo": { "name": "京都 四条河原町", "jma_code": "260000", "feature": "世界最強の観光都市。インバウンド需要が桁違い。" },
    "hyogo_kobe": { "name": "兵庫 神戸(三宮)", "jma_code": "280000", "feature": "オシャレな港町。観光とビジネス。" },
    # --- 中国・九州・沖縄 ---
    "hiroshima": { "name": "広島", "jma_code": "340000", "feature": "平和公園・宮島。欧米系インバウンド多い。" },
    "fukuoka": { "name": "福岡 博多・中洲", "jma_code": "400000", "feature": "アジアの玄関口。屋台文化など夜の需要が強い。" },
    "okinawa_naha": { "name": "沖縄 那覇", "jma_code": "471000", "feature": "国際通り。観光客メイン。台風等の天候影響大。" },
}

# --- JMA API 取得 ---
def get_jma_forecast(area_code):
    url = f"https://www.jma.go.jp/bosai/forecast/data/forecast/{area_code}.json"
    warning_url = f"https://www.jma.go.jp/bosai/warning/data/warning/{area_code}.json"
    result = {"forecasts": [], "warning": "特になし"}
    
    try:
        with urllib.request.urlopen(url, timeout=15) as res:
            data = json.loads(res.read().decode('utf-8'))
            if not data or "timeSeries" not in data[0]: raise ValueError("JSON invalid")
            
            weather_series = data[0]["timeSeries"][0]
            rain_series = data[0]["timeSeries"][1]
            temp_series = data[0]["timeSeries"][2]
            
            weathers = weather_series["areas"][0].get("weatherCodes", [])
            rains = rain_series["areas"][0].get("pops", [])
            temps = temp_series["areas"][0].get("temps", [])
            
            def get_val(arr, idx): return arr[idx] if len(arr) > idx else "-"
            
            result["forecasts"] = [{
                "code": get_val(weathers, 0),
                "rain_am": get_val(rains, 0),
                "rain_pm": get_val(rains, 1),
                "high": temps[-1] if temps else "-", 
                "low": temps[0] if temps else "-"
            }]
    except:
        result["forecasts"] = [{"code": "200", "rain_am": "-", "rain_pm": "-", "high": "-", "low": "-"}]

    try:
        with urllib.request.urlopen(warning_url, timeout=5) as res:
            w_data = json.loads(res.read().decode('utf-8'))
            if "headlineText" in w_data and w_data["headlineText"]:
                 result["warning"] = w_data["headlineText"]
    except: pass
    return result

def get_weather_emoji_jma(jma_code):
    try:
        code = int(jma_code)
        if code in [100, 101, 123, 124]: return "☀️"
        if code in [102, 103, 104, 105, 106, 107, 108, 110, 111, 112]: return "🌤️"
        if code in [200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212]: return "☁️"
        if 300 <= code < 400: return "☔"
        if 400 <= code < 500: return "⛄"
    except: pass
    return "☁️"

def extract_json_block(text):
    try:
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match: return match.group(0)
        return text
    except: return text

# --- Gemini API (2段階ロジック) ---
def call_gemini_search(prompt):
    """フェーズ1: 検索専用（JSONモードなし）"""
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}"
    headers = { "Content-Type": "application/json" }
    
    payload = {
        "contents": [{ "parts": [{"text": prompt}] }],
        "tools": [{ "googleSearch": {} }], # 検索ON
        "generationConfig": { "temperature": 0.7 } # JSONモードなし
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        if response.status_code == 200:
            data = response.json()
            if "candidates" in data and len(data["candidates"]) > 0:
                return data["candidates"][0]["content"]["parts"][0]["text"]
        return None
    except:
        return None

def call_gemini_json(prompt):
    """フェーズ2: 生成専用（JSONモードあり、検索なし）"""
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}"
    headers = { "Content-Type": "application/json" }
    
    payload = {
        "contents": [{ "parts": [{"text": prompt}] }],
        "generationConfig": {
            "temperature": 0.7,
            "responseMimeType": "application/json" # JSONモードON
        }
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=60)
        if response.status_code == 200:
            data = response.json()
            if "candidates" in data and len(data["candidates"]) > 0:
                return data["candidates"][0]["content"]["parts"][0]["text"]
        return None
    except:
        return None

# --- AI生成メイン処理 ---
def get_ai_advice(area_key, area_data, target_date, jma_data):
    if not API_KEY: return None

    date_str = target_date.strftime('%Y-%m-%d')
    date_display = target_date.strftime('%m月%d日')
    weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
    full_date = f"{date_display} ({weekday_str})"
    
    forecast = jma_data["forecasts"][0]
    w_emoji = get_weather_emoji_jma(forecast.get("code", "200"))
    high_temp = forecast.get("high", "-")
    low_temp = forecast.get("low", "-")
    rain_display = f"午前{forecast.get('rain_am','-')}% / 午後{forecast.get('rain_pm','-')}%"
    warning_text = jma_data.get("warning", "特になし")

    print(f"🤖 [AI] {area_data['name']} / {full_date} ", end="", flush=True)

    # 1. 検索フェーズ
    print("🔍検索...", end="", flush=True)
    search_prompt = f"""
    エリア: {area_data['name']}
    日付: {date_str}
    
    このエリアの、この日のイベント情報、混雑予想、関連ニュースをGoogle検索して、
    箇条書きで詳しく教えてください。
    """
    search_result = call_gemini_search(search_prompt)
    if not search_result: search_result = "検索結果なし。一般的な傾向から推測します。"

    # 2. 生成フェーズ
    print("📝生成...", end="", flush=True)
    json_prompt = f"""
    あなたは戦略経営コンサルタントです。以下の【検索結果】と【気象データ】に基づき、戦略レポートを作成してください。

    【ターゲット】
    エリア: {area_data['name']} ({area_data['feature']})
    日付: {date_str} ({weekday_str})

    【気象データ】
    天気:{w_emoji}, 最高:{high_temp}℃/最低:{low_temp}℃, 降水:{rain_display}, 警報:{warning_text}

    【検索結果（ファクト）】
    {search_result}

    【重要指令】
    1. **挨拶不要:** いきなり分析結果から書け。
    2. **JSON出力:** 以下の形式のみを出力せよ。

    {{
        "date": "{full_date}",
        "is_long_term": false,
        "rank": "S/A/B/C",
        "weather_overview": {{ 
            "condition": "{w_emoji}", 
            "high": "{high_temp}℃", "low": "{low_temp}℃", "rain": "{rain_display}",
            "warning": "{warning_text}"
        }},
        "daily_schedule_and_impact": "【{date_display}のレポート】\\n\\n■市場予測\\n(結論)...\\n\\n■主要因\\n(検索結果から)...\\n\\n■推奨戦略\\n・...", 
        "timeline": {{
            "morning": {{ "weather": "{w_emoji}", "temp": "{low_temp}℃", "rain": "{forecast.get('rain_am','-')}%", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "...", "construction": "...", "delivery": "...", "security": "..." }} }},
            "daytime": {{ "weather": "{w_emoji}", "temp": "{high_temp}℃", "rain": "{forecast.get('rain_pm','-')}%", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "...", "construction": "...", "delivery": "...", "security": "..." }} }},
            "night": {{ "weather": "{w_emoji}", "temp": "{low_temp}℃", "rain": "{forecast.get('rain_pm','-')}%", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "...", "construction": "...", "delivery": "...", "security": "..." }} }}
        }}
    }}
    """
    
    json_text = call_gemini_json(json_prompt)
    if json_text:
        try:
            res = json.loads(extract_json_block(json_text))
            print("OK")
            return res
        except:
            print("JSON Error")
            return None
    
    print("API Error")
    return None

# --- 簡易予測 ---
def get_simple_forecast(target_date):
    date_display = target_date.strftime('%m月%d日')
    weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
    full_date = f"{date_display} ({weekday_str})"
    rank = "C"
    if target_date.weekday() >= 5: rank = "B"
    return {
        "date": full_date, "is_long_term": True, "rank": rank,
        "weather_overview": { "condition": "☁️", "high": "-", "low": "-", "rain": "-", "warning": "-" },
        "daily_schedule_and_impact": f"【{date_display}の傾向（長期予測）】\n詳細なデータは直近になると更新されます。",
        "timeline": None
    }

# --- メイン ---
if __name__ == "__main__":
    today = datetime.now(JST)
    print(f"🦅 Eagle Eye 2段階生成版 起動: {today.strftime('%Y/%m/%d')}", flush=True)
    
    master_data = {}
    
    for area_key, area_data in TARGET_AREAS.items():
        print(f"\n📍 {area_data['name']}", flush=True)
        area_forecasts = []
        jma_data = get_jma_forecast(area_data["jma_code"])
        
        for i in range(90):
            target_date = today + timedelta(days=i)
            if i < 3: 
                data = get_ai_advice(area_key, area_data, target_date, jma_data)
                if data:
                    area_forecasts.append(data)
                    time.sleep(2)
                else:
                    area_forecasts.append(get_simple_forecast(target_date))
            else:
                area_forecasts.append(get_simple_forecast(target_date))
        
        master_data[area_key] = area_forecasts

    if len(master_data) > 0:
        with open("eagle_eye_data.json", "w", encoding="utf-8") as f:
            json.dump(master_data, f, ensure_ascii=False, indent=2)
        print(f"\n✅ 完了", flush=True)
    else:
        exit(1)
