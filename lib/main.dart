import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const EagleEyeApp());
}

/// ===========================
/// App
/// ===========================
class EagleEyeApp extends StatelessWidget {
  const EagleEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Navy-first, Material3 dark theme
    const navyBg = Color(0xFF0B1220);
    const cardBg = Color(0x1AFFFFFF); // 10% white
    const cardBorder = Color(0x22FFFFFF);

    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ).copyWith(
      background: navyBg,
      surface: const Color(0xFF101A2E),
    );

    return MaterialApp(
      title: 'Eagle Eye',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: navyBg,
        cardColor: cardBg,
        dividerColor: Colors.white.withOpacity(0.12),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w800),
          titleSmall: TextStyle(fontWeight: FontWeight.w800),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: cardBorder, width: 1),
          ),
        ),
      ),
      home: const EagleEyeHome(),
    );
  }
}

/// ===========================
/// Home
/// - Today/Tomorrow/DayAfter: PageView (swipe)
/// - Later days: Calendar screen
/// - Job selector: Bottom (B)
/// ===========================
class EagleEyeHome extends StatefulWidget {
  const EagleEyeHome({super.key});

  @override
  State<EagleEyeHome> createState() => _EagleEyeHomeState();
}

class _EagleEyeHomeState extends State<EagleEyeHome> {
  late Future<EagleEyeData> _future;
  String? _selectedAreaKey;

  String _selectedJobKey = JobKeys.taxi; // default

  final PageController _pageController = PageController(initialPage: 0);
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = EagleEyeData.loadFromAsset('assets/eagle_eye_data.json');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openCalendar(BuildContext context, List<DayForecast> forecasts, String areaLabel) async {
    final base = _baseTodayLocal();
    final last = base.add(Duration(days: (forecasts.isNotEmpty ? forecasts.length - 1 : 0)));

    final picked = await Navigator.of(context).push<DateTime?>(
      MaterialPageRoute(
        builder: (_) => CalendarScreen(
          title: 'カレンダー － $areaLabel',
          firstDate: base,
          lastDate: last,
          initialDate: base.add(Duration(days: _pageIndex.clamp(0, 2))),
          forecasts: forecasts,
          baseDate: base,
          selectedJobKey: _selectedJobKey,
        ),
      ),
    );

    if (picked == null) return;

    final idx = picked.difference(base).inDays;
    if (idx >= 0 && idx < forecasts.length) {
      // if within 0..2, jump page; else stay (calendar used for later)
      if (idx <= 2) {
        _pageController.jumpToPage(idx);
        setState(() => _pageIndex = idx);
      } else {
        // optional: show a dialog/preview for later day - already handled inside CalendarScreen
      }
    }
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

        // UI側はハードコードしない：JSONから動的生成
        _selectedAreaKey ??= areaKeys.isNotEmpty ? areaKeys.first : null;

        final selectedKey = _selectedAreaKey;
        final forecasts = selectedKey == null ? <DayForecast>[] : (data.byArea[selectedKey] ?? <DayForecast>[]);

        final areaLabel = selectedKey == null ? '' : data.areaLabel(selectedKey);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Eagle Eye'),
                const SizedBox(width: 10),
                if (areaLabel.isNotEmpty)
                  Text(
                    areaLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.78),
                    ),
                  ),
              ],
            ),
            actions: [
              if (forecasts.isNotEmpty)
                IconButton(
                  tooltip: 'カレンダー',
                  onPressed: () => _openCalendar(context, forecasts, areaLabel),
                  icon: const Icon(Icons.calendar_month),
                ),
              if (areaKeys.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedKey,
                      dropdownColor: const Color(0xFF101A2E),
                      items: areaKeys
                          .map(
                            (k) => DropdownMenuItem<String>(
                              value: k,
                              child: Text(data.areaLabel(k)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedAreaKey = v;
                          _pageIndex = 0;
                          _pageController.jumpToPage(0);
                        });
                      },
                    ),
                  ),
                ),
            ],
          ),
          body: forecasts.isEmpty
              ? const Center(child: Text('データがありません'))
              : Column(
                  children: [
                    // Swipable pages for first 3 days
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _min(3, forecasts.length),
                        onPageChanged: (i) => setState(() => _pageIndex = i),
                        itemBuilder: (context, i) {
                          final label = (i == 0) ? '今日' : (i == 1) ? '明日' : '明後日';
                          return SingleChildScrollView(
                            // ★ bottom job bar + safe area 分の余白を増やす
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 92),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TopPills(
                                  left: label,
                                  right: forecasts[i].date,
                                ),
                                const SizedBox(height: 10),
                                DayCard(
                                  day: forecasts[i],
                                  selectedJobKey: _selectedJobKey,
                                ),
                                const SizedBox(height: 16),
                                const _HintRow(
                                  icon: Icons.swipe,
                                  text: '左右にスワイプで 今日〜明後日',
                                ),
                                const SizedBox(height: 8),
                                const _HintRow(
                                  icon: Icons.calendar_month,
                                  text: '4日目以降はカレンダーから',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          // Bottom job selector (B)
          bottomNavigationBar: JobSelectorBar(
            selectedJobKey: _selectedJobKey,
            onChanged: (k) => setState(() => _selectedJobKey = k),
          ),
        );
      },
    );
  }

  static int _min(int a, int b) => a < b ? a : b;

  DateTime _baseTodayLocal() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

/// ===========================
/// Calendar Screen (later days)
/// ===========================
class CalendarScreen extends StatefulWidget {
  final String title;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime initialDate;

  final List<DayForecast> forecasts;
  final DateTime baseDate;

  final String selectedJobKey;

  const CalendarScreen({
    super.key,
    required this.title,
    required this.firstDate,
    required this.lastDate,
    required this.initialDate,
    required this.forecasts,
    required this.baseDate,
    required this.selectedJobKey,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  DayForecast? _forecastFor(DateTime d) {
    final idx = d.difference(widget.baseDate).inDays;
    if (idx < 0 || idx >= widget.forecasts.length) return null;
    return widget.forecasts[idx];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = _forecastFor(_selected);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CalendarDatePicker(
                initialDate: _selected,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                onDateChanged: (d) => setState(() => _selected = d),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (day == null)
            Text('この日のデータがありません', style: theme.textTheme.bodyMedium)
          else
            DayCard(
              day: day,
              selectedJobKey: widget.selectedJobKey,
              compactHeader: true,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(_selected),
        icon: const Icon(Icons.check),
        label: const Text('この日へ'),
      ),
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

  final String date; // "MM月dd日 (X)"
  final bool isLongTerm;

  final String rank; // S/A/B/C
  final List<String> rankReasons; // max 5
  final RankDrivers rankDrivers; // pos/neg
  final String evidenceLevel; // high/med/low (UIには出さない)
  final int confidence; // 0..100 (UIには出さない)

  final WeatherOverview weatherOverview;
  final List<String> eventTrafficFacts;

  final Map<String, String> peakWindows;
  final Map<String, String> jobActions;

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

  static const _jobs = JobKeys.all;

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
      if (v is List) {
        return v.map((e) => e?.toString().trim() ?? '').where((x) => x.isNotEmpty).toList();
      }
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
      if (x is List) {
        return x.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
      }
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
  final String high; // "最高xx℃"
  final String low; // "最低xx℃"
  final String rain; // "午前.. / 午後.."
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

  static const _jobs = JobKeys.all;

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
  final String selectedJobKey;
  final bool compactHeader;

  const DayCard({
    super.key,
    required this.day,
    required this.selectedJobKey,
    this.compactHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rankColor = _rankColor(day.rank);
    final jobLabel = JobKeys.label(selectedJobKey);

    final keyFacts = _pickKeyFacts(day);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    day.date,
                    style: (compactHeader ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                _RankBadge(rank: day.rank, color: rankColor),
              ],
            ),
            const SizedBox(height: 10),

            // Weather overview (strong visual)
            _SectionTitle(icon: Icons.cloud, title: '天気'),
            const SizedBox(height: 6),
            _InfoLine(
              leading: day.weatherOverview.condition,
              text:
                  '${day.weatherOverview.high} / ${day.weatherOverview.low}   •   降水 ${day.weatherOverview.rain}',
            ),
            if (day.weatherOverview.warning.trim().isNotEmpty && day.weatherOverview.warning != '-')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _InfoLine(
                  leading: '⚠️',
                  text: '注意 ${day.weatherOverview.warning}',
                  emphasis: true,
                ),
              ),

            const SizedBox(height: 14),

            // Key facts (instead of "根拠/信頼度")
            if (keyFacts.isNotEmpty) ...[
              _SectionTitle(icon: Icons.bolt, title: '今日の要点'),
              const SizedBox(height: 6),
              ...keyFacts.map((s) => _Bullet(s)).toList(),
              const SizedBox(height: 14),
            ],

            // Rank reasons (optional; keep but not noisy)
            if (day.rankReasons.isNotEmpty) ...[
              _SectionTitle(icon: Icons.fact_check, title: '見立て'),
              const SizedBox(height: 6),
              ...day.rankReasons.map((s) => _Bullet(s)).toList(),
              const SizedBox(height: 14),
            ],

            // Job action (personalized)
            _SectionTitle(icon: Icons.work, title: 'あなた向け（$jobLabel）'),
            const SizedBox(height: 6),
            _ActionBox(
              text: (day.jobActions[selectedJobKey] ?? '').trim().isEmpty
                  ? '—'
                  : (day.jobActions[selectedJobKey] ?? '').trim(),
            ),

            const SizedBox(height: 14),

            // Timeline (show only selected job advice)
            if (day.timeline != null) ...[
              _SectionTitle(icon: Icons.schedule, title: '時間帯'),
              const SizedBox(height: 6),
              _SlotCard(title: '朝', slot: day.timeline!.morning, jobKey: selectedJobKey),
              const SizedBox(height: 10),
              _SlotCard(title: '昼', slot: day.timeline!.daytime, jobKey: selectedJobKey),
              const SizedBox(height: 10),
              _SlotCard(title: '夜', slot: day.timeline!.night, jobKey: selectedJobKey),
              const SizedBox(height: 14),
            ],

            // Report text
            if (day.dailyScheduleAndImpact.trim().isNotEmpty) ...[
              _SectionTitle(icon: Icons.description, title: 'レポート'),
              const SizedBox(height: 6),
              Text(
                day.dailyScheduleAndImpact.trim(),
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.85), height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static List<String> _pickKeyFacts(DayForecast day) {
    // Prefer event/traffic facts; fallback to drivers
    final out = <String>[];

    for (final s in day.eventTrafficFacts) {
      if (out.length >= 3) break;
      out.add(s);
    }
    if (out.isNotEmpty) return out;

    // fallback
    for (final s in day.rankDrivers.positive) {
      if (out.length >= 2) break;
      out.add('増える: $s');
    }
    for (final s in day.rankDrivers.negative) {
      if (out.length >= 3) break;
      out.add('減る: $s');
    }
    return out;
  }

  static Color _rankColor(String rank) {
    switch (rank) {
      case 'S':
        return const Color(0xFFFF5C6C);
      case 'A':
        return const Color(0xFFFFB020);
      case 'B':
        return const Color(0xFF4EA1FF);
      default:
        return const Color(0xFFB3B7C3);
    }
  }
}

class _TopPills extends StatelessWidget {
  final String left;
  final String right;
  const _TopPills({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Pill(text: left, strong: true),
        const SizedBox(width: 8),
        _Pill(text: right, strong: false),
        const Spacer(),
        Icon(Icons.keyboard_arrow_left, color: Colors.white.withOpacity(0.5), size: 18),
        Icon(Icons.keyboard_arrow_right, color: Colors.white.withOpacity(0.5), size: 18),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool strong;
  const _Pill({required this.text, required this.strong});

  @override
  Widget build(BuildContext context) {
    final color = strong ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.10);
    final border = Colors.white.withOpacity(0.14);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              color: Colors.white.withOpacity(0.92),
            ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final String rank;
  final Color color;
  const _RankBadge({required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        border: Border.all(color: color.withOpacity(0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Rank $rank',
        style: TextStyle(fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white.withOpacity(0.9)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.92),
              ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String leading;
  final String text;
  final bool emphasis;

  const _InfoLine({
    required this.leading,
    required this.text,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withOpacity(emphasis ? 0.95 : 0.85),
          fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(leading, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white.withOpacity(0.88),
          height: 1.45,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: style),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

class _ActionBox extends StatelessWidget {
  final String text;
  const _ActionBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withOpacity(0.08);
    final border = Colors.white.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.92),
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final String title;
  final TimelineSlot slot;
  final String jobKey;

  const _SlotCard({
    required this.title,
    required this.slot,
    required this.jobKey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String v(String s) => s.trim().isEmpty ? '—' : s.trim();
    final advice = v(slot.advice[jobKey] ?? '');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title  ${slot.weather}  ${slot.temp}（高${slot.tempHigh} 低${slot.tempLow}）  湿度${slot.humidity}  降水${slot.rain}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.92),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'アドバイス（${JobKeys.label(jobKey)}）',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            advice,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.86),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.55)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.62)),
          ),
        ),
      ],
    );
  }
}

/// ===========================
/// Bottom Job Selector (B)
/// ===========================
class JobSelectorBar extends StatelessWidget {
  final String selectedJobKey;
  final ValueChanged<String> onChanged;

  const JobSelectorBar({
    super.key,
    required this.selectedJobKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0B1220);
    final border = Colors.white.withOpacity(0.12);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 74, // ★固定（暴走防止）
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: bg.withOpacity(0.92),
            border: Border(top: BorderSide(color: border)),
          ),
          child: Row(
            children: [
              for (final k in JobKeys.all) ...[
                Expanded(
                  child: _JobTab(
                    label: JobKeys.shortLabel(k),
                    isActive: k == selectedJobKey,
                    onTap: () => onChanged(k),
                  ),
                ),
                if (k != JobKeys.all.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JobTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _JobTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = isActive;

    final bg = active ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.08);
    final border = active ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.12);
    final textColor = active ? Colors.white.withOpacity(0.95) : Colors.white.withOpacity(0.75);

    return SizedBox(
      height: 46, // ★固定（縦伸び防止）
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                color: textColor,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===========================
/// Job keys / labels
/// ===========================
class JobKeys {
  static const taxi = 'taxi';
  static const delivery = 'delivery';
  static const restaurant = 'restaurant';
  static const retail = 'retail';
  static const hotel = 'hotel';

  static const all = [taxi, delivery, restaurant, retail, hotel];

  static String label(String k) {
    switch (k) {
      case taxi:
        return 'タクシー';
      case delivery:
        return 'デリバリー';
      case restaurant:
        return '飲食店';
      case retail:
        return '小売';
      case hotel:
        return 'ホテル';
      default:
        return k;
    }
  }

  static String shortLabel(String k) {
    switch (k) {
      case taxi:
        return 'Taxi';
      case delivery:
        return 'Delivery';
      case restaurant:
        return 'Food';
      case retail:
        return 'Retail';
      case hotel:
        return 'Hotel';
      default:
        return k;
    }
  }
}
