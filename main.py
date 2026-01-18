import os
import json
import google.generativeai as genai
from datetime import datetime, timedelta, timezone

# --- 設定 ---
# GitHubの金庫からキーを取り出す
API_KEY = os.environ.get("GEMINI_API_KEY")

# 日本時間の現在時刻を取得
JST = timezone(timedelta(hours=9), 'JST')
today = datetime.now(JST)
date_str = today.strftime('%Y年%m月%d日')
weekday_str = ["月", "火", "水", "木", "金", "土", "日"][today.weekday()]
full_date = f"{date_str} ({weekday_str})"

def get_ai_advice():
    if not API_KEY:
        print("エラー: APIキーが見つかりません")
        return None

    try:
        genai.configure(api_key=API_KEY)
        # モデルを自動選択 (Pro > Flash の順)
        model_name = 'gemini-1.5-flash' # デフォルト
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                if 'gemini-1.5-pro' in m.name:
                    model_name = m.name
                    break
        
        model = genai.GenerativeModel(model_name)
        
        # プロンプト（命令書）
        # 本来はここにWeb検索などの最新情報を組み込みますが、
        # 今回はデモとして「架空のイベント情報」を元に生成させます。
        prompt = f"""
        あなたは函館の観光コンサルタントAIです。
        今日（{full_date}）の函館の観光需要予測データを作成してください。
        
        以下の条件でJSONデータを作成してください。
        1. ランクは「S, A, B, C」のいずれか。
        2. 天気は今の時期の函館らしいもの。
        3. アドバイスは以下の職業別に具体的に。
           - taxi (タクシー)
           - restaurant (飲食店)
           - hotel (ホテル)
           - shop (お土産)
           - logistics (物流)
           - conveni (コンビニ)
        4. タイムラインは朝・昼・夕・夜の4つ。交通規制などの警告があれば含める。

        出力はJSON形式のみ。Markdown記号は不要。
        """
        
        response = model.generate_content(prompt)
        text = response.text.replace("```json", "").replace("```", "").strip()
        return json.loads(text)

    except Exception as e:
        print(f"エラー発生: {e}")
        return None

# --- メイン処理 ---
if __name__ == "__main__":
    print(f"🦅 Eagle Eye 起動: {full_date}")
    
    data = get_ai_advice()
    
    if data:
        # 画面表示用データに日付を追加
        data["date"] = full_date
        
        # JSONファイルとして保存
        with open("eagle_eye_data.json", "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print("✅ データ保存完了: eagle_eye_data.json")
    else:
        print("❌ データ生成失敗")
