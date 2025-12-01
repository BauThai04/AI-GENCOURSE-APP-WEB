import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  final String apiKey =
      "AIzaSyBkkE4vRrW6cwLTIW6E4qe-2zVhrSPep7g"; // Lấy tại aistudio.google.com

  Future<Map<String, dynamic>> generateCourse(String topic) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey');

    // Prompt Engineering: Yêu cầu AI trả về JSON chuẩn
    final prompt = """
      Tạo một khóa học về chủ đề: "$topic".
      Hãy trả về kết quả CHỈ LÀ JSON (không có markdown ```json) theo cấu trúc sau:
      {
        "title": "Tên khóa học",
        "description": "Mô tả ngắn",
        "chapters": [
          {
            "title": "Tên chương 1",
            "content": "Nội dung chi tiết chương 1 (khoảng 100 từ) để đọc."
          },
           {
            "title": "Tên chương 2",
            "content": "Nội dung chi tiết chương 2 (khoảng 100 từ)."
          }
        ]
      }
    """;

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String rawText = data['candidates'][0]['content']['parts'][0]['text'];
      // Clean text nếu AI lỡ thêm markdown
      rawText = rawText.replaceAll('```json', '').replaceAll('```', '');
      return jsonDecode(rawText);
    } else {
      throw Exception('Failed to generate course');
    }
  }
}
