import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const EagleEyeApp());
}

/// ===========================
/// Theme constants
/// ===========================
const kNavyBg = Color(0xFF0B1220);
const kSurface = Color(0xFF101A2E);
const kCardBg = Color(0x1AFFFFFF); // 10% white
const kCardBorder = Color(0x22FFFFFF);
const kAccentOrange = Color(0xFFFFB020);

class EagleEyeApp extends StatelessWidget {
  const EagleEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ).copyWith(
      background: kNavyBg,
      surface: kSurface,
    );

    return MaterialApp(
      title: 'Eagle Eye',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: kNavyBg,
        dividerColor: Colors.white.withOpacity(0.12),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w900),
          titleMedium: TextStyle(fontWeight: FontWeight.w900),
          titleSmall: TextStyle(fontWeight: FontWeight.w900),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: kNavyBg.withOpacity(0.92),
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardTheme(
          color: kCardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kCardBorder, width: 1),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: const TextStyle(color: Colors.white),
          menuStyle: MenuStyle(
            // Flutter 3.19: MaterialStateProperty (WidgetStateProperty is newer)
            backgroundColor: MaterialStateProperty.all(kSurface),
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
/// - Region/Job are fixed after initial setup. Change via Settings only.
/// ===========================
class EagleEyeHome extends StatefulWidget {
  const EagleEyeHome({super.key});

  @override
  State<EagleEyeHome> createState() => _EagleEyeHomeState();
}

class _EagleEyeHomeState extends State<EagleEyeHome> {
  late Future<EagleEyeData> _future;

  // Fixed settings (chosen on first launch of this session)
  String? _selectedAreaKey;
  String _selectedJobKey = JobKeys.taxi;
  bool _setupDone = false;

  // Prevent multi-push of initial setup dialog
  bool _setupLaunching = false;

  // Paging
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

  DateTime _baseTodayLocal() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _ensureSetup(EagleEyeData data) async {
    if (_setupDone || _setupLaunching) return;
    _setupLaunching = true;

    final orderedKeys = data.areaKeysNorthToSouth();
    final initialArea = _selectedAreaKey ?? (orderedKeys.isNotEmpty ? orderedKeys.first : null);
    final initialJob = _selectedJobKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final res = await Navigator.of(context).push<SettingsResult?>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SettingsScreen(
            title: '初期設定',
            areaItems: orderedKeys.map((k) => AreaItem(key: k, label: data.areaLabel(k))).toList(),
            initialAreaKey: initialArea,
            initialJobKey: initialJob,
            mustChoose: true,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _selectedAreaKey = res?.areaKey ?? initialArea;
        _selectedJobKey = res?.jobKey ?? initialJob;
        _setupDone = true;
        _setupLaunching = false;
        _pageIndex = 0;
        _pageController.jumpToPage(0);
      });
    });
  }

  Future<void> _openSettings(EagleEyeData data) async {
    final orderedKeys = data.areaKeysNorthToSouth();
    final res = await Navigator.of(context).push<SettingsResult?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SettingsScreen(
          title: '設定',
          areaItems: orderedKeys.map((k) => AreaItem(key: k, label: data.areaLabel(k))).toList(),
          initialAreaKey: _selectedAreaKey ?? (orderedKeys.isNotEmpty ? orderedKeys.first : null),
          initialJobKey: _selectedJobKey,
          mustChoose: false,
        ),
      ),
    );

    if (res == null) return;
    setState(() {
      final areaChanged = res.areaKey != _selectedAreaKey;
      _selectedAreaKey = res.areaKey;
      _selectedJobKey = res.jobKey;
      if (areaChanged) {
        _pageIndex = 0;
        _pageController.jumpToPage(0);
      }
    });
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
      if (idx <= 2) {
        _pageController.jumpToPage(idx);
        setState(() => _pageIndex = idx);
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
        _ensureSetup(data);

        final selectedKey = _selectedAreaKey;
        final forecasts = selectedKey == null ? <DayForecast>[] : (data.byArea[selectedKey] ?? <DayForecast>[]);
        final areaLabel = selectedKey == null ? '' : data.areaLabel(selectedKey);

        // AppBar: avoid overlap by keeping title minimal + ellipsis for area label
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Eagle Eye'),
                if (areaLabel.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      areaLabel,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              IconButton(
                tooltip: '設定',
                onPressed: () => _openSettings(data),
                icon: const Icon(Icons.settings),
              ),
              if (forecasts.isNotEmpty)
                IconButton(
                  tooltip: 'カレンダー',
                  onPressed: () => _openCalendar(context, forecasts, areaLabel),
                  icon: const Icon(Icons.calendar_month),
                ),
              const SizedBox(width: 6),
            ],
          ),
          body: forecasts.isEmpty
              ? const Center(child: Text('データがありません'))
              : PageView.builder(
                  controller: _pageController,
                  itemCount: _min(3, forecasts.length),
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  itemBuilder: (context, i) {
                    final label = (i == 0) ? '今日' : (i == 1) ? '明日' : '明後日';
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopPills(left: label, right: forecasts[i].date),
                          const SizedBox(height: 10),
                          DayCard(
                            day: forecasts[i],
                            selectedJobKey: _selectedJobKey,
                          ),
                          const SizedBox(height: 14),
                          _HintRow(icon: Icons.swipe, text: '左右にスワイプで 今日〜明後日'),
                          const SizedBox(height: 6),
                          _HintRow(icon: Icons.calendar_month, text: '4日目以降はカレンダーから'),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  static int _min(int a, int b) => a < b ? a : b;
}

/// ===========================
/// Settings
/// ===========================
class AreaItem {
  final String key;
  final String label;
  const AreaItem({required this.key, required this.label});
}

class SettingsResult {
  final String? areaKey;
  final String jobKey;
  const SettingsResult({required this.areaKey, required this.jobKey});
}

class SettingsScreen extends StatefulWidget {
  final String title;
  final List<AreaItem> areaItems;
  final String? initialAreaKey;
  final String initialJobKey;
  final bool mustChoose;

  const SettingsScreen({
    super.key,
    required this.title,
    required this.areaItems,
    required this.initialAreaKey,
    required this.initialJobKey,
    required this.mustChoose,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _areaKey;
  late String _jobKey;

  @override
  void initState() {
    super.initState();
    _areaKey = widget.initialAreaKey ?? (widget.areaItems.isNotEmpty ? widget.areaItems.first.key : null);
    _jobKey = widget.initialJobKey;
  }

  void _save() {
    Navigator.of(context).pop(SettingsResult(areaKey: _areaKey, jobKey: _jobKey));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => !widget.mustChoose,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          automaticallyImplyLeading: !widget.mustChoose,
          actions: [
            TextButton(
              onPressed: _areaKey == null ? null : _save,
              child: Text(
                '保存',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _areaKey == null ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.92),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            _SectionTitle(icon: Icons.place, title: '地域'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _areaKey,
                    dropdownColor: kSurface,
                    items: widget.areaItems
                        .map(
                          (a) => DropdownMenuItem<String>(
                            value: a.key,
                            child: Text(a.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _areaKey = v),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(icon: Icons.work, title: '職業'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in JobKeys.all)
                      _ChoiceChip(
                        label: JobKeys.label(k),
                        selected: k == _jobKey,
                        onTap: () => setState(() => _jobKey = k),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.mustChoose
                  ? '※ 初回のみ、地域と職業を選択してください（後から設定で変更できます）'
                  : '※ 地域と職業は設定からのみ変更できます',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.65)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _areaKey == null ? null : _save,
              child: const Text('この設定で開始'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.08);
    final border = selected ? Colors.white.withOpacity(0.26) : Colors.white.withOpacity(0.12);
    final color = selected ? Colors.white.withOpacity(0.95) : Colors.white.withOpacity(0.80);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// ===========================
/// Calendar Screen (later days)
/// - Custom calendar to color Sat/Sun/Holidays
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
  late DateTime _month; // first day of month

  @override
  void initState() {
    super.initState();
    _selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    _month = DateTime(_selected.year, _selected.month, 1);
  }

  DayForecast? _forecastFor(DateTime d) {
    final idx = d.difference(widget.baseDate).inDays;
    if (idx < 0 || idx >= widget.forecasts.length) return null;
    return widget.forecasts[idx];
  }

  bool _inRange(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    return !dd.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day)) &&
        !dd.isAfter(DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));
  }

  void _prevMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = _forecastFor(_selected);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _MonthHeader(
                    month: _month,
                    onPrev: _prevMonth,
                    onNext: _nextMonth,
                  ),
                  const SizedBox(height: 10),
                  _CalendarGrid(
                    month: _month,
                    selected: _selected,
                    firstDate: widget.firstDate,
                    lastDate: widget.lastDate,
                    inRange: _inRange,
                    forecastFor: _forecastFor,
                    onPick: (d) => setState(() => _selected = d),
                  ),
                ],
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

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final label = '${month.year}年 ${month.month}月';
    return Row(
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month; // first day of month
  final DateTime selected;
  final DateTime firstDate;
  final DateTime lastDate;

  final bool Function(DateTime) inRange;
  final DayForecast? Function(DateTime) forecastFor;
  final ValueChanged<DateTime> onPick;

  const _CalendarGrid({
    required this.month,
    required this.selected,
    required this.firstDate,
    required this.lastDate,
    required this.inRange,
    required this.forecastFor,
    required this.onPick,
  });

  static const _weekLabels = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // grid starts on Sunday
    final startWeekday = firstOfMonth.weekday % 7; // Sun=0, Mon=1..Sat=6
    const totalCells = 42; // 6 rows

    return Column(
      children: [
        Row(
          children: List.generate(7, (i) {
            final c = _weekdayColor(i);
            return Expanded(
              child: Center(
                child: Text(
                  _weekLabels[i],
                  style: TextStyle(
                    color: c.withOpacity(0.9),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          itemCount: totalCells,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, idx) {
            final dayNum = idx - startWeekday + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }

            final d = DateTime(month.year, month.month, dayNum);
            final enabled = inRange(d);

            final isSelected = _sameDay(d, selected);
            final isHoliday = JapanHolidays.isHoliday(d);
            final weekdayIndex = d.weekday % 7; // Sun=0..Sat=6
            final textColor = _dateColor(weekdayIndex, isHoliday);

            final forecast = forecastFor(d);
            final rank = forecast?.rank;
            final rankColorValue = rank == null ? null : DayCard.rankColor(rank);

            return InkWell(
              onTap: enabled ? () => onPick(d) : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? kAccentOrange.withOpacity(0.85) : Colors.white.withOpacity(0.10),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          color: enabled ? textColor : textColor.withOpacity(0.25),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (rank != null)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: (rankColorValue ?? Colors.white).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: (rankColorValue ?? Colors.white).withOpacity(0.35)),
                          ),
                          child: Text(
                            rank,
                            style: TextStyle(
                              color: enabled
                                  ? (rankColorValue ?? Colors.white)
                                  : (rankColorValue ?? Colors.white).withOpacity(0.35),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static Color _weekdayColor(int weekdayIndex) {
    // 0=Sun..6=Sat
    if (weekdayIndex == 0) return const Color(0xFFFF5C6C);
    if (weekdayIndex == 6) return const Color(0xFF4EA1FF);
    return Colors.white.withOpacity(0.85);
  }

  static Color _dateColor(int weekdayIndex, bool isHoliday) {
    if (isHoliday || weekdayIndex == 0) return const Color(0xFFFF5C6C);
    if (weekdayIndex == 6) return const Color(0xFF4EA1FF);
    return Colors.white.withOpacity(0.90);
  }
}

/// ===========================
/// Data layer
/// ===========================
class EagleEyeData {
  final Map<String, List<DayForecast>> byArea;

  EagleEyeData(this.byArea);

  List<String> get areaKeys => byArea.keys.toList()..sort();

  List<String> areaKeysNorthToSouth() {
    final keys = byArea.keys.toList();
    keys.sort((a, b) {
      final la = areaLabel(a);
      final lb = areaLabel(b);
      final ra = AreaOrder.rank(la);
      final rb = AreaOrder.rank(lb);
      if (ra != rb) return ra.compareTo(rb);
      return la.compareTo(lb);
    });
    return keys;
  }

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

    // FIX: avoid name collision (rankColor variable vs rankColor method)
    final Color rankColorValue = DayCard.rankColor(day.rank);
    final jobLabel = JobKeys.label(selectedJobKey);

    // FIX: do not declare 'final' inside children list
    final keyFacts = _pickKeyFacts(day);

    // Report sanitization: remove conflicting rank & filter job section
    final sanitizedReport = ReportSanitizer.sanitize(
      day.dailyScheduleAndImpact,
      rank: day.rank,
      selectedJobKey: selectedJobKey,
    );

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
                _RankBadge(rank: day.rank, color: rankColorValue),
              ],
            ),
            const SizedBox(height: 10),

            // Weather overview
            _SectionTitle(icon: Icons.cloud, title: '天気'),
            const SizedBox(height: 6),
            _InfoLine(
              leading: day.weatherOverview.condition,
              text: '${day.weatherOverview.high} / ${day.weatherOverview.low}   •   降水 ${day.weatherOverview.rain}',
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

            // Key facts (general)
            if (keyFacts.isNotEmpty) ...[
              _SectionTitle(icon: Icons.bolt, title: '今日の要点'),
              const SizedBox(height: 6),
              ...keyFacts.map((s) => _Bullet(s)).toList(),
              const SizedBox(height: 14),
            ],

            // View (rank reasons)
            if (day.rankReasons.isNotEmpty) ...[
              _SectionTitle(icon: Icons.fact_check, title: '見立て'),
              const SizedBox(height: 6),
              ...day.rankReasons.map((s) => _Bullet(s)).toList(),
              const SizedBox(height: 14),
            ],

            // Personalized block (selected job only)
            _SectionTitle(icon: Icons.work, title: 'あなた向け（$jobLabel）'),
            const SizedBox(height: 6),
            _ActionBox(
              title: '打ち手',
              text: (day.jobActions[selectedJobKey] ?? '').trim().isEmpty
                  ? '—'
                  : (day.jobActions[selectedJobKey] ?? '').trim(),
            ),
            const SizedBox(height: 10),
            if ((day.peakWindows[selectedJobKey] ?? '').trim().isNotEmpty)
              _ActionBox(
                title: 'ピーク目安',
                text: (day.peakWindows[selectedJobKey] ?? '').trim(),
                compact: true,
              ),

            const SizedBox(height: 14),

            // Timeline (selected job only)
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

            // Report
            if (sanitizedReport.trim().isNotEmpty) ...[
              _SectionTitle(icon: Icons.description, title: 'レポート'),
              const SizedBox(height: 6),
              Text(
                sanitizedReport.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.88),
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static List<String> _pickKeyFacts(DayForecast day) {
    final out = <String>[];

    for (final s in day.eventTrafficFacts) {
      if (out.length >= 3) break;
      out.add(s);
    }
    if (out.isNotEmpty) return out;

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

  static Color rankColor(String rank) {
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
        Icon(icon, size: 18, color: kAccentOrange.withOpacity(0.95)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: kAccentOrange.withOpacity(0.95),
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
          fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
          height: 1.35,
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
          height: 1.55,
          fontWeight: FontWeight.w600,
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
  final String title;
  final String text;
  final bool compact;

  const _ActionBox({
    required this.title,
    required this.text,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white.withOpacity(0.08);
    final border = Colors.white.withOpacity(0.12);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.80),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
          ),
        ],
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
              height: 1.55,
              fontWeight: FontWeight.w600,
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.62),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
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
}

/// ===========================
/// Area order: North -> South (prefecture order)
/// ===========================
class AreaOrder {
  static const _pref = [
    '北海道',
    '青森',
    '岩手',
    '宮城',
    '秋田',
    '山形',
    '福島',
    '茨城',
    '栃木',
    '群馬',
    '埼玉',
    '千葉',
    '東京',
    '神奈川',
    '新潟',
    '富山',
    '石川',
    '福井',
    '山梨',
    '長野',
    '岐阜',
    '静岡',
    '愛知',
    '三重',
    '滋賀',
    '京都',
    '大阪',
    '兵庫',
    '奈良',
    '和歌山',
    '鳥取',
    '島根',
    '岡山',
    '広島',
    '山口',
    '徳島',
    '香川',
    '愛媛',
    '高知',
    '福岡',
    '佐賀',
    '長崎',
    '熊本',
    '大分',
    '宮崎',
    '鹿児島',
    '沖縄',
  ];

  static int rank(String label) {
    final s = label.replaceAll(' ', '').replaceAll('　', '');
    for (var i = 0; i < _pref.length; i++) {
      final p = _pref[i];
      if (s.startsWith(p)) return i;
      if (p.length >= 2 && s.startsWith('${p}県')) return i;
      if (p.length >= 2 && s.startsWith('${p}市')) return i;
      if (p == '東京' && (s.startsWith('東京都') || s.startsWith('東京'))) return i;
      if (p == '大阪' && (s.startsWith('大阪府') || s.startsWith('大阪'))) return i;
      if (p == '京都' && (s.startsWith('京都府') || s.startsWith('京都'))) return i;
      if (p == '北海道' && s.startsWith('北海道')) return i;
    }
    return 9999;
  }
}

/// ===========================
/// Report sanitizer
/// - Remove conflicting rank text like "Aランク"
/// - Remove/Filter [職業別要点] block (show only selected job elsewhere)
/// ===========================
class ReportSanitizer {
  static String sanitize(String raw, {required String rank, required String selectedJobKey}) {
    var t = raw.trim();
    if (t.isEmpty) return '';

    // 1) Remove/neutralize any explicit rank mentions that can conflict with badge.
    // e.g. "Aランク" -> "ランク"
    t = t.replaceAll(RegExp(r'[SABC]ランク'), 'ランク');

    // 2) Remove [職業別要点] block entirely
    t = _removeJobBlock(t);

    // 3) Clean excessive blank lines
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return t;
  }

  static String _removeJobBlock(String t) {
    final lines = t.split('\n');
    final out = <String>[];

    bool skipping = false;
    for (final line in lines) {
      final s = line.trim();

      final isStart = s.contains('職業別要点') || s.contains('[職業別要点]') || s.contains('【職業別要点】');
      if (isStart) {
        skipping = true;
        continue;
      }

      if (skipping) {
        if (s.startsWith('【') && s.endsWith('】') && !s.contains('職業別要点')) {
          skipping = false;
          out.add(line);
        }
        continue;
      }

      out.add(line);
    }

    return out.join('\n').trim();
  }
}

/// ===========================
/// Japan Holidays (no package)
/// - Supports typical modern rules + substitute + citizen's holiday
/// - Equinox approximation for 1900-2099
/// ===========================
class JapanHolidays {
  static bool isHoliday(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final base = _baseHolidaysForYear(d.year);

    final withExtra = _applySubstituteAndCitizen(base, d.year);

    return withExtra.contains(d);
  }

  static Set<DateTime> _baseHolidaysForYear(int year) {
    final set = <DateTime>{};

    // Fixed-date holidays
    set.add(DateTime(year, 1, 1)); // 元日
    set.add(DateTime(year, 2, 11)); // 建国記念の日
    set.add(DateTime(year, 2, 23)); // 天皇誕生日（2020-）
    set.add(DateTime(year, 4, 29)); // 昭和の日
    set.add(DateTime(year, 5, 3)); // 憲法記念日
    set.add(DateTime(year, 5, 4)); // みどりの日
    set.add(DateTime(year, 5, 5)); // こどもの日
    set.add(DateTime(year, 8, 11)); // 山の日
    set.add(DateTime(year, 11, 3)); // 文化の日
    set.add(DateTime(year, 11, 23)); // 勤労感謝の日

    // Monday-based
    set.add(_nthMonday(year, 1, 2)); // 成人の日：1月第2月曜
    set.add(_nthMonday(year, 7, 3)); // 海の日：7月第3月曜
    set.add(_nthMonday(year, 9, 3)); // 敬老の日：9月第3月曜
    set.add(_nthMonday(year, 10, 2)); // スポーツの日：10月第2月曜

    // Equinox
    set.add(DateTime(year, 3, _vernalEquinoxDay(year)));
    set.add(DateTime(year, 9, _autumnalEquinoxDay(year)));

    return set;
  }

  static Set<DateTime> _applySubstituteAndCitizen(Set<DateTime> base, int year) {
    final set = {...base};

    // Substitute holiday: if holiday falls on Sunday -> next weekday that isn't holiday becomes holiday.
    final sorted = base.toList()..sort((a, b) => a.compareTo(b));
    for (final h in sorted) {
      if (h.weekday == DateTime.sunday) {
        var sub = h.add(const Duration(days: 1));
        while (set.contains(sub)) {
          sub = sub.add(const Duration(days: 1));
        }
        set.add(sub);
      }
    }

    // Citizen's holiday: a weekday sandwiched between two holidays becomes holiday.
    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      if (set.contains(d)) continue;
      if (d.weekday == DateTime.sunday || d.weekday == DateTime.saturday) continue;
      final prev = d.add(const Duration(days: -1));
      final next = d.add(const Duration(days: 1));
      if (set.contains(prev) && set.contains(next)) {
        set.add(d);
      }
    }

    return set;
  }

  static DateTime _nthMonday(int year, int month, int n) {
    final first = DateTime(year, month, 1);
    final firstWeekday = first.weekday; // Mon=1..Sun=7
    final offsetToMon = (DateTime.monday - firstWeekday) % 7;
    final day = 1 + offsetToMon + 7 * (n - 1);
    return DateTime(year, month, day);
  }

  // Equinox approximation valid for 1900-2099
  static int _vernalEquinoxDay(int year) {
    final y = year - 1980;
    final day = (20.8431 + 0.242194 * y - (y / 4).floor()).floor();
    return day.clamp(20, 21);
  }

  static int _autumnalEquinoxDay(int year) {
    final y = year - 1980;
    final day = (23.2488 + 0.242194 * y - (y / 4).floor()).floor();
    return day.clamp(22, 24);
  }
}
