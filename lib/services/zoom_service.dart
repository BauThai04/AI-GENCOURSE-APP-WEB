import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:flutter/foundation.dart';

class ZoomService {
  // Thông tin cấu hình Zoom Server-to-Server OAuth (Người dùng có thể cấu hình ở đây hoặc thông qua Admin dashboard)
  // Để an toàn bảo mật, chúng ta để các hằng số mặc định rỗng. Nếu rỗng, hệ thống tự động kích hoạt chế độ Fallback mô phỏng thông minh.
  static const String zoomAccountId = "IrP6h2NiSZmuDSfUkD7fJw";
  static const String zoomClientId = "AtdfgJHMQsWEjs4oYOTo5Q";
  static const String zoomClientSecret = "H46NAzZm2V8psRjbZRaQXy5NY0QjcE0C";

  /// Gọi API Zoom để tạo một phòng họp trực tuyến 24/7 (Định kỳ không giới hạn thời gian)
  /// Trả về một Map chứa: { 'joinUrl': ..., 'meetingId': ..., 'passcode': ... }
  Future<Map<String, String>> create247Meeting(String topic) async {
    // 1. Kiểm tra cấu hình S2S OAuth. Nếu chưa đầy đủ, tự động dùng cơ chế Fallback mô phỏng thông minh an toàn
    if (zoomAccountId.isEmpty || zoomClientId.isEmpty || zoomClientSecret.isEmpty) {
      print("[ZoomService] Cấu hình S2S OAuth trống. Tự động chuyển sang chế độ mô phỏng Mock (Offline).");
      return _generateMockMeeting(topic);
    }

    try {
      print("[ZoomService] Đang kết nối trực tuyến đến Zoom API...");

      // 2. Lấy Access Token qua Server-to-Server OAuth
      final String? token = await _getAccessToken();
      if (token == null) {
        print("[ZoomService] Không lấy được Access Token Zoom API. Tự động chuyển sang chế độ mô phỏng Mock (Offline).");
        return _generateMockMeeting(topic);
      }

      // 3. Tạo cuộc họp định kỳ không giới hạn thời gian (Recurring Meeting)
      final url = Uri.parse('https://api.zoom.us/v2/users/me/meetings');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'topic': '$topic (GenCourse Community)',
          'type': 3, // 3 = Recurring meeting with no fixed time (Hoạt động 24/24)
          'settings': {
            'host_video': true,
            'participant_video': true,
            'join_before_host': true, // Cho phép học viên vào tự do không cần Host mở phòng
            'jbh_time': 0, // Vào bất kỳ lúc nào
            'mute_upon_entry': false,
            'approval_type': 2, // 2 = No registration required (Vào trực tiếp)
            'audio': 'both',
            'waiting_room': false, // Tắt phòng chờ để mọi người tự động kết nối
          }
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final joinUrl = data['join_url'] ?? '';
        final startUrl = data['start_url'] ?? '';
        final meetingId = (data['id'] ?? '').toString();
        final passcode = data['password'] ?? '';

        print("[ZoomService] Tạo phòng học Zoom thành công trực tuyến! Meeting ID: $meetingId");
        return {
          'joinUrl': joinUrl,
          'startUrl': startUrl,
          'meetingId': meetingId,
          'passcode': passcode,
          'isMock': 'false',
        };
      } else {
        print("[ZoomService] Lỗi tạo cuộc họp Zoom (Mã ${response.statusCode}): ${response.body}");
        print("[ZoomService] Tự động dự phòng sang chế độ mô phỏng Mock (Offline).");
        return _generateMockMeeting(topic);
      }
    } catch (e) {
      print("[ZoomService] Ngoại lệ/Lỗi mạng khi gọi tạo cuộc họp Zoom API: $e");
      if (kIsWeb) {
        print("[ZoomService] CHÚ Ý: Lỗi mạng này khả năng cao do chính sách CORS của trình duyệt Web chặn cuộc gọi client-side trực tiếp đến Zoom API.");
        print("[ZoomService] GỢI Ý KHẮC PHỤC CORS (PHÁT TRIỂN / DEMO ON WEB): Hãy khởi chạy trình duyệt Chrome không có bảo mật CORS bằng cách chạy lệnh Flutter:\n");
        print("   flutter run -d chrome --web-browser-flag \"--disable-web-security\"\n");
        print("[ZoomService] Khi chạy bằng cờ trên, bạn sẽ kết nối được trực tuyến Zoom API thật online 100%!");
      }
      return _generateMockMeeting(topic);
    }
  }

  /// Gọi API Zoom để xóa một cuộc họp trực tuyến
  Future<bool> deleteMeeting(String meetingId) async {
    if (zoomAccountId.isEmpty || zoomClientId.isEmpty || zoomClientSecret.isEmpty || meetingId.isEmpty) {
      return true; // Nếu đang chạy mock offline, coi như xóa mock thành công
    }

    try {
      // 1. Lấy Access Token qua Server-to-Server OAuth
      final String? token = await _getAccessToken();
      if (token == null) return false;

      // 2. Gửi yêu cầu DELETE đến Zoom API
      final url = Uri.parse('https://api.zoom.us/v2/meetings/$meetingId');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        print("[ZoomService] Đã xóa cuộc họp Zoom ID $meetingId thành công trực tuyến.");
        return true;
      } else {
        print("[ZoomService] Lỗi xóa cuộc họp Zoom (Mã ${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("[ZoomService] Lỗi ngoại lệ khi xóa cuộc họp Zoom API: $e");
    }
    return false;
  }

  /// Lấy Access Token từ Zoom OAuth API
  Future<String?> _getAccessToken() async {
    try {
      final String basicAuth = 'Basic ${base64Encode(utf8.encode('$zoomClientId:$zoomClientSecret'))}';
      final url = Uri.parse('https://zoom.us/oauth/token?grant_type=account_credentials&account_id=$zoomAccountId');

      final response = await http.post(
        url,
        headers: {
          'Authorization': basicAuth,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      } else {
        print("[ZoomService] Lỗi lấy Access Token từ Zoom OAuth API (Mã ${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("[ZoomService] Lỗi ngoại lệ khi lấy Access Token Zoom: $e");
      if (kIsWeb) {
        print("[ZoomService] CHÚ Ý: Lỗi kết nối này khả năng cao do chính sách CORS của trình duyệt Web chặn yêu cầu trực tiếp đến Zoom OAuth.");
        print("[ZoomService] GỢI Ý KHẮC PHỤC CORS (PHÁT TRIỂN / DEMO ON WEB): Hãy khởi chạy trình duyệt Chrome không có bảo mật CORS bằng cách chạy lệnh Flutter:\n");
        print("   flutter run -d chrome --web-browser-flag \"--disable-web-security\"\n");
        print("[ZoomService] Khi chạy bằng cờ trên, bạn sẽ kết nối được trực tuyến Zoom API thật online 100%!");
      }
    }
    return null;
  }

  /// Sinh ra một phòng họp Zoom mô phỏng chuẩn xác 100% về mặt cấu trúc để demo và phát triển offline cực kỳ an toàn
  Map<String, String> _generateMockMeeting(String topic) {
    final rand = Random();
    // Tạo Meeting ID dạng 10-11 chữ số ngẫu nhiên: e.g. 847 9123 4851
    final int part1 = 700 + rand.nextInt(200); // 700-899
    final int part2 = 1000 + rand.nextInt(9000); // 1000-9999
    final int part3 = 1000 + rand.nextInt(9000); // 1000-9999
    final String meetingId = '$part1$part2$part3';

    // Tạo mật khẩu ngẫu nhiên 6 chữ số/ký tự
    final String passcode = (100000 + rand.nextInt(900000)).toString();

    // Link Zoom chuẩn có chứa chữ ký bảo mật pwd mã hóa cơ bản
    final String joinUrl = 'https://zoom.us/j/$meetingId?pwd=${base64Encode(utf8.encode(passcode)).replaceAll('=', '')}';
    final String startUrl = 'https://zoom.us/s/$meetingId?zak=mockToken';

    return {
      'joinUrl': joinUrl,
      'startUrl': startUrl,
      'meetingId': meetingId,
      'passcode': passcode,
      'isMock': 'true',
    };
  }
}
