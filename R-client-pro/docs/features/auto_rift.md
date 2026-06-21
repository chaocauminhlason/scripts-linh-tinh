Dưới đây là **Tài liệu Bàn giao Kỹ thuật (Technical Handover Document)** chi tiết cho phiên bản V8.6. Bạn có thể lưu lại tài liệu này để làm tài liệu tham khảo cho team, hoặc dùng làm "phao cứu sinh" nếu sau này Game Developer tung bản cập nhật mới.

---

# 📜 BẢN BÀN GIAO KỸ THUẬT: MODULE AUTO RIFT V8.6 (Ultimate Edition)

## 1. TỔNG QUAN HỆ THỐNG (System Overview)

* **Chức năng chính:** Tự động quét, xâm nhập, dọn dẹp và thoát các ải (Dungeon) trong game hoàn toàn tự động, hỗ trợ cả ải tự tạo (Dynamic) và ải mặc định trên bản đồ (Static).
* **Môi trường hoạt động:** Roblox Executor (LocalPlayer).
* **Mô hình hoạt động:** State Machine (Máy trạng thái) với 3 pha: `SCANNING` ➔ `COMBAT` ➔ `EXITING`.

## 2. KIẾN TRÚC CỐT LÕI (Core Architecture)

### 2.1. Quản lý Luồng (Thread Management)

* **Vấn đề cũ:** Các lệnh `InvokeServer` (Gửi yêu cầu và chờ phản hồi) như bắt quái, tạo phòng, thoát phòng làm đứng toàn bộ vòng lặp (Yielding), gây ra độ trễ lên tới 10-15 giây.
* **Giải pháp V8.6:** Toàn bộ lệnh gọi Remote được bọc trong `task.spawn()`. Điều này tạo ra một luồng song song (Asynchronous-like), cho phép Tool bắn lệnh đi và tiếp tục xử lý logic ngay lập tức mà không cần chờ Server gật đầu. Tốc độ thoát ải được ép xuống mức **0 giây (Instant Exit)**.

### 2.2. Định danh Cổng thông minh (Smart Portal ID)

* **Cơ chế:** Sử dụng thuộc tính `DungeonStartTick` (Tem thời gian khai sinh) làm "Chứng minh thư" độc nhất cho mỗi cổng.
* **Vị trí quét:**
* **Dynamic:** `Workspace.DynamicDungeon`
* **Static:** Quét trực tiếp lớp vỏ hiển thị tại `Workspace.Area.[Tên_Map].Area.Dungeon`, bỏ qua hoàn toàn lớp lõi vật lý rỗng tại nhánh `ServerZone` để tránh bị mù thông số.


* **Team ID:** Lệnh `DungeonCreateTeamChannel` và `DungeonStartChannel` bắt buộc phải truyền `DungeonStartTick` vào tham số thứ 3 để Server chấp thuận.

---

## 3. CÁC CƠ CHẾ ĐỘT PHÁ (Breakthrough Mechanisms)

Đây là những cơ chế được xây dựng từ việc "bắt bài" trực tiếp mã nguồn ẩn của Game Developer:

### 3.1. Sổ Đen Kháng Lệch Thời Gian (Time-Sync Blacklist)

* **Nguyên lý:** Game có thuộc tính `DungeonEndTick` quy định giờ chết của cổng. Tuy nhiên, không thể so sánh thẳng `EndTick` của Server với `os.time()` của PC vì sẽ bị lệch múi giờ hoặc lệch giây, dẫn đến lỗi kẹt vòng lặp (vào lại cổng vừa thoát).
* **Xử lý:** Tool tính toán **Thời lượng sống** (Duration) = `EndTick - StartTick` (thường là 300s cho Static và 120s cho Dynamic). Sau đó lấy `os.time() của PC + Duration` để lưu Sổ đen. Đảm bảo rác tự dọn chính xác tuyệt đối.

### 3.2. Radar Chống Zombie (Ultimate Anti-Deception Radar)

Quái vật trong game không dùng `HumanoidRootPart` và không tự biến mất khi chết, mà chuyển sang trạng thái "Zombie tàng hình chờ bắt". Radar mới (`SmartScanMonsters`) sử dụng 2 bộ lọc chí mạng để phân biệt quái sống/chết trong 0.1 giây:

1. **Dấu ấn Tử thần (`CatchEndTick`):** Quái vừa chết sẽ lập tức được Server gắn Attribute `CatchEndTick`. Radar thấy Attribute này là phán tử hình ngay lập tức, không cần nhìn máu.
2. **Máu hệ Châu Âu ("0,4"):** Game cố tình giữ lại dưới 1 máu để kích hoạt thu phục, và ghi thẻ StringValue chứa dấu phẩy thay vì dấu chấm. Radar tích hợp cơ chế `string.gsub(hpVal.Value, ",", ".")` để ép kiểu dữ liệu và đọc vị chính xác tình trạng cạn máu.

---

## 4. HƯỚNG DẪN BẢO TRÌ & BẮT BỆNH (Maintenance Guide)

Nếu sau này Game update và Auto Rift gặp trục trặc, hãy check các điểm sau theo thứ tự:

1. **Kẹt ở Phase `SCANNING` (Không thấy cổng):**
* Game Dev có thể đã đổi tên biến `DungeonStartTick`. Hãy dùng tool *X-Ray Attribute* soi lại thư mục `Area.Dungeon` để xem biến đó bị đổi thành tên gì.


2. **Kẹt ở Phase `COMBAT` (Chém không khí hoặc không chịu thoát):**
* Kiểm tra lại cấu trúc Quái vật (Thư mục `Workspace.Monsters`). Nếu Dev đổi thẻ `Health` thành `Hp` hoặc đổi cơ chế từ dấu phẩy sang dấu khác, hãy cập nhật lại hàm `SmartScanMonsters`.


3. **Không bắt được Pet/Không nhặt được đồ:**
* Hiện tại Tool đang dùng tốc độ *Instant Exit* (Thoát 0 giây). Nếu Server cập nhật chống lag và yêu cầu phải xem xong animation mới cho đồ, hãy thêm `task.wait(1.5)` vào ngay trước khối lệnh `task.spawn` gọi `ArenaLeaveChannel` ở phase `EXITING`.


4. **Báo lỗi Remote Arguments:**
* Đảm bảo hàm `DataPullFunc` vẫn giữ nguyên cấu trúc mảng. (VD: `{ "DungeonStartChannel", targetId, TeamId }`).



---

