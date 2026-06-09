

# TÀI LIỆU BÀN GIAO KỸ THUẬT (TECHNICAL HANDOVER)

**Dự án:** R-client-pro
**Module:** Auto Dungeon (`features/auto_dungeon.txt`)
**Phiên bản cập nhật:** Tối ưu hóa logic di chuyển & Chống kẹt thú cưỡi (Anti-stuck)

## 1. Tổng quan Module (Module Overview)

Module `auto_dungeon.txt` chịu trách nhiệm tự động hóa toàn bộ quá trình farm quái vật trong khu vực Hầm Ngục (Dungeon). Module hoạt động độc lập thông qua một công tắc tổng (Master Switch) và quản lý 3 luồng tác vụ song song: Tự động đánh (Auto Attack), Tự động thoát khi hoàn thành (Auto Exit), và Tự động ghép phòng (Auto Join).

## 2. Giao diện & Biến trạng thái (UI & State Variables)

Hệ thống sử dụng thư viện Rayfield UI với cấu trúc phân cấp:

* **DungeonMasterBreaker (Công tắc tổng):** Kiểm soát luồng điện của toàn bộ module. Nếu tắt, mọi vòng lặp con sẽ bị ngắt và nhân vật tự động dừng lại (Reset MoveTo).
* **AutoAttack_V2:** Điều khiển logic tìm và tiêu diệt quái vật.
* **AutoExitDungeon:** Điều khiển logic theo dõi tiến độ màn chơi và tự động xác nhận thoát.
* **AutoJoinOthers:** Tự động dò tìm người chơi khác trong sảnh để ghép phòng.

## 3. Logic Hoạt động Cốt lõi (Core Logic Implementation)

### 3.1. Thuật toán Quét & Tiếp cận Mục tiêu (Targeting & Movement)

Thay vì sử dụng tính toán khoảng cách 3D (Magnitude) thông thường, hệ thống đã được tối ưu hóa bằng thuật toán **Khoảng cách 2D (Trục X và Z)**:

* **Công thức:** `math.sqrt((hrp.Position.X - pos.X)^2 + (hrp.Position.Z - pos.Z)^2)`
* **Mục đích:** Loại bỏ sai số trục Y, ngăn chặn tình trạng tool bị "đánh lừa" khi mục tiêu bay quá cao hoặc rơi xuống vực.

### 3.2. Cơ chế Tiếp cận (Approach Mechanism)

Hệ thống chia khoảng cách tiếp cận thành 3 ngưỡng để tối ưu hóa thời gian và tránh kẹt vật lý:

1. **Khoảng cách > 40 studs:** Kích hoạt Teleport (`hrp.CFrame = CFrame.new(...)`) tốc biến thẳng đến vị trí trên đầu quái vật (offset Y + 4 studs) để tiết kiệm thời gian.
2. **Khoảng cách > 12 studs:** Kích hoạt Native Pathfinding của game (`humanoid:MoveTo`). Kết hợp bộ đếm `dungeonStuckTimer`, nếu nhân vật bị kẹt vật cản quá 3 giây, hệ thống sẽ tự động ép CFrame để vượt rào cản.
3. **Khoảng cách < 12 studs (Tầm đánh):** Dừng di chuyển, kích hoạt cơ chế Ép xuống thú và gọi API tấn công.

### 3.3. Cơ chế Chống kẹt Thú cưỡi (Force Dismount)

Game sử dụng Custom Mount System (không dùng thuộc tính `Sit` mặc định của Roblox). Để đảm bảo API `ClientAttackMonster` không bị lỗi khi nhân vật ở trên không:

* Hệ thống gọi hàm `SmartDismount()` ngay sau bước Teleport và ngay trước khi đánh.
* **Thực thi:** Giả lập thao tác phím thủ công (Gửi tín hiệu `Enum.KeyCode.M` qua `VirtualInputManager`), kết hợp một nhịp `Jump` và `task.wait(0.15)` để đồng bộ trạng thái rớt xuống đất với Server, ép game ngắt Animation cưỡi thú trước khi tung chiêu.

### 3.4. Logic Tự động Thoát (Auto Exit Routine)

* Theo dõi `LabStage` UI để nhận diện tiến độ `20/20`.
* Sử dụng cờ `stage20ClockStarted` để xác nhận đồng hồ đếm ngược màn cuối xuất hiện. Khi đồng hồ biến mất (Boss bị hạ), kích hoạt luồng `SafeExitRoutine`.
* **SafeExitRoutine:** Mô phỏng thao tác Click thủ công vào các nút "Thoát" và "Xác nhận" (Bypass các lớp UI xác nhận của game), kèm theo delay an toàn (`task.wait(1.5)`) để tránh bị Server từ chối do spam request. Đồng thời gọi `WebhookModule` để báo cáo trạng thái hoàn thành.

## 4. Hạng mục kỹ thuật Tồn đọng (Backlog / Future Enhancements)

* **[Đang tạm hoãn] Tối ưu hóa nhận diện Thú cưỡi thông qua Memory Extraction:** * *Mô tả:* Hiện tại tool đang dùng phương pháp "Blind Dismount" (ép bấm M kết hợp Jump) bất kể loại thú đang cưỡi. Phương pháp này hoạt động tốt nhưng đôi khi gây thừa thao tác nếu người chơi đang đi bộ.
* *Giải pháp đề xuất cho phiên bản sau:* Sử dụng `getfenv` hoặc Memory Hook để trích xuất trực tiếp thư viện `_G.PathTool.ClientPlayerManager` từ `MgrPetMountClient`, qua đó đọc chính xác cờ `RidePetId` hoặc phân loại Thú bay/Thú chạy bộ (`FlySpeed` / `LandSpeed`) để quyết định điều kiện gọi phím M một cách thông minh hơn.



---
