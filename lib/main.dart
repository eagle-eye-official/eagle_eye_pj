import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const EagleEyeApp());
}

// --- 定数 ---
class AppColors {
  static const background = Color(0xFF0F172A);
  static const cardBackground = Color(0xFF1E293B);
  static const primary = Color(0xFF3B82F6);
  static const accent = Color(0xFFF59E0B);
  static const action = Color(0xFFFF6D00);

  static const rankS = Color(0xFFEF4444);
  static const rankA = Color(0xFFF97316);
  static const rankB = Color(0xFF3B82F6);
  static const rankC = Color(0xFF10B981);
}

class JobData {
  final String id;
  final String label;
  final IconData icon;
  final Color badgeColor;
  const JobData({
    required this.id,
    required this.label,
    required this.icon,
    required this.badgeColor,
  });
}

class AreaData {
  final String id;
  final String name;
  const AreaData(this.id, this.name);
}

// 30地点
final List<AreaData> kAvailableAreas = [
  AreaData("hakodate", "北海道 函館"),
  AreaData("sapporo", "北海道 札幌"),
  AreaData("sendai", "宮城 仙台"),
  AreaData("tokyo_marunouchi", "東京 丸の内"),
  AreaData("tokyo_ginza", "東京 銀座"),
  AreaData("tokyo_shinjuku", "東京 新宿"),
  AreaData("tokyo_shibuya", "東京 渋谷"),
  AreaData("tokyo_roppongi", "東京 六本木"),
  AreaData("tokyo_ikebukuro", "東京 池袋"),
  AreaData("tokyo_shinagawa", "東京 品川"),
  AreaData("tokyo_ueno", "東京 上野"),
  AreaData("tokyo_asakusa", "東京 浅草"),
  AreaData("tokyo_akihabara", "東京 秋葉原"),
  AreaData("tokyo_omotesando", "東京 表参道"),
  AreaData("tokyo_ebisu", "東京 恵比寿"),
  AreaData("tokyo_odaiba", "東京 お台場"),
  AreaData("tokyo_toyosu", "東京 豊洲"),
  AreaData("tokyo_haneda", "東京 羽田空港"),
  AreaData("chiba_maihama", "千葉 舞浜"),
  AreaData("kanagawa_yokohama", "神奈川 横浜"),
  AreaData("aichi_nagoya", "愛知 名古屋"),
  AreaData("osaka_kita", "大阪 キタ"),
  AreaData("osaka_minami", "大阪 ミナミ"),
  AreaData("osaka_hokusetsu", "大阪 北摂"),
  AreaData("osaka_bay", "大阪 ベイエリア"),
  AreaData("osaka_tennoji", "大阪 天王寺"),
  AreaData("kyoto_shijo", "京都 四条"),
  AreaData("hyogo_kobe", "兵庫 神戸"),
  AreaData("hiroshima", "広島"),
  AreaData("fukuoka", "福岡 博多"),
  AreaData("okinawa_naha", "沖縄 那覇"),
];

// ✅ 5職業に固定（main.py側のJOB_KEYSと揃える）
final List<JobData> kInitialJobList = [
  JobData(id: "taxi", label: "タクシー", icon: Icons.local_taxi, badgeColor: Colors.amber),
  JobData(id: "delivery", label: "配送", icon: Icons.local_shipping, badgeColor: Colors.teal),
  JobData(id: "restaurant", label: "飲食店", icon: Icons.restaurant, badgeColor: Colors.redAccent),
  JobData(id: "retail", label: "小売", icon: Icons.store, badgeColor: Colors.pink),
  JobData(id: "hotel", label: "ホテル", icon: Icons.hotel, badgeColor: Colors.blue),
];

final List<String> kAgeGroups = ["10代", "20代", "30代", "40代", "50代", "60代以上"];

// 2026年祝日
final Set<DateTime> kHolidays2026 = {
  DateTime(2026, 1, 1),
  DateTime(2026, 1, 12),
  DateTime(2026, 2, 11),
  DateTime(2026, 2, 23),
  DateTime(2026, 3, 20),
  DateTime(2026, 4, 29),
  DateTime(2026, 5, 3),
  DateTime(2026, 5, 4),
  DateTime(2026, 5, 5),
  DateTime(2026, 5, 6),
  DateTime(2026, 7, 20),
  DateTime(2026, 8, 11),
  DateTime(2026, 9, 21),
  DateTime(2026, 9, 22),
  DateTime(2026, 9, 23),
  DateTime(2026, 10, 12),
  DateTime(2026, 11, 3),
  DateTime(2026, 11, 23),
  DateTime(2026, 11, 24),
};

// --- URLを開く（WebでもOK） ---
Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
  if (!ok) {
    throw 'Could not launch $url';
  }
}

// --- 小物ユーティリティ：温度を数字にする ---
double? _extractTempNumber(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  final m = RegExp(r'(-?\d+)').firstMatch(s);
  if (m == null) return null;
  return double.tryParse(m.group(1)!);
}

String _formatTempC(double? v) {
  if (v == null) return "-";
  return "${v.round()}°C";
}

Color _rankColor(String rank) {
  switch (rank) {
    case "S":
      return AppColors.rankS;
    case "A":
      return AppColors.rankA;
    case "B":
      return AppColors.rankB;
    default:
      return AppColors.rankC;
  }
}

String _rankText(String rank) {
  switch (rank) {
    case "S":
      return "激混み";
    case "A":
      return "混雑";
    case "B":
      return "普通";
    default:
      return "閑散";
  }
}

// --- アプリ ---
class EagleEyeApp extends StatelessWidget {
  const EagleEyeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eagle Eye',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.cardBackground,
          secondary: AppColors.action,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: AppColors.background, elevation: 0),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.action, foregroundColor: Colors.white),
        ),
      ),
      home: const SplashPage(),
    );
  }
}

// --- スプラッシュ ---
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BootLoader()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 3),
                boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 20)],
                image: const DecorationImage(
                  image: NetworkImage('https://cdn-icons-png.flaticon.com/512/482/482637.png'),
                  fit: BoxFit.scaleDown,
                  scale: 1.5,
                  colorFilter: ColorFilter.mode(AppColors.accent, BlendMode.srcIn),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "EAGLE EYE",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppColors.accent),
            ),
            const SizedBox(height: 10),
            const Text("Strategy & Weather Intelligence", style: TextStyle(color: Colors.grey, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

class BootLoader extends StatefulWidget {
  const BootLoader({super.key});
  @override
  State<BootLoader> createState() => _BootLoaderState();
}

class _BootLoaderState extends State<BootLoader> {
  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('selected_area_id') != null) {
      _navigateToMain(
        prefs.getString('selected_area_id')!,
        prefs.getString('selected_job_id')!,
        prefs.getString('selected_age')!,
      );
    } else {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingPage()));
    }
  }

  void _navigateToMain(String areaId, String jobId, String age) {
    final area = kAvailableAreas.firstWhere((a) => a.id == areaId, orElse: () => kAvailableAreas.first);
    final job = kInitialJobList.firstWhere((j) => j.id == jobId, orElse: () => kInitialJobList.first);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainContainerPage(initialArea: area, initialJob: job, initialAge: age)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accent)));
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  AreaData? selectedArea;
  JobData? selectedJob;
  String? selectedAge;

  Future<void> _saveAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_area_id', selectedArea!.id);
    await prefs.setString('selected_job_id', selectedJob!.id);
    await prefs.setString('selected_age', selectedAge!);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainContainerPage(initialArea: selectedArea!, initialJob: selectedJob!, initialAge: selectedAge!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.accent)),
              const Text("Eagle Eyeへようこそ", style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 30),

              _areaDropdown(),
              const SizedBox(height: 20),
              _ageDropdown(),
              const SizedBox(height: 20),

              const Text("職業", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kInitialJobList.map((job) {
                  final isSelected = selectedJob == job;
                  return ChoiceChip(
                    label: Text(job.label),
                    avatar: Icon(job.icon, size: 16, color: isSelected ? Colors.white : job.badgeColor),
                    selected: isSelected,
                    onSelected: (val) => setState(() => selectedJob = val ? job : null),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.cardBackground,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (selectedArea != null && selectedJob != null && selectedAge != null) ? _saveAndStart : null,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: const Text("分析を開始する", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _areaDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("対象エリア", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AreaData>(
            value: selectedArea,
            isExpanded: true,
            hint: const Text("選択してください"),
            items: kAvailableAreas.map((a) => DropdownMenuItem(value: a, child: Text(a.name))).toList(),
            onChanged: (val) => setState(() => selectedArea = val),
          ),
        ),
      )
    ]);
  }

  Widget _ageDropdown() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("あなたの年代", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedAge,
            isExpanded: true,
            hint: const Text("選択してください"),
            items: kAgeGroups.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (val) => setState(() => selectedAge = val),
          ),
        ),
      )
    ]);
  }
}

class MainContainerPage extends StatefulWidget {
  final AreaData initialArea;
  final JobData initialJob;
  final String initialAge;
  const MainContainerPage({super.key, required this.initialArea, required this.initialJob, required this.initialAge});

  @override
  State<MainContainerPage> createState() => _MainContainerPageState();
}

class _MainContainerPageState extends State<MainContainerPage> {
  int _currentIndex = 0;
  List<dynamic> currentAreaDataList = [];
  bool isLoading = true;
  String? errorMessage;
  late AreaData currentArea;
  late JobData currentJob;
  late String currentAge;

  @override
  void initState() {
    super.initState();
    currentArea = widget.initialArea;
    currentJob = widget.initialJob;
    currentAge = widget.initialAge;
    _fetchData();
  }

  Future<void> _logAdmin(String msg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "admin_log_${DateTime.now().toIso8601String()}";
      await prefs.setString(key, msg);
    } catch (_) {}
  }

  bool _isValidAreaData(Map<String, dynamic> allData, String areaId) {
    final v = allData[areaId];
    if (v == null) return false;
    if (v is! List) return false;
    if (v.isEmpty) return false;
    return true;
  }

  Future<Map<String, dynamic>?> _fetchAllJsonWithRetry() async {
    // URL候補（rawが詰まった/地域だけ欠けたときに備えてミラー）
    final baseUrls = <String>[
      "https://raw.githubusercontent.com/eagle-eye-official/eagle_eye_pj/main/eagle_eye_data.json",
      "https://cdn.jsdelivr.net/gh/eagle-eye-official/eagle_eye_pj@main/eagle_eye_data.json",
    ];

    const maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      for (final base in baseUrls) {
        final t = DateTime.now().millisecondsSinceEpoch;
        final url = "$base?t=$t&a=$attempt";
        try {
          await _logAdmin("FETCH attempt=$attempt url=$base area=${currentArea.id}");
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
          if (response.statusCode != 200) {
            await _logAdmin("FETCH non-200 status=${response.statusCode} url=$base");
            continue;
          }
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is! Map<String, dynamic>) {
            await _logAdmin("FETCH invalid json type url=$base");
            continue;
          }
          // 「該当エリアが空/欠落」も失敗扱い → リトライに回す
          if (!_isValidAreaData(decoded, currentArea.id)) {
            await _logAdmin("FETCH ok but area_missing area=${currentArea.id} url=$base");
            continue;
          }
          return decoded;
        } catch (e) {
          await _logAdmin("FETCH exception attempt=$attempt url=$base err=$e");
          // 次URL or 次attemptへ
          continue;
        }
      }
      // attempt間の待機（軽いバックオフ）
      await Future.delayed(Duration(milliseconds: 450 * attempt));
    }
    return null;
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final allData = await _fetchAllJsonWithRetry();
    if (allData == null) {
      if (mounted) {
        setState(() {
          errorMessage = "データ取得に失敗しました（通信/データ欠落）。\n電波状況を確認して再試行してください。";
          isLoading = false;
          currentAreaDataList = [];
        });
      }
      return;
    }

    final list = allData[currentArea.id];
    if (list is! List || list.isEmpty) {
      if (mounted) {
        setState(() {
          errorMessage = "データは取得できましたが、エリア「${currentArea.name}」の情報が見つかりませんでした。";
          isLoading = false;
          currentAreaDataList = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        currentAreaDataList = List<dynamic>.from(list);
        isLoading = false;
      });
    }
  }

  void _updateSettings({AreaData? area, JobData? job, String? age}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (area != null) {
        currentArea = area;
        prefs.setString('selected_area_id', area.id);
        _fetchData();
      }
      if (job != null) {
        currentJob = job;
        prefs.setString('selected_job_id', job.id);
      }
      if (age != null) {
        currentAge = age;
        prefs.setString('selected_age', age);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        dataList: currentAreaDataList,
        job: currentJob,
        isLoading: isLoading,
        errorMessage: errorMessage,
        onRetry: _fetchData,
      ),
      CalendarPage(dataList: currentAreaDataList, job: currentJob),
      ProfilePage(area: currentArea, job: currentJob, age: currentAge, onUpdate: _updateSettings),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.location_on, color: AppColors.action, size: 20),
          const SizedBox(width: 8),
          Text(currentArea.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        actions: [IconButton(onPressed: _fetchData, icon: const Icon(Icons.refresh))],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.cardBackground,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "分析"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "カレンダー"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "設定"),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final List<dynamic> dataList;
  final JobData job;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  const DashboardPage({
    super.key,
    required this.dataList,
    required this.job,
    required this.isLoading,
    this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    if (errorMessage != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
          const SizedBox(height: 20),
          Text(errorMessage!, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text("再読み込み")),
        ]),
      );
    }
    if (dataList.isEmpty) return const Center(child: Text("データがありません"));

    final displayData = dataList.take(3).toList();

    return PageView.builder(
      itemCount: displayData.length,
      itemBuilder: (context, index) {
        final dayData = displayData[index];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateHeader(dayData['date'], index),
              const SizedBox(height: 10),
              _buildRankCard(dayData),
              const SizedBox(height: 14),
              _buildFactsCard(dayData),
              const SizedBox(height: 12),
              _buildPeakCard(dayData, job),
              const SizedBox(height: 12),
              _buildTodayActionCard(dayData, job),
              const SizedBox(height: 12),
              _buildJobActionCard(dayData, job),
              const SizedBox(height: 18),
              _buildEventTrafficInfo(dayData),
              const SizedBox(height: 20),
              _buildTimeline(dayData, job),
              const SizedBox(height: 20),
              _buildStrategyReport(dayData),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(String date, int index) {
    final label = index == 0 ? "今日" : (index == 1 ? "明日" : "明後日");
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      const SizedBox(width: 10),
      Text(date, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
    ]);
  }

  // 日次の最高/最低を「weather_overview or timelineから補完」して作る
  Map<String, String> _resolveDailyHighLow(Map<String, dynamic> data) {
    final w = (data['weather_overview'] ?? {}) as Map;
    final highStr = w['high'];
    final lowStr = w['low'];

    double? hi = _extractTempNumber(highStr);
    double? lo = _extractTempNumber(lowStr);

    // どちらか欠ける、または同値なら timeline から補完
    if (hi == null || lo == null || hi == lo) {
      final timeline = data['timeline'];
      final temps = <double>[];
      if (timeline is Map) {
        for (final key in ['morning', 'daytime', 'night']) {
          final slot = timeline[key];
          if (slot is Map<String, dynamic>) {
            final th = _extractTempNumber(slot['high'] ?? slot['temp_high'] ?? slot['max']);
            final tl = _extractTempNumber(slot['low'] ?? slot['temp_low'] ?? slot['min']);
            if (th != null) temps.add(th);
            if (tl != null) temps.add(tl);

            // それでも無ければ temp単体から拾う
            final t = _extractTempNumber(slot['temp']);
            if (t != null) temps.add(t);
          }
        }
      }
      if (temps.isNotEmpty) {
        hi = temps.reduce(max);
        lo = temps.reduce(min);
      }
    }

    final hiOut = hi == null ? (highStr?.toString() ?? "-") : "最高${_formatTempC(hi)}";
    final loOut = lo == null ? (lowStr?.toString() ?? "-") : "最低${_formatTempC(lo)}";
    return {"high": hiOut, "low": loOut};
  }

  Widget _buildRankCard(Map<String, dynamic> data) {
    final rank = (data['rank'] ?? "C").toString();
    final w = (data['weather_overview'] ?? {}) as Map;
    final condition = w['condition']?.toString() ?? "☁️";
    final rain = w['rain']?.toString() ?? "-";
    final warning = w['warning']?.toString() ?? "特になし";

    final color = _rankColor(rank);
    final text = _rankText(rank);

    final hl = _resolveDailyHighLow(data);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.8), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          if (warning != "特になし")
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: Text("⚠️ $warning", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(rank, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, height: 1)),
              const SizedBox(width: 20),
              Column(
                children: [
                  Text(text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  Text(condition, style: const TextStyle(fontSize: 40)),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [
                const Icon(Icons.thermostat, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(hl["high"] ?? "-", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(hl["low"] ?? "-", style: const TextStyle(fontSize: 14)),
              ]),
              Column(children: [
                const Icon(Icons.umbrella, color: Colors.white, size: 28),
                const SizedBox(height: 6),
                Text(rain, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFactsCard(Map<String, dynamic> data) {
    final facts = data['event_traffic_facts'];
    if (facts == null || facts is! List || facts.isEmpty) return const SizedBox.shrink();

    final items = facts.take(6).map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.flash_on, color: AppColors.accent),
            SizedBox(width: 8),
            Text("重要事実（今日の判断材料）", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          ...items.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("•  ", style: TextStyle(color: Colors.white70, height: 1.4)),
                    Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildPeakCard(Map<String, dynamic> data, JobData job) {
    final pw = data['peak_windows'];
    if (pw == null || pw is! Map) return const SizedBox.shrink();

    final val = pw[job.id] ?? "";
    final text = val.toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(job.icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${job.label}のピーク時間", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ main.py の today_action を優先して表示（無ければ控えめな保険コメント）
  Widget _buildTodayActionCard(Map<String, dynamic> data, JobData job) {
    final ai = (data['today_action'] ?? "").toString().trim();
    if (ai.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.assistant, color: AppColors.accent),
            SizedBox(width: 8),
            Text("今日の一手（提案）", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          Text(ai, style: const TextStyle(color: Colors.white70, height: 1.5)),
        ]),
      );
    }

    // fallback（控えめ）
    final rank = (data['rank'] ?? "C").toString();
    final w = (data['weather_overview'] ?? {}) as Map;
    final warning = w['warning']?.toString() ?? "特になし";
    final rain = w['rain']?.toString() ?? "";
    final bullets = <String>[];

    if (rank == "S" || rank == "A") {
      bullets.add("需要増を前提に“待機位置”を先に確保（駅/商業施設/ホテル動線）。");
      bullets.add("混雑で遅延が出るので、到着見込みの説明テンプレを用意。");
    } else if (rank == "B") {
      bullets.add("ピーク時間に合わせて稼働を寄せ、その他は休憩や補給に回す。");
    } else {
      bullets.add("需要が薄い前提で、移動コストを抑え“短距離の確度”を優先。");
    }
    if (warning != "特になし") {
      bullets.add("⚠️ 注意情報あり：安全優先で行動（装備/迂回/運休前提の代替案）。");
    }
    if (rain.contains("%")) {
      final p = int.tryParse(RegExp(r'(\d+)').firstMatch(rain)?.group(1) ?? "");
      if (p != null && p >= 50) {
        bullets.add("降水確率高め：滑り止め/防水/遅延前提で“早め行動”に切替。");
      }
    }
    bullets.add("${job.label}：安全と効率の両立で“できる範囲を最大化”。");

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.assistant, color: AppColors.accent),
          SizedBox(width: 8),
          Text("今日の一手（提案）", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ...bullets.take(4).map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("•  ", style: TextStyle(color: Colors.white70, height: 1.4)),
                Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, height: 1.4))),
              ]),
            )),
      ]),
    );
  }

  // ✅ main.py の job_actions（職業別の打ち手・要点）を表示
  Widget _buildJobActionCard(Map<String, dynamic> data, JobData job) {
    final ja = data['job_actions'];
    if (ja == null || ja is! Map) return const SizedBox.shrink();

    final v = ja[job.id] ?? "";
    final text = v.toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(job.icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${job.label}の打ち手（要点）", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildEventTrafficInfo(Map<String, dynamic> data) {
    final info = data['daily_schedule_and_impact'] as String?;
    if (info == null) return const SizedBox.shrink();

    String eventContent = "";
    if (info.contains("**■Event & Traffic**")) {
      final parts = info.split("**■Event & Traffic**");
      if (parts.length > 1) {
        eventContent = parts[1].split("**■")[0].trim();
      }
    }

    if (eventContent.isEmpty || eventContent == "特になし") return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.event_note, color: AppColors.primary),
            SizedBox(width: 8),
            Text("イベント・交通情報（詳細）", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16))
          ]),
          const SizedBox(height: 10),
          Text(eventContent, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildTimeline(Map<String, dynamic> data, JobData job) {
    final timeline = data['timeline'];
    if (timeline == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("時間ごとの天気 & アドバイス", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _timeSlot("朝 (06-12)", timeline['morning'], job),
        _timeSlot("昼 (12-18)", timeline['daytime'], job),
        _timeSlot("夜 (18-24)", timeline['night'], job),
      ],
    );
  }

  String _timeTempRangeText(Map<String, dynamic> slot) {
    // 優先：high/low, temp_high/temp_low, max/min
    final hi = _extractTempNumber(slot['high'] ?? slot['temp_high'] ?? slot['max']);
    final lo = _extractTempNumber(slot['low'] ?? slot['temp_low'] ?? slot['min']);

    if (hi != null || lo != null) {
      final hiStr = hi == null ? "-" : _formatTempC(hi);
      final loStr = lo == null ? "-" : _formatTempC(lo);
      return "最高$hiStr / 最低$loStr";
    }

    // 次点：temp_range
    final tr = slot['temp_range'];
    if (tr != null) return tr.toString();

    // 最後：temp単体
    final t = slot['temp'];
    if (t != null && t.toString().trim().isNotEmpty) {
      return "気温 ${t.toString()}";
    }
    return "気温 -";
  }

  Widget _timeSlot(String label, Map<String, dynamic>? slot, JobData job) {
    if (slot == null) return const SizedBox.shrink();

    final adviceMap = slot['advice'];
    String myAdvice = "特になし";
    if (adviceMap is Map) {
      myAdvice = (adviceMap[job.id] ?? "特になし").toString();
    }

    final emoji = slot['weather'] ?? "";
    final rain = slot['rain'] ?? "";
    final humidity = slot['humidity'] ?? "-";
    final humidityStr = humidity.toString().trim();
    final tempRangeText = _timeTempRangeText(slot);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              const Spacer(),
              Text(emoji.toString(), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  const Icon(Icons.thermostat, size: 14, color: Colors.grey),
                  Text(tempRangeText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
                if (rain.toString().trim().isNotEmpty && rain.toString() != "-")
                  Row(children: [
                    const Icon(Icons.water_drop, size: 14, color: Colors.blueAccent),
                    Text(rain.toString(), style: const TextStyle(fontSize: 12)),
                  ]),
                if (humidityStr.isNotEmpty && humidityStr != "-")
                  Row(children: [
                    const Icon(Icons.opacity, size: 14, color: Colors.lightBlueAccent),
                    Text(humidityStr, style: const TextStyle(fontSize: 12)),
                  ]),
              ]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(job.icon, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(myAdvice, style: const TextStyle(fontSize: 14, height: 1.4))),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ レポートはそのまま表示（職業別フィルタは撤廃）
  Widget _buildStrategyReport(Map<String, dynamic> data) {
    final raw = data['daily_schedule_and_impact'] as String?;
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();

    final dateRaw = data['date'].toString();
    final dateClean = dateRaw.split(' ')[0].replaceAll(RegExp(r'\d{4}年'), '');
    final title = "$dateCleanのレポート";

    final lines = raw.split('\n');
    final parsedContent = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        parsedContent.add(const SizedBox(height: 8));
        continue;
      }
      if (line.contains('**')) {
        final cleanLine = line.replaceAll('**', '').replaceAll('■', '');
        parsedContent.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 12),
          child: Row(children: [
            const Icon(Icons.check_circle_outline, color: AppColors.accent, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(cleanLine,
                  style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
        ));
      } else {
        parsedContent.add(Text(line, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16))
        ]),
        const Divider(color: Colors.white24),
        ...parsedContent,
      ]),
    );
  }
}

class CalendarPage extends StatefulWidget {
  final List<dynamic> dataList;
  final JobData job;
  const CalendarPage({super.key, required this.dataList, required this.job});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, dynamic>? _selectedDayData;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _updateSelectedData(_selectedDay!);
  }

  void _updateSelectedData(DateTime date) {
    final dateStr1 = "${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日";
    try {
      final data = widget.dataList.firstWhere(
        (item) => item['date'].toString().contains(dateStr1),
        orElse: () => null,
      );
      setState(() => _selectedDayData = data);
    } catch (e) {
      setState(() => _selectedDayData = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<DateTime, Map<String, String>> infoMap = {};
    for (var item in widget.dataList) {
      try {
        final raw = item['date'].toString();
        final month = int.parse(raw.substring(0, 2));
        final day = int.parse(raw.substring(3, 5));
        final year = DateTime.now().year + (month < DateTime.now().month ? 1 : 0);

        final dt = DateTime(year, month, day);
        final w = item['weather_overview'] ?? {};
        infoMap[dt] = {
          "rank": item['rank']?.toString() ?? "C",
          "cond": w['condition']?.toString() ?? "",
          "rain": w['rain']?.toString() ?? "",
          "high": w['high']?.toString() ?? "",
          "low": w['low']?.toString() ?? "",
        };
      } catch (e) {}
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          TableCalendar(
            locale: 'ja_JP',
            firstDay: DateTime.now().subtract(const Duration(days: 1)),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            onDaySelected: (sel, foc) {
              setState(() {
                _selectedDay = sel;
                _focusedDay = foc;
              });
              _updateSelectedData(sel);
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, _) => _buildCell(date, infoMap[DateTime(date.year, date.month, date.day)]),
              selectedBuilder: (context, date, _) =>
                  _buildCell(date, infoMap[DateTime(date.year, date.month, date.day)], isSelected: true),
              todayBuilder: (context, date, _) => _buildCell(date, infoMap[DateTime(date.year, date.month, date.day)], isToday: true),
            ),
          ),
          const Divider(height: 30, color: Colors.grey),
          if (_selectedDayData != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("予測: ${_selectedDayData!['date']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _SimpleRankCard(data: _selectedDayData!),
                const SizedBox(height: 12),
                _FactsCardInline(data: _selectedDayData!),
                const SizedBox(height: 10),
                _PeakCardInline(data: _selectedDayData!, job: widget.job),
                const SizedBox(height: 10),
                _JobActionInline(data: _selectedDayData!, job: widget.job),
                const SizedBox(height: 20),
                _buildEventTrafficInfo(_selectedDayData!),
                const SizedBox(height: 20),
                _SimpleTimeline(data: _selectedDayData!, job: widget.job),
              ]),
            ),
          ] else ...[
            const Padding(padding: EdgeInsets.all(20.0), child: Text("データなし", style: TextStyle(color: Colors.grey))),
          ]
        ],
      ),
    );
  }

  Widget _buildEventTrafficInfo(Map<String, dynamic> data) {
    final info = data['daily_schedule_and_impact'] as String?;
    if (info == null) return const SizedBox.shrink();

    String eventContent = "";
    if (info.contains("**■Event & Traffic**")) {
      final parts = info.split("**■Event & Traffic**");
      if (parts.length > 1) {
        eventContent = parts[1].split("**■")[0].trim();
      }
    }

    if (eventContent.isEmpty || eventContent == "特になし") return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.event_note, color: AppColors.primary),
          SizedBox(width: 8),
          Text("イベント・交通情報（詳細）", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16))
        ]),
        const SizedBox(height: 10),
        Text(eventContent, style: const TextStyle(fontSize: 14, height: 1.5)),
      ]),
    );
  }

  Widget _buildCell(DateTime date, Map<String, String>? info, {bool isSelected = false, bool isToday = false}) {
    bool isHoliday = kHolidays2026.any((h) => isSameDay(h, date)) || date.weekday == DateTime.sunday;
    Color textColor = isHoliday ? Colors.redAccent : Colors.white;
    if (!isHoliday && date.weekday == DateTime.saturday) textColor = Colors.blueAccent;

    BoxDecoration dec = const BoxDecoration();
    if (isSelected) dec = BoxDecoration(border: Border.all(color: AppColors.accent, width: 2), shape: BoxShape.circle);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: dec,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("${date.day}", style: TextStyle(color: textColor, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
          if (info != null) ...[
            Text(info['cond']!, style: const TextStyle(fontSize: 9)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(info['high']!.replaceAll("最高", "").replaceAll("℃", "").replaceAll("°C", ""),
                    style: const TextStyle(fontSize: 8, color: Colors.redAccent)),
                const Text("/", style: TextStyle(fontSize: 8)),
                Text(info['low']!.replaceAll("最低", "").replaceAll("℃", "").replaceAll("°C", ""),
                    style: const TextStyle(fontSize: 8, color: Colors.blueAccent)),
              ],
            ),
            Text(info['rain']!.split('/')[0], style: const TextStyle(fontSize: 8, color: Colors.lightBlue)),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: info['rank'] == "S"
                    ? AppColors.rankS
                    : (info['rank'] == "A"
                        ? AppColors.rankA
                        : (info['rank'] == "B" ? AppColors.rankB : AppColors.rankC)),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _FactsCardInline extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FactsCardInline({required this.data});

  @override
  Widget build(BuildContext context) {
    final facts = data['event_traffic_facts'];
    if (facts == null || facts is! List || facts.isEmpty) return const SizedBox.shrink();
    final items = facts.take(6).map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.flash_on, color: AppColors.accent),
          SizedBox(width: 8),
          Text("重要事実（判断材料）", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        ...items.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("•  ", style: TextStyle(color: Colors.white70, height: 1.4)),
                  Expanded(child: Text(t, style: const TextStyle(color: Colors.white70, height: 1.4))),
                ],
              ),
            )),
      ]),
    );
  }
}

class _PeakCardInline extends StatelessWidget {
  final Map<String, dynamic> data;
  final JobData job;
  const _PeakCardInline({required this.data, required this.job});

  @override
  Widget build(BuildContext context) {
    final pw = data['peak_windows'];
    if (pw == null || pw is! Map) return const SizedBox.shrink();

    final val = pw[job.id] ?? "";
    final text = val.toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(job.icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${job.label}のピーク時間", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: Colors.white70, height: 1.4)),
          ]),
        ),
      ]),
    );
  }
}

class _JobActionInline extends StatelessWidget {
  final Map<String, dynamic> data;
  final JobData job;
  const _JobActionInline({required this.data, required this.job});

  @override
  Widget build(BuildContext context) {
    final ja = data['job_actions'];
    if (ja == null || ja is! Map) return const SizedBox.shrink();

    final val = ja[job.id] ?? "";
    final text = val.toString().trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(job.icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${job.label}の打ち手（要点）", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}

class _SimpleRankCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SimpleRankCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final rank = data['rank'] ?? "C";
    final w = data['weather_overview'] ?? {};

    Color color = AppColors.rankC;
    if (rank == "S") color = AppColors.rankS;
    if (rank == "A") color = AppColors.rankA;
    if (rank == "B") color = AppColors.rankB;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.2), border: Border.all(color: color), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(rank.toString(), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color)),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w['condition']?.toString() ?? "", style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(w['high']?.toString() ?? "-", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(w['low']?.toString() ?? "-", style: const TextStyle(fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}

class _SimpleTimeline extends StatelessWidget {
  final Map<String, dynamic> data;
  final JobData job;
  const _SimpleTimeline({required this.data, required this.job});
  @override
  Widget build(BuildContext context) {
    final timeline = data['timeline'];

    if (timeline == null) {
      final text = data['daily_schedule_and_impact'] as String? ?? "詳細なし";
      final cleanText = text.replaceAll('**', '').replaceAll('■', '');
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(8)),
        child: Text(cleanText, style: const TextStyle(color: Colors.white70, height: 1.5)),
      );
    }

    String getAdvice(String timeKey) {
      if (timeline[timeKey] == null) return "-";
      final adv = timeline[timeKey]['advice'];
      if (adv is Map) return (adv[job.id] ?? "特になし").toString();
      return "特になし";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("アドバイス", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
        const SizedBox(height: 8),
        _row("朝", getAdvice("morning")),
        const SizedBox(height: 8),
        _row("昼", getAdvice("daytime")),
        const SizedBox(height: 8),
        _row("夜", getAdvice("night")),
      ],
    );
  }

  Widget _row(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 30, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final AreaData area;
  final JobData job;
  final String age;
  final Function({AreaData? area, JobData? job, String? age}) onUpdate;

  const ProfilePage({super.key, required this.area, required this.job, required this.age, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("設定変更", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _item("登録エリア", area.name, () => _showAreaPicker(context)),
          _item("職業", job.label, () => _showJobPicker(context)),
          _item("年代", age, () => _showAgePicker(context)),
          const SizedBox(height: 40),
          const Divider(color: Colors.grey),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mail_outline),
              label: const Text("お問い合わせ・ご要望はこちら"),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.action, minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                await openExternalUrl(
                    'https://docs.google.com/forms/d/e/1FAIpQLScoy5UPNTvd6ZSp4Yov4kvww2jnX5pEitYJbuedMTw9nv6-Yg/viewform');
              },
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onLongPress: () => _showAdminDialog(context),
              child: const Text("App Version 2.1.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('admin_log_')).toList()..sort();
    String logText = "";
    for (var k in keys) {
      logText += "${prefs.getString(k)}\n";
    }

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text("Admin Logs"),
              content: SingleChildScrollView(child: Text(logText.isEmpty ? "No logs" : logText)),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
            ));
  }

  Widget _item(String label, String val, VoidCallback onTap) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        subtitle: Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        trailing: const Icon(Icons.edit, color: AppColors.primary),
        onTap: onTap,
      ),
    );
  }

  void _showAreaPicker(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (_) => ListView(
              children: kAvailableAreas
                  .map((a) => ListTile(
                        title: Text(a.name),
                        onTap: () {
                          onUpdate(area: a);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ));
  }

  void _showJobPicker(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (_) => ListView(
              children: kInitialJobList
                  .map((j) => ListTile(
                        leading: Icon(j.icon),
                        title: Text(j.label),
                        onTap: () {
                          onUpdate(job: j);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ));
  }

  void _showAgePicker(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (_) => ListView(
              children: kAgeGroups
                  .map((a) => ListTile(
                        title: Text(a),
                        onTap: () {
                          onUpdate(age: a);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ));
  }
}
