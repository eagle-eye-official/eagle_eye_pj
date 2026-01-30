*** a/main.py
--- b/main.py
***************
*** 1,40 ****
  # main.py
  # Eagle Eye - assets/eagle_eye_data.json generator
  # - 5 jobs only: taxi, delivery, restaurant, retail, hotel
  # - Writes assets/eagle_eye_data.json
  # - Robust: still generates output even if Gemini/Open-Meteo/JMA fails
  #
  # 2026-01 patch:
  # - Areas default to "major cities + Hakodate" to reduce tokens/cost (AREA_SET=all to restore)
  # - 2-stage AI: (1) Extract signals (events/traffic/alerts) -> (2) Judge/day report
  # - Venue list injected for better evidence
  # - rank_reasons / rank_drivers / evidence_level added
  # - Safety valve: low confidence => never S
  
  import os
  import json
  import time
  import re
  import urllib.request
  from datetime import datetime, timedelta, timezone
  from concurrent.futures import ThreadPoolExecutor, as_completed
  
  import requests
***************
*** 55,64 ****
  # Jobs fixed to 5 (MVP)
  JOB_KEYS = ["taxi", "delivery", "restaurant", "retail", "hotel"]
+ JOB_LABELS = {
+     "taxi": "タクシー",
+     "delivery": "デリバリー",
+     "restaurant": "飲食店",
+     "retail": "小売",
+     "hotel": "ホテル",
+ }
  
  # --- 2026 Holidays (Japan) ---
  HOLIDAYS_2026 = {
      "2026-01-01", "2026-01-12", "2026-02-11", "2026-02-23", "2026-03-20",
      "2026-04-29", "2026-05-03", "2026-05-04", "2026-05-05", "2026-05-06",
***************
*** 205,260 ****
  def extract_json_block(text: str) -> str:
      m = re.search(r"\{.*\}", text, re.DOTALL)
      return m.group(0) if m else text
+
+ # =========================
+ # 2026-01 patch: text sanitizers (weather mismatch prevention)
+ # =========================
+ def strip_unverified_weather_sentences(text: str) -> str:
+     """
+     Remove sentences likely to introduce conflicting alternate forecasts (e.g. "一部の予報では...").
+     Only drops such sentences when they contain ℃ or % (i.e. numeric claims).
+     """
+     if not text:
+         return ""
+     parts = re.split(r"(?<=[。！？])", text)
+     keep = []
+     for s in parts:
+         ss = s.strip()
+         if not ss:
+             continue
+         bad_kw = any(k in ss for k in (
+             "別の予報", "異なる見解", "一部の予報", "別の見解",
+             "別の天気", "別情報", "予報では", "ところによっては"
+         ))
+         if bad_kw and (("℃" in ss) or ("%" in ss) or ("％" in ss)):
+             continue
+         keep.append(s)
+     return "".join(keep).strip()
+
+ def remove_weather_numbers(text: str) -> str:
+     """
+     Drop sentences containing ℃ or % (to avoid numeric contradictions in narrative).
+     """
+     if not text:
+         return ""
+     parts = re.split(r"(?<=[。！？\n])", text)
+     keep = []
+     for s in parts:
+         ss = s.strip()
+         if not ss:
+             continue
+         if ("℃" in ss) or ("%" in ss) or ("％" in ss):
+             continue
+         keep.append(s)
+     return "".join(keep).strip()
+
+ def scrub_weather_numbers_in_text(s: str) -> str:
+     """
+     Keep meaning, remove weather numeric expressions to prevent mismatches
+     (e.g., "最高1℃、最低-2℃", "降水確率60%").
+     """
+     if not s:
+         return ""
+     t = str(s)
+     # drop parenthetical segments that include ℃ or %
+     t = re.sub(r"（[^）]*(℃|%|％)[^）]*）", "", t)
+     t = re.sub(r"\([^)]*(℃|%|％)[^)]*\)", "", t)
+     # replace explicit temps/pops
+     t = re.sub(r"最高\s*-?\d+\s*℃", "最高気温", t)
+     t = re.sub(r"最低\s*-?\d+\s*℃", "最低気温", t)
+     t = re.sub(r"-?\d+\s*℃", "", t)
+     t = re.sub(r"\d+\s*(%|％)", "", t)
+     # cleanup
+     t = re.sub(r"\s+", " ", t).strip()
+     t = t.strip("、。・ ")
+     return t
+
+ def auto_confidence(evidence_level: str, facts: list) -> int:
+     """
+     Fill confidence when Gemini returns 0/blank.
+     Conservative mapping + small boost by evidence amount.
+     """
+     base = {"high": 82, "med": 68, "low": 50}.get((evidence_level or "low").lower(), 50)
+     n = len(facts or [])
+     if n == 0:
+         base -= 10
+     elif n >= 3:
+         base += 5
+     return max(0, min(100, int(base)))
+
+ def normalize_condition_from_timeline(day_obj: dict) -> None:
+     """
+     Unify weather_overview.condition with timeline (prefer daytime).
+     """
+     if not isinstance(day_obj, dict):
+         return
+     tl = day_obj.get("timeline")
+     if not isinstance(tl, dict):
+         return
+     pick = None
+     for slot in ("daytime", "morning", "night"):
+         w = (tl.get(slot) or {}).get("weather")
+         if w and str(w).strip() not in ("-", ""):
+             pick = str(w).strip()
+             break
+     if pick:
+         day_obj.setdefault("weather_overview", {})
+         day_obj["weather_overview"]["condition"] = pick
+
+ def build_daily_schedule_and_impact_safe(
+     target_dt: datetime,
+     weather_overview: dict,
+     facts: list,
+     reasons: list,
+     signals_note: str,
+     job_actions: dict
+ ) -> str:
+     """
+     Build narrative without conflicting numeric weather claims.
+     Weather numbers appear ONLY in the fixed overview line (from weather_overview).
+     """
+     label = _date_label(target_dt)
+     wo = weather_overview or {}
+     condition = wo.get("condition", "☁️")
+     high = wo.get("high", "-")
+     low = wo.get("low", "-")
+     rain = wo.get("rain", "-")
+     warning = wo.get("warning", "特になし") or "特になし"
+
+     lines = []
+     lines.append(f"{label}の概況")
+     lines.append(f"天気: {condition}｜{high} / {low}｜降水確率: {rain}｜警報注意報: {warning}")
+
+     f = [str(x).strip() for x in (facts or []) if str(x).strip()]
+     if f:
+         lines.append("")
+         lines.append("■イベント/交通（観測）")
+         for x in f[:6]:
+             lines.append(f"- {x}")
+
+     # build "見立て" from reasons + signals_note (sanitized, non-numeric)
+     rs = [scrub_weather_numbers_in_text(x) for x in (reasons or []) if scrub_weather_numbers_in_text(x)]
+     note = strip_unverified_weather_sentences(signals_note or "")
+     note = remove_weather_numbers(note).strip()
+
+     if rs or note:
+         lines.append("")
+         lines.append("■見立て")
+         for x in rs[:5]:
+             lines.append(f"- {x}")
+         if note:
+             lines.append(note)
+
+     lines.append("")
+     lines.append("【職業別要点】")
+     ja = job_actions or {}
+     for k in JOB_KEYS:
+         lines.append(f"{JOB_LABELS.get(k, k)}: {str(ja.get(k, '-') or '-').strip()}")
+
+     return "\n".join(lines).strip()
  
  def clamp_rank(rank: str, max_rank: str) -> str:
      # Higher is "S", then A, B, C
      order = ["S", "A", "B", "C"]
      try:
***************
*** 573,612 ****
  def build_long_term_day(area_key: str, area_name: str, target_dt: datetime, long_term_text: str):
      full_date = _date_label(target_dt)
      rank = base_rank_for_date(target_dt)
  
      wo = {
          "condition": "☁️",
          "high": "-",
          "low": "-",
          "rain": "-",
-         "rain_am": None,
-         "rain_pm": None,
-         "rain_night": None,
-         "warning": "-"
+         "rain_am": "-",
+         "rain_pm": "-",
+         "rain_night": "-",
+         "warning": "特になし"
      }
  
      return {
          "area_key": area_key,
          "area_name": area_name,
          "date": full_date,
          "is_long_term": True,
          "rank": rank,
          "rank_reasons": [],
          "rank_drivers": {"positive": [], "negative": []},
          "evidence_level": "low",
          "weather_overview": wo,
          "event_traffic_facts": [],
          "peak_windows": {k: "" for k in JOB_KEYS},
          "job_actions": {k: "" for k in JOB_KEYS},
          "daily_schedule_and_impact": f"【{target_dt.strftime('%m月%d日')}の長期予測】\n\n■長期傾向\n{long_term_text}\n",
          "timeline": None,
-         "confidence": 0
+         "confidence": 30
      }
***************
*** 744,915 ****
  def generate_ai_day(area_key: str, area_data, target_dt: datetime, jma_day_data, warning_text: str, slot_weather, signals_for_day: dict):
      """
      Stage2:
        Build evidence and ask Gemini to judge:
          - rank (S/A/B/C)
          - rank_reasons, rank_drivers, evidence_level, confidence
          - plus existing fields expected by main.dart
      If Gemini unavailable/fails -> returns None.
      """
      if not API_KEY:
          return None
  
      date_str = target_dt.strftime("%Y-%m-%d")
      full_date = _date_label(target_dt)
  
      w_code = (jma_day_data or {}).get("code", "200")
      w_emoji = get_weather_emoji_jma(w_code)
  
      now_dt = datetime.now(JST)
      is_today = (target_dt.date() == now_dt.date())
  
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
  
      venues = AREA_VENUES.get(area_key, [])
      cal = build_calendar_factors(target_dt)
  
      # Evidence object (structured; keeps tokens reasonable)
      evidence = {
          "area": {
              "key": area_key,
              "name": area_data["name"],
              "feature": area_data.get("feature", ""),
              "venues_hint": venues[:10]
          },
          "date": {
              "date": date_str,
              "label": full_date,
              "calendar": cal
          },
          "weather": {
              "jma_code": w_code,
              "condition": w_emoji,
              "high": f"{high}",
              "low": f"{low}",
              "warning": warning_text,
              "rain": {
                  "am": rain_am,
                  "pm": rain_pm,
                  "night": rain_ng,
                  "display": rain_display
              },
              "slots": slot_weather
          },
          "signals": signals_for_day if isinstance(signals_for_day, dict) else {
              "events": [], "traffic": [], "alerts": [],
              "overall_note": "", "evidence_level": "low", "sources_note": ""
          }
      }
  
      # Schema hint for stage2 output
      schema_hint = {
          "area_key": area_key,
          "area_name": area_data["name"],
          "date": full_date,
          "is_long_term": False,
          "rank": "S/A/B/C",
          "rank_reasons": ["(max 5) なぜそのランクか（具体的）"],
          "rank_drivers": {"positive": ["..."], "negative": ["..."]},
          "evidence_level": "high/med/low",
          "confidence": 0,
          "weather_overview": {
              "condition": w_emoji,
              "high": f"最高{high}℃",
              "low": f"最低{low}℃",
              "rain": rain_display,
              "rain_am": rain_am,
              "rain_pm": rain_pm,
              "rain_night": rain_ng,
              "warning": warning_text
          },
          "event_traffic_facts": ["(max 6)"],
          "peak_windows": {k: "" for k in JOB_KEYS},
          "job_actions": {k: "" for k in JOB_KEYS},
          "daily_schedule_and_impact": "レポート本文（改行OK。最後に職業別要点を含める）",
          "timeline": {
              "morning": {
                  "weather": slot_weather["morning"]["weather"],
                  "temp": slot_weather["morning"]["temp"],
                  "temp_high": slot_weather["morning"]["temp_high"],
                  "temp_low": slot_weather["morning"]["temp_low"],
                  "humidity": slot_weather["morning"]["humidity"],
                  "rain": slot_weather["morning"]["rain"],
                  "advice": {k: "" for k in JOB_KEYS}
              },
              "daytime": {
                  "weather": slot_weather["daytime"]["weather"],
                  "temp": slot_weather["daytime"]["temp"],
                  "temp_high": slot_weather["daytime"]["temp_high"],
                  "temp_low": slot_weather["daytime"]["temp_low"],
                  "humidity": slot_weather["daytime"]["humidity"],
                  "rain": slot_weather["daytime"]["rain"],
                  "advice": {k: "" for k in JOB_KEYS}
              },
              "night": {
                  "weather": slot_weather["night"]["weather"],
                  "temp": slot_weather["night"]["temp"],
                  "temp_high": slot_weather["night"]["temp_high"],
                  "temp_low": slot_weather["night"]["temp_low"],
                  "humidity": slot_weather["night"]["humidity"],
                  "rain": slot_weather["night"]["rain"],
                  "advice": {k: "" for k in JOB_KEYS}
              }
          }
      }
  
      prompt = (
          "あなたは世界トップクラスの戦略コンサルタントです。\n"
          "次の evidence(JSON) に基づき、その日の混雑予測ランクと根拠、職業別提案を作ってください。\n\n"
  
          "【重要ルール】\n"
          "- フェイク禁止。evidenceにない固有名詞を作らない（会場名/イベント名を捏造しない）。\n"
          "- 曖昧なら未確認とし、confidence/evidence_level を下げる。\n"
          "- 曜日だけでランクを決めない（曜日は参考に留める）。\n"
          "- rank_reasons は「誰が見てもそうだよね」と言える具体根拠（最大5）。\n"
          "- rank_drivers は増える要因/減る要因の両方を短文で。\n"
          "- event_traffic_facts は最大6件、短い箇条書き。\n"
          "- peak_windows / timeline.*.advice / job_actions は必ず全職業キーを埋める。\n"
          "- job_actions は各職業1行で高密度（区切りは「｜」推奨）。\n"
+         "- daily_schedule_and_impact に天気の数値（℃/%）を入れない（数値はweather_overviewに集約）。\n\n"
  
          "【出力はJSONのみ】\n"
          "次のスキーマを最低限満たすこと（キー追加は可）。\n\n"
          + json.dumps(schema_hint, ensure_ascii=False, indent=2)
          + "\n\n【evidence】\n"
          + json.dumps(evidence, ensure_ascii=False)
      )
  
      res = call_gemini_json(prompt)
      if not res:
          return None
  
      try:
          j = json.loads(extract_json_block(res))
      except Exception:
          return None
  
      # ---- sanitize & ensure schema for main.dart ----
      j.setdefault("area_key", area_key)
      j.setdefault("area_name", area_data["name"])
      j.setdefault("date", full_date)
      j.setdefault("is_long_term", False)
  
      # rank + reasons
      j["rank"] = str(j.get("rank") or "C").strip().upper()
      rr = j.get("rank_reasons")
      if not isinstance(rr, list):
          rr = []
-     j["rank_reasons"] = [str(x).strip() for x in rr if str(x).strip()][:5]
+     # remove weather numeric expressions from reasons to avoid mismatches
+     j["rank_reasons"] = [scrub_weather_numbers_in_text(str(x).strip()) for x in rr if str(x).strip()]
+     j["rank_reasons"] = [x for x in j["rank_reasons"] if x][:5]
  
      rd = j.get("rank_drivers")
      if not isinstance(rd, dict):
          rd = {"positive": [], "negative": []}
      pos = rd.get("positive")
      neg = rd.get("negative")
      if not isinstance(pos, list):
          pos = []
      if not isinstance(neg, list):
          neg = []
      j["rank_drivers"] = {
-         "positive": [str(x).strip() for x in pos if str(x).strip()][:5],
-         "negative": [str(x).strip() for x in neg if str(x).strip()][:5]
+         "positive": [scrub_weather_numbers_in_text(str(x).strip()) for x in pos if str(x).strip()][:5],
+         "negative": [scrub_weather_numbers_in_text(str(x).strip()) for x in neg if str(x).strip()][:5]
      }
+     j["rank_drivers"]["positive"] = [x for x in j["rank_drivers"]["positive"] if x]
+     j["rank_drivers"]["negative"] = [x for x in j["rank_drivers"]["negative"] if x]
  
      evl = str(j.get("evidence_level") or (signals_for_day.get("evidence_level") if isinstance(signals_for_day, dict) else "low")).strip().lower()
      if evl not in ("high", "med", "low"):
          evl = "low"
      j["evidence_level"] = evl
  
      conf = j.get("confidence")
      try:
          j["confidence"] = int(conf)
      except Exception:
          j["confidence"] = 0
  
      # weather_overview
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
  
      # event_traffic_facts
      facts_fallback = signals_to_facts(signals_for_day, max_items=6)
      et = j.get("event_traffic_facts")
      if not isinstance(et, list):
          et = facts_fallback
      et_clean = [str(x).strip() for x in et if str(x).strip()]
      if not et_clean:
          et_clean = facts_fallback
      j["event_traffic_facts"] = et_clean[:6]
  
      # peak_windows / job_actions
      pw = j.get("peak_windows") or {}
      if not isinstance(pw, dict):
          pw = {}
      for k in JOB_KEYS:
          pw.setdefault(k, "")
      j["peak_windows"] = {k: str(pw.get(k, "")).strip() for k in JOB_KEYS}
  
      ja = j.get("job_actions") or {}
      if not isinstance(ja, dict):
          ja = {}
      for k in JOB_KEYS:
          ja.setdefault(k, "")
      j["job_actions"] = {k: str(ja.get(k, "")).strip() for k in JOB_KEYS}
  
      j.setdefault("daily_schedule_and_impact", "")
  
      # timeline: ensure slots & advice
      tl = j.get("timeline")
      if not isinstance(tl, dict):
          tl = {}
      for slot_name in ["morning", "daytime", "night"]:
          slot_src = tl.get(slot_name) if isinstance(tl.get(slot_name), dict) else {}
          base = slot_weather.get(slot_name, {})
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
  
      # normalize hi/lo for display stability
      normalize_high_low_from_timeline(j)
+     # unify condition with timeline (avoid condition mismatch)
+     normalize_condition_from_timeline(j)
  
-     # Safety valve: low confidence => no S
-     apply_rank_safety(j)
+     # If confidence missing/0, auto-fill conservatively
+     if int(j.get("confidence") or 0) <= 0:
+         j["confidence"] = auto_confidence(j.get("evidence_level"), j.get("event_traffic_facts"))
+     # Safety valve: low confidence => no S
+     apply_rank_safety(j)
  
      # If reasons empty, create minimal reasons from evidence (no fabrication)
      if not j["rank_reasons"]:
          auto = []
          if facts_fallback:
              auto.append(f"観測材料: {facts_fallback[0]}")
          # weather: use slot rain and warning
          if warning_text and warning_text != "特になし":
              auto.append(f"警報注意報: {warning_text}")
          if rain_am != "-" or rain_pm != "-" or rain_ng != "-":
              auto.append(f"降水見込み: 午前{rain_am}/午後{rain_pm}/夜{rain_ng}")
          j["rank_reasons"] = auto[:5]
  
+     # ---- rebuild daily_schedule_and_impact safely (apply to ALL AI days) ----
+     signals_note = ""
+     if isinstance(signals_for_day, dict):
+         signals_note = str(signals_for_day.get("overall_note") or "").strip()
+     # also sanitize Gemini narrative (if any) and merge (non-numeric only)
+     gemini_text = strip_unverified_weather_sentences(str(j.get("daily_schedule_and_impact") or ""))
+     gemini_text = remove_weather_numbers(gemini_text).strip()
+     if gemini_text:
+         signals_note = (signals_note + "\n" + gemini_text).strip() if signals_note else gemini_text
+
+     j["daily_schedule_and_impact"] = build_daily_schedule_and_impact_safe(
+         target_dt=target_dt,
+         weather_overview=j.get("weather_overview"),
+         facts=j.get("event_traffic_facts"),
+         reasons=j.get("rank_reasons"),
+         signals_note=signals_note,
+         job_actions=j.get("job_actions"),
+     )
+
      return j
