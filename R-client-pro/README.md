# 📁 TÀI LIỆU BÀN GIAO: R-CLIENT PRO TOOL (AUTO-FARM & BOSS HUB)

**Tác giả / Lead Developer:** Lê Hồng Sơn  
**Phiên bản:** 1.3 (Bản cập nhật Săn Boss, Quản lý Server & Tiện ích Không gian)  
**Mục tiêu dự án:** Tự động hóa toàn diện quy trình farm hầm ngục (Dungeon), săn Boss, tối ưu hóa trải nghiệm người dùng với các tiện ích chống AFK, theo dõi đồng đội, nhảy server (Server Hop) và phân tích không gian thực (Live GPS).

---

## 1. TỔNG QUAN HỆ THỐNG (SYSTEM OVERVIEW)

Tool được phát triển bằng Lua (chạy trên các Executor của R-Client). Giao diện người dùng (UI) được xây dựng dựa trên thư viện **Rayfield**. Hệ thống hoạt động theo cơ chế vòng lặp thời gian thực (Coroutine) để theo dõi các sự kiện trong game và tự động đưa ra các thao tác nhấp chuột ảo nhằm vượt qua các cơ chế chống Auto của nhà phát triển game.

### 1.1. Các thư viện và API cốt lõi
* **Giao diện:** `https://sirius.menu/rayfield`
* **Input ảo:** `VirtualInputManager` (Dùng để click chuột tọa độ)
* **Xử lý Mạng:** `HttpService` và `TeleportService` (Quản lý Server)
* **Xử lý UI:** `GuiService` (Tính toán độ bù trừ của thanh Topbar)

---

## 2. DANH SÁCH TÍNH NĂNG CỐT LÕI (CORE FEATURES)

| Tính năng | Mô tả chi tiết hoạt động | Trạng thái |
| --- | --- | --- |
| **Auto-Exit Dungeon** | Tự động quét và nhận diện khi hoàn thành màn 20/20. Tính toán tọa độ và tự động nhấp chuột ảo để thoát ra sảnh, sẵn sàng cho vòng lặp tiếp theo. | ✅ Hoàn thiện |
| **Auto Join Room** | Quét các phòng mở, nhận diện chủ phòng thông qua thuật toán bóc tách ID Avatar, sau đó tự động tốc biến (Teleport) vào phòng. Có Fail-safe nhận diện không gian. | ✅ Hoàn thiện |
| **Săn Boss (Boss Teleport)** | Dịch chuyển tức thời đến điểm spawn của các Boss lớn (Flaragon, Godzilla, ShakeKnight). Tự động lùi về vùng an toàn (Safe Zone) nếu Boss chưa xuất hiện. | ✅ Hoàn thiện (Mới) |
| **Quản lý Server (Hop/Rejoin)** | Quét API Roblox tìm Server Public ít người nhất để nhảy sang (Hop). Hỗ trợ Rejoin Server hiện tại và hẹn giờ Rejoin tự động. | ✅ Hoàn thiện (Mới) |
| **Tọa độ Live (GPS Overlay)** | Lớp phủ UI độc lập ở góc phải màn hình, hiển thị tọa độ (X/Y/Z) theo thời gian thực. Hỗ trợ kéo thả (Drag) tự do để đo đạc và Debug vị trí. | ✅ Hoàn thiện (Mới) |
| **Follow Player** | Cho phép chọn một người chơi trong server để tự động đi theo (`Humanoid:MoveTo`). Tự động tốc biến (`CFrame`) nếu bị kẹt địa hình quá 30 giây. | ✅ Hoàn thiện |
| **Anti-AFK & Optimization** | Ép cấu hình Potato Mode (xóa Render 3D, bóng, giới hạn 15 FPS) và gửi tín hiệu giả lập ngầm giúp treo game qua đêm không bị văng/nóng máy. | ✅ Hoàn thiện |

---

## 3. ⚠️ BÁO CÁO KỸ THUẬT: VƯỢT BẪY UI GAME

### 3.1. Phân tích chiêu trò của Game Developer
Trong quá trình phát triển tính năng Auto-Exit, chúng tôi đã phát hiện hệ thống chống Auto rất tinh vi của game:
1. **Nút bấm ảo (Ghost Buttons):** Game thả rất nhiều object mang tên `DeletedLab` ở góc khuất màn hình hoặc bên ngoài tọa độ hiển thị để làm mồi nhử các hàm quét UI.
2. **Khung UI giả mạo:** Khung phần thưởng `FloatRewardView` hiển thị to giữa màn hình, nhưng các nút bấm (Yes/No) không hề mang thuộc tính Text chuẩn.

### 3.2. Giải pháp đã triển khai (Đường dẫn tuyệt đối - Absolute Path)
Để tool miễn nhiễm với mọi bản cập nhật, chức năng click chuột được trỏ thẳng vào **đường dẫn tuyệt đối** của cây thư mục UI.
**Hàm xử lý tọa độ an toàn (`ClickButtonExact`):** Sử dụng `AbsolutePosition` kết hợp với `AbsoluteSize` để lấy trung tâm của nút. **Bắt buộc** phải cộng bù trừ `GuiService:GetGuiInset().Y`, nếu không chuột ảo sẽ luôn click hụt lên phía trên do bị lệch thanh Topbar của R-Client.

---

## 4. ⚠️ BÁO CÁO KỸ THUẬT: CƠ CHẾ AUTO JOIN & NHẬN DIỆN USERID

### 4.1. Thách thức từ hệ thống tối ưu hóa (Anti-lag)
Các khối phòng (`Abyss_1`, `Abyss_2`) ở Workspace thực chất chỉ là "vỏ rỗng". Bảng UI (`SurfaceGui`) chỉ được Render/Spawn ra khi có người bước tới. Game sử dụng "Fake Text" thay vì hiển thị tên thật của người chơi.

### 4.2. Giải pháp lách luật: Bóc tách Endpoint Avatar
Hệ thống quét các `ImageLabel` (Ảnh đại diện). R-Client gọi hình đại diện thông qua API: `rbxthumb://type=AvatarHeadShot&id=[USER_ID]...`. Tool sử dụng thuật toán Regex `string.match(imgUrl, "id=(%d+)")` để trích xuất thẳng `UserId` bằng số từ ảnh, qua đó phân biệt chính xác chủ phòng 100%.

---

## 5. 🛡️ QUẢN TRỊ RỦI RO: XỬ LÝ NGOẠI LỆ (EDGE CASES)

Quá trình kiểm thử (QA) đã phát hiện và xử lý thành công 4 lỗ hổng nghiêm trọng (Test Cases):

### 5.1. Lỗi "Ping-Pong" (Spam Teleport giữa nhiều phòng)
* **Giải pháp:** Áp dụng kiến trúc **Thu thập dữ liệu trước khi thực thi**. Nếu phát hiện bản thân đã đứng trong một phòng hợp lệ (đo bằng `Magnitude < 15`), nó sẽ đánh dấu `alreadyInSomeoneRoom = true` và bỏ qua các phòng mở khác.

### 5.2. Lỗi "Bị ép làm chủ phòng" và "Tốc biến mù" (Out of Bounds)
* **Giải pháp:** Khi chủ phòng thoát, game ép người đứng ké thành chủ phòng. Tool kiểm tra chéo `UserId` và `Magnitude < 25`. Nếu đúng, sử dụng phép nhân ma trận `CFrame * CFrame.new(0, 0, 20)` để ép nhân vật nhảy lùi lại về **phía sau lưng** (hướng an toàn) thay vì một tọa độ cố định dễ gây xuyên tường (Noclip).

### 5.3. Lỗi Kéo ngược từ trong Dungeon
* **Giải pháp:** Sử dụng UI `LabStage` làm công tắc ngắt (Kill Switch). Trạng thái `isInDungeon` = `true` khi `LabStage.Text ~= "Unknown"`, từ đó đóng băng hoàn toàn logic quét phòng bên ngoài sảnh.

### 5.4. Lỗi "Nhân vật bay hơi" (Nil HRP)
* **Giải pháp:** Cấu trúc Fail-safe `if hrp and humanoid and humanoid.Health > 0` được bọc bên ngoài toàn bộ logic đo lường không gian để chống Crash Tool khi nhân vật tử vong.

---

## 6. CẤU TRÚC CODE (CODE ARCHITECTURE)

Dự án được viết gói gọn trong một tệp script duy nhất. Mã nguồn được chia thành 6 khối chính:
1. **Khởi tạo UI & Biến Toàn cục:** Setup Rayfield UI.
2. **Core Functions:** Chứa các hàm toán học tính tọa độ và Click ảo tuyệt đối.
3. **UI Tabs Construction:** Khởi tạo các Tab (Dungeon, Follow, Boss, Server, Optimization).
4. **Main Coroutine Loop:** Vòng lặp thời gian thực đa nhiệm xử lý Auto Join và Auto Exit.
5. **Optimization Module:** Can thiệp sâu vào Engine Rendering để giảm tải phần cứng.
6. **Overlay UI:** Lớp UI thứ hai (ScreenGui riêng biệt) xử lý chức năng đo đạc không gian (Tọa độ Live Drag & Drop).