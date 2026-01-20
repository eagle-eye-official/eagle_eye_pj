import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const EagleEyeApp());
}

// --- 定数・設定 ---
class AppColors {
  static const background = Color(0xFF0F172A); // 深いネイビーブラック
  static const cardBackground = Color(0xFF1E293B);
  static const primary = Color(0xFF3B82F6); // 鮮やかなブルー
  static const accent = Color(0xFFF59E0B); // ゴールド（鷲の目）
  
  // ランク別カラー
  static const rankS = Color(0xFFEF4444); // 赤
  static const rankA = Color(0xFFF97316); // オレンジ
  static const rankB = Color(0xFF3B82F6); // 青
  static const rankC = Color(0xFF10B981); // 緑
  
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.grey;
}

class JobData {
  final String id;
  final String label;
  final IconData icon;
  final Color badgeColor;
  const JobData({required this.id, required this.label, required this.icon, required this.badgeColor});
}

class AreaData {
  final String id;
  final String name;
  const AreaData(this.id, this.name);
}

// エリア定義
final List<AreaData> kAvailableAreas = [
  AreaData("hakodate", "北海道 函館市"),
  AreaData("osaka_hokusetsu", "大阪 北摂 (豊中・新大阪)"),
  AreaData("osaka_kita", "大阪 キタ (梅田)"),
  AreaData("osaka_minami", "大阪 ミナミ (難波)"),
  AreaData("osaka_bay", "大阪 ベイエリア (USJ)"),
  AreaData("osaka_tennoji", "大阪 天王寺・阿倍野"),
];

// 職業定義
final List<JobData> kInitialJobList = [
  JobData(id: "taxi", label: "タクシー運転手", icon: Icons.local_taxi, badgeColor: Colors.amber),
  JobData(id: "restaurant", label: "飲食店", icon: Icons.restaurant, badgeColor: Colors.redAccent),
  JobData(id: "hotel", label: "ホテル・宿泊", icon: Icons.hotel, badgeColor: Colors.blue),
  JobData(id: "shop", label: "小売・物販", icon: Icons.store, badgeColor: Colors.pink),
  JobData(id: "logistics", label: "物流・配送", icon: Icons.local_shipping, badgeColor: Colors.teal),
  JobData(id: "conveni", label: "コンビニ", icon: Icons.local_convenience_store, badgeColor: Colors.orange),
  JobData(id: "construction", label: "建設・現場", icon: Icons.construction, badgeColor: Colors.brown),
  JobData(id: "delivery", label: "デリバリー", icon: Icons.delivery_dining, badgeColor: Colors.green),
  JobData(id: "security", label: "イベント・警備", icon: Icons.security, badgeColor: Colors.indigo),
];

final List<String> kAgeGroups = ["10代", "20代", "30代", "40代", "50代", "60代以上"];

// --- アプリ本体 ---
class EagleEyeApp extends StatelessWidget {
  const EagleEyeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eagle Eye',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.cardBackground),
        appBarTheme: const AppBarTheme(backgroundColor: AppColors.background, elevation: 0),
      ),
      home: const SplashPage(),
    );
  }
}

// ------------------------------
// 🦅 スプラッシュ画面
// ------------------------------
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BootLoader()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 4),
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.5), blurRadius: 30)],
                ),
                child: const Icon(Icons.remove_red_eye_rounded, size: 80, color: AppColors.accent),
              ),
              const SizedBox(height: 20),
              const Text("EAGLE EYE", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppColors.accent)),
              const SizedBox(height: 10),
              const Text("Future Demand Forecast", style: TextStyle(color: Colors.grey, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------
// 🚀 起動チェック
// ------------------------------
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
    final savedAreaId = prefs.getString('selected_area_id');
    final savedJobId = prefs.getString('selected_job_id');
    final savedAge = prefs.getString('selected_age');

    if (savedAreaId != null && savedJobId != null && savedAge != null) {
      _navigateToMain(savedAreaId, savedJobId, savedAge);
    } else {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingPage()));
    }
  }

  void _navigateToMain(String areaId, String jobId, String age) {
    final area = kAvailableAreas.firstWhere((a) => a.id == areaId, orElse: () => kAvailableAreas.first);
    final job = kInitialJobList.firstWhere((j) => j.id == jobId, orElse: () => kInitialJobList.first);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainContainerPage(initialArea: area, initialJob: job, initialAge: age)));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.accent)));
  }
}

// ------------------------------
// 🔰 オンボーディング
// ------------------------------
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
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainContainerPage(initialArea: selectedArea!, initialJob: selectedJob!, initialAge: selectedAge!)));
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
              
              _dropdown("対象エリア", selectedArea?.name, (val) => setState(() => selectedArea = val), kAvailableAreas),
              const SizedBox(height: 20),
              _dropdown("あなたの年代", selectedAge, (val) => setState(() => selectedAge = val), kAgeGroups),
              const SizedBox(height: 20),
              
              const Text("職業", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10, runSpacing: 10,
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.all(16)),
                  child: const Text("分析を開始する", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>(String label, String? currentVal, Function(T?) onChanged, List<T> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: items.contains(currentVal) || (T == AreaData && items.any((e) => (e as AreaData).name == currentVal)) ? items.firstWhere((e) => (e as dynamic).name == currentVal) : null,
            isExpanded: true,
            hint: const Text("選択してください"),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e is AreaData ? e.name : e.toString()))).toList(),
            onChanged: onChanged,
          ),
        ),
      )
    ]);
  }
}

// ------------------------------
// 📱 メインコンテナ
// ------------------------------
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
  AreaData currentArea = kAvailableAreas[0];
  JobData currentJob = kInitialJobList[0];
  String currentAge = "30代";
  
  @override
  void initState() {
    super.initState();
    currentArea = widget.initialArea;
    currentJob = widget.initialJob;
    currentAge = widget.initialAge;
    _fetchData();
  }

  // ★修正箇所：データ取得先を「Raw URL」に変更し、エラーハンドリングを強化
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    // キャッシュ回避のタイムスタンプ
    final t = DateTime.now().millisecondsSinceEpoch;
    // GitHubのRawデータURLを使用（反映が早い）
    final url = "https://raw.githubusercontent.com/eagle-eye-official/eagle_eye_pj/main/eagle_eye_data.json?t=$t";
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> allData = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            currentAreaDataList = allData[currentArea.id] ?? [];
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "データ取得エラー: ${response.statusCode}\nまだデータが生成されていない可能性があります。";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = "接続エラー: $e";
          isLoading = false;
        });
      }
    }
  }

  void _updateSettings({AreaData? area, JobData? job, String? age}) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (area != null) {
        currentArea = area;
        prefs.setString('selected_area_id', area.id);
        _fetchData(); // エリア変更時は再取得
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
      DashboardPage(dataList: currentAreaDataList, job: currentJob, isLoading: isLoading, errorMessage: errorMessage, onRetry: _fetchData),
      CalendarPage(dataList: currentAreaDataList, job: currentJob),
      ProfilePage(area: currentArea, job: currentJob, age: currentAge, onUpdate: _updateSettings),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.remove_red_eye, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Text(currentArea.name, style: const TextStyle(fontSize: 14)),
          const Icon(Icons.arrow_drop_down, color: Colors.grey)
        ]),
        actions: [
          IconButton(onPressed: () => _updateSettings(area: kAvailableAreas[(kAvailableAreas.indexOf(currentArea) + 1) % kAvailableAreas.length]), icon: const Icon(Icons.swap_horiz))
        ],
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

// ------------------------------
// 📊 ダッシュボード (Home)
// ------------------------------
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
    required this.onRetry
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    
    // エラー表示
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text("再読み込み", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    if (dataList.isEmpty) {
      return const Center(child: Text("表示するデータがありません"));
    }

    final displayData = dataList.take(3).toList();

    return PageView.builder(
      itemCount: displayData.length,
      itemBuilder: (context, index) {
        final dayData = displayData[index];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildDateHeader(dayData['date'], index),
              const SizedBox(height: 10),
              _buildRankCard(dayData),
              const SizedBox(height: 20),
              _buildGoogleSearchInfo(dayData),
              const SizedBox(height: 20),
              _buildTimeline(dayData, job),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateHeader(String date, int index) {
    final label = index == 0 ? "今日" : (index == 1 ? "明日" : "明後日");
    return Text("$label ($date)", style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold));
  }

  Widget _buildRankCard(Map<String, dynamic> data) {
    final rank = data['rank'] ?? "C";
    final weather = data['weather_overview'] ?? {};
    final condition = weather['condition'] ?? "☁️";
    final rain = weather['rain'] ?? "-%";
    final high = weather['high'] ?? "-";
    final low = weather['low'] ?? "-";

    Color color = AppColors.rankC;
    String text = "閑散";
    if (rank == "S") { color = AppColors.rankS; text = "激混み"; }
    if (rank == "A") { color = AppColors.rankA; text = "混雑"; }
    if (rank == "B") { color = AppColors.rankB; text = "普通"; }

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
                Text("$high / $low", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              Column(children: [
                const Icon(Icons.umbrella, color: Colors.white, size: 28),
                Text(rain, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSearchInfo(Map<String, dynamic> data) {
    final info = data['daily_schedule_and_impact'] as String?;
    if (info == null || info.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.analytics, color: AppColors.accent),
            SizedBox(width: 8),
            Text("AI詳細分析レポート", style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16))
          ]),
          const SizedBox(height: 12),
          Text(info, style: const TextStyle(fontSize: 14, height: 1.6)),
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
        _timeSlot("朝 (05-11)", timeline['morning'], job),
        _timeSlot("昼 (11-16)", timeline['daytime'], job),
        _timeSlot("夜 (16-24)", timeline['night'], job),
      ],
    );
  }

  Widget _timeSlot(String label, Map<String, dynamic>? slot, JobData job) {
    if (slot == null) return const SizedBox.shrink();
    final adviceMap = slot['advice'] ?? {};
    final myAdvice = adviceMap[job.id] ?? "特になし";
    final emoji = slot['weather'] ?? ""; 
    final temp = slot['temp'] ?? "";
    final rain = slot['rain'] ?? "";

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
              Text("$emoji $temp  ☔$rain", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
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
}

// ------------------------------
// 📅 カレンダー (機能修復版)
// ------------------------------
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
    final dateStr = _formatDate(date);
    // 日付文字列でデータを検索
    try {
      final data = widget.dataList.firstWhere(
        (item) => _isSameDateStr(item['date'], dateStr),
        orElse: () => null
      );
      setState(() {
        _selectedDayData = data;
      });
    } catch (e) {
      setState(() {
        _selectedDayData = null;
      });
    }
  }
  
  // 日付文字列比較ロジック
  bool _isSameDateStr(String dateStrFromApi, String targetDateStr) {
    // API形式: "2026年01月20日 (火)"
    // ターゲット: "2026-01-20"
    final cleanApiDate = dateStrFromApi.replaceAll('年', '-').replaceAll('月', '-').replaceAll('日', '').split(' ')[0];
    return cleanApiDate == targetDateStr;
  }
  
  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
  }

  @override
  Widget build(BuildContext context) {
    // ランク色分け用マップ作成
    final rankMap = <DateTime, String>{};
    for (var item in widget.dataList) {
      try {
        final dateStr = item['date'].toString().split(' ')[0].replaceAll('年', '-').replaceAll('月', '-').replaceAll('日', '');
        rankMap[DateTime.parse(dateStr)] = item['rank'];
      } catch (e) {
        // ignore error
      }
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
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _updateSelectedData(selectedDay);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final dateKey = DateTime(date.year, date.month, date.day);
                if (rankMap.containsKey(dateKey)) {
                  final rank = rankMap[dateKey]!;
                  Color c = AppColors.rankC;
                  if(rank=="S") c=AppColors.rankS;
                  if(rank=="A") c=AppColors.rankA;
                  if(rank=="B") c=AppColors.rankB;
                  return Positioned(
                    bottom: 1,
                    child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  );
                }
                return null;
              },
            ),
          ),
          const Divider(height: 30, color: Colors.grey),
          
          // 選択した日の詳細表示エリア
          if (_selectedDayData != null) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("選んだ日の予測: ${_selectedDayData!['date']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _SimpleRankCard(data: _selectedDayData!),
                  const SizedBox(height: 20),
                  _SimpleTimeline(data: _selectedDayData!, job: widget.job),
                ],
              ),
            ),
          ] else ...[
             const Padding(
               padding: EdgeInsets.all(20.0),
               child: Text("この日の詳細データはありません", style: TextStyle(color: Colors.grey)),
             ),
          ]
        ],
      ),
    );
  }
}

// カレンダー用の簡易表示ウィジェット
class _SimpleRankCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SimpleRankCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final rank = data['rank'] ?? "C";
    final weather = data['weather_overview'] ?? {};
    final condition = weather['condition'] ?? "☁️";
    
    Color color = AppColors.rankC;
    if (rank == "S") color = AppColors.rankS;
    if (rank == "A") color = AppColors.rankA;
    if (rank == "B") color = AppColors.rankB;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(rank, style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color)),
          Text(condition, style: const TextStyle(fontSize: 30)),
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
    if (timeline == null) return const Text("詳細タイムラインなし");
    
    String getAdvice(String timeKey) {
      if (timeline[timeKey] == null) return "-";
      return timeline[timeKey]['advice']?[job.id] ?? "特になし";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("あなたへのアドバイス", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent)),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 30, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

// ------------------------------
// 👤 設定 (CSVボタン削除版)
// ------------------------------
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
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: Text("App Version 1.0.0", style: TextStyle(color: Colors.grey, fontSize: 12))),
          ),
        ],
      ),
    );
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
    showModalBottomSheet(context: context, builder: (_) => ListView(
      children: kAvailableAreas.map((a) => ListTile(title: Text(a.name), onTap: (){ onUpdate(area: a); Navigator.pop(context); })).toList()
    ));
  }
  void _showJobPicker(BuildContext context) {
    showModalBottomSheet(context: context, builder: (_) => ListView(
      children: kInitialJobList.map((j) => ListTile(leading: Icon(j.icon), title: Text(j.label), onTap: (){ onUpdate(job: j); Navigator.pop(context); })).toList()
    ));
  }
  void _showAgePicker(BuildContext context) {
    showModalBottomSheet(context: context, builder: (_) => ListView(
      children: kAgeGroups.map((a) => ListTile(title: Text(a), onTap: (){ onUpdate(age: a); Navigator.pop(context); })).toList()
    ));
  }
}
