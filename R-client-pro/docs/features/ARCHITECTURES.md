# 🏗️ R-Client Pro - System Architecture Documentation

## 1. Tổng quan dự án (Project Overview)
**R-Client Pro** là một dự án Roblox Automation Script nâng cao, được thiết kế theo kiến trúc **Modular & Centralized Control** (Kiến trúc mô-đun hóa và Điều khiển tập trung). 

Thay vì dồn toàn bộ logic vào một file script khổng lồ, hệ thống được chia nhỏ thành các **Core Services** và các **Feature Modules**. Điều này giúp tối ưu hóa hiệu năng, dễ dàng bảo trì, debug và hỗ trợ mở rộng tính năng linh hoạt mà không gây xung đột mã nguồn.

> [!IMPORTANT]
> **Triết lý thiết kế cốt lõi:** Hạn chế tối đa việc tương tác với `RemoteEvent/RemoteFunction` gốc của game để tránh bị hệ thống Anti-Cheat phát hiện. Thay vào đó, dự án thực hiện **Hooking trực tiếp** vào Client API của game thông qua biến môi trường toàn cục `getrenv()._G.PathTool`.

---

## 2. Cấu trúc thư mục (Directory Structure)

```text
📁 R-Client-Pro/
├── 📄 main.txt                     # Entry point (Cache bypass, khởi tạo UI, SafeLoad core & features)
├── 📁 core/                        # Các dịch vụ cốt lõi (Nạp trước)
│   ├── 📄 utilities.txt            # Hàm helper dùng chung (SafeLoad, Format, HTTP,...)
│   ├── 📄 webhook.txt              # Quản lý gửi thông báo đến Discord Webhook
│   └── 📄 system_controller.txt    # Bộ não điều khiển toàn cục (Pause/Resume, Module Registry, Task Queue)
└── 📁 features/                    # Các module tính năng độc lập (Nạp động)
    ├── 📄 farm.txt                 # Tự động tấn công, bắt thú, hồi máu, lưu vị trí
    ├── 📄 tracker.txt              # Định vị GPS trực tiếp, theo dõi người chơi, lệnh chat
    ├── 📄 boss_hunt.txt            # Săn Boss thế giới / Boss đặc biệt, quét RAM cấu hình
    ├── 📄 auto_rift.txt            # Logic tự động săn Rift
    ├── 📄 auto_dungeon.txt         # Tự động tạo, tham gia và rời phó bản
    ├── 📄 server_manager.txt       # Quản lý Rejoin nếu bị kick, Hop server săn thời tiết
    ├── 📄 shops_and_guis.txt       # Cửa sổ gọi nhanh các bảng giao diện (Bypass UI)
    ├── 📄 hatch_egg.txt            # Tự động ấp trứng (vòng lặp luồng cục bộ)
    ├── 📄 pick_up_event.txt        # Tự động nhặt vật phẩm sự kiện
    ├── 📄 optimization.txt         # Giảm tải đồ họa, khóa 15 FPS, anti-AFK, tắt màn hình
    └── 📄 ai_assistant.txt         # Tích hợp trợ lý ảo AI nhận diện lệnh điều khiển qua chat/webhook
```

---

## 3. Các thành phần cốt lõi (Core Components)

### 3.1. Main Script (`main.txt`)
* **Nhiệm vụ:** Là điểm khởi chạy duy nhất (Entry point) của hệ thống.
* **Luồng hoạt động:**
  1. Gửi request lấy thông tin Commit SHA mới nhất từ API GitHub nhằm **Bypass Cache (Fastly CDN)** hoàn toàn.
  2. Nạp thư viện **Rayfield UI Library**.
  3. Sử dụng cơ chế nạp an toàn `SafeLoad` để tải lần lượt các file trong thư mục `core/`.
  4. Tạo giao diện UI chính.
  5. Nạp động tất cả các module trong thư mục `features/`, truyền đối tượng `Window`, `Utils`, và `Controller` làm tham số đầu vào.
  6. Kích hoạt tính năng lưu cấu hình UI (`Rayfield:LoadConfiguration()`).

### 3.2. System Controller (`system_controller.txt`)
* **Nhiệm vụ:** Đóng vai trò là một Event Bus / State Manager trung tâm để điều phối trạng thái hoạt động của toàn bộ script.
* **Các tính năng chính:**
  * **Global Pause/Resume:** Quản lý cờ hiệu `_G.SystemController.IsPaused`. Khi kích hoạt dừng khẩn cấp, Controller sẽ phát tín hiệu yêu cầu tất cả module tạm dừng các vòng lặp xử lý logic của chúng.
  * **Module Registry:** Duy trì danh sách các module đang hoạt động trong bảng `Modules = {}` thông qua phương thức `registerModule()`.
  * **Task Queue (Hàng đợi công việc):** Sắp xếp mức độ ưu tiên giữa các nhiệm vụ tự động (Ví dụ: Khi đang farm quái thường mà có Boss xuất hiện -> Tạm thời lưu vị trí farm -> Điều hướng đi săn Boss -> Hoàn thành săn Boss -> Quay lại tiếp tục farm).

---

## 4. Quy tắc cú pháp & Tương tác API game (Critical Rules)

> [!CAUTION]
> **Quy tắc cú pháp tối thượng (Dot Syntax Rule):**
> Toàn bộ các hệ thống API client của game (đóng gói trong `getrenv()._G.PathTool`) đều sử dụng cú pháp dấu **Chấm (`.`)** thay vì dấu Hai Chấm (`:`) truyền thống trong Lua.
>
> * Dùng đúng: `env.ViewManagerBase.OpenView("StoreView")`
> * Dùng sai: `env.ViewManagerBase:OpenView("StoreView")` (Sẽ gây lỗi dư tham số `self` và dẫn đến lỗi âm thầm - Silent Fail).

* **Truy xuất dữ liệu mảng lưu trữ:** Game sử dụng kiểu dữ liệu **String** cho các khóa (Keys) của mảng lưu trữ (ví dụ: `saveData.H[tostring(slot)]`). Khi gọi, luôn đảm bảo ép kiểu sang String qua hàm `tostring()`.
* **Hạ cấp phân quyền (Context Identity Mismatch):** Khi thực hiện các lệnh yêu cầu bắt đầu ấp trứng (`StartHatch`) hoặc gửi request dữ liệu từ executor, cần bọc lệnh trong `set_thread_id(2)` để hạ quyền Executor xuống mức Client Script thông thường, tránh bị phát hiện bởi Anti-Cheat.

---

## 5. Vòng đời của một Feature Module (Lifecycle)

Mỗi file trong thư mục `features/` được thiết kế dưới dạng một Anonymous Function nhận vào các tham số lõi:
```lua
return function(Window, Utils, Controller)
    -- 1. Khởi tạo State cục bộ (local variables)
    local isRunning = false
    
    -- 2. Đăng ký nhận diện với System Controller
    if Controller then
        Controller:registerModule("MyFeature", function(paused)
            if paused then
                -- Logic xử lý khi bị Pause (Dừng di chuyển, ngắt vòng lặp)
            else
                -- Logic xử lý khi được Resume
            end
        end)
    end

    -- 3. Tạo Giao diện UI tương ứng trên Window
    local Tab = Window:CreateTab("My Tab", 123456)
    
    -- 4. Tạo luồng xử lý độc lập (Không được chặn Main Thread)
    task.spawn(function()
        while task.wait(1) do
            if not isRunning then continue end
            if Controller and Controller.IsPaused then continue end
            
            -- Thực hiện logic tự động hóa tại đây
        end
    end)
end
```

---

## 6. Hướng dẫn dành cho Developer (Dev Guide)

### 6.1. Quy tắc thêm tính năng mới
1. Tạo một tệp tin `.txt` mới trong thư mục `features/`.
2. Định dạng cấu trúc module theo dạng chuẩn trả về một Function nhận tham số lõi `(Window, Utils, Controller)`.
3. Tuyệt đối không sử dụng hàm `while wait()` trực tiếp trên Main Thread. Tất cả các tác vụ lặp lại tuần hoàn bắt buộc phải bọc trong `task.spawn()`.
4. **Quản lý bộ nhớ (Garbage Collection):** Khi tạo các đối tượng tạm thời như Platform ảo hỗ trợ bay hoặc đường vẽ định vị, phải đảm bảo gọi phương thức `Destroy()` ngay sau khi tắt tính năng để ngăn chặn rò rỉ bộ nhớ (Memory Leak).

### 6.2. Giao tiếp giữa các Module
Các module độc lập tuyệt đối **không được phép tham chiếu chéo trực tiếp** lẫn nhau nhằm tránh hiện tượng Dính kết chặt (Tight Coupling). Mọi nhu cầu chia sẻ dữ liệu hoặc gọi lệnh liên thông phải thông qua trung gian `_G.SystemController` hoặc cập nhật giá trị thuộc tính dùng chung trên nhân vật `LocalPlayer`.

### 6.3. Xử lý lỗi ngoại lệ (Error Handling)
Dự án vận hành hoàn toàn trên môi trường client của game, nơi dữ liệu mạng và cấu trúc đối tượng có thể thay đổi bất thường. Do đó, các hành động tương tác với tài nguyên Roblox (Dịch chuyển, Raycast, JSON Decode, HTTP Request) **bắt buộc phải bọc trong câu lệnh `pcall`** để tránh crash script.

---

## 7. Các vấn đề tồn đọng & Kế hoạch nâng cấp (To-Do List)

* [ ] Tối ưu hóa việc đọc cấu hình quái/boss từ `CfgMonster` để chia sẻ cache dùng chung cho toàn bộ hệ thống, tránh việc từng module gọi đọc độc lập gây quá tải tài nguyên.
* [ ] Thiết lập cơ chế mã hóa (Encryption) cơ bản cho tệp tin lưu tọa độ GPS dạng JSON nhằm chặn người dùng chỉnh sửa thủ công gây lỗi phân tích cú pháp (Syntax Parse Error).
* [ ] Tích hợp dịch vụ báo cáo lỗi tự động (Error Logger Webhook) trực tiếp vào `utilities.txt` để hỗ trợ đội ngũ phát triển phát hiện lỗi runtime nhanh chóng.
