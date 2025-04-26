// lib/app/controllers/review_controller.dart
import 'package:get/get.dart';
import '../data/providers/requests_provider.dart';
import '../data/models/request_model.dart';

/// 리뷰 품앗이 리스트 조회를 처리합니다.
class ReviewController extends GetxController {
  final RequestsProvider _reqProv = RequestsProvider();

  /// 실시간 리뷰 요청 리스트
  var requests = <RequestModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    // Supabase 'requests' 테이블에서 type='review'인 항목 스트림 구독
    _reqProv.streamRequests(type: 'review').listen((list) {
      requests.value = list;
    });
  }
}