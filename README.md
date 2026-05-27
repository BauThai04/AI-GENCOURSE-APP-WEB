# AI GenCourse (Social & Course Generator App)

Ứng dụng Mạng xã hội kết hợp AI tự động sinh khóa học học tập trực quan được xây dựng bằng **Flutter**, **Firebase** và tích hợp **Agora Video SDK** cùng **Gemini AI**.

---

## 🚀 Hướng Dẫn Cài Đặt & Khởi Chạy Nhanh

### 1. Cài đặt thư viện dependencies
```bash
flutter pub get
```

### 2. Chạy ứng dụng trên môi trường Web
```bash
flutter run -d chrome
```

### 3. Chạy ứng dụng trên Thiết Bị Di Động (Android/iOS) hoặc Desktop
```bash
flutter run
```

---

## 🎥 Tích hợp Agora Video SDK (Lưới Camera "Study With Me" 24/7)

Hệ thống đã được chuyển đổi toàn diện từ Zoom sang **Agora Video SDK** để hiển thị **lưới camera (Video Grid) bo tròn** giữa tất cả học viên trong phòng học cộng đồng, mô phỏng hoàn hảo các nền tảng "Study With Me" nổi tiếng.

### Ưu điểm vượt trội của Agora:
1. **Lưới Camera Tùy Biến (Custom UI Grid)**: Các ô camera được bo tròn tinh tế dạng 16:9 giống hệt StudyStream, có thể tự động xếp cạnh nhau linh hoạt qua `Wrap` và hiển thị kèm tên/trạng thái micro của học viên.
2. **Hỗ trợ Flutter Web xuất sắc**: Agora chạy mượt mà trực tiếp trên WebRTC HTML5 mà không gặp các lỗi bảo mật CORS phức tạp của Zoom.
3. **Chế độ App ID Only**: Cho phép kết nối trực tuyến thật 100% bằng cách sử dụng App ID và truyền token rỗng (`""`), cực kỳ thuận tiện để chạy demo và thử nghiệm mà không cần dựng máy chủ tạo token động.

### Cách cấu hình App ID của bạn:
- Mặc định, ứng dụng sử dụng một App ID thử nghiệm có sẵn để bạn trải nghiệm ngay lập tức.
- Để sử dụng App ID của riêng bạn:
  1. Đăng ký tài khoản miễn phí tại [Agora Console](https://console.agora.io/).
  2. Tạo một dự án mới (Khuyên dùng chế độ **Testing Mode / No-Certificate** để bypass Token, hoặc tạo Temporary Token nếu dùng chế độ bảo mật).
  3. Khi tạo phòng học mới trong app, dán App ID và Token của bạn vào biểu mẫu tương ứng.
