Dưới đây là bản tài liệu bàn giao dự án (Handover Document) được hệ thống hóa với tư duy phân tích của một Technical Business Analyst. Cấu trúc Markdown này được thiết kế tối ưu để bạn có thể sao chép và dán trực tiếp vào các phần mềm quản lý tri thức như Notion hoặc Obsidian Sync nhằm lưu trữ lâu dài.

---

# 📁 TÀI LIỆU BÀN GIAO: ROBLOX PRO TOOL (AUTO-FARM)

**Tác giả / Lead Developer:** Lê Hồng Sơn

**Phiên bản:** 1.0 (Bản hoàn thiện Absolute Path)

**Mục tiêu dự án:** Tự động hóa quy trình farm hầm ngục (Dungeon), tối ưu hóa trải nghiệm người dùng với các tiện ích chống AFK, theo dõi đồng đội và quản lý server.

---

## 1. TỔNG QUAN HỆ THỐNG (SYSTEM OVERVIEW)

Tool được phát triển bằng Lua (chạy trên các Executor của Roblox). Giao diện người dùng (UI) được xây dựng dựa trên thư viện **Rayfield**. Hệ thống hoạt động theo cơ chế vòng lặp thời gian thực (Coroutine) để theo dõi các sự kiện trong game và tự động đưa ra các thao tác nhấp chuột ảo nhằm vượt qua các cơ chế chống Auto của nhà phát triển game.

### 1.1. Các thư viện và API cốt lõi

* **Giao diện:** `https://sirius.menu/rayfield`
* **Input ảo:** `VirtualInputManager` (Dùng để click chuột tọa độ)
* **Anti-AFK:** `VirtualUser` (Giả lập thao tác để chống kick)
* **Xử lý UI:** `GuiService` (Tính toán độ bù trừ của thanh Topbar)

---

## 2. DANH SÁCH TÍNH NĂNG CỐT LÕI (CORE FEATURES)

| Tính năng | Mô tả chi tiết hoạt động | Trạng thái |
| --- | --- | --- |
| **Auto-Exit Dungeon** | Tự động quét và nhận diện khi hoàn thành màn 20/20. Tính toán tọa độ và tự động nhấp chuột ảo để thoát ra sảnh, sẵn sàng cho vòng lặp tiếp theo. | ✅ Hoàn thiện |
| **Fail-safe Nghiệm thu** | Sau khi click thoát, hệ thống tự động chờ 2.5s để nghiệm thu kết quả hiển thị của `LabStage`. Nếu kẹt do lag mạng, tự động thử lại ở nhịp sau. | ✅ Hoàn thiện |
| **Follow Player** | Cho phép chọn một người chơi trong server để tự động đi theo (`Humanoid:MoveTo`). Tự động tốc biến (`CFrame`) nếu bị kẹt địa hình quá 30 giây. | ✅ Hoàn thiện |
| **Anti-AFK** | Gửi tín hiệu giả lập ngầm lên máy chủ Roblox giúp treo game qua đêm không bị kick vì lỗi 20 phút idle. | ✅ Hoàn thiện |
| **Server Hop/Rejoin** | Tích hợp API của Roblox để tự động tìm và chuyển sang server ít người, hoặc rejoin lại server hiện tại sau một khoảng thời gian hẹn trước. | ✅ Hoàn thiện |

---

## 3. ⚠️ BÁO CÁO KỸ THUẬT QUAN TRỌNG: VƯỢT BẪY UI GAME

*(Lưu ý cực kỳ quan trọng dành cho người phát triển tiếp theo. Tuyệt đối không sử dụng lại các hàm tìm kiếm UI chung chung như `FindButton` bằng Text hoặc Name).*

### 3.1. Phân tích chiêu trò của Game Developer

Trong quá trình phát triển tính năng Auto-Exit, chúng tôi đã phát hiện hệ thống chống Auto rất tinh vi của game:

1. **Nút bấm ảo (Ghost Buttons):** Game thả rất nhiều object mang tên `DeletedLab` ở góc khuất màn hình hoặc bên ngoài tọa độ hiển thị để làm mồi nhử các hàm quét UI tự động.
2. **Khung UI giả mạo:** Khung phần thưởng `FloatRewardView` hiển thị to giữa màn hình, nhưng các nút bấm bên trong đó (Yes/No) không hề mang thuộc tính Text chuẩn, khiến việc quét chữ bị vô hiệu hóa.
3. **Thay đổi kích thước động (Tween Animation):** Các bảng thông báo có hiệu ứng phóng to dần (khoảng 1 - 1.5 giây), nếu click ngay khi nó vừa xuất hiện sẽ bị lệch tọa độ hoàn toàn.

### 3.2. Giải pháp đã triển khai (Đường dẫn tuyệt đối - Absolute Path)

Để tool miễn nhiễm với mọi bản cập nhật đổi tên hoặc thêm nút rác của Dev, chức năng click chuột được trỏ thẳng vào **đường dẫn tuyệt đối** của cây thư mục UI:

* **Bảng xác nhận thực tế:** `PlayerGui.MainGui.ScreenGui.ConfirmView`
* **Nút Xác nhận (Yes):** `ConfirmView.FmBottom.BtOk`
* **Nút Hủy bỏ (No):** `ConfirmView.FmBottom.BtCancel`

**Hàm xử lý tọa độ an toàn (`ClickButtonExact`):**
Hệ thống sử dụng `AbsolutePosition` kết hợp với `AbsoluteSize` để lấy trung tâm của nút. **Bắt buộc** phải có đoạn check `IgnoreGuiInset` để cộng bù trừ `GuiService:GetGuiInset().Y`, nếu không chuột ảo sẽ luôn click hụt lên phía trên do bị lệch thanh Topbar (khoảng 36px).

---

## 4. CẤU TRÚC CODE (CODE ARCHITECTURE)

Dự án được viết gói gọn trong một tệp script duy nhất để dễ dàng Execute. Mã nguồn được chia thành 4 khối chính:

1. **Khởi tạo UI & Biến Toàn cục:** Setup Rayfield UI và ánh xạ các Services cần thiết của Roblox.
2. **Core Functions:** Chứa các hàm toán học tính tọa độ (`ClickButtonExact`, `findUIElementByName`) và quy trình chuỗi thao tác tự động (`SafeExitRoutine`).
3. **UI Tabs Construction:** Khởi tạo các Tab trên giao diện menu (Theo dõi, Hầm ngục, Tiện ích, Server).
4. **Main Coroutine Loop:** Vòng lặp `while task.wait(0.5) do` chạy ngầm để liên tục kiểm tra điều kiện (Màn 20/20, Boss chết, Trạng thái đi theo người chơi) và kích hoạt hàm tương ứng.

---

## 5. HƯỚNG PHÁT TRIỂN TƯƠNG LAI (FUTURE ROADMAP)

* **Bắt sự kiện (Event-Driven) thay vì Polling:** Hiện tại hệ thống đang dùng vòng lặp `while` quét 0.5s/lần. Có thể nghiên cứu chuyển sang dùng `:GetPropertyChangedSignal()` trên các Text UI (ví dụ `LabStage`) để tối ưu hóa hiệu suất CPU/RAM của Executor.
* **Lưu cấu hình nâng cao:** Cập nhật tính năng tự động ghi nhớ người chơi đang Follow khi Server Hop hoặc Rejoin.
* **Auto-Skill / Auto-Attack:** Có thể tích hợp thêm một module tự động tung chiêu khi phát hiện quái ở gần dựa trên khoảng cách `Magnitude`.