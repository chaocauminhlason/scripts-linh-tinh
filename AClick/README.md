# 🚀 Hướng dẫn sử dụng FastClick Pro (Dev Mode)

**FastClick Pro** là một bộ công cụ hỗ trợ AutoClick và Macro đa năng được thiết kế nguyên bản (Native UI) để hoạt động mượt mà và an toàn 100% bên trong môi trường Roblox Studio cũng như Game thực tế.

---

## 📥 Cách Cài Đặt (Dành cho Developer)
1. Mở dự án game của bạn trong **Roblox Studio**.
2. Ở cửa sổ **Explorer**, tìm đến thư mục `StarterPlayer` > `StarterPlayerScripts`.
3. Tạo một `LocalScript` mới.
4. Copy toàn bộ mã nguồn FastClick Pro và dán vào `LocalScript` đó.
5. Nhấn **Play** để trải nghiệm.

---

## 🎛️ Tổng quan Giao diện (UI)
Giao diện được thiết kế theo phong cách **Modern Dark Mode** với các tính năng:
- **Kéo thả tự do:** Nhấn giữ chuột trái vào bảng Menu để di chuyển nó quanh màn hình.
- **Thu nhỏ gọn gàng:** Nhấn nút `_` ở góc phải trên cùng để ẩn bảng đi. Lúc này, một nút xanh **"Mở FastClick"** nhỏ gọn sẽ xuất hiện ở cạnh trên màn hình để bạn gọi lại bảng bất cứ lúc nào.

---

## ⚡ 1. Nhóm Tính Năng: AutoClick
Tự động click tại vị trí con trỏ chuột hiện tại hoặc tự động vung vũ khí.

*   **Trạng thái (BẬT/TẮT):** Công tắc kích hoạt AutoClick cơ bản.
*   **Chế độ: Dùng Tool:**
    *   *TẮT:* Giả lập click chuột thật trên màn hình.
    *   *BẬT:* Bỏ qua chuột, chỉ liên tục sử dụng (Activate) vật phẩm/vũ khí bạn đang cầm trên tay (Tránh click nhầm khi xoay Camera).
*   **Tốc độ (s):** Thời gian nghỉ giữa mỗi lần click (Mức an toàn tối thiểu là 0.015s). Tích hợp **Humanized Click** (Dao động nhịp độ ngẫu nhiên) để tránh bị Anti-Cheat quét.
*   **Số lần (0 = Vô hạn):** Tự động tắt sau khi click đủ số lượng. *(Hệ thống mặc định đặt là 1 lần để đảm bảo an toàn, tránh treo máy khi quên cài đặt).*

---

## 📍 2. Nhóm Tính Năng: Tọa Độ & Macro Chuỗi (Sequence)
Ghi nhớ các vị trí trên màn hình và click tuần tự theo chu kỳ.

**Cách thiết lập chuỗi:**
1. Di chuyển chuột đến điểm thứ nhất, ấn phím **`P`**.
2. Hệ thống sẽ báo đã lưu thành công kèm tọa độ (X, Y).
3. Lặp lại bước 1 cho các điểm tiếp theo.
4. Bấm nút đỏ **"🗑️ Xóa toàn bộ"** để làm lại.

**Chạy chuỗi:**
*   **Trạng thái chuỗi:** Bật công tắc để tool bắt đầu click lần lượt từ Điểm 1, Điểm 2, Điểm 3... 
*   **Số vòng (0 = Vô hạn):** Tự động ngắt công tắc sau khi chạy đủ vòng. *(Hệ thống mặc định đặt là 1 vòng để tránh lỗi vòng lặp vô tận ngoài ý muốn).*

---

## 🛠️ 3. Nhóm Tính Năng: Tiện Ích (Utilities)

### 🛡️ Chống AFK *(Mặc định: BẬT)*
Khi bật, hệ thống sẽ tự động gõ một phím ảo (F15) mỗi khi phát hiện bạn chuẩn bị AFK, giúp bạn treo game xuyên đêm không bị Roblox kick (giới hạn 20 phút).

### 📡 Lệnh Follow (Hệ thống Radar & Thú cưng) *(Mặc định: BẬT)*
Cho phép người chơi khác gọi nhân vật của bạn chạy đến chỗ họ (Giống tính năng Thú cưng/Đệ tử).
*   **Bám sát liên tục:** 
    *   *BẬT (Mặc định):* Khi đến gần mục tiêu, nhân vật sẽ đứng chờ. Nếu mục tiêu di chuyển ra xa, nhân vật sẽ tiếp tục tự động đuổi theo.
    *   *TẮT:* Nhân vật chỉ chạy đến tọa độ mục tiêu 1 lần duy nhất rồi tự ngắt kết nối.
*   **🛑 Hủy Follow hiện tại:** Nút khẩn cấp giúp bạn ngắt kết nối và dừng nhân vật lại ngay lập tức nếu bị đưa vào chỗ nguy hiểm.
*   **Màn hình Radar:** Cập nhật Real-time tên mục tiêu, trạng thái dò tìm "...", và tọa độ XYZ.

---

## 💬 4. Bảng Lệnh Chat (Chat Commands)
Hỗ trợ bộ lệnh gõ tắt (Aliases) cực nhanh để điều khiển ngay trong khi đang chat hoặc combat.

| Chức năng | Lệnh đầy đủ | ⚡ Lệnh gõ tắt (Khuyên dùng) |
| :--- | :--- | :--- |
| **Bật AutoClick** | `!start` | `!s` hoặc `!on` |
| **Tắt AutoClick** | `!stop` | `!x` hoặc `!off` |
| **Bật Chuỗi (Sequence)** | `!start_seq` | `!ss` hoặc `!play` |
| **Tắt Chuỗi (Sequence)** | `!stop_seq` | `!xs` hoặc `!pause`|
| **Bắt đầu Follow** | `follow` | `!f` |
| **Hủy Follow** | `unfollow` | `!uf` hoặc `!xf` |

> 🔒 **Bảo mật lệnh Follow:** Lệnh Hủy Follow (`!uf`, `!xf`) được khóa an toàn. Chỉ có **bạn (chủ tool)** hoặc **người đang được bạn đi theo** mới có quyền gõ lệnh này để ngắt kết nối. Người chơi khác không thể gõ để phá ngang quá trình.
