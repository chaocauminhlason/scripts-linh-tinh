-- ====================================================================
-- ROBLOX PRO TOOL - BẢN HOÀN CHỈNH TỐI ƯU HÓA (ĐƯỜNG DẪN TUYỆT ĐỐI)
-- ====================================================================

-- [[ TẢI THƯ VIỆN UI ]]
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Roblox Pro Tool - Final Version",
   LoadingTitle = "Đang tải tính năng...",
   LoadingStatus = "Vui lòng đợi",
   ConfigurationSaving = { Enabled = true, FolderName = "ProToolConfig", FileName = "MainConfig" },
   KeySystem = false
})

-- [[ BIẾN TOÀN CỤC ]]
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local following, targetPlayer, missingTime = false, nil, 0
local antiAfkEnabled, rejoinTimer = false, 0
local autoExitEnabled, autoExitTriggered, stage20ClockStarted = false, false, false

-- ====================================================================
-- [[ HỆ THỐNG CLICK & TÌM KIẾM ĐƯỜNG DẪN TUYỆT ĐỐI (CORE) ]]
-- ====================================================================

-- Hàm tìm Khung Cha hiển thị (Dùng cho nút BgLeave vì nó đã hoạt động ổn)
local function findUIElementByName(parent, name)
    if not parent then return nil end
    for _, child in ipairs(parent:GetDescendants()) do
        if child.Name == name then return child end
    end
    return nil
end

-- Hàm Click Chính Xác Tâm Điểm Của Nút
local function ClickButtonExact(button, debugName)
    if not button then return end
    
    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    
    local centerX = absPos.X + (absSize.X / 2)
    local centerY = absPos.Y + (absSize.Y / 2)
    
    -- Xử lý bù trừ thanh Topbar của Roblox
    local screenGui = button:FindFirstAncestorOfClass("ScreenGui")
    local finalY = centerY
    if screenGui and not screenGui.IgnoreGuiInset then
        finalY = finalY + GuiService:GetGuiInset().Y
    end

    print(string.format("🎯 [AUTO-CLICK] Mục tiêu: '%s' | Tọa độ chuẩn: X=%d, Y=%d", debugName, math.floor(centerX), math.floor(finalY)))

    VirtualInputManager:SendMouseButtonEvent(centerX, finalY, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(centerX, finalY, 0, false, game, 1)
end

-- Quy trình tự động Thoát & Nghiệm thu
local function SafeExitRoutine()
    print("🚀 Auto-Exit: Khởi động quy trình vượt ngục bằng Absolute Path...")
    
    -- BƯỚC 1: Tìm và Click nút Thoát (BgLeave)
    local exitBtn = findUIElementByName(playerGui, "BgLeave")
    if exitBtn and exitBtn.AbsoluteSize.X > 0 then
        ClickButtonExact(exitBtn, "Nút Thoát (BgLeave)")
    else
        print("❌ Lỗi: Không thấy nút BgLeave!")
        autoExitTriggered = false
        return
    end

    -- Chờ 1.5 giây để bảng xác nhận mở hẳn
    print("⏳ Đang chờ bảng ConfirmView mở lên...")
    task.wait(1.5) 

    -- BƯỚC 2: Đi thẳng vào ĐƯỜNG DẪN TUYỆT ĐỐI của bảng Yes/No
    local mainGui = playerGui:FindFirstChild("MainGui")
    if mainGui then
        local screenGui = mainGui:FindFirstChild("ScreenGui")
        if screenGui then
            local confirmView = screenGui:FindFirstChild("ConfirmView")
            
            if confirmView and confirmView.Visible then
                local fmBottom = confirmView:FindFirstChild("FmBottom")
                if fmBottom then
                    -- Lấy đúng nút Yes (BtOk) thay vì BtCancel như lúc test
                    local btOk = fmBottom:FindFirstChild("BtOk")
                    
                    if btOk and btOk.AbsoluteSize.X > 0 then
                        print("🔥 Bắt được mục tiêu BtOk! Đang tiến hành nhấp chuột...")
                        for i = 1, 3 do
                            ClickButtonExact(btOk, "Nút Yes (BtOk)")
                            task.wait(0.2)
                        end
                    else
                        print("❌ Lỗi: Không tìm thấy nút BtOk bên trong FmBottom!")
                        autoExitTriggered = false
                        return
                    end
                end
            else
                print("❌ Lỗi: Bảng ConfirmView không tồn tại hoặc bị ẩn!")
                autoExitTriggered = false
                return
            end
        end
    end

    -- BƯỚC 3: KIỂM TRA CHÉO KẾT QUẢ THỰC TẾ
    print("⏳ Đang chờ hệ thống chuyển map và nghiệm thu kết quả...")
    task.wait(2.5) 
    
    local checkLabStage = findUIElementByName(playerGui, "LabStage")
    local currentStageText = checkLabStage and checkLabStage.Text or "Unknown"
    
    if currentStageText == "Unknown" or not string.match(currentStageText, "20/20") then
        print("==================================================")
        print("🎉 CHUẨN XÁC 100%! ĐÃ THOÁT THÀNH CÔNG VỚI ĐƯỜNG DẪN GỐC.")
        print("👉 Trạng thái màn chơi hiện tại: " .. currentStageText)
        print("==================================================")
        
        -- Tự động reset cờ hiệu, sẵn sàng cho trận farm tiếp theo
        autoExitTriggered = false
        stage20ClockStarted = false
    else
        print("⚠️ CẢNH BÁO: Vẫn kẹt ở màn 20. Sẽ tự động thử lại nhịp sau!")
        autoExitTriggered = false
    end
end


-- ==========================================
-- [[ TAB GIAO DIỆN & TÍNH NĂNG ]]
-- ==========================================

-- TAB 1: THEO DÕI
local MainTab = Window:CreateTab("Theo Dõi", 4483362458)
local StatusLabel = MainTab:CreateLabel("Trạng thái: Đang nghỉ")

local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return names
end

local PlayerDropdown = MainTab:CreateDropdown({
   Name = "Chọn người đi theo", Options = GetPlayerNames(), CurrentOption = "", MultipleOptions = false, Flag = "PlayerDropdown",
   Callback = function(Option)
      targetPlayer = Players:FindFirstChild(Option[1])
      if targetPlayer then following = true StatusLabel:Set("Trạng thái: Đang theo dõi " .. targetPlayer.Name) end
   end,
})

MainTab:CreateButton({ Name = "Làm mới danh sách", Callback = function() PlayerDropdown:Refresh(GetPlayerNames()) end })
MainTab:CreateToggle({ Name = "Bật/Tắt Theo Dõi", CurrentValue = false, Flag = "FollowToggle", Callback = function(Value) following = Value if not Value then StatusLabel:Set("Trạng thái: Đã dừng") end end })
MainTab:CreateSection("Chat '!f' để kích hoạt follow từ xa.")


-- TAB 2: AUTO EXIT HẦM NGỤC
local DungeonTab = Window:CreateTab("Hầm Ngục", 4483362458)
local DungeonStatus = DungeonTab:CreateLabel("Trạng thái Auto Exit: Đang tắt")

DungeonTab:CreateToggle({
    Name = "Tự Động Thoát Khi Xong Màn 20", CurrentValue = false, Flag = "AutoExitDungeon",
    Callback = function(Value)
        autoExitEnabled = Value
        if Value then DungeonStatus:Set("Trạng thái Auto Exit: ĐANG BẬT VÀ QUÉT...")
        else DungeonStatus:Set("Trạng thái Auto Exit: Đang tắt") autoExitTriggered, stage20ClockStarted = false, false end
    end
})


-- TAB 3: TIỆN ÍCH
local UtilityTab = Window:CreateTab("Tiện Ích", 4483345998)
UtilityTab:CreateToggle({
   Name = "Chống AFK (Anti-Kick)", CurrentValue = false, Flag = "AntiAfk",
   Callback = function(Value) antiAfkEnabled = Value if Value then Rayfield:Notify({Title = "Anti-AFK", Content = "Đã kích hoạt", Duration = 3}) end end,
})


-- TAB 4: QUẢN LÝ SERVER
local ServerTab = Window:CreateTab("Server", 4483362458)
ServerTab:CreateButton({ Name = "Rejoin Server", Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end })
ServerTab:CreateButton({ Name = "Rejoin Same Server", Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end })
ServerTab:CreateButton({
   Name = "Tìm Server Ít Người (Hop)",
   Callback = function()
      local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
      local data = HttpService:JSONDecode(game:HttpGet(url))
      if data and data.data then
          for _, server in ipairs(data.data) do
              if server.playing < server.maxPlayers and server.id ~= game.JobId then
                  TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer) break
              end
          end
      end
   end,
})
ServerTab:CreateInput({
   Name = "Set Rejoin Time (phút)", PlaceholderText = "Nhập số phút...", RemoveTextAfterFocusLost = false,
   Callback = function(Text)
      rejoinTimer = tonumber(Text)
      if rejoinTimer then task.delay(rejoinTimer * 60, function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end) end
   end,
})


-- ==========================================
-- [[ LOGIC CHẠY NGẦM THỜI GIAN THỰC ]]
-- ==========================================

-- Lắng nghe Chat Follow
local function SetupChat(p)
    p.Chatted:Connect(function(msg)
        if msg == "!f" then targetPlayer = p following = true StatusLabel:Set("Trạng thái: Đang theo dõi " .. p.Name) end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then SetupChat(p) end end
Players.PlayerAdded:Connect(SetupChat)

-- Vòng lặp chính xử lý tính năng
local mainCoroutine = coroutine.create(function()
    while task.wait(0.5) do
        
        -- Logic Follow
        if following and targetPlayer then
            pcall(function()
                local char, tChar = LocalPlayer.Character, targetPlayer.Character
                if char and tChar and tChar:FindFirstChild("HumanoidRootPart") then
                    missingTime = 0 char.Humanoid:MoveTo(tChar.HumanoidRootPart.Position)
                else
                    if missingTime == 0 then missingTime = os.time() end
                    if os.time() - missingTime >= 30 and tChar and tChar:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.CFrame = tChar.HumanoidRootPart.CFrame missingTime = 0
                    end
                end
            end)
        end

        -- Logic Auto-Exit Hầm Ngục
        if autoExitEnabled and not autoExitTriggered then
            local labStage = findUIElementByName(playerGui, "LabStage")
            local fmTimeFrame = nil
            pcall(function() fmTimeFrame = playerGui.MainGui.ScreenGui.ArenaMainRightTopView.FmTime end)

            if labStage then
                local currentStage, maxStage = string.match(labStage.Text, "(%d+)/(%d+)")
                
                -- Nếu đang ở màn 20
                if currentStage and maxStage and tonumber(currentStage) == tonumber(maxStage) then
                    
                    if fmTimeFrame and fmTimeFrame.Visible == true then
                        if not stage20ClockStarted then 
                            stage20ClockStarted = true 
                            DungeonStatus:Set("Trạng thái Auto Exit: Đồng hồ màn 20 đã chạy...") 
                        end
                    end
                    
                    if stage20ClockStarted then
                        if not fmTimeFrame or fmTimeFrame.Visible == false then
                            autoExitTriggered = true 
                            DungeonStatus:Set("Trạng thái Auto Exit: Boss đã gục, chuẩn bị click thoát...")
                            task.spawn(SafeExitRoutine)
                        end
                    end
                    
                -- Nếu chưa tới màn 20 (hoặc vòng lặp farm mới)
                else
                    if stage20ClockStarted then stage20ClockStarted = false end
                    if autoExitTriggered then autoExitTriggered = false end
                end
            end
        end
    end
end)
coroutine.resume(mainCoroutine)

-- Logic Anti-AFK
LocalPlayer.Idled:Connect(function()
    if antiAfkEnabled then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end
end)

Rayfield:Notify({Title = "Thành Công!", Content = "Bản Tool chuẩn Absolute Path đã sẵn sàng!", Duration = 5})