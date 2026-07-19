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
├── 📄 key-system.txt               # Hệ thống xác thực Key (PlatoBoost), có cache key tự động
├── 📁 core/                        # Các dịch vụ cốt lõi (Nạp trước)
│   ├── 📄 utilities.txt            # Hàm helper dùng chung (Teleport, SmartScan, Format, HTTP,...)
│   ├── 📄 localization.txt         # Hệ thống đa ngôn ngữ (EN/VI) - nguồn dịch tập trung
│   ├── 📄 config_manager.txt       # Quản lý cấu hình tập trung (đọc/ghi JSON, migration)
│   ├── 📄 webhook.txt              # Quản lý gửi thông báo đến Discord Webhook
│   └── 📄 system_controller.txt    # Bộ não điều khiển toàn cục (Pause/Resume, Module Registry)
└── 📁 features/                    # Các module tính năng độc lập (Nạp động)
    ├── 📄 farm.txt                 # Tự động tấn công, bắt thú, hồi máu, lưu vị trí
    ├── 📄 boss_hunt.txt            # Săn Boss thế giới / Boss đặc biệt, quét RAM cấu hình
    ├── 📄 auto_dungeon.txt         # Tự động tạo, tham gia và rời phó bản
    ├── 📄 auto_rift.txt            # Logic tự động săn Rift
    ├── 📄 auto_event.txt           # Tự động tham gia sự kiện Q&A, chọn quà, nhặt items
    ├── 📄 hatch_egg.txt            # Tự động ấp trứng và lai dắt Pet
    ├── 📄 pet_manager.txt          # Quản lý Pet: Equip, Mount, Feed, Enhance, Fuse, Sell
    ├── 📄 server_manager.txt       # Quản lý Rejoin, Hop server săn thời tiết
    ├── 📄 shops_and_guis.txt       # Cửa sổ gọi nhanh các bảng giao diện (Bypass UI)
    ├── 📄 tracker.txt              # Định vị GPS trực tiếp, theo dõi người chơi
    ├── 📄 optimization.txt         # Giảm tải đồ họa, khóa 15 FPS, anti-AFK, tắt màn hình
    └── 📄 ai_assistant.txt         # Tích hợp trợ lý ảo AI (bị tắt mặc định)
```

---

## 3. Các thành phần cốt lõi (Core Components)

### 3.1. Main Script (`main.txt`)
* **Nhiệm vụ:** Là điểm khởi chạy duy nhất (Entry point) của hệ thống.
* **Luồng hoạt động:**
  1. Gửi request lấy thông tin Commit SHA mới nhất từ API GitHub nhằm **Bypass Cache (Fastly CDN)** hoàn toàn.
  2. Nạp thư viện **Rayfield UI Library**.
  3. Tạo đối tượng `ctx` (Context Object) với `ctx.Ready = false` làm tín hiệu đồng bộ.
  4. Sử dụng cơ chế nạp an toàn `SafeLoad` để tải lần lượt các file trong thư mục `core/`, sau đó tất cả các module trong `features/`.
  5. Gọi `Rayfield:LoadConfiguration()` để phục hồi trạng thái UI đã lưu.
  6. Đặt `ctx.Ready = true` — phát tín hiệu cho tất cả background loops bắt đầu chạy.

> [!IMPORTANT]
> **ctx.Ready Guard Pattern:** Mọi background loop (`task.spawn`) trong các feature module **bắt buộc** phải bắt đầu bằng `repeat task.wait(0.1) until ctx.Ready`. Điều này đảm bảo vòng lặp không đọc state `false` ban đầu trước khi `Rayfield:LoadConfiguration()` kịp phục hồi các toggle đã được người dùng lưu lại từ lần chơi trước.

### 3.2. Context Object (`ctx`)
Thay vì truyền tham số rời, mọi Feature Module đều nhận một `ctx` duy nhất qua Dependency Injection:
```lua
local ctx = {
    Window     = Window,          -- Rayfield Window (tạo Tab/Toggle/...)
    Utils      = Utils,           -- Hàm tiện ích dùng chung
    Controller = Controller,      -- System Controller (Pause/Resume)
    Webhook    = WebhookModule,   -- Gửi thông báo Discord
    Config     = ConfigManager,   -- Đọc/ghi cấu hình JSON tập trung
    Localization = Localization,  -- Bản dịch EN/VI
    Ready      = false,           -- Signal: false cho đến khi LoadConfiguration() hoàn tất
}
```

### 3.3. Config Manager (`config_manager.txt`)
* **Nhiệm vụ:** Quản lý toàn bộ cấu hình người dùng vào **một file JSON duy nhất** (`R_ClientPro_Config.json`), thay vì để mỗi module tự đọc ghi file riêng.
* **Tính năng Migration:** Tự động đọc và chuyển đổi dữ liệu từ các file JSON cũ (`R_ClientPro_FarmPos.json`, `R_ClientPro_MonsterFilter.json`, `RClient_HopBlacklist.json`) vào file config chính ở lần chạy đầu tiên.
* **API:** `Config.Get("Farm.Position")` / `Config.Set("Farm.Position", data)`

### 3.4. System Controller (`system_controller.txt`)
* **Nhiệm vụ:** Đóng vai trò là một Event Bus / State Manager trung tâm để điều phối trạng thái hoạt động của toàn bộ script.
* **Các tính năng chính:**
  * **Global Pause/Resume:** Quản lý cờ hiệu `Controller.IsPaused`. Khi kích hoạt dừng khẩn cấp, Controller sẽ phát tín hiệu yêu cầu tất cả module tạm dừng các vòng lặp xử lý logic.
  * **Module Registry:** Duy trì danh sách các module đang hoạt động trong bảng `Modules = {}` thông qua phương thức `registerModule()`.

---

## 4. Quy tắc cú pháp & Tương tác API game (Critical Rules)

> [!CAUTION]
> **Quy tắc cú pháp tối thượng (Dot Syntax Rule):**
> Toàn bộ các hệ thống API client của game (đóng gói trong `getrenv()._G.PathTool`) đều sử dụng cú pháp dấu **Chấm (`.`)** thay vì dấu Hai Chấm (`:`) truyền thống trong Lua.
>
> * Dùng đúng: `env.ViewManagerBase.OpenView("StoreView")`
> * Dùng sai: `env.ViewManagerBase:OpenView("StoreView")` (Sẽ gây lỗi dư tham số `self`)

* **Truy xuất dữ liệu mảng lưu trữ:** Game sử dụng kiểu dữ liệu **String** cho các khóa (Keys). Luôn ép kiểu sang String qua `tostring()`.
* **Hạ cấp phân quyền (Context Identity Mismatch):** Khi thực hiện các lệnh yêu cầu quyền Client Script (bắt đầu ấp trứng, gửi request nội bộ...), cần bọc lệnh trong `set_thread_id(2)` để tránh bị Anti-Cheat phát hiện.

---

## 5. Vòng đời của một Feature Module (Lifecycle)

Mỗi file trong thư mục `features/` được thiết kế dưới dạng một Anonymous Function nhận vào `ctx`:
```lua
return function(ctx)
    local Window     = ctx.Window
    local Utils      = ctx.Utils
    local Controller = ctx.Controller

    -- 1. Khởi tạo State cục bộ
    local settings = { autoRun = false }

    -- 2. Đăng ký nhận diện với System Controller (tùy chọn)
    if Controller and type(Controller.registerModule) == "function" then
        Controller:registerModule("MyFeature", function(paused)
            settings.autoRun = not paused
        end)
    end

    -- 3. Tạo Giao diện UI tương ứng trên Window
    local Tab = Window:CreateTab(Utils.t("my_tab"), "icon-name")
    Tab:CreateToggle({
        Name = "Auto Run",
        CurrentValue = false,
        Flag = "MyFeatureToggle",    -- Flag dùng cho Rayfield:LoadConfiguration()
        Callback = function(v) settings.autoRun = v end
    })

    -- 4. Tạo luồng xử lý độc lập
    --    BẮT BUỘC: chờ ctx.Ready trước khi bắt đầu để tránh đọc state ban đầu sai
    task.spawn(function()
        repeat task.wait(0.1) until ctx.Ready
        while task.wait(1) do
            if not settings.autoRun then continue end
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
2. Định dạng cấu trúc module theo dạng chuẩn `return function(ctx)`.
3. Tuyệt đối không sử dụng hàm `while wait()` trực tiếp trên Main Thread. Tất cả các tác vụ lặp lại tuần hoàn bắt buộc phải bọc trong `task.spawn()`.
4. **Thêm `repeat task.wait(0.1) until ctx.Ready`** là dòng đầu tiên của mọi `task.spawn` background loop để đảm bảo đọc state đúng sau khi Rayfield restore cấu hình.
5. Thêm tất cả chuỗi ngôn ngữ mới vào `core/localization.txt` trước — không hardcode chuỗi trực tiếp trong feature.
6. Đăng ký `SafeLoad` của module mới vào `main.txt`.
7. **Quản lý bộ nhớ:** Khi tạo các đối tượng tạm thời (Platform ảo, BillboardGui...), đảm bảo gọi `Destroy()` ngay sau khi tắt tính năng để ngăn Memory Leak.

### 6.2. Key System & Cache Key (`key-system.txt`)
* Key được xác thực qua **PlatoBoost API** với cơ chế nonce để tránh replay attack.
* Sau khi xác thực thành công, key được cache cục bộ vào file `laith_key_cache.txt` bằng `writefile`.
* Lần chạy tiếp theo, hệ thống tự động đọc key cache và xác thực lại. Nếu key còn hạn → bỏ qua bước nhập tay. Nếu key hết hạn → xóa cache và yêu cầu nhập mới.

### 6.3. Giao tiếp giữa các Module
Các module độc lập **không được phép tham chiếu chéo trực tiếp** lẫn nhau (Tight Coupling). Mọi nhu cầu chia sẻ dữ liệu hoặc gọi lệnh liên thông phải qua `Controller` hoặc thuộc tính dùng chung trên `_G`.

### 6.4. Xử lý lỗi ngoại lệ (Error Handling)
Dự án vận hành trên môi trường client của game, nơi dữ liệu mạng và cấu trúc đối tượng có thể thay đổi bất thường. Do đó, các hành động tương tác với tài nguyên Roblox (Dịch chuyển, Raycast, JSON Decode, HTTP Request) **bắt buộc phải bọc trong `pcall`** để tránh crash script.

---

## 7. Các vấn đề tồn đọng & Kế hoạch nâng cấp (To-Do List)

* [x] ~~Cập nhật Lifecycle pattern từ tham số rời sang `ctx` Dependency Injection~~
* [x] ~~Thêm `Config Manager` tập trung (migration từ JSON cũ sang file duy nhất)~~
* [x] ~~Thêm `ctx.Ready` guard để fix race condition state reset khi startup~~
* [x] ~~Thêm key cache tự động cho Key System~~
* [x] ~~Thêm module Pet Manager (Equip, Mount, Feed, Enhance, Fuse, Sell)~~
* [ ] Tối ưu hóa việc đọc cấu hình quái/boss từ `CfgMonster` để chia sẻ cache dùng chung cho toàn bộ hệ thống, tránh việc từng module gọi đọc độc lập gây quá tải tài nguyên.
* [ ] Thiết lập cơ chế mã hóa (Encryption) cơ bản cho tệp tin lưu tọa độ GPS dạng JSON nhằm chặn người dùng chỉnh sửa thủ công gây lỗi phân tích cú pháp.
* [ ] Tích hợp dịch vụ báo cáo lỗi tự động (Error Logger Webhook) trực tiếp vào `utilities.txt` để hỗ trợ đội ngũ phát triển phát hiện lỗi runtime nhanh chóng.
* [ ] Verify và điều chỉnh tên API thực tế cho các phương thức Pet Manager (`ClientFeed`, `ClientEnhance`, `ClientEvolve`, `ClientRecycle`) sau khi kiểm tra qua game environment.
