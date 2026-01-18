import os
import json
import time
import urllib.request
from datetime import datetime, timedelta, timezone
import google.generativeai as genai

# --- 設定 ---
API_KEY = os.environ.get("GEMINI_API_KEY")
JST = timezone(timedelta(hours=9), 'JST')

# 函館の座標 (Open-Meteo用)
LAT = 41.7687
LON = 140.7288

def get_stats_from_hourly(hourly_data, start_hour, end_hour):
    """指定した時間範囲の最高・最低気温と最大降水確率を算出"""
    temps = hourly_data['temperature_2m'][start_hour:end_hour]
    rains = hourly_data['precipitation_probability'][start_hour:end_hour]
    codes = hourly_data['weather_code'][start_hour:end_hour]
    
    if not temps: return {"max": "-", "min": "-", "rain": "-", "code": 0}
    most_common_code = max(set(codes), key=codes.count)

    return {
        "max": max(temps),
        "min": min(temps),
        "rain": max(rains),
        "code": most_common_code
    }

def get_real_weather(date_obj):
    """Open-Meteo APIから函館の天気予報を取得する"""
    date_str = date_obj.strftime('%Y-%m-%d')
    url = f"https://api.open-meteo.com/v1/forecast?latitude={LAT}&longitude={LON}&hourly=temperature_2m,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FTokyo&start_date={date_str}&end_date={date_str}"
    
    try:
        with urllib.request.urlopen(url) as response:
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
        print(f"⚠️ 天気API取得エラー: {e}")
        return None

def get_weather_label(code):
    if code == 0: return "快晴"
    if code in [1, 2, 3]: return "曇り"
    if code in [45, 48]: return "霧"
    if code in [51, 53, 55, 61, 63, 65, 80, 81, 82]: return "雨"
    if code in [71, 73, 75, 77, 85, 86]: return "雪"
    if code >= 95: return "雷雨"
    return "曇り"

def get_model():
    genai.configure(api_key=API_KEY)
    # 最新モデルを優先的に使用
    target_model = "models/gemini-2.0-flash-exp" # 最新があれば指定、なければ自動検索
    try:
        genai.GenerativeModel(target_model)
        return genai.GenerativeModel(target_model)
    except:
        return genai.GenerativeModel("gemini-1.5-flash")

def get_ai_advice(target_date, days_offset):
    if not API_KEY: return None

    try:
        model = get_model()
        date_str = target_date.strftime('%Y年%m月%d日')
        weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
        full_date = f"{date_str} ({weekday_str})"
        
        real_weather = get_real_weather(target_date)
        
        if real_weather:
            w_info = f"""
            【実況天気予報データ (函館)】
            全体: 最高{real_weather['main']['max_temp']}℃ / 最低{real_weather['main']['min_temp']}℃ / 降水確率{real_weather['main']['rain_prob']}%
            朝(05-11): 最高{real_weather['morning']['max']}℃ / 最低{real_weather['morning']['min']}℃ / 降水{real_weather['morning']['rain']}%
            昼(11-16): 最高{real_weather['daytime']['max']}℃ / 最低{real_weather['daytime']['min']}℃ / 降水{real_weather['daytime']['rain']}%
            夜(16-24): 最高{real_weather['night']['max']}℃ / 最低{real_weather['night']['min']}℃ / 降水{real_weather['night']['rain']}%
            """
            main_condition = get_weather_label(real_weather['main']['code'])
        else:
            w_info = "天気データ取得失敗。"
            main_condition = "不明"

        timing_text = "今日" if days_offset == 0 else f"{days_offset}日後の未来"
        print(f"🤖 {timing_text} ({full_date}) の予測生成中...")

        # ★イベント情報を抽出するようにプロンプトを強化
        prompt = f"""
        あなたは函館の観光コンサルタントAIです。
        {timing_text}である「{full_date}」の函館の観光需要予測データを作成してください。
        
        気象データ:
        {w_info}
        
        以下のJSON形式で出力してください（Markdown記号なし）。
        特に「events」フィールドには、この時期の函館で開催される可能性が高いイベントや、天候による交通規制の可能性（「雪のため速度規制の恐れ」など）を具体的に予測して記述してください。

        {{
            "date": "{full_date}",
            "rank": "S, A, B, Cのいずれか",
            "weather_overview": {{
                "condition": "{main_condition}などの天気概況",
                "high": "{real_weather['main']['max_temp'] if real_weather else '--'}℃",
                "low": "{real_weather['main']['min_temp'] if real_weather else '--'}℃",
                "rain": "{real_weather['main']['rain_prob'] if real_weather else '--'}%"
            }},
            "events_info": {{
                "event_name": "イベント名や特記事項（なければ「特になし」）",
                "time_info": "開催時間や注意すべき時間帯",
                "traffic_warning": "交通規制や道路状況の警告（例：路面凍結による渋滞予測）"
            }},
            "timeline": {{
                "morning": {{
                    "weather": "天気概況",
                    "high": "{real_weather['morning']['max'] if real_weather else '--'}℃",
                    "low": "{real_weather['morning']['min'] if real_weather else '--'}℃",
                    "rain": "{real_weather['morning']['rain'] if real_weather else '--'}%",
                    "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "..." }}
                }},
                "daytime": {{
                    "weather": "天気概況",
                    "high": "{real_weather['daytime']['max'] if real_weather else '--'}℃",
                    "low": "{real_weather['daytime']['min'] if real_weather else '--'}℃",
                    "rain": "{real_weather['daytime']['rain'] if real_weather else '--'}%",
                    "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "..." }}
                }},
                "night": {{
                    "weather": "天気概況",
                    "high": "{real_weather['night']['max'] if real_weather else '--'}℃",
                    "low": "{real_weather['night']['min'] if real_weather else '--'}℃",
                    "rain": "{real_weather['night']['rain'] if real_weather else '--'}%",
                    "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "..." }}
                }}
            }}
        }}
        """
        
        response = model.generate_content(prompt)
        text = response.text.replace("```json", "").replace("```", "").strip()
        return json.loads(text)

    except Exception as e:
        print(f"❌ エラー ({full_date}): {e}")
        return None

if __name__ == "__main__":
    today = datetime.now(JST)
    print(f"🦅 Eagle Eye 起動: {today.strftime('%Y/%m/%d')}")
    all_data = []
    for i in range(3):
        target_date = today + timedelta(days=i)
        data = get_ai_advice(target_date, i)
        if data: all_data.append(data)
        time.sleep(2)

    if len(all_data) > 0:
        with open("eagle_eye_data.json", "w", encoding="utf-8") as f:
            json.dump(all_data, f, ensure_ascii=False, indent=2)
        print("✅ データ保存完了")
    else:
        exit(1)
