Chào Sơn. Bản tài liệu này cần được cập nhật ngay những "kinh nghiệm xương máu" thực chiến mà chúng ta vừa bóc tách được từ mã nguồn của game (nhất là vụ Dot Syntax, đảo tham số và UI Blocker).

Dưới đây là bản tài liệu đã được viết lại chuẩn chỉnh, đầy đủ các lưu ý kỹ thuật mới nhất để làm bộ khung vững chắc cho các module tiếp theo.

---

# 📂 TÀI LIỆU DỰ ÁN: R-CLIENT PRO (ROBLOX SCRIPT HUB) - BẢN CẬP NHẬT

## 1. TỔNG QUAN DỰ ÁN

* **Tên dự án:** R-Client Pro
* **Mục tiêu:** Xây dựng bộ công cụ tự động hóa (Auto-Farm, Auto-Hatch, Bypass UI, Boss Hunt) cho một tựa game trên nền tảng Roblox.
* **Ngôn ngữ/Giao diện:** Lua / Thư viện UI Rayfield.
* **Cốt lõi kỹ thuật:** Hạn chế gọi `RemoteEvent/RemoteFunction` chay để tránh Anti-Cheat. Dự án sử dụng kỹ thuật **Hooking trực tiếp vào Client API** của game thông qua biến môi trường toàn cục `getrenv()._G`.

## 2. KHÁM PHÁ API LÕI CỦA GAME (GAME ENVIRONMENT)

Toàn bộ dữ liệu và hàm xử lý (Logic/UI) của game được đóng gói trong: `local env = getrenv()._G.PathTool`

⚠️ **QUY TẮC TỐI THƯỢNG (SYNTAX RULE):** Toàn bộ các hệ thống API của tựa game này (từ Logic đến UI) đều sử dụng **Dấu Chấm (`.`)** thay vì Dấu Hai Chấm (`:`) truyền thống của Lua. Việc dùng `:` sẽ làm dư tham số `self` và gây lỗi Silent Fail.

### A. Hệ thống Quản lý Giao diện (ViewManagerBase)

Quản lý việc mở/đóng UI xuyên tường (Bypass UI) bất chấp khoảng cách vật lý.

* **Cách gọi chuẩn:** `env.ViewManagerBase.OpenView("Tên_View")` hoặc `env.ViewManagerBase.CloseView("Tên_View")`.
* **Kỹ thuật UI Blocker:** Thay vì đợi UI hiện lên rồi mới đóng, dự án sử dụng Hook đè trực tiếp lên `OpenView` để chặn đứng các popup rác (như `GambleRewardUI` khi nổ trứng) ngay từ trong trứng nước.
* **Danh sách View quan trọng:**
* *Cửa hàng / Túi đồ:* `StoreView`, `ItemBagView`, `PetBagView`
* *Pet & Trứng:* `EggSelectView`, `EggHatchSkipView`, `PetVaultView`, `PetRecycleView`, `PetCollectView`
* *Khác:* `GambleRewardUI` (Bảng thông báo nhận Pet), `AchieveView`, `SettingView`



### B. Hệ thống Ấp Trứng (EggSystem & CfgEgg)

Dùng để bypass thời gian chờ, tự động nhồi trứng và thu hoạch.

* **Đường dẫn cấu hình trứng:** `env.CfgEgg.Tmpls` (Chứa danh sách ID, Tên, và Thời gian ấp).
* **Đường dẫn Data Player:** `gamePlayer.egg.saveData.H[tostring(slot)]`.
* *Lưu ý:* Key của Lò ấp là **String** (VD: `"1"`), không phải Number. Thời gian `T = 0` nghĩa là trứng đã chín.


* **Đường dẫn Logic (`env.EggSystem`):**
* `ClientHatchStart(slot, eggId)`: Bỏ trứng vào lò (Lưu ý: `slot` truyền vào trước).
* `ClientHatchTaken(slot)`: Thu hoạch trứng đã chín.
* `ClientHatchSkip(slot, true)`: Dùng vé bỏ qua thời gian ấp. (Bắt buộc phải có tham số `true` để xác nhận).



### C. Hệ thống Dữ liệu Pet & Túi (PetData)

Dùng để kiểm tra sức chứa túi an toàn trước khi Auto-Farm/Auto-Hatch.

* **Đường dẫn Logic:** `env.PetData` (Nằm trong `gamePlayer.pet`)
* `GetBagAmount()`: Trả về số lượng Pet hiện có.
* `GetBagCapacity()`: Trả về sức chứa tối đa của túi.



## 3. CẤU TRÚC FILE MODULE (Github Repository)

Dự án được thiết kế theo dạng Modular, nạp động qua `loadstring` (kèm Bypass Cache GitHub bằng Time Query).

1. **`auto_execute.txt`:** Hệ thống nạp script chống nhân bản (Anti-Double UI).
2. **`features/boss_hunt.txt`:** Tìm kiếm RootPart của Boss qua từ khóa và Teleport ra sau lưng Boss.
3. **`features/server_manager.txt`:** Quản lý Session Timer, Server Hop và Auto-Rejoin chống Kick/Disconnect.
4. **`features/rgame_farm.txt`:** Auto Attack & Catch. Có tính năng **Smart Heal** và lưu vị trí `savedFarmPosition`.
5. **`features/shops_and_guis.txt`:** Menu gọi nhanh các bảng giao diện hệ thống (Bypass UI).
6. **`features/hatch_egg.txt`:** **Smart Auto Hatch V7**. Tự động bắt data trứng, chặn UI rác (GambleRewardUI), xử lý đa luồng Start/Skip/Claim an toàn chống kẹt, và tự ngắt cầu dao khi đầy túi.
7. **`features/auto_dungeon.txt`:** *(Đang phát triển)* Đi phó bản tự động.

## 4. HƯỚNG DẪN DÀNH CHO AI (PROMPT INSTRUCTION)

*Khi người dùng yêu cầu tạo mới hoặc sửa module, AI phải tuân thủ nghiêm ngặt các quy tắc sau:*

1. **Luôn sử dụng Dot Syntax (`.`)** khi gọi các hàm của `env.EggSystem` hoặc `env.ViewManagerBase`.
2. **Key Data luôn là String:** Khi truy xuất dữ liệu từ các mảng được Game lưu trữ (như `saveData.H`), phải ép kiểu `tostring()`.
3. **Hooking thay vì Remote:** Ưu tiên dùng `getrenv()._G.PathTool` để giao tiếp với Client Logic. Chỉ dùng RemoteEvent khi Client Logic không hỗ trợ.
4. **Viết Test Độc lập:** Khi phát triển tính năng mới có tính rủi ro (đọc/ghi UI, chọc vào hàm cốt lõi), luôn cung cấp một Script Test nhỏ (có hàm lưu log vào Clipboard tiếng Anh) để người dùng chạy thử nghiệm trước khi tích hợp vào vòng lặp Rayfield UI chính.
