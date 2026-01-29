import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const EagleEyeApp());
}

class EagleEyeApp extends StatelessWidget {
  const EagleEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eagle Eye',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const EagleEyeHome(),
    );
  }
}

class EagleEyeHome extends StatefulWidget {
  const EagleEyeHome({super.key});

  @override
  State<EagleEyeHome> createState() => _EagleEyeHomeState();
}

class _EagleEyeHomeState extends State<EagleEyeHome> {
  late Future<EagleEyeData> _future;
  String? _selectedAreaKey;

  @override
  void initState() {
    super.initState();
    _future = EagleEyeData.loadFromAsset('assets/eagle_eye_data.json');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EagleEyeData>(
      future: _future,
      builder: (context, snapshot) {
        final theme = Theme.of(context);

        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Eagle Eye')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Eagle Eye')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'JSON読込エラー: ${snapshot.error}\n\n'
                'assets/eagle_eye_data.json が存在するか、pubspec.yaml に assets 登録されているか確認してください。',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final areaKeys = data.areaKeys;

        // ★ 地域を絞った点の「完璧化」：UI側は一切ハードコードせず JSON から動的生成
        // ＝ main.py が major にしていれば、ここも自動で major のみになる（函館も JSON にある限り残る）
        _selectedAreaKey ??= areaKeys.isNotEmpty ? areaKeys.first : null;

        final selectedKey = _selectedAreaKey;
        final forecasts = selectedKey == null ? <DayForecast>[] : data.byArea[selectedKey] ?? <DayForecast>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Eagle Eye'),
            actions: [
              if (areaKeys.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedKey,
                      items: areaKeys
                          .map((k) => DropdownMenuItem<String>(
                                value: k,
                                child: Text(data.areaLabel(k)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedAreaKey = v),
                    ),
                  ),
                ),
            ],
          ),
          body: forecasts.isEmpty
              ? const Center(child: Text('データがありません'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: forecasts.length,
                  itemBuilder: (context, i) {
                    return DayCard(day: forecasts[i]);
                  },
                ),
        );
      },
    );
  }
}

/// ===========================
/// Data layer
/// ===========================
class EagleEyeData {
  final Map<String, List<DayForecast>> byArea;

  EagleEyeData(this.byArea);

  List<String> get areaKeys => byArea.keys.toList()..sort();

  String areaLabel(String areaKey) {
    final list = byArea[areaKey];
    if (list != null && list.isNotEmpty) {
      final a = list.first.areaName?.trim();
      if (a != null && a.isNotEmpty) return a;
    }
    return areaKey;
  }

  static Future<EagleEyeData> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Root JSON must be an object: { areaKey: [days...] }');
    }

    final out = <String, List<DayForecast>>{};
    decoded.forEach((areaKey, value) {
      if (value is List) {
        out[areaKey] = value
            .map((e) => e is Map<String, dynamic> ? DayForecast.fromJson(e) : null)
            .whereType<DayForecast>()
            .toList();
      } else {
        out[areaKey] = <DayForecast>[];
      }
    });

    return EagleEyeData(out);
  }
}

class DayForecast {
  final String? areaKey;
  final String? areaName;

  final String date; // "MM月dd日 (X)" のラベル
  final bool isLongTerm;

  final String rank; // S/A/B/C
  final List<String> rankReasons; // max 5
  final RankDrivers rankDrivers; // pos/neg
  final String evidenceLevel; // high/med/low
  final int confidence; // 0..100

  final WeatherOverview weatherOverview;
  final List<String> eventTrafficFacts;

  final Map<String, String> peakWindows; // job -> text
  final Map<String, String> jobActions;  // job -> text

  final String dailyScheduleAndImpact;
  final Timeline? timeline;

  const DayForecast({
    required this.areaKey,
    required this.areaName,
    required this.date,
    required this.isLongTerm,
    required this.rank,
    required this.rankReasons,
    required this.rankDrivers,
    required this.evidenceLevel,
    required this.confidence,
    required this.weatherOverview,
    required this.eventTrafficFacts,
    required this.peakWindows,
    required this.jobActions,
    required this.dailyScheduleAndImpact,
    required this.timeline,
  });

  static const _jobs = ['taxi', 'delivery', 'restaurant', 'retail', 'hotel'];

  factory DayForecast.fromJson(Map<String, dynamic> j) {
    String s(dynamic v, [String fallback = '']) => (v == null) ? fallback : v.toString();
    bool b(dynamic v) => v == true;
    int i(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is double) return v.round();
      final parsed = int.tryParse(v?.toString() ?? '');
      return parsed ?? fallback;
    }

    List<String> strList(dynamic v) {
      if (v is List) return v.map((e) => e?.toString().trim() ?? '').where((x) => x.isNotEmpty).toList();
      return const [];
    }

    Map<String, String> jobMap(dynamic v) {
      final out = <String, String>{};
      if (v is Map) {
        for (final k in _jobs) {
          out[k] = (v[k] ?? '').toString().trim();
        }
      } else {
        for (final k in _jobs) {
          out[k] = '';
        }
      }
      return out;
    }

    final rank = s(j['rank'], 'C').trim().toUpperCase();
    final evidence = s(j['evidence_level'], 'low').trim().toLowerCase();
    final conf = i(j['confidence'], 0).clamp(0, 100);

    // UI安全：rankは不正ならCに丸める
    final normalizedRank = {'S', 'A', 'B', 'C'}.contains(rank) ? rank : 'C';
    final normalizedEvidence = {'high', 'med', 'low'}.contains(evidence) ? evidence : 'low';

    return DayForecast(
      areaKey: j['area_key']?.toString(),
      areaName: j['area_name']?.toString(),
      date: s(j['date'], ''),
      isLongTerm: b(j['is_long_term']),
      rank: normalizedRank,
      rankReasons: strList(j['rank_reasons']).take(5).toList(),
      rankDrivers: RankDrivers.fromJson(j['rank_drivers']),
      evidenceLevel: normalizedEvidence,
      confidence: conf,
      weatherOverview: WeatherOverview.fromJson(j['weather_overview']),
      eventTrafficFacts: strList(j['event_traffic_facts']).take(6).toList(),
      peakWindows: jobMap(j['peak_windows']),
      jobActions: jobMap(j['job_actions']),
      dailyScheduleAndImpact: s(j['daily_schedule_and_impact'], ''),
      timeline: Timeline.fromJsonOrNull(j['timeline']),
    );
  }
}

class RankDrivers {
  final List<String> positive;
  final List<String> negative;

  const RankDrivers({required this.positive, required this.negative});

  factory RankDrivers.fromJson(dynamic v) {
    List<String> strList(dynamic x) {
      if (x is List) return x.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
      return const [];
    }

    if (v is Map) {
      return RankDrivers(
        positive: strList(v['positive']).take(5).toList(),
        negative: strList(v['negative']).take(5).toList(),
      );
    }
    return const RankDrivers(positive: [], negative: []);
    }
}

class WeatherOverview {
  final String condition; // emoji
  final String high;      // "最高xx℃"
  final String low;       // "最低xx℃"
  final String rain;      // "午前.. / 午後.."
  final String? rainAm;
  final String? rainPm;
  final String? rainNight;
  final String warning;

  const WeatherOverview({
    required this.condition,
    required this.high,
    required this.low,
    required this.rain,
    required this.rainAm,
    required this.rainPm,
    required this.rainNight,
    required this.warning,
  });

  factory WeatherOverview.fromJson(dynamic v) {
    String s(dynamic x, [String fallback = '-']) => (x == null) ? fallback : x.toString();
    if (v is Map) {
      return WeatherOverview(
        condition: s(v['condition'], '☁️'),
        high: s(v['high'], '-'),
        low: s(v['low'], '-'),
        rain: s(v['rain'], '-'),
        rainAm: v['rain_am'] == null ? null : v['rain_am'].toString(),
        rainPm: v['rain_pm'] == null ? null : v['rain_pm'].toString(),
        rainNight: v['rain_night'] == null ? null : v['rain_night'].toString(),
        warning: s(v['warning'], '-'),
      );
    }
    return const WeatherOverview(
      condition: '☁️',
      high: '-',
      low: '-',
      rain: '-',
      rainAm: null,
      rainPm: null,
      rainNight: null,
      warning: '-',
    );
  }
}

class Timeline {
  final TimelineSlot morning;
  final TimelineSlot daytime;
  final TimelineSlot night;

  const Timeline({required this.morning, required this.daytime, required this.night});

  static Timeline? fromJsonOrNull(dynamic v) {
    if (v is! Map) return null;
    return Timeline(
      morning: TimelineSlot.fromJson(v['morning']),
      daytime: TimelineSlot.fromJson(v['daytime']),
      night: TimelineSlot.fromJson(v['night']),
    );
  }
}

class TimelineSlot {
  final String weather;
  final String temp;
  final String tempHigh;
  final String tempLow;
  final String humidity;
  final String rain;
  final Map<String, String> advice; // job -> text

  const TimelineSlot({
    required this.weather,
    required this.temp,
    required this.tempHigh,
    required this.tempLow,
    required this.humidity,
    required this.rain,
    required this.advice,
  });

  static const _jobs = ['taxi', 'delivery', 'restaurant', 'retail', 'hotel'];

  factory TimelineSlot.fromJson(dynamic v) {
    String s(dynamic x, [String fallback = '-']) => (x == null) ? fallback : x.toString();
    Map<String, String> adv(dynamic x) {
      final out = <String, String>{};
      if (x is Map) {
        for (final k in _jobs) {
          out[k] = (x[k] ?? '').toString().trim();
        }
      } else {
        for (final k in _jobs) {
          out[k] = '';
        }
      }
      return out;
    }

    if (v is Map) {
      return TimelineSlot(
        weather: s(v['weather'], '☁️'),
        temp: s(v['temp'], '-'),
        tempHigh: s(v['temp_high'], '-'),
        tempLow: s(v['temp_low'], '-'),
        humidity: s(v['humidity'], '-'),
        rain: s(v['rain'], '-'),
        advice: adv(v['advice']),
      );
    }
    return TimelineSlot(
      weather: '☁️',
      temp: '-',
      tempHigh: '-',
      tempLow: '-',
      humidity: '-',
      rain: '-',
      advice: {for (final k in _jobs) k: ''},
    );
  }
}

/// ===========================
/// UI layer
/// ===========================
class DayCard extends StatelessWidget {
  final DayForecast day;
  const DayCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rankColor = _rankColor(day.rank, theme.colorScheme);
    final evidenceText = _evidenceLabel(day.evidenceLevel);
    final confText = '${day.confidence}%';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: date + rank badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    day.date,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _RankBadge(rank: day.rank, color: rankColor),
              ],
            ),
            const SizedBox(height: 6),

            // Evidence row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(text: '根拠: $evidenceText'),
                _Chip(text: '信頼度: $confText'),
                if (day.isLongTerm) const _Chip(text: '長期予測'),
              ],
            ),

            const SizedBox(height: 10),

            // Weather overview
            _SectionTitle(icon: Icons.cloud, title: '天気'),
            Text(
              '${day.weatherOverview.condition}  ${day.weatherOverview.high} / ${day.weatherOverview.low}  ｜  降水: ${day.weatherOverview.rain}',
              style: theme.textTheme.bodyMedium,
            ),
            if (day.weatherOverview.warning.trim().isNotEmpty && day.weatherOverview.warning != '-')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('注意: ${day.weatherOverview.warning}', style: theme.textTheme.bodySmall),
              ),

            const SizedBox(height: 10),

            // Rank reasons
            if (day.rankReasons.isNotEmpty) ...[
              _SectionTitle(icon: Icons.fact_check, title: 'ランク根拠'),
              ...day.rankReasons.map((s) => _Bullet(s)).toList(),
              const SizedBox(height: 10),
            ],

            // Drivers
            if (day.rankDrivers.positive.isNotEmpty || day.rankDrivers.negative.isNotEmpty) ...[
              _SectionTitle(icon: Icons.trending_up, title: '増減要因'),
              if (day.rankDrivers.positive.isNotEmpty) ...[
                Text('増える', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ...day.rankDrivers.positive.map((s) => _Bullet(s)).toList(),
              ],
              if (day.rankDrivers.negative.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('減る', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ...day.rankDrivers.negative.map((s) => _Bullet(s)).toList(),
              ],
              const SizedBox(height: 10),
            ],

            // Event / Traffic facts
            if (day.eventTrafficFacts.isNotEmpty) ...[
              _SectionTitle(icon: Icons.directions, title: 'イベント・交通（要点）'),
              ...day.eventTrafficFacts.map((s) => _Bullet(s)).toList(),
              const SizedBox(height: 10),
            ],

            // Job actions
            _SectionTitle(icon: Icons.work, title: '職業別の打ち手（要点）'),
            _JobRow(label: 'タクシー', value: day.jobActions['taxi'] ?? ''),
            _JobRow(label: 'デリバリー', value: day.jobActions['delivery'] ?? ''),
            _JobRow(label: '飲食店', value: day.jobActions['restaurant'] ?? ''),
            _JobRow(label: '小売', value: day.jobActions['retail'] ?? ''),
            _JobRow(label: 'ホテル', value: day.jobActions['hotel'] ?? ''),

            const SizedBox(height: 10),

            // Timeline (optional)
            if (day.timeline != null) ...[
              _SectionTitle(icon: Icons.schedule, title: '時間帯'),
              _SlotCard(title: '朝', slot: day.timeline!.morning),
              const SizedBox(height: 8),
              _SlotCard(title: '昼', slot: day.timeline!.daytime),
              const SizedBox(height: 8),
              _SlotCard(title: '夜', slot: day.timeline!.night),
              const SizedBox(height: 10),
            ],

            // Report text
            if (day.dailyScheduleAndImpact.trim().isNotEmpty) ...[
              _SectionTitle(icon: Icons.description, title: 'レポート'),
              Text(day.dailyScheduleAndImpact, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  static Color _rankColor(String rank, ColorScheme scheme) {
    switch (rank) {
      case 'S':
        return scheme.error;
      case 'A':
        return Colors.orange;
      case 'B':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  static String _evidenceLabel(String ev) {
    switch (ev) {
      case 'high':
        return '高';
      case 'med':
        return '中';
      default:
        return '低';
    }
  }
}

class _RankBadge extends StatelessWidget {
  final String rank;
  final Color color;
  const _RankBadge({required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Rank $rank',
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _JobRow extends StatelessWidget {
  final String label;
  final String value;
  const _JobRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text(v, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final String title;
  final TimelineSlot slot;

  const _SlotCard({required this.title, required this.slot});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String v(String s) => s.trim().isEmpty ? '—' : s.trim();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title  ${slot.weather}  ${slot.temp}（高${slot.tempHigh} 低${slot.tempLow}）  湿度${slot.humidity}  降水${slot.rain}',
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('アドバイス', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _mini('タクシー', v(slot.advice['taxi'] ?? '')),
          _mini('デリバリー', v(slot.advice['delivery'] ?? '')),
          _mini('飲食店', v(slot.advice['restaurant'] ?? '')),
          _mini('小売', v(slot.advice['retail'] ?? '')),
          _mini('ホテル', v(slot.advice['hotel'] ?? '')),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
