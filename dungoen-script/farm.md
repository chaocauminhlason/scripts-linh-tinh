# 📜 TÀI LIỆU BÀN GIAO KỸ THUẬT: 

**Tệp thực thi chính:** `farm.txt`  
**Phiên bản:** V6.0 (Cập nhật kiến trúc Dynamic UI & No-Clock Debounce)  
**Mục đích:** Tự động hóa hoàn toàn quá trình leo tháp/vượt ngục (Hầm ngục) với tốc độ phản hồi tính bằng mili-giây, chống kẹt wave, và qua mặt hệ thống Anti-cheat của game.

---

## 🏗️ 1. KIẾN TRÚC HỆ THỐNG (CORE ARCHITECTURE)
Script được thiết kế dựa trên mô hình **Đa luồng giả lập (Coroutines)**, chia nhỏ các tác vụ để chạy song song (Asynchronous) nhằm tối ưu hóa CPU và tránh xung đột logic. Bao gồm 4 luồng chính:

1. **Luồng UI (Event-driven):** Lắng nghe các tương tác kéo thả, bấm nút, và thay đổi mảng dữ liệu (Array manipulation) theo thời gian thực.
2. **Luồng CFrame Glide (RunService.Heartbeat):** Bơm gia tốc di chuyển ngầm ở mỗi khung hình (FPS).
3. **Luồng Máy Trạng Thái (State Machine - 20 Ticks/sec):** Giám sát môi trường game (Máu quái vật, khoảng cách dịch chuyển) để phất cờ (Flags) điều phối.
4. **Luồng Core Auto (Logic Engine):** Chịu trách nhiệm thực thi đường đi, tương tác cửa và nhặt Buff dựa trên cờ trạng thái.

---

## 🚀 2. CÁC TÍNH NĂNG VÀ TỐI ƯU HÓA NỔI BẬT

### A. Cơ chế Quét thông minh (Smart Scanner)
* **Tối ưu hóa GetDescendants:** Thay vì quét toàn bộ `Workspace` (gây khựng FPS), tool định vị thẳng vào thư mục `AbyssClientModel`.
* **Gộp vòng lặp:** Quét tìm Cửa (`AbyssDoorInfo`) và Trụ Buff (`DoGUI`) diễn ra trong cùng một vòng lặp (O(N) thay vì O(2N)). Tốc độ quét tăng gấp 100 lần.

### B. Cỗ máy Trạng thái "Xác nhận Kép" (No-Clock Double Debounce)
* **Loại bỏ sự phụ thuộc vào UI game:** Không dùng đồng hồ đếm ngược (`FmTime`) làm mốc qua màn do UI game thường có độ trễ.
* **Đọc máu trực tiếp:** Quét máu quái vật (`Humanoid.Health <= 0`) với tốc độ 0.05s/lần.
* **Debounce 1.5 Giây:** Khắc phục triệt để lỗi chạy non ở các phòng có nhiều đợt quái (Waves) hoặc phòng Hồi sinh (không có quái). Tool sẽ chờ một khoảng "im lặng tuyệt đối" kéo dài 1.5 giây trước khi xác nhận `waveCleared = true`.

### C. Động cơ tăng tốc tàng hình (CFrame Glide Engine)
* **Bypass Anti-Cheat:** Vận hành thông qua `RunService.Heartbeat`, giữ nguyên chỉ số `WalkSpeed = 16` mặc định nhưng liên tục cộng dồn một Vector gia tốc (`EXTRA_SPEED = 8`) vào tọa độ của `HumanoidRootPart`.
* **Kết quả:** Nhân vật di chuyển nhanh gấp rưỡi một cách mượt mà mà không bị server đánh flag "SpeedHack" hay bị giật ngược (Rubberbanding).

### D. Bản đồ Dữ liệu Tĩnh (Data Mapping)
* Bảng `STAGES_WITH_BUFF` định nghĩa cứng 10 màn rớt trụ Buff (1, 3, 5, 7, 8, 10, 12, 14, 16, 19).
* Tool lập tức bỏ qua logic rà soát `DoGUI` ở 10 màn còn lại, bay thẳng ra cửa không một động tác thừa.

### E. Giao diện Động (Dynamic UI Layout)
* Tách biệt 2 danh sách **Ưu Tiên Cửa** và **Ưu Tiên Buff** thành 2 Tab riêng biệt.
* Giao diện có khả năng tự động co giãn chiều cao (Dynamic Resize).
* Thuật toán Render List thay đổi trực tiếp (Reference Pointer) vào mảng dữ liệu gốc, giúp việc đổi thứ tự ưu tiên trên UI có hiệu lực ngay ở mili-giây tiếp theo mà không cần khởi động lại tool.

---

## ⚙️ 3. HƯỚNG DẪN TÙY CHỈNH (DÀNH CHO DEV)

Bạn có thể thay đổi các thông số lõi ở ngay đầu file `farm.txt`:

1. **Tùy chỉnh Gia tốc (CFrame Glide):**
   ```lua
   local EXTRA_SPEED = 8 -- Mặc định là 8. Tăng lên 10-12 nếu server không check gắt. Không nên vượt quá 15.
   Cập nhật Mảng Ưu Tiên Mặc định:

Mảng PriorityList: Định nghĩa các cửa (tên lấy từ ITEM_DATA).

Mảng PRIORITY_BUFF_LIST: Chứa tên các Buff từ bậc IV xuống I.

(Lưu ý: Tên ghi trong mảng phải khớp 100% (không phân biệt hoa/thường) với text hiển thị ở LabName của game).

Cập nhật Bản Đồ Phân Bố Buff (Data Map):

Lua
local STAGES_WITH_BUFF = {
    ["1/20"] = true, ["3/20"] = true, ... -- Thêm/Bớt các phòng nếu NPH update cấu trúc hầm ngục.
}
🔄 4. LUỒNG THỰC THI THỰC TẾ (WORKFLOW)
[Enter] Bước qua cửa (Dịch chuyển > 150 studs) ➡️ Reset toàn bộ Flag (Trí nhớ) ➡️ Bắt đầu đếm thời gian Debounce.

[Combat] Quét thấy quái / Đồng hồ hiện ➡️ Đánh nhau ➡️ Liên tục reset bộ đếm Debounce về 0.

[Clear] Quái chết hết VÀ đồng hồ tắt ➡️ Bộ đếm Debounce chạy đến 1.5 giây ➡️ Kích hoạt waveCleared = true.

[Action] Core Auto bắt đầu chạy ➡️ Tính toán điểm số Cửa ưu tiên.

[Talent] Kiểm tra STAGES_WITH_BUFF:

Nếu True: Tìm trụ DoGUI ➡️ Pathfinding tới gần (< 4 studs) ➡️ Ép phím E (0.05s) ➡️ Quét UI & So sánh điểm ➡️ Click chuột ảo.

Nếu False: Bỏ qua khối lệnh Talent.

[Exit] Pathfinding hướng đến Cánh cửa đã chọn ➡️ Bật cờ isWaitingForTeleport ➡️ Đứng yên chờ server kéo sang phòng mới ➡️ Lặp lại Bước 1.

Tài liệu được cập nhật tự động vào lúc dự án hoàn thành kiến trúc V6.0.