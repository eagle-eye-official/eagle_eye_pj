import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const EagleEyeApp());
}

// --- カラー設定 ---
class AppColors {
  static const background = Color(0xFF121212);
  static const cardBackground = Color(0xFF1E1E1E);
  static const navBarBackground = Color(0xFF1E1E1E);
  static const primary = Colors.blueAccent;
  static const sRankGradientStart = Color(0xFFff5f6d);
  static const sRankGradientEnd = Color(0xFFffc371);
  static const textPrimary = Colors.white;
  static const textSecondary = Colors.grey;
  static const warning = Color(0xFFff4b4b);
}

// 職業データモデル
class JobData {
  final String id;
  final String label;
  final IconData icon;
  final Color badgeColor;
  JobData({required this.id, required this.label, required this.icon, required this.badgeColor});
}

class EagleEyeApp extends StatelessWidget {
  const EagleEyeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        appBarTheme: const AppBarTheme(backgroundColor: AppColors.background, elevation: 0),
        colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.cardBackground),
      ),
      home: const JobSelectionPage(),
    );
  }
}

// ==========================================
// 📱 1. 職業選択画面
// ==========================================
class JobSelectionPage extends StatelessWidget {
  const JobSelectionPage({super.key});
  static final List<JobData> initialJobList = [
    JobData(id: "taxi", label: "タクシー運転手", icon: Icons.local_taxi_rounded, badgeColor: const Color(0xFFFBC02D)),
    JobData(id: "restaurant", label: "飲食店", icon: Icons.restaurant_rounded, badgeColor: const Color(0xFFD32F2F)),
    JobData(id: "hotel", label: "ホテル・宿泊", icon: Icons.apartment_rounded, badgeColor: const Color(0xFF1976D2)),
    JobData(id: "shop", label: "お土産・物販", icon: Icons.local_mall_rounded, badgeColor: const Color(0xFFE91E63)),
    JobData(id: "logistics", label: "物流・配送", icon: Icons.local_shipping_rounded, badgeColor: const Color(0xFF009688)),
    JobData(id: "conveni", label: "コンビニ", icon: Icons.storefront_rounded, badgeColor: const Color(0xFFFF9800)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.remove_red_eye_rounded, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                const Text("Eagle Eye", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 60),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: initialJobList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _buildJobButton(context, initialJobList[index]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobButton(BuildContext context, JobData job) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => DashboardPage(selectedJob: job))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            children: [
              Icon(job.icon, color: job.badgeColor, size: 28),
              const SizedBox(width: 20),
              Expanded(child: Text(job.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📱 2. ダッシュボード画面
// ==========================================
class DashboardPage extends StatefulWidget {
  final JobData selectedJob;
  const DashboardPage({super.key, required this.selectedJob});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = true;
  List<dynamic> allData = [];
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    const url = "https://raw.githubusercontent.com/eagle-eye-official/eagle_eye_pj/main/eagle_eye_data.json";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          allData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load');
      }
    } catch (e) {
      setState(() {
        errorMessage = "データ取得エラー: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (errorMessage.isNotEmpty) return Scaffold(body: Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red))));

    return Scaffold(
      body: PageView.builder(
        itemCount: allData.length,
        itemBuilder: (context, index) {
          return DailyReportView(data: allData[index], selectedJob: widget.selectedJob, pageIndex: index);
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.navBarBackground,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index == 2) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const JobSelectionPage()));
        },
      ),
    );
  }
}

class DailyReportView extends StatelessWidget {
  final Map<String, dynamic> data;
  final JobData selectedJob;
  final int pageIndex;

  const DailyReportView({super.key, required this.data, required this.selectedJob, required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    String date = data['date'] ?? "";
    String rank = data['rank'] ?? "-";
    // メイン天気情報
    Map<String, dynamic> wOverview = data['weather_overview'] ?? {};
    String condition = wOverview['condition'] ?? "不明";
    String high = wOverview['high'] ?? "--";
    String low = wOverview['low'] ?? "--";
    String rain = wOverview['rain'] ?? "--";

    // タイムライン情報
    Map<String, dynamic> timeline = data['timeline'] ?? {};

    String rankLabel = "不明";
    if (rank == "S") rankLabel = "激混み";
    else if (rank == "A") rankLabel = "混雑";
    else if (rank == "B") rankLabel = "普通";
    else if (rank == "C") rankLabel = "閑散";

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(date),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // 天気詳細付きのランクカード
                    _buildMainCard(rank, rankLabel, condition, high, low, rain),
                    const SizedBox(height: 30),
                    const Align(alignment: Alignment.centerLeft, child: Text("Time Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 16),
                    // タイムライン (朝・昼・夜)
                    _buildTimeSlot(timeline['morning'], "朝 (05:00-11:00)", Icons.wb_twilight),
                    _buildTimeSlot(timeline['daytime'], "昼 (11:00-16:00)", Icons.wb_sunny),
                    _buildTimeSlot(timeline['night'], "夜 (16:00-24:00)", Icons.nights_stay),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String date) {
    String dayLabel = pageIndex == 0 ? "今日" : (pageIndex == 1 ? "明日" : "明後日");
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Eagle Eye ($dayLabel)", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: selectedJob.badgeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(selectedJob.label, style: TextStyle(color: selectedJob.badgeColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Text(date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMainCard(String rank, String label, String cond, String high, String low, String rain) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [AppColors.sRankGradientStart, AppColors.sRankGradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        children: [
          Text(rank, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, height: 1.0)),
          Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // 天気詳細情報
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [const Icon(Icons.wb_sunny_outlined, color: Colors.white70), const SizedBox(height: 4), Text(cond, style: const TextStyle(fontSize: 12))]),
                Column(children: [const Icon(Icons.thermostat, color: Colors.white70), const SizedBox(height: 4), Text("$high / $low", style: const TextStyle(fontSize: 12))]),
                Column(children: [const Icon(Icons.umbrella, color: Colors.white70), const SizedBox(height: 4), Text(rain, style: const TextStyle(fontSize: 12))]),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimeSlot(Map<String, dynamic>? data, String title, IconData icon) {
    if (data == null) return const SizedBox.shrink();
    
    String temp = data['temp'] ?? "-";
    String rain = data['rain'] ?? "-";
    String weather = data['weather'] ?? "-";
    
    // 職業別アドバイスを取得
    Map<String, dynamic> advices = data['advice'] ?? {};
    String jobAdvice = advices[selectedJob.id] ?? "特になし";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              const Icon(Icons.thermostat, size: 14, color: Colors.grey),
              Text(temp, style: const TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              const Icon(Icons.umbrella, size: 14, color: Colors.grey),
              Text(rain, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const Divider(color: Colors.grey),
          Text("天気: $weather", style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(jobAdvice, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
