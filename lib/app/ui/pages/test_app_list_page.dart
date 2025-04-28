import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_play_scraper/google_play_scraper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    fetchApps();
  }

  Future<void> fetchApps() async {
    try {
      final apps = await _client
          .from('user_apps')
          .select('package_name, app_state');

      List<Future<void>> fetchTasks = [];

      for (final app in apps) {
        fetchTasks.add(_fetchSingleAppInfo(app['package_name'], app['app_state']));
      }

      await Future.wait(fetchTasks);
    } catch (e) {
      Get.snackbar('오류', '앱 목록을 불러오지 못했습니다.');
    }
    isLoading = false;
    setState(() {});
  }

  Future<void> _fetchSingleAppInfo(String packageName, String appState) async {
    try {
      final playStoreInfo = await GooglePlayScraper().app(appId: packageName);
      final appInfo = {
        'packageName': packageName,
        'title': playStoreInfo.title,
        'iconUrl': playStoreInfo.icon,
      };
      _addAppToStateList(appInfo, appState);
    } catch (_) {
      final appInfo = {
        'packageName': packageName,
        'title': packageName,
        'iconUrl': null,
      };
      _addAppToStateList(appInfo, appState);
    }
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
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        final app = apps[index];
        return GestureDetector(
          onTap: () => openInPlayStore(app['packageName']),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: app['iconUrl'] != null
                    ? Image.network(
                        app['iconUrl'],
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(
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
              const SizedBox(height: 8),
              Text(
                app['title'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
      appBar: AppBar(title: const Text('테스트 앱 목록')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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