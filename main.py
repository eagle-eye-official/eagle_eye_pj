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

def get_real_weather(date_obj):
    """
    Open-Meteo APIから函館の天気予報を取得する
    """
    date_str = date_obj.strftime('%Y-%m-%d')
    # 1時間ごとの気温、降水確率、天気コードを取得
    url = f"https://api.open-meteo.com/v1/forecast?latitude={LAT}&longitude={LON}&hourly=temperature_2m,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FTokyo&start_date={date_str}&end_date={date_str}"
    
    try:
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
            
            # 日次データ（メイン表示用）
            daily = data['daily']
            main_weather = {
                "max_temp": daily['temperature_2m_max'][0],
                "min_temp": daily['temperature_2m_min'][0],
                "rain_prob": daily['precipitation_probability_max'][0],
                "code": daily['weather_code'][0]
            }

            # 時間別データ（タイムライン用）の抽出
            hourly = data['hourly']
            
            # 時間帯ごとのインデックス (0時始まり)
            # 朝(5-11), 昼(11-16), 夜(16-24) の代表値（中間や平均）を取る簡易ロジック
            
            # 朝 (8時のデータを代表に)
            morning = {
                "temp": hourly['temperature_2m'][8],
                "rain": hourly['precipitation_probability'][8],
                "code": hourly['weather_code'][8]
            }
            # 昼 (13時のデータを代表に)
            daytime = {
                "temp": hourly['temperature_2m'][13],
                "rain": hourly['precipitation_probability'][13],
                "code": hourly['weather_code'][13]
            }
            # 夜 (19時のデータを代表に)
            night = {
                "temp": hourly['temperature_2m'][19],
                "rain": hourly['precipitation_probability'][19],
                "code": hourly['weather_code'][19]
            }
            
            return {"main": main_weather, "morning": morning, "daytime": daytime, "night": night}

    except Exception as e:
        print(f"⚠️ 天気API取得エラー: {e}")
        return None

def get_weather_label(code):
    """WMO天気コードを日本語に変換"""
    if code == 0: return "快晴"
    if code in [1, 2, 3]: return "曇り"
    if code in [45, 48]: return "霧"
    if code in [51, 53, 55, 61, 63, 65, 80, 81, 82]: return "雨"
    if code in [71, 73, 75, 77, 85, 86]: return "雪"
    if code >= 95: return "雷雨"
    return "曇り"

def get_model():
    genai.configure(api_key=API_KEY)
    target_model = "models/gemini-2.5-flash"
    try:
        return genai.GenerativeModel(target_model)
    except:
        target_model = 'gemini-1.5-flash'
        return genai.GenerativeModel(target_model)

def get_ai_advice(target_date, days_offset):
    if not API_KEY: return None

    try:
        model = get_model()
        
        # 日付文字列
        date_str = target_date.strftime('%Y年%m月%d日')
        weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
        full_date = f"{date_str} ({weekday_str})"
        
        # ★ここで実況天気を取得！
        real_weather = get_real_weather(target_date)
        
        # AIへの天気情報インプット作成
        if real_weather:
            w_info = f"""
            【実況天気予報データ】
            全体: 最高{real_weather['main']['max_temp']}℃ / 最低{real_weather['main']['min_temp']}℃ / 降水確率{real_weather['main']['rain_prob']}%
            朝(5-11): 気温{real_weather['morning']['temp']}℃ / 降水{real_weather['morning']['rain']}% / 天気コード{real_weather['morning']['code']}
            昼(11-16): 気温{real_weather['daytime']['temp']}℃ / 降水{real_weather['daytime']['rain']}% / 天気コード{real_weather['daytime']['code']}
            夜(16-24): 気温{real_weather['night']['temp']}℃ / 降水{real_weather['night']['rain']}% / 天気コード{real_weather['night']['code']}
            ※天気コード: 0=晴, 1-3=曇, 50番台60番台=雨, 70番台=雪
            """
            # メインの天気を日本語化しておく
            main_condition = get_weather_label(real_weather['main']['code'])
        else:
            w_info = "天気データ取得失敗。今の時期の函館の天気を推測してください。"
            main_condition = "不明"

        timing_text = "今日" if days_offset == 0 else f"{days_offset}日後の未来"
        print(f"🤖 {timing_text} ({full_date}) の予測生成中...")

        prompt = f"""
        あなたは函館の観光コンサルタントAIです。
        {timing_text}である「{full_date}」の函館の観光需要予測データを作成してください。
        
        絶対に以下の実況天気予報に基づいてアドバイスを行ってください。
        {w_info}
        
        以下のJSON形式で出力してください（Markdown記号なし）。
        {{
            "date": "{full_date}",
            "rank": "S, A, B, Cのいずれか",
            "weather_overview": {{
                "condition": "{main_condition}などの天気概況",
                "high": "{real_weather['main']['max_temp'] if real_weather else '--'}℃",
                "low": "{real_weather['main']['min_temp'] if real_weather else '--'}℃",
                "rain": "{real_weather['main']['rain_prob'] if real_weather else '--'}%"
            }},
            "timeline": {{
                "morning": {{
                    "period": "05:00-11:00",
                    "weather": "天気概況",
                    "temp": "{real_weather['morning']['temp'] if real_weather else '--'}℃",
                    "rain": "{real_weather['morning']['rain'] if real_weather else '--'}%",
                    "advice": {{
                        "taxi": "一言アドバイス",
                        "restaurant": "一言アドバイス",
                        "hotel": "一言アドバイス",
                        "shop": "一言アドバイス",
                        "logistics": "一言アドバイス",
                        "conveni": "一言アドバイス"
                    }}
                }},
                "daytime": {{
                    "period": "11:00-16:00",
                    "weather": "天気概況",
                    "temp": "{real_weather['daytime']['temp'] if real_weather else '--'}℃",
                    "rain": "{real_weather['daytime']['rain'] if real_weather else '--'}%",
                    "advice": {{ "taxi": "...", "restaurant": "...", "hotel": "...", "shop": "...", "logistics": "...", "conveni": "..." }}
                }},
                "night": {{
                    "period": "16:00-24:00",
                    "weather": "天気概況",
                    "temp": "{real_weather['night']['temp'] if real_weather else '--'}℃",
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

# --- メイン処理 ---
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
