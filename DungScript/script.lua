-- ====================================================================
-- R PRO TOOL - BẢN HOÀN CHỈNH TỐI ƯU HÓA (ĐƯỜNG DẪN TUYỆT ĐỐI)
-- Tích hợp Auto Attack, Auto Join Room & Optimization
-- ====================================================================

-- [[ TẢI THƯ VIỆN UI ]]
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Roblox Pro Tool - Dev by sondeptrai",
    LoadingTitle = "Đang tải tính năng...",
    LoadingStatus = "Vui lòng đợi",
    ConfigurationSaving = { Enabled = true, FolderName = "ProToolConfig", FileName = "MainConfig" },
    KeySystem = false
})

-- [[ BIẾN TOÀN CỤC & SERVICES ]]
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local myUserId = LocalPlayer.UserId
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

local following, targetPlayer, missingTime = false, nil, 0
local antiAfkEnabled, rejoinTimer = false, 0
local autoExitEnabled, autoExitTriggered, stage20ClockStarted = false, false, false
local autoAttackEnabled = false
local autoJoinOthersEnabled = false
local originalFPS = 60

-- ====================================================================
-- [[ HỆ THỐNG CLICK & TÌM KIẾM ĐƯỜNG DẪN TUYỆT ĐỐI (CORE) ]]
-- ====================================================================

local function findUIElementByName(parent, name)
    if not parent then return nil end
    for _, child in ipairs(parent:GetDescendants()) do
        if child.Name == name then return child end
    end
    return nil
end

local function ClickButtonExact(button, debugName)
    if not button then return end

    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize

    local centerX = absPos.X + (absSize.X / 2)
    local centerY = absPos.Y + (absSize.Y / 2)

    local screenGui = button:FindFirstAncestorOfClass("ScreenGui")
    local finalY = centerY
    if screenGui and not screenGui.IgnoreGuiInset then
        finalY = finalY + GuiService:GetGuiInset().Y
    end

    VirtualInputManager:SendMouseButtonEvent(centerX, finalY, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(centerX, finalY, 0, false, game, 1)
end

local function SafeExitRoutine()
    local exitBtn = findUIElementByName(playerGui, "BgLeave")
    if exitBtn and exitBtn.AbsoluteSize.X > 0 then
        ClickButtonExact(exitBtn, "Nút Thoát (BgLeave)")
    else
        autoExitTriggered = false
        return
    end

    task.wait(1.5)

    local mainGui = playerGui:FindFirstChild("MainGui")
    if mainGui then
        local screenGui = mainGui:FindFirstChild("ScreenGui")
        if screenGui then
            local confirmView = screenGui:FindFirstChild("ConfirmView")
            if confirmView and confirmView.Visible then
                local fmBottom = confirmView:FindFirstChild("FmBottom")
                if fmBottom then
                    local btOk = fmBottom:FindFirstChild("BtOk")
                    if btOk and btOk.AbsoluteSize.X > 0 then
                        for i = 1, 3 do
                            ClickButtonExact(btOk, "Nút Yes (BtOk)")
                            task.wait(0.2)
                        end
                    else
                        autoExitTriggered = false
                        return
                    end
                end
            else
                autoExitTriggered = false
                return
            end
        end
    end

    task.wait(2.5)

    local checkLabStage = findUIElementByName(playerGui, "LabStage")
    local currentStageText = checkLabStage and checkLabStage.Text or "Unknown"

    if currentStageText == "Unknown" or not string.match(currentStageText, "20/20") then
        autoExitTriggered = false
        stage20ClockStarted = false
    else
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
    Name = "Chọn người đi theo",
    Options = GetPlayerNames(),
    CurrentOption = "",
    MultipleOptions = false,
    Flag = "PlayerDropdown",
    Callback = function(Option)
        targetPlayer = Players:FindFirstChild(Option[1])
        if targetPlayer then
            following = true
            StatusLabel:Set("Trạng thái: Đang theo dõi " .. targetPlayer.Name)
        end
    end,
})

MainTab:CreateButton({ Name = "Làm mới danh sách", Callback = function() PlayerDropdown:Refresh(GetPlayerNames()) end })
MainTab:CreateToggle({ Name = "Bật/Tắt Theo Dõi", CurrentValue = false, Flag = "FollowToggle", Callback = function(Value)
    following = Value
    if not Value then StatusLabel:Set("Trạng thái: Đã dừng") end
end })
MainTab:CreateSection("Chat '!f' để kích hoạt follow từ xa.")


-- TAB 2: AUTO EXIT HẦM NGỤC
local DungeonTab = Window:CreateTab("Hầm Ngục", 4483362458)
local DungeonStatus = DungeonTab:CreateLabel("Trạng thái Auto Exit: Đang tắt")

DungeonTab:CreateToggle({
    Name = "Tự Động Thoát Khi Xong Màn 20",
    CurrentValue = false,
    Flag = "AutoExitDungeon",
    Callback = function(Value)
        autoExitEnabled = Value
        if Value then
            DungeonStatus:Set("Trạng thái Auto Exit: ĐANG BẬT VÀ QUÉT...")
        else
            DungeonStatus:Set("Trạng thái Auto Exit: Đang tắt")
            autoExitTriggered, stage20ClockStarted = false, false
        end
    end
})

DungeonTab:CreateToggle({
    Name = "Luôn Bật Tự Động Đánh (Auto Attack)",
    CurrentValue = false,
    Flag = "AutoAttack",
    Callback = function(Value)
        autoAttackEnabled = Value
    end
})

DungeonTab:CreateToggle({
    Name = "Tự Động Nhảy Vào Phòng Người Khác",
    CurrentValue = false,
    Flag = "AutoJoinOthers",
    Callback = function(Value)
        autoJoinOthersEnabled = Value
    end
})


-- TAB 3: TIỆN ÍCH
local UtilityTab = Window:CreateTab("Tiện Ích", 4483345998)
UtilityTab:CreateToggle({
    Name = "Chống AFK (Anti-Kick)",
    CurrentValue = false,
    Flag = "AntiAfk",
    Callback = function(Value)
        antiAfkEnabled = Value
        if Value then Rayfield:Notify({ Title = "Anti-AFK", Content = "Đã kích hoạt", Duration = 3 }) end
    end,
})


-- TAB 4: TỐI ƯU HÓA (GIẢM TẢI CPU/GPU)
local OptimizationTab = Window:CreateTab("Tối Ưu", 4483345998)
OptimizationTab:CreateSection("Cảnh báo: Đồ họa sẽ cực kỳ xấu khi bật.")

OptimizationTab:CreateButton({
    Name = "Kích hoạt Đồ Họa Siêu Thấp (Potato Mode)",
    Callback = function()
        print("Đang xóa tài nguyên đồ họa...")

        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.ShadowSoftness = 0
        if Lighting:FindFirstChildOfClass("Atmosphere") then Lighting:FindFirstChildOfClass("Atmosphere"):Destroy() end
        if Lighting:FindFirstChildOfClass("DepthOfFieldEffect") then Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
                :Destroy() end

        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and not v:IsA("MeshPart") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") or v:IsA("Trail") then
                v:Destroy()
            end
        end

        Workspace.Terrain.WaterWaveSize = 0
        Workspace.Terrain.WaterWaveSpeed = 0
        Workspace.Terrain.WaterReflectance = 0
        Workspace.Terrain.WaterTransparency = 1

        Rayfield:Notify({ Title = "Tối ưu hóa", Content = "Đã chuyển về Potato Mode. CPU nhẹ đi đáng kể!", Duration = 3 })
    end,
})

OptimizationTab:CreateToggle({
    Name = "Giới Hạn 15 FPS (Giảm nóng máy)",
    CurrentValue = false,
    Flag = "FpsLimiter",
    Callback = function(Value)
        if Value then
            if setfpscap then
                setfpscap(15)
                print("Đã ép FPS xuống 15")
            else
                Rayfield:Notify({ Title = "Lỗi", Content = "Executor của bạn không hỗ trợ setfpscap", Duration = 3 })
            end
        else
            if setfpscap then
                setfpscap(originalFPS)
                print("Đã trả FPS về mặc định")
            end
        end
    end,
})

OptimizationTab:CreateToggle({
    Name = "Tắt Render 3D (Màn hình đen)",
    CurrentValue = false,
    Flag = "Disable3D",
    Callback = function(Value)
        pcall(function() RunService:Set3dRenderingEnabled(not Value) end)
        if Value then
            Rayfield:Notify({ Title = "Tối ưu", Content = "Đã tắt Render 3D. Chỉ hiển thị UI.", Duration = 3 })
        else
            Rayfield:Notify({ Title = "Tối ưu", Content = "Đã bật lại Render 3D.", Duration = 3 })
        end
    end,
})


-- TAB 5: QUẢN LÝ SERVER
local ServerTab = Window:CreateTab("Server", 4483362458)
ServerTab:CreateButton({ Name = "Rejoin Server", Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end })
ServerTab:CreateButton({ Name = "Rejoin Same Server", Callback = function() TeleportService:TeleportToPlaceInstance(
    game.PlaceId, game.JobId, LocalPlayer) end })
ServerTab:CreateButton({
    Name = "Tìm Server Ít Người (Hop)",
    Callback = function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local data = HttpService:JSONDecode(game:HttpGet(url))
        if data and data.data then
            for _, server in ipairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    break
                end
            end
        end
    end,
})
ServerTab:CreateInput({
    Name = "Set Rejoin Time (phút)",
    PlaceholderText = "Nhập số phút...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        rejoinTimer = tonumber(Text)
        if rejoinTimer then task.delay(rejoinTimer * 60,
                function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end) end
    end,
})


-- ==========================================
-- [[ LOGIC CHẠY NGẦM THỜI GIAN THỰC ]]
-- ==========================================

local function SetupChat(p)
    p.Chatted:Connect(function(msg)
        if msg == "!f" then
            targetPlayer = p
            following = true
            StatusLabel:Set("Trạng thái: Đang theo dõi " .. p.Name)
        end
    end)
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then SetupChat(p) end end
Players.PlayerAdded:Connect(SetupChat)

local mainCoroutine = coroutine.create(function()
    while task.wait(0.5) do
        -- 1. Logic Follow
        if following and targetPlayer then
            pcall(function()
                local char, tChar = LocalPlayer.Character, targetPlayer.Character
                if char and tChar and tChar:FindFirstChild("HumanoidRootPart") then
                    missingTime = 0
                    char.Humanoid:MoveTo(tChar.HumanoidRootPart.Position)
                else
                    if missingTime == 0 then missingTime = os.time() end
                    if os.time() - missingTime >= 30 and tChar and tChar:FindFirstChild("HumanoidRootPart") then
                        char.HumanoidRootPart.CFrame = tChar.HumanoidRootPart.CFrame
                        missingTime = 0
                    end
                end
            end)
        end

        -- 2. Logic Auto Attack
        if autoAttackEnabled then
            pcall(function()
                local mainGui = playerGui:FindFirstChild("MainGui")
                if mainGui then
                    local screenGui = mainGui:FindFirstChild("ScreenGui")
                    if screenGui then
                        local mainBottomView = screenGui:FindFirstChild("MainBottomView")
                        if mainBottomView then
                            local fmAutoAttack = mainBottomView:FindFirstChild("FmAutoAttack")
                            if fmAutoAttack then
                                local btAutoOn = fmAutoAttack:FindFirstChild("BtAutoOn")
                                if btAutoOn and btAutoOn.Visible and btAutoOn.AbsoluteSize.X > 0 then
                                    ClickButtonExact(btAutoOn, "Nút Bật Đánh (BtAutoOn)")
                                end
                            end
                        end
                    end
                end
            end)
        end

-- 3. Logic Auto Join Phòng Người Khác
        local labStage = findUIElementByName(playerGui, "LabStage")
        local isInDungeon = labStage and labStage.Text ~= "Unknown"

        if autoJoinOthersEnabled and not isInDungeon then
            pcall(function()
                local wArea = workspace:FindFirstChild("Area")
                local center = wArea and wArea:FindFirstChild("center")
                local innerArea = center and center:FindFirstChild("Area")
                local abyssFolder = innerArea and innerArea:FindFirstChild("Abyss")

                if abyssFolder then
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local humanoid = char and char:FindFirstChild("Humanoid")
                    
                    -- Chỉ xử lý khi nhân vật thực sự còn sống
                    if hrp and humanoid and humanoid.Health > 0 then
                        
                        local alreadyInSomeoneRoom = false
                        local shouldJumpOut = false
                        local jumpOutTarget = nil
                        local roomToJoin = nil

                        -- DUYỆT QUA TẤT CẢ CÁC PHÒNG ĐỂ THU THẬP DỮ LIỆU
                        for _, room in ipairs(abyssFolder:GetChildren()) do
                            if string.match(room.Name, "Abyss_") then
                                local surfaceGui = room:FindFirstChild("Platform") and room.Platform:FindFirstChild("Board") and room.Platform.Board:FindFirstChild("SurfaceGui")
                                
                                if surfaceGui then
                                    local fmEmpty, fmPrepare = surfaceGui:FindFirstChild("FmEmpty"), surfaceGui:FindFirstChild("FmPrepare")
                                    local fmInfo, fmPlayer = surfaceGui:FindFirstChild("FmInfo"), surfaceGui:FindFirstChild("FmPlayer")

                                    if fmEmpty and fmPrepare and fmInfo and fmPlayer then
                                        if (not fmEmpty.Visible) and (not fmPrepare.Visible) and fmInfo.Visible and fmPlayer.Visible then
                                            
                                            local isOtherPlayer = false
                                            local isMyRoom = false
                                            
                                            -- Đọc UserId
                                            for _, desc in ipairs(fmPlayer:GetDescendants()) do
                                                if desc:IsA("ImageLabel") and string.find(desc.Image, "AvatarHeadShot") then
                                                    local extractedId = string.match(desc.Image, "id=(%d+)")
                                                    if extractedId then
                                                        if tonumber(extractedId) ~= myUserId then isOtherPlayer = true
                                                        else isMyRoom = true end
                                                        break 
                                                    end
                                                end
                                            end

                                            local targetPos = (room:IsA("Model") and room:GetPivot().Position) or (room:IsA("BasePart") and room.Position)

                                            if targetPos then
                                                local dist = (hrp.Position - targetPos).Magnitude
                                                
                                                -- Nếu phòng đổi chủ thành của mình và đang đứng trên bục
                                                if isMyRoom and dist < 25 then
                                                    shouldJumpOut = true
                                                    -- TÌM VÀ LẤY TỌA ĐỘ LEAVEATH
                                                    local leaveAth = room:FindFirstChild("LeaveAth")
                                                    if leaveAth and leaveAth:IsA("Attachment") then
                                                        jumpOutTarget = leaveAth.WorldPosition
                                                    end
                                                    
                                                elseif isOtherPlayer then
                                                    if dist < 15 then
                                                        alreadyInSomeoneRoom = true
                                                    elseif not roomToJoin then
                                                        roomToJoin = targetPos + Vector3.new(0, 5, 0)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        -- RA QUYẾT ĐỊNH DỰA TRÊN DỮ LIỆU ĐÃ TỔNG HỢP
                        if shouldJumpOut then
                            print("⚠️ Bị ép thành chủ phòng! Đang bay ra điểm an toàn...")
                            if jumpOutTarget then
                                -- Nhảy vào LeaveAth (Cộng thêm 3 stud trục Y để không lún đất)
                                hrp.CFrame = CFrame.new(jumpOutTarget + Vector3.new(0, 3, 0))
                            else
                                -- Fallback: Nếu mạng lag chưa load kịp LeaveAth thì lùi tạm 20 stud
                                hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, 20)
                            end
                            task.wait(2)
                            
                        elseif roomToJoin and not alreadyInSomeoneRoom then
                            print("🚀 Tự động bay vào phòng ké...")
                            hrp.CFrame = CFrame.new(roomToJoin)
                            task.wait(3)
                        end

                    end
                end
            end)
        end

        -- 4. Logic Auto-Exit Hầm Ngục
        if autoExitEnabled and not autoExitTriggered then
            local labStage = findUIElementByName(playerGui, "LabStage")
            local fmTimeFrame = nil
            pcall(function() fmTimeFrame = playerGui.MainGui.ScreenGui.ArenaMainRightTopView.FmTime end)

            if labStage then
                local currentStage, maxStage = string.match(labStage.Text, "(%d+)/(%d+)")

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
    if antiAfkEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

Rayfield:Notify({ Title = "Thành Công!", Content = "Bản Tool chuẩn Ultimate đã sẵn sàng!", Duration = 5 })
