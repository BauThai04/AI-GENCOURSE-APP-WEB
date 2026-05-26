# AI GenCourse (Social & Course Generator App)

Ứng dụng Mạng xã hội kết hợp AI tự động sinh khóa học học tập trực quan được xây dựng bằng **Flutter**, **Firebase** và tích hợp **Zoom API** cùng **Gemini AI**.

---

## 🚀 Hướng Dẫn Cài Đặt & Khởi Chạy Nhanh

### 1. Cài đặt thư viện dependencies
```bash
flutter pub get
```

### 2. Chạy ứng dụng trên môi trường Web (Chế độ mặc định)
```bash
flutter run -d chrome
```
*Lưu ý: Chạy ở chế độ mặc định này, do chính sách bảo mật CORS của trình duyệt Web, cuộc gọi trực tiếp từ Client đến Zoom API sẽ bị chặn và hệ thống tự động kích hoạt **Chế độ mô phỏng Offline (Mock)** thông minh để phục vụ phát triển cục bộ.*

---

## 🟢 Hướng Dẫn Kích Hoạt Zoom Online Thật 100% (Bypass CORS)

Do Zoom API không cho phép gửi yêu cầu trực tiếp từ trình duyệt Client-side (CORS restriction), bạn cần chạy trình duyệt ở chế độ bypass CORS khi phát triển hoặc demo:

### Cách 1: Khởi chạy Chrome tắt bảo mật CORS (Khuyên dùng)
Hãy chạy dự án bằng lệnh dưới đây để tự động mở Chrome ở chế độ tắt bảo mật web, cho phép ứng dụng Flutter Web tạo và kết nối trực tiếp đến phòng Zoom API thật 100%:
```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```
Khi chạy bằng lệnh này:
- Hệ thống sẽ kết nối trực tuyến với máy chủ Zoom qua Server-to-Server OAuth.
- Khi tạo phòng học, thẻ sẽ hiển thị: **"Kết nối Zoom API thật (Live 24/7)"** màu xanh lá.
- Host có thể bấm nút **"BẮT ĐẦU PHÒNG HỌP (HOST)"** và học viên có thể bấm **"THAM GIA TRÊN TRÌNH DUYỆT (WEB CLIENT)"** để vào phòng họp thật online cực kỳ mượt mà!

### Cách 2: Chạy ứng dụng trên Thiết Bị Di Động (Android/iOS) hoặc Desktop
Các nền tảng Native như Android (file APK), iOS, Windows, macOS **không bị giới hạn bởi chính sách CORS của trình duyệt**. Khi bạn build và chạy trên các nền tảng này, tính năng Zoom Online thật sẽ tự động hoạt động 100% mặc định!
```bash
# Ví dụ chạy trên thiết bị Android/iOS hoặc giả lập
flutter run
```

---

## 🛠️ Cấu Hình Production An Toàn Bảo Mật
Trong môi trường Production, để chạy online thật trên web thông thường mà không cần tắt bảo mật Chrome và đảm bảo an toàn tuyệt đối cho Client Secret của Zoom, bạn nên triển khai một **Backend Proxy Server nhỏ hoặc Firebase Cloud Functions** trung gian để thực hiện Server-to-Server OAuth với Zoom API, tránh lộ credentials ở phía Client.
