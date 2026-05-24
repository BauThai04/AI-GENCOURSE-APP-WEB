# Cấu Trúc Dự Án AI GenCourse (Social & Course Generator App)

Dự án này là một ứng dụng Mạng xã hội kết hợp AI sinh khóa học học tập trực quan (AI GenCourse Social) được viết bằng **Flutter**. Giao diện ứng dụng được thiết kế theo phong cách responsive (tương thích đa màn hình Mobile, Tablet, Desktop) lấy cảm hứng từ cấu trúc 3 cột của mạng xã hội như Truth Social / Twitter.

---

## 🌟 Tổng Quan Kiến Trúc Dự Án
Ứng dụng sử dụng kiến trúc phân lớp sạch sẽ (Clean Architecture-like structure) kết hợp với **Riverpod** để quản lý trạng thái (State Management) và **Firebase** làm giải pháp Backend (Authentication, Cloud Firestore, Firebase Storage).

---

## 📂 Sơ Đồ Cấu Trúc Thư Mục Tổng Thể

```text
ai_gencourse/
├── .idea/                      # Cấu hình IDE Android Studio / VS Code
├── android/                    # Mã nguồn Native cho hệ điều hành Android
├── ios/                        # Mã nguồn Native cho hệ điều hành iOS
├── linux/                      # Mã nguồn Native cho hệ điều hành Linux
├── macos/                      # Mã nguồn Native cho hệ điều hành macOS
├── web/                        # Mã nguồn chạy trên nền tảng Web
├── windows/                    # Mã nguồn Native cho hệ điều hành Windows
├── test/                       # Thư mục chứa các tệp kiểm thử (Unit test, Widget test)
├── lib/                        # Thư mục chính chứa toàn bộ mã nguồn Dart của ứng dụng
│   ├── core/                   # Cấu hình hệ thống, màu sắc, hằng số dùng chung
│   ├── data/                   # Tầng Dữ liệu (Models, Repositories)
│   │   ├── models/             # Định nghĩa cấu trúc dữ liệu từ Firestore / API
│   │   └── repositories/       # Xử lý tương tác trực tiếp với Database / Firestore
│   ├── services/               # Tầng Dịch vụ (AI, Speech, API tích hợp)
│   ├── providers/              # Tầng Quản lý trạng thái (Riverpod Providers)
│   ├── presentation/           # Tầng Giao diện người dùng (UI)
│   │   ├── layout/             # Định nghĩa khung bố cục Responsive (Left Sidebar, Right Sidebar...)
│   │   ├── screens/            # Các màn hình chức năng chính của ứng dụng
│   │   └── widgets/            # Các Widget nhỏ, có thể tái sử dụng trên nhiều màn hình
│   └── main.dart               # Tệp đầu vào khởi chạy ứng dụng (Auth Gate, Firebase Init)
├── pubspec.yaml                # Cấu hình dự án, quản lý thư viện dependencies
├── README.md                   # Hướng dẫn chạy dự án sơ bộ
└── PROJECT_STRUCTURE.md        # Tệp tài liệu cấu trúc chi tiết dự án (Tệp này)
```

---

## 🔍 Chi Tiết Các Thư Mục & Tệp Tin Trong `lib/`

### 1. `lib/core/` - Các thành phần cốt lõi
*   **[constants.dart](lib/core/constants.dart)**: Định nghĩa các hằng số dùng chung trong dự án bao gồm:
    *   Responsive Breakpoints (`kDesktopBreakpoint = 1000.0`, `kTabletBreakpoint = 600.0`).
    *   Kích thước các cột (`kLeftSidebarWidth = 255.0`, `kRightSidebarWidth = 310.0`).
    *   Bảng màu chủ đạo (Màu tím thương hiệu: `0xFF5A4FCF`, màu nhấn hồng: `0xFFE04F5F`).

### 2. `lib/data/` - Tầng Quản lý dữ liệu
Thư mục này chia làm 2 thư mục con nhằm đảm bảo sự phân tách trách nhiệm (Separation of Concerns):
#### 📁 `models/` - Định nghĩa cấu trúc dữ liệu & Chuyển đổi dữ liệu (Serialization)
*   **[user_model.dart](lib/data/models/user_model.dart)**: Đại diện cho người dùng hệ thống (tên hiển thị, username, avatar, bio, đếm follower/following...).
*   **[post_model.dart](lib/data/models/post_model.dart)**: Cấu trúc bài đăng mạng xã hội (văn bản, danh sách ảnh, đếm thích/bình luận, ngày tạo...).
*   **[comment_model.dart](lib/data/models/comment_model.dart)**: Mô tả bình luận dưới các bài đăng.
*   **[notification_model.dart](lib/data/models/notification_model.dart)**: Mô tả cấu trúc các thông báo (like, comment, follow...).
*   **[chat_thread_model.dart](lib/data/models/chat_thread_model.dart)**: Luồng hội thoại nhắn tin giữa các người dùng.
*   **[chat_message_model.dart](lib/data/models/chat_message_model.dart)**: Tin nhắn cụ thể trong luồng hội thoại.
*   **[news_article_model.dart](lib/data/models/news_article_model.dart)**: Tin tức công nghệ lấy từ API.
*   **[youtube_video_model.dart](lib/data/models/youtube_video_model.dart)**: Video YouTube tích hợp.

#### 📁 `repositories/` - Xử lý trực tiếp với Cloud Firestore
*   **[user_repository.dart](lib/data/repositories/user_repository.dart)**: Thực hiện các truy vấn Firestore liên quan đến Profile người dùng (Cập nhật profile, theo dõi user, tìm kiếm...).
*   **[post_repository.dart](lib/data/repositories/post_repository.dart)**: Quản lý bài đăng trên Firestore (Đăng bài, thích bài viết, xóa bài viết, tải feed bài đăng...).
*   **[chat_repository.dart](lib/data/repositories/chat_repository.dart)**: Quản lý hội thoại và tin nhắn thời gian thực qua Firestore.

### 3. `lib/services/` - Tầng Dịch vụ & Tích hợp bên ngoài
*   **[auth_service.dart](lib/services/auth_service.dart)**: Tương tác với Firebase Authentication (Đăng ký, Đăng nhập bằng Email/Password, Đăng xuất).
*   **[ai_service.dart](lib/services/ai_service.dart)**: Tương tác với **Gemini API** (Google AI Studio) để sinh tự động nội dung khóa học theo chủ đề yêu cầu dưới dạng JSON có cấu trúc rõ ràng.
*   **[voice_service.dart](lib/services/voice_service.dart)**: Điều khiển tính năng giọng nói trong ứng dụng:
    *   *Speech-to-Text* (Chuyển giọng nói thành văn bản bằng thư viện `speech_to_text`).
    *   *Text-to-Speech* (Đọc nội dung văn bản tiếng Việt bằng thư viện `flutter_tts`).
*   **[news_service.dart](lib/services/news_service.dart)**: Lấy tin tức Tech/AI mới nhất từ các dịch vụ API bên ngoài để cập nhật lên sidebar.
*   **[youtube_service.dart](lib/services/youtube_service.dart)**: Tải và hiển thị danh sách các Video YouTube có chủ đề AI hữu ích.

### 4. `lib/providers/` - Tầng Quản lý trạng thái (Riverpod)
*   **[app_providers.dart](lib/providers/app_providers.dart)**: Các provider quản lý trạng thái chung (User hiện tại, danh sách bài đăng, thông báo, tin tức, luồng video...).
*   **[nav_provider.dart](lib/providers/nav_provider.dart)**: Quản lý việc chuyển đổi màn hình hiện tại trên Sidebar (Home, Alerts, AI Studio, Messages, Communities, Profile...).
*   **[chat_providers.dart](lib/providers/chat_providers.dart)**: Quản lý trạng thái nhắn tin thời gian thực.

### 5. `lib/presentation/` - Tầng Giao diện người dùng
#### 📁 `layout/` - Định nghĩa khung giao diện Responsive
*   **[responsive_scaffold.dart](lib/presentation/layout/responsive_scaffold.dart)**: Bộ khung chính của app. Nó tự động phát hiện độ rộng màn hình để phân chia bố cục:
    *   *Màn hình Desktop* (>900px): Giao diện 3 cột bao gồm `LeftSidebar` (Trái) + `Main Content` (Giữa) + `RightSidebarContent` (Phải - hiển thị Tin tức, LIVE stream giả lập, Trending Topics, suggested groups và Youtube videos).
    *   *Màn hình Mobile/Tablet*: Chỉ hiển thị cột `Main Content` kèm thanh điều hướng dưới cùng (`BottomNavigationBar`).
*   **[left_sidebar.dart](lib/presentation/layout/left_sidebar.dart)**: Thanh điều hướng bên trái trên màn hình rộng chứa các nút (Home, Search, Alerts, Messages, Communities, AI GenCourse, Profile, Post button, Logout...).

#### 📁 `screens/` - Các màn hình lớn
*   **[login_screen.dart](lib/presentation/screens/login_screen.dart)**: Màn hình Đăng nhập / Đăng ký tài khoản mạng xã hội.
*   **[home_screen.dart](lib/presentation/screens/home_screen.dart)**: Màn hình dòng thời gian (Feed), hiển thị danh sách bài đăng mới nhất từ mọi người và thanh soạn thảo bài đăng nhanh.
*   **[ai_gencourse_screen.dart](lib/presentation/screens/ai_gencourse_screen.dart)**: Màn hình chức năng đặc biệt giúp sinh khóa học tự động từ Gemini AI và tương tác học tập.
*   **[profile_screen.dart](lib/presentation/screens/profile_screen.dart)**: Trang cá nhân người dùng, hiển thị thông tin chi tiết, danh sách bài viết đã đăng, chức năng follow/unfollow.
*   **[messages_screen.dart](lib/presentation/screens/messages_screen.dart)**: Màn hình tin nhắn trực tiếp chat thời gian thực.
*   **[alerts_screen.dart](lib/presentation/screens/alerts_screen.dart)**: Màn hình thông báo các hoạt động tương tác.
*   **[groups_screen.dart](lib/presentation/screens/groups_screen.dart)**: Quản lý và hiển thị các hội nhóm học tập, cộng đồng.
*   **[mobile_search_screen.dart](lib/presentation/screens/mobile_search_screen.dart)**: Trang tìm kiếm người dùng và bài đăng tối ưu hóa cho di động.
*   **[mobile_news_tab.dart](lib/presentation/screens/mobile_news_tab.dart)**: Xem tin tức tích hợp trên thiết bị di động.
*   **[in_app_webview_screen.dart](lib/presentation/screens/in_app_webview_screen.dart)**: Màn hình trình duyệt nhúng để đọc tin tức chi tiết mà không cần thoát ứng dụng.
*   **[post_detail_screen.dart](lib/presentation/screens/post_detail_screen.dart)**: Xem chi tiết bài viết và danh sách bình luận.

#### 📁 `widgets/` - Các thành phần giao diện nhỏ tái sử dụng
*   **[post_card.dart](lib/presentation/widgets/post_card.dart)**: Card hiển thị bài đăng (thông tin tác giả, nội dung chữ, lưới hình ảnh, các nút thích/bình luận/chia sẻ).
*   **[post_composer.dart](lib/presentation/widgets/post_composer.dart)**: Hộp thoại / Khung soạn thảo bài viết mới (hỗ trợ nhập văn bản, chọn ảnh).
*   **[user_search_box.dart](lib/presentation/widgets/user_search_box.dart)**: Thanh tìm kiếm người dùng thông minh.
*   **[notification_toast.dart](lib/presentation/widgets/notification_toast.dart)**: Toast thông báo đẩy hiển thị sinh động khi có tương tác mới.
*   **[chat_thread_view.dart](lib/presentation/widgets/chat_thread_view.dart)**: Giao diện cuộc trò chuyện chi tiết.

---

## 🛠️ Công Nghệ & Các Thư Viện Sử Dụng (pubspec.yaml)
*   **Quản lý trạng thái (State Management)**: `flutter_riverpod` (^2.5.1) - Giúp quản lý trạng thái ứng dụng một cách mạch lạc, phản hồi nhanh và dễ viết test.
*   **Tích hợp AI**: `http` (^1.2.2) gửi yêu cầu trực tiếp đến Google Gemini API REST endpoints.
*   **Xử lý giọng nói (Voice)**: `speech_to_text` (^6.6.2) và `flutter_tts` (^4.0.2).
*   **Backend & Cơ sở dữ liệu**:
    *   `firebase_core`: ^3.6.0
    *   `firebase_auth`: ^5.3.1 (Đăng nhập, quản lý phiên làm việc).
    *   `cloud_firestore`: ^5.4.4 (Lưu trữ và đồng bộ hóa dữ liệu thời gian thực).
    *   `firebase_storage`: ^12.3.3 (Lưu trữ tệp hình ảnh tải lên).
*   **Tiện ích bổ sung**:
    *   `cached_network_image`: Tải và lưu bộ nhớ đệm hình ảnh thông minh.
    *   `webview_flutter`: Tích hợp trình duyệt nhúng để mở link tin tức.
    *   `url_launcher`: Mở video YouTube và các liên kết trình duyệt ngoài.
    *   `uuid`: Sinh ID duy nhất cho tin nhắn, bài viết.
    *   `intl` & `timeago`: Định dạng thời gian sinh động ("2 phút trước", "1 ngày trước").

---

## 🏁 Luồng Chạy Của Ứng Dụng (Auth Gate)
Tại [main.dart](lib/main.dart), ứng dụng khởi tạo Firebase tùy thuộc vào nền tảng (Web, Android, iOS, MacOS).
Ứng dụng sử dụng một `StreamBuilder` lắng nghe thay đổi trạng thái đăng nhập từ Firebase:
1.  **Chưa đăng nhập**: Chuyển hướng người dùng tới màn hình [login_screen.dart](lib/presentation/screens/login_screen.dart).
2.  **Đã đăng nhập**: Đưa người dùng vào giao diện chính [responsive_scaffold.dart](lib/presentation/layout/responsive_scaffold.dart) tự động điều chỉnh hiển thị 1 cột (Mobile) hoặc 3 cột (Desktop).
