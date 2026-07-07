# 📜 TÀI LIỆU BÀN GIAO KỸ THUẬT: MODULE AUTO FARM (`features/farm.txt`)

## 1. TỔNG QUAN HỆ THỐNG (System Overview)

* **Chức năng chính**: Tự động hóa toàn diện quy trình farm quái vật bao gồm tấn công thường, diệt quái không gian (TP Farm), tự động bắt quái (Auto Catch), tự động hồi phục máu cho thú cưng (Auto Heal) tại suối nước nóng gần nhất và tự động quay trở về tâm bãi farm (Smart Return).
* **Môi trường hoạt động**: Roblox Executor (LocalPlayer).
* **Quản lý dữ liệu & Định vị**:
  * Lưu trữ tọa độ tâm bãi farm: [R_ClientPro_FarmPos.json](file:///d:/scripts/scripts-linh-tinh/R-client-pro/docs/features/farm.md#)
  * Lưu trữ danh sách lọc quái ưu tiên: [R_ClientPro_MonsterFilter.json](file:///d:/scripts/scripts-linh-tinh/R-client-pro/docs/features/farm.md#)
  * **Tâm bãi farm tạm thời (`tempFarmPosition`)**: Nếu người dùng chưa lưu vị trí cố định, hệ thống sẽ tự động bắt vị trí nhân vật tại thời điểm kích hoạt Auto Farm làm tâm bãi để áp dụng bộ lọc khoảng cách (`attackRadius`) một cách chính xác, ngăn chặn việc nhân vật bị trôi bãi vô tận khi teleport hạ quái.

---

## 2. KIẾN TRÚC CỐT LÕI (Core Architecture)

### 2.1. Quản lý Cache & Tải chậm (Lazy Loading Cache)
Để tối ưu hóa hiệu năng và tránh giật lag khi truy xuất dữ liệu liên tục từ game, module sử dụng bảng `SystemCache`:
* **MonsterSystem**: Import động từ `ReplicatedStorage.CommonLogic.Monster.MonsterSystem`.
* **AttackRemote**: Tham chiếu đến hàm gửi dữ liệu tấn công (`DataPullFunc`) thông qua cây thư mục ẩn trong `ReplicatedStorage`.
* **InternalMonsterTable**: Trích xuất bảng cấu hình quái vật thô từ `upvalue` của hàm `GetMonsterInfo`.

### 2.2. Trích xuất Upvalue & Giải mã tên quái (Upvalue Extraction & Name Resolving)
Game sử dụng định danh động cho quái vật dạng `Monster_[UID]` (ví dụ: `Monster_47103`). Để hiển thị tên thật tĩnh trên giao diện và lọc quái chính xác:
1. Tool tìm hàm `GetMonsterInfo` của game thông qua biến môi trường toàn cục `_G.PathTool.MgrMonsterClient`.
2. Sử dụng thư viện debug của Executor `debug.getupvalues(MgrMonsterClient.GetMonsterInfo)` để bóc tách bảng dữ liệu cấu hình quái vật ẩn.
3. Ánh xạ ID tạm thời với bảng cấu hình hệ thống `_G.PathTool.CfgMonster.Tmpls` để lấy tên chuẩn (Name/Title) của quái vật.

---

## 3. CÁC TÁC VỤ NỀN (Background Workers / Coroutines)

Hệ thống vận hành song song 5 luồng tác vụ độc lập chạy ngầm để đảm bảo tính thời gian thực:

### 3.1. Luồng Tấn Công Thường (Auto Attack Worker)
* Chịu sự kiểm soát của công tắc tổng `Tự Động Đánh Quái` (`AppState.autoAttack`).
* **Điều kiện thực thi**: Chỉ hoạt động khi `AppState.autoAttack` được bật và `AppState.tpFarmEnabled` tắt.
* Quét quái định kỳ mỗi `0.2` giây trong bán kính chỉ định (`attackRadius`).
* Gọi API tấn công `ClientAttackMonster(monsterId)` trực tiếp thông qua module mạng của game để triệt tiêu quái ở cự ly gần.

### 3.2. Luồng Tấn Công Không Gian (TP Farm Worker)
* Hoạt động như một **chế độ phụ (sub-mode)** của công tắc tổng `Tự Động Đánh Quái`.
* **Điều kiện thực thi**: Chỉ kích hoạt khi cả `AppState.autoAttack` và `AppState.tpFarmEnabled` đều được bật.
* Thích hợp cho việc farm tầm xa hoặc bypass địa hình hiểm trở.
* Định vị quái vật gần nhất trong bán kính farm, tự động tính toán vị trí đứng an toàn phía **sau lưng quái 5 studs** (`monsterRoot.CFrame * CFrame.new(0, 0, 5)`).
* Ép góc nhìn nhân vật hướng về phía quái (`CFrame.lookAt`) và di chuyển nhân vật đến điểm an toàn bằng cách thay đổi `CFrame` trực tiếp (glide).
* Bật trạng thái thú cưỡi (`ToggleMount(true)`), thực thi bắn remote tấn công `MonsterAttackChannel` lên Server, sau đó hạ thú cưỡi (`ToggleMount(false)`).

### 3.3. Luồng Tự Động Bắt Quái (Auto Catch Worker)
* Định vị quái đang trong trạng thái cạn máu chờ thu phục (nhận diện qua bộ quét `Catch` của `SmartScanMonsters`).
* Nếu khoảng cách xa hơn `20` studs, kích hoạt tự động dịch chuyển đến tọa độ quái vật.
* Gọi chuỗi API `ClientCatchMonsterStart` -> Chờ hoàn thành hành động (1.5s - 5s) -> Gọi `ClientCatchMonsterComplete` để thu phục thú cưng một cách bất đồng bộ (`task.spawn`).

### 3.4. Luồng Hồi Máu Thú Cưng (Smart Auto Heal)
* Kiểm soát thông qua cơ chế **Khóa trạng thái (Mutex Lock)** bằng cờ `AppState.isHealing` để đóng băng tất cả các luồng farm khác khi đang thực hiện hồi máu.
* **Cơ chế tính toán thú cưng kiệt sức**: Đối chiếu số lượng Pet hiển thị trên danh sách giao diện (`PetList` UI) với số lượng Pet thực tế đang spawn trên Workspace để tìm ra số Pet đã chết.
* **Quy trình hồi máu**:
  1. Nếu số lượng Pet chết đạt ngưỡng (`healThreshold`), kích hoạt hồi phục.
  2. Định vị suối nước nóng gần nhất (`Recover` zone).
  3. Tạo một `Part` ảo đóng vai trò bệ đỡ dưới chân nhân vật tại suối nước nóng để tránh tình trạng nhân vật bị lọt hố/rơi tự do khi bản đồ chưa kịp load (Map Streaming).
  4. Teleport nhân vật đến suối nước nóng và khóa di chuyển trong `9` giây để Pet hồi đầy máu.
  5. Xóa bệ đỡ ảo, dùng `SafeTeleport` đưa người chơi quay về tâm bãi farm ban đầu và mở khóa trạng thái.

### 3.5. Luồng Bám Bãi (Smart Return)
* Giám sát khoảng cách giữa vị trí hiện tại của nhân vật và tâm bãi farm được cấu hình.
* Nếu khoảng cách vượt ngưỡng cho phép (`attackRadius + 20`), tool sẽ tự động gọi `SafeTeleport` kéo nhân vật trở lại tâm bãi farm để tránh tình trạng bị quái đẩy đi quá xa hoặc đi lạc bản đồ.

---

## 4. HƯỚNG DẪN DEV / BẢO TRÌ (Maintenance & Troubleshooting)

* **Lỗi click hụt / Không dịch chuyển**: 
  * Kiểm tra lại hàm `Utils.SafeTeleport`. Đảm bảo không bị chặn bởi các cơ chế chống noclip mới của game.
* **Lỗi không nhận diện được tên quái**:
  * Kiểm tra xem cấu trúc `_G.PathTool.CfgMonster.Tmpls` của game có thay đổi vị trí lưu trữ (ví dụ: đổi key `tmplId` thành `templateId`).
* **Lỗi kẹt tại suối nước nóng**:
  * Nếu thời gian hồi máu trên server tăng lên, hãy tăng thời gian khóa `task.wait(9)` trong luồng hồi máu tương ứng.
