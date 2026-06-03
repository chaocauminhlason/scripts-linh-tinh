local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TextChatService = game:GetService("TextChatService")
local PathfindingService = game:GetService("PathfindingService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse() -- Dùng để lấy mục tiêu con trỏ chuột
-- Sử dụng CoreGui để UI không bị mất (ưu tiên cho Executor)
local guiParent = pcall(function() return CoreGui.Name end) and CoreGui or player:WaitForChild("PlayerGui")

-- ========================================== --
-- BIẾN HỆ THỐNG                              --
-- ========================================== --
local autoClicking = false
local seqClicking = false
local useToolMode = false 
local clickSpeed = 0.1
local savedPos = {}

local antiAfk = true         
local allowFollow = true     
local continuousFollow = true 
local targetClicks = 1       
local targetLoops = 1        
local currentClicks = 0
local currentLoops = 0

local isFollowing = false
local followTarget = nil

-- Biến cho Auto Farm
local itemWhitelist = {}
local autoFarmEnabled = false
local itemFolder = workspace -- Thư mục chứa vật phẩm (có thể chỉnh lại nếu game dùng folder khác)

-- ========================================== --
-- DỌN DẸP UI CŨ (CHỐNG TRÙNG LẶP)            --
-- ========================================== --
if guiParent:FindFirstChild("FastClickProGui") then
    guiParent.FastClickProGui:Destroy()
end

-- ========================================== --
-- TẠO GIAO DIỆN (CÓ THANH CUỘN)              --
-- ========================================== --
local gui = Instance.new("ScreenGui", guiParent)
gui.Name = "FastClickProGui"
gui.ResetOnSpawn = false 

local openBtn = Instance.new("TextButton", gui)
openBtn.Size = UDim2.new(0, 120, 0, 35)
openBtn.Position = UDim2.new(0.5, -60, 0, 10)
openBtn.Text = "Mở FastClick"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 14
openBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
openBtn.TextColor3 = Color3.new(1, 1, 1)
openBtn.Visible = false
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 6)

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 290, 0, 480) 
frame.Position = UDim2.new(0, 20, 0, 20)
frame.BackgroundColor3 = Color3.fromRGB(25, 28, 33) 
frame.Active = true
frame.Draggable = true 
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local shadow = Instance.new("UIStroke", frame)
shadow.Color = Color3.fromRGB(0, 0, 0)
shadow.Transparency = 0.5
shadow.Thickness = 2

local header = Instance.new("Frame", frame)
header.Size = UDim2.new(1, -20, 0, 30)
header.Position = UDim2.new(0, 10, 0, 10)
header.BackgroundTransparency = 1

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(0.8, 0, 1, 0)
title.Text = "FASTCLICK PRO V3"
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.BackgroundTransparency = 1

local minBtn = Instance.new("TextButton", header)
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(1, -30, 0, 0)
minBtn.Text = "_"
minBtn.Font = Enum.Font.GothamBold
minBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

minBtn.MouseButton1Click:Connect(function()
    frame.Visible = false
    openBtn.Visible = true
end)
openBtn.MouseButton1Click:Connect(function()
    frame.Visible = true
    openBtn.Visible = false
end)

local container = Instance.new("ScrollingFrame", frame)
container.Size = UDim2.new(1, -20, 1, -55)
container.Position = UDim2.new(0, 10, 0, 45) 
container.BackgroundTransparency = 1
container.BorderSizePixel = 0
container.ScrollBarThickness = 4 
container.ScrollBarImageColor3 = Color3.fromRGB(120, 125, 130)
container.ScrollingDirection = Enum.ScrollingDirection.Y
container.AutomaticCanvasSize = Enum.AutomaticSize.Y 
container.CanvasSize = UDim2.new(0, 0, 0, 0)

local layout = Instance.new("UIListLayout", container)
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- ========================================== --
-- HÀM HỖ TRỢ TẠO UI COMPONENTS               --
-- ========================================== --
local function createSectionTitle(text)
    local lbl = Instance.new("TextLabel", container)
    lbl.Size = UDim2.new(1, 0, 0, 25)
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Color3.fromRGB(150, 160, 170)
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
end

local function createSeparator()
    local line = Instance.new("Frame", container)
    line.Size = UDim2.new(1, -10, 0, 1)
    line.BackgroundColor3 = Color3.fromRGB(50, 55, 60)
    line.BorderSizePixel = 0
    local spacer = Instance.new("Frame", container)
    spacer.Size = UDim2.new(1, 0, 0, 2)
    spacer.BackgroundTransparency = 1
end

local function createToggle(labelText, defaultState, callback)
    local row = Instance.new("Frame", container)
    row.Size = UDim2.new(1, -10, 0, 30) 
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0.35, 0, 0.8, 0)
    btn.Position = UDim2.new(0.65, 0, 0.1, 0)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local isOn = defaultState
    local function updateVisuals()
        if isOn then
            btn.Text = "BẬT 🟢"
            btn.BackgroundColor3 = Color3.fromRGB(45, 160, 85)
        else
            btn.Text = "TẮT 🔘"
            btn.BackgroundColor3 = Color3.fromRGB(70, 75, 80)
        end
    end
    updateVisuals()

    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        updateVisuals()
        if callback then callback(isOn) end
    end)
    return {
        setState = function(state)
            isOn = state
            updateVisuals()
            if callback then callback(isOn) end
        end
    }
end

local function createInputRow(labelText, defaultText, callback)
    local row = Instance.new("Frame", container)
    row.Size = UDim2.new(1, -10, 0, 30)
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1

    local box = Instance.new("TextBox", row)
    box.Size = UDim2.new(0.45, 0, 0.8, 0)
    box.Position = UDim2.new(0.55, 0, 0.1, 0)
    box.Text = defaultText
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
    box.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new("UIStroke", box)
    stroke.Color = Color3.fromRGB(60, 65, 70)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    box.FocusLost:Connect(function()
        local val = tonumber(box.Text)
        if val and val >= 0 then
            if callback then callback(val) end
        else
            box.Text = defaultText
        end
    end)
    return box
end

local function createActionRow(text, color, callback)
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.new(1, 1, 1)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Transparency = 0.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- ========================================== --
-- XÂY DỰNG GIAO DIỆN CHÍNH                   --
-- ========================================== --

-- 1. AUTOCLICK
createSectionTitle("⚡ AUTOCLICK")
local basicToggleUI = createToggle("Trạng thái", false, function(state) autoClicking = state if state then currentClicks = 0 end end)
createToggle("Chế độ: Dùng Tool", false, function(state) useToolMode = state end)
createInputRow("Tốc độ (s)", "0.1", function(val) clickSpeed = math.max(val, 0.015) end)
createInputRow("Số lần (0 = Vô hạn)", "1", function(val) targetClicks = val end)

createSeparator()

-- 2. TỌA ĐỘ
createSectionTitle("📍 CHUỖI TỌA ĐỘ (MACRO)")
local coordLabel = Instance.new("TextLabel", container)
coordLabel.Size = UDim2.new(1, -10, 0, 25)
coordLabel.Text = "[P] Trỏ chuột lưu (Đã lưu: 0)"
coordLabel.Font = Enum.Font.Gotham
coordLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
coordLabel.TextSize = 12
coordLabel.TextXAlignment = Enum.TextXAlignment.Center
coordLabel.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
Instance.new("UICorner", coordLabel).CornerRadius = UDim.new(0, 6)

local seqToggleUI = createToggle("Chạy chuỗi", false, function(state)
    if state and #savedPos == 0 then
        warn("Chưa lưu tọa độ nào!")
        seqClicking = false
        return
    end
    seqClicking = state
    if state then currentLoops = 0 end
end)
createInputRow("Số vòng (0 = Vô hạn)", "1", function(val) targetLoops = val end)
createActionRow("🗑️ Xóa chuỗi tọa độ", Color3.fromRGB(180, 50, 50), function()
    table.clear(savedPos)
    coordLabel.Text = "[P] Trỏ chuột lưu (Đã lưu: 0)"
end)

createSeparator()

-- 3. AUTO NHẶT ĐỒ (FARM)
createSectionTitle("🎒 AUTO NHẶT ĐỒ")
local farmToggleUI = createToggle("Trạng thái nhặt", false, function(state) autoFarmEnabled = state end)

local listLabel = Instance.new("TextLabel", container)
listLabel.Size = UDim2.new(1, -10, 0, 35)
listLabel.Text = "Danh sách trống"
listLabel.Font = Enum.Font.Gotham
listLabel.TextSize = 11
listLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
listLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
listLabel.TextWrapped = true
Instance.new("UICorner", listLabel).CornerRadius = UDim.new(0, 6)

-- NÚT THÊM VẬT PHẨM TỪ TÚI ĐỒ (ĐANG TRANG BỊ)
createActionRow("➕ Thêm vật đang cầm trên tay", Color3.fromRGB(45, 160, 85), function()
    local char = player.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            if not table.find(itemWhitelist, tool.Name) then
                table.insert(itemWhitelist, tool.Name)
                listLabel.Text = "Đang tìm: " .. table.concat(itemWhitelist, ", ")
                listLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
            end
        else
            listLabel.Text = "⚠️ Lỗi: Bạn chưa cầm vật phẩm nào trên tay!"
            listLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            task.wait(2)
            if #itemWhitelist > 0 then
                listLabel.Text = "Đang tìm: " .. table.concat(itemWhitelist, ", ")
                listLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
            else
                listLabel.Text = "Danh sách trống"
                listLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            end
        end
    end
end)

-- HƯỚNG DẪN THÊM BẰNG CÁCH TRỎ CHUỘT
local hoverInstruction = Instance.new("TextLabel", container)
hoverInstruction.Size = UDim2.new(1, -10, 0, 25)
hoverInstruction.Text = "Hoặc: Trỏ chuột vào vật + Bấm [O] để thêm"
hoverInstruction.Font = Enum.Font.Gotham
hoverInstruction.TextColor3 = Color3.fromRGB(180, 180, 180)
hoverInstruction.TextSize = 11
hoverInstruction.TextXAlignment = Enum.TextXAlignment.Center
hoverInstruction.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
Instance.new("UICorner", hoverInstruction).CornerRadius = UDim.new(0, 6)

createActionRow("🗑️ Xóa danh sách vật phẩm", Color3.fromRGB(180, 50, 50), function()
    table.clear(itemWhitelist)
    listLabel.Text = "Danh sách trống"
    listLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
end)

createSeparator()

-- 4. TIỆN ÍCH (FOLLOW & AFK)
createSectionTitle("🛠️ TIỆN ÍCH")
createToggle("Chống AFK", true, function(state) antiAfk = state end)

local followStatusLabel = Instance.new("TextLabel", container)
followStatusLabel.Size = UDim2.new(1, -10, 0, 40)
followStatusLabel.Text = "📡 Đang chờ ai đó gọi lệnh..."
followStatusLabel.Font = Enum.Font.Gotham
followStatusLabel.TextSize = 11
followStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
followStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
followStatusLabel.TextWrapped = true
Instance.new("UICorner", followStatusLabel).CornerRadius = UDim.new(0, 6)

createToggle("Lệnh Follow", true, function(state)
    allowFollow = state
    if state then
        followStatusLabel.Text = "📡 Đang chờ ai đó gọi lệnh..."
        followStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    else
        isFollowing = false
        followStatusLabel.Text = "Trạng thái: Đã tắt"
        followStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid:MoveTo(player.Character.HumanoidRootPart.Position)
        end
    end
end)
createToggle("Bám sát liên tục", true, function(state) continuousFollow = state end)

createActionRow("🛑 Hủy Follow hiện tại", Color3.fromRGB(180, 50, 50), function()
    isFollowing = false
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid:MoveTo(player.Character.HumanoidRootPart.Position)
    end
    if allowFollow then
        followStatusLabel.Text = "🛑 Đã hủy! Đang chờ lệnh mới..."
        followStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
end)

local bottomSpacer = Instance.new("Frame", container)
bottomSpacer.Size = UDim2.new(1, 0, 0, 10)
bottomSpacer.BackgroundTransparency = 1

-- ========================================== --
-- LOGIC PATHFINDING CHUNG (FOLLOW & NHẶT ĐỒ) --
-- ========================================== --
local pathParams = {
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentCanClimb = false
}

-- ========================================== --
-- LOGIC BẮT SỰ KIỆN BÀN PHÍM/CHUỘT           --
-- ========================================== --
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    -- Phím P: Lưu tọa độ AutoClick
    if input.KeyCode == Enum.KeyCode.P then
        local loc = UserInputService:GetMouseLocation()
        table.insert(savedPos, {X = loc.X, Y = loc.Y})
        coordLabel.Text = "Điểm " .. #savedPos .. " (X:" .. math.floor(loc.X) .. ", Y:" .. math.floor(loc.Y) .. ")"
        
    -- Phím O: Lấy tên vật phẩm đang trỏ chuột
    elseif input.KeyCode == Enum.KeyCode.O then
        local target = mouse.Target
        if target then
            -- Quét xem target hoặc Parent của nó có ProximityPrompt không
            local finalName = target.Name
            if target.Parent and target.Parent:FindFirstChildWhichIsA("ProximityPrompt") then
                finalName = target.Parent.Name
            elseif target:FindFirstChildWhichIsA("ProximityPrompt") then
                finalName = target.Name
            end
            
            -- Thêm vào danh sách trắng
            if not table.find(itemWhitelist, finalName) then
                table.insert(itemWhitelist, finalName)
                listLabel.Text = "Đang tìm: " .. table.concat(itemWhitelist, ", ")
                listLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
            end
        end
    end
end)

-- ========================================== --
-- LOGIC AUTO NHẶT ĐỒ                         --
-- ========================================== --
local function getNearestItem()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local rootPart = character.HumanoidRootPart

    local nearestItem = nil
    local shortestDistance = math.huge

    for _, object in ipairs(itemFolder:GetDescendants()) do
        if object:IsA("ProximityPrompt") then
            local itemPart = object.Parent
            if itemPart and itemPart:IsA("BasePart") then
                if table.find(itemWhitelist, itemPart.Name) then
                    local distance = (rootPart.Position - itemPart.Position).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        nearestItem = itemPart
                    end
                end
            end
        end
    end
    return nearestItem
end

local function autoCollect(targetItem)
    local character = player.Character
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    local prompt = targetItem:FindFirstChildWhichIsA("ProximityPrompt")

    if not prompt then return false end

    local path = PathfindingService:CreatePath(pathParams)
    local success, _ = pcall(function()
        path:ComputeAsync(rootPart.Position, targetItem.Position)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()

        for _, waypoint in ipairs(waypoints) do
            if not targetItem or not targetItem.Parent or not autoFarmEnabled then return false end

            local distanceToTarget = (rootPart.Position - targetItem.Position).Magnitude
            if distanceToTarget <= prompt.MaxActivationDistance then break end

            if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end

            humanoid:MoveTo(waypoint.Position)
            local moveSuccess = humanoid.MoveToFinished:Wait(2)
            if not moveSuccess then
                humanoid.Jump = true
                return false 
            end
        end

        local finalDistance = (rootPart.Position - targetItem.Position).Magnitude
        if finalDistance <= prompt.MaxActivationDistance then
            if fireproximityprompt then
                fireproximityprompt(prompt)
            end
            task.wait(0.5) 
            return true
        end
    end
    return false
end

task.spawn(function()
    while task.wait(1) do
        if autoFarmEnabled and #itemWhitelist > 0 and not isFollowing then
            local itemToCollect = getNearestItem()
            if itemToCollect then
                autoCollect(itemToCollect)
            end
        end
    end
end)

-- ========================================== --
-- LOGIC FOLLOW BẰNG PATHFINDING              --
-- ========================================== --
local function runToPlayer(targetPlayer)
    if not player.Character or not targetPlayer.Character then return end
    
    isFollowing = true
    followTarget = targetPlayer
    
    task.spawn(function()
        local dots = 0
        while isFollowing and followTarget and followTarget.Character do
            local myChar = player.Character
            local targetChar = followTarget.Character
            
            local myHRP = myChar:FindFirstChild("HumanoidRootPart")
            local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
            local myHumanoid = myChar:FindFirstChildOfClass("Humanoid")
            
            if myHRP and targetHRP and myHumanoid then
                local distance = (myHRP.Position - targetHRP.Position).Magnitude
                
                if distance <= 4.5 then
                    if continuousFollow then
                        myHumanoid:MoveTo(myHRP.Position) 
                        followStatusLabel.Text = "✅ Đang bám sát: " .. targetPlayer.Name
                        followStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                        task.wait(0.5)
                    else
                        followStatusLabel.Text = "✅ Đã tới mục tiêu: " .. targetPlayer.Name
                        followStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                        isFollowing = false
                        break
                    end
                else
                    local path = PathfindingService:CreatePath(pathParams)
                    local success, _ = pcall(function()
                        path:ComputeAsync(myHRP.Position, targetHRP.Position)
                    end)

                    if success and path.Status == Enum.PathStatus.Success then
                        local waypoints = path:GetWaypoints()
                        local stepLimit = math.min(4, #waypoints) 
                        for i = 1, stepLimit do
                            if not isFollowing or not targetChar.Parent then break end
                            local wp = waypoints[i]
                            if wp.Action == Enum.PathWaypointAction.Jump then
                                myHumanoid.Jump = true
                            end
                            myHumanoid:MoveTo(wp.Position)
                            myHumanoid.MoveToFinished:Wait(2)
                        end
                    else
                        myHumanoid:MoveTo(targetHRP.Position)
                        task.wait(0.3)
                    end

                    dots = (dots + 1) % 4
                    local dotStr = string.rep(".", dots)
                    followStatusLabel.Text = string.format("Đang đuổi theo %s%s\n📍 X: %d | Y: %d | Z: %d", 
                        targetPlayer.Name, dotStr, math.floor(targetHRP.Position.X), math.floor(targetHRP.Position.Y), math.floor(targetHRP.Position.Z))
                    followStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 100) 
                end
            else
                isFollowing = false
                followStatusLabel.Text = "❌ Mất dấu mục tiêu!"
                followStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                break
            end
        end
    end)
end

-- ========================================== --
-- LOGIC CLICK CHUỘT VÀ CHỐNG AFK             --
-- ========================================== --
player.Idled:Connect(function()
    if antiAfk then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F15, false, game)
        task.wait()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F15, false, game)
    end
end)

task.spawn(function()
    while true do
        if autoClicking then
            if targetClicks > 0 and currentClicks >= targetClicks then
                basicToggleUI.setState(false) 
                continue
            end
            
            if useToolMode then
                local char = player.Character
                if char and char:FindFirstChildOfClass("Tool") then
                    char:FindFirstChildOfClass("Tool"):Activate()
                end
            else
                local loc = UserInputService:GetMouseLocation()
                VirtualInputManager:SendMouseButtonEvent(loc.X, loc.Y, 0, true, game, 0)
                task.wait()
                VirtualInputManager:SendMouseButtonEvent(loc.X, loc.Y, 0, false, game, 0)
            end
            currentClicks = currentClicks + 1
            task.wait(math.max(0.015, clickSpeed + (math.random(-10, 10) / 1000)))
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while true do
        if seqClicking and #savedPos > 0 then
            if targetLoops > 0 and currentLoops >= targetLoops then
                seqToggleUI.setState(false)
                continue
            end
            for i, pos in ipairs(savedPos) do
                if not seqClicking then break end
                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                task.wait()
                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
                task.wait(math.max(0.015, clickSpeed + (math.random(-10, 10) / 1000)))
            end
            currentLoops = currentLoops + 1
        else
            task.wait(0.1)
        end
    end
end)

-- ========================================== --
-- XỬ LÝ LỆNH CHAT                            --
-- ========================================== --
local function onChatCommand(msg, sender)
    local text = string.lower(msg)
    if text == "!start" or text == "!s" or text == "!on" then
        basicToggleUI.setState(true)
    elseif text == "!stop" or text == "!x" or text == "!off" then
        basicToggleUI.setState(false)
    elseif (text == "!start_seq" or text == "!ss" or text == "!play") and #savedPos > 0 then
        seqToggleUI.setState(true)
    elseif text == "!stop_seq" or text == "!xs" or text == "!pause" then
        seqToggleUI.setState(false)
    elseif text == "follow" or text == "!f" then
        if allowFollow and sender ~= player then runToPlayer(sender) end
    elseif text == "unfollow" or text == "!uf" or text == "!xf" then
        if isFollowing and (sender == player or sender == followTarget) then
            isFollowing = false
            if player.Character and player.Character:FindFirstChild("Humanoid") then
                player.Character.Humanoid:MoveTo(player.Character.HumanoidRootPart.Position)
            end
            if allowFollow then
                followStatusLabel.Text = "🛑 " .. sender.Name .. " đã ngắt Follow."
                followStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
            end
        end
    end
end

TextChatService.MessageReceived:Connect(function(textChatMessage)
    if textChatMessage.TextSource then
        local sender = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
        if sender then onChatCommand(textChatMessage.Text, sender) end
    end
end)
for _, p in pairs(Players:GetPlayers()) do p.Chatted:Connect(function(msg) onChatCommand(msg, p) end) end
Players.PlayerAdded:Connect(function(p) p.Chatted:Connect(function(msg) onChatCommand(msg, p) end) end)