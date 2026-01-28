import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// ===============================
/// Eagle Eye - main.dart
/// - assets/eagle_eye_data.json を読み込み
/// - main.py(v5.1)の新フィールドに対応
/// - 視認性（文字色/コントラスト）を改善
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
    // ===== Palette（コントラスト重視）=====
    const bg = Color(0xFF0B1220);
    const card = Color(0xFF111F34);      // ほんの少し明るく
    const card2 = Color(0xFF142844);     // 内側ブロック用
    const accent = Color(0xFFFFA135);

    // 文字色（強制的に明るく）
    const fg = Color(0xFFEAF0FF);        // ほぼ白
    const fgSoft = Color(0xFFB9C7E6);    // 説明文
    const fgMuted = Color(0xFF92A3C7);   // 補助

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      secondary: accent,
      background: bg,
      surface: card,
      // 重要：onX を “明るい色”で固定（黒化事故を防ぐ）
      onBackground: fg,
      onSurface: fg,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
    );

    final textTheme = base.textTheme
        .apply(bodyColor: fg, displayColor: fg)
        .copyWith(
          titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg),
          titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg),
          bodyLarge: const TextStyle(fontSize: 15, height: 1.55, color: fg),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.60, color: fg),
          bodySmall: const TextStyle(fontSize: 12, height: 1.50, color: fgSoft),
          labelLarge: const TextStyle(color: fg),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        foregroundColor: fg, // AppBarの文字・アイコンを白固定
      ),
      iconTheme: const IconThemeData(color: fg),
      dividerTheme: base.dividerTheme.copyWith(
        color: fg.withOpacity(0.12),
        thickness: 1,
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: fg,
        iconColor: fg,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: accent.withOpacity(0.18),
        labelStyle: const TextStyle(color: fg, fontWeight: FontWeight.w800),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      // ここも事故が出やすいので固定
      expansionTileTheme: ExpansionTileThemeData(
        textColor: fg,
        iconColor: fg,
        collapsedTextColor: fgSoft,
        collapsedIconColor: fgSoft,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // 内側ブロックの背景色を少し持ち上げる
      extensions: <ThemeExtension<dynamic>>[
        _EagleEyeColors(card2: card2, fg: fg, fgSoft: fgSoft, fgMuted: fgMuted),
      ],
    );
  }
}

/// 内側ブロックで使う色（Theme拡張）
class _EagleEyeColors extends ThemeExtension<_EagleEyeColors> {
  final Color card2;
  final Color fg;
  final Color fgSoft;
  final Color fgMuted;

  const _EagleEyeColors({
    required this.card2,
    required this.fg,
    required this.fgSoft,
    required this.fgMuted,
  });

  @override
  _EagleEyeColors copyWith({Color? card2, Color? fg, Color? fgSoft, Color? fgMuted}) {
    return _EagleEyeColors(
      card2: card2 ?? this.card2,
      fg: fg ?? this.fg,
      fgSoft: fgSoft ?? this.fgSoft,
      fgMuted: fgMuted ?? this.fgMuted,
    );
  }

  @override
  _EagleEyeColors lerp(ThemeExtension<_EagleEyeColors>? other, double t) {
    if (other is! _EagleEyeColors) return this;
    return _EagleEyeColors(
      card2: Color.lerp(card2, other.card2, t) ?? card2,
      fg: Color.lerp(fg, other.fg, t) ?? fg,
      fgSoft: Color.lerp(fgSoft, other.fgSoft, t) ?? fgSoft,
      fgMuted: Color.lerp(fgMuted, other.fgMuted, t) ?? fgMuted,
    );
  }
}

/// ===============================
/// Data Models (ゆるめ：壊れに強く)
/// ===============================

class ForecastDay {
  final String date; // "01月27日 (火)"
  final bool isLongTerm;
  final String rank; // S/A/B/C
  final WeatherOverview weatherOverview;
  final List<String> eventTrafficFacts; // 最大6想定
  final Map<String, String> peakWindows; // taxi/delivery/...
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
  /// assets/eagle_eye_data.json を読む
  Future<Map<String, List<ForecastDay>>> load() async {
    final raw = await rootBundle.loadString('assets/eagle_eye_data.json');
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

          _HeroOverviewCard(day: day),
          const SizedBox(height: 12),

          if (day.eventTrafficFacts.isNotEmpty) ...[
            _SectionTitle(icon: Icons.flash_on, title: '今日の判断材料'),
            const SizedBox(height: 8),
            _FactsCard(facts: day.eventTrafficFacts),
            const SizedBox(height: 12),
          ],

          final taxiPeaks = (day.peakWindows['taxi'] ?? '').trim();
          if (taxiPeaks.isNotEmpty) ...[
            _SectionTitle(icon: Icons.local_taxi, title: 'タクシーのピーク時間'),
            const SizedBox(height: 8),
            _InfoCard(
              leading: const Icon(Icons.access_time),
              title: taxiPeaks,
              subtitle: '「混む時間＝取りに行く価値がある時間」です。雪・遅延日はピークが“伸びる”傾向があります。',
            ),
            const SizedBox(height: 12),
          ],

          final taxiKeypoint = _extractJobKeypoint(day.dailyScheduleAndImpact, 'タクシー');
          _SectionTitle(icon: Icons.local_taxi, title: 'タクシーの打ち手（要点）'),
          const SizedBox(height: 8),
          _DecisionCard(
            headline: taxiKeypoint.isNotEmpty
                ? taxiKeypoint
                : '本日は「安全確保」を最優先に、状況で“取りに行く時間”を切り替える設計が鍵です。',
            bullets: _suggestDecisionBullets(day),
          ),
          const SizedBox(height: 12),

          _SectionTitle(icon: Icons.event, title: 'イベント・交通情報（詳細）'),
          const SizedBox(height: 8),
          _EventTrafficDetailCard(facts: day.eventTrafficFacts, fallbackText: day.dailyScheduleAndImpact),
          const SizedBox(height: 12),

          _SectionTitle(icon: Icons.schedule, title: '時間ごとの天気＆アドバイス'),
          const SizedBox(height: 8),
          if (day.timeline != null) ...[
            _TimeSlotCard(
              label: '朝（06-12）',
              slot: day.timeline!.morning,
              jobHint: day.timeline!.morning.advice['taxi'] ?? '',
            ),
            const SizedBox(height: 10),
            _TimeSlotCard(
              label: '昼（12-18）',
              slot: day.timeline!.daytime,
              jobHint: day.timeline!.daytime.advice['taxi'] ?? '',
            ),
            const SizedBox(height: 10),
            _TimeSlotCard(
              label: '夜（18-24）',
              slot: day.timeline!.night,
              jobHint: day.timeline!.night.advice['taxi'] ?? '',
            ),
            const SizedBox(height: 12),
          ] else ...[
            _InfoCard(
              leading: const Icon(Icons.info_outline),
              title: '時間帯データがありません',
              subtitle: 'main.py側のOpen-Meteo取得/整形に失敗している可能性があります。',
            ),
            const SizedBox(height: 12),
          ],

          _SectionTitle(icon: Icons.lightbulb, title: '今日のレポート（詳細）'),
          const SizedBox(height: 8),
          _ReportCard(reportText: day.dailyScheduleAndImpact),
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
            separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.10)),
            itemBuilder: (_, i) {
              final k = keys[i];
              final selected = k == _areaKey;
              return ListTile(
                title: Text(
                  _prettyAreaName(k),
                  style: TextStyle(fontWeight: selected ? FontWeight.w900 : FontWeight.w700),
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

  String _extractJobKeypoint(String report, String jobName) {
    if (report.trim().isEmpty) return '';
    final lines = report.split('\n').map((e) => e.trim()).toList();

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (line.contains(jobName) && line.contains(':')) {
        final idx = line.indexOf(':');
        if (idx >= 0 && idx + 1 < line.length) {
          return line.substring(idx + 1).trim();
        }
      }
    }
    return '';
  }

  List<String> _suggestDecisionBullets(ForecastDay day) {
    final rainAm = (day.weatherOverview.rainAm ?? '').trim();
    final rainPm = (day.weatherOverview.rainPm ?? '').trim();
    final warning = day.weatherOverview.warning.trim();

    final bullets = <String>[];

    if (warning.isNotEmpty && warning != '-' && warning != '特になし') {
      bullets.add('⚠️ $warning：無理に取りに行かず“安全優先の稼ぎ方”へ切替');
    }

    if (rainAm.isNotEmpty || rainPm.isNotEmpty) {
      bullets.add('☔ 午前$rainAm / 午後$rainPm：需要が動く時間にだけ寄せる（ムダ待機を削る）');
    } else {
      bullets.add('☔ 降水の不確実性が高い日は「出る/出ない」ではなく「時間帯で出る」が勝ち筋');
    }

    if (day.eventTrafficFacts.isNotEmpty) {
      bullets.add('🚦 交通の乱れがある日は「目的地の偏り」が出る→“人が戻る導線”を押さえる');
    } else {
      bullets.add('🚦 交通情報が薄い日は、駅・病院・商業施設など“定番導線”の回転で拾う');
    }

    bullets.add('🧠 迷ったら「事故るリスク＞取り逃す損失」：判断基準を先に固定');

    return bullets;
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
            const SizedBox(width: 14),
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
                          '混雑予測（意思決定スコア）',
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
                      style: t.bodySmall,
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
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800),
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
            Text('“今日の判断が変わる情報”だけを短く。', style: t.bodySmall),
            const SizedBox(height: 10),
            ...facts.take(8).map((s) => Padding(
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
    final ext = Theme.of(context).extension<_EagleEyeColors>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Text(
                headline,
                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w900, color: ext.fg),
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
                      Icon(Icons.check_circle_outline, size: 18, color: ext.fg),
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
    final ext = Theme.of(context).extension<_EagleEyeColors>()!;

    final items = facts.isNotEmpty ? facts : _extractEventTrafficFromReport(fallbackText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('読みやすさ優先で、1要点=1ブロックに整理。', style: t.bodySmall),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Text('特段の情報は見つかりませんでした。', style: t.bodyMedium)
            else
              ...items.take(10).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ext.card2.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.10)),
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
    final ext = Theme.of(context).extension<_EagleEyeColors>()!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: t.titleMedium)),
                Text(slot.weather, style: const TextStyle(fontSize: 20)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _pill('🌡️ 気温 ${slot.temp}'),
                _pill('↕️ 最高${slot.tempHigh} / 最低${slot.tempLow}'),
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
                  color: ext.card2.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
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
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w800),
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.80), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String reportText;
  const _ReportCard({required this.reportText});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final summary = _extractSection(reportText, '■総括');
    final actions = _extractSection(reportText, '■職業別の打ち手（要点）');

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text('開くと「総括」と「職業別の要点」だけ表示します', style: t.bodySmall),
        children: [
          if (summary.isNotEmpty) ...[
            Text('総括', style: t.titleMedium),
            const SizedBox(height: 6),
            Text(summary, style: t.bodyMedium),
            const SizedBox(height: 12),
          ],
          if (actions.isNotEmpty) ...[
            Text('職業別の打ち手（要点）', style: t.titleMedium),
            const SizedBox(height: 6),
            _prettyBullets(actions),
          ],
          if (summary.isEmpty && actions.isEmpty) Text('レポートが空です。', style: t.bodyMedium),
        ],
      ),
    );
  }

  static String _extractSection(String text, String header) {
    if (text.trim().isEmpty) return '';
    final start = text.indexOf(header);
    if (start < 0) return '';
    final rest = text.substring(start + header.length);
    final next = rest.indexOf('\n■');
    final block = (next >= 0) ? rest.substring(0, next) : rest;
    return block
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n')
        .trim();
  }

  static Widget _prettyBullets(String text) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final bulletLines = lines.where((l) => l.startsWith('・')).toList();
    final items = bulletLines.isNotEmpty ? bulletLines : lines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((l) {
        final line = l.startsWith('・') ? l.substring(1).trim() : l;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white.withOpacity(0.92))),
              Expanded(child: Text(line, style: TextStyle(color: Colors.white.withOpacity(0.96), height: 1.55))),
            ],
          ),
        );
      }).toList(),
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
