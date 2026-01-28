import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// ===============================
/// Eagle Eye - main.dart
/// - assets/eagle_eye_data.json を読み込み
/// - 職業選択で「ピーク」「打ち手」「時間帯アドバイス」を切替
/// - Webビルドで落ちる「List children内でfinal宣言」禁止に対応
/// ===============================

void main() {
  runApp(const EagleEyeApp());
}

class EagleEyeApp extends StatelessWidget {
  const EagleEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eagle Eye',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AnalysisScreen(),
    );
  }

  ThemeData _buildTheme() {
    const bg = Color(0xFF0B1220);
    const card = Color(0xFF0F1B2D);
    const accent = Color(0xFFFFA135);
    const accentSoft = Color(0x33FFA135);

    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: card,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: base.dividerTheme.copyWith(
        color: Colors.white.withOpacity(0.08),
        thickness: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: accentSoft,
        labelStyle: const TextStyle(color: Colors.white),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      textTheme: base.textTheme.copyWith(
        titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        bodyLarge: const TextStyle(fontSize: 15, height: 1.55, color: Colors.white),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.55, color: Colors.white),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: Colors.white.withOpacity(0.80),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}

/// ===============================
/// Job (職業定義)
/// ===============================

enum JobType {
  taxi,
  delivery,
  hotel,
  restaurant,
  retail,
  care,
}

class JobInfo {
  final JobType type;
  final String key; // JSON key
  final String label; // UI label
  final IconData icon;

  const JobInfo({
    required this.type,
    required this.key,
    required this.label,
    required this.icon,
  });
}

const List<JobInfo> kJobs = [
  JobInfo(type: JobType.care, key: 'care', label: 'care', icon: Icons.health_and_safety),
  JobInfo(type: JobType.delivery, key: 'delivery', label: 'デリバリー', icon: Icons.delivery_dining),
  JobInfo(type: JobType.hotel, key: 'hotel', label: 'ホテル', icon: Icons.hotel),
  JobInfo(type: JobType.restaurant, key: 'restaurant', label: '飲食店', icon: Icons.restaurant),
  JobInfo(type: JobType.retail, key: 'retail', label: '小売', icon: Icons.storefront),
  JobInfo(type: JobType.taxi, key: 'taxi', label: 'タクシー', icon: Icons.local_taxi),
];

JobInfo jobByKey(String key) {
  return kJobs.firstWhere((j) => j.key == key, orElse: () => kJobs.last);
}

/// ===============================
/// Data Models (壊れに強く)
/// ===============================

class ForecastDay {
  final String date; // "01月27日 (火)"
  final bool isLongTerm;
  final String rank; // S/A/B/C
  final WeatherOverview weatherOverview;
  final List<String> eventTrafficFacts;
  final Map<String, String> peakWindows; // taxi/delivery/...
  final Map<String, String> jobActions; // taxi/delivery/...（job별要点）
  final String dailyScheduleAndImpact; // レポート全文
  final TimelineSlots? timeline; // morning/daytime/night
  final int confidence;

  ForecastDay({
    required this.date,
    required this.isLongTerm,
    required this.rank,
    required this.weatherOverview,
    required this.eventTrafficFacts,
    required this.peakWindows,
    required this.jobActions,
    required this.dailyScheduleAndImpact,
    required this.timeline,
    required this.confidence,
  });

  factory ForecastDay.fromJson(Map<String, dynamic> j) {
    return ForecastDay(
      date: (j['date'] ?? '-') as String,
      isLongTerm: (j['is_long_term'] ?? false) as bool,
      rank: (j['rank'] ?? 'C') as String,
      weatherOverview: WeatherOverview.fromJson((j['weather_overview'] ?? {}) as Map<String, dynamic>),
      eventTrafficFacts: _asStringList(j['event_traffic_facts']),
      peakWindows: _asStringMap(j['peak_windows']),
      jobActions: _asStringMap(j['job_actions']),
      dailyScheduleAndImpact: (j['daily_schedule_and_impact'] ?? '') as String,
      timeline: j['timeline'] == null ? null : TimelineSlots.fromJson(j['timeline'] as Map<String, dynamic>),
      confidence: (j['confidence'] is num) ? (j['confidence'] as num).round() : 0,
    );
  }

  static List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }

  static Map<String, String> _asStringMap(dynamic v) {
    if (v is Map) {
      final out = <String, String>{};
      v.forEach((k, val) {
        out[k.toString()] = val?.toString() ?? '';
      });
      return out;
    }
    return const {};
  }
}

class WeatherOverview {
  final String condition; // emoji
  final String high; // "最高0℃"
  final String low; // "最低-1℃"
  final String rain; // "午前70% / 午後100%" 等（互換）
  final String? rainAm;
  final String? rainPm;
  final String? rainNight;
  final String warning;

  WeatherOverview({
    required this.condition,
    required this.high,
    required this.low,
    required this.rain,
    required this.rainAm,
    required this.rainPm,
    required this.rainNight,
    required this.warning,
  });

  factory WeatherOverview.fromJson(Map<String, dynamic> j) {
    return WeatherOverview(
      condition: (j['condition'] ?? '☁️') as String,
      high: (j['high'] ?? '-') as String,
      low: (j['low'] ?? '-') as String,
      rain: (j['rain'] ?? '-') as String,
      rainAm: j['rain_am']?.toString(),
      rainPm: j['rain_pm']?.toString(),
      rainNight: j['rain_night']?.toString(),
      warning: (j['warning'] ?? '-') as String,
    );
  }
}

class TimelineSlots {
  final SlotWeather morning;
  final SlotWeather daytime;
  final SlotWeather night;

  TimelineSlots({required this.morning, required this.daytime, required this.night});

  factory TimelineSlots.fromJson(Map<String, dynamic> j) {
    return TimelineSlots(
      morning: SlotWeather.fromJson((j['morning'] ?? {}) as Map<String, dynamic>),
      daytime: SlotWeather.fromJson((j['daytime'] ?? {}) as Map<String, dynamic>),
      night: SlotWeather.fromJson((j['night'] ?? {}) as Map<String, dynamic>),
    );
  }
}

class SlotWeather {
  final String weather; // emoji
  final String temp; // "0℃"
  final String tempHigh; // "1℃"
  final String tempLow; // "-2℃"
  final String humidity; // "70%"
  final String rain; // "100%"
  final Map<String, String> advice; // taxi/delivery/...

  SlotWeather({
    required this.weather,
    required this.temp,
    required this.tempHigh,
    required this.tempLow,
    required this.humidity,
    required this.rain,
    required this.advice,
  });

  factory SlotWeather.fromJson(Map<String, dynamic> j) {
    return SlotWeather(
      weather: (j['weather'] ?? '☁️') as String,
      temp: (j['temp'] ?? '-') as String,
      tempHigh: (j['temp_high'] ?? '-') as String,
      tempLow: (j['temp_low'] ?? '-') as String,
      humidity: (j['humidity'] ?? '-') as String,
      rain: (j['rain'] ?? '-') as String,
      advice: _asAdvice(j['advice']),
    );
  }

  static Map<String, String> _asAdvice(dynamic v) {
    if (v is Map) {
      final out = <String, String>{};
      v.forEach((k, val) => out[k.toString()] = val?.toString() ?? '');
      return out;
    }
    return const {};
  }
}

/// ===============================
/// Repository (assetsから読む)
/// ===============================

class EagleEyeRepo {
  Future<Map<String, List<ForecastDay>>> load() async {
    final raw = await rootBundle.loadString('assets/eagle_eye_data.json');

    // 空ファイル/途中で切れているJSONの事故を早期に分かりやすく
    if (raw.trim().isEmpty) {
      throw const FormatException('assets/eagle_eye_data.json が空です');
    }

    final decoded = json.decode(raw);
    if (decoded is! Map) {
      throw Exception('eagle_eye_data.json の形式が不正です（rootがMapではない）');
    }

    final out = <String, List<ForecastDay>>{};
    decoded.forEach((areaKey, value) {
      if (value is List) {
        out[areaKey.toString()] = value
            .whereType<Map>()
            .map((m) => ForecastDay.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }
    });
    return out;
  }
}

/// ===============================
/// UI
/// ===============================

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _repo = EagleEyeRepo();

  Map<String, List<ForecastDay>> _data = {};
  String? _areaKey;
  int _dayIndex = 0;

  bool _loading = true;
  String? _error;

  JobInfo _selectedJob = kJobs.last; // default taxi

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final data = await _repo.load();
      final keys = data.keys.toList()..sort();
      setState(() {
        _data = data;
        _areaKey = keys.isNotEmpty ? keys.first : null;
        _dayIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _areaKey == null ? 'Eagle Eye' : _prettyAreaName(_areaKey!);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '更新',
            onPressed: () async {
              setState(() {
                _loading = true;
                _error = null;
              });
              await _init();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? _ErrorView(message: _error!)
              : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final areaKey = _areaKey;
    if (areaKey == null || !_data.containsKey(areaKey)) {
      return const _ErrorView(message: 'データがありません');
    }
    final list = _data[areaKey]!;
    if (list.isEmpty) return const _ErrorView(message: 'エリアの予測が空です');

    final day = list[_dayIndex.clamp(0, list.length - 1)];

    // 職業별：ピーク/要点/時間帯アドバイスのキーを決める
    final jobKey = _selectedJob.key;

    // ピーク（職業別）
    final peaks = (day.peakWindows[jobKey] ?? '').trim();

    // 職業別要点（job_actions優先、なければレポートから抽出）
    final jobAction = _jobActionFor(day, jobKey);

    return RefreshIndicator(
      onRefresh: () async => _init(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _AreaAndDateHeader(
            areaKey: areaKey,
            dayIndex: _dayIndex,
            totalDays: list.length,
            dateLabel: day.date,
            onAreaTap: () => _showAreaPicker(context),
            onPrev: _dayIndex > 0 ? () => setState(() => _dayIndex--) : null,
            onNext: _dayIndex < list.length - 1 ? () => setState(() => _dayIndex++) : null,
          ),
          const SizedBox(height: 12),

          // 職業選択（最上部）
          _JobPickerCard(
            selected: _selectedJob,
            onSelect: (j) => setState(() => _selectedJob = j),
          ),
          const SizedBox(height: 12),

          // Hero Overview (Rank + Weather)
          _HeroOverviewCard(day: day),
          const SizedBox(height: 12),

          // 今日の判断材料（重要事実）
          if (day.eventTrafficFacts.isNotEmpty) ...[
            const _SectionTitle(icon: Icons.flash_on, title: '今日の判断材料'),
            const SizedBox(height: 8),
            _FactsCard(facts: day.eventTrafficFacts),
            const SizedBox(height: 12),
          ],

          // ピーク時間（職業別）
          if (peaks.isNotEmpty) ...[
            _SectionTitle(icon: _selectedJob.icon, title: '${_selectedJob.label}のピーク時間'),
            const SizedBox(height: 8),
            _InfoCard(
              leading: const Icon(Icons.access_time),
              title: peaks,
              subtitle: _peakSubtitleFor(jobKey),
            ),
            const SizedBox(height: 12),
          ],

          // 打ち手（要点）：職業別
          _SectionTitle(icon: _selectedJob.icon, title: '${_selectedJob.label}の打ち手（要点）'),
          const SizedBox(height: 8),
          _DecisionCard(
            headline: jobAction.isNotEmpty ? jobAction : '本日は「安全確保」を最優先に、状況で動き方を切り替えるのが鍵です。',
            bullets: _suggestDecisionBullets(day, jobKey),
          ),
          const SizedBox(height: 12),

          // イベント・交通情報（詳細）
          const _SectionTitle(icon: Icons.event, title: 'イベント・交通情報（詳細）'),
          const SizedBox(height: 8),
          _EventTrafficDetailCard(facts: day.eventTrafficFacts, fallbackText: day.dailyScheduleAndImpact),
          const SizedBox(height: 12),

          // 時間ごとの天気＆アドバイス（職業別）
          const _SectionTitle(icon: Icons.schedule, title: '時間ごとの天気＆アドバイス'),
          const SizedBox(height: 8),
          if (day.timeline != null) ...[
            _TimeSlotCard(
              label: '朝（06-12）',
              slot: day.timeline!.morning,
              jobHint: (day.timeline!.morning.advice[jobKey] ?? '').trim(),
            ),
            const SizedBox(height: 10),
            _TimeSlotCard(
              label: '昼（12-18）',
              slot: day.timeline!.daytime,
              jobHint: (day.timeline!.daytime.advice[jobKey] ?? '').trim(),
            ),
            const SizedBox(height: 10),
            _TimeSlotCard(
              label: '夜（18-24）',
              slot: day.timeline!.night,
              jobHint: (day.timeline!.night.advice[jobKey] ?? '').trim(),
            ),
            const SizedBox(height: 12),
          ] else ...[
            _InfoCard(
              leading: const Icon(Icons.info_outline),
              title: '時間帯データがありません',
              subtitle: 'main.py側の天気取得/整形に失敗している可能性があります。',
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  void _showAreaPicker(BuildContext context) {
    final keys = _data.keys.toList()..sort();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            itemCount: keys.length,
            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.08)),
            itemBuilder: (_, i) {
              final k = keys[i];
              final selected = k == _areaKey;
              return ListTile(
                title: Text(
                  _prettyAreaName(k),
                  style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                ),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _areaKey = k;
                    _dayIndex = 0;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  String _prettyAreaName(String areaKey) {
    return areaKey.replaceAll('_', ' ').trim();
  }

  String _peakSubtitleFor(String jobKey) {
    switch (jobKey) {
      case 'taxi':
        return '「混む時間＝取りに行く価値がある時間」です。雪・遅延日はピークが“伸びる/ズレる”傾向があります。';
      case 'delivery':
        return '「注文が集中する時間」を示します。天候が荒れる日は“まとめ注文”が増えやすい前提で調整します。';
      case 'hotel':
        return '「到着/問い合わせが増えやすい時間」の目安です。欠航・遅延日は“チェックイン波”が後ろ倒しになります。';
      case 'restaurant':
        return '「来店/テイクアウトが動く時間」の目安です。悪天候日は“店内減・持ち帰り増”に寄りやすいです。';
      case 'retail':
        return '「購買行動が動く時間」の目安です。荒天日は“短時間集中”になりやすいのでピークが尖ります。';
      case 'care':
        return '「移動/訪問が重なる時間」の目安です。路面状況が悪い日は余裕を見てルート調整します。';
      default:
        return '混みやすい時間帯の目安です。';
    }
  }

  String _jobActionFor(ForecastDay day, String jobKey) {
    // job_actions があれば優先
    final direct = (day.jobActions[jobKey] ?? '').trim();
    if (direct.isNotEmpty) return direct;

    // なければレポートの「■職業別の打ち手（要点）」から抽出
    final report = day.dailyScheduleAndImpact;
    if (report.trim().isEmpty) return '';
    final lines = report.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    // 例：「・タクシー: ...」「タクシー: ...」など
    final jobLabel = _jobLabelForExtraction(jobKey);
    for (final line in lines) {
      if (line.contains(jobLabel) && line.contains(':')) {
        final idx = line.indexOf(':');
        if (idx >= 0 && idx + 1 < line.length) {
          return line.substring(idx + 1).trim();
        }
      }
    }
    return '';
  }

  String _jobLabelForExtraction(String jobKey) {
    switch (jobKey) {
      case 'taxi':
        return 'タクシー';
      case 'delivery':
        return 'デリバリー';
      case 'hotel':
        return 'ホテル';
      case 'restaurant':
        return '飲食';
      case 'retail':
        return '小売';
      case 'care':
        return '介護';
      default:
        return jobKey;
    }
  }

  List<String> _suggestDecisionBullets(ForecastDay day, String jobKey) {
    final rainAm = (day.weatherOverview.rainAm ?? '').trim();
    final rainPm = (day.weatherOverview.rainPm ?? '').trim();
    final warning = day.weatherOverview.warning.trim();

    final bullets = <String>[];

    if (warning.isNotEmpty && warning != '-' && warning != '特になし') {
      bullets.add('⚠️ $warning：無理をしない運用に切替（事故/遅延コストを最小化）');
    }

    if (rainAm.isNotEmpty || rainPm.isNotEmpty) {
      final amTxt = rainAm.isNotEmpty ? rainAm : '-';
      final pmTxt = rainPm.isNotEmpty ? rainPm : '-';
      bullets.add('☔ 午前$amTxt / 午後$pmTxt：需要が動く時間にだけ寄せてムダ待機/ムダ在庫を削る');
    } else {
      bullets.add('☔ 不確実性が高い日は「出る/出ない」より「時間帯で動く」が勝ち筋');
    }

    if (day.eventTrafficFacts.isNotEmpty) {
      bullets.add('🚦 交通の乱れがある日は導線が偏る→“戻り導線”や代替導線を先に決める');
    } else {
      bullets.add('🚦 情報が薄い日は定番導線（駅/病院/商業/幹線）で回転を作る');
    }

    // 職業ごとのワンポイント
    bullets.add(_jobSpecificBullet(jobKey));

    bullets.add('🧠 迷ったら「事故るリスク＞取り逃す損失」：判断基準を先に固定');

    // 空が混ざらないように
    return bullets.where((e) => e.trim().isNotEmpty).toList();
  }

  String _jobSpecificBullet(String jobKey) {
    switch (jobKey) {
      case 'taxi':
        return '🎯 タクシーは「待つ場所」より「取れる時間」を固定すると判断が速い';
      case 'delivery':
        return '🎯 デリバリーは「受ける範囲」と「締める判断」を先に決めて遅配を防ぐ';
      case 'hotel':
        return '🎯 ホテルは「遅延/欠航対応」を最優先。問い合わせ導線と説明文テンプレを用意';
      case 'restaurant':
        return '🎯 飲食は「店内⇄持ち帰り」の比率を可変に。仕込み/人員を時間帯で寄せる';
      case 'retail':
        return '🎯 小売は「午前〜正午」で回収しやすい。レジ/品出し配分をピークに寄せる';
      case 'care':
        return '🎯 介護は「訪問順の最適化」と「時間余裕」の確保。送迎は安全第一で代替連絡を徹底';
      default:
        return '';
    }
  }
}

/// ===============================
/// Widgets
/// ===============================

class _AreaAndDateHeader extends StatelessWidget {
  final String areaKey;
  final int dayIndex;
  final int totalDays;
  final String dateLabel;
  final VoidCallback onAreaTap;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _AreaAndDateHeader({
    required this.areaKey,
    required this.dayIndex,
    required this.totalDays,
    required this.dateLabel,
    required this.onAreaTap,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onAreaTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.place, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'エリア選択',
                      style: t.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Chip(
          label: Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          tooltip: '前日',
        ),
        Text('${dayIndex + 1}/$totalDays', style: t.bodySmall),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: '翌日',
        ),
      ],
    );
  }
}

class _JobPickerCard extends StatelessWidget {
  final JobInfo selected;
  final ValueChanged<JobInfo> onSelect;

  const _JobPickerCard({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('職業を選択', style: t.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kJobs.map((j) {
                final isSel = j.key == selected.key;
                return ChoiceChip(
                  selected: isSel,
                  label: Text(j.label),
                  avatar: Icon(j.icon, size: 18, color: Colors.white),
                  onSelected: (_) => onSelect(j),
                  selectedColor: accent.withOpacity(0.22),
                  backgroundColor: Colors.white.withOpacity(0.06),
                  labelStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: isSel ? accent.withOpacity(0.45) : Colors.white.withOpacity(0.08),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '※「ピーク時間」「打ち手」「時間帯アドバイス」がこの職業に切り替わります。',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroOverviewCard extends StatelessWidget {
  final ForecastDay day;
  const _HeroOverviewCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final rankColor = _rankColor(day.rank);
    final rainAm = day.weatherOverview.rainAm?.trim();
    final rainPm = day.weatherOverview.rainPm?.trim();
    final rainNight = day.weatherOverview.rainNight?.trim();

    final rainLine = (rainAm != null && rainPm != null)
        ? '午前${rainAm} / 午後${rainPm}${(rainNight != null && rainNight.isNotEmpty) ? ' / 夜${rainNight}' : ''}'
        : day.weatherOverview.rain;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rank badge + label ("混雑予測"をランク上へ)
            Column(
              children: [
                Text(
                  '混雑予測',
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: rankColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: rankColor.withOpacity(0.45)),
                  ),
                  child: Center(
                    child: Text(
                      day.rank,
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: rankColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Weather overview (「意思決定ス…」は削除)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(day.weatherOverview.condition, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '天気',
                          style: t.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _miniPill('🌡️ ${day.weatherOverview.high} / ${day.weatherOverview.low}'),
                      _miniPill('☔ $rainLine'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (day.weatherOverview.warning.trim().isNotEmpty && day.weatherOverview.warning.trim() != '-')
                    Text(
                      '⚠️ ${day.weatherOverview.warning}',
                      style: t.bodySmall?.copyWith(color: Colors.white.withOpacity(0.85)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _miniPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.92),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Color _rankColor(String rank) {
    switch (rank.toUpperCase()) {
      case 'S':
        return const Color(0xFFFFD166);
      case 'A':
        return const Color(0xFFFF8F3D);
      case 'B':
        return const Color(0xFF4DD0E1);
      default:
        return const Color(0xFFA0AEC0);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: t.titleMedium),
      ],
    );
  }
}

class _FactsCard extends StatelessWidget {
  final List<String> facts;
  const _FactsCard({required this.facts});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...facts.take(10).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Expanded(child: Text(s, style: t.bodyMedium)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.leading,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  const SizedBox(height: 6),
                  Text(subtitle, style: t.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final String headline;
  final List<String> bullets;

  const _DecisionCard({
    required this.headline,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // headline
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Text(
                headline,
                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 10),

            Text('今日の動き方（迷いを減らす）', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(b, style: t.bodyMedium)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _EventTrafficDetailCard extends StatelessWidget {
  final List<String> facts;
  final String fallbackText;

  const _EventTrafficDetailCard({
    required this.facts,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final items = facts.isNotEmpty ? facts : _extractEventTrafficFromReport(fallbackText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (items.isEmpty)
              Text('特段の情報は見つかりませんでした。', style: t.bodyMedium)
            else
              ...items.take(10).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s, style: t.bodyMedium)),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  static List<String> _extractEventTrafficFromReport(String report) {
    final text = report;
    final start = text.indexOf('■Event & Traffic');
    if (start < 0) return const [];
    final end = text.indexOf('■総括', start);
    final block = (end > start) ? text.substring(start, end) : text.substring(start);
    return block
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.startsWith('■'))
        .take(8)
        .toList();
  }
}

class _TimeSlotCard extends StatelessWidget {
  final String label;
  final SlotWeather slot;
  final String jobHint;

  const _TimeSlotCard({
    required this.label,
    required this.slot,
    required this.jobHint,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row
            Row(
              children: [
                Expanded(
                  child: Text(label, style: t.titleMedium),
                ),
                Text(slot.weather, style: const TextStyle(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _pill('🌡️ 気温 ${slot.temp}'),
                _pill('↕️ 高${slot.tempHigh} / 低${slot.tempLow}'),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(child: _kv('予想降水確率', slot.rain)),
                const SizedBox(width: 10),
                Expanded(child: _kv('予想湿度', slot.humidity)),
              ],
            ),

            if (jobHint.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  jobHint.trim(),
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.92),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text(message, style: t.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              'assets/eagle_eye_data.json を配置しているか、pubspec.yamlでassets登録しているか確認してください。',
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
