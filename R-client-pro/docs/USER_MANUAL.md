# Hướng Dẫn Sử Dụng R-Client Pro Tool (Tài Liệu Chi Tiết Cho Người Dùng)



## 2. Các Hệ Thống Cốt Lõi

### 🧠 Điều Khiển Tổng & Nút Khẩn Cấp (Panic Button)
* **STOP ALL / RESUME ALL**: Hai nút điều hướng nhanh ở Tab đầu giúp bạn tạm dừng hoặc chạy lại toàn bộ các luồng hành vi (Farm, Săn Boss, Đi ải) ngay lập tức.
* **Nút bấm khẩn cấp (Phím P)**: Khi gặp tình huống khẩn cấp, bạn chỉ cần nhấn **phím P** trên bàn phím. Toàn bộ các vòng lặp và lệnh dịch chuyển sẽ bị ngắt ngay lập tức để bảo vệ nhân vật.

### 🌐 Hệ Thống Dịch Ngôn Ngữ Tự Động (Localization)
Hệ thống tự động phát hiện ngôn ngữ trên tài khoản Roblox của bạn để hiển thị giao diện phù hợp:
* **Tiếng Việt (vi)**: Tự động kích hoạt khi ngôn ngữ Roblox của bạn là Tiếng Việt.
* **Tiếng Anh (en)**: Mặc định cho mọi ngôn ngữ còn lại.

---

## 3. Hướng Dẫn Chi Tiết Chức Năng Từng Tab

### 🌾 Auto Farm (Tự Động Cày Quái)
* **Chọn Quái Mục Tiêu (Monster Filter)**: Bạn có thể chọn tiêu diệt một hoặc nhiều loại quái cụ thể. Bỏ chọn tất cả (hoặc chọn `Tất cả quái`) để diệt mọi quái vật trên bản đồ.
* **Quét Quái (Scan Monsters)**: Tự động quét toàn bộ loài quái đang có trên bản đồ hiện tại và điền vào danh sách để bạn lọc.
* **TP Farm (Tấn công dịch chuyển)**: Tự động dịch chuyển áp sát quái vật để diệt nhanh nhất. 
  > [!TIP]
  > **Bảo vệ chống rơi vực (Anti-Fall)**: Khi bật TP Farm, hệ thống sẽ tự động tạo một tấm nền vô hình (`FarmSafePlatform`) ngay dưới chân bạn mỗi lần dịch chuyển để tránh trường hợp bạn bị rơi tự do xuống hố sâu hoặc vách đá do lỗi tải bản đồ của game.
* **Smart Return (Quay lại bãi)**: Tự động ghi nhớ vị trí farm của bạn. Sau khi bạn chết hoặc đi hồi máu, nhân vật sẽ tự động bay ngược về bãi để tiếp tục farm.

---

### 🦖 Boss Hunt (Săn Boss Thế Giới & Boss Đặc Biệt)
Hệ thống săn boss sở hữu cơ chế điều phối thông minh tránh xung đột:
* **Auto Special Boss**: Tự động lắng nghe tín hiệu từ game, đổi đảo và tiêu diệt Special Boss (Ignisraptor, Undine, v.v.).
* **Auto World Boss**: Tự động chuyển đảo xoay vòng theo danh sách bạn chọn để săn World Boss khi có Sóng xuất hiện.
* **Ưu tiên Special Boss (Nhường cờ chống giật)**:
  * Khi cả hai sự kiện Boss cùng diễn ra trên một đảo, luồng World Boss sẽ tự động **nhường quyền điều khiển** cho Special Boss.
  * Nhân vật sẽ tiêu diệt xong Special Boss rồi mới quay lại diệt World Boss. Tuyệt đối không có hiện tượng nhân vật bị giật qua lại giữa 2 boss.
  * Hệ thống được trang bị khoảng trễ **0.5 giây** sau khi dịch chuyển đến Boss để đảm bảo nhân vật đáp đất an toàn trước khi xả chiêu.

---

### 🏰 Auto Dungeon (Tự Động Đi Hầm Ngục)
* **Trong Phụ Bản**: Tự động đánh quái và diệt Boss.
  * *Auto Exit Stage 20*: Tự động rời hầm ngục ngay khi hoàn thành màn 20 để tối ưu hóa thời gian farm chìa khóa (Dungeon Key).
* **Ngoài Sảnh Chờ (Lobby)**:
  * *Auto Join*: Tự động tìm và tham gia các phòng chờ đang có sẵn người chơi khác để ké ải.
  * *Auto Create*: Tự động tạo phòng mới với độ khó tùy chọn (Normal, Hard, Nightmare, Inferno) và tự khởi động khi phòng đủ số người yêu cầu.

---

### 🥚 Auto Hatch & Pet Breeding (Ấp Trứng & Lai Dắt)
* **Tự Động Nhận Biết Ô Ấp (Smart Slots)**: Bạn không cần phải kéo thanh cấu hình số lượng máy ấp như trước. Tool sẽ tự động quét trạng thái mở khóa của các ô ấp (từ 1 đến 10) trong game của bạn và tự động nạp trứng vào các ô trống đã mở khóa.
* **Nhận Trứng Lai Dắt Tự Động**: Tự động quét 5 khe lai dắt trong máy lai thú và thực hiện nhận Pet con ngay khi quá trình lai dắt (4 giờ) kết thúc.
* **Chọn Cặp Bố Mẹ Lai Dắt Chi Tiết (Detailed Breeding)**:
  * Danh sách chọn Pet Bố và Pet Mẹ hiển thị đầy đủ thông tin: **Tên loài, Phẩm chất (Grade S, SS...), Dị biến (Shiny, Huge, Bloodlit, Corrupted, Fairy...) và Mã Số ID duy nhất của Pet đó**.
  * **Khóa cứng theo ID**: Khi chọn một thú cụ thể, tool sẽ dùng đúng mã ID của thú đó để lai dắt.
  * **Chế độ Any (Bất kỳ)**: Nếu chọn `Any`, tool sẽ tự động tìm và dùng con có phẩm chất (Grade) cao nhất thuộc giới tính đó trong túi đồ của bạn để lai dắt.

---

### 🌌 Auto Rift (Săn Cổng Rift)
* **Lọc Màu Cổng Rift (Rift Color Filter)**: Bạn có thể chọn cụ thể các màu sắc cổng muốn vào (ví dụ: chỉ săn cổng Đỏ và Tím). Hệ thống sẽ tự động quét và bỏ qua các cổng có màu sắc không nằm trong danh sách lựa chọn của bạn để tiết kiệm thời gian.


---

### 🎨 Optimization (Tối Ưu Hóa & Giảm Tải RAM)
* **Potato Mode & Disable 3D Rendering**: Giảm đồ họa xuống mức cực thấp hoặc tắt hoàn toàn dựng hình 3D (màn hình đen) để giảm đến 90% tải hoạt động cho GPU, giúp treo nhiều acc mượt mà.
* **Dọn Dẹp Bộ Nhớ & Logs (Memory & Log Cleaner)**:
  * **Auto GC (Dọn rác tự động)**: Quét ngầm mỗi 60 giây để dọn dẹp bộ nhớ Lua Heap và dọn cache logs của game giúp giảm lag.
  * **Nút bấm Clear Memory & Logs Now**: Bấm để lập tức chạy dọn rác bộ nhớ sâu, xóa sạch developer console (F9) của Roblox và console của phần mềm hack. Sau khi dọn dẹp sẽ hiện thông báo chính xác số dung lượng MB RAM đã được giải phóng.

---

### 🕶️ Chế Độ Streamer (Streamer Mode - Bảo Mật Tuyệt Đối)
Khi kích hoạt chế độ ẩn danh:
1. **Đổi tên nhân vật**: Tên trên đầu nhân vật của bạn sẽ được đổi thành tên giả do bạn cấu hình trong ô nhập liệu.
2. **Chặn thông báo hệ thống**: Tự động can thiệp vào các bảng thông báo hệ thống của Roblox (như thông báo Boss xuất hiện) để lọc bỏ và che giấu tên thật của bạn.
3. **Quét sạch văn bản trên màn hình (UI Sweeper)**: Quét liên tục mỗi 0.5 giây toàn bộ giao diện màn hình (Bảng chat, Leaderboard, Level bar, UI sự kiện...). Bất kỳ từ khóa nào trùng với tên thật hoặc DisplayName của bạn sẽ lập tức bị đè và thay thế bằng tên giả, đảm bảo không bị lộ thông tin khi quay màn hình hoặc phát trực tiếp.

---

## 4. Giải Thích Tính Năng Auto Event (Săn Sự Kiện)
Đây là tính năng thông minh tự động hóa toàn bộ chuỗi sự kiện đặc biệt trong game:
* **Hộp Quà Rơi Tự Do & Trứng Sự Kiện**: Tự động dịch chuyển đến các vật phẩm sự kiện rơi trên bản đồ (như rương Noel, trứng admin...) và gửi lệnh nhận thưởng.
* **Tự Động Đố Vui (Q&A Event)**: Tool tự động giải mã câu hỏi trong dữ liệu game (`CfgQA`), phát hiện bục có đáp án chính xác và di chuyển nhân vật đến đó đứng đợi cho đến khi hết thời gian đếm ngược để nhận thưởng.
* **Tự Chọn Quà Cực Phẩm (Chọn hình đúng / Gift Selection)**:
  * Khi sự kiện chọn bục quà diễn ra, tool sử dụng **Thuật toán chấm điểm ưu tiên** dựa trên giá trị phần thưởng của từng bục:
    $$\text{Trứng (Egg)} > \text{Rương (Chest)} > \text{Vật phẩm EXP} > \text{Kim cương} > \text{Vàng}$$
  * Nhân vật sẽ tự động dịch chuyển đến bục có phần quà giá trị cao nhất.
  * Nếu phần quà hai bên giá trị bằng nhau, tool sẽ tự động chuyển sang chế độ **Follow Crowd** (Đứng theo số đông người chơi) để đảm bảo tỉ lệ chiến thắng cao nhất.
