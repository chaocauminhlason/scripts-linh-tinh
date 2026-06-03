Dưới đây là nội dung file `README.md` đã được cập nhật lên phiên bản **1.2**, bổ sung thêm toàn bộ các báo cáo kỹ thuật về việc xử lý ngoại lệ (Edge Cases) và vá lỗ hổng logic mà chúng ta vừa hoàn thiện.

Bạn có thể copy nội dung này để commit lên kho lưu trữ (Repository) của mình nhé:

---

# 📁 TÀI LIỆU BÀN GIAO: R-CLIENT PRO TOOL (AUTO-FARM)

**Tác giả / Lead Developer:** Lê Hồng Sơn

**Phiên bản:** 1.2 (Bản vá lỗi Logic & Tối ưu Edge Cases)

**Mục tiêu dự án:** Tự động hóa quy trình farm hầm ngục (Dungeon), tối ưu hóa trải nghiệm người dùng với các tiện ích chống AFK, theo dõi đồng đội, quản lý server và tự động tham gia phòng thông minh (Kèm Fail-safe).

---

## 1. TỔNG QUAN HỆ THỐNG (SYSTEM OVERVIEW)

Tool được phát triển bằng Lua (chạy trên các Executor của R-Client). Giao diện người dùng (UI) được xây dựng dựa trên thư viện **Rayfield**. Hệ thống hoạt động theo cơ chế vòng lặp thời gian thực (Coroutine) để theo dõi các sự kiện trong game và tự động đưa ra các thao tác nhấp chuột ảo nhằm vượt qua các cơ chế chống Auto của nhà phát triển game.

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
| **Auto Join Room** | Tự động quét các phòng mở, nhận diện chủ phòng thông qua thuật toán bóc tách ID Avatar, sau đó tự động tốc biến (Teleport) vào phòng của người chơi khác. Có tích hợp nhận diện không gian để tránh lỗi. | ✅ Hoàn thiện |
| **Fail-safe Nghiệm thu** | Sau khi click thoát, hệ thống tự động chờ 2.5s để nghiệm thu kết quả hiển thị của `LabStage`. Nếu kẹt do lag mạng, tự động thử lại ở nhịp sau. | ✅ Hoàn thiện |
| **Follow Player** | Cho phép chọn một người chơi trong server để tự động đi theo (`Humanoid:MoveTo`). Tự động tốc biến (`CFrame`) nếu bị kẹt địa hình quá 30 giây. | ✅ Hoàn thiện |
| **Anti-AFK** | Gửi tín hiệu giả lập ngầm lên máy chủ R-Client giúp treo game qua đêm không bị kick vì lỗi 20 phút idle. | ✅ Hoàn thiện |
| **Tối ưu Hóa (Optimization)** | Các module ép cấu hình Potato Mode, giới hạn FPS và tắt Render 3D giúp treo máy thời gian dài không bị nóng máy, văng game. | ✅ Hoàn thiện |

---

## 3. ⚠️ BÁO CÁO KỸ THUẬT: VƯỢT BẪY UI GAME

### 3.1. Phân tích chiêu trò của Game Developer

Trong quá trình phát triển tính năng Auto-Exit, chúng tôi đã phát hiện hệ thống chống Auto rất tinh vi của game:

1. **Nút bấm ảo (Ghost Buttons):** Game thả rất nhiều object mang tên `DeletedLab` ở góc khuất màn hình hoặc bên ngoài tọa độ hiển thị để làm mồi nhử các hàm quét UI tự động.
2. **Khung UI giả mạo:** Khung phần thưởng `FloatRewardView` hiển thị to giữa màn hình, nhưng các nút bấm bên trong đó (Yes/No) không hề mang thuộc tính Text chuẩn, khiến việc quét chữ bị vô hiệu hóa.

### 3.2. Giải pháp đã triển khai (Đường dẫn tuyệt đối - Absolute Path)

Để tool miễn nhiễm với mọi bản cập nhật, chức năng click chuột được trỏ thẳng vào **đường dẫn tuyệt đối** của cây thư mục UI:

* **Nút Xác nhận (Yes):** `ConfirmView.FmBottom.BtOk`

**Hàm xử lý tọa độ an toàn (`ClickButtonExact`):**
Hệ thống sử dụng `AbsolutePosition` kết hợp với `AbsoluteSize` để lấy trung tâm của nút. **Bắt buộc** phải có đoạn check `IgnoreGuiInset` để cộng bù trừ `GuiService:GetGuiInset().Y`, nếu không chuột ảo sẽ luôn click hụt lên phía trên do bị lệch thanh Topbar của R-Client.

---

## 4. ⚠️ BÁO CÁO KỸ THUẬT: CƠ CHẾ AUTO JOIN & NHẬN DIỆN USERID

### 4.1. Thách thức từ hệ thống tối ưu hóa (Anti-lag)

Các khối phòng (`Abyss_1`, `Abyss_2`) ở Workspace thực chất chỉ là "vỏ rỗng". Bảng UI (`SurfaceGui`) chỉ được Render/Spawn ra khi có người bước tới. Thêm vào đó, nhà phát triển game sử dụng "Fake Text" (chỉ để chữ `Label`) thay vì hiển thị tên thật của người chơi.

### 4.2. Giải pháp lách luật: Bóc tách Endpoint Avatar

Để nhận diện chuẩn xác 100% chủ nhân của căn phòng đang mở, hệ thống quét các `ImageLabel` (Ảnh đại diện). R-Client luôn gọi hình đại diện thông qua API hệ thống: `rbxthumb://type=AvatarHeadShot&id=[USER_ID]&w=150&h=150`. Tool sử dụng thuật toán Regex `string.match(imgUrl, "id=(%d+)")` để trích xuất thẳng `UserId` bằng số từ ảnh để phân biệt chủ phòng.

---

## 5. 🛡️ QUẢN TRỊ RỦI RO: XỬ LÝ NGOẠI LỆ (EDGE CASES) BẰNG TOÁN HỌC KHÔNG GIAN

Quá trình kiểm thử (QA/Testing) cho tính năng Auto Join đã phát hiện và xử lý thành công 4 lỗ hổng nghiêm trọng (Test Cases):

### 5.1. Lỗi "Ping-Pong" (Spam Teleport giữa nhiều phòng)

* **Vấn đề:** Nếu có nhiều hơn 2 phòng cùng mở, nhân vật sẽ bị kẹt trong vòng lặp tốc biến qua lại liên tục giữa các phòng do nhịp quét thời gian thực.
* **Giải pháp:** Áp dụng kiến trúc **Thu thập dữ liệu trước khi thực thi**. Tool sẽ duyệt qua *toàn bộ* các phòng để thiết lập "bản đồ trạng thái". Nếu phát hiện bản thân đã đứng trong một phòng hợp lệ (đo bằng `Magnitude < 15`), nó sẽ đánh dấu `alreadyInSomeoneRoom = true` và bỏ qua các phòng mở khác.

### 5.2. Lỗi "Bị ép làm chủ phòng" và "Tốc biến mù" (Out of Bounds)

* **Vấn đề:** Khi chủ phòng thoát, game tự động chuyển quyền chủ phòng cho người đang đứng ké. Nếu code chỉ đơn thuần teleport ra ngoài bằng cách cộng bù tọa độ tuyệt đối (`X+30, Z+30`), nhân vật có nguy cơ bay xuyên tường hoặc lọt gầm map.
* **Giải pháp:**
1. Kiểm tra chéo `UserId` và khoảng cách (`Magnitude < 25`) để nhận diện sự kiện "bị ép làm chủ phòng".
2. Sử dụng phép nhân ma trận không gian `CFrame * CFrame.new(0, 0, 20)` để ép nhân vật luôn nhảy lùi lại về **phía sau lưng** (hướng an toàn) thay vì một tọa độ cố định trên map.



### 5.3. Lỗi Kéo ngược từ trong Dungeon

* **Vấn đề:** Vòng lặp Auto Join vẫn chạy khi người chơi đã vào trong trận. Nếu ở sảnh có phòng mở, tool sẽ giật nhân vật từ trong map đánh quái bay ra ngoài.
* **Giải pháp:** Sử dụng UI `LabStage` làm công tắc ngắt (Kill Switch). Trạng thái `isInDungeon` = `true` khi `LabStage.Text ~= "Unknown"`, từ đó đóng băng hoàn toàn logic quét phòng bên ngoài sảnh.

### 5.4. Lỗi "Nhân vật bay hơi" (Nil HRP)

* **Vấn đề:** Nhân vật bị chết hoặc đang hồi sinh ngay lúc hàm Teleport được gọi sẽ gây lỗi sập Tool (Crash).
* **Giải pháp:** Cấu trúc Fail-safe `if hrp and humanoid and humanoid.Health > 0` được bọc bên ngoài toàn bộ logic đo lường không gian để đảm bảo an toàn tuyệt đối.

---

## 6. CẤU TRÚC CODE (CODE ARCHITECTURE)

Dự án được viết gói gọn trong một tệp script duy nhất để dễ dàng Execute. Mã nguồn được chia thành 5 khối chính:

1. **Khởi tạo UI & Biến Toàn cục:** Setup Rayfield UI.
2. **Core Functions:** Chứa các hàm toán học tính tọa độ.
3. **UI Tabs Construction:** Khởi tạo các Tab trên giao diện.
4. **Main Coroutine Loop:** Vòng lặp thời gian thực đa nhiệm.
5. **Optimization Module:** Can thiệp sâu vào Engine Rendering (Lighting, Materials, RunService) để giảm tải phần cứng.