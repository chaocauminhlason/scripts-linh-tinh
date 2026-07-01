

---

```markdown
# 🏗️ Script Pro - System Architecture Documentation

## 1. Tổng quan dự án (Project Overview)
R-Game Pro là một dự án Roblox Automation Script được thiết kế theo kiến trúc **Modular & Centralized Control** (Mô-đun hóa và Điều khiển tập trung). 

Thay vì nhồi nhét mọi thứ vào một file khổng lồ, hệ thống được chia nhỏ thành các Core Services và Feature Modules. Điều này giúp dự án dễ dàng scale, dễ debug và cho phép nhiều Developer làm việc song song mà không bị conflict code.

---

## 2. Cấu trúc thư mục (Directory Structure)

```text
📁 R-Game-Pro/
├── 📄 main.txt                 # Entry point (Key System, Khởi tạo UI, Load Modules)
├── 📁 core/                    # Lõi hệ thống (Luôn load trước)
│   ├── 📄 utilities.txt        # Các hàm helper dùng chung (SafeLoad, Format, HTTP,...)
│   ├── 📄 webhook.txt          # Thông báo discord
│   └── 📄 system_controller.txt# Bộ não trung tâm (Quản lý hàng đợi, Pause/Resume toàn cục)
└── 📁 features/                # Các module tính năng độc lập
    ├── 📄 farm.txt             # Auto Attack, Catch, Heal, Return
    ├── 📄 tracker.txt          # GPS Live, Follow Player, Chat Command
    ├── 📄 boss_hunt.txt        # Logic săn Boss, quét RAM cấu hình
    ├── 📄 server_manager.txt   # rejoin if kick, hop server hunt weathers,
    ├── 📄 shop_and_guis.txt    # open UI game
    ├── 📄 auto_dungeon.txt     # auto creat, auto join, auto leave
    ├── 📄 auto_rift.txt        # Logic săn Rift
    ├── 📄 optimization         # 15fps, anti afk, black screen   
    └── 📄 hatch_egg.txt        # Tự động ấp trứng (Local Thread)

```

---

## 3. Các thành phần cốt lõi (Core Components)

### 3.1. Main Script (`main.txt`)

* **Nhiệm vụ:** Là điểm bắt đầu của script.
* **Luồng hoạt động:**
1. Kích hoạt **Key System** (Platoboost + Lootlabs).
2. Tải các file Core thông qua cơ chế `SafeLoad`.
3. Khởi tạo Giao diện (Rayfield UI).
4. Load các Module trong thư mục `features/` và truyền đối tượng `Window`, `Utils` vào cho chúng.



### 3.2. System Controller (`system_controller.txt`)

* **Nhiệm vụ:** Hoạt động như một "Tổng đài" (Event Bus / State Manager) để điều phối các module.
* **Các tính năng chính:**
* **Global Pause/Resume:** Biến `_G.SystemController.IsPaused`. Khi người dùng nhấn Emergency Stop hoặc phím `P`, Controller sẽ báo cho tất cả các module đang chạy tạm dừng luồng của chúng.
* **Module Registry:** Chứa bảng `Modules = {}`. Bất kỳ module tính năng nào muốn "nghe" lệnh từ hệ thống đều phải gọi `registerModule()`.
* **Task Queue (Hàng đợi):** Quản lý luồng ưu tiên (Ví dụ: Đang Farm thì có Boss xuất hiện -> Tạm ngưng Farm -> Đi đánh Boss -> Đánh xong quay lại Farm).



---

## 4. Vòng đời của một Feature Module (Lifecycle)

Mỗi file trong thư mục `features/` (ví dụ: `farm.txt`) được thiết kế dưới dạng một Anonymous Function trả về (Return).

**Cấu trúc chuẩn của một Module:**

1. **Khởi tạo State:** Khai báo các biến local (`camSettings`, `savedPos`,...).
2. **Đăng ký với Controller:**
```txt
if _G.SystemController then
    _G.SystemController:registerModule("ModuleName", function(paused)
        -- Logic xử lý khi nhận lệnh Pause/Resume từ hệ thống
    end)
end

```


3. **Dựng UI (Giao diện):** Tạo Tab, Section, Toggle, Slider tương ứng.
4. **Task Spawning (Luồng chạy):** Tạo các vòng lặp `task.spawn()` độc lập. Bên trong vòng lặp **bắt buộc** phải có check điều kiện: `if _G.SystemController.IsPaused then continue end`.

---

## 5. Hướng dẫn cho Developer mới (Dev Guide)

### 5.1. Quy tắc thêm tính năng mới

Nếu bạn muốn thêm một tính năng mới (ví dụ: `auto_quest.txt`):

1. **Tạo file mới** trong thư mục `features/`.
2. **Kế thừa form chuẩn:** Trả về một function nhận tham số `(Window, Utils)`.
3. **Tuyệt đối không** gọi `while wait()` trên Main Thread, mọi vòng lặp phải được bọc trong `task.spawn()`.
4. **Xử lý rác (Garbage Collection):** Nếu tạo các Part ảo (như Platform khi đứng trên không), phải có hàm `Destroy()` sau khi dùng xong để tránh memory leak.

### 5.2. Giao tiếp giữa các Module

Các module **không được** gọi trực tiếp lẫn nhau để tránh dính kết chéo (Tight Coupling). Nếu `Module A` cần `Module B` làm gì đó, hãy đưa trạng thái đó lên `_G.SystemController` hoặc sử dụng cơ chế đọc chung Attribute từ LocalPlayer.

### 5.3. Xử lý lỗi (Error Handling)

Dự án chạy trên môi trường Client của game, do đó mọi lệnh tương tác với API của Roblox (Teleport, Raycast, Get Attribute, Network Fire) **phải được bọc trong `pcall**`.

```txt
local success, result = pcall(function()
    return game:GetService("HttpService"):JSONDecode(data)
end)
if not success then warn("Lỗi parse JSON: " .. result) end

```

---

## 6. Known Issues & To-Do (Dành cho bản cập nhật tới)

* [ ] Tối ưu hóa việc đọc RAM của `CfgMonster` để share cache chung cho cả hệ thống thay vì mỗi module đọc một lần.
* [ ] Thêm mã hóa (Encryption) nhẹ cho file tọa độ GPS lưu dạng JSON để tránh user can thiệp thủ công gây lỗi parse.
* [ ] Tích hợp Discord Webhook Error Logger trực tiếp vào `utilities.txt`.

