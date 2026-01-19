import os
import json
import time
import urllib.request
from datetime import datetime, timedelta, timezone
import google.generativeai as genai

# --- 設定 ---
API_KEY = os.environ.get("GEMINI_API_KEY")
JST = timezone(timedelta(hours=9), 'JST')

# ★全エリア解放
TARGET_AREAS = {
    "hakodate": {
        "name": "北海道 函館市",
        "lat": 41.7687, "lon": 140.7288,
        "population": 243000,
        "feature": "日本有数の観光都市。夜景と海鮮が人気。異国情緒あふれる街並み。"
    },
    "osaka_hokusetsu": {
        "name": "大阪 北摂 (豊中・新大阪)",
        "lat": 34.7809, "lon": 135.4624,
        "population": 400000,
        "feature": "伊丹空港や新大阪駅があり移動拠点となる。治安が良く落ち着いた住宅街も多い。"
    },
    "osaka_kita": {
        "name": "大阪 キタ (梅田)",
        "lat": 34.7025, "lon": 135.4959,
        "population": 1000000, 
        "feature": "西日本最大のビジネス街兼繁華街。グランフロントや地下街が発達。"
    },
    "osaka_minami": {
        "name": "大阪 ミナミ (難波)",
        "lat": 34.6655, "lon": 135.5011,
        "population": 500000,
        "feature": "インバウンド人気No.1。道頓堀、グリコ、食い倒れの街。夜の需要が高い。"
    },
    "osaka_bay": {
        "name": "大阪 ベイエリア (USJ)",
        "lat": 34.6654, "lon": 135.4323,
        "population": 100000,
        "feature": "USJや海遊館がある海沿いのエリア。風の影響を受けやすく、イベント依存度が高い。"
    },
    "osaka_tennoji": {
        "name": "大阪 天王寺・阿倍野",
        "lat": 34.6477, "lon": 135.5135,
        "population": 300000,
        "feature": "あべのハルカスと通天閣(新世界)が共存するエリア。新旧の文化が入り混じる。"
    }
}

# --- 天気取得関数 ---
def get_stats_from_hourly(hourly_data, start_hour, end_hour):
    temps = hourly_data['temperature_2m'][start_hour:end_hour]
    rains = hourly_data['precipitation_probability'][start_hour:end_hour]
    codes = hourly_data['weather_code'][start_hour:end_hour]
    if not temps: return {"max": "-", "min": "-", "rain": "-", "code": 0}
    most_common_code = max(set(codes), key=codes.count)
    return {"max": max(temps), "min": min(temps), "rain": max(rains), "code": most_common_code}

def get_real_weather(lat, lon, date_obj):
    date_str = date_obj.strftime('%Y-%m-%d')
    url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&hourly=temperature_2m,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FTokyo&start_date={date_str}&end_date={date_str}"
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            data = json.loads(response.read().decode())
            daily = data['daily']
            hourly = data['hourly']
            main_weather = {
                "max_temp": daily['temperature_2m_max'][0],
                "min_temp": daily['temperature_2m_min'][0],
                "rain_prob": daily['precipitation_probability_max'][0],
                "code": daily['weather_code'][0]
            }
            morning = get_stats_from_hourly(hourly, 5, 11)
            daytime = get_stats_from_hourly(hourly, 11, 16)
            night = get_stats_from_hourly(hourly, 16, 24)
            return {"main": main_weather, "morning": morning, "daytime": daytime, "night": night}
    except Exception as e:
        print(f"⚠️ 天気取得エラー: {e}", flush=True)
        return None

def get_weather_label(code):
    if code == 0: return "快晴"
    if code in [1, 2, 3]: return "曇り"
    if code in [45, 48]: return "霧"
    if code in [51, 53, 55, 61, 63, 65, 80, 81, 82]: return "雨"
    if code in [71, 73, 75, 77, 85, 86]: return "雪"
    if code >= 95: return "雷雨"
    return "曇り"

# --- AI生成 (ハイブリッド対応版) ---
def get_ai_advice(area_key, area_data, target_date, days_offset):
    if not API_KEY: return None
    genai.configure(api_key=API_KEY)
    
    date_str = target_date.strftime('%Y年%m月%d日')
    weekday_int = target_date.weekday()
    weekday_str = ["月", "火", "水", "木", "金", "土", "日"][weekday_int]
    full_date = f"{date_str} ({weekday_str})"
    
    real_weather = get_real_weather(area_data["lat"], area_data["lon"], target_date)
    
    psychology_prompt = ""
    if weekday_int == 6: psychology_prompt = "日曜日は翌日仕事のため夜間需要減。ランク辛めに。"
    elif weekday_int == 5: psychology_prompt = "土曜日は夜間需要高め。"

    w_info = "不明"
    main_condition = "不明"
    if real_weather:
        w_info = f"最高{real_weather['main']['max_temp']}℃ / 最低{real_weather['main']['min_temp']}℃ / 降水{real_weather['main']['rain_prob']}%"
        main_condition = get_weather_label(real_weather['main']['code'])

    print(f"🤖 [AI予測] {area_data['name']} / {full_date} 生成開始...", flush=True)

    prompt = f"""
    あなたは「{area_data['name']}」の地域特性に精通した観光コンサルタントAIです。
    {full_date}の需要予測データを作成してください。
    エリア特徴: {area_data['feature']}
    基準人口: 約{area_data['population']}人
    ランク基準: S(人口10%超流入/激混み), A(5%超/混雑), B(週末並), C(平日/閑散)。日曜夜はランク下げ推奨。
    気象: {w_info} ({main_condition})
    {psychology_prompt}
    
    JSON出力のみ:
    {{
        "date": "{full_date}", "is_long_term": false, "rank": "S/A/B/C",
        "weather_overview": {{ "condition": "{main_condition}", "high": "{real_weather['main']['max_temp'] if real_weather else '-'}℃", "low": "{real_weather['main']['min_temp'] if real_weather else '-'}℃", "rain": "{real_weather['main']['rain_prob'] if real_weather else '-'}%" }},
        "events_info": {{ "event_name": "イベント名", "time_info": "規模感", "traffic_warning": "影響" }},
        "timeline": {{
            "morning": {{ "weather": "概況", "high": "℃", "low": "℃", "rain": "%", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "..." }} }},
            "daytime": {{ "weather": "概況", "high": "℃", "low": "℃", "rain": "%", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "..." }} }},
            "night": {{ "weather": "概況", "high": "℃", "low": "℃", "rain": "%", "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "..." }} }}
        }}
    }}
    """
    
    # ★ここが重要：モデル自動切り替えロジック
    try:
        # まずは最新のFlashに挑戦！
        model = genai.GenerativeModel("gemini-1.5-flash")
        res = model.generate_content(prompt)
        return json.loads(res.text.replace("```json", "").replace("```", "").strip())
        
    except Exception as e:
        # 404(モデルが見つからない)などのエラーが出たら、即座にPro(旧型)に切り替え
        print(f"⚠️ Flashモデルでの生成に失敗 ({e})。レガシーモデル(Pro)に切り替えます...", flush=True)
        try:
            model = genai.GenerativeModel("gemini-pro")
            res = model.generate_content(prompt)
            return json.loads(res.text.replace("```json", "").replace("```", "").strip())
        except Exception as e2:
            print(f"❌ レガシーモデルでも失敗: {e2}", flush=True)
            return None

# --- 簡易予測 ---
def get_simple_forecast(target_date):
    date_str = target_date.strftime('%Y年%m月%d日')
    weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
    full_date = f"{date_str} ({weekday_str})"
    rank = "C"
    if target_date.weekday() == 5: rank = "A"
    elif target_date.weekday() in [4, 6]: rank = "B"
    return {
        "date": full_date, "is_long_term": True, "rank": rank,
        "weather_overview": { "condition": "予報待ち", "high": "-", "low": "-", "rain": "-" },
        "events_info": { "event_name": "ー", "time_info": "", "traffic_warning": "" },
        "timeline": None
    }

# --- メイン ---
if __name__ == "__main__":
    today = datetime.now(JST)
    print(f"🦅 Eagle Eye 全国版(Flash/Proハイブリッド) 起動: {today.strftime('%Y/%m/%d')}", flush=True)
    
    master_data = {}
    
    for area_key, area_data in TARGET_AREAS.items():
        print(f"\n📍 エリア処理開始: {area_data['name']}", flush=True)
        area_forecasts = []
        
        for i in range(90):
            target_date = today + timedelta(days=i)
            
            if i < 3: # 直近3日はAI
                data = get_ai_advice(area_key, area_data, target_date, i)
                if data:
                    area_forecasts.append(data)
                    time.sleep(1) # 成功したら1秒待機
                else:
                    print("⚠️ 生成失敗。簡易版を適用。", flush=True)
                    area_forecasts.append(get_simple_forecast(target_date))
            else:
                area_forecasts.append(get_simple_forecast(target_date))
        
        master_data[area_key] = area_forecasts

    if len(master_data) > 0:
        with open("eagle_eye_data.json", "w", encoding="utf-8") as f:
            json.dump(master_data, f, ensure_ascii=False, indent=2)
        print(f"✅ 全エリアデータ保存完了", flush=True)
    else:
        exit(1)
