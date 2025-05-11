import 'package:flutter/material.dart';
import '../../middleware/package_checker_service.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/notification_badge_button.dart';

class TestAppListPage extends StatefulWidget {
  const TestAppListPage({Key? key}) : super(key: key);

  @override
  State<TestAppListPage> createState() => _TestAppListPageState();
}

class _TestAppListPageState extends State<TestAppListPage> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> preparingApps = [];
  List<Map<String, dynamic>> testingApps = [];
  List<Map<String, dynamic>> endedApps = [];
  bool isLoading = true;

  /// Play 스토어 HTML에서 og:image 메타태그(icon URL) 한 줄만 추출
  Future<String?> _fetchPlayIcon(String packageName) async {
    final url =
        'https://play.google.com/store/apps/details?id=$packageName&hl=ko&gl=kr';
    final res = await http.get(Uri.parse(url), headers: {
      'User-Agent':
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36'
    });

    if (res.statusCode != 200) {
        return null;
    }

    final doc = html.parse(res.body);
    return doc
        .head
        ?.querySelector('meta[property="og:image"]')
        ?.attributes['content'];
  }

  Future<bool> _isAppInstalled(String packageName) async {
    try {
      // installed_apps returns bool?; null → false
      return (await InstalledApps.isAppInstalled(packageName)) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    PackageCheckerService.initLastCheckDate().then((_) {
      setState(() {});  // 불러온 후 화면 갱신
    });
    fetchApps();
  }


  Future<void> fetchApps() async {
    // 리스트 초기화
    preparingApps.clear();
    testingApps.clear();
    endedApps.clear();

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        Get.snackbar('오류', '로그인이 필요합니다.');
        isLoading = false;
        setState(() {});
        return;
      }
      final parts = await _client
          .from('participations')
          .select(
              'request_id, req:requests!participations_request_id_fkey(status, request_type, user_apps(package_name, app_name, icon_url))')
          .eq('user_id', userId)
          .eq('req.request_type', 'test');

      List<Future<void>> fetchTasks = [];

      for (final part in (parts as List<dynamic>)) {
        final req = part['req'];
        if (req == null) continue;

        final status = req['status'] as String? ?? 'open';
        String mappedState = switch (status) {
          'open' => 'preparing',
          'test' => 'testing',
          _ => 'ended',
        };

        final pkg = req['user_apps']?['package_name'] as String?;
        final app = req['user_apps']?['app_name'] as String?;
        final iconUrl = req['user_apps']?['icon_url'] as String?;
        if (pkg != null) {
          fetchTasks.add(_fetchSingleAppInfo(pkg, app, iconUrl, mappedState));
        }
      }

      await Future.wait(fetchTasks);
    } catch (e) {
      Get.snackbar('오류', '참여 앱 목록을 불러오지 못했습니다.');
    }
    isLoading = false;
    setState(() {});
  }

  Future<void> _fetchSingleAppInfo(String packageName, String? appName, String? appIconUrl, String appState) async {
    try {
      final iconUrl = await _fetchPlayIcon(packageName) ?? appIconUrl;
      final installed = await _isAppInstalled(packageName);

      final appInfo = {
        'packageName': packageName,
        'title': appName ?? packageName,
        'iconUrl': iconUrl,
        'state': appState,
        'installed': installed,
      };

      if (appState == 'preparing' || appState == 'testing') {
        _addAppToStateList(appInfo, appState);
        // Save locally
        await _saveInstalledApp(packageName);
      } else {
        if (installed) {
          _addAppToStateList(appInfo, 'ended');
        } else {
          await _removeInstalledApp(packageName);
        }
      }
    } catch (e) {
      // 네트워크 오류 등 → 아이콘 없이 추가
      final installed = await _isAppInstalled(packageName);
      final appInfo = {
        'packageName': packageName,
        'title': packageName,
        'iconUrl': null,
        'state': appState,
        'installed': installed,
      };
      if (appState == 'preparing' || appState == 'testing') {
        _addAppToStateList(appInfo, appState);
        await _saveInstalledApp(packageName);
      } else {
        if (installed) {
          _addAppToStateList(appInfo, 'ended');
        } else {
          await _removeInstalledApp(packageName);
        }
      }
    }
  }

  Future<void> _saveInstalledApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('installed_test_apps') ?? [];
    if (!saved.contains(packageName)) {
      saved.add(packageName);
      final updated = {...saved, packageName}.toList(); // 중복 제거
      await prefs.setStringList('installed_test_apps', updated);
    }
  }

  Future<void> _removeInstalledApp(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('installed_test_apps') ?? [];
    saved.remove(packageName);
    await prefs.setStringList('installed_test_apps', saved);
  }

  void _addAppToStateList(Map<String, dynamic> appInfo, String appState) {
    switch (appState) {
      case 'preparing':
        preparingApps.add(appInfo);
        break;
      case 'testing':
        testingApps.add(appInfo);
        break;
      case 'ended':
        endedApps.add(appInfo);
        break;
    }
  }

  Widget _statusBadge(bool installed) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: installed ? Colors.blue : Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          installed ? Icons.circle_outlined : Icons.close,
          color: Colors.white,
          size: 14,
        ),
      ),
    );
  }

  void openInPlayStore(String packageName) async {
    final url = 'https://play.google.com/store/apps/details?id=$packageName';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget buildAppGrid(List<Map<String, dynamic>> apps) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: apps.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.7,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
      ),
      itemBuilder: (context, index) {
        final app = apps[index];
        return GestureDetector(
          onTap: () => openInPlayStore(app['packageName']),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: app['iconUrl'] != null
                        ? Image.network(
                            app['iconUrl'],
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: Colors.grey[300],
                              child: const Icon(Icons.apps, size: 40),
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: Colors.grey[300],
                            child: const Icon(Icons.apps, size: 40),
                          ),
                  ),
                  // 우상단 상태 배지
                  Positioned(
                    top: 2,
                    right: 2,
                    child: _statusBadge(app['installed'] == true),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  app['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('테스트 앱 목록'), actions: [NotificationBadgeButton(),],),
      // Inserted column with update button and last checked time
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (testingApps.isEmpty && preparingApps.isEmpty && endedApps.isEmpty)
            ? const Center(child: Text('등록된 테스트 앱이 없습니다.'))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await PackageCheckerService.performInstallCheck();
                              Get.snackbar('완료', '설치 상태를 업데이트했습니다.');
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('설치 상태 업데이트'),
                          ),
                        ),
                        if (PackageCheckerService.lastCheckDate != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: Text(
                                '마지막 업데이트: ${PackageCheckerService.lastCheckDate.toString().substring(0, 19)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 24,),
                    // 상태 범례
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: [
                          _statusBadge(false),
                          const SizedBox(width: 4),
                          const Text('미설치', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 16),
                          _statusBadge(true),
                          const SizedBox(width: 4),
                          const Text('설치', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    if (testingApps.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('테스트 중', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      buildAppGrid(testingApps),
                    ],
                    if (preparingApps.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('테스트 전', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      buildAppGrid(preparingApps),
                    ],
                    if (endedApps.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('테스트 종료', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      buildAppGrid(endedApps),
                    ],
                  ],
                ),
              ),
    );
  }
}