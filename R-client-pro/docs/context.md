# 📂 TÀI LIỆU DỰ ÁN: R-CLIENT PRO (ROBLOX SCRIPT HUB)

## 1. TỔNG QUAN DỰ ÁN
* **Tên dự án:** R-Client Pro 
* **Mục tiêu:** Xây dựng bộ công cụ tự động hóa (Auto-Farm, Auto-Hatch, Bypass UI, Boss Hunt) cho một tựa game trên nền tảng Roblox.
* **Ngôn ngữ/Giao diện:** Lua / Thư viện UI Rayfield.
* **Cốt lõi kỹ thuật:** Hạn chế gọi `RemoteEvent/RemoteFunction` chay để tránh Anti-Cheat. Thay vào đó, dự án **sử dụng kỹ thuật Hooking trực tiếp vào Client API** của game thông qua biến môi trường toàn cục `getrenv()._G`.

## 2. KHÁM PHÁ API LÕI CỦA GAME (GAME ENVIRONMENT)
Toàn bộ dữ liệu và hàm xử lý (Logic/UI) của tựa game này được Dev đóng gói và giấu trong:
`local env = getrenv()._G.PathTool`

Dưới đây là các Module và API quan trọng đã trích xuất được:

### A. Hệ thống Quản lý Giao diện (ViewManagerBase)
Hệ thống quản lý việc mở/đóng UI xuyên tường (Bypass UI) bất chấp trạng thái của người chơi.
* **Cách gọi chuẩn:** `env.ViewManagerBase.OpenView("Tên_View")` hoặc `env.ViewManagerBase:OpenView("Tên_View")`
* **Danh sách các View quan trọng đã tìm thấy:**
  * Cửa hàng / Túi đồ: `StoreView`, `ItemBagView`, `PetBagView`
  * Pet & Trứng: `EggSelectView`, `EggHatchSkipView`, `PetVaultView`, `PetRecycleView`, `PetCollectView`, `PetRideView`, `PetTeamView`, `PetEvolveView`, `PetTransformView`
  * Khác: `TaskView`, `ActivityView`, `GambleRewardView`, `AchieveView`, `SettingView`, `CodeView`

### B. Hệ thống Ấp Trứng (EggSystem & CfgEgg)
Dùng để bypass thời gian chờ, tự động nhồi trứng và thu hoạch mà không cần đứng gần lò ấp.
* **Đường dẫn cấu hình trứng:** `env.CfgEgg` (Chứa danh sách ID và Tên của mọi loại trứng).
* **Đường dẫn Logic:** `env.EggSystem`
  * `ClientHatchStart(eggId, slot)`: Bỏ trứng vào lò.
  * `ClientHatchTaken(slot)`: Thu hoạch trứng đã chín.
  * `ClientHatchSkip(slot)`: Dùng vé bỏ qua thời gian ấp.

### C. Hệ thống Dữ liệu Pet & Túi (PetData)
Dùng để kiểm tra sức chứa túi an toàn trước khi Auto-Farm/Auto-Hatch.
* **Đường dẫn Logic:** `env.PetData`
  * `GetBagAmount()`: Trả về số lượng Pet hiện có.
  * `GetBagCapacity()`: Trả về sức chứa tối đa của túi.

## 3. CẤU TRÚC FILE MODULE HIỆN TẠI (Github Repository)
Dự án được chia nhỏ thành các module độc lập để dễ quản lý, được nạp qua `loadstring` trong file `main.txt`.

1. **`auto_execute.txt`:** Hệ thống nạp script chống nhân bản (Anti-Double UI). Kiểm tra `getgenv().RClientPro_Loaded` và ghi file vào thư mục `autoexec` của Executor.
2. **`features/boss_hunt.txt`:** Chuyên tìm kiếm RootPart của Boss qua từ khóa (flaragon, godzilla...) và Teleport người chơi đến phía sau Boss.
3. **`features/server_manager.txt`:** Quản lý Session Timer (thời gian treo máy), Server Hop (tìm server ít người qua Roblox API) và Auto-Rejoin chống Kick/Disconnect bằng cách lắng nghe `CoreGui.ErrorPrompt`.
4. **`features/rgame_farm.txt`:** Auto Attack & Catch. Tích hợp tính năng **Smart Heal** (Đếm số pet sống trên map so với UI, tự động bay ra suối máu, tạo bệ đỡ và quay lại) và tính năng lưu vị trí Farm (`savedFarmPosition`). Có xử lý ngoại lệ khi đang cưỡi thú (`RidePetId`).
5. **`features/shops_and_guis.txt`:** Menu gọi nhanh các bảng giao diện hệ thống (Bypass UI) đã liệt kê ở phần 2.A.
6. **`features/hatch_egg.txt`:** **Smart Auto Hatch**. Quét tự động danh sách trứng từ `CfgEgg` đưa vào Dropdown. Tự động kiểm tra túi đồ đầy qua `PetData` để ngắt cầu dao (Stop if Full), gọi `EggSystem` để Start và Claim trứng.

## 4. HƯỚNG DẪN DÀNH CHO AI (PROMPT INSTRUCTION)
*Khi người dùng tải lên file này, AI hãy đọc kỹ toàn bộ bối cảnh trên.*
1. Hiểu rằng dự án ưu tiên dùng `getrenv()._G.PathTool` thay vì `RemoteEvent`.
2. Hiểu cấu trúc Rayfield UI đang sử dụng (`Window:CreateTab`, `Tab:CreateSection`, `CreateButton`, `CreateToggle`, `CreateDropdown`).
3. Chờ người dùng yêu cầu module tiếp theo cần phát triển hoặc fix bug, sau đó phản hồi bằng code Lua hoàn chỉnh tương thích với hệ sinh thái này.



## LẤY TẤT CẢ HÀM
-- Lấy biến toàn cục _G của chính con game
local game_env = getrenv()._G 

if game_env.PathTool then
    print("====================================")
    print("✅ ĐÃ TÌM THẤY PATH TOOL! Bắt đầu quét:")
    print("====================================")
    
    for key, value in pairs(game_env.PathTool) do
        print("🔹", tostring(key), "->", tostring(value))
        
        -- Nếu bên trong nó lại chứa một thư mục/bảng khác (như DoGuiButtonUtil) thì quét luôn
        if type(value) == "table" then
            for k2, v2 in pairs(value) do
                print("      ↳", tostring(k2), "->", tostring(v2))
            end
        end
    end
    print("====================================")
else
    warn("❌ Vẫn không thấy PathTool! Có thể game chưa load xong hoặc Dev đã giấu nó qua Module.")
end
