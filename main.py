import os
import json
import time
import google.generativeai as genai
from datetime import datetime, timedelta, timezone

# --- 設定 ---
API_KEY = os.environ.get("GEMINI_API_KEY")
JST = timezone(timedelta(hours=9), 'JST')

def get_model():
    """利用可能な最新モデルを自動選択して返す"""
    genai.configure(api_key=API_KEY)
    
    # まずは最新の2.5系などを狙い撃ち
    target_model = "models/gemini-2.5-flash"
    print(f"🔍 モデル設定: {target_model} を試行します...")
    
    try:
        model = genai.GenerativeModel(target_model)
        return model
    except:
        print("⚠️ 指定モデルが見つかりません。自動検索します...")
        target_model = 'gemini-1.5-flash' # 初期値
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                if 'gemini' in m.name:
                    target_model = m.name
                    if '2.5' in m.name or '2.0' in m.name:
                        break
        print(f"✅ 自動選択されたモデル: {target_model}")
        return genai.GenerativeModel(target_model)

def get_ai_advice(target_date, days_offset):
    """指定された日付の予測データを生成する"""
    if not API_KEY:
        print("エラー: APIキーが環境変数に見つかりません")
        return None

    try:
        model = get_model()
        
        # 日付文字列の作成
        date_str = target_date.strftime('%Y年%m月%d日')
        weekday_str = ["月", "火", "水", "木", "金", "土", "日"][target_date.weekday()]
        full_date = f"{date_str} ({weekday_str})"
        
        # 何日後かによって指示を少し変える
        timing_text = "今日" if days_offset == 0 else f"{days_offset}日後の未来"
        
        print(f"🤖 {timing_text} ({full_date}) の予測を生成中...")

        # プロンプト（命令書）
        prompt = f"""
        あなたは函館の観光コンサルタントAIです。
        {timing_text}である「{full_date}」の函館の観光需要予測データを作成してください。
        
        以下の条件でJSONデータを作成してください。
        1. ランクは「S, A, B, C」のいずれか。
        2. 天気は今の時期の函館らしいもの。
        3. アドバイスは以下の職業別に具体的に（40文字以内）。
           - taxi (タクシー)
           - restaurant (飲食店)
           - hotel (ホテル)
           - shop (お土産)
           - logistics (物流)
           - conveni (コンビニ)
        4. タイムラインは朝・昼・夕・夜の4つ。

        出力はJSON形式のみ。Markdown記号は不要。
        """
        
        response = model.generate_content(prompt)
        text = response.text.replace("```json", "").replace("```", "").strip()
        data = json.loads(text)
        
        # 日付情報をデータに追加
        data["date"] = full_date
        return data

    except Exception as e:
        print(f"❌ エラー発生 ({full_date}): {e}")
        return None

# --- メイン処理 ---
if __name__ == "__main__":
    today = datetime.now(JST)
    print(f"🦅 Eagle Eye 起動: {today.strftime('%Y/%m/%d')}")
    
    all_data = []
    
    # 今日(0)、明日(1)、明後日(2) の3日分をループ
    for i in range(3):
        target_date = today + timedelta(days=i)
        
        # AIに生成させる
        data = get_ai_advice(target_date, i)
        
        if data:
            all_data.append(data)
        else:
            print(f"⚠️ {i}日後のデータ生成に失敗しました。スキップします。")
        
        # AIを休ませる（API制限対策で少し待つ）
        time.sleep(2)

    if len(all_data) > 0:
        # リスト形式（[...]）で保存
        with open("eagle_eye_data.json", "w", encoding="utf-8") as f:
            json.dump(all_data, f, ensure_ascii=False, indent=2)
        print(f"✅ 3日分のデータ保存完了: eagle_eye_data.json (件数: {len(all_data)})")
    else:
        print("❌ 全てのデータ生成に失敗しました")
        exit(1)
