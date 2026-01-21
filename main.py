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

# --- 戦略的30地点定義 (JMAコード: 一次細分区域 XX0000 形式に完全修正) ---
TARGET_AREAS = {
    # --- 北海道・東北 ---
    "hakodate": { "name": "北海道 函館", "jma_code": "014100", "lat": 41.7687, "lon": 140.7288, "feature": "観光・夜景・海鮮。冬は雪の影響大。クルーズ船寄港地。" },
    "sapporo": { "name": "北海道 札幌", "jma_code": "016000", "lat": 43.0618, "lon": 141.3545, "feature": "北日本最大の歓楽街ススキノ。雪まつり等のイベント。" },
    "sendai": { "name": "宮城 仙台", "jma_code": "040000", "lat": 38.2682, "lon": 140.8694, "feature": "東北のビジネス拠点。国分町の夜間需要。" },
    # --- 東京・関東 (東京は130000) ---
    "tokyo_marunouchi": { "name": "東京 丸の内・東京駅", "jma_code": "130000", "lat": 35.6812, "lon": 139.7671, "feature": "日本のビジネス中心地。出張・接待・富裕層需要。" },
    "tokyo_ginza": { "name": "東京 銀座・新橋", "jma_code": "130000", "lat": 35.6701, "lon": 139.7630, "feature": "夜の接待需要とサラリーマンの聖地。高級店多し。" },
    "tokyo_shinjuku": { "name": "東京 新宿・歌舞伎町", "jma_code": "130000", "lat": 35.6914, "lon": 139.7020, "feature": "世界一の乗降客数と眠らない街。タクシー需要最強。" },
    "tokyo_shibuya": { "name": "東京 渋谷・原宿", "jma_code": "130000", "lat": 35.6580, "lon": 139.7016, "feature": "若者とインバウンド、IT企業の街。トレンド発信地。" },
    "tokyo_roppongi": { "name": "東京 六本木・赤坂", "jma_code": "130000", "lat": 35.6641, "lon": 139.7336, "feature": "富裕層、外国人、メディア関係者の夜の移動。" },
    "tokyo_ikebukuro": { "name": "東京 池袋", "jma_code": "130000", "lat": 35.7295, "lon": 139.7109, "feature": "埼玉方面への玄関口、サブカルチャー。" },
    "tokyo_shinagawa": { "name": "東京 品川・高輪", "jma_code": "130000", "lat": 35.6285, "lon": 139.7397, "feature": "リニア・新幹線拠点。ホテルとビジネス需要。" },
    "tokyo_ueno": { "name": "東京 上野", "jma_code": "130000", "lat": 35.7141, "lon": 139.7741, "feature": "北の玄関口、美術館、アメ横。観光客多し。" },
    "tokyo_asakusa": { "name": "東京 浅草", "jma_code": "130000", "lat": 35.7119, "lon": 139.7983, "feature": "インバウンド観光の絶対王者。人力車や食べ歩き。" },
    "tokyo_akihabara": { "name": "東京 秋葉原・神田", "jma_code": "130000", "lat": 35.6983, "lon": 139.7731, "feature": "オタク文化とビジネスの融合。電気街。" },
    "tokyo_omotesando": { "name": "東京 表参道・青山", "jma_code": "130000", "lat": 35.6652, "lon": 139.7123, "feature": "ファッション、富裕層のランチ・買い物需要。" },
    "tokyo_ebisu": { "name": "東京 恵比寿・代官山", "jma_code": "130000", "lat": 35.6467, "lon": 139.7101, "feature": "オシャレな飲食需要、タクシー利用率高め。" },
    "tokyo_odaiba": { "name": "東京 お台場・有明", "jma_code": "130000", "lat": 35.6278, "lon": 139.7745, "feature": "ビッグサイトのイベント、観光、デートスポット。" },
    "tokyo_toyosu": { "name": "東京 豊洲・湾岸", "jma_code": "130000", "lat": 35.6568, "lon": 139.7960, "feature": "タワマン住民の生活需要と市場関係。" },
    "tokyo_haneda": { "name": "東京 羽田空港エリア", "jma_code": "130000", "lat": 35.5494, "lon": 139.7798, "feature": "旅行・出張客の送迎需要。天候による遅延影響。" },
    "chiba_maihama": { "name": "千葉 舞浜(ディズニー)", "jma_code": "120000", "lat": 35.6329, "lon": 139.8804, "feature": "ディズニーリゾート。イベントと天候への依存度極大。" },
    "kanagawa_yokohama": { "name": "神奈川 横浜", "jma_code": "140000", "lat": 35.4437, "lon": 139.6380, "feature": "みなとみらい観光とビジネスが融合。中華街。" },
    # --- 中部 ---
    "aichi_nagoya": { "name": "愛知 名古屋", "jma_code": "230000", "lat": 35.1815, "lon": 136.9066, "feature": "トヨタ系ビジネスと独自の飲食文化。車社会。" },
    # --- 関西 ---
    "osaka_kita": { "name": "大阪 キタ (梅田)", "jma_code": "270000", "lat": 34.7025, "lon": 135.4959, "feature": "西日本最大のビジネス街兼繁華街。地下街発達。" },
    "osaka_minami": { "name": "大阪 ミナミ (難波)", "jma_code": "270000", "lat": 34.6655, "lon": 135.5011, "feature": "インバウンド人気No.1。食い倒れの街。" },
    "osaka_hokusetsu": { "name": "大阪 北摂", "jma_code": "270000", "lat": 34.7809, "lon": 135.4624, "feature": "伊丹空港/新幹線・ビジネス・高級住宅街。" },
    "osaka_bay": { "name": "大阪 ベイエリア(USJ)", "jma_code": "270000", "lat": 34.6654, "lon": 135.4323, "feature": "USJや海遊館。海風強くイベント依存度高い。" },
    "osaka_tennoji": { "name": "大阪 天王寺・阿倍野", "jma_code": "270000", "lat": 34.6477, "lon": 135.5135, "feature": "ハルカス/通天閣。新旧文化の融合。" },
    "kyoto_shijo": { "name": "京都 四条河原町", "jma_code": "260000", "lat": 35.0037, "lon": 135.7706, "feature": "世界最強の観光都市。インバウンド需要が桁違い。" },
    "hyogo_kobe": { "name": "兵庫 神戸(三宮)", "jma_code": "280000", "lat": 34.6946, "lon": 135.1956, "feature": "オシャレな港町。観光とビジネス。" },
    # --- 中国・九州・沖縄 ---
    "hiroshima": { "name": "広島", "jma_code": "340000", "lat": 34.3853, "lon": 132.4553, "feature": "平和公園・宮島。欧米系インバウンド多い。" },
    "fukuoka": { "name": "福岡 博多・中洲", "jma_code": "400000", "lat": 33.5902, "lon": 130.4017, "feature": "アジアの玄関口。屋台文化など夜の需要が強い。" },
    "okinawa_naha": { "name": "沖縄 那覇", "jma_code": "471000", "lat": 26.2124, "lon": 127.6809, "feature": "国際通り。観光客メイン。台風等の天候影響大。" },
}

# --- 天気予報コード変換ロジック (JMA/OpenMeteo共通化) ---
def get_weather_emoji(code):
    try:
        c = int(code)
        # JMA Codes
        if c in [100, 101, 123, 124]: return "☀️"
        if c in [102, 103, 104, 105, 106, 107, 108, 110, 111, 112]: return "🌤️"
        if c in [200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212]: return "☁️"
        if 300 <= c < 400: return "☔"
        if 400 <= c < 500: return "⛄"
        
        # OpenMeteo WMO Codes
        if c == 0: return "☀️"
        if c in [1, 2, 3]: return "🌤️"
        if c in [45, 48]: return "🌫️"
        if c in [51, 53, 55, 61, 63, 65, 80, 81, 82]: return "☔"
        if c in [71, 73, 75, 77, 85, 86]: return "⛄"
        if c >= 95: return "⛈️"
    except: pass
    return "☁️"

# --- データ取得機能 ---

# 1. JMA 詳細予報 (今日・明日) & 週間予報 (明後日-7日後)
def get_jma_full_data(area_code):
    url = f"https://www.jma.go.jp/bosai/forecast/data/forecast/{area_code}.json"
    result = {}
    
    try:
        with urllib.request.urlopen(url, timeout=10) as res:
            data = json.loads(res.read().decode('utf-8'))
            
            # --- 直近詳細 (0:今日, 1:明日) ---
            detailed = data[0]["timeSeries"]
            weathers = detailed[0]["areas"][0]["weatherCodes"]
            pops = detailed[1]["areas"][0]["pops"] # 降水確率
            # 気温 (JMAは不定形な配列のため、全探索してMin/Maxを決める)
            temps_arr = detailed[2]["areas"][0]["temps"]
            
            # 今日
            t_today = [float(t) for t in temps_arr if t != "-"] # 簡易的に全ての数値から
            max_today = max(t_today) if t_today else "-"
            min_today = min(t_today) if t_today else "-"
            
            # 明日 (インデックスが複雑なため、固定値ではなく配列後半を取得)
            # ※簡易実装: 配列の長さで判断
            max_tmr = temps_arr[-1] if len(temps_arr) > 2 else "-"
            min_tmr = temps_arr[2] if len(temps_arr) > 2 else "-"

            result["0"] = {"code": weathers[0], "pop": pops[0] if len(pops)>0 else "-", "high": max_today, "low": min_today}
            if len(weathers) > 1:
                result["1"] = {"code": weathers[1], "pop": pops[1] if len(pops)>1 else "-", "high": max_tmr, "low": min_tmr}

            # --- 週間予報 (2日後 - 6日後) ---
            if len(data) > 1:
                weekly = data[1]["timeSeries"]
                w_codes = weekly[0]["areas"][0]["weatherCodes"]
                w_pops = weekly[0]["areas"][0]["pops"] # 週間天気の降水確率
                w_temps_min = weekly[1]["areas"][0]["tempsMin"]
                w_temps_max = weekly[1]["areas"][0]["tempsMax"]
                
                for i in range(len(w_codes)):
                    day_idx = i + 1 # JMA週間は明日or明後日から始まることが多い
                    # 直近と重複しないよう調整（今回は簡易的にリスト追加）
                    k = str(day_idx + 1) # おおよそ2日後以降
                    if k not in result:
                        result[k] = {
                            "code": w_codes[i], 
                            "pop": w_pops[i] if i < len(w_pops) else "-",
                            "high": w_temps_max[i] if i < len(w_temps_max) else "-",
                            "low": w_temps_min[i] if i < len(w_temps_min) else "-"
                        }

    except Exception as e:
        print(f"JMA Error ({area_code}): {e}")
    
    return result

# 2. JMA 注意報・警報
def get_jma_warning(area_code):
    url = f"https://www.jma.go.jp/bosai/warning/data/warning/{area_code}.json"
    try:
        with urllib.request.urlopen(url, timeout=5) as res:
            data = json.loads(res.read().decode('utf-8'))
            if "headlineText" in data and data["headlineText"]:
                return data["headlineText"]
    except: pass
    return "特になし"

# 3. Open-Meteo 長期予報 (8日後 - 90日後)
# ※無料版Forecast APIは16日が限界だが、Climate統計の代わりにこれを使うのが現実的
# ※16日以降は「平年並み」として、直近の傾向を繰り返す簡易ロジックで代用
def get_open_meteo_forecast(lat, lon):
    url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=Asia%2FTokyo&forecast_days=16"
    result = {}
    try:
        res = requests.get(url, timeout=10)
        if res.status_code == 200:
            d = res.json()["daily"]
            for i in range(len(d["time"])):
                date_str = d["time"][i] # "2026-01-22"
                # 日付差分計算
                dt = datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=JST)
                diff = (dt.date() - datetime.now(JST).date()).days
                
                if diff >= 0:
                    result[str(diff)] = {
                        "code": d["weathercode"][i],
                        "pop": f"{int(d['precipitation_sum'][i]*10)}%", # 降水量から簡易確率へ
                        "high": d["temperature_2m_max"][i],
                        "low": d["temperature_2m_min"][i]
                    }
    except Exception as e:
        print(f"Open-Meteo Error: {e}")
    return result

# --- Gemini API (2段階) ---
def call_gemini_search(prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}"
    headers = { "Content-Type": "application/json" }
    payload = {
        "contents": [{ "parts": [{"text": prompt}] }],
        "tools": [{ "googleSearch": {} }],
        "generationConfig": { "temperature": 0.7 }
    }
    try:
        res = requests.post(url, headers=headers, json=payload, timeout=60)
        if res.status_code == 200:
            return res.json()["candidates"][0]["content"]["parts"][0]["text"]
    except: pass
    return None

def call_gemini_json(prompt):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={API_KEY}"
    headers = { "Content-Type": "application/json" }
    payload = {
        "contents": [{ "parts": [{"text": prompt}] }],
        "generationConfig": { "temperature": 0.7, "responseMimeType": "application/json" }
    }
    try:
        res = requests.post(url, headers=headers, json=payload, timeout=60)
        if res.status_code == 200:
            return res.json()["candidates"][0]["content"]["parts"][0]["text"]
    except: pass
    return None

def extract_json_block(text):
    try:
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match: return match.group(0)
    except: pass
    return text

# --- AI生成ロジック ---
def get_ai_advice(area_data, target_date, weather_info, warning):
    if not API_KEY: return None
    
    date_str = target_date.strftime('%m月%d日')
    weekday = ["月","火","水","木","金","土","日"][target_date.weekday()]
    
    w_emoji = get_weather_emoji(weather_info.get("code", 200))
    
    print(f"🤖 [AI] {area_data['name']} / {date_str}...", end="", flush=True)
    
    # 検索
    search_prompt = f"""
    エリア: {area_data['name']}
    日付: 2026年{date_str}
    
    このエリアのイベント、混雑、ニュースを検索し、箇条書きで教えて。
    """
    search_res = call_gemini_search(search_prompt) or "特になし"
    
    # 生成
    json_prompt = f"""
    あなたは戦略コンサルタントです。以下の情報から、各職種への戦略レポートを作成してください。

    【条件】
    エリア: {area_data['name']} ({area_data['feature']})
    日付: {date_str} ({weekday})
    天気: {w_emoji}, 気温{weather_info.get('high')}/{weather_info.get('low')}, 警報:{warning}
    検索情報: {search_res}

    【指令】
    1. **挨拶禁止:** いきなり本題に入れ。
    2. **総括:** 1行でズバリ。「〜のため、需要は〇〇です」。
    3. **戦略:** 「〜してください」ではなく「〜が有効です」「〜を推奨します」という提案口調。
    4. **構成:** Markdownで見やすく（**見出し**など使用）。
    
    【JSON出力】
    {{
        "date": "{date_str} ({weekday})", "rank": "S/A/B/C",
        "weather_overview": {{ "condition": "{w_emoji}", "high": "{weather_info.get('high')}", "low": "{weather_info.get('low')}", "rain": "{weather_info.get('pop')}", "warning": "{warning}" }},
        "daily_schedule_and_impact": "【{date_str}のレポート】\\n\\n**■総括**\\n(総括文)...\\n\\n**■主要因**\\n・(検索結果)...\\n\\n**■推奨戦略**\\n・...", 
        "timeline": {{
            "morning": {{ "weather": "{w_emoji}", "temp": "{weather_info.get('low')}", "rain": "-", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "...", "construction": "...", "delivery": "...", "security": "..." }} }},
            "daytime": {{ "weather": "{w_emoji}", "temp": "{weather_info.get('high')}", "rain": "-", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "...", "construction": "...", "delivery": "...", "security": "..." }} }},
            "night": {{ "weather": "{w_emoji}", "temp": "{weather_info.get('low')}", "rain": "-", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "...", "construction": "...", "delivery": "...", "security": "..." }} }}
        }}
    }}
    """
    
    res_text = call_gemini_json(json_prompt)
    if res_text:
        try:
            return json.loads(extract_json_block(res_text))
        except: pass
    return None

def get_simple_data(target_date, weather_info):
    date_str = target_date.strftime('%m月%d日')
    weekday = ["月","火","水","木","金","土","日"][target_date.weekday()]
    w_emoji = get_weather_emoji(weather_info.get("code", 200))
    
    return {
        "date": f"{date_str} ({weekday})", "rank": "C",
        "weather_overview": { "condition": w_emoji, "high": weather_info.get('high','-'), "low": weather_info.get('low','-'), "rain": "-", "warning": "-" },
        "daily_schedule_and_impact": f"【{date_str}の予報】\n平年並みの傾向です。詳細は直近に更新されます。",
        "timeline": None
    }

# --- メイン処理 ---
if __name__ == "__main__":
    today = datetime.now(JST)
    print(f"🦅 Eagle Eye v1.0 Hybrid Logic 起動: {today.strftime('%Y/%m/%d')}", flush=True)
    
    master_data = {}
    
    for key, area in TARGET_AREAS.items():
        print(f"\n📍 {area['name']}", flush=True)
        
        # 1. データ収集 (JMA + OpenMeteo)
        jma_data = get_jma_full_data(area["jma_code"])
        om_data = get_open_meteo_forecast(area["lat"], area["lon"])
        warning = get_jma_warning(area["jma_code"])
        
        area_forecasts = []
        
        # 90日ループ
        for i in range(90):
            target_date = today + timedelta(days=i)
            idx_str = str(i)
            
            # 天気データのマージ (優先順位: JMA直近 > JMA週間 > OpenMeteo > なし)
            weather_info = {}
            if idx_str in jma_data:
                weather_info = jma_data[idx_str]
            elif idx_str in om_data:
                weather_info = om_data[idx_str]
            else:
                # 16日以降は16日目のデータを使い回す(統計的推論代用)
                weather_info = om_data.get("15", {"code": 200, "high": "-", "low": "-"})

            # AI生成 (直近2日のみ)
            if i < 2:
                data = get_ai_advice(area, target_date, weather_info, warning)
                if data:
                    area_forecasts.append(data)
                    print(" OK")
                    time.sleep(2)
                else:
                    print(" Error->Simple")
                    area_forecasts.append(get_simple_data(target_date, weather_info))
            else:
                area_forecasts.append(get_simple_data(target_date, weather_info))
        
        master_data[key] = area_forecasts

    with open("eagle_eye_data.json", "w", encoding="utf-8") as f:
        json.dump(master_data, f, ensure_ascii=False, indent=2)
    print("\n✅ 全工程完了", flush=True)
