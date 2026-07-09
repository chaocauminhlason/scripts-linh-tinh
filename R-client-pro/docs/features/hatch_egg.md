

```markdown
# TÀI LIỆU BÀN GIAO KỸ THUẬT: MODULE SMART AUTO HATCH V9

**Người thực hiện/Bàn giao:** Lê Hồng Sơn  
**Ngày cập nhật cuối:** 01/07/2026  
**Phiên bản:** V9 (Final Fixed)  
**Môi trường:** Roblox Executor (Yêu cầu hỗ trợ Thread Identity API)

---

## 1. TỔNG QUAN (OVERVIEW)
Module **Smart Auto Hatch V9** là công cụ tự động hóa quá trình ấp và thu hoạch trứng trong game. Điểm khác biệt lớn nhất của phiên bản này so với các bản cũ là khả năng **tự động đồng bộ UI native** và **vượt qua cơ chế Anti-Cheat (chặn luồng Executor)** mới nhất của nhà phát triển game.

**Chức năng chính:**
- Quét và đọc cấu hình trứng từ file game gốc (`CfgEgg`).
- Tự động bỏ trứng vào lò trống (Auto Start).
- Tự động thu hoạch khi trứng chín (Auto Claim).
- Theo dõi sức chứa túi Pet để tự động dừng tool khi đầy, chống kẹt logic.

---

## 2. KIẾN TRÚC & CƠ CHẾ BYPASS (QUAN TRỌNG)

### Vấn đề của bản cũ:
Game đã cập nhật hệ thống kiểm soát quyền thực thi. Khi Executor (thường chạy ở Identity 7 hoặc 8) gọi vào các hàm cập nhật UI hoặc gửi Request của game (yêu cầu Identity 2), game sẽ báo lỗi `nil`, văng lỗi `Cannot require a non-RobloxScript module` hoặc UI không chịu cập nhật dữ liệu.

### Giải pháp cốt lõi: Thread Identity Downgrade
Module sử dụng kỹ thuật "Ép quyền luồng ngầm". Trước khi tương tác với hàm của game, luồng thực thi sẽ được hạ xuống mức người chơi thông thường, sau đó mới trả lại quyền cho Executor.

```lua
-- Ví dụ cơ chế hoạt động:
local oldId = get_thread_id()
set_thread_id(2) -- Hạ quyền xuống Identity 2 (LocalScript gốc)

-- [Thực thi các hàm của game tại đây]
env.EventSystem.Execute("EggHatchChange") -- Ép đồng bộ UI

set_thread_id(oldId) -- Trả lại quyền siêu Admin cho Executor

```

---

## 3. LUỒNG HOẠT ĐỘNG DỮ LIỆU (DATA FLOW)

Không sử dụng `RemoteEvent` hay `RemoteFunction` trực tiếp để tránh bị Server ban do thiếu Context. Tool can thiệp trực tiếp vào Object nội bộ của Client:

1. **Đọc trạng thái (Read State):**
* Sử dụng `clientEgg:GetHatchEggTmplId(slotNum)` để lấy ID trứng đang ấp.
* Sử dụng `clientEgg:GetHatchEggStartTick(slotNum)` để lấy thời điểm bắt đầu ấp.
* Kết hợp với `HatchTime` từ `env.CfgEgg.Tmpls` để tính toán thời gian thực chính xác.


2. **Ghi trạng thái (Write State):**
* Bỏ trứng: Gọi `env.EggSystem.ClientHatchStart` hoặc `clientEgg:StartHatch`.
* Thu hoạch: Gọi `env.EggSystem.ClientHatchTaken` hoặc `clientEgg:ClientHatchTaken`.


3. **Đồng bộ giao diện (Sync UI):**
* Gọi `env.EventSystem.Execute("EggHatchChange")` ngay sau khi ghi trạng thái thành công để engine game tự động vẽ lại Frame.



---

## 4. HƯỚNG DẪN BẢO TRÌ (TROUBLESHOOTING & MAINTENANCE)

Người kế thừa module cần lưu ý các điểm sau khi game có bản cập nhật mới:

* **Lỗi không cập nhật UI:** Kiểm tra lại object `env.EventSystem`. Dev có thể đổi tên event `"EggHatchChange"` thành một tên khác. Dùng Spy tool để bắt lại event name.
* **Lỗi `nil` khi gọi hàm (Bị chặn quyền):** Đảm bảo Executor đang dùng có hỗ trợ API `setthreadidentity` / `setidentity`. Nếu thiếu API này, toàn bộ module sẽ không hoạt động.
* **Lỗi đọc sai trạng thái (Ghost Data):** Tuyệt đối không đọc dữ liệu từ `saveData.H` vì Dev có thói quen xóa ID rác nhưng không dọn sạch table. Luôn dùng hàm chính thống `GetHatchEggTmplId()` để kiểm tra trạng thái Lò.

---

## 5. CẤU TRÚC FILE LIÊN QUAN (DEPENDENCIES)

Module phụ thuộc vào các đường dẫn Global (`_G.PathTool`) nội tại của game:

* `env.BossRoomSystemClient.gamePlayer.egg` (Chứa logic Local)
* `env.BossRoomSystemClient.gamePlayer.pet` (Chứa logic kiểm tra túi đồ)
* `env.CfgEgg` (Chứa cấu hình thời gian ấp)
* `env.EventSystem` (Chứa hệ thống phát sự kiện cập nhật View)

*(Hết tài liệu)*

