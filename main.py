import os
import json
import time
import urllib.request
from datetime import datetime, timedelta, timezone
import google.generativeai as genai

# --- 設定 ---
API_KEY = os.environ.get("GEMINI_API_KEY")
JST = timezone(timedelta(hours=9), 'JST')

# 函館の基礎データ
LAT = 41.7687
LON = 140.7288
HAKODATE_POPULATION = 243000  # 函館市の人口（約24.3万人）

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
    # 最新モデルを指定（推論能力が高いモデル推奨）
    target_model = "models/gemini-2.0-flash-exp"
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
        weekday_int = target_date.weekday()
        weekday_str = ["月", "火", "水", "木", "金", "土", "日"][weekday_int]
        full_date = f"{date_str} ({weekday_str})"
        
        real_weather = get_real_weather(target_date)
        
        # 曜日別の心理的バイアス
        psychology_prompt = ""
        if weekday_int == 6: # 日曜日
            psychology_prompt = """
            【重要：日曜日の心理的バイアス】
            ・日曜日は「翌日から仕事」のため、地元住民の夜間の外出は極端に減ります。
            ・観光客も日曜日の午後には帰路につくため、夜の飲食・宿泊需要は土曜日に比べて大幅に下がります。
            ・イベントがあっても「翌日仕事」の影響を考慮し、需要ランクは辛め（低め）に見積もってください。
            """
        elif weekday_int == 5: # 土曜日
            psychology_prompt = """
            【重要：土曜日の傾向】
            ・翌日が休みのため、夜遅くまで地元住民や観光客の動きが活発です。夜間需要は高めです。
            """

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

        # ★ここが進化ポイント：人口比率による科学的ランク判定
        prompt = f"""
        あなたは函館の観光コンサルタントAIです。
        {timing_text}である「{full_date}」の函館の観光需要予測データを作成してください。
        
        【判断ロジック：人口比率インパクト】
        函館市の人口は約 {HAKODATE_POPULATION} 人です。
        イベントがある場合、過去のデータから推定来場者数を割り出し、以下の基準でランクを決定してください。
        
        * ランクS (激混み): 推定来場者が人口の10%以上（約2.4万人以上）
        * ランクA (混雑): 推定来場者が人口の5%以上（約1.2万人以上）
        * ランクB (普通): 推定来場者が人口の1%以上、または通常の週末
        * ランクC (閑散): それ以下、または平日・悪天候
        ※ただし、日曜日の夜は上記「心理的バイアス」によりランクを1つ下げることを検討してください。

        気象データ:
        {w_info}

        {psychology_prompt}
        
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
            "events_info": {{
                "event_name": "イベント名（なければ「特になし」）",
                "time_info": "過去の規模感（例：例年3万人が来場）や時間",
                "traffic_warning": "人口比率{HAKODATE_POPULATION}人に対するインパクトや交通規制の警告"
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
