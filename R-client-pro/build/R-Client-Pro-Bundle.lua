-- ====================================================================
-- R-CLIENT PRO BUNDLE (AUTO-BUNDLED ALL MODULES)
-- ====================================================================

local modules = {}

modules['core/utilities.txt'] = function(...)
-- ====================================================================
-- MODULE: UTILITIES (CÁC HÀM TIỆN ÍCH DÙNG CHUNG)
-- VERSION: 2.0 - THÊM HỆ THỐNG DỊCH CHUYỂN
-- ====================================================================
local Utils = {}

-- Khai báo các Services cần thiết nội bộ trong module
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- Biến hàng đợi toàn cục
_G.HopQueue = {
    Requests = {}, -- Danh sách yêu cầu {Priority = 1, Sender = "Boss"}
    IsProcessing = false
}

function Utils.RequestHop(senderName, priority)
    table.insert(_G.HopQueue.Requests, {Sender = senderName, Priority = priority or 1})
    print("[Dispatcher] 📥 Đã nhận yêu cầu hop từ: " .. senderName)
    
    if not _G.HopQueue.IsProcessing then
        Utils.ProcessQueue()
    end
end

function Utils.ProcessQueue()
    if #_G.HopQueue.Requests == 0 then return end
    
    _G.HopQueue.IsProcessing = true
    -- Sắp xếp theo ưu tiên (Số càng cao càng ưu tiên)
    table.sort(_G.HopQueue.Requests, function(a, b) return a.Priority > b.Priority end)
    
    local topRequest = table.remove(_G.HopQueue.Requests, 1)
    print("[Dispatcher] 🚀 Đang xử lý hop cho: " .. topRequest.Sender)
    
    -- Gọi hàm Hop cũ
    Utils.HopServerV2("Đang chuyển server theo yêu cầu của: " .. topRequest.Sender)
    
    task.wait(15) -- Cooldown cứng để đảm bảo server mới load xong
    _G.HopQueue.IsProcessing = false
    
    -- Xử lý tiếp nếu còn hàng đợi
    if #_G.HopQueue.Requests > 0 then
        Utils.ProcessQueue()
    end
end
-- ==========================================
-- CACHE REMOTE
-- ==========================================
local cachedRemote = nil

local function GetDataPullFunc()
    if cachedRemote then return cachedRemote end
    
    local success, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("CommonLibrary")
            :WaitForChild("Tool")
            :WaitForChild("RemoteManager")
            :WaitForChild("Funcs")
            :WaitForChild("DataPullFunc")
    end)
    
    if success and remote then
        cachedRemote = remote
        return remote
    end
    return nil
end

-- ==========================================
-- HỆ THỐNG DỊCH CHUYỂN (TELEPORT)
-- ==========================================

-- BẢNG MAP: Area ID → Tên khu vực
local AreaMap = {
    [1] = "Starter Island",
    [2] = "Volcano",
    [3] = "Frost Isle",
    [4] = "Neverland",
    [5] = "Duneveil Isle",
    [6] = "Tideland",
    [7] = "Spirit Grove",
    [8] = "Dragon's Breath",
    [9] = "Blossom Haven",
    [10] = "Mobius Circus",
    [11] = "Specter Shallows",
    [12] = "Nova Coast"
}

-- ==========================================
-- 1. DỊCH CHUYỂN ĐẾN KHU VỰC BẰNG REMOTE
-- ==========================================
function Utils.TeleportToArea(areaId)
    local remote = GetDataPullFunc()
    if not remote then
        warn("[Utils] ❌ Không tìm thấy DataPullFunc")
        return false
    end
    
    local success, result = pcall(function()
        return remote:InvokeServer("AreaTeleportToRegionChannel", areaId)
    end)
    
    if success then
        local areaName = AreaMap[areaId] or "Unknown (" .. areaId .. ")"
        print("[Utils] 🚀 Đã dịch chuyển đến: " .. areaName)
        return true
    else
        warn("[Utils] ❌ Dịch chuyển thất bại: " .. tostring(result))
        return false
    end
end

-- ==========================================
-- 2. DỊCH CHUYỂN ĐẾN STARTER ISLAND (ID: 1)
-- ==========================================
function Utils.TeleportToStarterIsland()
    return Utils.TeleportToArea(1)
end

-- ==========================================
-- 3. DỊCH CHUYỂN ĐẾN VOLCANO (ID: 2)
-- ==========================================
function Utils.TeleportToVolcano()
    return Utils.TeleportToArea(2)
end

-- ==========================================
-- 4. DỊCH CHUYỂN ĐẾN KHU VỰC THEO TÊN
-- ==========================================
function Utils.TeleportToAreaByName(areaName)
    for id, name in pairs(AreaMap) do
        if string.find(string.lower(name), string.lower(areaName)) then
            return Utils.TeleportToArea(id)
        end
    end
    warn("[Utils] ❌ Không tìm thấy khu vực: " .. areaName)
    return false
end

-- ==========================================
-- LẤY AREA ID HIỆN TẠI (AN TOÀN / FALLBACK)
-- ==========================================
function Utils.GetCurrentAreaId()
    -- Kiểm tra các phụ bản đặc biệt trước (Abyss, Rift)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local mainGui = playerGui:FindFirstChild("MainGui")
        local screenGui = mainGui and mainGui:FindFirstChild("ScreenGui")
        if screenGui then
            local abyssView = screenGui:FindFirstChild("AbyssMainTopView")
            if abyssView and abyssView.Visible then
                return "Abyss"
            end
            
            local arenaView = screenGui:FindFirstChild("ArenaMainRightTopView")
            if arenaView and arenaView.Visible then
                return "Rift"
            end
        end
    end

    -- Cách 1: Lấy trực tiếp từ AreaSignShower của game (Độ chính xác 100%)
    local success, areaId = pcall(function()
        local env = getrenv and getrenv()._G and getrenv()._G.PathTool
        if env and env.AreaSignShower and type(env.AreaSignShower.GetSelfAreaId) == "function" then
            return tonumber(env.AreaSignShower.GetSelfAreaId())
        end
    end)
    if success and areaId then return areaId end

    -- Cách 2: Phân tích khoảng cách vật lý làm phương án dự phòng (So khớp TeleKey trong CfgAreaRegion)
    local success2, closestAreaId = pcall(function()
        local env = getrenv and getrenv()._G and getrenv()._G.PathTool
        local areaFolder = Workspace:FindFirstChild("Area")
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if env and env.CfgAreaRegion and env.CfgAreaRegion.Tmpls and areaFolder and hrp then
            local minDist = math.huge
            local bestId = nil
            
            for _, folder in ipairs(areaFolder:GetChildren()) do
                local folderNameLower = folder.Name:lower()
                local matchedId = nil
                
                -- Tìm Area ID tương ứng trong CfgAreaRegion.Tmpls dựa trên TeleKey
                for id, tmpl in pairs(env.CfgAreaRegion.Tmpls) do
                    if type(tmpl) == "table" and tmpl.TeleKey then
                        local telePrefix = string.split(tmpl.TeleKey, ".")[1]
                        if telePrefix and string.lower(telePrefix) == folderNameLower then
                            matchedId = tonumber(id)
                            break
                        end
                    end
                end
                
                -- Fallback nếu không khớp được qua TeleKey
                if not matchedId then
                    if folderNameLower == "center" then
                        matchedId = 1
                    else
                        -- Dự phòng so khớp gần đúng tên từ AreaMap
                        for id, areaName in pairs(AreaMap) do
                            local cleanName = areaName:lower()
                                :gsub(" island", "")
                                :gsub(" isle", "")
                                :gsub(" grove", "")
                                :gsub(" shallows", "")
                                :gsub(" coast", "")
                                :gsub(" haven", "")
                            if string.find(folderNameLower, cleanName) or string.find(cleanName, folderNameLower) then
                                matchedId = id
                                break
                            end
                        end
                    end
                end
                
                if matchedId then
                    local folderPos = nil
                    pcall(function() folderPos = folder:GetPivot().Position end)
                    if folderPos then
                        local dist = (hrp.Position - folderPos).Magnitude
                        if dist < minDist then
                            minDist = dist
                            bestId = matchedId
                        end
                    end
                end
            end
            return bestId
        end
    end)
    if success2 and closestAreaId then return closestAreaId end

    return nil
end

-- ==========================================
-- 5. LẤY DANH SÁCH CÁC KHU VỰC
-- ==========================================
function Utils.GetAreaList()
    local areas = {}
    for id, name in pairs(AreaMap) do
        table.insert(areas, {id = id, name = name})
    end
    table.sort(areas, function(a, b) return a.id < b.id end)
    return areas
end

-- ==========================================
-- 6. DỊCH CHUYỂN ĐẾN VỊ TRÍ CỤ THỂ (CFrame)
-- ==========================================
function Utils.TeleportToPosition(position, offsetY)
    offsetY = offsetY or 5
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then 
        warn("[Utils] ❌ Không tìm thấy HumanoidRootPart")
        return false 
    end
    
    local targetPos = position.Position + Vector3.new(0, offsetY, 0)
    hrp.CFrame = CFrame.new(targetPos)
    return true
end

-- ==========================================
-- 7. DỊCH CHUYỂN AN TOÀN (CÓ RAYCAST)
-- ==========================================
function Utils.SafeTeleport(targetCFrame, offsetY)
    offsetY = offsetY or 5
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local targetPos = targetCFrame.Position + Vector3.new(0, offsetY, 0)
    
    -- Raycast kiểm tra mặt đất
    local rayOrigin = targetPos + Vector3.new(0, 10, 0)
    local rayDirection = Vector3.new(0, -20, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if rayResult then
        local groundY = rayResult.Position.Y
        targetPos = Vector3.new(targetPos.X, groundY + 3, targetPos.Z)
    end
    
    hrp.CFrame = CFrame.new(targetPos)
    return true
end

-- ==========================================
-- 8. DỊCH CHUYỂN ĐẾN BOSS (DÙNG CHO BOSS HUNT)
-- ==========================================
function Utils.TeleportToBoss(bossPosition, offsetY)
    offsetY = offsetY or 8
    if not bossPosition then return false end
    
    -- Tạo CFrame từ Vector3
    local cframe = CFrame.new(bossPosition)
    return Utils.SafeTeleport(cframe, offsetY)
end

-- ==========================================
-- 9. VỀ VỊ TRÍ FARM ĐÃ LƯU
-- ==========================================
function Utils.GoToFarmPos()
    local posFileName = "R_ClientPro_FarmPos.json"
    local HttpService = game:GetService("HttpService")
    local farmPos = nil
    
    pcall(function()
        if isfile and isfile(posFileName) then
            local data = HttpService:JSONDecode(readfile(posFileName))
            if data and data.X and data.Y and data.Z then
                farmPos = CFrame.new(data.X, data.Y, data.Z)
            end
        end
    end)
    
    if farmPos then
        return Utils.SafeTeleport(farmPos, 5)
    end
    return false
end

-- ==========================================
-- HÀM TEST KẾT NỐI
-- ==========================================
function Utils.TestKetNoi()
    print("✅ Đã load thành công Module Utilities 2.0!")
    print("📋 Danh sách khu vực có thể dịch chuyển:")
    for id, name in pairs(AreaMap) do
        print("   [" .. id .. "] " .. name)
    end
end

-- ==========================================
-- HÀM QUÉT UI ĐỆ QUY
-- ==========================================
function Utils.FindUIElementByName(parent, name)
    if not parent then return nil end
    for _, child in ipairs(parent:GetDescendants()) do
        if child.Name == name then 
            return child 
        end
    end
    return nil
end

-- ==========================================
-- HÀM CLICK CHUỘT ẢO
-- ==========================================
function Utils.ClickButtonExact(button, debugName)
    if not button then return end
    
    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    
    local centerX = absPos.X + (absSize.X / 2)
    local finalY = absPos.Y + (absSize.Y / 2)
    
    local screenGui = button:FindFirstAncestorOfClass("ScreenGui")
    if screenGui and not screenGui.IgnoreGuiInset then 
        finalY = finalY + GuiService:GetGuiInset().Y 
    end
    
    VirtualInputManager:SendMouseButtonEvent(centerX, finalY, 0, true, game, 1)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(centerX, finalY, 0, false, game, 1)
    
    if debugName then
        print("🖱️ [Utils] Đã click ảo vào: " .. debugName)
    end
end

-- ==========================================
-- HÀM LẤY ID NGƯỜI CHƠI
-- ==========================================
local cachedPlayerId = nil
function Utils.GetPlayerId()
    if cachedPlayerId then 
        return cachedPlayerId 
    end
    
    local petsFolder = Workspace:FindFirstChild("Pets")
    if not petsFolder then return nil end
    
    for _, pet in pairs(petsFolder:GetChildren()) do
        if pet:IsA("BasePart") then
            local playerId = pet:GetAttribute("PlayerId")
            if playerId then
                cachedPlayerId = playerId
                return playerId
            end
        end
    end
    
    return nil
end

-- ==========================================
-- HÀM X-RAY QUÉT MẶT ĐẤT
-- ==========================================
function Utils.GetGroundPosition(targetPosition)
    local rayOrigin = targetPosition + Vector3.new(0, 50, 0)
    local rayDirection = Vector3.new(0, -100, 0)

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local char = game.Players.LocalPlayer.Character
    local petsFolder = game.Workspace:FindFirstChild("Pets")
    raycastParams.FilterDescendantsInstances = {char, petsFolder} 

    local raycastResult = game.Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

    if raycastResult then
        return raycastResult.Position + Vector3.new(0, 3, 0)
    else
        return targetPosition + Vector3.new(0, 3, 0)
    end
end

-- ==========================================
-- HỆ THỐNG CHIẾN ĐẤU & TƯƠNG TÁC REMOTE
-- ==========================================

-- 1. Lên / Xuống thú cưỡi
function Utils.ToggleMount(state)
    local remote = GetDataPullFunc()
    if remote then
        pcall(function() remote:InvokeServer("PetSwitchRideStatusChannel", state) end)
    end
end

-- 2. Tự động nhảy xuống thú an toàn
function Utils.SmartDismount()
    local isRiding = LocalPlayer:GetAttribute("RidePetId") ~= nil
    if isRiding then
        Utils.ToggleMount(false)
        task.wait(0.3)
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChild("Humanoid")
        if humanoid then humanoid.Jump = true end
        task.wait(0.1)
    end
end

-- 3. Gửi lệnh tấn công quái
function Utils.AttackMonster(monsterId)
    local remote = GetDataPullFunc()
    if remote then
        pcall(function() remote:InvokeServer("MonsterAttackChannel", monsterId) end)
    end
end

-- 4. Gửi lệnh ném bóng bắt quái
function Utils.CatchMonster(monsterId)
    local remote = GetDataPullFunc()
    if remote then
        pcall(function() remote:InvokeServer("MonsterCatchStartChannel", monsterId) end)
    end
end

-- 5. Gửi lệnh Rời Phòng / Thoát Trận
function Utils.LeaveMatch(riftId, teamId)
    local remote = GetDataPullFunc()
    if remote then
        pcall(function()
            remote:InvokeServer("ArenaLeaveChannel")
            if riftId and teamId then
                remote:InvokeServer("DungeonLeaveTeamChannel", riftId, teamId)
            end
        end)
    end
end

-- ==========================================
-- DỊCH TÊN QUÁI TỪ DỮ LIỆU GAME (CfgMonster)
-- ==========================================
function Utils.ResolveMonsterName(monsterObj)
    if not monsterObj then return "Unknown" end
    local originalName = monsterObj.Name
    
    -- Cách 1: Giải mã qua CfgMonster từ game env
    local uidStr = string.match(originalName, "Monster_(%d+)")
    if uidStr then
        local uidNum = tonumber(uidStr)
        local env = getrenv and getrenv()._G and getrenv()._G.PathTool
        if env and env.MgrMonsterClient and env.CfgMonster then
            local success, info = pcall(function() return env.MgrMonsterClient:GetMonsterInfo(uidNum) end)
            if success and info then
                local tmplId = info.tmplId or info.TmplId or info.id
                local cfgData = env.CfgMonster.Tmpls[tostring(tmplId)] or env.CfgMonster.Tmpls[tonumber(tmplId)]
                if cfgData then
                    local name = cfgData.Name or cfgData.name or cfgData.Title
                    if name then return name end
                end
            end
        end
    end

    -- Cách 2: Tìm BillboardGui chứa tên hiển thị (UI Name) của quái
    for _, child in ipairs(monsterObj:GetDescendants()) do
        if child:IsA("TextLabel") and child.Visible then
            local text = child.Text
            if text and text ~= "" and not string.find(text, "/") and not string.find(text, "HP") then
                -- Xóa phần lv hiển thị (ví dụ: "Walrusk Lv.100" -> "Walrusk")
                local cleaned = string.gsub(text, "%s*Lv%.%s*%d+", "")
                cleaned = string.gsub(cleaned, "%s*%[%s*Lv%.%s*%d+%s*%]", "")
                cleaned = string.gsub(cleaned, "^%s*(.-)%s*$", "%1") -- Trim space
                if cleaned ~= "" and not tonumber(cleaned) then
                    return cleaned
                end
            end
        end
    end

    -- Cách 3: Lấy Humanoid DisplayName
    local hum = monsterObj:FindFirstChildOfClass("Humanoid")
    if hum and hum.DisplayName and hum.DisplayName ~= "" then
        local cleaned = string.gsub(hum.DisplayName, "%s*Lv%.%s*%d+", "")
        cleaned = string.gsub(cleaned, "%s*%[%s*Lv%.%s*%d+%s*%]", "")
        cleaned = string.gsub(cleaned, "^%s*(.-)%s*$", "%1")
        if cleaned ~= "" then return cleaned end
    end

    -- Cách 4: Cắt bỏ tiền tố "Monster_" nếu có
    if uidStr then
        local cleanName = string.gsub(originalName, "Monster_%d+", "")
        if cleanName ~= "" then return cleanName end
    end

    return originalName
end

-- 6. HỆ THỐNG RADAR: Quét, phân loại và tìm quái vật gần nhất
function Utils.ScanMonsters(monstersFolder, hrp)
    local hasAlive = false
    local deadList = {}
    local bestTarget = nil
    local closestDist2D = math.huge

    if monstersFolder then
        for _, m in pairs(monstersFolder:GetChildren()) do
            if m:IsA("Model") or m:IsA("BasePart") then
                local hum = m:FindFirstChildOfClass("Humanoid")
                if hum then
                    if hum.Health <= 0 then
                        table.insert(deadList, m)
                    else
                        hasAlive = true
                        local pos = m:IsA("Model") and m.PrimaryPart and m.PrimaryPart.Position or m.Position
                        local dist2D = math.sqrt((hrp.Position.X - pos.X)^2 + (hrp.Position.Z - pos.Z)^2)
                        if dist2D < closestDist2D then 
                            closestDist2D = dist2D
                            bestTarget = m 
                        end
                    end
                else
                    hasAlive = true
                    local pos = m:IsA("Model") and m.PrimaryPart and m.PrimaryPart.Position or m.Position
                    local dist2D = math.sqrt((hrp.Position.X - pos.X)^2 + (hrp.Position.Z - pos.Z)^2)
                    if dist2D < closestDist2D then 
                        closestDist2D = dist2D
                        bestTarget = m 
                    end
                end
            end
        end
    end

    return hasAlive, deadList, bestTarget, closestDist2D
end

    -- ==========================================
    -- WRAPPER HỖ TRỢ TƯƠNG THÍCH NGƯỢC (SCANMONSTERS)
    -- ==========================================
    function Utils.ScanMonsters(keywords)
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return {} end
        local rawTargets = Utils.SmartScanMonsters(hrp.Position, 999999, "Attack", keywords)
        local targets = {}
        for _, t in ipairs(rawTargets) do
            table.insert(targets, {
                Id = t.Id,
                Name = Utils.ResolveMonsterName(t.Object),
                Position = t.Position,
                RootPart = t.RootPart
            })
        end
        return targets
    end

    -- ==========================================
    -- HÀM LÕI: QUÉT & LỌC QUÁI THÔNG MINH
    -- ==========================================
    function Utils.SmartScanMonsters(centerPos, maxRadius, scanMode, filterFunction)
        -- scanMode: "Attack" (Đánh quái) hoặc "Catch" (Bắt quái)
        local validMonsters = {}
        local playerId = LocalPlayer.UserId
        local foldersToScan = {"ClientMonsters", "Monsters"}
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return validMonsters end

        -- Hỗ trợ contract truyền mảng keywords hoặc filter function trực tiếp
        local finalFilter = filterFunction
        if type(filterFunction) == "table" then
            finalFilter = function(monster)
                local realName = Utils.ResolveMonsterName(monster)
                for _, kw in ipairs(filterFunction) do
                    if string.find(string.lower(realName), string.lower(kw)) then
                        return true
                    end
                end
                return false
            end
        end

        for _, folderName in ipairs(foldersToScan) do
            local monstersFolder = Workspace:FindFirstChild(folderName)
            if monstersFolder then
                for _, monster in pairs(monstersFolder:GetChildren()) do
                    if monster:IsA("Model") or monster:IsA("BasePart") then
                        
                        -- Lọc theo tên UI
                        if finalFilter and not finalFilter(monster) then continue end

                        -- Tìm Root
                        local root = nil
                        if monster:IsA("Model") then
                            root = monster.PrimaryPart or monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChild("Root")
                        elseif monster:IsA("BasePart") then
                            root = monster
                        end
                        if not (root and root:IsA("BasePart")) then continue end

                        -- Đã bắt xong thì bỏ qua
                        if monster:GetAttribute("CatchEndTick") ~= nil or root:GetAttribute("CatchEndTick") ~= nil then 
                            continue 
                        end

                        local isValid = false

                        -- PHÂN NHÁNH LOGIC THEO MODE
                        if scanMode == "Catch" then
                            local catchTaken = monster:GetAttribute("CatchTakenPlayerId")
                            if catchTaken and catchTaken == playerId then isValid = true end
                        else
                            -- Chế độ Attack: Check máu >= 1 (Chống lừa BigNum)
                            local hum_monster = monster:FindFirstChildOfClass("Humanoid")
                            if hum_monster then
                                if hum_monster.Health >= 1 then isValid = true end
                            else
                                local hpVal = monster:FindFirstChild("Health")
                                if hpVal and hpVal:IsA("StringValue") then
                                    local rawStr = hpVal.Value
                                    local tryDec = tonumber((string.gsub(rawStr, ",", ".")))
                                    local hpNum = 0
                                    
                                    if tryDec then hpNum = tryDec
                                    else
                                        local parts = string.split(rawStr, ",")
                                        if #parts == 2 then
                                            local base = tonumber(parts[1])
                                            local exp = tonumber(parts[2])
                                            if base and exp then hpNum = base * (10 ^ exp) end
                                        end
                                    end
                                    if hpNum >= 1 then isValid = true end
                                else
                                    -- Mặc định nếu không tìm thấy thanh máu (đặc biệt là Boss), coi như còn sống
                                    isValid = true
                                end
                            end
                        end

                        -- Nếu thỏa điều kiện -> Đưa vào danh sách
                        if isValid then
                            local distFromCenter = (root.Position - centerPos).Magnitude
                            if distFromCenter <= maxRadius then
                                local idStr = monster.Name:match("Monster_(%d+)")
                                table.insert(validMonsters, {
                                    Object = monster,
                                    Id = idStr and tonumber(idStr) or nil,
                                    Position = root.Position,
                                    RootPart = root,
                                    Distance = (hrp.Position - root.Position).Magnitude
                                })
                            end
                        end
                    end
                end
            end
        end
        return validMonsters
    end

-- ==========================================
-- HÀM KIỂM TRA MÁU QUÁI (HỖ TRỢ BIGNUM & THẬP PHÂN)
-- ==========================================
function Utils.IsMonsterAlive(monsterObj)
    if not monsterObj then return false end
    
    -- 1. Ưu tiên kiểm tra Humanoid (Quái thường)
    local hum = monsterObj:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum.Health >= 1
    end
    
    -- 2. Kiểm tra qua StringValue (Quái máu to / Boss)
    local hpVal = monsterObj:FindFirstChild("Health")
    if hpVal and hpVal:IsA("StringValue") then
        local rawStr = hpVal.Value
        
        -- Thử parse thập phân thường (VD: "0,5" -> "0.5")
        local hpNum = tonumber((string.gsub(rawStr, ",", ".")))
        
        -- Nếu thất bại, giải mã định dạng khoa học/BigNum của game (VD: "9289000,-3")
        if not hpNum then
            local parts = string.split(rawStr, ",")
            if #parts == 2 then 
                local base = tonumber(parts[1]) or 0
                local exp = tonumber(parts[2]) or 0
                hpNum = base * (10 ^ exp)
            end
        end
        
        return (hpNum and hpNum >= 1) or false
    end
    
    -- Mặc định trả về false nếu không tìm thấy thanh máu
    return false
end

-- ==========================================
-- HÀM LẤY REMOTE (CHO CÁC MODULE KHÁC DÙNG)
-- ==========================================
function Utils.GetRemote()
    return GetDataPullFunc()
end

-- ==========================================
-- HÀM LẤY DANH SÁCH AREA
-- ==========================================
function Utils.GetAreaMap()
    return AreaMap
end

-- ==========================================
-- HÀM DỊCH CHUYỂN ĐẾN AREA THEO ID (ALIAS)
-- ==========================================
Utils.Teleport = Utils.TeleportToArea
Utils.TeleportTo = Utils.TeleportToArea

-- ==========================================
-- KHỞI TẠO: Kiểm tra remote khi load
-- ==========================================
task.spawn(function()
    local remote = GetDataPullFunc()
    if remote then
        print("[Utils] ✅ DataPullFunc đã sẵn sàng")
    else
        warn("[Utils] ⚠️ DataPullFunc chưa sẵn sàng, sẽ thử lại sau")
    end
end)
-- ==========================================
-- HỆ THỐNG DROPDOWN ĐA CHỌN KHU VỰC (DÙNG CHUNG)
-- ==========================================

-- BẢNG KHU VỰC MỞ RỘNG (Có thể thêm tùy ý)
local AreaData = {
    {id = 1, name = "Starter Island", category = "Cơ Bản"},
    {id = 2, name = "Volcano", category = "Săn Boss"},
    {id = 3, name = "Frost Isle", category = "Săn Boss"},
    {id = 4, name = "Neverland", category = "Săn Boss"},
    {id = 5, name = "Duneveil Isle", category = "Săn Boss"},
    {id = 6, name = "Tideland", category = "Săn Boss"},
    {id = 7, name = "Spirit Grove", category = "Săn Boss"},
    {id = 8, name = "Dragon's Breath", category = "Săn Boss"},
    {id = 9, name = "Blossom Haven", category = "Săn Boss"},
    {id = 10, name = "Mobius Circus", category = "Săn Boss"},
    {id = 11, name = "Specter Shallows", category = "Săn Boss"},
    {id = 12, name = "Nova Coast", category = "Săn Boss"}
}
-- ==========================================
-- 1.5 TẠO DROPDOWN ĐA CHỌN (BẢN LỌC - VERSION 2)
-- ==========================================
function Utils.CreateFilteredAreaMultiSelect(tab, config)
    config = config or {}
    local allowedIds = config.allowedIds or {}
    
    local options = {}
    local nameToIdMap = {}
    
    -- Lọc AreaData chỉ lấy những đảo có ID nằm trong allowedIds
    for _, area in ipairs(AreaData) do
        for _, allowedId in ipairs(allowedIds) do
            if area.id == allowedId then
                table.insert(options, area.name)
                nameToIdMap[area.name] = area.id
                break
            end
        end
    end
    
    local defaultOptions = {}
    if config.defaultAreas and #config.defaultAreas > 0 then
        for _, areaName in ipairs(config.defaultAreas) do
            if nameToIdMap[areaName] then
                table.insert(defaultOptions, areaName)
            end
        end
    end
    
    local dropdown = tab:CreateDropdown({
        Name = config.name or "Chọn Khu Vực",
        Options = options,
        CurrentOption = defaultOptions,
        MultipleOptions = true,
        Flag = config.flag or "AreaMultiSelectFiltered",
        Callback = function(selectedOptions)
            if config.callback then
                local selectedIds = {}
                -- Trả về trực tiếp mảng ID cho script xử lý
                for _, areaName in ipairs(selectedOptions) do
                    if nameToIdMap[areaName] then
                        table.insert(selectedIds, nameToIdMap[areaName])
                    end
                end
                config.callback(selectedIds, selectedOptions)
            end
        end
    })
    
    return dropdown
end
-- ==========================================
-- 1. TẠO DROPDOWN ĐA CHỌN KHU VỰC
-- ==========================================
function Utils.CreateAreaMultiSelect(tab, config)
    config = config or {}
    
    local options = {}
    for _, area in ipairs(AreaData) do
        table.insert(options, area.name)
    end
    
    local defaultOptions = {}
    if config.defaultAreas and #config.defaultAreas > 0 then
        for _, areaName in ipairs(config.defaultAreas) do
            for _, area in ipairs(AreaData) do
                if area.name == areaName then
                    table.insert(defaultOptions, areaName)
                    break
                end
            end
        end
    end
    
    -- Nếu không có default thì lấy tất cả
    if #defaultOptions == 0 then
        defaultOptions = options
    end
    
    local dropdown = tab:CreateDropdown({
        Name = config.name or "Chọn Khu Vực",
        Options = options,
        CurrentOption = defaultOptions,
        MultipleOptions = true,
        Flag = config.flag or "AreaMultiSelect",
        Callback = function(selectedOptions)
            if config.callback then
                -- Chuyển đổi tên → ID
                local selectedIds = {}
                for _, areaName in ipairs(selectedOptions) do
                    for _, area in ipairs(AreaData) do
                        if area.name == areaName then
                            table.insert(selectedIds, area.id)
                            break
                        end
                    end
                end
                config.callback(selectedIds, selectedOptions)
            end
        end
    })
    
    return dropdown
end

-- ==========================================
-- 2. LẤY DANH SÁCH ID TỪ TÊN KHU VỰC
-- ==========================================
function Utils.GetAreaIdsByNames(areaNames)
    local ids = {}
    for _, areaName in ipairs(areaNames) do
        for _, area in ipairs(AreaData) do
            if area.name == areaName then
                table.insert(ids, area.id)
                break
            end
        end
    end
    return ids
end

-- ==========================================
-- 3. LẤY DANH SÁCH TÊN TỪ ID KHU VỰC
-- ==========================================
function Utils.GetAreaNamesByIds(areaIds)
    local names = {}
    for _, areaId in ipairs(areaIds) do
        for _, area in ipairs(AreaData) do
            if area.id == areaId then
                table.insert(names, area.name)
                break
            end
        end
    end
    return names
end

-- ==========================================
-- 4. LẤY DANH SÁCH TẤT CẢ KHU VỰC (CÓ CATEGORY)
-- ==========================================
function Utils.GetAllAreas()
    return AreaData
end

-- ==========================================
-- 5. LẤY DANH SÁCH KHU VỰC THEO CATEGORY
-- ==========================================
function Utils.GetAreasByCategory(category)
    local result = {}
    for _, area in ipairs(AreaData) do
        if area.category == category then
            table.insert(result, area)
        end
    end
    return result
end

-- ==========================================
-- 6. DỊCH CHUYỂN ĐẾN NHIỀU KHU VỰC TUẦN TỰ
-- ==========================================
function Utils.TeleportToAreasSequential(areaIds, delayBetween)
    delayBetween = delayBetween or 3
    local remote = GetDataPullFunc()
    if not remote then
        warn("[Utils] ❌ Không tìm thấy DataPullFunc")
        return false
    end
    
    task.spawn(function()
        for _, areaId in ipairs(areaIds) do
            local success = Utils.TeleportToArea(areaId)
            if success then
                local areaName = AreaMap[areaId] or "Unknown"
                print("[Utils] 🚀 Đã đến: " .. areaName)
                task.wait(delayBetween)
            else
                warn("[Utils] ❌ Dịch chuyển đến area " .. areaId .. " thất bại")
            end
        end
    end)
    
    return true
end

-- ==========================================
-- 7. TẠO TOGGLE "AUTO DỊCH CHUYỂN KHU VỰC"
-- ==========================================
function Utils.CreateAreaAutoTeleport(tab, config)
    config = config or {}
    
    local sectionName = config.sectionName or "--- AUTO DỊCH CHUYỂN KHU VỰC ---"
    tab:CreateSection(sectionName)
    
    local areaDropdown = Utils.CreateAreaMultiSelect(tab, {
        name = config.dropdownName or "Chọn Khu Vực Cần Dịch Chuyển",
        flag = config.dropdownFlag or "AreaAutoTeleportSelect",
        defaultAreas = config.defaultAreas or {},
        callback = function(selectedIds, selectedNames)
            if config.onAreaSelect then
                config.onAreaSelect(selectedIds, selectedNames)
            end
        end
    })
    
    local isEnabled = false
    
    local toggle = tab:CreateToggle({
        Name = config.toggleName or "Tự Động Dịch Chuyển Đến Các Khu Vực",
        CurrentValue = false,
        Flag = config.toggleFlag or "AreaAutoTeleportToggle",
        Callback = function(Value)
            isEnabled = Value
            if config.onToggle then
                config.onToggle(Value)
            end
            
            if Value then
                -- Lấy danh sách area đang chọn
                local currentOptions = areaDropdown.CurrentOption or {}
                local areaIds = Utils.GetAreaIdsByNames(currentOptions)
                
                if #areaIds == 0 then
                    game.StarterGui:SetCore("SendNotification", {
                        Title = "⚠️ Lỗi", 
                        Text = "Vui lòng chọn ít nhất 1 khu vực!",
                        Duration = 3
                    })
                    return
                end
                
                if config.onStart then
                    config.onStart(areaIds)
                end
            else
                if config.onStop then
                    config.onStop()
                end
            end
        end
    })
    
    -- Hàm để lấy trạng thái
    local function getStatus()
        return isEnabled
    end
    
    -- Hàm để lấy danh sách area đang chọn
    local function getSelectedAreas()
        return Utils.GetAreaIdsByNames(areaDropdown.CurrentOption or {})
    end
    
    return {
        dropdown = areaDropdown,
        toggle = toggle,
        isEnabled = getStatus,
        getSelectedAreas = getSelectedAreas,
        setAreas = function(areaNames)
            areaDropdown:SetCurrentOption(areaNames)
        end
    }
end

-- ==========================================
-- 8. HÀM LẤY DANH SÁCH KHU VỰC DẠNG OPTION
-- ==========================================
function Utils.GetAreaOptions()
    local options = {}
    for _, area in ipairs(AreaData) do
        table.insert(options, area.name)
    end
    return options
end

-- ==========================================
-- 9. THÊM KHU VỰC MỚI VÀO HỆ THỐNG
-- ==========================================
function Utils.AddArea(id, name, category)
    category = category or "Khác"
    table.insert(AreaData, {id = id, name = name, category = category})
    AreaMap[id] = name
    print("[Utils] ✅ Đã thêm khu vực: " .. name .. " (ID: " .. id .. ")")
end

-- ==========================================
-- 10. DỊCH CHUYỂN ĐẾN KHU VỰC NGẪU NHIÊN TRONG DANH SÁCH
-- ==========================================
function Utils.TeleportToRandomArea(areaIds)
    if not areaIds or #areaIds == 0 then
        areaIds = {}
        for _, area in ipairs(AreaData) do
            table.insert(areaIds, area.id)
        end
    end
    
    local randomId = areaIds[math.random(1, #areaIds)]
    return Utils.TeleportToArea(randomId)
end

-- ==========================================
-- 11. LƯU DANH SÁCH KHU VỰC ĐÃ CHỌN
-- ==========================================
function Utils.SaveSelectedAreas(selectedIds, fileName)
    fileName = fileName or "R_SelectedAreas.json"
    local HttpService = game:GetService("HttpService")
    
    pcall(function()
        if writefile then
            writefile(fileName, HttpService:JSONEncode(selectedIds))
        end
    end)
end

-- ==========================================
-- 12. ĐỌC DANH SÁCH KHU VỰC ĐÃ CHỌN
-- ==========================================
function Utils.LoadSelectedAreas(fileName)
    fileName = fileName or "R_SelectedAreas.json"
    
    pcall(function()
        if isfile and isfile(fileName) then
            local data = HttpService:JSONDecode(readfile(fileName))
            if type(data) == "table" then
                return data
            end
        end
    end)
    return {}
end

-- ==========================================
-- HÀM MỞ RỘNG CHO UTILITIES
-- ==========================================

-- 1. Lưu/Đọc JSON an toàn
function Utils.SaveJSON(fileName, data)
    pcall(function() if writefile then writefile(fileName, HttpService:JSONEncode(data)) end end)
end

function Utils.LoadJSON(fileName)
    if isfile and isfile(fileName) then
        local success, data = pcall(function() return HttpService:JSONDecode(readfile(fileName)) end)
        return success and data or {}
    end
    return {}
end

-- 2. Hệ thống Boss Scanner Core (Sử dụng logic của Test Script 34)
function Utils.ScanBossByKeywords(keywords)
    local env = getrenv()._G.PathTool
    if not env or not env.MgrMonsterClient or not env.CfgMonster then return nil end
    
    local clientMonsters = Workspace:FindFirstChild("ClientMonsters")
    if not clientMonsters then return nil end

    for _, obj in pairs(clientMonsters:GetChildren()) do
        local idStr = string.match(obj.Name, "Monster_(%d+)")
        if idStr then
            local uid = tonumber(idStr)
            local success, info = pcall(function() return env.MgrMonsterClient:GetMonsterInfo(uid) end)
            if success and info then
                local tmplId = info.tmplId or info.TmplId or info.id
                local cfgData = env.CfgMonster.Tmpls[tostring(tmplId)] or env.CfgMonster.Tmpls[tonumber(tmplId)]
                if cfgData then
                    local realName = (cfgData.Name or ""):lower()
                    for _, kw in pairs(keywords) do
                        if realName:find(kw:lower()) then
                            local root = nil
                            if obj:IsA("Model") then
                                root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                            elseif obj:IsA("BasePart") then
                                root = obj
                            end
                            return {name = realName, pos = root and root.Position or obj.Position, uid = uid}
                        end
                    end
                end
            end
        end
    end
    return nil
end
-- Kiểm tra thời tiết hiện tại
function Utils.GetCurrentWeather(weatherMap)
    local env = getrenv()._G.PathTool
    if env and env.WeatherSystem and type(env.WeatherSystem.IsWeatherActive) == "function" then
        for name, id in pairs(weatherMap) do
            local ok, isActive = pcall(function() return env.WeatherSystem.IsWeatherActive(id) end)
            if ok and isActive then return name, id end
        end
    end
    return "Bình Thường", 0
end
-- ====================================================================
-- HÀM SERVER HOP (VERSION 2 - ĐÃ NÂNG CẤP LƯU BLACKLIST BẰNG JSON)
-- ====================================================================
function Utils.HopServerV2(reason)
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlaceId = game.PlaceId

    print("[Hop] 🔄 Bắt đầu tiến trình Hop V2. Lý do: " .. tostring(reason))

    -- Đọc Blacklist trực tiếp từ File JSON
    local blacklistedServers = Utils.LoadJSON("RClient_HopBlacklist.json")
    if type(blacklistedServers) ~= "table" then blacklistedServers = {} end

    pcall(function()
        local api = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local data = game:HttpGet(api)
        local json = HttpService:JSONDecode(data)
        
        if json and json.data then
            local validServers = {}
            for _, v in pairs(json.data) do
                -- Kiểm tra Blacklist
                local isBlacklisted = false
                for _, blackId in ipairs(blacklistedServers) do
                    if v.id == blackId then isBlacklisted = true break end
                end

                -- Điều kiện lọc: Không phải server hiện tại, không trong blacklist, server chưa đầy
                if v.id and v.id ~= game.JobId and not isBlacklisted then
                    local playing = v.playing or 0
                    local maxPlayers = v.maxPlayers or 0
                    if playing < maxPlayers then
                        table.insert(validServers, {id = v.id, playing = playing})
                    end
                end
            end
            
            if #validServers > 0 then
                -- Ưu tiên server vắng nhất
                table.sort(validServers, function(a, b) return a.playing < b.playing end)
                
                local targetId = validServers[1].id
                
                -- Thêm vào Blacklist và Lưu lại bằng JSON ngay lập tức
                table.insert(blacklistedServers, targetId)
                
                -- Giới hạn danh sách đen ở 50 server gần nhất để tránh phình to file
                if #blacklistedServers > 50 then table.remove(blacklistedServers, 1) end
                Utils.SaveJSON("RClient_HopBlacklist.json", blacklistedServers)
                
                print("[Hop V2] ✅ Chọn được server: " .. tostring(targetId) .. ". Đang Teleport...")
                
                -- Thông báo cho người dùng
                game.StarterGui:SetCore("SendNotification", {
                    Title = "🚀 Server Hop V2", 
                    Text = "Đang chuyển: " .. reason,
                    Duration = 3
                })
                
                TeleportService:TeleportToPlaceInstance(PlaceId, targetId, LocalPlayer)
            else
                warn("[Hop V2] ⚠️ Không tìm thấy server hợp lệ! Tiến hành Reset Blacklist.")
                -- Xóa trắng file JSON nếu hết server để nhảy
                Utils.SaveJSON("RClient_HopBlacklist.json", {}) 
                
                -- Thử nhảy bừa 1 server để thoát kẹt
                TeleportService:Teleport(PlaceId, LocalPlayer)
            end
        end
    end)
end

-- ==========================================
-- HÀM SERVER HOP (CÓ DANH SÁCH ĐEN - BLACKLIST)
-- ==========================================
function Utils.HopServer(notificationMsg)
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlaceId = game.PlaceId

    -- Lấy danh sách Blacklist từ biến global hoặc file cache nếu có
    -- Giả sử ta lưu trong _G.BlacklistedServers để dễ truy xuất
    _G.BlacklistedServers = _G.BlacklistedServers or {}

    if notificationMsg then
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "🚀 Auto Server Hop", 
                Text = notificationMsg,
                Duration = 5
            })
        end)
    end

    pcall(function()
        local api = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local data = game:HttpGet(api)
        local json = HttpService:JSONDecode(data)
        
        if json and json.data then
            local validServers = {}
            for _, v in pairs(json.data) do
                -- Lọc: Không phải server hiện tại VÀ không nằm trong danh sách đen
                local isBlacklisted = false
                for _, blackId in ipairs(_G.BlacklistedServers) do
                    if v.id == blackId then isBlacklisted = true break end
                end

                if v.id and v.id ~= game.JobId and not isBlacklisted then
                    local playing = v.playing or 0
                    local maxPlayers = v.maxPlayers or 0
                    if playing < maxPlayers then
                        table.insert(validServers, {id = v.id, playing = playing})
                    end
                end
            end
            
            if #validServers > 0 then
                -- Sắp xếp: Ưu tiên server vắng nhất
                table.sort(validServers, function(a, b) return a.playing < b.playing end)
                
                local targetId = validServers[1].id
                
                -- Thêm vào danh sách đen trước khi nhảy
                table.insert(_G.BlacklistedServers, targetId)
                
                print("[Utils] 🔄 Đang nhảy sang Server: " .. tostring(targetId) .. " (Đã thêm vào Blacklist)")
                TeleportService:TeleportToPlaceInstance(PlaceId, targetId, LocalPlayer)
            else
                -- Nếu danh sách đen khiến không tìm được server nào -> Reset danh sách đen
                warn("[Utils] ⚠️ Tất cả server đã được quét! Reset Blacklist...")
                _G.BlacklistedServers = {} 
            end
        end
    end)
end
-- ====================================================================
-- HÀM SERVER HOP (VERSION 3.0 - DÀNH CHO HỆ THỐNG QUEUE)
-- ====================================================================
function Utils.HopServer(reason)
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlaceId = game.PlaceId

    print("[Hop] 🔄 Bắt đầu tiến trình Hop. Lý do: " .. tostring(reason))

    -- Khởi tạo hoặc lấy Blacklist từ Global
    _G.BlacklistedServers = _G.BlacklistedServers or {}

    pcall(function()
        local api = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local data = game:HttpGet(api)
        local json = HttpService:JSONDecode(data)
        
        if json and json.data then
            local validServers = {}
            for _, v in pairs(json.data) do
                -- Kiểm tra Blacklist
                local isBlacklisted = false
                for _, blackId in ipairs(_G.BlacklistedServers) do
                    if v.id == blackId then isBlacklisted = true break end
                end

                -- Điều kiện lọc: Không phải server hiện tại, không trong blacklist, server chưa đầy
                if v.id and v.id ~= game.JobId and not isBlacklisted then
                    local playing = v.playing or 0
                    local maxPlayers = v.maxPlayers or 0
                    if playing < maxPlayers then
                        table.insert(validServers, {id = v.id, playing = playing})
                    end
                end
            end
            
            if #validServers > 0 then
                -- Ưu tiên server vắng nhất
                table.sort(validServers, function(a, b) return a.playing < b.playing end)
                
                local targetId = validServers[1].id
                
                -- Thêm vào Blacklist
                table.insert(_G.BlacklistedServers, targetId)
                
                print("[Hop] ✅ Chọn được server: " .. tostring(targetId) .. ". Đang Teleport...")
                
                -- Thông báo cho người dùng
                game.StarterGui:SetCore("SendNotification", {
                    Title = "🚀 Server Hop", 
                    Text = "Đang chuyển: " .. reason,
                    Duration = 3
                })
                
                TeleportService:TeleportToPlaceInstance(PlaceId, targetId, LocalPlayer)
            else
                warn("[Hop] ⚠️ Không tìm thấy server hợp lệ! Reset Blacklist.")
                _G.BlacklistedServers = {} -- Tự phục hồi
            end
        end
    end)
end

local InternalMonsterTable = nil

-- Khởi tạo đường hầm đọc RAM (Chỉ chạy 1 lần cho nhẹ máy)
function Utils.InitMonsterMemory()
    if InternalMonsterTable then return end
    pcall(function()
        local env = getrenv and getrenv()._G and getrenv()._G.PathTool
        if env and env.MgrMonsterClient then
            local upvalues = debug.getupvalues(env.MgrMonsterClient.GetMonsterInfo)
            if upvalues and type(upvalues[1]) == "table" then
                InternalMonsterTable = upvalues[1]
            end
        end
    end)
end


-- Fallback dịch thuật nếu không load được core/localization.txt
function Utils.t(key)
    return key
end

function Utils.getLang()
    return "en"
end

-- Trả về bảng Utils
return Utils

end

modules['core/system_controller.txt'] = function(...)
-- ====================================================================
-- MODULE: SYSTEM CONTROLLER (QUẢN LÝ TRẠNG THÁI & HÀNG ĐỢI - CHUẨN)
-- ====================================================================
local UserInputService = game:GetService("UserInputService")

local SystemController = {
    IsPaused = false,
    ActiveTask = nil, -- Mutex Lock: "None", "AutoFarm", "Dungeon", v.v.
    TaskQueue = {},   -- Hàng đợi chức năng
    SavedState = {}   -- Lưu trạng thái để Resume
}
-- Thêm vào bảng SystemController
SystemController.Modules = {} -- Danh sách các module đã đăng ký

-- Hàm để các module "đăng ký" vào danh sách theo dõi
function SystemController:registerModule(name, pauseFunc)
    self.Modules[name] = pauseFunc
end
-- [QUAN TRỌNG NHẤT]: Ép ngay nó vào _G để các file khác gọi không bị lỗi nil
_G.SystemController = SystemController 

-- [1] HỆ THỐNG HOTKEY (CHỈ PAUSE - PANIC BUTTON)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.P then -- Phím P để ép dừng khẩn cấp
        -- 1. Chốt cứng trạng thái hệ thống là đang Dừng
        SystemController.IsPaused = true
        
        -- 2. Gửi lệnh TẮT (truyền false) đến tất cả các module đang chạy
        for name, pauseFunc in pairs(SystemController.Modules) do
            pcall(function() pauseFunc(false) end)
        end
        
        -- 3. Lưu lại trạng thái của _G.Config (nếu bạn vẫn dùng hệ thống cũ này)
        _G.Config = _G.Config or {}
        print("[System] 🛑 PANIC BUTTON - Đang ép dừng và lưu trạng thái...")
        SystemController.SavedState.AutoFarm = _G.Config.AutoFarm or false
        SystemController.SavedState.BossHunt = _G.Config.BossHunt or false
        
        -- 4. Tắt biến cấu hình
        _G.Config.AutoFarm = false
        _G.Config.BossHunt = false
        
        -- 5. Thông báo ra màn hình
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "PANIC BUTTON", 
                Text = "🛑 Đã ÉP DỪNG mọi hoạt động!", 
                Duration = 3
            })
        end)
    end
end)

-- [2] HỆ THỐNG MUTEX LOCK (CẤP PHÉP CHẠY)
function SystemController.RequestLock(taskName)
    if SystemController.IsPaused then return false end
    
    if SystemController.ActiveTask == nil or SystemController.ActiveTask == taskName then
        SystemController.ActiveTask = taskName
        return true
    end
    return false -- Đang có Task khác chạy, bị từ chối
end

function SystemController.ReleaseLock(taskName)
    if SystemController.ActiveTask == taskName then
        SystemController.ActiveTask = nil
    end
end

-- [3] EVENT LOOP XỬ LÝ HÀNG ĐỢI (FIFO)
task.spawn(function()
    while task.wait(0.1) do
        if SystemController.IsPaused then continue end
        
        -- Nếu hệ thống đang rảnh và có Job trong hàng đợi
        if SystemController.ActiveTask == nil and #SystemController.TaskQueue > 0 then
            -- Rút Job đầu tiên ra (Dequeue)
            local nextTask = table.remove(SystemController.TaskQueue, 1)
            
            print("[Queue] 🚀 Đang thực thi: " .. nextTask.Name)
            SystemController.ActiveTask = nextTask.Name
            
            -- Chạy chức năng (bọc trong pcall để không chết luồng)
            task.spawn(function()
                local success, err = pcall(nextTask.Func)
                
                if not success then
                    warn("[Queue] ❌ Lỗi khi chạy " .. nextTask.Name .. ": " .. tostring(err))
                end
                
                -- BẤT KỂ LỖI HAY KHÔNG, VẪN PHẢI TRẢ LẠI LOCK CHO HỆ THỐNG
                SystemController.ReleaseLock(nextTask.Name)
                print("[Queue] ✅ Đã giải phóng Lock cho: " .. nextTask.Name)
            end)
        end
    end
end)
-- ====================================================================
-- TƯƠNG THÍCH NGƯỢC: Ánh xạ giữa ActiveTask và CurrentLock
-- ====================================================================
setmetatable(SystemController, {
    __index = function(t, k)
        if k == "CurrentLock" then
            return rawget(t, "ActiveTask")
        end
        return nil
    end,
    __newindex = function(t, k, v)
        if k == "CurrentLock" then
            rawset(t, "ActiveTask", v)
        else
            rawset(t, k, v)
        end
    end
})

return SystemController

end

modules['core/webhook.txt'] = function(...)
-- ====================================================================
-- MODULE: WEBHOOK & THÔNG BÁO DISCORD
-- ====================================================================
local WebhookModule = {}

local HttpService = game:GetService("HttpService")
local currentWebhookURL = ""
local webhookEnabled = false

WebhookModule.Utils = nil

-- 1. HÀM GỬI THÔNG BÁO (Để các file khác gọi lại)
function WebhookModule.SendNotification(message)
    if not webhookEnabled or currentWebhookURL == "" or not string.find(currentWebhookURL, "api/webhooks") then 
        return 
    end

    local req = (syn and syn.request) or (http and http.request) or http_request or fluxus and fluxus.request or request
    
    if req then
        local tFunc = function(k)
            if WebhookModule.Utils and WebhookModule.Utils.t then
                return WebhookModule.Utils.t(k)
            end
            local fallbacks = {
                webhook_notification_title = "🎉 Update Auto-Farm"
            }
            return fallbacks[k] or k
        end

        local data = {
            ["content"] = "",
            ["embeds"] = {
                {
                    ["title"] = tFunc("webhook_notification_title"),
                    ["description"] = message,
                    ["type"] = "rich",
                    ["color"] = tonumber(0x00FF00),
                    ["timestamp"] = DateTime.now():ToIsoDate()
                }
            }
        }
        
        req({ 
            Url = currentWebhookURL, 
            Method = "POST", 
            Headers = { ["Content-Type"] = "application/json" }, 
            Body = HttpService:JSONEncode(data) 
        })
    end
end

-- 2. HÀM TẠO GIAO DIỆN (Được gọi từ main.txt)
function WebhookModule.InitTab(Window, Rayfield, Utils)
    WebhookModule.Utils = Utils
    
    local tFunc = function(k)
        if Utils and Utils.t then
            return Utils.t(k)
        end
        local fallbacks = {
            webhook = "Webhook",
            sec_webhook_settings = "THIẾT LẬP DISCORD WEBHOOK",
            webhook_toggle = "Bật/Tắt Thông Báo Discord",
            webhook_url = "Link Discord Webhook",
            webhook_url_placeholder = "Dán link Webhook của bạn vào đây...",
            webhook_btn_test = "Gửi Thông Báo Test (Kiểm tra)",
            error_title = "Lỗi",
            webhook_invalid_msg = "Link Webhook không hợp lệ!",
            success_title = "Thành công",
            webhook_test_sent_msg = "Đã gửi thông báo test qua Discord!",
            webhook_test_payload = "🛠️ Test Webhook thành công! Hệ thống R-Client Pro đang hoạt động tốt."
        }
        return fallbacks[k] or k
    end

    local WebhookTab = Window:CreateTab(tFunc("webhook"), "bell")

    WebhookTab:CreateSection(" " .. tFunc("sec_webhook_settings") .. " ")

    WebhookTab:CreateToggle({
        Name = tFunc("webhook_toggle"),
        CurrentValue = false,
        Flag = "WebhookToggleConfig",
        Callback = function(Value)
            webhookEnabled = Value
        end,
    })

    WebhookTab:CreateInput({
        Name = tFunc("webhook_url"),
        PlaceholderText = tFunc("webhook_url_placeholder"),
        RemoveTextAfterFocusLost = false,
        Flag = "WebhookUrlConfig",
        Callback = function(Text)
            currentWebhookURL = Text
        end,
    })

    WebhookTab:CreateButton({
        Name = tFunc("webhook_btn_test"),
        Callback = function()
            if currentWebhookURL == "" or not string.find(currentWebhookURL, "api/webhooks") then
                Rayfield:Notify({Title = tFunc("error_title"), Content = tFunc("webhook_invalid_msg"), Duration = 3})
            else
                WebhookModule.SendNotification(tFunc("webhook_test_payload"))
                Rayfield:Notify({Title = tFunc("success_title"), Content = tFunc("webhook_test_sent_msg"), Duration = 3})
            end
        end,
    })
end

return WebhookModule
end

modules['core/localization.txt'] = function(...)
-- ====================================================================
-- MODULE: LOCALIZATION SYSTEM (HỆ THỐNG ĐA NGÔN NGỮ)
-- ====================================================================
local Localization = {}

local Translations = {
    -- Auto Hatch keys
    ["autohatch"] = { en = "Auto Hatch", vi = "Ấp Trứng" },
    ["unlocked_slots"] = { en = "Unlocked Slots", vi = "Số Lò Ấp Mở Khóa" },
    ["unlocked_slots_info"] = { en = "Set the number of incubator slots you have unlocked in-game.", vi = "Chọn số lượng lò ấp bạn đã mở khóa trong game để phân bổ." },
    ["select_eggs"] = { en = "Select Eggs", vi = "Chọn Loại Trứng" },
    ["select_eggs_info"] = { en = "Choose one or multiple types of eggs to hatch.", vi = "Chọn một hoặc nhiều loại trứng để tự động ấp." },
    ["refresh_eggs"] = { en = "🔄 Refresh Egg List", vi = "🔄 Làm Mới Danh Sách" },
    ["refresh_eggs_info"] = { en = "Reloads egg templates from the game config files.", vi = "Tải lại danh sách cấu hình trứng từ game." },
    ["auto_start"] = { en = "Auto Start Hatching", vi = "Tự Động Bỏ Trứng" },
    ["auto_start_info"] = { en = "Automatically drops selected eggs into empty incubator slots.", vi = "Tự động cho trứng đã chọn vào lò khi phát hiện lò trống." },
    ["auto_claim"] = { en = "Auto Claim Pets", vi = "Tự Động Thu Hoạch" },
    ["auto_claim_info"] = { en = "Automatically claims hatched pets once incubation finishes.", vi = "Tự động nhận pet sau khi ấp xong." },
    ["stop_if_full"] = { en = "Stop If Bag Full", vi = "Dừng Khi Túi Đầy" },
    ["stop_if_full_info"] = { en = "Automatically stops hatching when your pet inventory is full to prevent lost pets.", vi = "Tự động dừng ấp khi túi pet đầy để bảo vệ pet." },
    ["bag_status"] = { en = "Pet Bag: ", vi = "Túi Pet: " },
    ["bag_loading"] = { en = "Pet Bag: Loading...", vi = "Túi Pet: Đang tải..." },
    ["bag_full_warning"] = { en = "Pet bag is FULL! Auto hatching disabled.", vi = "Túi Pet ĐẦY! Đã tự động ngắt Auto." },
    ["warning_title"] = { en = "WARNING", vi = "CẢNH BÁO" },
    ["egg_fallback_name"] = { en = "Egg ", vi = "Trứng " },
    ["refresh_warning_name"] = { en = "⚠️ Click Refresh to load list!", vi = "⚠️ Bấm Refresh để tải danh sách!" },

    -- Optimization keys
    ["optimization"] = { en = "Optimization", vi = "Tối Ưu Hóa" },
    ["anti_afk"] = { en = "Anti AFK", vi = "Chống AFK" },
    ["anti_afk_info"] = { en = "Prevents you from being kicked for idling.", vi = "Ngăn bạn bị văng game do treo máy lâu." },
    ["potato_mode"] = { en = "Potato Mode (Real-time)", vi = "Chế Độ Potato (Thời gian thực)" },
    ["potato_mode_info"] = { en = "Real-time graphics optimization (smooth plastic, disable textures/particles/decals).", vi = "Tối ưu hóa đồ họa thời gian thực (nhựa trơn, tự động ẩn vân bề mặt/hiệu ứng hạt)." },
    ["potato_active"] = { en = "Potato Mode activated.", vi = "Đã kích hoạt Potato Mode thành công." },
    ["clean_vfx"] = { en = "Clean VFX & Debris", vi = "Dọn Hiệu Ứng VFX & Rác" },
    ["clean_vfx_info"] = { en = "Dynamically removes combat trails, beams, particles, and damage texts to reduce GPU load.", vi = "Tự động xóa các vệt chém, tia sáng, khói bụi chiến đấu và chữ hiện sát thương để nhẹ card GPU." },
    ["auto_gc"] = { en = "Auto RAM Purge (5m)", vi = "Tự Dọn Bộ Nhớ RAM (5p)" },
    ["auto_gc_info"] = { en = "Periodically purges Lua memory every 5 minutes to prevent client memory leaks and crashes.", vi = "Định kỳ dọn dẹp bộ nhớ đệm Lua mỗi 5 phút để tránh tràn RAM, văng game khi treo lâu." },
    ["limit_fps"] = { en = "Limit 15 FPS", vi = "Giới Hạn 15 FPS" },
    ["limit_fps_info"] = { en = "Caps frame rate at 15 FPS to reduce CPU/GPU usage when background farming.", vi = "Giới hạn FPS ở mức 15 để tiết kiệm CPU/GPU khi treo máy ngầm." },
    ["disable_3d"] = { en = "Disable 3D Rendering", vi = "Tắt Render 3D" },
    ["disable_3d_info"] = { en = "Blacks out screen and disables 3D graphics rendering to save maximum computer resources.", vi = "Tắt dựng hình 3D (đen màn hình) để tiết kiệm tối đa tài nguyên máy." },
    
    -- Streamer mode keys
    ["streamer_section"] = { en = "STREAMER MODE", vi = "CHẾ ĐỘ STREAMER" },
    ["fake_name"] = { en = "Fake Display Name", vi = "Tên Hiển Thị Giả" },
    ["fake_name_placeholder"] = { en = "Enter fake name...", vi = "Nhập tên giả..." },
    ["fake_name_info"] = { en = "Set a custom fake name to display on your character.", vi = "Nhập tên giả để ngụy trang hiển thị trên nhân vật." },
    ["streamer_mode"] = { en = "Streamer Mode (Rename)", vi = "Bật Chế Độ Ẩn Danh" },
    ["streamer_mode_info"] = { en = "Spoofs your name tags and character display name to match the fake name above.", vi = "Thay đổi nhãn tên nhân vật thành tên giả đã nhập." },

    -- Shops & GUIs keys
    ["gui"] = { en = "Shops & GUIs", vi = "Cửa Hàng & Giao Diện" },
    ["gui_open_title"] = { en = "Open UI", vi = "Mở Giao Diện" },
    ["gui_open_success"] = { en = "Opened view: ", vi = "Đã thực thi mở: " },
    ["gui_open_fail"] = { en = "Failed to open view: ", vi = "Không thể mở: " },
    ["open_view_info"] = { en = "Bypasses distance check to open this interface remotely.", vi = "Mở nhanh giao diện này từ xa, bỏ qua khoảng cách." },
    
    ["sec_tele_maps"] = { en = "🗺️ TELEPORT & MAPS", vi = "🗺️ DỊCH CHUYỂN & BẢN ĐỒ" },
    ["sec_bags"] = { en = "BAGS & INVENTORIES", vi = "TÚI ĐỒ & QUẢN LÝ" },
    ["sec_shops"] = { en = "GAME SHOPS", vi = "CỬA HÀNG (SHOPS)" },
    ["sec_events"] = { en = "ACTIVITIES & EVENTS", vi = "HOẠT ĐỘNG & SỰ KIỆN" },
    ["sec_recycle"] = { en = "PET STORAGE & RECYCLING", vi = "KHO TÀNG & TÁI CHẾ PET" },
    
    ["btn_area_tele"] = { en = "📍 Area Teleport", vi = "📍 Dịch Chuyển Tức Thời" },
    ["btn_item_bag"] = { en = "🎒 Item Bag", vi = "🎒 Mở Túi Đồ" },
    ["btn_pet_bag"] = { en = "🐶 Pet Bag", vi = "🐶 Mở Túi Pet" },
    ["btn_pet_team"] = { en = "🐾 Pet Team", vi = "🐾 Đội Hình Pet" },
    ["btn_pet_enhance"] = { en = "✨ Pet Enhance", vi = "✨ Nâng Cấp Pet" },
    ["btn_store"] = { en = "🛒 Main Store", vi = "🛒 Cửa Hàng Chính" },
    ["btn_catcher_shop"] = { en = "🎣 Catcher Shop", vi = "🎣 Cửa Hàng Bắt Thú" },
    ["btn_tower_shop"] = { en = "🗼 Tower Shop", vi = "🗼 Cửa Hàng Tháp" },
    ["btn_craft"] = { en = "⚒️ Crafting Bench", vi = "⚒️ Xưởng Chế Tạo" },
    ["btn_abyss_shop"] = { en = "🌌 Abyss Shop", vi = "🌌 Cửa Hàng Vực Thẳm" },
    ["btn_pet_gear_roll"] = { en = "⚙️ Pet Gear Roll", vi = "⚙️ Cửa Hàng Trang Bị Pet" },
    ["btn_tasks"] = { en = "📋 Tasks Board", vi = "📋 Bảng Nhiệm Vụ" },
    ["btn_activity"] = { en = "🎉 Event Center", vi = "🎉 Trung Tâm Sự Kiện" },
    ["btn_medal"] = { en = "🏅 Collection Medal", vi = "🏅 Nhiệm Vụ Sưu Tập" },
    ["btn_achieve"] = { en = "🏆 Achievements", vi = "🏆 Thành Tựu" },
    ["btn_pet_vault"] = { en = "🏦 Pet Vault", vi = "🏦 Kho Lưu Trữ Pet" },
    ["btn_pet_recycle"] = { en = "♻️ Pet Recycle", vi = "♻️ Tái Chế Pet" },
    ["btn_pet_collect"] = { en = "📖 Pet Collection Book", vi = "📖 Sưu Tập Pet" },
    ["btn_pet_ride"] = { en = "🐎 Mounts Management", vi = "🐎 Quản Lý Thú Cưỡi" },
    ["btn_pet_transform"] = { en = "🔄 Pet Transform", vi = "🔄 Chuyển Hóa Pet" },

    -- Server Manager keys
    ["server"] = { en = "Server Manager", vi = "Quản Lý Server" },
    ["sec_session_info"] = { en = "SESSION INFO", vi = "THÔNG TIN PHIÊN LÀM VIỆC" },
    ["active_time_label"] = { en = "Active Time: ", vi = "Thời gian treo máy: " },
    ["sec_weather_hunt"] = { en = "VIP WEATHER HUNT", vi = "SĂN THỜI TIẾT VIP" },
    ["select_weather"] = { en = "Select Target Weather", vi = "Chọn Thời Tiết Cần Săn" },
    ["auto_weather_hop"] = { en = "Auto Weather Hop", vi = "Săn Thời Tiết" },
    ["auto_weather_hop_info"] = { en = "Automatically hops servers until a target weather event is active.", vi = "Tự động nhảy server cho đến khi gặp thời tiết yêu cầu." },
    ["sec_manual_control"] = { en = "MANUAL CONTROL", vi = "ĐIỀU KHIỂN THỦ CÔNG" },
    ["btn_join_least"] = { en = "👤 Emptiest Server", vi = "👤 Server Vắng Nhất" },
    ["btn_join_least_info"] = { en = "Teleports to the public server with the lowest player count.", vi = "Chuyển sang server có số lượng người chơi ít nhất." },
    ["btn_join_random"] = { en = "🔀 Random Server", vi = "🔀 Server Ngẫu Nhiên" },
    ["btn_join_random_info"] = { en = "Teleports to a random public server.", vi = "Chuyển sang một server ngẫu nhiên." },
    ["btn_join_same"] = { en = "🔄 Rejoin Same", vi = "🔄 Kết Nối Lại" },
    ["btn_join_same_info"] = { en = "Reconnects to your current game server (quick reset).", vi = "Vào lại chính server hiện tại để reset nhân vật." },
    ["sec_anti_kick"] = { en = "ANTI-KICK SYSTEM", vi = "HỆ THỐNG CHỐNG AFK/KICK" },
    ["auto_rejoin"] = { en = "Auto Rejoin", vi = "Auto Rejoin" },
    ["auto_rejoin_info"] = { en = "Automatically reconnects to a new server if disconnected or kicked from the game.", vi = "Tự động kết nối lại vào server mới nếu bị mất kết nối hoặc bị kick." },
    ["hop_least_msg"] = { en = "Teleporting to the emptiest server...", vi = "Đang nhảy qua server vắng nhất..." },
    ["hop_random_msg"] = { en = "Teleporting to a random server...", vi = "Đang nhảy qua server ngẫu nhiên..." },

    -- Player Tracker keys
    ["tracker"] = { en = "Player Tracker", vi = "Theo Dõi" },
    ["tracker_idle"] = { en = "Status: Idle", vi = "Trạng thái: Đang nghỉ" },
    ["tracker_selected"] = { en = "Status: Selected ", vi = "Trạng thái: Đã chọn " },
    ["tracker_stopped"] = { en = "Status: Stopped", vi = "Trạng thái: Đã dừng" },
    ["tracker_following"] = { en = "Status: Following ", vi = "Trạng thái: Đang theo dõi " },
    ["select_player"] = { en = "Select Player", vi = "Chọn người đi theo" },
    ["select_player_info"] = { en = "Choose a player from the server to track or follow.", vi = "Chọn một người chơi trong server để theo dõi hoặc đi theo." },
    ["refresh_players"] = { en = "Refresh Player List", vi = "Làm mới danh sách" },
    ["refresh_players_info"] = { en = "Updates the list of active players in the server.", vi = "Cập nhật danh sách người chơi hiện tại trong server." },
    ["toggle_follow"] = { en = "Auto Follow", vi = "Auto Follow" },
    ["toggle_follow_info"] = { en = "Starts or stops automatically walking/teleporting to the selected player.", vi = "Bắt đầu hoặc dừng tự động đi theo/tốc biến đến người chơi đã chọn." },
    ["btn_teleport_player"] = { en = "🚀 Teleport", vi = "🚀 Dịch Chuyển" },
    ["btn_teleport_player_info"] = { en = "Teleports you directly to the selected player's current position.", vi = "Tốc biến thẳng đến vị trí người chơi được chọn." },
    ["listen_chat"] = { en = "Listen Chat '!f'", vi = "Nghe Chat '!f'" },
    ["listen_chat_info"] = { en = "Automatically follows players if they chat '!f' in-game.", vi = "Tự động đi theo người chơi nếu họ gõ '!f' trong khung chat." },
    ["tracker_not_found"] = { en = "Target player not found or offline!", vi = "Không tìm thấy người chơi mục tiêu!" },

    -- Boss Hunt keys
    ["boss"] = { en = "Boss Hunt", vi = "Săn Boss" },
    ["sec_sp_boss"] = { en = "🌟 AUTO SPECIAL BOSS", vi = "🌟 AUTO SPECIAL BOSS" },
    ["sp_boss_idle"] = { en = "Status: Waiting for signal...", vi = "Trạng thái: Đang chờ tín hiệu..." },
    ["auto_sp_boss"] = { en = "Auto Special Boss", vi = "Auto Săn Special Boss" },
    ["auto_sp_boss_info"] = { en = "Automatically teleports to and fights Special Bosses when they spawn.", vi = "Tự động dịch chuyển đến và đánh Special Boss khi xuất hiện." },
    ["select_sp_worlds"] = { en = "Select Special Boss Worlds", vi = "Chọn Đảo Săn Special Boss" },
    ["sec_wb_boss"] = { en = "🌍 AUTO WORLD BOSS", vi = "🌍 AUTO WORLD BOSS" },
    ["wb_boss_idle"] = { en = "Status: Waiting for Wave...", vi = "Trạng thái: Đang chờ Sóng..." },
    ["auto_wb_boss"] = { en = "Auto World Boss", vi = "Auto Săn World Boss" },
    ["auto_wb_boss_info"] = { en = "Automatically cycles through selected worlds to hunt active World Bosses.", vi = "Tự động đi quét các đảo đã chọn để săn World Boss đang hoạt động." },
    ["boss_req_lock"] = { en = "⏳ Requesting System Controller lock...", vi = "⏳ Đang xin cờ SystemController..." },
    ["boss_no_world"] = { en = "⚠️ Please select at least one world!", vi = "⚠️ Vui lòng chọn đảo để bắt đầu..." },
    ["select_wb_worlds"] = { en = "Select World Boss Worlds", vi = "Chọn Đảo Săn World Boss" },
    ["auto_hop_boss"] = { en = "Auto Hop Server", vi = "Tự Động Nhảy Server" },
    ["auto_hop_boss_info"] = { en = "Automatically switches servers if no target bosses are active in selected worlds.", vi = "Tự động nhảy server khác nếu không tìm thấy Boss hoạt động ở các đảo đã chọn." },
    ["boss_signal"] = { en = "🚨 Caught signal: ", vi = "🚨 Bắt được tín hiệu: " },
    ["boss_attacking"] = { en = "⚔️ Attacking: ", vi = "⚔️ Đang tấn công: " },
    ["boss_teleporting"] = { en = "🚀 Teleporting to Area ", vi = "🚀 Bay tới Đảo " },
    ["boss_waiting_spawn"] = { en = "⏳ Waiting for spawn: ", vi = "⏳ Đang đợi load: " },
    ["wb_wave_start"] = { en = "🚨 Wave started! Moving to first world...", vi = "🚨 Bắt đầu Sóng! Tiến đến đảo đầu tiên..." },
    ["wb_yield_sp"] = { en = "⏳ Yielding for Special Boss hunt...", vi = "⏳ Đang nhường đường cho luồng Special..." },
    ["wb_defeating"] = { en = "⚔️ Defeating: ", vi = "⚔️ Đang dọn: " },
    ["wb_scanning"] = { en = "🔎 Scanning area... ", vi = "🔎 Đang tìm quái... " },
    ["wb_loop_done_hop"] = { en = "🔄 Loop done! Time left: ", vi = "🔄 Xong vòng! Còn " },
    ["wb_loop_done_wait"] = { en = "💤 Loop done. Waiting for next wave...", vi = "💤 Xong vòng. Đang chờ Sóng tiếp theo." },
    ["status_prefix"] = { en = "Status: ", vi = "Trạng thái: " },

    -- Auto Rift keys
    ["rift"] = { en = "Auto Rift", vi = "Auto Rift" },
    ["rift_status_off"] = { en = "STATUS: AUTO RIFT OFF", vi = "TRẠNG THÁI: AUTO RIFT ĐANG TẮT" },
    ["rifts_cleared_prefix"] = { en = "Rifts Cleared: ", vi = "Rift đã dọn: " },
    ["rift_cycle_not_started"] = { en = "🔄 Loop: Not started", vi = "🔄 Vòng lặp: Chưa bắt đầu" },
    ["rift_cycle_stopped"] = { en = "🔄 Loop: Stopped", vi = "🔄 Vòng lặp: Đã dừng" },
    ["rift_status_prep"] = { en = "STATUS: PREPARING SCAN...", vi = "STATUS: ĐANG CHUẨN BỊ QUÉT..." },
    ["rift_status_lock"] = { en = "STATUS: Locked Rift: ", vi = "STATUS: Đã khóa Rift: " },
    ["rift_status_lock_entering"] = { en = ". Entering...", vi = ". Đang vào..." },
    ["rift_status_fail"] = { en = "STATUS: Failed to enter Rift. Swapping target!", vi = "STATUS: Không thể vào Rift. Đổi mục tiêu!" },
    ["rift_status_catch"] = { en = "STATUS: Catching monsters...", vi = "STATUS: Đang ném bóng bắt quái..." },
    ["rift_status_fight"] = { en = "STATUS: In battle - Fighting!", vi = "STATUS: Đang trong trận - Chiến đấu!" },
    ["rift_status_done"] = { en = "STATUS: Cleared! Fast exiting...", vi = "STATUS: Hoàn thành! Đang thoát nhanh..." },
    ["rift_status_wait_lock"] = { en = "STATUS: Waiting for system lock...", vi = "STATUS: Chờ hệ thống cấp cờ..." },
    ["rift_status_wait_spawn"] = { en = "STATUS: Waiting for monsters to spawn...", vi = "STATUS: Đang đợi spawn quái..." },
    ["rift_status_done_exit"] = { en = "STATUS: Target cleared! Preparing to exit...", vi = "STATUS: Đã xử lý xong quái! Chuẩn bị thoát..." },
    ["rift_cycle_resting"] = { en = "💤 Resting: ", vi = "💤 Đang nghỉ ngơi: " },
    ["rift_cycle_map"] = { en = "🌍 Current Map: ", vi = "🌍 Đang ở Map: " },
    ["rift_cycle_hold_map"] = { en = "⚡ Holding Map (Farm Dynamic): %d secs", vi = "⚡ Giữ Map (Farm Dynamic): %d giây" },
    ["rift_cycle_scan_dynamic"] = { en = "🌍 Scanning Dynamic (Holding Map: ", vi = "🌍 Chỉ quét Dynamic (Đang giữ Map: " },
    ["rift_selected_worlds_label"] = { en = "🎯 Selected %d worlds to farm Rift", vi = "🎯 Đã chọn %d thế giới để farm Rift" },
    ["sec_rift_controls"] = { en = "CONTROLS", vi = "CÔNG TẮC ĐIỀU KHIỂN" },
    ["rift_master_toggle"] = { en = "Auto Rift", vi = "Auto Rift" },
    ["rift_master_toggle_info"] = { en = "Enables the auto Rift scanning and farming system.", vi = "Bật hệ thống tự động tìm và quét cổng Rift." },
    ["rift_dynamic_toggle"] = { en = "🔍 Hunt Dynamic", vi = "🔍 Săn Dynamic" },
    ["rift_dynamic_toggle_info"] = { en = "Scans for dynamically spawned Rift portals created in your world.", vi = "Săn các cổng Rift tự sinh ra ngẫu nhiên." },
    ["rift_static_toggle"] = { en = "🔍 Hunt Static", vi = "🔍 Săn Static" },
    ["rift_static_toggle_info"] = { en = "Scans for static Rift portal spawn points.", vi = "Săn các cổng Rift cố định ở các đảo." },
    ["sec_rift_config"] = { en = "CONFIGURATION & CYCLES", vi = "CẤU HÌNH BẢN ĐỒ & VÒNG LẶP" },
    ["rift_select_worlds"] = { en = "Select Rift Worlds", vi = "Chọn Đảo Farm Rift" },
    ["rift_auto_hop"] = { en = "Auto Hop", vi = "Auto Hop" },
    ["rift_auto_hop_info"] = { en = "Automatically hops servers instead of resting when the round is completed.", vi = "Tự động nhảy server thay vì chờ nghỉ ngơi khi hoàn thành vòng quét." },
    ["rift_rest_time"] = { en = "Rest Time (Mins)", vi = "Thời gian nghỉ (Phút)" },
    ["rift_rest_time_info"] = { en = "Set how long to wait before starting the next scan cycle.", vi = "Thời gian chờ trước khi bắt đầu lượt quét tiếp theo." },
    ["rift_select_colors"] = { en = "Select Rift Colors", vi = "Chọn Màu Cổng Rift" },
    ["rift_select_colors_info"] = { en = "Choose which Rift colors to farm. Portal colors map to difficulty levels.", vi = "Chọn màu sắc các cổng Rift muốn săn. Màu sắc tương ứng với độ khó." },
    ["color_blue"] = { en = "Blue (Normal)", vi = "Xanh Dương (Normal)" },
    ["color_purple"] = { en = "Purple (Hard)", vi = "Tím (Hard)" },
    ["color_red"] = { en = "Red (Nightmare)", vi = "Đỏ (Nightmare)" },
    ["color_green"] = { en = "Green (Normal)", vi = "Xanh Lá (Normal)" },
    ["color_yellow"] = { en = "Yellow", vi = "Vàng" },
    ["color_pink"] = { en = "Pink", vi = "Hồng" },
    ["color_darkpurple"] = { en = "Dark Purple", vi = "Tím Đậm" },

    -- Auto Event keys
    ["auto_event"] = { en = "Auto Event", vi = "Auto Sự Kiện" },
    ["auto_event_toggle"] = { en = "Auto Claim Events", vi = "Auto Claim Sự Kiện" },
    ["auto_event_info"] = { en = "Automatically scans, teleports, and claims active event items (Abuse Eggs, Event Chests, Xmas, Halloween) across all maps.", vi = "Tự động quét, dịch chuyển và nhận các vật phẩm sự kiện đang hoạt động (Trứng Admin, Rương Sự Kiện, Xmas, Halloween) trên mọi bản đồ." },
    ["event_status_idle"] = { en = "STATUS: IDLE - WAITING FOR EVENT...", vi = "TRẠNG THÁI: ĐANG CHỜ SỰ KIỆN..." },
    ["event_status_farming"] = { en = "STATUS: Claiming active event items...", vi = "TRẠNG THÁI: Đang bay đến nhận quà sự kiện..." },
    ["event_status_standing"] = { en = "STATUS: Standing on correct choice platform...", vi = "TRẠNG THÁI: Đang đứng trên ô trả lời chính xác..." },
    ["sec_event_controls"] = { en = "CONTROLS", vi = "CÔNG TẮC ĐIỀU KHIỂN" },
    ["event_priority_mode"] = { en = "Gift Priority Mode", vi = "Chế độ Ưu tiên Quà" },
    ["event_priority_mode_info"] = { en = "Select the priority order for Gift Selection events.", vi = "Chọn thứ tự ưu tiên nhận quà khi chọn rương sự kiện." },
    ["sec_event_weights"] = { en = "REWARD WEIGHTS CONFIG", vi = "CẤU HÌNH TRỌNG SỐ QUÀ" },
    ["weight_egg"] = { en = "Egg Weight", vi = "Trọng số Trứng" },
    ["weight_chest"] = { en = "Treasure Chest Weight", vi = "Trọng số Rương Báu" },
    ["weight_gem"] = { en = "Diamond/Gem Weight", vi = "Trọng số Kim Cương" },
    ["weight_gold"] = { en = "Gold Weight", vi = "Trọng số Vàng" },
    ["hud_obby_title"] = { en = "LIVE EVENT HUD", vi = "BẢNG TIN SỰ KIỆN LIVE" },
    ["event_guide_title"] = { en = "Quick Guide", vi = "Hướng Dẫn Nhanh" },
    ["event_guide_content"] = {
        en = "• Auto Claim: Automatically teleports to and claims event items (Abuse Eggs, Chests, Robberies) spawned on map.\n• Auto Quiz Solver: Recognizes active Q&A / Gift Choice events, evaluates reward weightings (Chests > Eggs > Gems > Items), and stands on the best platform.",
        vi = "• Auto Claim: Tự động dịch chuyển đến nhặt trứng Admin, rương sự kiện và cướp bóc được thả ngẫu nhiên trên bản đồ.\n• Đố Vui & Chọn Quà: Tự động nhận diện câu hỏi Q&A / Bục quà và tự dịch chuyển nhân vật đứng yên trên bục có phần thưởng giá trị nhất (Ưu tiên: Rương > Trứng > Kim Cương > Vật phẩm)."
    },

    ["master_toggle"] = { en = "Master Switch", vi = "Công Tắc Tổng" },
    ["auto_attack"] = { en = "Auto Attack", vi = "Auto Attack" },
    ["auto_attack_info"] = { en = "Automatically attacks target monsters nearby.", vi = "Tự động tấn công quái vật mục tiêu gần bạn." },

    ["auto_breed"] = { en = "Auto Breeding", vi = "Auto Lai Dắt Pet" },
    ["auto_breed_info"] = { en = "Automatically breeds chosen Father and Mother species when the slot is empty.", vi = "Tự động bắt cặp lai dắt giữa thú bố và thú mẹ đã chọn khi máy lai dắt trống." },
    ["breed_father"] = { en = "Select Father Pet (Male)", vi = "Chọn Pet Bố (Đực)" },
    ["breed_mother"] = { en = "Select Mother Pet (Female)", vi = "Chọn Pet Mẹ (Cái)" },

    ["clear_ram_logs"] = { en = "Memory & Log Cleaner", vi = "Dọn Dẹp Bộ Nhớ & Logs" },
    ["clear_ram_logs_info"] = { en = "Triggers aggressive Lua garbage collection and wipes executor/developer consoles to reduce client lag.", vi = "Chạy dọn rác Lua cấp cao và xóa sạch bộ nhớ tạm của bảng điều khiển/Developer Console giúp giảm lag." },
    ["btn_clear_now"] = { en = "Clear Memory & Logs Now", vi = "Giải Phóng RAM & Xoá Logs Ngay" },

    -- Auto Dungeon keys
    ["dungeon"] = { en = "Auto Dungeon", vi = "Hầm Ngục" },
    ["dg_status_off"] = { en = "AUTO DUNGEON IS OFF", vi = "AUTO DUNGEON ĐANG TẮT" },
    ["dg_status_on"] = { en = "AUTO DUNGEON IS ON", vi = "AUTO DUNGEON ĐANG BẬT" },
    ["sec_in_dungeon"] = { en = "INSIDE DUNGEON", vi = "TRONG HẦM NGỤC" },
    ["dg_auto_attack"] = { en = "Auto Attack", vi = "Auto Attack" },
    ["dg_auto_attack_info"] = { en = "Automatically targets and attacks monsters inside the Dungeon.", vi = "Tự động nhắm và tấn công quái vật bên trong hầm ngục." },
    ["dg_auto_exit_20"] = { en = "Auto Exit 20", vi = "Auto Exit 20" },
    ["dg_auto_exit_20_info"] = { en = "Automatically leaves the Dungeon when stage 20 is reached to save time.", vi = "Tự động thoát khỏi Hầm ngục khi đạt màn 20 để tiết kiệm thời gian." },
    ["dg_wait_host_timeout"] = { en = "Max Wait Host", vi = "Chờ Chủ Phòng" },
    ["dg_wait_host_timeout_info"] = { en = "Maximum time to wait for the room host to continue before auto exiting.", vi = "Thời gian tối đa chờ chủ phòng bấm đi tiếp trước khi tự thoát." },
    ["sec_dg_lobby"] = { en = "IN LOBBY (SẢNH CHỜ)", vi = "NGOÀI SẢNH (LOBBY)" },
    ["dg_auto_join"] = { en = "Auto Join", vi = "Auto Join" },
    ["dg_auto_join_info"] = { en = "Automatically joins open public dungeon rooms in the lobby.", vi = "Tự động tham gia các phòng hầm ngục đang mở ở sảnh chờ." },
    ["dg_auto_create"] = { en = "Auto Create", vi = "Auto Create" },
    ["dg_auto_create_info"] = { en = "Automatically creates a dungeon room and starts it when player count is reached.", vi = "Tự động tạo phòng và bắt đầu khi đủ số lượng người chơi." },
    ["dg_select_diff"] = { en = "Select Difficulty", vi = "Chọn Độ Khó" },
    ["dg_select_diff_info"] = { en = "Set target dungeon difficulty level.", vi = "Chọn độ khó hầm ngục mục tiêu để đi." },
    ["dg_player_count"] = { en = "Players Required", vi = "Số Người Chờ" },
    ["dg_player_count_info"] = { en = "Number of players required in the room before starting the game.", vi = "Số lượng người chơi cần thiết trong phòng trước khi bắt đầu." },
    
    ["dg_label_stage20_clock"] = { en = "Status: Stage 20 clock started...", vi = "Trạng thái: Đồng hồ màn 20 đã chạy..." },
    ["dg_label_wait_host"] = { en = "Status: Waiting for host (Max %d mins)...", vi = "Trạng thái: Đợi chủ phòng chạy lại (Tối đa %d phút)..." },
    ["dg_label_host_left"] = { en = "Status: Host left! Leaving...", vi = "Trạng thái: Chủ phòng đã out, tự động thoát!" },
    ["dg_label_sync_host"] = { en = "Status: Syncing Host data to new map (%ds/7s)...", vi = "Trạng thái: Đang đồng bộ dữ liệu Host sang map mới (%ds/7s)..." },
    ["dg_label_host_timeout"] = { en = "Status: Host timeout! Leaving...", vi = "Trạng thái: Hết thời gian chờ, tự động thoát!" },
    ["dg_label_wait_host_detail"] = { en = "Status: Waiting for host (%ds/%ds) - Players: %d", vi = "Trạng thái: Đợi chủ phòng (%ds/%ds) - Số người: %d" },
    ["dg_label_boss_key"] = { en = "Status: Boss defeated. Use key to proceed...", vi = "Trạng thái: Boss gục, dùng chìa khóa đi tiếp..." },
    ["dg_label_boss_done_exit"] = { en = "Status: Boss defeated. Preparing to leave...", vi = "Trạng thái: Boss gục, chuẩn bị thoát..." },
    ["dg_label_lobby_yield_boss"] = { en = "🛑 Lobby: Yielding to Auto Boss...", vi = "🛑 Sảnh: Đang nhường đường cho Auto Boss..." },
    ["dg_label_lobby_boss_done"] = { en = "✅ Lobby: Boss done, resuming Dungeon!", vi = "✅ Sảnh: Boss đã xong, tiếp tục Auto Dungeon!" },
    ["dg_label_lobby_stopped"] = { en = "⏸️ Lobby: STOPPED (Main Controller)", vi = "⏸️ Sảnh: ĐÃ DỪNG (Main Controller)" },
    ["dg_label_lobby_wait_lock"] = { en = "Lobby: Waiting for lock...", vi = "Sảnh: Chờ cấp cờ AutoDungeon..." },
    ["dg_label_lobby_finding"] = { en = "Lobby: Finding rooms with players...", vi = "Sảnh: Đang tìm phòng có người..." },
    ["dg_label_lobby_full"] = { en = "Lobby: Room full %d/%d! Starting...", vi = "Sảnh: Đủ %d/%d người! Chuẩn bị Start..." },
    ["dg_label_lobby_force_start"] = { en = "Lobby: Forcing start...", vi = "Sảnh: Đang ép lệnh Start..." },
    ["dg_label_lobby_wait_players"] = { en = "Lobby: Waiting for players %d/%d", vi = "Sảnh: Đang chờ người %d/%d" },
    ["dg_label_lobby_creating"] = { en = "Lobby: Creating room and setting difficulty...", vi = "Sảnh: Đang thiết lập Độ Khó và Tạo phòng..." },
    ["dg_label_lobby_joining"] = { en = "Lobby: Joining empty room...", vi = "Sảnh: Đang nhảy vào phòng trống..." },
    ["dg_label_lobby_off"] = { en = "Lobby: Auto Join/Create is OFF", vi = "Sảnh: Auto Join/Create đang tắt" },

    -- Auto Farm keys
    ["farm"] = { en = "Auto Farm", vi = "Auto farm" },
    ["sec_farm_controls"] = { en = "SYSTEM CONTROLS", vi = "ĐIỀU KHIỂN TỔNG" },
    ["btn_stop_all"] = { en = "🛑 STOP ALL", vi = "🛑 DỪNG TẤT CẢ" },
    ["btn_stop_all_info"] = { en = "Pause all background auto-farming and auto-combat loops.", vi = "Dừng khẩn cấp toàn bộ các luồng auto và chiến đấu." },
    ["btn_resume_all"] = { en = "▶️ RESUME ALL", vi = "▶️ TIẾP TỤC HẾT" },
    ["btn_resume_all_info"] = { en = "Resume all paused auto-farming and auto-combat loops.", vi = "Tiếp tục chạy lại toàn bộ các luồng auto đã tạm dừng." },
    ["farm_target_all"] = { en = "All monsters", vi = "Tất cả quái" },
    ["farm_target_prefix"] = { en = "🐾 Target: ", vi = "🐾 Đang farm: " },
    ["farm_select_monsters"] = { en = "Select Target Monsters", vi = "Chọn loại quái" },
    ["farm_select_monsters_info"] = { en = "Select specific monsters to target. Unselect all to farm everything.", vi = "Chọn loại quái cụ thể để farm. Bỏ chọn hết để farm tất cả." },
    ["farm_scan_monsters"] = { en = "🔍 Scan Monsters on Map", vi = "🔍 Quét quái quanh Map" },
    ["farm_scan_monsters_info"] = { en = "Detects all unique monster types near you and loads them into the dropdown filter.", vi = "Quét tất cả các loại quái hiện có xung quanh và nạp vào danh sách chọn." },
    ["sec_farm_combat"] = { en = "COMBAT SETTINGS", vi = "CẤU HÌNH CHIẾN ĐẤU" },
    ["farm_tp_toggle"] = { en = "TP Farm", vi = "TP Farm" },
    ["farm_tp_toggle_info"] = { en = "Teleports directly to targets for faster farming (high efficiency).", vi = "Tự động dịch chuyển áp sát mục tiêu để diệt nhanh hơn." },
    ["farm_radius"] = { en = "Farm Radius", vi = "Bán kính Farm" },
    ["farm_radius_info"] = { en = "Set maximum distance to scan for target monsters.", vi = "Khoảng cách tối đa để quét và tấn công quái." },
    ["farm_auto_catch"] = { en = "Auto Catch", vi = "Auto Catch" },
    ["farm_auto_catch_info"] = { en = "Automatically throws capture balls at weakened target monsters.", vi = "Tự động ném bóng thu phục khi quái vật yếu máu." },
    ["sec_farm_survival"] = { en = "SURVIVAL SETTINGS", vi = "CẤU HÌNH SINH TỒN" },
    ["farm_auto_heal"] = { en = "Auto Heal", vi = "Auto Heal" },
    ["farm_auto_heal_info"] = { en = "Automatically heals your pet team when they fall below threshold.", vi = "Tự động hồi phục cho đội hình pet khi đạt ngưỡng yêu cầu." },
    ["farm_heal_threshold"] = { en = "Heal Threshold (Dead Pets)", vi = "Ngưỡng Pet chết để Heal" },
    ["farm_heal_threshold_info"] = { en = "Number of fainted pets before triggering the Auto Heal.", vi = "Số lượng pet bị hết máu để kích hoạt bình hồi máu." },
    ["farm_smart_return"] = { en = "Smart Return", vi = "Smart Return" },
    ["farm_smart_return_info"] = { en = "Automatically returns to your saved farming spot after healing or dying.", vi = "Tự động dịch chuyển về bãi farm sau khi hồi máu hoặc bị hồi sinh." },
    ["sec_farm_navigation"] = { en = "COORDINATES & NAVIGATION", vi = "TỌA ĐỘ VÀ ĐỊNH VỊ" },
    ["farm_center_label"] = { en = "Farm Center: ", vi = "Tâm bãi: " },
    ["farm_not_configured"] = { en = "📍 Not Configured", vi = "📍 Chưa cấu hình" },
    ["btn_save_spot"] = { en = "💾 Save Spot", vi = "💾 Lưu Tọa Độ" },
    ["btn_save_spot_info"] = { en = "Saves your current position as the center of your farming area.", vi = "Lưu vị trí bạn đang đứng để làm tọa độ tâm bãi farm." },
    ["btn_teleport_spot"] = { en = "🚀 Return Spot", vi = "🚀 Về Bãi" },
    ["btn_teleport_spot_info"] = { en = "Teleports you back to your saved farming position immediately.", vi = "Dịch chuyển tức thời về lại vị trí bãi farm đã lưu." },
    
    ["system_title"] = { en = "System", vi = "Hệ thống" },
    ["stopped_all_msg"] = { en = "🛑 Stopped all auto systems!", vi = "🛑 Đã tạm dừng tất cả auto!" },
    ["resumed_all_msg"] = { en = "▶️ Resumed all auto systems!", vi = "▶️ Tiếp tục vận hành tất cả auto!" },
    ["no_monsters_found_msg"] = { en = "No monsters found nearby!", vi = "Không tìm thấy quái nào xung quanh!" },
    ["scan_complete_title"] = { en = "Scan Complete", vi = "Quét Hoàn Tất" },
    ["scan_complete_msg"] = { en = "Found %d types of monsters.", vi = "Đã tìm thấy %d loại quái." },
    ["tp_farm_active_msg"] = { en = "Teleport Farm mode is active.", vi = "Đang vận hành chế độ Tấn công dịch chuyển (TP Farm)." },
    ["tp_farm_title"] = { en = "TP Farm", vi = "🚀 TP Farm" },
    ["tp_farm_enable_msg"] = { en = "TP Farm enabled! Please enable 'Auto Attack' to start.", vi = "Đã bật TP Farm! Hãy bật 'Tự Động Đánh Quái' để bắt đầu." },
    ["tp_farm_switched_msg"] = { en = "Switched to Teleport Farm mode.", vi = "Đã chuyển sang chế độ diệt quái không gian." },
    ["saved_title"] = { en = "Saved", vi = "Đã Lưu" },
    ["farm_saved_msg"] = { en = "Farming center position successfully saved!", vi = "Tọa độ bãi farm đã được ghi nhớ thành công!" },
    ["tele_fail_title"] = { en = "Cannot Teleport", vi = "Không thể chuyển vùng" },
    ["tele_abyss_fail_msg"] = { en = "Cannot auto teleport to Dungeon: ", vi = "Không thể tự động chuyển vào phụ bản: " },
    ["tele_world_title"] = { en = "Teleporting World", vi = "Chuyển World" },
    ["tele_world_msg"] = { en = "Teleporting to the saved farm world...", vi = "Đang tự động chuyển sang world đã lưu..." },
    ["tele_spot_title"] = { en = "Teleporting", vi = "Dịch chuyển" },
    ["tele_spot_success_msg"] = { en = "Successfully arrived at farm center!", vi = "Đã về tâm bãi farm thành công!" },
    ["tele_spot_flying_msg"] = { en = "Flying to farm center...", vi = "Đang bay về tâm bãi farm..." },
    ["farm_not_saved_msg"] = { en = "Saved farm position not found!", vi = "Chưa lưu vị trí tâm bãi farm!" },
    ["farm_guide_title"] = { en = "Quick Guide", vi = "Hướng Dẫn Nhanh" },
    ["farm_guide_content"] = { en = "• TP Farm: Teleport directly to monsters.\n• Auto Catch: Capture monsters when low HP.\n• Smart Return: Teleport back to farm center after healing/dying.", vi = "• TP Farm: Dịch chuyển áp sát quái để diệt nhanh hơn.\n• Auto Catch: Tự động ném bóng thu phục quái yếu máu.\n• Smart Return: Tự động bay về tâm bãi sau khi hồi phục/hồi sinh." },

    -- AI Assistant keys
    ["ai_title"] = { en = "🧠 Catch A Monster | AI", vi = "🧠 Catch A Monster | AI" },
    ["ai_key_saved"] = { en = "Saved Key", vi = "Key đã lưu" },
    ["ai_key_prompt"] = { en = "Enter Gemini API Key...", vi = "Nhập Gemini API Key..." },
    ["ai_prompt_placeholder"] = { en = "Enter command (supports multi-line code)...", vi = "Nhập lệnh (hỗ trợ dán code nhiều dòng)..." },
    ["ai_system_ready"] = { en = "> AI System Ready...", vi = "> Hệ thống AI sẵn sàng..." },
    ["toggle_on"] = { en = "ON", vi = "BẬT" },
    ["toggle_off"] = { en = "OFF", vi = "TẮT" },
    ["ai_webhook_log"] = { en = "Webhook Log: ", vi = "Nhật Ký Webhook: " },
    ["ai_clear_history"] = { en = "Clear conversation history", vi = "Xóa lịch sử hội thoại" },
    ["ai_history_cleared"] = { en = "> History cleared. AI reset.", vi = "> Lịch sử đã xóa. AI sẵn sàng từ đầu." },
    ["ai_get_code"] = { en = "GET CODE FROM AI", vi = "LẤY CODE TỪ AI" },
    ["ai_execute_code"] = { en = "EXECUTE CODE (Read first)", vi = "THỰC THI CODE (Sau khi đã đọc)" },
    ["ai_processing"] = { en = "PROCESSING...", vi = "ĐANG XỬ LÝ..." },
    ["ai_waiting"] = { en = "> Waiting for AI...", vi = "> Đang chờ AI..." },
    ["ai_timeout_prefix"] = { en = "Timeout: No response from API after ", vi = "Hết giờ: API không phản hồi sau " },
    ["ai_read_code_warn"] = { en = "-- REVIEW CODE BEFORE RUNNING --\n", vi = "-- ĐỌC CODE TRƯỚC KHI CHẠY --\n" },
    ["ai_got_code"] = { en = "CODE RECEIVED", vi = "ĐÃ LẤY ĐƯỢC CODE" },
    ["ai_error_prefix"] = { en = "ERROR:\n", vi = "LỖI:\n" },
    ["ai_error"] = { en = "ERROR", vi = "LỖI" },
    ["ai_running"] = { en = "RUNNING...", vi = "ĐANG CHẠY..." },
    ["ai_compile_error"] = { en = "COMPILE ERROR:", vi = "LỖI CÚ PHÁP:" },
    ["ai_execute_success"] = { en = "EXECUTED SUCCESSFULLY", vi = "THỰC THI THÀNH CÔNG" },
    ["ai_runtime_error"] = { en = "RUNTIME ERROR:", vi = "LỖI RUNTIME:" },
    ["ai_err_no_key"] = { en = "API Key is missing.", vi = "Chưa có API Key." },
    ["ai_err_no_http"] = { en = "Executor does not support HTTP Requests!", vi = "Executor không hỗ trợ HTTP Request!" },
    ["ai_err_connect"] = { en = "API connection error.", vi = "Lỗi kết nối API." },
    ["ai_err_http"] = { en = "HTTP Error: ", vi = "Lỗi HTTP: " },
    ["ai_err_json"] = { en = "JSON parsing error.", vi = "Lỗi parse JSON." },
    ["ai_err_empty"] = { en = "API returned an empty response.", vi = "API trả về response rỗng." },

    -- Webhook translation keys
    ["event_xray_toggle"] = { en = "Preview Rewards (X-Ray)", vi = "Nhìn Xuyên Thấu Quà" },
    ["event_xray_info"] = { en = "Displays 3D text overlays showing the exact rewards hidden on each event platform.", vi = "Hiển thị chữ 3D lơ lửng trên không tiết lộ chính xác phần quà ẩn bên trong mỗi bục sự kiện." },

    ["webhook"] = { en = "Webhook", vi = "Webhook" },
    ["sec_webhook_settings"] = { en = "DISCORD WEBHOOK SETTINGS", vi = "THIẾT LẬP DISCORD WEBHOOK" },
    ["webhook_toggle"] = { en = "Enable Discord Notification", vi = "Bật/Tắt Thông Báo Discord" },
    ["webhook_url"] = { en = "Discord Webhook URL", vi = "Link Discord Webhook" },
    ["webhook_url_placeholder"] = { en = "Paste your Webhook URL here...", vi = "Dán link Webhook của bạn vào đây..." },
    ["webhook_btn_test"] = { en = "Send Test Notification", vi = "Gửi Thông Báo Test" },
    ["webhook_invalid_msg"] = { en = "Invalid Webhook URL!", vi = "Link Webhook không hợp lệ!" },
    ["webhook_test_sent_msg"] = { en = "Test notification sent to Discord!", vi = "Đã gửi thông báo test qua Discord!" },
    ["webhook_notification_title"] = { en = "🎉 Auto-Farm Update", vi = "🎉 Cập nhật Auto-Farm" },
    ["webhook_test_payload"] = { en = "🛠️ Webhook Test Successful! R-Client Pro system is running smoothly.", vi = "🛠️ Test Webhook thành công! Hệ thống R-Client Pro đang hoạt động tốt." }
}

local currentLang = "en"
local locale = game:GetService("LocalizationService").RobloxLocaleId
if locale and string.sub(string.lower(locale), 1, 2) == "vi" then
    currentLang = "vi"
end

function Localization.t(key)
    local trans = Translations[key]
    if trans then
        return trans[currentLang] or trans["en"]
    end
    return key
end

function Localization.getLang()
    return currentLang
end

return Localization

end

modules['features/farm.txt'] = function(...)
-- ====================================================================
-- MODULE: R-GAME AUTO FARM (V10 REFACTORED - CONCURRENCY OPTIMIZED)
-- ====================================================================
return function(Window, Utils)
    -- ==========================================
    -- 1. KHỞI TẠO DỊCH VỤ & BIẾN MÔI TRƯỜNG
    -- ==========================================
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local HttpService = game:GetService("HttpService")
    local LocalPlayer = Players.LocalPlayer

    -- Cache hệ thống để tối ưu hiệu năng gọi API
    local SystemCache = {
        MonsterSystem = nil,
        AttackRemote = nil,
        InternalMonsterTable = nil,
        MonsterNames = {}
    }

    -- Quản lý File I/O
    local ConfigFiles = {
        Position = "R_ClientPro_FarmPos.json",
        Filter = "R_ClientPro_MonsterFilter.json"
    }

    -- Quản lý Trạng thái cục bộ (Local State)
    local AppState = {
        autoAttack = false,
        autoCatch = false,
        tpFarmEnabled = false,
        autoHeal = false,
        isHealing = false, -- Cờ (Flag) đóng vai trò Mutex lock để chặn các luồng khác khi đang hồi máu
        autoReturnToFarm = false,
        healThreshold = 1,
        attackRadius = 200,
        attackDelay = 0.2,
        tpDistanceOffset = Vector3.new(0, 7, 0),
        savedFarmPosition = nil,
        savedFarmAreaId = nil,
        tempFarmPosition = nil, -- Vị trí tạm thời khi bật farm mà không lưu vị trí
        targetMonsterNames = {}
    }

    -- ==========================================
    -- 2. TẦNG XỬ LÝ DỮ LIỆU & TIỆN ÍCH (HELPER FUNCTIONS)
    -- ==========================================
    
    -- [Network] Khởi tạo các module và remote một lần duy nhất (Lazy Loading)
    local function InitializeNetworkRemotes()
        if not SystemCache.MonsterSystem then
            pcall(function() SystemCache.MonsterSystem = require(ReplicatedStorage.CommonLogic.Monster.MonsterSystem) end)
        end
        
        if not SystemCache.AttackRemote then
            pcall(function()
                SystemCache.AttackRemote = ReplicatedStorage:FindFirstChild("CommonLibrary")
                    and ReplicatedStorage.CommonLibrary:FindFirstChild("Tool")
                    and ReplicatedStorage.CommonLibrary.Tool:FindFirstChild("RemoteManager")
                    and ReplicatedStorage.CommonLibrary.Tool.RemoteManager:FindFirstChild("Funcs")
                    and ReplicatedStorage.CommonLibrary.Tool.RemoteManager.Funcs:FindFirstChild("DataPullFunc")
            end)
        end
    end

    -- [I/O] Xử lý đọc/ghi file cấu hình an toàn
 --   local function LoadLocalData(fileName)
  --      if isfile and isfile(fileName) and readfile then
  --          local success, data = pcall(function() return HttpService:JSONDecode(readfile(fileName)) end)
   --         return success and data or nil
  --      end
   --     return nil
   -- end

    --local function SaveLocalData(fileName, dataTable)
    --    if writefile then
    --        pcall(function() writefile(fileName, HttpService:JSONEncode(dataTable)) end)
     --   end
  --  end

    -- [Memory] Khai thác Upvalue để lấy từ điển quái vật ẩn
    local function FetchInternalMonsterDictionary()
        if SystemCache.InternalMonsterTable then return end
        pcall(function()
            local env = getrenv and getrenv()._G and getrenv()._G.PathTool
            if env and env.MgrMonsterClient then
                local upvalues = debug.getupvalues(env.MgrMonsterClient.GetMonsterInfo)
                if upvalues and type(upvalues[1]) == "table" then
                    SystemCache.InternalMonsterTable = upvalues[1]
                end
            end
        end)
    end

    -- [Logic] Dịch tên quái từ UID động sang tên thật tĩnh
    local function ResolveMonsterName(monsterObj)
        if not monsterObj then return "Unknown" end
        
        local uidStr = string.match(monsterObj.Name, "Monster_(%d+)")
        if not uidStr then return monsterObj.Name end
        
        local uidNum = tonumber(uidStr)
        if SystemCache.MonsterNames[uidNum] then return SystemCache.MonsterNames[uidNum] end
        
        FetchInternalMonsterDictionary()
        
        if type(SystemCache.InternalMonsterTable) == "table" then
            local rawData = SystemCache.InternalMonsterTable[uidNum]
            if type(rawData) == "table" then
                local tmplId = rawData.TmplId or rawData.tmplId or rawData.cfgId
                if tmplId then
                    local env = getrenv and getrenv()._G and getrenv()._G.PathTool
                    if env and env.CfgMonster and env.CfgMonster.Tmpls then
                        local cfg = env.CfgMonster.Tmpls[tostring(tmplId)] or env.CfgMonster.Tmpls[tonumber(tmplId)]
                        if cfg and (cfg.Name or cfg.name or cfg.Title) then
                            local realName = cfg.Name or cfg.name or cfg.Title
                            SystemCache.MonsterNames[uidNum] = realName
                            return realName
                        end
                    end
                end
            end
        end
        return monsterObj.Name
    end

    -- [Logic] Quét toàn bộ quái trên map để nạp vào Dropdown
    local function ScanAllUniqueMonsters()
        local uniqueNames = {}
        local nameDictionary = {}
        local targetFolders = {"ClientMonsters", "Monsters"}
        
        for _, folderName in ipairs(targetFolders) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                for _, obj in pairs(folder:GetChildren()) do
                    if obj:IsA("Model") or obj:IsA("BasePart") then
                        local success, realName = pcall(function() return ResolveMonsterName(obj) end)
                        if success and realName and realName ~= "Unknown" and not string.find(realName, "Monster_") and not nameDictionary[realName] then
                            nameDictionary[realName] = true
                            table.insert(uniqueNames, realName)
                        end
                    end
                end
            end
        end
        table.sort(uniqueNames)
        return uniqueNames
    end

    -- [Validation] Kiểm tra xem hệ thống có đang bận hoặc bị khóa không
    local function IsSystemBusy()
        local controller = _G.SystemController
        if controller and (controller.IsPaused or controller.CurrentLock ~= nil) then return true end
        if _G.PendingBossHunt or _G.PendingSpecialBoss then return true end
        return false
    end

    -- [Validation] Lấy thông tin nhân vật an toàn
    local function GetValidCharacterData()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        if hrp and hum and hum.Health > 0 then
            return { Character = char, RootPart = hrp, Humanoid = hum, Position = hrp.Position }
        end
        return nil
    end

    local function IsAllMonstersOption(option)
        return option == "farm_target_all" 
            or option == "All monsters" 
            or option == "Tất cả quái"
            or option == (Utils.t and Utils.t("farm_target_all") or "farm_target_all")
    end

    -- [Validation] Lọc quái theo cài đặt người chơi
    local function IsMonsterInFilter(monster)
        if not AppState.targetMonsterNames or #AppState.targetMonsterNames == 0 then return true end
        for _, opt in ipairs(AppState.targetMonsterNames) do
            if IsAllMonstersOption(opt) then return true end
        end
        
        local realName = ResolveMonsterName(monster)
        for _, targetName in ipairs(AppState.targetMonsterNames) do
            if string.find(string.lower(realName), string.lower(targetName)) then
                return true
            end
        end
        return false
    end

    -- ==========================================
    -- 3. TẦNG LOGIC NGHIỆP VỤ (BUSINESS LOGIC)
    -- ==========================================
    
    -- Tính toán thiệt hại của Pet (Đồng bộ giữa UI và Thực tế qua dữ liệu túi đồ hoặc MgrPetClient)
    local function CalculatePetCasualties()
        local deadCount = 0
        local aliveCount = 0
        local maxEquipped = 3 -- Mặc định/Dự phòng số pet được trang bị
        local checkedViaMap = false
        
        pcall(function()
            local env = getrenv and getrenv()._G and getrenv()._G.PathTool
            local petData = env and env.BossRoomSystemClient and env.BossRoomSystemClient.gamePlayer and env.BossRoomSystemClient.gamePlayer.pet
            
            if petData and petData._equipedItemMap then
                local equippedCount = 0
                for _, petObj in pairs(petData._equipedItemMap) do
                    equippedCount = equippedCount + 1
                    if petObj.IsDead and petObj:IsDead() then
                        deadCount = deadCount + 1
                    else
                        aliveCount = aliveCount + 1
                    end
                end
                maxEquipped = math.max(maxEquipped, equippedCount)
                checkedViaMap = true
            end
            
            -- Chỉ dùng MgrPetClient fallback nếu không truy cập được dữ liệu trực tiếp từ túi đồ
            if not checkedViaMap and env and env.MgrPetClient and env.LogicNumber then
                local MgrPetClient = env.MgrPetClient
                local LogicNumber = env.LogicNumber
                
                MgrPetClient.IterPet(function(pet)
                    if pet.PlayerId == LocalPlayer.UserId then
                        if pet.EquipedAmount then
                            maxEquipped = math.max(maxEquipped, pet.EquipedAmount)
                        end
                        
                        local isAlive = false
                        local curRaw = pet.HealthValue and pet.HealthValue.Value
                        local maxRaw = pet.HealthValue and pet.HealthValue:GetAttribute("MaxHealth")
                        
                        if curRaw and maxRaw then
                            local curLogic = LogicNumber.FixLogicNumber(curRaw)
                            local maxLogic = LogicNumber.FixLogicNumber(maxRaw)
                            local ratio = LogicNumber.ToNumber(LogicNumber.Divide(curLogic, maxLogic))
                            
                            -- Nếu máu trên 1%, pet còn sống
                            if ratio > 0.01 then
                                isAlive = true
                            end
                        end
                        
                        if isAlive then
                            aliveCount = aliveCount + 1
                        else
                            deadCount = deadCount + 1
                        end
                    end
                    return true
                end)
                
                -- Nếu số lượng pet hoạt động/còn sống thực tế ít hơn tổng số pet được trang bị (EquipedAmount),
                -- chứng tỏ các pet bị thiếu hụt đã bị ẩn/chết hoàn toàn và không còn được hiển thị trong IterPet.
                if aliveCount < maxEquipped then
                    local missingCount = maxEquipped - aliveCount
                    if missingCount > deadCount then
                        deadCount = missingCount
                    end
                end
            end
        end)
        
        return deadCount
    end

    -- Xác định tọa độ suối hồi máu gần nhất
    local function LocateNearestHealingSpring(currentPos)
        local bestPos, minDist = nil, math.huge
        local areaFolder = Workspace:FindFirstChild("Area")
        
        if not areaFolder then return nil end
        
        for _, mapFolder in ipairs(areaFolder:GetChildren()) do
            local recFolder = mapFolder:FindFirstChild("ServerZone") and mapFolder.ServerZone:FindFirstChild("Recover")
            if recFolder then
                for _, recPart in ipairs(recFolder:GetDescendants()) do
                    if recPart:IsA("BasePart") then
                        local dist = (currentPos - recPart.Position).Magnitude
                        if dist < minDist then 
                            minDist = dist
                            bestPos = recPart.Position 
                        end
                    end
                end
            end
        end
        return bestPos
    end

    -- ==========================================
    -- 4. KHỞI TẠO DỮ LIỆU & ĐĂNG KÝ HỆ THỐNG
    -- ==========================================
    InitializeNetworkRemotes()

    local savedPosData = Utils.LoadJSON(ConfigFiles.Position)
    if savedPosData then 
        AppState.savedFarmPosition = CFrame.new(savedPosData.X, savedPosData.Y, savedPosData.Z) 
        AppState.savedFarmAreaId = savedPosData.AreaId
    end
    local loadedFilter = Utils.LoadJSON(ConfigFiles.Filter) or {}
    local cleanedFilter = {}
    for _, opt in ipairs(loadedFilter) do
        if not IsAllMonstersOption(opt) then
            table.insert(cleanedFilter, opt)
        end
    end
    AppState.targetMonsterNames = cleanedFilter

    if _G.SystemController and type(_G.SystemController.registerModule) == "function" then
        _G.SystemController:registerModule("AutoFarm", function(paused)
            AppState.autoAttack = not paused
            AppState.autoCatch = not paused
            if not paused then
                local charData = GetValidCharacterData()
                if charData then AppState.tempFarmPosition = charData.Position end
            else
                AppState.tempFarmPosition = nil
            end
        end)
    end

    local SendNotify = function(title, text)
        pcall(function() game.StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 3 }) end)
    end

    -- ==========================================
    -- 5. XÂY DỰNG GIAO DIỆN (UI BINDING)
    -- ==========================================
    local CamTab = Window:CreateTab(Utils.t("farm"), "dumbbell")
    local MonsterDropdown = nil

    CamTab:CreateParagraph({
        Title = "💡 " .. Utils.t("farm_guide_title"),
        Content = Utils.t("farm_guide_content")
    })

    CamTab:CreateSection(" " .. Utils.t("sec_farm_controls") .. " ")
    CamTab:CreateButton({ 
        Name = Utils.t("btn_stop_all"), 
        Info = Utils.t("btn_stop_all_info"),
        Callback = function()
            if _G.SystemController then
                _G.SystemController.IsPaused = true
                for _, pauseFunc in pairs(_G.SystemController.Modules) do pcall(function() pauseFunc(true) end) end
                SendNotify(Utils.t("system_title"), Utils.t("stopped_all_msg"))
            end
        end
    })
    
    CamTab:CreateButton({ 
        Name = Utils.t("btn_resume_all"), 
        Info = Utils.t("btn_resume_all_info"),
        Callback = function()
            if _G.SystemController then
                _G.SystemController.IsPaused = false
                for _, pauseFunc in pairs(_G.SystemController.Modules) do pcall(function() pauseFunc(false) end) end
                SendNotify(Utils.t("system_title"), Utils.t("resumed_all_msg"))
            end
        end
    })

    local MonsterListLabel = CamTab:CreateLabel(Utils.t("farm_target_prefix") .. Utils.t("farm_target_all"))
    local function UpdateUIFilterLabel()
        local text = #AppState.targetMonsterNames > 0 and table.concat(AppState.targetMonsterNames, ", ") or Utils.t("farm_target_all")
        MonsterListLabel:Set(Utils.t("farm_target_prefix") .. text)
    end
    UpdateUIFilterLabel()

    MonsterDropdown = CamTab:CreateDropdown({
        Name = Utils.t("farm_select_monsters"),
        Info = Utils.t("farm_select_monsters_info"),
        Options = {Utils.t("farm_target_all")},
        CurrentOption = #AppState.targetMonsterNames > 0 and AppState.targetMonsterNames or {Utils.t("farm_target_all")},
        MultipleOptions = true,
        Flag = "MonsterSelectFarm",
        Callback = function(Options)
            pcall(function()
                local hasAll = false
                local cleanOptions = {}
                for _, opt in ipairs(Options) do
                    if IsAllMonstersOption(opt) then
                        hasAll = true
                    else
                        table.insert(cleanOptions, opt)
                    end
                end
                
                if hasAll and #Options > 1 then
                    if #AppState.targetMonsterNames == 0 then
                        -- Previously all, now specific added -> Uncheck 'All monsters'
                        AppState.targetMonsterNames = cleanOptions
                        task.spawn(function() pcall(function() MonsterDropdown:Set(cleanOptions) end) end)
                    else
                        -- Previously specific, now 'All monsters' selected -> Select only 'All monsters'
                        AppState.targetMonsterNames = {}
                        local allOpt = { Utils.t("farm_target_all") }
                        task.spawn(function() pcall(function() MonsterDropdown:Set(allOpt) end) end)
                    end
                elseif hasAll then
                    AppState.targetMonsterNames = {}
                else
                    AppState.targetMonsterNames = cleanOptions
                end
                
                Utils.SaveJSON(ConfigFiles.Filter, AppState.targetMonsterNames)
                UpdateUIFilterLabel()
            end)
        end
    })

    CamTab:CreateButton({ 
        Name = Utils.t("farm_scan_monsters"), 
        Info = Utils.t("farm_scan_monsters_info"),
        Callback = function()
            task.spawn(function()
                local names = ScanAllUniqueMonsters()
                if #names == 0 then return SendNotify(Utils.t("warning_title"), Utils.t("no_monsters_found_msg")) end

                local finalOptions = {Utils.t("farm_target_all")}
                for _, name in ipairs(names) do table.insert(finalOptions, name) end
                
                if MonsterDropdown then
                    if MonsterDropdown.Refresh then MonsterDropdown:Refresh(finalOptions, true)
                    else MonsterDropdown:SetOptions(finalOptions) end
                end
                SendNotify(Utils.t("scan_complete_title"), string.format(Utils.t("scan_complete_msg"), #names))
            end)
        end
    })

    CamTab:CreateSection(" " .. Utils.t("sec_farm_combat") .. " ")
    CamTab:CreateToggle({
        Name = Utils.t("auto_attack"),
        Info = Utils.t("auto_attack_info"),
        CurrentValue = false,
        Callback = function(V)
            AppState.autoAttack = V
            if V then
                local charData = GetValidCharacterData()
                if charData then AppState.tempFarmPosition = charData.Position end
                if AppState.tpFarmEnabled then
                    SendNotify(Utils.t("auto_attack"), Utils.t("tp_farm_active_msg"))
                end
            else
                AppState.tempFarmPosition = nil
            end
        end
    })
    CamTab:CreateToggle({
        Name = Utils.t("farm_tp_toggle"),
        Info = Utils.t("farm_tp_toggle_info"),
        CurrentValue = false,
        Callback = function(V)
            AppState.tpFarmEnabled = V
            if V then
                if not AppState.autoAttack then
                    SendNotify(Utils.t("tp_farm_title"), Utils.t("tp_farm_enable_msg"))
                else
                    SendNotify(Utils.t("tp_farm_title"), Utils.t("tp_farm_switched_msg"))
                end
            end
        end
    })
    CamTab:CreateSlider({ Name = Utils.t("farm_radius"), Info = Utils.t("farm_radius_info"), Range = {10, 2000}, Increment = 10, Suffix = " studs", CurrentValue = 200, Callback = function(V) AppState.attackRadius = V end })
    CamTab:CreateToggle({ Name = Utils.t("farm_auto_catch"), Info = Utils.t("farm_auto_catch_info"), CurrentValue = false, Callback = function(V) AppState.autoCatch = V end })

    CamTab:CreateSection(" " .. Utils.t("sec_farm_survival") .. " ")
    CamTab:CreateToggle({ Name = Utils.t("farm_auto_heal"), Info = Utils.t("farm_auto_heal_info"), CurrentValue = false, Callback = function(V) AppState.autoHeal = V end })
    CamTab:CreateSlider({ 
        Name = Utils.t("farm_heal_threshold"), 
        Info = Utils.t("farm_heal_threshold_info"),
        Range = {1, 3}, 
        Increment = 1, 
        Suffix = (Utils.getLang() == "vi" and " Pet" or " Pets"), 
        CurrentValue = 1, 
        Callback = function(V) AppState.healThreshold = V end 
    })
    CamTab:CreateToggle({ Name = Utils.t("farm_smart_return"), Info = Utils.t("farm_smart_return_info"), CurrentValue = false, Callback = function(V) AppState.autoReturnToFarm = V end })

    CamTab:CreateSection(" " .. Utils.t("sec_farm_navigation") .. " ")
    
    local function GetAreaNameById(areaId)
        if not areaId then return nil end
        if type(areaId) == "string" then return areaId end
        if Utils and type(Utils.GetAreaList) == "function" then
            local list = Utils.GetAreaList()
            for _, area in ipairs(list) do
                if area.id == areaId then
                    return area.name
                end
            end
        end
        return "Unknown (" .. tostring(areaId) .. ")"
    end

    local function GetFarmPosLabelText()
        if not AppState.savedFarmPosition then return Utils.t("farm_not_configured") end
        local pos = AppState.savedFarmPosition.Position
        local areaName = GetAreaNameById(AppState.savedFarmAreaId)
        if areaName then
            return string.format("📍 %s | %d, %d, %d", areaName, math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
        else
            return string.format("📍 %d, %d, %d", math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
        end
    end

    local FarmPosLabel = CamTab:CreateLabel(Utils.t("farm_center_label") .. GetFarmPosLabelText())

    CamTab:CreateButton({ 
        Name = Utils.t("btn_save_spot"), 
        Info = Utils.t("btn_save_spot_info"),
        Callback = function()
            local charData = GetValidCharacterData()
            if charData then
                AppState.savedFarmPosition = charData.RootPart.CFrame
                local currentAreaId = Utils.GetCurrentAreaId()
                AppState.savedFarmAreaId = currentAreaId
                
                Utils.SaveJSON(ConfigFiles.Position, {
                    X = charData.Position.X, 
                    Y = charData.Position.Y, 
                    Z = charData.Position.Z,
                    AreaId = currentAreaId
                })
                
                FarmPosLabel:Set(Utils.t("farm_center_label") .. GetFarmPosLabelText())
                SendNotify(Utils.t("saved_title"), Utils.t("farm_saved_msg"))
            end
        end
    })

    CamTab:CreateButton({ 
        Name = Utils.t("btn_teleport_spot"), 
        Info = Utils.t("btn_teleport_spot_info"),
        Callback = function()
            if AppState.savedFarmPosition then
                local charData = GetValidCharacterData()
                if charData then
                    local currentAreaId = Utils.GetCurrentAreaId()
                    if AppState.savedFarmAreaId and currentAreaId ~= AppState.savedFarmAreaId then
                        if type(AppState.savedFarmAreaId) == "string" then
                            SendNotify(Utils.t("tele_fail_title"), Utils.t("tele_abyss_fail_msg") .. AppState.savedFarmAreaId)
                            return
                        end
                        
                        SendNotify(Utils.t("tele_world_title"), Utils.t("tele_world_msg"))
                        pcall(function() Utils.TeleportToArea(AppState.savedFarmAreaId) end)
                        task.wait(6) -- Đợi 6 giây để map kịp tải dữ liệu
                        
                        charData = GetValidCharacterData()
                        if charData then
                            Utils.SafeTeleport(AppState.savedFarmPosition, 5)
                            SendNotify(Utils.t("tele_spot_title"), Utils.t("tele_spot_success_msg"))
                        end
                    else
                        SendNotify(Utils.t("tele_spot_title"), Utils.t("tele_spot_flying_msg"))
                        Utils.SafeTeleport(AppState.savedFarmPosition, 5)
                    end
                end
            else
                SendNotify(Utils.t("warning_title"), Utils.t("farm_not_saved_msg"))
            end
        end
    })

    -- ==========================================
    -- 6. TẦNG THỰC THI (BACKGROUND WORKERS / COROUTINES)
    -- ==========================================

    -- Luồng 1: Auto Attack Thường
    task.spawn(function()
        while task.wait(0.2) do
            if IsSystemBusy() or AppState.isHealing or AppState.tpFarmEnabled or not AppState.autoAttack then continue end
            
            local charData = GetValidCharacterData()
            if not charData then continue end
            
            local centerPos = AppState.savedFarmPosition and AppState.savedFarmPosition.Position or AppState.tempFarmPosition or charData.Position
            local validMonsters = Utils.SmartScanMonsters(centerPos, AppState.attackRadius, "Attack", IsMonsterInFilter)

            if SystemCache.MonsterSystem then
                for _, mData in ipairs(validMonsters) do
                    Utils.SmartDismount()
                    if mData.Id then pcall(function() SystemCache.MonsterSystem:ClientAttackMonster(mData.Id) end) end
                end
            end
        end
    end)

    -- Luồng 2: Auto Catch
    task.spawn(function()
        while task.wait(0.5) do
            if IsSystemBusy() or AppState.isHealing or not AppState.autoCatch then continue end
            
            local charData = GetValidCharacterData()
            if not charData then continue end

            local centerPos = AppState.savedFarmPosition and AppState.savedFarmPosition.Position or AppState.tempFarmPosition or charData.Position
            local catchableMonsters = Utils.SmartScanMonsters(centerPos, AppState.attackRadius, "Catch", IsMonsterInFilter)
            
            local targetCatch, minDist = nil, math.huge
            for _, mData in ipairs(catchableMonsters) do
                if mData.Distance < minDist then
                    minDist, targetCatch = mData.Distance, mData
                end
            end

            if targetCatch and SystemCache.MonsterSystem then
            -- Nếu quá gần (dưới 15 studs) thì không cần Teleport
            if minDist > 20 then
            task.wait(0.25)
                Utils.SafeTeleport(CFrame.new(targetCatch.Position), 5)
            end
            
                -- Task con xử lý Async việc ném bóng bắt quái
                task.spawn(function()
                    local success, isStarted = pcall(function() return SystemCache.MonsterSystem:ClientCatchMonsterStart(targetCatch.Id) end)
                    if success then
                        task.wait(isStarted and 1.5 or 5)
                        pcall(function() SystemCache.MonsterSystem:ClientCatchMonsterComplete(targetCatch.Id) end)
                    end
                end)
            end
        end
    end)

    -- Luồng 3: Teleport Farm (Không gian)
    task.spawn(function()
        while task.wait(0.1) do
            if not AppState.autoAttack or not AppState.tpFarmEnabled or IsSystemBusy() or AppState.isHealing then 
                pcall(function()
                    local platform = Workspace:FindFirstChild("FarmSafePlatform")
                    if platform then platform:Destroy() end
                end)
                continue 
            end

            local charData = GetValidCharacterData()
            if not charData then task.wait(1); continue end

            local centerPos = AppState.savedFarmPosition and AppState.savedFarmPosition.Position or AppState.tempFarmPosition or charData.Position
            
            -- Lọc quái thông minh thông qua thư viện Utils bên ngoài
            local allMonsters = Utils.SmartScanMonsters(centerPos, AppState.attackRadius, "Attack", IsMonsterInFilter)
            
            if not allMonsters or #allMonsters == 0 then task.wait(0.5); continue end

            local closestMonster, minDist = nil, math.huge
            for _, m in ipairs(allMonsters) do
                local distFromPlayer = (charData.Position - m.Position).Magnitude
                if distFromPlayer < minDist then
                    minDist, closestMonster = distFromPlayer, m
                end
            end
            
            if closestMonster and SystemCache.AttackRemote then
                local obj = closestMonster.Object
                local monsterRoot = nil
                if obj:IsA("Model") then
                    monsterRoot = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Root")
                elseif obj:IsA("BasePart") then
                    monsterRoot = obj
                end
                local targetPos = closestMonster.Position
                
                if monsterRoot then
                    -- Lấy vị trí phía sau lưng quái 5 studs (trên cùng mặt phẳng Y)
                    local backPos = (monsterRoot.CFrame * CFrame.new(0, 0, 5)).Position
                    targetPos = Vector3.new(backPos.X, closestMonster.Position.Y, backPos.Z)
                else
                    targetPos = closestMonster.Position + Vector3.new(0, 0, 5)
                end

                if (charData.Position - targetPos).Magnitude > 20 then
                    Utils.ToggleMount(true)
                    
                    -- Spawn safe platform underneath targetPos to prevent falling
                    pcall(function()
                        local platform = Workspace:FindFirstChild("FarmSafePlatform")
                        if not platform then
                            platform = Instance.new("Part")
                            platform.Name = "FarmSafePlatform"
                            platform.Size = Vector3.new(8, 1, 8)
                            platform.Transparency = 1
                            platform.Anchored = true
                            platform.CanCollide = true
                            platform.Parent = Workspace
                        end
                        platform.CFrame = CFrame.new(targetPos - Vector3.new(0, 3.5, 0))
                    end)

                    charData.RootPart.CFrame = CFrame.lookAt(targetPos, closestMonster.Position)
                end
                pcall(function() SystemCache.AttackRemote:InvokeServer("MonsterAttackChannel", closestMonster.Id) end)
                Utils.SmartDismount()
                task.wait(AppState.attackDelay + 0.1)
            end
        end
    end)

    -- Luồng 4: Smart Auto Heal (Chạy tuần tự với Mutex Lock)
    task.spawn(function()
        while task.wait(1) do
            if not AppState.autoHeal or AppState.isHealing then continue end

            -- Chỉ hồi máu ở Map thường (phải ở Open World và tồn tại MainLeftView)
            local isNormalMap = false
            pcall(function()
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local mainGui = playerGui and playerGui:FindFirstChild("MainGui")
                local screenGui = mainGui and mainGui:FindFirstChild("ScreenGui")
                
                -- Phải có MainLeftView
                local leftView = screenGui and screenGui:FindFirstChild("MainLeftView")
                
                -- Phải ở Open World (không ở trong phó bản/Rift)
                local mainRightView = screenGui and screenGui:FindFirstChild("MainRightView")
                local fmReturn = mainRightView and mainRightView:FindFirstChild("FmReturn")
                local btReturn = fmReturn and fmReturn:FindFirstChild("BtReturn")
                local isInOpenWorld = btReturn and btReturn.Visible or false
                
                isNormalMap = (leftView ~= nil) and isInOpenWorld
            end)
            if not isNormalMap then continue end

            local deadPetsCount = CalculatePetCasualties()
            if deadPetsCount >= AppState.healThreshold then
                -- Khóa State, báo hiệu cho các luồng Farm khác tạm dừng
                AppState.isHealing = true
                _G.IsSystemHealActive = true
                
                -- Xuống thú cưỡi trước khi di chuyển hồi máu
                Utils.SmartDismount()
                task.wait(0.2)
                
                local charData = GetValidCharacterData()
                if charData then
                    SendNotify("🔄 Auto Heal", "Pet đã kiệt sức. Tiến hành Teleport hồi máu...")
                    local safeReturnPos = charData.RootPart.CFrame
                    local bestRecoverPos = LocateNearestHealingSpring(charData.Position)

                    if bestRecoverPos then
                        -- Xử lý vật lý: Tạo bệ đỡ để chống lọt hố khi Map chưa kịp Render
                        local platform = Instance.new("Part")
                        platform.Size, platform.Position = Vector3.new(20, 1, 20), bestRecoverPos - Vector3.new(0, 3, 0)
                        platform.Anchored, platform.Transparency, platform.CanCollide = true, 1, true
                        platform.Parent = Workspace

                        charData.RootPart.CFrame = CFrame.new(bestRecoverPos + Vector3.new(0, 3, 0))
                        
                        -- Tác vụ chạy tuần tự (Sequential Blocking): Đợi máu hồi đầy (tối đa 9 giây)
                        local healTimeout = tick() + 9
                        while tick() < healTimeout do
                            task.wait(0.5)
                            if CalculatePetCasualties() == 0 then
                                break
                            end
                        end
                        
                        platform:Destroy()
                        Utils.SafeTeleport(safeReturnPos, 5)
                        SendNotify("✅ Hoàn Tất", "Đã khôi phục sinh lực Pet và về bãi farm!")
                    end
                end
                
                -- Mở khóa State
                _G.IsSystemHealActive = false
                AppState.isHealing = false
            end
        end
    end)

    -- Luồng 5: Smart Return (Bám bãi)
    task.spawn(function()
        while task.wait(1) do
            if IsSystemBusy() or AppState.isHealing or not AppState.autoReturnToFarm then continue end
            local returnPos = AppState.savedFarmPosition or (AppState.tempFarmPosition and CFrame.new(AppState.tempFarmPosition))
            if not returnPos then continue end
            if not (AppState.autoAttack or AppState.autoCatch) then continue end

            local charData = GetValidCharacterData()
            if not charData then continue end

            local maxAllowedDistance = AppState.attackRadius + 20
            if (charData.Position - returnPos.Position).Magnitude > maxAllowedDistance then
                -- Check Double-lock ngay trước khi bay
                if not IsSystemBusy() then
                    SendNotify("📍 Smart Return", "Hệ thống rảnh rỗi. Đang quay về tâm bãi Farm...")
                    Utils.SafeTeleport(returnPos, 5)
                    task.wait(2)
                end
            end
        end
    end)

end
end

modules['features/boss_hunt.txt'] = function(...)
-- ====================================================================
-- MODULE: SĂN BOSS TỔNG HỢP (SPECIAL & WORLD BOSS) - BẢN FINAL
-- Tích hợp Mutex Lock (SystemController) + Nội bộ nhường cờ + Giữ Lock 5 Phút
-- ====================================================================

local SPECIAL_BOSS_MAPPING = {
    [5]  = { "DustWing" },
    [6]  = { "Undine", "Walrusk" },
    [7]  = { "Cobaltwing" },
    [8]  = { "Ignisraptor" },
    [9]  = { "Bladetooth" },
    [10] = { "Stellar Sentinel" },
    [11] = { "Bull Lord" },
    [12] = { "Capshark", "Crabblaze" },
}

local WORLD_BOSS_MAPPING = {
    [2]  = { "Flaragon" },
    [3]  = { "Mountusk", "Glazadon" },
    [4]  = { "ShadeKnight" },
    [5]  = { "Gildron" },
    [6]  = { "Tidevex" },
    [7]  = { "Frostwyrm" },
    [8]  = { "Dracospike" },
    [9]  = { "Thunderclaw", "Crystalfae" },
    [10] = { "Lampyr" },
    [11] = { "Scareaper" },
    [12] = { "Beatopus" },
}

local SP_HUNT_TIMEOUT_SECS  = 180
local SP_ATTACK_EXTEND_SECS = 4
local SP_SCAN_LOG_INTERVAL  = 20
local SP_ATTACK_WAIT        = 0.1
local MAX_ATTACK_DISTANCE   = 20

local WB_WAVE_TIMER_FILE    = "RClient_BossGlobalTimer.json"
local WB_WAVE_DURATION_SECS = 300
local WB_SCAN_TIMEOUT_TICKS = 15
local WB_WAVE_COOLDOWN_SECS = 60
local WB_ATTACK_INTERVAL    = 1
local SHARED_TELEPORT_WAIT  = 3

return function(Window, Utils)
    -- ==========================================
    -- TRẠNG THÁI (STATE)
    -- ==========================================
    local spSettings = { enabled = false, selectedWorlds = {} }
    local spHuntState = {
        isActive      = false,
        targetBoss    = "",
        targetWorldId = nil,
        hasTeleported = false,
        engaged       = false,
        timeoutAt     = 0,
    }

    local wbSettings = { enabled = false, autoHop = false, selectedWorlds = {} }
    local wbHuntState = {
        isActive          = false,
        currentWorldIndex = 1,
        currentWorldId    = nil,
        hasTeleported     = false,
        engaged           = false,
        scanAttempts      = 0,
    }
    local wbLastWaveAlertTime = 0

    local monsterNameCache     = {}
    local internalMonsterTable = nil 

    -- ==========================================
    -- QUẢN LÝ CỜ (MUTEX LOCK) - BẢN BỌC THÉP
    -- ==========================================
    local function TryAcquireLock()
        local ctrl = _G.SystemController
        if ctrl then
            if ctrl.CurrentLock == "BossHunt" then return true end
            
            pcall(function()
                if type(ctrl.RequestLock) == "function" then
                    ctrl.RequestLock("BossHunt")
                end
            end)
            
            return ctrl.CurrentLock == "BossHunt"
        end
        return true 
    end

    local function TryReleaseLock()
        -- 1. Chặn trả cờ nếu 1 trong 2 luồng Săn Boss vẫn đang hoạt động
        if spHuntState.isActive or wbHuntState.isActive then return end
        
        _G.PendingBossHunt = false
        _G.PendingSpecialBoss = false
        
        -- 2. Thực hiện trả cờ cực kỳ an toàn
        local ctrl = _G.SystemController
        if ctrl and ctrl.CurrentLock == "BossHunt" then
            local success, err = pcall(function()
                -- Thử cả 2 cách gọi phổ biến nhất để chống crash ngầm
                if type(ctrl.ReleaseLock) == "function" then
                    ctrl.ReleaseLock("BossHunt") 
                elseif type(ctrl.releaseLock) == "function" then
                    ctrl.releaseLock("BossHunt")
                end
            end)
            
            if success then
                print("🏳️ [BOSS HUNT] Đã nhả cờ SystemController thành công!")
            else
                warn("⚠️ [BOSS HUNT] Lỗi khi nhả cờ (Crash ngầm): " .. tostring(err))
            end
        end
    end

    -- ==========================================
    -- HÀM DÙNG CHUNG (SHARED HELPERS)
    -- ==========================================
    local function EnsureMonsterTableLoaded()
        if internalMonsterTable then return end
        pcall(function()
            local pathTool = getrenv and getrenv()._G and getrenv()._G.PathTool
            if not (pathTool and pathTool.MgrMonsterClient) then return end
            local upvalues = debug.getupvalues(pathTool.MgrMonsterClient.GetMonsterInfo)
            if upvalues and type(upvalues[1]) == "table" then internalMonsterTable = upvalues[1] end
        end)
    end

    local function LookupMonsterNameFromConfig(uid)
        EnsureMonsterTableLoaded()
        if not (internalMonsterTable and type(internalMonsterTable) == "table") then return nil end
        local rawData = internalMonsterTable[uid]
        if type(rawData) ~= "table" then return nil end
        local tmplId = rawData.TmplId or rawData.tmplId or rawData.cfgId
        if not tmplId then return nil end

        local ok, result = pcall(function()
            local pathTool = getrenv()._G.PathTool
            if not (pathTool.CfgMonster and pathTool.CfgMonster.Tmpls) then return nil end
            local cfg = pathTool.CfgMonster.Tmpls[tostring(tmplId)] or pathTool.CfgMonster.Tmpls[tonumber(tmplId)]
            return cfg and (cfg.Name or cfg.name or cfg.Title)
        end)
        return ok and result or nil
    end

    local function GetMonsterDisplayName(monsterObj)
        if not monsterObj then return "Unknown" end
        local uidStr = string.match(monsterObj.Name, "Monster_(%d+)")
        if not uidStr then return monsterObj.Name end
        local uid = tonumber(uidStr)
        if monsterNameCache[uid] then return monsterNameCache[uid] end
        local resolved = LookupMonsterNameFromConfig(uid)
        if resolved then
            monsterNameCache[uid] = resolved
            return resolved
        end
        return monsterObj.Name
    end

    local function GetRootPart(obj)
        if obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Root")
        elseif obj:IsA("BasePart") then
            return obj
        end
        return nil
    end

    local function SharedTeleportToBoss(hrp, bossPosition)
        Utils.ToggleMount(true)
        task.wait(0.5)
        hrp.CFrame = CFrame.new(bossPosition + Vector3.new(0, 8, 0))
    end

    local function SaveWbWaveEndTime()
        Utils.SaveJSON(WB_WAVE_TIMER_FILE, { EndTime = os.time() + WB_WAVE_DURATION_SECS })
    end

    local function ReadWbWaveTimer()
        local data = Utils.LoadJSON(WB_WAVE_TIMER_FILE)
        if not (data and data.EndTime) then return false, 0 end
        local timeLeft = data.EndTime - os.time()
        return timeLeft > 0, math.max(timeLeft, 0)
    end

    -- ==========================================
    -- GIAO DIỆN (UI)
    -- ==========================================
    local BossTab = Window:CreateTab(Utils.t("boss"), "skull")

    -- [UI] SPECIAL BOSS
    BossTab:CreateSection(" " .. Utils.t("sec_sp_boss") .. " ")
    local spStatusLabel = BossTab:CreateLabel(Utils.t("sp_boss_idle"))

    BossTab:CreateToggle({
        Name = Utils.t("auto_sp_boss"),
        Info = Utils.t("auto_sp_boss_info"),
        CurrentValue = false,
        Flag = "EnableSpecialBoss",
        Callback = function(isEnabled) 
            spSettings.enabled = isEnabled 
            if not isEnabled then 
                spHuntState.isActive = false
                TryReleaseLock()
            end
        end,
    })

    local spAllowedWorldIds = {}
    for worldId in pairs(SPECIAL_BOSS_MAPPING) do table.insert(spAllowedWorldIds, worldId) end
    Utils.CreateFilteredAreaMultiSelect(BossTab, {
        name = Utils.t("select_sp_worlds"),
        flag = "SpBossWorldSelect",
        allowedIds = spAllowedWorldIds,
        callback = function(selectedIds) spSettings.selectedWorlds = selectedIds end,
    })

    -- [UI] WORLD BOSS
    BossTab:CreateSection(" " .. Utils.t("sec_wb_boss") .. " ")
    local wbStatusLabel = BossTab:CreateLabel(Utils.t("wb_boss_idle"))

    local function StartWbHuntFromFirstWorld()
        wbHuntState.currentWorldIndex = 1
        wbHuntState.currentWorldId    = tonumber(wbSettings.selectedWorlds[1])
        wbHuntState.hasTeleported     = false
        wbHuntState.engaged           = false
        wbHuntState.scanAttempts      = 0
        wbHuntState.isActive          = true
    end

    BossTab:CreateToggle({
        Name = Utils.t("auto_wb_boss"),
        Info = Utils.t("auto_wb_boss_info"),
        CurrentValue = false,
        Flag = "EnableWorldBoss",
        Callback = function(isEnabled)
            wbSettings.enabled = isEnabled
            if isEnabled then
                if #wbSettings.selectedWorlds > 0 then
                    print("🌍 [WORLD BOSS] Đã nhận lệnh. Đang xin Hệ thống cấp cờ...")
                    StartWbHuntFromFirstWorld()
                    wbStatusLabel:Set(Utils.t("boss_req_lock"))
                else
                    print("⚠️ [WORLD BOSS] Chưa chọn đảo nào!")
                    wbStatusLabel:Set(Utils.t("boss_no_world"))
                    wbHuntState.isActive = false
                end
            else
                wbHuntState.isActive = false
                wbStatusLabel:Set(Utils.t("tracker_stopped"))
                TryReleaseLock()
            end
        end,
    })

    local wbAllowedWorldIds = {}
    for worldId in pairs(WORLD_BOSS_MAPPING) do table.insert(wbAllowedWorldIds, worldId) end
    Utils.CreateFilteredAreaMultiSelect(BossTab, {
        name = Utils.t("select_wb_worlds"),
        flag = "WbBossWorldSelect",
        allowedIds = wbAllowedWorldIds,
        callback = function(selectedIds) wbSettings.selectedWorlds = selectedIds end,
    })

    BossTab:CreateToggle({
        Name = Utils.t("auto_hop_boss"),
        Info = Utils.t("auto_hop_boss_info"),
        CurrentValue = false,
        Flag = "WbAutoHop",
        Callback = function(isEnabled) wbSettings.autoHop = isEnabled end,
    })

    -- ==========================================
    -- HÀM LOGIC QUÉT
    -- ==========================================
    local function FindSpWorldByBossName(bossName)
        local lowerName = string.lower(bossName)
        for worldId, keywords in pairs(SPECIAL_BOSS_MAPPING) do
            for _, kw in ipairs(keywords) do
                if string.find(lowerName, string.lower(kw), 1, true) then return worldId end
            end
        end
        return nil
    end

    local function IdentifyWbWorldByBossName(bossName)
        local lowerName = string.lower(bossName)
        for worldId, keywords in pairs(WORLD_BOSS_MAPPING) do
            for _, kw in ipairs(keywords) do
                if string.find(lowerName, string.lower(kw), 1, true) then return worldId end
            end
        end
        return nil
    end

    local function ScanBossesList(targetMapping)
        local targets = {}
        local folders = {"Monsters", "ClientMonsters"}
        for _, fName in ipairs(folders) do
            local folder = workspace:FindFirstChild(fName)
            if folder then
                for _, obj in pairs(folder:GetChildren()) do
                    local root = GetRootPart(obj)
                    if root then
                        local displayName = GetMonsterDisplayName(obj)
                        local lowerName = string.lower(displayName)
                        for _, kw in ipairs(targetMapping) do
                            if string.find(lowerName, string.lower(kw), 1, true) then
                                local uidStr = string.match(obj.Name, "Monster_(%d+)")
                                table.insert(targets, {
                                    Id = uidStr and tonumber(uidStr) or obj.Name,
                                    Name = displayName,
                                    Position = root.Position,
                                })
                                break
                            end
                        end
                    end
                end
            end
        end
        return targets
    end

    -- ==========================================
    -- LUỒNG CẢM BIẾN (UNIFIED SENSOR)
    -- ==========================================
    task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        local lastProcessedText = ""

        while task.wait(0.5) do
            pcall(function()
                local playerGui = localPlayer:FindFirstChild("PlayerGui")
                if not playerGui then return end
                local fmBubble = playerGui:FindFirstChild("FmBubble", true)
                if not fmBubble then return end
                local labName = fmBubble:FindFirstChild("LabName", true)
                if not labName then return end

                local currentText = labName.Text
                if currentText == "" or currentText == "Label" or currentText == lastProcessedText then return end
                lastProcessedText = currentText

                -- Kiểm tra Special Boss
                if spSettings.enabled and not spHuntState.isActive then
                    local spWorldId = FindSpWorldByBossName(currentText)
                    local isAllowed = false
                    for _, aId in pairs(spSettings.selectedWorlds) do if tonumber(aId) == tonumber(spWorldId) then isAllowed = true break end end
                    
                    if spWorldId and isAllowed then
                        print("🔔 [CẢM BIẾN] Bắt được Special Boss: '" .. currentText .. "' tại Đảo " .. spWorldId)
                        spHuntState.targetBoss    = currentText
                        spHuntState.targetWorldId = tonumber(spWorldId)
                        spHuntState.hasTeleported = false
                        spHuntState.engaged       = false
                        spHuntState.isActive      = true
                        spHuntState.timeoutAt     = os.time() + SP_HUNT_TIMEOUT_SECS
                        spStatusLabel:Set(Utils.t("boss_signal") .. currentText)
                        return
                    end
                end

                -- Kiểm tra World Boss
                if wbSettings.enabled and not wbHuntState.isActive then
                    local wbWorldId = IdentifyWbWorldByBossName(currentText)
                    if wbWorldId then
                        if os.time() - wbLastWaveAlertTime >= WB_WAVE_COOLDOWN_SECS then
                            wbLastWaveAlertTime = os.time()
                            SaveWbWaveEndTime()
                            
                            if #wbSettings.selectedWorlds > 0 then
                                print("⚔️ [SÓNG WORLD BOSS] Kích hoạt càn quét (Tín hiệu: " .. currentText .. ")")
                                StartWbHuntFromFirstWorld()
                                wbStatusLabel:Set(Utils.t("wb_wave_start"))
                            end
                        end
                    end
                end
            end)
        end
    end)

    -- ==========================================
    -- LUỒNG HUNTER: SPECIAL BOSS
    -- ==========================================
    task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer
        local scanLogCooldown = 0

        while task.wait(0.1) do
            if not spSettings.enabled or not spHuntState.isActive then 
                _G.PendingSpecialBoss = false
                continue 
            end
            _G.PendingSpecialBoss = true

            if _G.IsSystemHealActive then
                task.wait(0.5)
                continue
            end

            if not TryAcquireLock() then 
                spStatusLabel:Set(Utils.t("boss_req_lock")) 
                continue 
            end

            if os.time() > spHuntState.timeoutAt then
                local reason = spHuntState.engaged and ("☠️ Đã dọn xong: " .. spHuntState.targetBoss) or ("⏱️ Hết giờ tìm: " .. spHuntState.targetBoss)
                spHuntState.isActive = false
                spStatusLabel:Set(Utils.t("status_prefix") .. reason)
                print("[SPECIAL] " .. reason)
                TryReleaseLock()
                continue
            end

            local targets = ScanBossesList({string.lower(spHuntState.targetBoss)})
            local ok, remote = pcall(function() return game.ReplicatedStorage:FindFirstChild("CommonLibrary").Tool.RemoteManager.Funcs:FindFirstChild("DataPullFunc") end)
            remote = ok and remote or nil

            if #targets > 0 and remote then
                local boss = targets[1]
                if not spHuntState.engaged then
                    print("🎯 [SPECIAL] Thấy Boss '" .. boss.Name .. "'! Vào việc...")
                    spHuntState.engaged = true
                end

                spStatusLabel:Set(Utils.t("boss_attacking") .. boss.Name)
                local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp and boss.Position and (hrp.Position - boss.Position).Magnitude > MAX_ATTACK_DISTANCE then
                    SharedTeleportToBoss(hrp, boss.Position)
                    task.wait(0.5)
                end

                task.wait(SP_ATTACK_WAIT)
                pcall(function() remote:InvokeServer("MonsterAttackChannel", boss.Id) end)
                Utils.SmartDismount()

                spHuntState.timeoutAt = os.time() + SP_ATTACK_EXTEND_SECS
            else
                if not spHuntState.hasTeleported then
                    spStatusLabel:Set(Utils.t("boss_teleporting") .. tostring(spHuntState.targetWorldId))
                    spHuntState.hasTeleported = true
                    pcall(function() Utils.TeleportToArea(spHuntState.targetWorldId) end)
                    task.wait(SHARED_TELEPORT_WAIT)
                else
                    scanLogCooldown += 1
                    if scanLogCooldown >= SP_SCAN_LOG_INTERVAL then scanLogCooldown = 0 end
                    spStatusLabel:Set(Utils.t("boss_waiting_spawn") .. spHuntState.targetBoss)
                end
            end
        end
    end)

    -- ==========================================
    -- LUỒNG HUNTER: WORLD BOSS
    -- ==========================================
    task.spawn(function()
        local localPlayer = game:GetService("Players").LocalPlayer

        while task.wait(0.2) do
            if not wbSettings.enabled or not wbHuntState.isActive then 
                _G.PendingBossHunt = false
                continue 
            end
            _G.PendingBossHunt = true

            if _G.IsSystemHealActive then
                task.wait(0.5)
                continue
            end

            -- NHƯỜNG CỜ NỘI BỘ: Đợi Special đánh xong, mình không nhả cờ ra ngoài Hệ thống
            if spHuntState.isActive then
                wbStatusLabel:Set(Utils.t("wb_yield_sp"))
                continue
            end

            if not TryAcquireLock() then 
                wbStatusLabel:Set(Utils.t("boss_req_lock")) 
                continue 
            end

            local targets = ScanBossesList(WORLD_BOSS_MAPPING[wbHuntState.currentWorldId] or {})

            if #targets > 0 then
                local boss = targets[1]
                if not wbHuntState.engaged then
                    print("🎯 [WORLD] Thấy Boss '" .. boss.Name .. "' tại đảo " .. wbHuntState.currentWorldId)
                    wbHuntState.engaged = true
                    local isWaveActive, _ = ReadWbWaveTimer()
                    if not isWaveActive then SaveWbWaveEndTime() end
                end

                wbStatusLabel:Set(Utils.t("wb_defeating") .. boss.Name)
                local hrp = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp and boss.Position and (hrp.Position - boss.Position).Magnitude > MAX_ATTACK_DISTANCE then
                    -- Kiểm tra lại xem Special Boss có chen ngang không trước khi teleport
                    if spHuntState.isActive then
                        wbStatusLabel:Set(Utils.t("wb_yield_sp"))
                        continue
                    end
                    SharedTeleportToBoss(hrp, boss.Position)
                    task.wait(0.5)
                end

                if spHuntState.isActive then
                    wbStatusLabel:Set(Utils.t("wb_yield_sp"))
                    continue
                end
                Utils.AttackMonster(boss.Id)
                task.wait(WB_ATTACK_INTERVAL)
                wbHuntState.scanAttempts = 0
            else
                if not wbHuntState.hasTeleported then
                    wbStatusLabel:Set(Utils.t("boss_teleporting") .. tostring(wbHuntState.currentWorldId))
                    if spHuntState.isActive then
                        wbStatusLabel:Set(Utils.t("wb_yield_sp"))
                        continue
                    end
                    pcall(function() Utils.TeleportToArea(wbHuntState.currentWorldId) end)
                    wbHuntState.hasTeleported = true
                    task.wait(SHARED_TELEPORT_WAIT)
                else
                    wbHuntState.scanAttempts += 1
                    if wbHuntState.scanAttempts <= WB_SCAN_TIMEOUT_TICKS then
                        wbStatusLabel:Set(Utils.t("wb_scanning") .. "(" .. wbHuntState.scanAttempts .. "/" .. WB_SCAN_TIMEOUT_TICKS .. ")")
                    else
                        local nextIndex = wbHuntState.currentWorldIndex + 1
                        local isWaveActive, timeLeft = ReadWbWaveTimer()

                        if nextIndex > #wbSettings.selectedWorlds then
                            wbHuntState.isActive = false
                            
                            local isWaveActive, timeLeft = ReadWbWaveTimer()
                            
                            if wbSettings.autoHop and isWaveActive then
                                wbStatusLabel:Set(Utils.t("wb_loop_done_hop") .. math.floor(timeLeft) .. "s")
                                print("🔄 [WORLD BOSS] Còn thời gian, gửi lệnh Hop Server...")
                                if Utils.RequestHop then Utils.RequestHop("Boss_AutoHop", 2) end
                            else
                                wbStatusLabel:Set(Utils.t("wb_loop_done_wait"))
                                print("💤 [WORLD BOSS] Sóng kết thúc, dừng Hop.")
                                
                                wbLastWaveAlertTime = os.time() 
                                TryReleaseLock() -- Nhả cờ an toàn
                            end
                        else
                            wbHuntState.currentWorldIndex = nextIndex
                            wbHuntState.currentWorldId    = tonumber(wbSettings.selectedWorlds[nextIndex])
                            wbHuntState.hasTeleported     = false
                            wbHuntState.engaged           = false
                            wbHuntState.scanAttempts      = 0
                        end
                    end
                end
            end
        end
    end)
end
end

modules['features/server_manager.txt'] = function(...)
-- ====================================================================
-- MODULE: QUẢN LÝ SERVER & AUTO HOP (V4.2 - FULL PERSISTENT STATE)
-- ====================================================================
return function(Window, Utils)
    local Players = game:GetService("Players")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local CoreGui = game:GetService("CoreGui")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local LocalPlayer = Players.LocalPlayer
    
    -- ==========================================
    -- HỆ THỐNG CACHE TRẠNG THÁI (STATE PERSISTENCE)
    -- ==========================================
    local configFileName = "WeatherAutoHop_State.json"
    local weatherHopSettings = { 
        enabled = false, 
        targetIds = {60001},
        selectedNames = {"🔴 Huyết Nguyệt (Blood Moon)"} 
    }
    local autoRejoinEnabled = false -- Biến cấu hình nút Rejoin
    local sessionStartTime = os.time()

    -- Khôi phục trạng thái từ file JSON cục bộ
    pcall(function()
        if isfile and isfile(configFileName) then
            local rawData = readfile(configFileName)
            local parsedData = HttpService:JSONDecode(rawData)
            if parsedData then
                weatherHopSettings.enabled = parsedData.enabled or false
                weatherHopSettings.targetIds = parsedData.targetIds or {60001}
                weatherHopSettings.selectedNames = parsedData.selectedNames or {"🔴 Huyết Nguyệt (Blood Moon)"}
                autoRejoinEnabled = parsedData.autoRejoinEnabled or false -- Khôi phục cấu hình Rejoin
            end
        end
    end)

    -- Hàm lưu trạng thái tổng hợp
    local function SaveState()
        pcall(function()
            if writefile then
                local dataToSave = {
                    enabled = weatherHopSettings.enabled,
                    targetIds = weatherHopSettings.targetIds,
                    selectedNames = weatherHopSettings.selectedNames,
                    autoRejoinEnabled = autoRejoinEnabled -- Đóng gói cấu hình Rejoin vào JSON
                }
                local jsonData = HttpService:JSONEncode(dataToSave)
                writefile(configFileName, jsonData)
            end
        end)
    end

    _G.ServerManager = {
        pauseFarm = false,
        currentWeather = "Bình Thường"
    }

    -- ==========================================
    -- ==========================================
    -- GIAO DIỆN UI
    -- ==========================================
    local ServerTab = Window:CreateTab(Utils.t("server"), "server")

    ServerTab:CreateSection(" " .. Utils.t("sec_session_info") .. " ")
    local SessionLabel = ServerTab:CreateLabel(Utils.t("active_time_label") .. "00:00:00")

    task.spawn(function()
        while task.wait(1) do
            local diff = os.time() - sessionStartTime
            local hours = math.floor(diff / 3600)
            local minutes = math.floor((diff % 3600) / 60)
            local seconds = diff % 60
            SessionLabel:Set(Utils.t("active_time_label") .. string.format("%02d:%02d:%02d", hours, minutes, seconds))
        end
    end)

    ServerTab:CreateSection(" " .. Utils.t("sec_weather_hunt") .. " ")

    local WeatherMap = {
        ["Ban Ngày (Day)"] = 10001, ["Ban Đêm (Night)"] = 10002, ["Nhiều Mây (Cloudy)"] = 20002,
        ["Trời Mưa (Rainy)"] = 30001, ["Trời Tuyết (Snowy)"] = 30002, ["Cực Quang (Aurora)"] = 30003,
        ["Sấm Sét (Lightning)"] = 40001, ["🔴 Huyết Nguyệt (Blood Moon)"] = 60001,
        ["🐉 Hoàng Hôn Rồng (Draconic Twilight)"] = 60002, ["🌟 Hào Quang Rồng (Dragon-Glow)"] = 60003,
        ["🧚 Màn Sương Ảo Mộng (Dreamveil)"] = 60004
    }

    ServerTab:CreateDropdown({
        Name = Utils.t("select_weather"),
        Options = {
            "Trời Mưa (Rainy)", "Trời Tuyết (Snowy)", "Cực Quang (Aurora)", "Sấm Sét (Lightning)",
            "🔴 Huyết Nguyệt (Blood Moon)", "🐉 Hoàng Hôn Rồng (Draconic Twilight)", 
            "🌟 Hào Quang Rồng (Dragon-Glow)", "🧚 Màn Sương Ảo Mộng (Dreamveil)"
        },
        CurrentOption = weatherHopSettings.selectedNames,
        MultipleOptions = true,
        Callback = function(Options)
            weatherHopSettings.selectedNames = Options
            weatherHopSettings.targetIds = {}
            for _, selectedOption in ipairs(Options) do
                if WeatherMap[selectedOption] then 
                    table.insert(weatherHopSettings.targetIds, WeatherMap[selectedOption]) 
                end
            end
            SaveState()
        end,
    })

    ServerTab:CreateToggle({
        Name = Utils.t("auto_weather_hop"),
        Info = Utils.t("auto_weather_hop_info"),
        CurrentValue = weatherHopSettings.enabled,
        Callback = function(Value) 
            weatherHopSettings.enabled = Value 
            SaveState()
        end
    })

    -- ==========================================
    -- HÀM MANUAL HOP
    -- ==========================================
    local isManualTeleporting = false
    local function ManualHop(mode)
        if isManualTeleporting then return end
        isManualTeleporting = true
        
        local PlaceId = game.PlaceId
        pcall(function()
            local api = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
            local data = game:HttpGet(api)
            local json = HttpService:JSONDecode(data)
            
            if json and json.data then
                local validServers = {}
                for _, v in pairs(json.data) do
                    if v.id and v.id ~= game.JobId then
                        local playing = v.playing or 0
                        local maxPlayers = v.maxPlayers or 0
                        if playing < maxPlayers then
                            table.insert(validServers, {id = v.id, playing = playing})
                        end
                    end
                end
                
                if #validServers > 0 then
                    table.sort(validServers, function(a, b) return a.playing < b.playing end)
                    
                    local targetId
                    if mode == "least" then
                        targetId = validServers[1].id
                    else
                        targetId = validServers[math.random(1, #validServers)].id
                    end
                    
                    if targetId then
                        game.StarterGui:SetCore("SendNotification", {
                            Title = Utils.t("server_tab"), 
                            Text = mode == "least" and Utils.t("hop_least_msg") or Utils.t("hop_random_msg"),
                            Duration = 5
                        })
                        TeleportService:TeleportToPlaceInstance(PlaceId, targetId, LocalPlayer)
                    end
                end
            end
        end)
        task.wait(2)
        isManualTeleporting = false
    end

    -- ==========================================
    -- ĐIỀU KHIỂN THỦ CÔNG & ANTI-KICK
    -- ==========================================
    ServerTab:CreateSection(" " .. Utils.t("sec_manual_control") .. " ")

    ServerTab:CreateButton({ 
        Name = Utils.t("btn_join_least"), 
        Info = Utils.t("btn_join_least_info"),
        Callback = function() ManualHop("least") end 
    })
    
    ServerTab:CreateButton({ 
        Name = Utils.t("btn_join_random"), 
        Info = Utils.t("btn_join_random_info"),
        Callback = function() ManualHop("random") end 
    })
    
    ServerTab:CreateButton({ 
        Name = Utils.t("btn_join_same"), 
        Info = Utils.t("btn_join_same_info"),
        Callback = function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end 
    })

    ServerTab:CreateSection(" " .. Utils.t("sec_anti_kick") .. " ")
    ServerTab:CreateToggle({
        Name = Utils.t("auto_rejoin"),
        Info = Utils.t("auto_rejoin_info"),
        CurrentValue = autoRejoinEnabled, -- Đồng bộ từ Cache cứu vớt khi chuyển server
        Callback = function(Value) 
            autoRejoinEnabled = Value 
            SaveState() -- Ghi nhớ trạng thái ngay lập tức
        end,
    })

    -- LUỒNG QUÉT POPUP ERROR 279
    task.spawn(function()
        while task.wait(0.5) do
            if not autoRejoinEnabled then continue end
            
            local found = false
            local isError279 = false
            
            pcall(function()
                local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui")
                if promptOverlay then
                    for _, child in pairs(promptOverlay:GetDescendants()) do
                        if child:IsA("TextLabel") or child:IsA("TextButton") then
                            local txt = child.Text or ""
                            if string.find(txt, "Connection Failed") or string.find(txt, "Error Code: 279") then
                                found = true
                                isError279 = true
                                break
                            elseif string.find(txt, "Disconnected") or string.find(txt, "Error Code") then
                                found = true
                                break
                            end
                        end
                    end
                end
            end)
            
            if found then
                game.StarterGui:SetCore("SendNotification", {
                    Title = "🔁 Auto Rejoin", 
                    Text = isError279 and "Phát hiện lỗi 279, đang Cancel và kết nối lại..." or "Phát hiện bị kick, đang kết nối lại...",
                    Duration = 3
                })
                
                pcall(function()
                    local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui")
                    if promptOverlay then
                        for _, child in pairs(promptOverlay:GetDescendants()) do
                            if child:IsA("TextButton") and (string.find(child.Text, "Cancel") or string.find(child.Text, "Retry")) then
                                local absPos = child.AbsolutePosition
                                local absSize = child.AbsoluteSize
                                local centerX = absPos.X + (absSize.X / 2)
                                local centerY = absPos.Y + (absSize.Y / 2)
                                VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
                                task.wait(0.05)
                                VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
                                break
                            end
                        end
                    end
                end)
                
                task.wait(1)
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end
    end)

    -- ==========================================
    -- MASTER LOOP: ĐIỀU PHỐI THỜI TIẾT (CÓ TÔN TRỌNG BOSS & DUNGEON)
    -- ==========================================
    task.spawn(function()
        local currentlyInTargetWeather = false
        local lastHopTime = 0 
        local HOP_COOLDOWN = 10 

        while task.wait(2) do
            local controller = _G.SystemController
            
            if controller and controller.IsPaused and not currentlyInTargetWeather then 
                continue 
            end

            if weatherHopSettings.enabled then
                local env = getrenv()._G.PathTool
                local isTarget = false
                local activeTargetName = ""

                if env and env.WeatherSystem and type(env.WeatherSystem.IsWeatherActive) == "function" then
                    for _, tid in ipairs(weatherHopSettings.targetIds) do
                        local ok, isActive = pcall(function() return env.WeatherSystem.IsWeatherActive(tid) end)
                        if ok and isActive then
                            isTarget = true
                            for name, id in pairs(WeatherMap) do
                                if id == tid then activeTargetName = name break end
                            end
                            break
                        end
                    end
                end

                if isTarget then
                    -- 🌤️ THỜI TIẾT ĐÚNG MỤC TIÊU -> NHẢ LOCK ĐỂ AI LÀM GÌ THÌ LÀM
                    if not currentlyInTargetWeather then
                        print("[Weather] ✅ Đã tìm thấy thời tiết VIP: " .. tostring(activeTargetName))
                        game.StarterGui:SetCore("SendNotification", { Title = "🌤️ Thời Tiết VIP", Text = "Đang ở: " .. activeTargetName, Duration = 5 })
                        currentlyInTargetWeather = true
                        
                        if controller and controller.CurrentLock == "WeatherHop" then
                            controller.ReleaseLock("WeatherHop")
                        end
                    end
                else
                    -- 🌪️ THỜI TIẾT RÁC -> KIỂM TRA XEM CÓ ĐƯỢC PHÉP NHẢY SERVER KHÔNG
                    currentlyInTargetWeather = false
                    
                    local canHop = true
                    if controller and controller.CurrentLock then
                        local lock = controller.CurrentLock
                        -- DANH SÁCH VIP: Nếu đang làm các việc này thì cấm ngặt việc nhảy Server
                        if lock == "BossHunt" or lock == "SpecialBoss" or lock == "AutoDungeon" or lock == "AutoRift" then
                            canHop = false
                        end
                    end
                    
                    if canHop then
                        -- Không vướng VIP, được phép đạp Auto Farm ra và nhảy Server
                        if (os.time() - lastHopTime) >= HOP_COOLDOWN then
                            lastHopTime = os.time()
                            
                            print("🚨 [Weather] Thời tiết rác! Đang Server Hop...")
                            if controller then controller.CurrentLock = "WeatherHop" end
                            
                            task.spawn(function()
                                pcall(function() Utils.HopServer("Săn Thời Tiết VIP") end)
                            end)
                            
                            task.wait(10)
                        end
                    else
                        -- Đang vướng Boss hoặc Dungeon -> Chấp nhận ở lại cày cho xong
                        -- Print log ra để bạn biết nó đang nhịn (bạn có thể xóa dòng print này nếu sợ trôi F9)
                        print("[Weather] ⏳ Thời tiết xấu nhưng đang vướng " .. controller.CurrentLock .. ", nhẫn nhịn chờ xong việc...")
                    end
                end
            end
        end
    end)
    
    print("✅ Server Manager 4.2 (Full Persistence Loaded!)")
end

end

modules['features/shops_and_guis.txt'] = function(...)
-- ====================================================================
-- MODULE: SHOPS & GUIS (MỞ GIAO DIỆN XUYÊN TƯỜNG / BYPASS UI)
-- ====================================================================
return function(Window, Utils)
    -- Tạo một Tab mới trên giao diện Rayfield
    local GuiTab = Window:CreateTab(Utils.t("gui"), "shopping-cart") 

    -- ==========================================
    -- HÀM XỬ LÝ CỐT LÕI (BYPASS UI)
    -- ==========================================
    local function OpenGameUI(viewName, ...)
        local args = {...}
        local success, err = pcall(function()
            local env = getrenv()._G.PathTool
            if env then
                -- Ưu tiên dùng ViewManagerBase với DẤU CHẤM
                if env.ViewManagerBase and type(env.ViewManagerBase.OpenView) == "function" then
                    env.ViewManagerBase.OpenView(viewName, unpack(args))
                
                -- Phương án dự phòng: Gọi thẳng hàm OnOpen
                elseif env[viewName] and type(env[viewName].OnOpen) == "function" then
                    env[viewName].OnOpen(unpack(args))
                end
            end
        end)
        
        if success then
            game.StarterGui:SetCore("SendNotification", {
                Title = Utils.t("gui_open_title"), 
                Text = Utils.t("gui_open_success") .. viewName, 
                Duration = 2
            })
        else
            game.StarterGui:SetCore("SendNotification", {
                Title = Utils.t("warning_title"), 
                Text = Utils.t("gui_open_fail") .. viewName, 
                Duration = 2
            })
        end
    end

    -- ==========================================
    -- GIAO DIỆN NÚT BẤM (BUTTONS)
    -- ==========================================
    GuiTab:CreateSection(" " .. Utils.t("sec_tele_maps") .. " ")
    GuiTab:CreateButton({
        Name = Utils.t("btn_area_tele"),
        Info = Utils.t("open_view_info"),
        Callback = function() OpenGameUI("AreaTeleportView") end
    })

    GuiTab:CreateSection(" " .. Utils.t("sec_bags") .. " ")
    GuiTab:CreateButton({ Name = Utils.t("btn_item_bag"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("ItemBagView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_bag"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetBagView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_team"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetTeamView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_enhance"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetEvolveView") end })

    GuiTab:CreateSection(" " .. Utils.t("sec_shops") .. " ")
    GuiTab:CreateButton({ Name = Utils.t("btn_store"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("StoreView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_catcher_shop"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("CatcherShopView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_tower_shop"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("TowerShopView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_craft"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("SyntheticView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_abyss_shop"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("AbyssShopView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_gear_roll"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetGearRollView") end })

    GuiTab:CreateSection(" " .. Utils.t("sec_events") .. " ")
    GuiTab:CreateButton({ Name = Utils.t("btn_tasks"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("TaskView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_activity"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("ActivityView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_medal"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("MedalView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_achieve"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("AchieveView") end })

    GuiTab:CreateSection(" " .. Utils.t("sec_recycle") .. " ")
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_vault"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetVaultView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_recycle"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetRecycleView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_collect"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetCollectView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_ride"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetRideView") end })
    GuiTab:CreateButton({ Name = Utils.t("btn_pet_transform"), Info = Utils.t("open_view_info"), Callback = function() OpenGameUI("PetTransformView") end })
end
end

modules['features/auto_dungeon.txt'] = function(...)
-- ====================================================================
-- MODULE: DUNGEON AUTO (AUTO ATTACK, AUTO EXIT, AUTO JOIN & AUTO CREATE)
-- BẢN CẬP NHẬT: TÍCH HỢP HỆ THỐNG ƯU TIÊN SỐ 1 & NHƯỜNG ĐƯỜNG CHO BOSS
-- ====================================================================
return function(Window, Utils, WebhookModule)
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    
    local LocalPlayer = Players.LocalPlayer
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local myUserId = LocalPlayer.UserId

    -- Biến trạng thái hệ thống
    local masterSwitchEnabled = false
    local autoExitEnabled = false
    local autoExitTriggered = false
    local stage20ClockStarted = false
    local autoAttackEnabled = false
    local autoJoinOthersEnabled = false
    local autoCreateEnabled = false
    local targetPlayerCount = 1
    local targetDifficulty = 1 
    
    local dungeonStuckTimer = 0
    local dungeonLastPosition = nil
    local isStartingDungeon = false
    
    -- Các biến mới phục vụ logic đếm giờ đi ké
    local hostMissingTime = nil
    local waitingForHost = false
    local dungeonCompletionTime = 0
    local waitHostTimeoutMinutes = 1 -- Mặc định là 1 phút

    -- API Game
    local AbyssSystem = nil
    pcall(function() AbyssSystem = require(ReplicatedStorage.CommonLogic.Abyss.AbyssSystem) end)

    -- ==========================================
    -- ĐĂNG KÝ VỚI MAIN CONTROLLER
    -- ==========================================
    local function DungeonToggle(Value)
        masterSwitchEnabled = Value
        if not Value then
            pcall(function()
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Humanoid") then
                    char.Humanoid:MoveTo(char.HumanoidRootPart.Position)
                end
            end)
            if _G.SystemController then _G.SystemController.ReleaseLock("AutoDungeon") end
        end
    end

    if _G.SystemController and type(_G.SystemController.registerModule) == "function" then
        _G.SystemController:registerModule("dungeon", DungeonToggle)
    end

    -- ==========================================
    -- HÀM REMOTE: LÊN / XUỐNG THÚ
    -- ==========================================
    local function ToggleMount(state)
        pcall(function()
            local args = { "PetSwitchRideStatusChannel", state }
            ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager"):WaitForChild("Funcs"):WaitForChild("DataPullFunc"):InvokeServer(unpack(args))
        end)
    end

    local function SmartDismount()
        local isRiding = LocalPlayer:GetAttribute("RidePetId") ~= nil
        if isRiding then
            ToggleMount(false) 
            task.wait(0.3)
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChild("Humanoid")
            if humanoid then humanoid.Jump = true end
            task.wait(0.1)
        end
    end

    -- ==========================================
    -- HÀM TIỆN ÍCH: ĐẾM NGƯỜI TRONG HẦM NGỤC
    -- ==========================================
    local function GetPlayersInDungeon(myHrp)
        local count = 1 -- Luôn có bản thân mình
        if not myHrp then return count end
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local pChar = p.Character
                local pHrp = pChar:FindFirstChild("HumanoidRootPart")
                local pHum = pChar:FindFirstChild("Humanoid")
                if pHrp and pHum and pHum.Health > 0 then
                    if (pHrp.Position - myHrp.Position).Magnitude < 1000 then
                        count = count + 1
                    end
                end
            end
        end
        return count
    end

    -- ==========================================
    -- GIAO DIỆN UI (RAYFIELD TABS)
    -- ==========================================
    local DungeonTab = Window:CreateTab(Utils.t("dungeon"), "shield")
    local DungeonStatus = DungeonTab:CreateLabel(Utils.t("dg_status_off"))

    DungeonTab:CreateToggle({
        Name = Utils.t("master_toggle"), -- master switch
        Info = Utils.t("dg_auto_attack_info"),
        CurrentValue = false, 
        Flag = "DungeonMasterBreaker",
        Callback = function(Value)
            DungeonToggle(Value)
            if not Value then DungeonStatus:Set(Utils.t("dg_status_off")) else DungeonStatus:Set(Utils.t("dg_status_on")) end
        end
    })

    DungeonTab:CreateSection(" " .. Utils.t("sec_in_dungeon") .. " ")
    DungeonTab:CreateToggle({ Name = Utils.t("dg_auto_attack"), Info = Utils.t("dg_auto_attack_info"), CurrentValue = false, Flag = "AutoAttack_V2", Callback = function(Value) autoAttackEnabled = Value end })
    DungeonTab:CreateToggle({ Name = Utils.t("dg_auto_exit_20"), Info = Utils.t("dg_auto_exit_20_info"), CurrentValue = false, Flag = "AutoExitDungeon", Callback = function(Value) autoExitEnabled = Value if not Value then autoExitTriggered = false stage20ClockStarted = false waitingForHost = false end end })
    
    DungeonTab:CreateSlider({
        Name = Utils.t("dg_wait_host_timeout"), 
        Info = Utils.t("dg_wait_host_timeout_info"),
        Range = {1, 20}, 
        Increment = 1, 
        Suffix = (Utils.getLang() == "vi" and " Phút" or " Mins"), 
        CurrentValue = 1, 
        Flag = "WaitHostTimeout",
        Callback = function(Value) waitHostTimeoutMinutes = Value end,
    })

    DungeonTab:CreateSection(" " .. Utils.t("sec_dg_lobby") .. " ")
    DungeonTab:CreateToggle({ Name = Utils.t("dg_auto_join"), Info = Utils.t("dg_auto_join_info"), CurrentValue = false, Flag = "AutoJoinOthers", Callback = function(Value) autoJoinOthersEnabled = Value end })
    DungeonTab:CreateToggle({ Name = Utils.t("dg_auto_create"), Info = Utils.t("dg_auto_create_info"), CurrentValue = false, Flag = "AutoCreateRoom", Callback = function(Value) autoCreateEnabled = Value end })

    DungeonTab:CreateDropdown({
        Name = Utils.t("dg_select_diff"), 
        Info = Utils.t("dg_select_diff_info"),
        Options = {"1 - Normal", "2 - Hard", "3 - Nightmare", "4 - Inferno" }, 
        CurrentOption = {"1 - Normal"}, 
        MultipleOptions = false, 
        Flag = "DungeonDifficulty",
        Callback = function(Option)
            if Option[1] == "1 - Normal" then targetDifficulty = 1 elseif Option[1] == "2 - Hard" then targetDifficulty = 2 elseif Option[1] == "3 - Nightmare" then targetDifficulty = 3 elseif Option[1] == "4 - Inferno" then targetDifficulty = 4 end
        end,
    })

    DungeonTab:CreateSlider({
        Name = Utils.t("dg_player_count"), 
        Info = Utils.t("dg_player_count_info"),
        Range = {1, 4}, 
        Increment = 1, 
        Suffix = (Utils.getLang() == "vi" and " Người" or " Players"), 
        CurrentValue = 1, 
        Flag = "TargetPlayerCount",
        Callback = function(Value) targetPlayerCount = Value end,
    })

    -- LOGIC GỌI REMOTE THOÁT
    local function SafeExitRoutine()
        pcall(function()
            local args = { "ArenaLeaveChannel" }
            ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager"):WaitForChild("Funcs"):WaitForChild("DataPullFunc"):InvokeServer(unpack(args))
        end)
        
        -- [TÍCH HỢP]: Nhả Lock ngay khi ấn thoát để hệ thống biết Dungeon đã xong
        if _G.SystemController then _G.SystemController.ReleaseLock("AutoDungeon") end
        
        task.wait(1.5)
        
        local checkLabStage = Utils.FindUIElementByName(playerGui, "LabStage")
        local currentStageText = checkLabStage and checkLabStage.Text or "Unknown"
        if currentStageText == "Unknown" or not string.match(currentStageText, "20/20") then 
            autoExitTriggered = false
            stage20ClockStarted = false 
            waitingForHost = false
        else 
            autoExitTriggered = false 
        end
    end

    -- ==========================================
    -- VÒNG LẶP CORE 
    -- ==========================================
    task.spawn(function()
        while task.wait(0.5) do
            if not masterSwitchEnabled then continue end

            local controller = _G.SystemController
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
           
            if not (hrp and humanoid and humanoid.Health > 0) then continue end
            local labStage = Utils.FindUIElementByName(playerGui, "LabStage")
            local isInDungeon = (labStage and labStage.Text ~= "Unknown" and labStage.Text ~= "")
         
            if isInDungeon then
                -- [TÍCH HỢP]: Chiếm Lock vĩnh viễn khi đang trong Dungeon (Ưu tiên 1)
                if controller then controller.RequestLock("AutoDungeon") end

                if autoAttackEnabled then
                    local monstersFolder = Workspace:FindFirstChild("Monsters")
                    local closestDist2D = math.huge
                    local bestTarget = nil

                    if monstersFolder then
                        for _, monster in pairs(monstersFolder:GetChildren()) do
                            if monster:IsA("Model") or monster:IsA("BasePart") then
                                local hum = monster:FindFirstChildOfClass("Humanoid")
                                if (not hum) or (hum and hum.Health > 0) then
                                    local pos = monster:IsA("Model") and monster.PrimaryPart and monster.PrimaryPart.Position or monster.Position
                                    local dist2D = math.sqrt((hrp.Position.X - pos.X)^2 + (hrp.Position.Z - pos.Z)^2)
                                    if dist2D < closestDist2D and dist2D < 150 then closestDist2D = dist2D bestTarget = monster end
                                end
                            end
                        end
                    end

                    if bestTarget then
                        local targetPos = bestTarget:IsA("Model") and bestTarget.PrimaryPart and bestTarget.PrimaryPart.Position or bestTarget.Position
                        
                        if closestDist2D > 40 then
                            ToggleMount(true)
                            task.wait(0.2)
                            hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 4)) 
                            task.wait(0.2)
                            humanoid:MoveTo(hrp.Position) 
                            dungeonLastPosition = hrp.Position 
                            dungeonStuckTimer = 0 
                            SmartDismount()
                        elseif closestDist2D > 12 then
                            humanoid:MoveTo(targetPos)
                            if dungeonLastPosition and (hrp.Position - dungeonLastPosition).Magnitude < 1 then
                                dungeonStuckTimer = dungeonStuckTimer + 0.5
                                if dungeonStuckTimer >= 3 then 
                                    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 3)) 
                                    dungeonStuckTimer = 0 
                                end
                            else dungeonStuckTimer = 0 end
                            dungeonLastPosition = hrp.Position
                        else
                            humanoid:MoveTo(hrp.Position) 
                            dungeonStuckTimer = 0 
                            SmartDismount()
                            
                            local id = tonumber(bestTarget.Name:match("Monster_(%d+)"))
                            if id then
                                pcall(function()
                                    local args = { "MonsterAttackChannel", id }
                                    ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager"):WaitForChild("Funcs"):WaitForChild("DataPullFunc"):InvokeServer(unpack(args))
                                end)
                            end
                        end
                    else dungeonStuckTimer = 0 SmartDismount() end
                end

                if autoExitEnabled and not autoExitTriggered then
                    local fmTimeFrame = nil
                    pcall(function() fmTimeFrame = playerGui.MainGui.ScreenGui.ArenaMainRightTopView.FmTime end)
                    local currentStage, maxStage = string.match(labStage.Text, "(%d+)/(%d+)")
                    
                    if currentStage and maxStage and tonumber(currentStage) == tonumber(maxStage) then
                        if fmTimeFrame and fmTimeFrame.Visible == true then 
                            if not stage20ClockStarted then 
                                stage20ClockStarted = true
                                waitingForHost = false
                                hostMissingTime = nil 
                                DungeonStatus:Set(Utils.t("dg_label_stage20_clock")) 
                            end 
                        end
                        
                        if stage20ClockStarted and (not fmTimeFrame or fmTimeFrame.Visible == false) then
                            if autoJoinOthersEnabled then
                                if not waitingForHost then
                                    waitingForHost = true
                                    dungeonCompletionTime = tick()
                                    hostMissingTime = nil 
                                    DungeonStatus:Set(string.format(Utils.t("dg_label_wait_host"), waitHostTimeoutMinutes))
                                else
                                    local elapsed = math.floor(tick() - dungeonCompletionTime)
                                    local playersInside = GetPlayersInDungeon(hrp)
                                    local maxWaitSeconds = waitHostTimeoutMinutes * 60 
                                    
                                    if playersInside <= 1 then
                                        if not hostMissingTime then hostMissingTime = tick() end
                                        local missingElapsed = math.floor(tick() - hostMissingTime)
                                        
                                        if missingElapsed >= 7 then 
                                            autoExitTriggered = true 
                                            DungeonStatus:Set(Utils.t("dg_label_host_left"))
                                            task.spawn(function() if WebhookModule and WebhookModule.SendNotification then WebhookModule.SendNotification("**" .. LocalPlayer.Name .. "** thoát Hầm ngục vì chủ phòng sủi.") end end)
                                            task.spawn(SafeExitRoutine)
                                        else
                                            DungeonStatus:Set(string.format(Utils.t("dg_label_sync_host"), missingElapsed))
                                        end
                                    else
                                        hostMissingTime = nil 
                                        if elapsed >= maxWaitSeconds then
                                            autoExitTriggered = true 
                                            DungeonStatus:Set(Utils.t("dg_label_host_timeout"))
                                            task.spawn(function() if WebhookModule and WebhookModule.SendNotification then WebhookModule.SendNotification(string.format("**%s** thoát Hầm ngục do Timeout (%d phút).", LocalPlayer.Name, waitHostTimeoutMinutes)) end end)
                                            task.spawn(SafeExitRoutine)
                                        else
                                            DungeonStatus:Set(string.format(Utils.t("dg_label_wait_host_detail"), elapsed, maxWaitSeconds, playersInside))
                                        end
                                    end
                                end
                            elseif autoCreateEnabled then
                                -- Bật Auto Create mà không bật Auto Join -> Dùng chìa khóa đi tiếp ngay tại đấy
                                autoExitTriggered = true
                                DungeonStatus:Set(Utils.t("dg_label_boss_key"))
                                task.spawn(function()
                                    if WebhookModule and WebhookModule.SendNotification then
                                        WebhookModule.SendNotification("**" .. LocalPlayer.Name .. "** hoàn thành 20/20 và đã tự động dùng chìa khóa đi tiếp!")
                                    end
                                end)
                                
                                pcall(function()
                                    local args = { "AbyssRestartChannel" }
                                    game:GetService("ReplicatedStorage"):WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager"):WaitForChild("Funcs"):WaitForChild("DataPullFunc"):InvokeServer(unpack(args))
                                end)
                                
                                task.wait(5) -- Đợi game dịch chuyển sang map mới
                                autoExitTriggered = false
                                stage20ClockStarted = false
                                waitingForHost = false
                                hostMissingTime = nil
                            else
                                -- Không bật cả hai -> Thoát bình thường
                                autoExitTriggered = true 
                                DungeonStatus:Set(Utils.t("dg_label_boss_done_exit"))
                                task.spawn(function() if WebhookModule and WebhookModule.SendNotification then WebhookModule.SendNotification("**" .. LocalPlayer.Name .. "** vừa hoàn thành vòng Dungeon 20/20!") end end)
                                task.spawn(SafeExitRoutine)
                            end
                        end
                    else 
                        stage20ClockStarted = false
                        autoExitTriggered = false 
                        waitingForHost = false
                        hostMissingTime = nil 
                    end
                end

            else
                -- ========================================================
                -- [TÍCH HỢP]: LOGIC NGOÀI SẢNH - NHƯỜNG ĐƯỜNG CHO BOSS
                -- ========================================================
                if _G.PendingBossHunt or _G.PendingSpecialBoss then
                    DungeonStatus:Set(Utils.t("dg_label_lobby_yield_boss"))
                    if controller then controller.ReleaseLock("AutoDungeon") end
                    
                    -- Khoanh tay đứng đợi cho đến khi Boss đánh xong
                    while _G.PendingBossHunt or (controller and controller.CurrentLock == "BossHunt") do
                        task.wait(1)
                    end
                    
                    DungeonStatus:Set(Utils.t("dg_label_lobby_boss_done"))
                    task.wait(2) 
                    continue -- Chạy lại vòng lặp từ đầu để check Lock
                end
                
                -- Nếu Main Controller Pause toàn hệ thống
                if controller and controller.IsPaused then 
                    DungeonStatus:Set(Utils.t("dg_label_lobby_stopped"))
                    continue 
                end

                if autoJoinOthersEnabled or autoCreateEnabled then
                    pcall(function()
                        local wArea = Workspace:FindFirstChild("Area")
                        local center = wArea and wArea:FindFirstChild("center")
                        local innerArea = center and center:FindFirstChild("Area")
                        local abyssFolder = innerArea and innerArea:FindFirstChild("Abyss")
                        
                        if abyssFolder then
                            local alreadyInSomeoneRoom = false
                            local isMyRoom = false
                            local myRoomNode = nil
                            local shouldJumpOut = false
                            local jumpOutTarget = nil
                            
                            local roomToJoin = nil
                            local closestJoinDist = math.huge
                            
                            local emptyRoomToCreate = nil
                            local closestEmptyDist = math.huge
                            
                            local isPreparingRoom = false
                            local preparingRoomNode = nil 

                            for _, room in ipairs(abyssFolder:GetChildren()) do
                                if string.match(room.Name, "Abyss_") then
                                    local platform = room:FindFirstChild("Platform")
                                    local board = platform and platform:FindFirstChild("Board")
                                    local surfaceGui = board and board:FindFirstChild("SurfaceGui")
                                    
                                    local isThisRoomMyRoom = false
                                    for k, _ in pairs(room:GetAttributes()) do
                                        if k == "Owner_" .. tostring(myUserId) then
                                            isThisRoomMyRoom = true
                                            isMyRoom = true; myRoomNode = room; break
                                        end
                                    end

                                    if surfaceGui and surfaceGui:FindFirstChild("FmEmpty") and surfaceGui:FindFirstChild("FmPrepare") and surfaceGui:FindFirstChild("FmInfo") and surfaceGui:FindFirstChild("FmPlayer") then
                                        local targetPos = (room:IsA("Model") and room:GetPivot().Position) or (room:IsA("BasePart") and room.Position)
                                        if targetPos then
                                            local dist = (hrp.Position - targetPos).Magnitude
                                            
                                            if (not surfaceGui.FmEmpty.Visible) and (not surfaceGui.FmPrepare.Visible) and surfaceGui.FmInfo.Visible and surfaceGui.FmPlayer.Visible then
                                                local isOtherPlayer = false
                                                for _, desc in ipairs(surfaceGui.FmPlayer:GetDescendants()) do
                                                    if desc:IsA("ImageLabel") and string.find(desc.Image, "AvatarHeadShot") then
                                                        local extractedId = string.match(desc.Image, "id=(%d+)")
                                                        if extractedId and tonumber(extractedId) ~= myUserId then isOtherPlayer = true break end
                                                    end
                                                end
                                                
                                                if isThisRoomMyRoom and dist < 25 then 
                                                    shouldJumpOut = true 
                                                    local leaveAth = room:FindFirstChild("LeaveAth") 
                                                    if leaveAth and leaveAth:IsA("Attachment") then jumpOutTarget = leaveAth.WorldPosition end
                                                elseif isOtherPlayer then 
                                                    if dist < 15 then alreadyInSomeoneRoom = true 
                                                    elseif dist < closestJoinDist then closestJoinDist = dist roomToJoin = targetPos + Vector3.new(0, 3, 0) end 
                                                end
                                            end

                                            if surfaceGui.FmPrepare.Visible and dist < 12 then
                                                isPreparingRoom = true; preparingRoomNode = room
                                            end

                                            if surfaceGui.FmEmpty.Visible and not autoJoinOthersEnabled then
                                                if dist < closestEmptyDist then
                                                    closestEmptyDist = dist; emptyRoomToCreate = targetPos + Vector3.new(0, 3, 0) 
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            -- KIỂM TRA VÀ QUẢN LÝ CỜ KHÓA (MUTEX LOCK) CHO SẢNH
                            local needLock = false
                            if autoJoinOthersEnabled then
                                -- Cần lock nếu chuẩn bị join phòng, hoặc đang ngồi phòng người khác (không bị gài chủ phòng)
                                if (roomToJoin and not alreadyInSomeoneRoom) or (alreadyInSomeoneRoom and not shouldJumpOut) then
                                    needLock = true
                                end
                            elseif autoCreateEnabled then
                                if isMyRoom or isPreparingRoom or emptyRoomToCreate then
                                    needLock = true
                                end
                            end

                            if needLock then
                                if controller then
                                    local hasLock = controller.RequestLock("AutoDungeon")
                                    if not hasLock and controller.CurrentLock ~= "AutoDungeon" then
                                        DungeonStatus:Set(Utils.t("dg_label_lobby_wait_lock"))
                                        -- Hủy các lệnh di chuyển ở sảnh trong tick này
                                        shouldJumpOut = false
                                        roomToJoin = nil
                                        isPreparingRoom = false
                                        emptyRoomToCreate = nil
                                    end
                                end
                            else
                                -- Không cần thao tác, nhả cờ sảnh để module khác (Rift, Boss) chạy
                                if controller and controller.CurrentLock == "AutoDungeon" then
                                    controller.ReleaseLock("AutoDungeon")
                                end
                            end

                            -- THỰC THI HÀNH ĐỘNG SẢNH
                            if autoJoinOthersEnabled then
                                DungeonStatus:Set(Utils.t("dg_label_lobby_finding"))
                                if shouldJumpOut then 
                                    -- Giải phóng cờ ngay lập tức khi kích hoạt chức năng nhảy ra khỏi bục
                                    if controller and controller.CurrentLock == "AutoDungeon" then
                                        controller.ReleaseLock("AutoDungeon")
                                        print("[AutoDungeon] 🔓 Bị gài chủ phòng! Nhảy ra khỏi bục và nhả cờ...")
                                    end
                                    if jumpOutTarget then hrp.CFrame = CFrame.new(jumpOutTarget + Vector3.new(0, 3, 0)) else hrp.CFrame = hrp.CFrame * CFrame.new(0, 0, 20) end task.wait(2)
                                elseif roomToJoin and not alreadyInSomeoneRoom then hrp.CFrame = CFrame.new(roomToJoin) task.wait(3) end

                            elseif autoCreateEnabled then
                                if isStartingDungeon then return end

                                if isMyRoom and myRoomNode then
                                    local currentPlayerCount = 0
                                    for key, _ in pairs(myRoomNode:GetAttributes()) do
                                        if string.find(key, "Owner_") == 1 or string.find(key, "Mem_") == 1 then currentPlayerCount = currentPlayerCount + 1 end
                                    end
                                    
                                    if currentPlayerCount >= targetPlayerCount then
                                        DungeonStatus:Set(string.format(Utils.t("dg_label_lobby_full"), currentPlayerCount, targetPlayerCount))
                                        isStartingDungeon = true
                                        
                                        task.wait(2.5)
                                        DungeonStatus:Set(Utils.t("dg_label_lobby_force_start"))
                                        
                                        pcall(function()
                                            local CG = getrenv()._G
                                            if CG and CG.PathTool and CG.PathTool.ViewUtil and CG.PathTool.AbyssSystem then
                                                CG.PathTool.ViewUtil.DoRequest(CG.PathTool.AbyssSystem.ClientStartAbyss)
                                            end
                                        end)
                                        
                                        local startNames = {"BtStart", "BtnStart", "BtGo", "BtEnter", "StartBtn"}
                                        local btnStart = nil
                                        
                                        local teamView = Utils.FindUIElementByName(playerGui, "AbyssTeamView")
                                        if teamView then
                                            for _, btnName in ipairs(startNames) do
                                                btnStart = Utils.FindUIElementByName(teamView, btnName)
                                                if btnStart then break end
                                            end
                                        end
                                        
                                        if not btnStart then
                                            for _, v in pairs(playerGui:GetDescendants()) do
                                                if v:IsA("GuiButton") and v.Visible and v.AbsoluteSize.X > 0 then
                                                    for _, btnName in ipairs(startNames) do
                                                        if v.Name == btnName then btnStart = v break end
                                                    end
                                                    if btnStart then break end
                                                    local txt = v:IsA("TextButton") and v.Text or ""
                                                    local lab = v:FindFirstChildOfClass("TextLabel")
                                                    if lab then txt = lab.Text end
                                                    txt = string.lower(txt)
                                                    if string.match(txt, "start") or string.match(txt, "bắt đầu") then btnStart = v break end
                                                end
                                            end
                                        end
                                        
                                        if btnStart then
                                            pcall(function()
                                                if getconnections then
                                                    for _, conn in ipairs(getconnections(btnStart.Activated)) do conn.Function() end
                                                    for _, conn in ipairs(getconnections(btnStart.MouseButton1Click)) do conn.Function() end
                                                end
                                            end)
                                            Utils.ClickButtonExact(btnStart, "Nút Start")
                                        end
                                        
                                        task.wait(4.5)
                                        isStartingDungeon = false
                                    else 
                                        DungeonStatus:Set(string.format(Utils.t("dg_label_lobby_wait_players"), currentPlayerCount, targetPlayerCount)) 
                                    end

                                elseif isPreparingRoom and preparingRoomNode then
                                    DungeonStatus:Set(Utils.t("dg_label_lobby_creating"))
                                    local abyssIndex = tonumber(string.match(preparingRoomNode.Name, "Abyss_(%d+)")) or 1
                                    local difficultyCode = 1000 + targetDifficulty 
                                    
                                    pcall(function()
                                        local args = { "AbyssCreateTeamChannel", abyssIndex, difficultyCode, targetPlayerCount }
                                        game:GetService("ReplicatedStorage"):WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager"):WaitForChild("Funcs"):WaitForChild("DataPullFunc"):InvokeServer(unpack(args))
                                    end)
                                    task.wait(1.5)

                                elseif emptyRoomToCreate then
                                    local distToEmpty = (hrp.Position - emptyRoomToCreate).Magnitude
                                    if distToEmpty > 15 then
                                        DungeonStatus:Set(Utils.t("dg_label_lobby_joining"))
                                        hrp.CFrame = CFrame.new(emptyRoomToCreate)
                                        task.wait(1.5)
                                    end
                                end
                            end
                        end
                    end)
                else
                    DungeonStatus:Set(Utils.t("dg_label_lobby_off"))
                    if controller and controller.CurrentLock == "AutoDungeon" then
                        controller.ReleaseLock("AutoDungeon")
                    end
                end
            end
        end
    end)
end

end

modules['features/tracker.txt'] = function(...)
-- ====================================================================
-- MODULE: THEO DÕI NGƯỜI CHƠI & LIVE GPS (V2.2 - TÍCH HỢP ĐIỀU KHIỂN TỔNG)
-- ====================================================================
return function(Window, Utils)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer

    local following = false
    local targetPlayer = nil
    local missingTime = 0
    local chatListenerEnabled = false

    -- [ĐĂNG KÝ VỚI SYSTEM CONTROLLER]
    -- Khi nhận lệnh Pause/Resume từ nút STOP/RESUME (hoặc phím P), nó tự cập nhật biến following
    if _G.SystemController and type(_G.SystemController.registerModule) == "function" then
        _G.SystemController:registerModule("tracker", function(paused)
            if paused then
                following = false -- Dừng ép buộc
            else
                -- Có thể thêm logic khôi phục ở đây nếu muốn
            end
        end)
    end

    local MainTab = Window:CreateTab(Utils.t("tracker"), "eye")
    local StatusLabel = MainTab:CreateLabel(Utils.t("tracker_idle"))

    local function GetPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do 
            if p ~= LocalPlayer then table.insert(names, p.Name) end 
        end
        return names
    end

    local PlayerDropdown = MainTab:CreateDropdown({ 
        Name = Utils.t("select_player"), 
        Info = Utils.t("select_player_info"),
        Options = GetPlayerNames(), 
        CurrentOption = {}, 
        MultipleOptions = false, 
        Callback = function(Option)
            targetPlayer = Players:FindFirstChild(Option[1])
            if targetPlayer then StatusLabel:Set(Utils.t("tracker_selected") .. targetPlayer.Name) end 
        end 
    })

    MainTab:CreateButton({ 
        Name = Utils.t("refresh_players"), 
        Info = Utils.t("refresh_players_info"), 
        Callback = function() PlayerDropdown:Refresh(GetPlayerNames()) end 
    })
    
    local FollowToggle = MainTab:CreateToggle({ 
        Name = Utils.t("toggle_follow"), 
        Info = Utils.t("toggle_follow_info"), 
        CurrentValue = false, 
        Callback = function(Value) 
            following = Value 
            if not Value then StatusLabel:Set(Utils.t("tracker_stopped")) end 
        end 
    })

    MainTab:CreateButton({ 
        Name = Utils.t("btn_teleport_player"), 
        Info = Utils.t("btn_teleport_player_info"), 
        Callback = function()
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame end
            else
                game.StarterGui:SetCore("SendNotification", {
                    Title = Utils.t("warning_title"), 
                    Text = Utils.t("tracker_not_found"), 
                    Duration = 3
                })
            end
        end 
    })

    MainTab:CreateToggle({
        Name = Utils.t("listen_chat"),
        Info = Utils.t("listen_chat_info"),
        CurrentValue = false,
        Callback = function(Value) chatListenerEnabled = Value end
    })

    local function SetupChat(p) 
        p.Chatted:Connect(function(msg) 
            -- CHỈ KHI NÀO ĐANG BẬT TOGGLE HOẶC ĐANG BẬT LISTEN THÌ MỚI ĐỔI MỤC TIÊU
            if chatListenerEnabled and msg == "!f" then 
                targetPlayer = p 
                following = true 
                FollowToggle:Set(true)
                StatusLabel:Set(Utils.t("tracker_following") .. p.Name) 
            end 
        end) 
    end
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then SetupChat(p) end end
    Players.PlayerAdded:Connect(SetupChat)

    -- [LOGIC FOLLOW]
    task.spawn(function()
        while task.wait(0.5) do
            -- Kiểm tra xem hệ thống có đang bị Pause toàn cục không
            if _G.SystemController and _G.SystemController.IsPaused then continue end
            
            if following and targetPlayer then
                pcall(function()
                    local char = LocalPlayer.Character
                    local tChar = targetPlayer.Character
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
        end
    end)

    -- [GPS LIVE]
    local coordGui = Instance.new("ScreenGui", game.CoreGui)
    coordGui.Name = "CoordLiveGUI"
    local coordText = Instance.new("TextLabel", coordGui)
    coordText.Size = UDim2.new(0, 160, 0, 26); coordText.Position = UDim2.new(0.78, 0, 0.05, 0)
    coordText.BackgroundTransparency = 1; coordText.TextColor3 = Color3.fromRGB(0, 255, 0)
    coordText.Font = Enum.Font.Code; coordText.TextSize = 16; coordText.TextXAlignment = Enum.TextXAlignment.Left
    coordText.Text = "0 / 0 / 0"; coordText.Active = true

    RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local p = char.HumanoidRootPart.Position
            coordText.Text = string.format("📍 %.1f / %.1f / %.1f", p.X, p.Y, p.Z)
        end
    end)

    -- [DRAGGING LOGIC]
    local dragging, dragStart, startPos
    coordText.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = coordText.Position
        end
    end)
    coordText.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            coordText.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

end

modules['features/hatch_egg.txt'] = function(...)
-- ====================================================================
-- MODULE: SMART AUTO HATCH V9.1 (MULTI-SELECT UPGRADE)
-- ====================================================================
return function(Window, Utils)
    local EggTab = Window:CreateTab(Utils.t("autohatch"), "egg")

    local hatchSettings = {
        autoStart = false,
        autoSkip = false,
        autoClaim = false,
        stopIfBagFull = true,
        eggIdsToHatch = {}, -- Chuyển thành Table để chứa nhiều ID
        autoBreed = false,
        breedFather = "Any",
        breedMother = "Any"
    }

    -- Hàm can thiệp quyền hạn của Executor
    local get_thread_id = getthreadcontext or getthreadidentity or getidentity or (syn and syn.get_thread_identity)
    local set_thread_id = setthreadcontext or setthreadidentity or setidentity or (syn and syn.set_thread_identity)

    -- ==========================================
    -- QUÉT DỮ LIỆU TỰ ĐỘNG
    -- ==========================================
    local eggOptions = {}
    local eggIdMap = {}

    local function LoadEggData()
        local env = getrenv()._G.PathTool
        if env and env.CfgEgg and env.CfgEgg.Tmpls then
            for id, info in pairs(env.CfgEgg.Tmpls) do
                local eId = tonumber(id)
                if eId then
                    local eName = info.Name or info.name or info.EggName or (Utils.t("egg_fallback_name") .. tostring(eId))
                    eName = string.gsub(eName, '"', '')
                    eName = string.gsub(eName, '\n', ' ')
                    local displayStr = eName .. " (ID: " .. eId .. ")"
                    table.insert(eggOptions, displayStr)
                    eggIdMap[displayStr] = eId
                end
            end
            table.sort(eggOptions)
            return true
        end
        return false
    end

    if not LoadEggData() or #eggOptions == 0 then
        table.insert(eggOptions, Utils.t("refresh_warning_name"))
        eggIdMap[Utils.t("refresh_warning_name")] = 1
    end
    
    -- Khởi tạo giá trị mặc định cho mảng chọn
    if #eggOptions > 0 and eggIdMap[eggOptions[1]] then
        table.insert(hatchSettings.eggIdsToHatch, eggIdMap[eggOptions[1]])
    end

    -- ==========================================
    -- GIAO DIỆN UI
    -- ==========================================
    EggTab:CreateSection(" " .. string.upper(Utils.t("bag_status")) .. " ")
    local BagStatusLabel = EggTab:CreateLabel(Utils.t("bag_loading"))



    EggTab:CreateSection(" " .. string.upper(Utils.t("select_eggs")) .. " ")
    local EggDropdown = EggTab:CreateDropdown({
        Name = Utils.t("select_eggs"),
        Info = Utils.t("select_eggs_info"),
        Options = eggOptions,
        CurrentOption = {eggOptions[1]},
        MultipleOptions = true, -- Bật tính năng chọn nhiều
        Flag = "EggSelectDropdown",
        Callback = function(Options)
            -- Làm sạch mảng cũ và nạp danh sách ID mới vào
            hatchSettings.eggIdsToHatch = {}
            for _, selectedString in ipairs(Options) do
                if eggIdMap[selectedString] then
                    table.insert(hatchSettings.eggIdsToHatch, eggIdMap[selectedString])
                end
            end
        end,
    })

    EggTab:CreateButton({
        Name = Utils.t("refresh_eggs"),
        Info = Utils.t("refresh_eggs_info"),
        Callback = function()
            eggOptions = {}
            eggIdMap = {}
            if LoadEggData() and #eggOptions > 0 then
                EggDropdown:Refresh(eggOptions)
            end
        end
    })

    EggTab:CreateSection(" " .. string.upper(Utils.t("auto_hatch_tab")) .. " ")
    
    local ToggleStart = EggTab:CreateToggle({
        Name = Utils.t("auto_start"),
        Info = Utils.t("auto_start_info"),
        CurrentValue = false,
        Flag = "AutoStartEgg",
        Callback = function(Value) hatchSettings.autoStart = Value end
    })

    local ToggleClaim = EggTab:CreateToggle({
        Name = Utils.t("auto_claim"),
        Info = Utils.t("auto_claim_info"),
        CurrentValue = false,
        Flag = "AutoClaimEgg",
        Callback = function(Value) hatchSettings.autoClaim = Value end
    })

    EggTab:CreateSection(" " .. string.upper(Utils.t("stop_if_full")) .. " ")
    EggTab:CreateToggle({
        Name = Utils.t("stop_if_full"),
        Info = Utils.t("stop_if_full_info"),
        CurrentValue = true,
        Flag = "StopIfFull",
        Callback = function(Value) hatchSettings.stopIfBagFull = Value end
    })

    EggTab:CreateSection(" " .. string.upper(Utils.t("auto_breed")) .. " ")
    
    local function FormatPetOptionString(pet, env)
        local tmpl = pet:GetTmpl()
        local name = tmpl.Name or tmpl.name or "Unknown"
        local grade = pet:GetGrade()
        local gradeName = env.Constants.PetGradeName[grade] or tostring(grade)
        
        local muts = {}
        local spProp = pet:GetSpecialProp() or 0
        if spProp > 0 then
            for _, v in pairs(env.PetSpecialPropUtil.SpecialPropertyDef) do
                if bit32.band(spProp, v) > 0 then
                    local desc = env.PetSpecialPropUtil.SpecialPropertyDesc[v]
                    if desc and desc.Name then
                        table.insert(muts, desc.Name)
                    end
                end
            end
        end
        
        local displayStr = name .. " (" .. gradeName .. ")"
        if #muts > 0 then
            displayStr = displayStr .. " [" .. table.concat(muts, "+") .. "]"
        end
        displayStr = displayStr .. " (ID: " .. tostring(pet.itemId) .. ")"
        return displayStr
    end

    local maleNames, femaleNames = {"Any"}, {"Any"}
    pcall(function()
        local env = getrenv()._G.PathTool
        local player = env.ClientPlayerManager.GetGamePlayer()
        local petData = player.pet
        petData:IterItem(function(pet)
            local tmpl = pet:GetTmpl()
            if not pet:IsChildPet() and not tmpl.CantBreed and pet:GetGrade() >= env.CfgPetBreed.ParentGradeMin then
                local displayStr = FormatPetOptionString(pet, env)
                local gender = pet:GetGender()
                if gender == env.Constants.PetGenderType.Male then
                    table.insert(maleNames, displayStr)
                elseif gender == env.Constants.PetGenderType.Female then
                    table.insert(femaleNames, displayStr)
                end
            end
            return true
        end)
    end)
    table.sort(maleNames)
    table.sort(femaleNames)

    local ToggleBreed = EggTab:CreateToggle({
        Name = Utils.t("auto_breed"),
        Info = Utils.t("auto_breed_info"),
        CurrentValue = false,
        Flag = "AutoBreedPets",
        Callback = function(Value) hatchSettings.autoBreed = Value end
    })

    local FatherDropdown = EggTab:CreateDropdown({
        Name = Utils.t("breed_father"),
        Options = maleNames,
        CurrentOption = {"Any"},
        Flag = "BreedFatherDropdown",
        Callback = function(Options)
            hatchSettings.breedFather = Options[1] or "Any"
        end
    })

    local MotherDropdown = EggTab:CreateDropdown({
        Name = Utils.t("breed_mother"),
        Options = femaleNames,
        CurrentOption = {"Any"},
        Flag = "BreedMotherDropdown",
        Callback = function(Options)
            hatchSettings.breedMother = Options[1] or "Any"
        end
    })

    EggTab:CreateButton({
        Name = "🔄 Refresh Pet List",
        Callback = function()
            local mList, fList = {"Any"}, {"Any"}
            pcall(function()
                local env = getrenv()._G.PathTool
                local player = env.ClientPlayerManager.GetGamePlayer()
                local petData = player.pet
                petData:IterItem(function(pet)
                    local tmpl = pet:GetTmpl()
                    if not pet:IsChildPet() and not tmpl.CantBreed and pet:GetGrade() >= env.CfgPetBreed.ParentGradeMin then
                        local displayStr = FormatPetOptionString(pet, env)
                        local gender = pet:GetGender()
                        if gender == env.Constants.PetGenderType.Male then
                            table.insert(mList, displayStr)
                        elseif gender == env.Constants.PetGenderType.Female then
                            table.insert(fList, displayStr)
                        end
                    end
                    return true
                end)
            end)
            table.sort(mList)
            table.sort(fList)
            FatherDropdown:Refresh(mList)
            MotherDropdown:Refresh(fList)
        end
    })

    -- ==========================================
    -- LUỒNG 1: THEO DÕI TÚI PET
    -- ==========================================
    task.spawn(function()
        while task.wait(1) do
            local env = getrenv()._G.PathTool
            if env and env.BossRoomSystemClient and env.BossRoomSystemClient.gamePlayer and env.BossRoomSystemClient.gamePlayer.pet then
                local realPetData = env.BossRoomSystemClient.gamePlayer.pet
                pcall(function()
                    local currentPets = type(realPetData.GetBagAmount) == "function" and realPetData.GetBagAmount(realPetData) or 0
                    local maxPets = type(realPetData.GetBagCapacity) == "function" and realPetData.GetBagCapacity(realPetData) or 0
                    
                    BagStatusLabel:Set(Utils.t("bag_status") .. currentPets .. " / " .. maxPets)
                    
                    if hatchSettings.stopIfBagFull and currentPets >= maxPets and maxPets > 0 then
                        if hatchSettings.autoClaim or hatchSettings.autoStart then
                            hatchSettings.autoClaim = false
                            hatchSettings.autoStart = false
                            ToggleStart:Set(false)
                            ToggleClaim:Set(false)
                            game.StarterGui:SetCore("SendNotification", {Title = Utils.t("warning_title"), Text = Utils.t("bag_full_warning"), Duration = 5})
                        end
                    end
                end)
            end
        end
    end)

    -- ==========================================
    -- LUỒNG 2: CORE LOGIC & NATIVE UI SYNC
    -- ==========================================
    task.spawn(function()
        while task.wait(0.5) do
            if not hatchSettings.autoStart and not hatchSettings.autoClaim then continue end
            
            local env = getrenv()._G.PathTool
            if not env or not env.BossRoomSystemClient then continue end
            
            local clientEgg = env.BossRoomSystemClient.gamePlayer.egg
            if not clientEgg then continue end

            local currentTime = (env.Utils and env.Utils.GetServerTime()) or workspace:GetServerTimeNow()

            for slotNum = 1, 10 do
                if not clientEgg:IsHatchUnlocked(slotNum) then continue end
                local eggId = clientEgg:GetHatchEggTmplId(slotNum)
                local startTick = clientEgg:GetHatchEggStartTick(slotNum) or 0

                -- AUTO START: Khi Lò trống
                if hatchSettings.autoStart and not eggId then
                    -- Kiểm tra xem có chọn trứng nào chưa
                    if #hatchSettings.eggIdsToHatch > 0 then
                        -- Random một quả trong danh sách bạn đã chọn để đưa vào lò
                        local randomIdx = math.random(1, #hatchSettings.eggIdsToHatch)
                        local targetEggId = hatchSettings.eggIdsToHatch[randomIdx]

                        pcall(function()
                            local oldId = get_thread_id()
                            set_thread_id(2) 

                            if env.EggSystem and env.EggSystem.ClientHatchStart then
                                env.EggSystem.ClientHatchStart(slotNum, targetEggId)
                            elseif type(clientEgg.StartHatch) == "function" then
                                clientEgg:StartHatch(slotNum, targetEggId, currentTime)
                            end
                            
                            if env.EventSystem then env.EventSystem.Execute("EggHatchChange") end
                            
                            set_thread_id(oldId) 
                        end)
                        task.wait(0.3)
                    end
                
                -- AUTO CLAIM: Khi Lò có trứng
                elseif hatchSettings.autoClaim and eggId then
                    local eggCfg = env.CfgEgg and (env.CfgEgg.Tmpls[eggId] or env.CfgEgg.Tmpls[tonumber(eggId)] or env.CfgEgg.Tmpls[tostring(eggId)])
                    local hatchTime = eggCfg and eggCfg.HatchTime or 3600
                    
                    if (startTick + hatchTime) <= currentTime then
                        pcall(function()
                            local oldId = get_thread_id()
                            set_thread_id(2) 

                            if env.EggSystem and env.EggSystem.ClientHatchTaken then
                                env.EggSystem.ClientHatchTaken(slotNum)
                            elseif type(clientEgg.ClientHatchTaken) == "function" then
                                clientEgg:ClientHatchTaken(slotNum)
                            end

                            if env.EventSystem then env.EventSystem.Execute("EggHatchChange") end

                            set_thread_id(oldId) 
                        end)
                        task.wait(0.3)
                    end
                end
            end

            -- AUTO CLAIM BREEDING EGG: Nhận trứng lai dắt (Pet Breed) khi ấp xong
            if hatchSettings.autoClaim then
                pcall(function()
                    local petData = env.BossRoomSystemClient.gamePlayer.pet
                    if petData then
                        for i = 1, 5 do
                            local breedingInfo = petData:GetBreeding(i)
                            if breedingInfo then
                                local breedTime = env.CfgPetBreed and env.CfgPetBreed.BreedTime or 14400
                                if (breedingInfo.StartTick + breedTime) <= currentTime then
                                    if petData:GetBagAmount() < petData:GetBagCapacity() then
                                        local oldId = get_thread_id()
                                        set_thread_id(2)
                                        
                                        if env.PetBreedSystem and env.PetBreedSystem.ClientHatching then
                                            env.PetBreedSystem.ClientHatching()
                                        end
                                        
                                        set_thread_id(oldId)
                                        task.wait(0.3)
                                    end
                                end
                            end
                        end
                    end
                end)
            end

            -- AUTO BREED PAIRING: Tự động ghép cặp lai dắt (Pet Breed)
            if hatchSettings.autoBreed then
                pcall(function()
                    local petData = env.BossRoomSystemClient.gamePlayer.pet
                    if petData then
                        local hasActiveBreed = false
                        for i = 1, 5 do
                            if petData:GetBreeding(i) ~= nil then
                                hasActiveBreed = true
                                break
                            end
                        end
                        if not hasActiveBreed then
                            -- Quét tìm con đực phù hợp
                            local maleCandidates = {}
                            local selectedFatherId = string.match(hatchSettings.breedFather, "%(ID:%s*(%d+)%)")
                            
                            petData:IterItem(function(pet)
                                local tmpl = pet:GetTmpl()
                                if not pet:IsChildPet() and not tmpl.CantBreed and pet:GetGrade() >= env.CfgPetBreed.ParentGradeMin then
                                    if pet:GetGender() == env.Constants.PetGenderType.Male then
                                        if selectedFatherId then
                                            if tostring(pet.itemId) == selectedFatherId then
                                                table.insert(maleCandidates, {
                                                    itemId = pet.itemId,
                                                    grade = pet:GetGrade()
                                                })
                                            end
                                        else
                                            table.insert(maleCandidates, {
                                                itemId = pet.itemId,
                                                grade = pet:GetGrade()
                                            })
                                        end
                                    end
                                end
                                return true
                            end)
                            
                            -- Quét tìm con cái phù hợp
                            local femaleCandidates = {}
                            local selectedMotherId = string.match(hatchSettings.breedMother, "%(ID:%s*(%d+)%)")
                            
                            petData:IterItem(function(pet)
                                local tmpl = pet:GetTmpl()
                                if not pet:IsChildPet() and not tmpl.CantBreed and pet:GetGrade() >= env.CfgPetBreed.ParentGradeMin then
                                    if pet:GetGender() == env.Constants.PetGenderType.Female then
                                        if selectedMotherId then
                                            if tostring(pet.itemId) == selectedMotherId then
                                                table.insert(femaleCandidates, {
                                                    itemId = pet.itemId,
                                                    grade = pet:GetGrade()
                                                })
                                            end
                                        else
                                            table.insert(femaleCandidates, {
                                                itemId = pet.itemId,
                                                grade = pet:GetGrade()
                                            })
                                        end
                                    end
                                end
                                return true
                            end)
                            
                            -- Sắp xếp theo Grade cao nhất trước
                            table.sort(maleCandidates, function(a, b) return a.grade > b.grade end)
                            table.sort(femaleCandidates, function(a, b) return a.grade > b.grade end)
                            
                            local bestMale = maleCandidates[1]
                            local bestFemale = femaleCandidates[1]
                            
                            if bestMale and bestFemale then
                                -- Check Cost
                                local canPay = true
                                pcall(function()
                                    canPay = env.ExchangeSystem.CheckCost(env.BossRoomSystemClient.gamePlayer, env.CfgPetBreed.BreedCost)
                                end)
                                
                                if canPay then
                                    local oldId = get_thread_id()
                                    set_thread_id(2)
                                    
                                    if env.PetBreedSystem and env.PetBreedSystem.ClientCreateBreeding then
                                        env.PetBreedSystem.ClientCreateBreeding(bestMale.itemId, bestFemale.itemId)
                                        print("[AutoBreed] Paired Male (" .. tostring(bestMale.itemId) .. ") with Female (" .. tostring(bestFemale.itemId) .. ") successfully!")
                                    end
                                    
                                    set_thread_id(oldId)
                                    task.wait(0.5)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)
end

end

modules['features/auto_rift.txt'] = function(...)
-- ====================================================================
-- MODULE: AUTO RIFT SYSTEM V9.3 (DEBUG LOGS & 1-MONSTER INSTANT EXIT)
-- REFACTORED: Tối ưu hoá cấu trúc, giảm trùng lặp, cải thiện hiệu suất
-- ====================================================================
return function(Window, Utils)
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local HttpService = game:GetService("HttpService")
    
    local LocalPlayer = Players.LocalPlayer

    -- ==========================================
    -- ĐĂNG KÝ VỚI MAIN CONTROLLER & BIẾN CẤU HÌNH
    -- ==========================================
    local riftSettings = {
        enabled = false,
        scanDynamic = true,
        scanStatic = true,
        autoHop = false,
        restTimeMinutes = 5,
        selectedWorlds = {2,3,4,5,6},
        selectedColors = {"Blue", "Purple", "Red", "Green", "Yellow", "Pink"}
    }
    
    local cycleState = {
        currentIndex = 1,
        currentLoadedWorld = nil,
        isResting = false,
        restEndTime = 0,
        lastDynamicActivityTime = 0
    }

    local targetRiftId, targetRiftKey = nil, nil
    local targetExpireDuration = 300 
    local currentTeamId = 0
    local riftsClearedCount = 0
    
    local dungeonStuckTimer = 0
    local dungeonLastPosition = nil

    local completedRifts = {} 
    local catchingMemory = {} 
    local catchCount = {} 
    
    local riftState = "SCANNING" 
    local riftEntryPosition = nil
    local hasEncounteredMonsters = false 

    local DataPullFunc = nil

    pcall(function()
        if Utils and Utils.LoadSelectedAreas then
            local savedWorlds = Utils.LoadSelectedAreas("R_SelectedRiftWorlds.json")
            if type(savedWorlds) == "table" and #savedWorlds > 0 then riftSettings.selectedWorlds = savedWorlds end
            
            local savedColors = Utils.LoadSelectedAreas("R_SelectedRiftColors.json")
            if type(savedColors) == "table" and #savedColors > 0 then riftSettings.selectedColors = savedColors end
        end
    end)

    local function RiftToggle(enable)
        riftSettings.enabled = enable
        if not enable then 
            riftState = "SCANNING"
            riftEntryPosition = nil
            targetRiftId = nil; targetRiftKey = nil; hasEncounteredMonsters = false
            cycleState.lastDynamicActivityTime = 0
            if _G.SystemController then _G.SystemController.ReleaseLock("AutoRift") end
        end
    end

    if _G.SystemController and type(_G.SystemController.registerModule) == "function" then
        _G.SystemController:registerModule("rift", RiftToggle)
    end

    -- ==========================================
    -- GIAO DIỆN UI
    -- ==========================================
    local RiftTab = Window:CreateTab(Utils.t("rift"), "door-open")
    local RiftStatus = RiftTab:CreateLabel(Utils.t("rift_status_off"))
    local ClearedLabel = RiftTab:CreateLabel(Utils.t("rifts_cleared_prefix") .. "0")
    local CycleStatus = RiftTab:CreateLabel(Utils.t("rift_cycle_not_started"))

    RiftTab:CreateSection(" " .. Utils.t("sec_rift_controls") .. " ")
    RiftTab:CreateToggle({
        Name = Utils.t("rift_master_toggle"), 
        Info = Utils.t("rift_master_toggle_info"),
        CurrentValue = false, 
        Flag = "AutoRiftMasterToggle",
        Callback = function(Value)
            RiftToggle(Value)
            if not Value then 
                RiftStatus:Set(Utils.t("tracker_stopped"))
                CycleStatus:Set(Utils.t("rift_cycle_stopped"))
            else 
                RiftStatus:Set(Utils.t("rift_status_prep"))
                cycleState.currentIndex = 1; cycleState.currentLoadedWorld = nil; cycleState.isResting = false; cycleState.lastDynamicActivityTime = 0
            end
        end
    })

    RiftTab:CreateToggle({ Name = Utils.t("rift_dynamic_toggle"), Info = Utils.t("rift_dynamic_toggle_info"), CurrentValue = true, Flag = "ScanDynamicToggle", Callback = function(Value) riftSettings.scanDynamic = Value end })
    RiftTab:CreateToggle({ Name = Utils.t("rift_static_toggle"), Info = Utils.t("rift_static_toggle_info"), CurrentValue = true, Flag = "ScanStaticToggle", Callback = function(Value) riftSettings.scanStatic = Value end })

    RiftTab:CreateSection(" " .. Utils.t("sec_rift_config") .. " ")
    local TargetLabel = RiftTab:CreateLabel(string.format(Utils.t("rift_selected_worlds_label"), #riftSettings.selectedWorlds))
    Utils.CreateAreaMultiSelect(RiftTab, {
        name = Utils.t("rift_select_worlds"), flag = "RiftWorldSelect",
        defaultAreas = Utils.GetAreaNamesByIds(riftSettings.selectedWorlds),
        callback = function(selectedIds)
            if type(selectedIds) == "table" then
                riftSettings.selectedWorlds = selectedIds
                if Utils and Utils.SaveSelectedAreas then Utils.SaveSelectedAreas(selectedIds, "R_SelectedRiftWorlds.json") end
                TargetLabel:Set(string.format(Utils.t("rift_selected_worlds_label"), #selectedIds))
            end
        end
    })

    local colorDisplayOptions = {
        Utils.t("color_blue"),
        Utils.t("color_purple"),
        Utils.t("color_red"),
        Utils.t("color_green"),
        Utils.t("color_yellow"),
        Utils.t("color_pink")
    }

    local displayToInternalColor = {
        [Utils.t("color_blue")] = "Blue",
        [Utils.t("color_purple")] = "Purple",
        [Utils.t("color_red")] = "Red",
        [Utils.t("color_green")] = "Green",
        [Utils.t("color_yellow")] = "Yellow",
        [Utils.t("color_pink")] = "Pink"
    }

    local internalToDisplayColor = {
        ["Blue"] = Utils.t("color_blue"),
        ["Purple"] = Utils.t("color_purple"),
        ["Red"] = Utils.t("color_red"),
        ["Green"] = Utils.t("color_green"),
        ["Yellow"] = Utils.t("color_yellow"),
        ["Pink"] = Utils.t("color_pink")
    }

    local currentDisplayOptions = {}
    for _, internalColor in ipairs(riftSettings.selectedColors) do
        local display = internalToDisplayColor[internalColor]
        if display then
            table.insert(currentDisplayOptions, display)
        end
    end
    if #currentDisplayOptions == 0 then
        currentDisplayOptions = {unpack(colorDisplayOptions)}
    end

    RiftTab:CreateDropdown({
        Name = Utils.t("rift_select_colors"),
        Info = Utils.t("rift_select_colors_info"),
        Options = colorDisplayOptions,
        CurrentOption = currentDisplayOptions,
        MultipleOptions = true,
        Flag = "RiftColorDropdown",
        Callback = function(Options)
            local selected = {}
            for _, display in ipairs(Options) do
                local internalColor = displayToInternalColor[display]
                if internalColor then
                    table.insert(selected, internalColor)
                end
            end
            riftSettings.selectedColors = selected
            if Utils and Utils.SaveSelectedAreas then
                Utils.SaveSelectedAreas(selected, "R_SelectedRiftColors.json")
            end
        end,
    })

    RiftTab:CreateToggle({ Name = Utils.t("rift_auto_hop"), Info = Utils.t("rift_auto_hop_info"), CurrentValue = false, Flag = "RiftAutoHop", Callback = function(Value) riftSettings.autoHop = Value end })
    RiftTab:CreateSlider({ Name = Utils.t("rift_rest_time"), Info = Utils.t("rift_rest_time_info"), Range = {1, 60}, Increment = 1, CurrentValue = 5, Flag = "RiftRestTime", Callback = function(Value) riftSettings.restTimeMinutes = Value end })


    -- ==========================================
    -- RADAR QUÉT QUÁI & HELPERS
    -- ==========================================
    local function SmartScanMonsters(monstersFolder, hrp)
        local hasAlive, deadList, best, minDist = false, {}, nil, math.huge
        if monstersFolder then
            for _, m in pairs(monstersFolder:GetChildren()) do
                if not string.match(m.Name, "Monster_") then continue end
                
                -- Lấy phần lõi của quái để tính tọa độ chính xác
                local root = m:IsA("Model") and m.PrimaryPart or m
                if not root or not root:IsA("BasePart") then 
                    root = m:FindFirstChildWhichIsA("BasePart")
                    if not root then continue end
                end

                -- Chỉ nhắm mục tiêu quái vật trong bán kính 250 studs kể từ khi vào Rift
                if riftEntryPosition then
                    local distFromEntry = (riftEntryPosition - root.Position).Magnitude
                    if distFromEntry > 250 then
                        continue
                    end
                end

                local id = tonumber(m.Name:match("Monster_(%d+)"))
                if id and catchCount[id] and catchCount[id] >= 3 then continue end
                if m:GetAttribute("CatchEndTick") ~= nil or root:GetAttribute("CatchEndTick") ~= nil then table.insert(deadList, m) continue end
                
                local hpVal = m:FindFirstChild("Health")
                if hpVal and hpVal:IsA("StringValue") then
                    local hpNum = tonumber((string.gsub(hpVal.Value, ",", ".")))
                    if hpNum and hpNum < 1 then table.insert(deadList, m) continue end
                end

                hasAlive = true
                local d = (hrp.Position - root.Position).Magnitude
                if d < minDist then minDist = d best = root end
            end
        end
        return hasAlive, deadList, best, minDist
    end

    local function GetPortalPosition(obj)
        local guiNode = obj:FindFirstChild("GUI")
        if guiNode then 
            if guiNode:IsA("Attachment") then return guiNode.WorldPosition end
            local pos; local success = pcall(function() pos = guiNode:GetPivot().Position end)
            if success and pos then return pos end
        end
        if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart.Position end
        return obj:GetPivot().Position 
    end

    local function IsInOpenWorld()
        local success, result = pcall(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            local mainGui = playerGui and playerGui:FindFirstChild("MainGui")
            local screenGui = mainGui and mainGui:FindFirstChild("ScreenGui")
            local mainRightView = screenGui and screenGui:FindFirstChild("MainRightView")
            local fmReturn = mainRightView and mainRightView:FindFirstChild("FmReturn")
            local btReturn = fmReturn and fmReturn:FindFirstChild("BtReturn")
            return btReturn and btReturn.Visible or false
        end)
        return success and result or false
    end

    local function IsMapFolderMatchingId(folderName, worldId)
        if not worldId then return false end
        local env = getrenv and getrenv()._G and getrenv()._G.PathTool
        if env and env.CfgAreaRegion and env.CfgAreaRegion.Tmpls then
            local tmpl = env.CfgAreaRegion.Tmpls[worldId] or env.CfgAreaRegion.Tmpls[tonumber(worldId)]
            if tmpl and tmpl.TeleKey then
                local telePrefix = string.split(tmpl.TeleKey, ".")[1]
                if telePrefix and string.lower(telePrefix) == string.lower(folderName) then
                    return true
                end
            end
        end
        if worldId == 1 and string.lower(folderName) == "center" then
            return true
        end
        local num = tonumber(string.match(folderName, "(%d+)"))
        return num == worldId
    end

    -- Hàm dọn dẹp danh sách Rift đã đi qua bị hết hạn
    local function CleanExpiredRifts()
        local currentTime = os.time()
        for key, expireTime in pairs(completedRifts) do
            if currentTime > expireTime then
                completedRifts[key] = nil
            end
        end
    end

    -- Hàm dùng chung để lọc và chọn cổng Rift tốt nhất từ danh sách các object (Tránh trùng lặp code)
    local function FindBestPortalFromList(objects, hrp, shortestDistance, bestPortal, prefix, portalTypeLabel)
        local env = getrenv and getrenv()._G and getrenv()._G.PathTool
        local colorMap = {
            ["Portal1"] = "Blue",
            ["Portal2"] = "Purple",
            ["Portal3"] = "Red",
            ["Portal4"] = "Green",
            ["Portal5"] = "Yellow",
            ["Portal6"] = "Pink",
            ["Portal7"] = "Purple"
        }

        for _, obj in ipairs(objects) do
            local idStr = string.match(obj.Name, "Dungeon_(%d+)")
            if idStr then
                local id = tonumber(idStr)
                
                -- Lọc theo màu sắc của cổng Rift
                local tmplId = obj:GetAttribute("DungeonTmplId")
                local tmpl = tmplId and env and env.CfgDungeon and env.CfgDungeon.Tmpls[tmplId]
                local modelName = tmpl and tmpl.EnterModel
                local color = modelName and colorMap[modelName] or "Blue"

                local isColorSelected = false
                for _, selColor in ipairs(riftSettings.selectedColors) do
                    if selColor == color then
                        isColorSelected = true
                        break
                    end
                end

                if not isColorSelected then
                    print(string.format("[TEST-LOG] ❌ Bỏ qua: %s %s có màu %s không nằm trong danh sách chọn!", portalTypeLabel, idStr, color))
                    continue
                end

                local properTeamId = obj:GetAttribute("DungeonStartTick")
                if properTeamId and properTeamId > 0 then
                    local portalKey = prefix .. idStr .. "_" .. properTeamId
                    if not completedRifts[portalKey] then
                        local doorPos = GetPortalPosition(obj)
                        local dist = (hrp.Position - doorPos).Magnitude
                        print(string.format("[TEST-LOG] ✅ HỢP LỆ: %s %s (Màu: %s) | Khoảng cách: %d", portalTypeLabel, idStr, color, math.floor(dist)))
                        
                        if dist < shortestDistance then
                            shortestDistance = dist
                            local endTick = obj:GetAttribute("DungeonEndTick")
                            local duration = 300
                            if endTick and endTick > properTeamId then 
                                duration = endTick - properTeamId 
                            end
                            bestPortal = {
                                id = id,
                                key = portalKey,
                                pos = doorPos,
                                teamId = properTeamId,
                                penalty = duration
                            }
                        end
                    else
                        print(string.format("[TEST-LOG] ❌ Bỏ qua: %s %s đang nằm trong Blacklist!", portalTypeLabel, idStr))
                    end
                else
                    print(string.format("[TEST-LOG] ❌ Bỏ qua: %s %s thiếu Attribute DungeonStartTick", portalTypeLabel, idStr))
                end
            end
        end
        return bestPortal, shortestDistance
    end

    -- Thử vào cổng Rift (Di chuyển + gọi Remote an toàn)
    local function TryEnterRift(bestPortal, hrp, controller)
        targetRiftId = bestPortal.id
        targetRiftKey = bestPortal.key
        targetExpireDuration = bestPortal.penalty
        if controller then controller.RequestLock("AutoRift") end

        if string.match(targetRiftKey, "^Dyn_") then
            cycleState.lastDynamicActivityTime = os.time()
            print("[TEST-LOG] ⚡ Đã chốt mục tiêu Dynamic Rift: " .. tostring(targetRiftId) .. ". Cập nhật lastDynamicActivityTime.")
        end

        print("[TEST-LOG] 🎯 Đã chốt mục tiêu: Rift " .. tostring(targetRiftId) .. ". Đang áp sát cổng...")
        RiftStatus:Set(Utils.t("rift_status_lock") .. tostring(targetRiftId) .. Utils.t("rift_status_lock_entering"))
        hrp.CFrame = CFrame.new(bestPortal.pos + Vector3.new(0, 3, 0))
        task.wait(0.5) 

        local safe_id, safe_team = targetRiftId, bestPortal.teamId
        currentTeamId = safe_team

        local function SendEnterRemote()
            pcall(function()
                DataPullFunc:InvokeServer("DungeonCreateTeamChannel", safe_id, safe_team)
                DataPullFunc:InvokeServer("DungeonStartChannel", safe_id, safe_team)
            end)
        end

        print("[TEST-LOG] Gửi Remote vào Rift lần 1...")
        task.spawn(SendEnterRemote)
        task.wait(2.0) 
        
        -- Kiểm tra xem đã dịch chuyển vào phòng Rift chưa
        local checkChar = LocalPlayer.Character
        local checkHrp = checkChar and checkChar:FindFirstChild("HumanoidRootPart")
        if checkHrp then
            local distFromPortal = (checkHrp.Position - bestPortal.pos).Magnitude
            print("[TEST-LOG] Khoảng cách tới cổng cũ sau khi gửi lệnh: " .. math.floor(distFromPortal) .. " studs")
            
            if distFromPortal < 150 and IsInOpenWorld() then
                print("[TEST-LOG] ⚠️ Vẫn đang ở Open World! Thử gửi Remote lần 2...")
                task.spawn(SendEnterRemote) 
                task.wait(2.0)
                
                local distRecheck = (checkHrp.Position - bestPortal.pos).Magnitude
                if distRecheck < 150 then
                    print("[TEST-LOG] ❌ Lỗi chặn cổng! Bỏ qua và chuyển mục tiêu.")
                    RiftStatus:Set(Utils.t("rift_status_fail"))
                    completedRifts[targetRiftKey] = os.time() + 60 
                    targetRiftId = nil
                    targetRiftKey = nil
                    riftState = "SCANNING"
                    if controller then controller.ReleaseLock("AutoRift") end
                else
                    print("[TEST-LOG] 🚀 VÀO RIFT THÀNH CÔNG (Lần 2)!")
                    dungeonStuckTimer = 0
                    hasEncounteredMonsters = false
                    riftState = "COMBAT"
                    riftEntryPosition = checkHrp.Position
                end
            else
                print("[TEST-LOG] 🚀 VÀO RIFT THÀNH CÔNG ngay lập tức!")
                dungeonStuckTimer = 0
                hasEncounteredMonsters = false
                riftState = "COMBAT"
                riftEntryPosition = checkHrp.Position
            end
        end
    end

    -- Xử lý ném bóng bắt quái khi quái chết
    local function HandleCatching(deadMonsters)
        RiftStatus:Set(Utils.t("rift_status_catch"))
        for _, m in pairs(deadMonsters) do
            local id = tonumber(m.Name:match("Monster_(%d+)"))
            if id and not catchingMemory[id] then
                catchCount[id] = (catchCount[id] or 0) + 1
                if catchCount[id] >= 3 then catchingMemory[id] = true end
                task.spawn(function() pcall(function() Utils.CatchMonster(id) end) end)
            end
        end
    end

    -- Xử lý chiến đấu, tự động di chuyển và đánh quái
    local function HandleCombat(hrp, humanoid, bestTarget, closestDist2D)
        RiftStatus:Set(Utils.t("rift_status_fight"))
        if not bestTarget then return end
        
        local targetPos = bestTarget.Position
        if closestDist2D > 12 then
            if closestDist2D > 40 then 
                pcall(function() Utils.ToggleMount(true) end) 
                -- Ép dịch chuyển lại gần quái nếu đứng quá xa
                hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 5))
                task.wait(0.2)
            end
            
            humanoid:MoveTo(targetPos)
            
            -- HỆ THỐNG GỠ KẸT (STUCK DETECTION)
            if dungeonLastPosition and (hrp.Position - dungeonLastPosition).Magnitude < 1 then
                dungeonStuckTimer = dungeonStuckTimer + 0.5
                if dungeonStuckTimer >= 2 then 
                    humanoid.Jump = true
                    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
                    dungeonStuckTimer = 0 
                end
            else 
                dungeonStuckTimer = 0 
            end
            dungeonLastPosition = hrp.Position
        else
            -- Đã áp sát mục tiêu
            humanoid:MoveTo(hrp.Position) 
            pcall(function() Utils.SmartDismount() end)
            dungeonStuckTimer = 0
            
            -- Xử lý ID an toàn cho cả BasePart và Model (chống race condition khi quái biến mất)
            local parent = bestTarget.Parent
            local parentName = parent and parent.Name
            local targetName = bestTarget.Name
            local id = (parentName and tonumber(parentName:match("Monster_(%d+)"))) 
                or (targetName and tonumber(targetName:match("Monster_(%d+)")))
            
            if id then 
                task.spawn(function() pcall(function() Utils.AttackMonster(id) end) end) 
            end 
        end
    end

    -- Thoát khỏi Rift sau khi hoàn thành nhiệm vụ
    local function ExecuteExitRift(controller)
        RiftStatus:Set(Utils.t("rift_status_done"))
        print("[TEST-LOG] Gửi lệnh thoát (ArenaLeaveChannel)...")
        
        local exit_id, exit_team = targetRiftId, currentTeamId
        task.spawn(function()
            pcall(function()
                DataPullFunc:InvokeServer("ArenaLeaveChannel")
                if exit_id and exit_team then 
                    DataPullFunc:InvokeServer("DungeonLeaveTeamChannel", exit_id, exit_team) 
                end
            end)
        end)
        
        if targetRiftKey then
            completedRifts[targetRiftKey] = os.time() + targetExpireDuration
            riftsClearedCount = riftsClearedCount + 1
            ClearedLabel:Set(Utils.t("rifts_cleared_prefix") .. riftsClearedCount)
            if string.match(targetRiftKey, "^Dyn_") then
                cycleState.lastDynamicActivityTime = os.time()
                print("[TEST-LOG] ⚡ Đã dọn xong cổng Dynamic: " .. tostring(targetRiftKey) .. ". Cập nhật lastDynamicActivityTime.")
            end
        end
        
        targetRiftId = nil
        targetRiftKey = nil
        riftEntryPosition = nil
        targetExpireDuration = 300
        catchingMemory = {}
        catchCount = {} 
        hasEncounteredMonsters = false
        
        if controller then controller.ReleaseLock("AutoRift") end
        riftState = "SCANNING"
        task.wait(1)
    end

    -- ==========================================
    -- MAIN LOOP 
    -- ==========================================
    task.spawn(function()
        DataPullFunc = ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager"):WaitForChild("Funcs"):WaitForChild("DataPullFunc")

        while task.wait(0.5) do
            local controller = _G.SystemController
            if controller and controller.IsPaused then continue end
            if not riftSettings.enabled or #riftSettings.selectedWorlds == 0 then continue end

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChild("Humanoid")
            if not (hrp and humanoid and humanoid.Health > 0) then continue end

            -- Yêu cầu giữ cờ AutoRift khi bắt đầu chu kỳ quét (Chống tranh chấp với AutoFarm)
            if controller and not cycleState.isResting then
                if not controller.RequestLock("AutoRift") and controller.CurrentLock ~= "AutoRift" then
                    RiftStatus:Set(Utils.t("rift_status_wait_lock"))
                    task.wait(0.5)
                    continue
                end
            end

            -- Xử lý quét quái chiến đấu trong Rift
            local monstersFolder = Workspace:FindFirstChild("Monsters")
            local hasAliveMonsters, deadMonsters, bestTarget, closestDist2D = false, {}, nil, math.huge
            local unhandledDeadCount = 0
            
            if riftState == "COMBAT" or riftState == "EXITING" then
                hasAliveMonsters, deadMonsters, bestTarget, closestDist2D = SmartScanMonsters(monstersFolder, hrp)
                for _, m in pairs(deadMonsters) do
                    local id = tonumber(m.Name:match("Monster_(%d+)"))
                    if id and not catchingMemory[id] then unhandledDeadCount = unhandledDeadCount + 1 end
                end
                
                -- Đánh dấu nếu phát hiện quái
                if hasAliveMonsters or unhandledDeadCount > 0 then
                    if not hasEncounteredMonsters then
                        print("[TEST-LOG] Đã phát hiện quái vật trong Rift! Bật cờ hasEncounteredMonsters = true")
                        hasEncounteredMonsters = true
                    end
                end
            end

            -- LOGIC QUÉT VÀ DI CHUYỂN MAP
            if riftState == "SCANNING" then
                riftEntryPosition = nil
                -- Xử lý thời gian nghỉ ngơi
                if cycleState.isResting then
                    if riftSettings.autoHop and controller then
                        table.insert(controller.TaskQueue, { 
                            Name = "RiftRoundHop", 
                            Func = function() 
                                if controller.RequestLock("AutoRift") then 
                                    Utils.HopServer("Hoàn tất 1 vòng quét Rift") 
                                    controller.ReleaseLock("AutoRift") 
                                end 
                            end 
                        })
                        task.wait(5)
                        continue
                    else
                        local timeLeft = cycleState.restEndTime - os.time()
                        if timeLeft > 0 then 
                            CycleStatus:Set(Utils.t("rift_cycle_resting") .. string.format("%02d:%02d", math.floor(timeLeft/60), timeLeft%60))
                            continue
                        else 
                            cycleState.isResting = false
                            cycleState.currentIndex = 1 
                        end
                    end
                end

                if not riftSettings.scanDynamic and not riftSettings.scanStatic then task.wait(1); continue end

                local shouldCycle = riftSettings.scanStatic
                local currentTick = os.time()
                local hasRecentDynamicActivity = (currentTick - cycleState.lastDynamicActivityTime) < 30

                if shouldCycle and not hasRecentDynamicActivity then
                    -- Chuyển world và chờ load map dữ liệu
                    local targetWorldId = riftSettings.selectedWorlds[cycleState.currentIndex]
                    if targetWorldId then
                        if cycleState.currentLoadedWorld ~= targetWorldId then
                            print("[TEST-LOG] Di chuyển sang World mới ID: " .. tostring(targetWorldId))
                            pcall(function() Utils.TeleportToArea(targetWorldId) end)
                            cycleState.currentLoadedWorld = targetWorldId
                            
                            print("[TEST-LOG] Bắt đầu đợi 7 giây cho Server nạp dữ liệu map (StreamingEnabled)...")
                            task.wait(7) -- Thời gian nghỉ chống lag load map
                            print("[TEST-LOG] Đợi load map xong, tiến hành quét cổng!")
                            continue
                        end
                        CycleStatus:Set(Utils.t("rift_cycle_map") .. tostring(targetWorldId))
                    else
                        print("[TEST-LOG] Đã chạy hết danh sách World -> Bắt đầu nghỉ ngơi/Chuyển Server")
                        cycleState.isResting = true
                        cycleState.restEndTime = os.time() + (riftSettings.restTimeMinutes * 60)
                        cycleState.currentLoadedWorld = nil
                        
                        -- Giải phóng cờ AutoRift trong suốt thời gian nghỉ
                        if controller and controller.CurrentLock == "AutoRift" then
                            controller.ReleaseLock("AutoRift")
                            print("[TEST-LOG] 🔓 Đã nhả cờ AutoRift cho hệ thống (Vào trạng thái nghỉ)")
                        end
                        continue
                    end
                else
                    -- Không thực hiện world cycle, giữ nguyên map hiện tại
                    local currentWorldId = Utils.GetCurrentAreaId() or cycleState.currentLoadedWorld or "Chưa xác định"
                    cycleState.currentLoadedWorld = currentWorldId
                    
                    if hasRecentDynamicActivity then
                        local timeLeft = 30 - (currentTick - cycleState.lastDynamicActivityTime)
                        CycleStatus:Set(string.format(Utils.t("rift_cycle_hold_map"), math.ceil(timeLeft)))
                    else
                        CycleStatus:Set(Utils.t("rift_cycle_scan_dynamic") .. tostring(currentWorldId) .. ")")
                    end
                end

                -- Làm sạch các Rift hết hạn blacklist
                CleanExpiredRifts()
                
                local bestPortal, shortestDistance = nil, math.huge
                print("[TEST-LOG] BẮT ĐẦU QUÉT RIFT TẠI MAP " .. tostring(cycleState.currentLoadedWorld or "Chưa xác định") .. " ")

                -- [MÁY QUÉT 1]: QUÉT DYNAMIC PORTALS
                if riftSettings.scanDynamic then
                    local dynamicFolder = Workspace:FindFirstChild("DynamicDungeon")
                    if dynamicFolder then
                        local dynChildren = dynamicFolder:GetChildren()
                        print("[TEST-LOG] Thấy thư mục DynamicDungeon. Số object bên trong: " .. #dynChildren)
                        bestPortal, shortestDistance = FindBestPortalFromList(dynChildren, hrp, shortestDistance, bestPortal, "Dyn_", "Cổng Dynamic")
                    else
                        print("[TEST-LOG] ⚠️ Không thấy thư mục Workspace.DynamicDungeon")
                    end
                end

                -- [MÁY QUÉT 2]: QUÉT STATIC PORTALS (Chỉ quét trong world hiện tại)
                if riftSettings.scanStatic and not bestPortal and cycleState.currentLoadedWorld then
                    local areaFolder = Workspace:FindFirstChild("Area")
                    if areaFolder then
                        for _, mapFolder in pairs(areaFolder:GetChildren()) do
                            if IsMapFolderMatchingId(mapFolder.Name, cycleState.currentLoadedWorld) then
                                local arDungeon = mapFolder:FindFirstChild("Area") and mapFolder.Area:FindFirstChild("Dungeon")
                                if arDungeon then
                                    local statChildren = arDungeon:GetChildren()
                                    print("[TEST-LOG] Thấy thư mục Dungeon trong map " .. mapFolder.Name .. ". Số object: " .. #statChildren)
                                    bestPortal, shortestDistance = FindBestPortalFromList(statChildren, hrp, shortestDistance, bestPortal, "Stat_", "Cổng Static")
                                end
                            end
                        end
                    else
                        print("[TEST-LOG] ⚠️ Không thấy thư mục Workspace.Area")
                    end
                end

                -- Xử lý di chuyển vào Rift được chọn
                if bestPortal then
                    TryEnterRift(bestPortal, hrp, controller)
                else
                    if shouldCycle and not hasRecentDynamicActivity then
                        print("[TEST-LOG] ⏩ Map này không có Rift hợp lệ -> Chuyển Map tiếp theo!")
                        cycleState.currentIndex = cycleState.currentIndex + 1
                        cycleState.currentLoadedWorld = nil 
                        task.wait(0.5) 
                    else
                        -- Đang giữ map để quét Dynamic hoặc không chạy Static cycle
                        print("[TEST-LOG] Đang giữ map, đợi cổng xuất hiện...")
                        task.wait(1.0)
                    end
                end

            elseif riftState == "COMBAT" then
                if unhandledDeadCount > 0 then
                    HandleCatching(deadMonsters)
                elseif hasAliveMonsters then
                    HandleCombat(hrp, humanoid, bestTarget, closestDist2D)
                else 
                    -- Đã xử lý xong quái, tiến hành thoát
                    if not hasEncounteredMonsters then
                        print("[TEST-LOG] Combat Mode: Đợi Server spawn con quái duy nhất...")
                        RiftStatus:Set(Utils.t("rift_status_wait_spawn"))
                    else
                        print("[TEST-LOG] Đã giết/bắt xong con quái duy nhất. Kích hoạt EXIT ngay lập tức!")
                        RiftStatus:Set(Utils.t("rift_status_done_exit"))
                        riftState = "EXITING" 
                    end
                end

            elseif riftState == "EXITING" then
                ExecuteExitRift(controller)
            end
        end
    end)
end

end

modules['features/optimization.txt'] = function(...)
-- ====================================================================
-- MODULE: TỐI ƯU HÓA & CHỐNG AFK
-- ====================================================================
return function(Window, Utils)
    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local VirtualUser = game:GetService("VirtualUser")

    local LocalPlayer = Players.LocalPlayer
    local originalFPS = 60
    local antiAfkEnabled = true

    local potatoEnabled = false
    local cleanVfxEnabled = false
    local autoGcEnabled = false

    local function applyPotatoToPart(v)
        if v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
        elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") then
            v:Destroy()
        end
    end

    local function applyVfxClean(v)
        local c = v.ClassName
        if c == "ParticleEmitter" or c == "Trail" or c == "Beam" or c == "Sparkles" or c == "Smoke" or c == "Fire" then
            v:Destroy()
        elseif v:IsA("BillboardGui") and (v.Name == "DamageTag" or string.match(v.Name, "Damage") or v:FindFirstChild("TextLabel")) then
            v:Destroy()
        end
    end

    -- Real-time optimization listener
    Workspace.DescendantAdded:Connect(function(v)
        if potatoEnabled then
            pcall(applyPotatoToPart, v)
        end
        if cleanVfxEnabled then
            pcall(applyVfxClean, v)
        end
    end)

    local function PerformAggressiveClean(silent)
        local before = gcinfo()
        collectgarbage("collect")
        local after = gcinfo()
        
        -- Clear console logs
        if clearconsole then
            pcall(clearconsole)
        elseif rconsoleclear then
            pcall(rconsoleclear)
        end
        
        -- Attempt DevConsole clearing
        pcall(function()
            local devConsoleController = require(game:GetService("CoreGui").RobloxGui.Modules.DevConsole.Controllers.DevConsoleController)
            if devConsoleController and devConsoleController.get then
                local controller = devConsoleController:get()
                if controller and controller.clear then
                    controller:clear()
                end
            end
        end)
        
        -- Free CoreGui Log cache
        pcall(function()
            local logService = game:GetService("LogService")
            if logService and type(logService.Clear) == "function" then
                logService:Clear()
            end
        end)

        local savedMB = (before - after) / 1024
        if not silent then
            pcall(function()
                game.StarterGui:SetCore("SendNotification", {
                    Title = "🧹 System Cleaned",
                    Text = string.format("Đã giải phóng %.2f MB RAM & xóa sạch logs!", savedMB),
                    Duration = 3
                })
            end)
        end
        print(string.format("[Optimization] Aggressive memory clean: Reduced Lua heap from %.2f MB to %.2f MB (Saved %.2f MB)", before / 1024, after / 1024, savedMB))
    end

    -- Auto GC Background thread (Chạy định kỳ mỗi 60 giây)
    task.spawn(function()
        while task.wait(60) do
            if autoGcEnabled then
                pcall(PerformAggressiveClean, true)
            end
        end
    end)

    -- LOGIC CHỐNG AFK NGẦM
    LocalPlayer.Idled:Connect(function() 
        if antiAfkEnabled then 
            VirtualUser:CaptureController() 
            VirtualUser:ClickButton2(Vector2.new()) 
        end 
    end)

    -- TẠO GIAO DIỆN
    local OptimizationTab = Window:CreateTab(Utils.t("optimization"), "zap")

    OptimizationTab:CreateToggle({ 
        Name = Utils.t("anti_afk"), 
        Info = Utils.t("anti_afk_info"),
        CurrentValue = true,
        Flag = "AntiAfk", 
        Callback = function(Value) antiAfkEnabled = Value end 
    })

    OptimizationTab:CreateToggle({ 
        Name = Utils.t("potato_mode"), 
        Info = Utils.t("potato_mode_info"),
        CurrentValue = false,
        Flag = "PotatoModeRealTime",
        Callback = function(Value)
            potatoEnabled = Value
            if Value then
                pcall(function()
                    Lighting.GlobalShadows = false 
                    Lighting.FogEnd = 9e9 
                    Lighting.ShadowSoftness = 0
                    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
                    if atmosphere then atmosphere:Destroy() end
                    
                    for _, v in ipairs(Workspace:GetDescendants()) do 
                        pcall(applyPotatoToPart, v)
                    end
                    
                    Workspace.Terrain.WaterWaveSize = 0 
                    Workspace.Terrain.WaterWaveSpeed = 0 
                    Workspace.Terrain.WaterReflectance = 0 
                    Workspace.Terrain.WaterTransparency = 1
                end)
            else
                pcall(function()
                    Lighting.GlobalShadows = true
                    Workspace.Terrain.WaterWaveSize = 0.15 
                    Workspace.Terrain.WaterWaveSpeed = 1 
                    Workspace.Terrain.WaterReflectance = 1 
                    Workspace.Terrain.WaterTransparency = 0.3
                end)
            end
        end 
    })

    OptimizationTab:CreateToggle({
        Name = Utils.t("clean_vfx"),
        Info = Utils.t("clean_vfx_info"),
        CurrentValue = false,
        Flag = "CleanVfxDebris",
        Callback = function(Value)
            cleanVfxEnabled = Value
            if Value then
                pcall(function()
                    for _, v in ipairs(Workspace:GetDescendants()) do
                        applyVfxClean(v)
                    end
                end)
            end
        end
    })

    OptimizationTab:CreateToggle({
        Name = Utils.t("auto_gc"),
        Info = Utils.t("auto_gc_info"),
        CurrentValue = false,
        Flag = "AutoGcMemory",
        Callback = function(Value)
            autoGcEnabled = Value
            if Value then
                pcall(collectgarbage, "collect")
            end
        end
    })

    OptimizationTab:CreateButton({
        Name = Utils.t("btn_clear_now"),
        Info = Utils.t("clear_ram_logs_info"),
        Callback = function()
            PerformAggressiveClean(false)
        end
    })

    OptimizationTab:CreateToggle({ 
        Name = Utils.t("limit_fps"), 
        Info = Utils.t("limit_fps_info"),
        CurrentValue = false, 
        Flag = "FpsLimiter", 
        Callback = function(Value) 
            if setfpscap then setfpscap(Value and 15 or originalFPS) end 
        end 
    })

    OptimizationTab:CreateToggle({ 
        Name = Utils.t("disable_3d"), 
        Info = Utils.t("disable_3d_info"),
        CurrentValue = false, 
        Flag = "Disable3D", 
        Callback = function(Value) 
            pcall(function() RunService:Set3dRenderingEnabled(not Value) end) 
        end 
    })
    local _streamerName = "Streamer" -- Tên mặc định
    local isSpoofing = false

    local realName = LocalPlayer.Name
    local realDisplayName = LocalPlayer.DisplayName

    local StreamerTab = OptimizationTab

    StreamerTab:CreateSection(" " .. Utils.t("streamer_section") .. " ")
    local NameInput = StreamerTab:CreateInput({
        Name = Utils.t("fake_name"),
        PlaceholderText = Utils.t("fake_name_placeholder"),
        Info = Utils.t("fake_name_info"),
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            if Text and Text ~= "" then
                _streamerName = Text
            end
        end,
    })

    StreamerTab:CreateToggle({
        Name = Utils.t("streamer_mode"),
        Info = Utils.t("streamer_mode_info"),
        CurrentValue = false,
        Flag = "StreamerSpoofToggle",
        Callback = function(Value)
            isSpoofing = Value
            
            -- Trả lại tên thật nếu tắt công tắc
            if not Value then
                pcall(function()
                    local char = LocalPlayer.Character
                    if char then
                        local labName = char:FindFirstChild("HumanoidRootPart")
                            and char.HumanoidRootPart:FindFirstChild("NameTag")
                            and char.HumanoidRootPart.NameTag:FindFirstChild("FmSize")
                            and char.HumanoidRootPart.NameTag.FmSize:FindFirstChild("FmName")
                            and char.HumanoidRootPart.NameTag.FmSize.FmName:FindFirstChild("LabName")
                        
                        if labName then
                            labName.Text = realDisplayName
                        end
                        
                        local hum = char:FindFirstChild("Humanoid")
                        if hum then hum.DisplayName = realDisplayName end
                    end
                end)
            end
        end
    })

    -- ==========================================
    -- VÒNG LẶP KHÓA MỤC TIÊU (0.1s/lần)
    -- ==========================================
    task.spawn(function()
        while task.wait(0.1) do
            if isSpoofing then
                pcall(function()
                    local char = LocalPlayer.Character
                    if char then
                        -- 1. Đánh thẳng vào đường dẫn Custom UI từ ảnh F9
                        local labName = char:FindFirstChild("HumanoidRootPart")
                            and char.HumanoidRootPart:FindFirstChild("NameTag")
                            and char.HumanoidRootPart.NameTag:FindFirstChild("FmSize")
                            and char.HumanoidRootPart.NameTag.FmSize:FindFirstChild("FmName")
                            and char.HumanoidRootPart.NameTag.FmSize.FmName:FindFirstChild("LabName")
                        
                        if labName then
                            -- Nếu thấy có chứa tên thật thì đè tên giả vào
                            if string.find(labName.Text, realName) or string.find(labName.Text, realDisplayName) then
                                labName.Text = _streamerName
                            end
                        end
                        
                        -- 2. Đổi luôn DisplayName của Humanoid (Đề phòng game dùng cả 2)
                        local hum = char:FindFirstChild("Humanoid")
                        if hum and hum.DisplayName ~= _streamerName then
                            hum.DisplayName = _streamerName
                        end
                    end
                end)
            end
        end
    end)

    -- Intercept và ẩn tên thật trong toàn bộ thông báo hệ thống (StarterGui:SetCore)
    pcall(function()
        local StarterGui = game:GetService("StarterGui")
        if hookfunction then
            local oldSetCore
            oldSetCore = hookfunction(StarterGui.SetCore, function(self, name, data)
                if isSpoofing and name == "SendNotification" and type(data) == "table" then
                    if data.Title and type(data.Title) == "string" then
                        data.Title = string.gsub(data.Title, realName, _streamerName)
                        data.Title = string.gsub(data.Title, realDisplayName, _streamerName)
                    end
                    if data.Text and type(data.Text) == "string" then
                        data.Text = string.gsub(data.Text, realName, _streamerName)
                        data.Text = string.gsub(data.Text, realDisplayName, _streamerName)
                    end
                end
                return oldSetCore(self, name, data)
            end)
        else
            local rawSetCore = StarterGui.SetCore
            StarterGui.SetCore = function(self, name, data)
                if isSpoofing and name == "SendNotification" and type(data) == "table" then
                    if data.Title and type(data.Title) == "string" then
                        data.Title = string.gsub(data.Title, realName, _streamerName)
                        data.Title = string.gsub(data.Title, realDisplayName, _streamerName)
                    end
                    if data.Text and type(data.Text) == "string" then
                        data.Text = string.gsub(data.Text, realName, _streamerName)
                        data.Text = string.gsub(data.Text, realDisplayName, _streamerName)
                    end
                end
                return rawSetCore(self, name, data)
            end
        end
    end)

    -- Luồng quét định kỳ quét sạch tên thật trên toàn bộ giao diện màn hình (PlayerGui)
    task.spawn(function()
        while task.wait(0.5) do
            if isSpoofing then
                pcall(function()
                    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                    if playerGui then
                        for _, v in ipairs(playerGui:GetDescendants()) do
                            if v:IsA("TextLabel") or v:IsA("TextButton") then
                                if string.find(v.Text, realName) or string.find(v.Text, realDisplayName) then
                                    local txt = v.Text
                                    txt = string.gsub(txt, realName, _streamerName)
                                    txt = string.gsub(txt, realDisplayName, _streamerName)
                                    v.Text = txt
                                end
                            end
                        end
                    end
                end)
            end
        end
    end)
end

end

modules['features/ai_assistant.txt'] = function(...)
-- ====================================================================
-- MODULE: Best Script AI ASSISTANT (V4.5)
-- Thay đổi so với V4.4:
--   [FIX]  PromptInput scroll khi paste text dài
--   [FIX]  ResetSubmitButton không reset isProcessing (timeout bug)
--   [FIX]  CleanCodeResponse strip \r\n Windows line ending
--   [FIX]  Auto-scroll output xuống cuối sau khi nhận response
--   [NEW]  Conversation history — AI nhớ context nhiều lượt
--   [NEW]  Model selector — cycle Gemini Flash / Pro
--   [NEW]  Prompt history — nhấn nút ↑ để lấy lại prompt cũ
-- ====================================================================

local UTF8_MAP = {
    ["á"]="a",["à"]="a",["ả"]="a",["ã"]="a",["ạ"]="a",["ă"]="a",["ắ"]="a",["ằ"]="a",["ẳ"]="a",["ẵ"]="a",["ặ"]="a",["â"]="a",["ấ"]="a",["ầ"]="a",["ẩ"]="a",["ẫ"]="a",["ậ"]="a",
    ["é"]="e",["è"]="e",["ẻ"]="e",["ẽ"]="e",["ẹ"]="e",["ê"]="e",["ế"]="e",["ề"]="e",["ể"]="e",["ễ"]="e",["ệ"]="e",
    ["í"]="i",["ì"]="i",["ỉ"]="i",["ĩ"]="i",["ị"]="i",
    ["ó"]="o",["ò"]="o",["ỏ"]="o",["õ"]="o",["ọ"]="o",["ô"]="o",["ố"]="o",["ồ"]="o",["ổ"]="o",["ỗ"]="o",["ộ"]="o",["ơ"]="o",["ớ"]="o",["ờ"]="o",["ở"]="o",["ỡ"]="o",["ợ"]="o",
    ["ú"]="u",["ù"]="u",["ủ"]="u",["ũ"]="u",["ụ"]="u",["ư"]="u",["ứ"]="u",["ừ"]="u",["ử"]="u",["ữ"]="u",["ự"]="u",
    ["ý"]="y",["ỳ"]="y",["ỷ"]="y",["ỹ"]="y",["ỵ"]="y",["đ"]="d",
    ["Á"]="A",["À"]="A",["Ả"]="A",["Ã"]="A",["Ạ"]="A",["Ă"]="A",["Ắ"]="A",["Ằ"]="A",["Ẳ"]="A",["Ẵ"]="A",["Ặ"]="A",["Â"]="A",["Ấ"]="A",["Ầ"]="A",["Ẩ"]="A",["Ẫ"]="A",["Ậ"]="A",
    ["É"]="E",["È"]="E",["Ẻ"]="E",["Ẽ"]="E",["Ẹ"]="E",["Ê"]="E",["Ế"]="E",["Ề"]="E",["Ể"]="E",["Ễ"]="E",["Ệ"]="E",
    ["Í"]="I",["Ì"]="I",["Ỉ"]="I",["Ĩ"]="I",["Ị"]="I",
    ["Ó"]="O",["Ò"]="O",["Ỏ"]="O",["Õ"]="O",["Ọ"]="O",["Ô"]="O",["Ố"]="O",["Ồ"]="O",["Ổ"]="O",["Ỗ"]="O",["Ộ"]="O",["Ơ"]="O",["Ớ"]="O",["Ờ"]="O",["Ở"]="O",["Ỡ"]="O",["Ợ"]="O",
    ["Ú"]="U",["Ù"]="U",["Ủ"]="U",["Ũ"]="U",["Ụ"]="U",["Ư"]="U",["Ứ"]="U",["Ừ"]="U",["Ử"]="U",["Ữ"]="U",["Ự"]="U",
    ["Ý"]="Y",["Ỳ"]="Y",["Ỷ"]="Y",["Ỹ"]="Y",["Ỵ"]="Y",["Đ"]="D"
}

return function(Window, Utils, WebhookModule)
    local HttpService      = game:GetService("HttpService")
    local CoreGui          = game:GetService("CoreGui")
    local UserInputService = game:GetService("UserInputService")

    local API_KEY_FILE = "R_ClientPro_AI_Key.txt"
    local GUI_NAME     = "RClientPro_AIAssistantUI"
    local API_TIMEOUT  = 15

    if CoreGui:FindFirstChild(GUI_NAME) then CoreGui[GUI_NAME]:Destroy() end

    -- ==========================================
    -- HÀM TIỆN ÍCH
    -- ==========================================

    local function GetSavedAPIKey()
        if isfile and isfile(API_KEY_FILE) then
            local key = readfile(API_KEY_FILE)
            if key and key ~= "" then return string.gsub(key, "^%s*(.-)%s*$", "%1") end
        end
        return nil
    end

    local function SaveAPIKey(key)
        if writefile then pcall(function() writefile(API_KEY_FILE, key) end) end
    end

    local function CopyToClipboard(text)
        if setclipboard then pcall(function() setclipboard(text) end) end
    end

    local function RemoveAccents(str)
        if type(str) ~= "string" then return str end
        for k, v in pairs(UTF8_MAP) do str = string.gsub(str, k, v) end
        return str
    end

    -- FIX: strip \r\n Windows line ending
    local function CleanCodeResponse(rawCode)
        rawCode = string.gsub(rawCode, "```lua\n?", "")
        rawCode = string.gsub(rawCode, "```\n?", "")
        rawCode = string.gsub(rawCode, "\r\n", "\n")
        rawCode = string.gsub(rawCode, "^%s*(.-)%s*$", "%1")
        return rawCode
    end

    -- ==========================================
    -- STATE
    -- ==========================================

    local isProcessing      = false
    local pendingCode       = nil
    local conversationHistory = {}       -- NEW: lịch sử hội thoại
    local promptHistory     = {}         -- NEW: lịch sử prompt
    local historyIndex      = 0
    local useWebhook        = false

    -- NEW: Model selector
    local MODELS = {
        { label = "⚡ Flash (Nhanh)", id = "gemini-2.5-flash" },
        { label = "🧠 Pro (Mạnh)",   id = "gemini-2.5-pro"   },
    }
    local currentModelIdx = 1

    -- ==========================================
    -- UI
    -- ==========================================

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = GUI_NAME
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 450, 0, 490)
    MainFrame.Position = UDim2.new(1, -470, 0, 50)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = false
    MainFrame.Visible = false
    MainFrame.Parent = ScreenGui
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 30)
    TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    TitleBar.Parent = MainFrame
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -40, 1, 0)
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = Utils.t("ai_title") --(L-Alt Ẩn/Hiện)
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 13
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    -- Drag
    local dragging, dragInput, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    TitleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- API Key
    local KeyInput = Instance.new("TextBox")
    KeyInput.Size = UDim2.new(1, -20, 0, 30)
    KeyInput.Position = UDim2.new(0, 10, 0, 40)
    KeyInput.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    KeyInput.TextColor3 = Color3.fromRGB(200, 200, 200)
    KeyInput.Font = Enum.Font.Gotham
    KeyInput.TextSize = 12
    KeyInput.PlaceholderText = GetSavedAPIKey() and Utils.t("ai_key_saved") or Utils.t("ai_key_prompt")
    KeyInput.Text = ""
    KeyInput.ClearTextOnFocus = false
    KeyInput.Parent = MainFrame
    Instance.new("UICorner", KeyInput).CornerRadius = UDim.new(0, 4)

    KeyInput.FocusLost:Connect(function()
        if KeyInput.Text ~= "" then
            SaveAPIKey(KeyInput.Text)
            KeyInput.PlaceholderText = Utils.t("saved_title") .. "!"
            KeyInput.Text = ""
        end
    end)

    -- NEW: Model selector button
    local ModelBtn = Instance.new("TextButton")
    ModelBtn.Size = UDim2.new(1, -20, 0, 26)
    ModelBtn.Position = UDim2.new(0, 10, 0, 78)
    ModelBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    ModelBtn.TextColor3 = Color3.fromRGB(180, 220, 255)
    ModelBtn.Font = Enum.Font.GothamBold
    ModelBtn.TextSize = 11
    ModelBtn.Text = "Model: " .. MODELS[currentModelIdx].label
    ModelBtn.Parent = MainFrame
    Instance.new("UICorner", ModelBtn).CornerRadius = UDim.new(0, 4)

    ModelBtn.MouseButton1Click:Connect(function()
        currentModelIdx = (currentModelIdx % #MODELS) + 1
        ModelBtn.Text = "Model: " .. MODELS[currentModelIdx].label
    end)

    -- Output ScrollingFrame
    local OutputScroll = Instance.new("ScrollingFrame")
    OutputScroll.Size = UDim2.new(1, -20, 0, 155)
    OutputScroll.Position = UDim2.new(0, 10, 0, 112)
    OutputScroll.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    OutputScroll.BorderSizePixel = 0
    OutputScroll.ScrollBarThickness = 4
    OutputScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    OutputScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    OutputScroll.Parent = MainFrame
    Instance.new("UICorner", OutputScroll).CornerRadius = UDim.new(0, 4)

    local OutputPadding = Instance.new("UIPadding")
    OutputPadding.PaddingLeft = UDim.new(0, 6); OutputPadding.PaddingRight  = UDim.new(0, 6)
    OutputPadding.PaddingTop  = UDim.new(0, 6); OutputPadding.PaddingBottom = UDim.new(0, 6)
    OutputPadding.Parent = OutputScroll

    local OutputLabel = Instance.new("TextLabel")
    OutputLabel.Size = UDim2.new(1, -12, 0, 0)
    OutputLabel.AutomaticSize = Enum.AutomaticSize.Y
    OutputLabel.BackgroundTransparency = 1
    OutputLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    OutputLabel.Font = Enum.Font.Code
    OutputLabel.TextSize = 12
    OutputLabel.TextXAlignment = Enum.TextXAlignment.Left
    OutputLabel.TextYAlignment = Enum.TextYAlignment.Top
    OutputLabel.TextWrapped = true
    OutputLabel.Text = Utils.t("ai_system_ready")
    OutputLabel.Parent = OutputScroll

    -- FIX: auto-scroll output xuống cuối
    local function ScrollOutputToBottom()
        task.wait()
        OutputScroll.CanvasPosition = Vector2.new(0, math.max(0, OutputLabel.AbsoluteSize.Y - OutputScroll.AbsoluteSize.Y + 12))
    end

    OutputLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        OutputScroll.CanvasSize = UDim2.new(0, 0, 0, OutputLabel.AbsoluteSize.Y + 12)
    end)

    -- FIX SCROLL INPUT: ScrollingFrame bọc TextBox — text dài không bị clip
    local PromptScroll = Instance.new("ScrollingFrame")
    PromptScroll.Size = UDim2.new(1, -20, 0, 95)
    PromptScroll.Position = UDim2.new(0, 10, 0, 275)
    PromptScroll.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    PromptScroll.BorderSizePixel = 0
    PromptScroll.ScrollBarThickness = 4
    PromptScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    PromptScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    PromptScroll.Parent = MainFrame
    Instance.new("UICorner", PromptScroll).CornerRadius = UDim.new(0, 4)

    local PromptInput = Instance.new("TextBox")
    PromptInput.Size = UDim2.new(1, -12, 0, 0)
    PromptInput.Position = UDim2.new(0, 6, 0, 6)
    PromptInput.AutomaticSize = Enum.AutomaticSize.Y
    PromptInput.BackgroundTransparency = 1
    PromptInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PromptInput.Font = Enum.Font.Code
    PromptInput.TextSize = 13
    PromptInput.PlaceholderText = Utils.t("ai_prompt_placeholder")
    PromptInput.PlaceholderColor3 = Color3.fromRGB(90, 90, 100)
    PromptInput.TextWrapped = true
    PromptInput.ClearTextOnFocus = false
    PromptInput.MultiLine = true
    PromptInput.TextXAlignment = Enum.TextXAlignment.Left
    PromptInput.TextYAlignment = Enum.TextYAlignment.Top
    PromptInput.Parent = PromptScroll

    PromptInput:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local h = PromptInput.AbsoluteSize.Y + 12
        PromptScroll.CanvasSize = UDim2.new(0, 0, 0, h)
        if PromptInput:IsFocused() then
            PromptScroll.CanvasPosition = Vector2.new(0, math.max(0, h - PromptScroll.AbsoluteSize.Y))
        end
    end)

    -- NEW: Prompt history button (↑)
    local HistoryBtn = Instance.new("TextButton")
    HistoryBtn.Size = UDim2.new(0, 32, 0, 26)
    HistoryBtn.Position = UDim2.new(1, -42, 0, 275)
    HistoryBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    HistoryBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
    HistoryBtn.Font = Enum.Font.GothamBold
    HistoryBtn.TextSize = 14
    HistoryBtn.Text = "↑"
    HistoryBtn.Parent = MainFrame
    Instance.new("UICorner", HistoryBtn).CornerRadius = UDim.new(0, 4)

    HistoryBtn.MouseButton1Click:Connect(function()
        if #promptHistory == 0 then return end
        historyIndex = math.max(1, historyIndex - 1 == 0 and #promptHistory or historyIndex - 1)
        PromptInput.Text = promptHistory[historyIndex] or ""
    end)

    -- Webhook Toggle
    local WebhookToggleBtn = Instance.new("TextButton")
    WebhookToggleBtn.Size = UDim2.new(1, -20, 0, 28)
    WebhookToggleBtn.Position = UDim2.new(0, 10, 0, 378)
    WebhookToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    WebhookToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookToggleBtn.Font = Enum.Font.GothamBold
    WebhookToggleBtn.TextSize = 11
    WebhookToggleBtn.Text = Utils.t("ai_webhook_log") .. Utils.t("toggle_off")
    WebhookToggleBtn.Parent = MainFrame
    Instance.new("UICorner", WebhookToggleBtn).CornerRadius = UDim.new(0, 4)

    WebhookToggleBtn.MouseButton1Click:Connect(function()
        if not WebhookModule or type(WebhookModule.SendNotification) ~= "function" then
            OutputLabel.Text = OutputLabel.Text .. "\n\n[LOI] WebhookModule khong hop le."
            ScrollOutputToBottom()
            return
        end
        useWebhook = not useWebhook
        WebhookToggleBtn.Text = Utils.t("ai_webhook_log") .. (useWebhook and Utils.t("toggle_on") or Utils.t("toggle_off"))
        WebhookToggleBtn.BackgroundColor3 = useWebhook and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(40, 40, 45)
    end)

    -- NEW: Clear history button
    local ClearBtn = Instance.new("TextButton")
    ClearBtn.Size = UDim2.new(1, -20, 0, 28)
    ClearBtn.Position = UDim2.new(0, 10, 0, 414)
    ClearBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    ClearBtn.TextColor3 = Color3.fromRGB(255, 180, 180)
    ClearBtn.Font = Enum.Font.GothamBold
    ClearBtn.TextSize = 11
    ClearBtn.Text = "🗑 " .. Utils.t("ai_clear_history")
    ClearBtn.Parent = MainFrame
    Instance.new("UICorner", ClearBtn).CornerRadius = UDim.new(0, 4)

    ClearBtn.MouseButton1Click:Connect(function()
        conversationHistory = {}
        promptHistory = {}
        historyIndex = 0
        OutputLabel.Text = Utils.t("ai_history_cleared")
        ScrollOutputToBottom()
    end)

    -- Submit Btn
    local SubmitBtn = Instance.new("TextButton")
    SubmitBtn.Size = UDim2.new(1, -20, 0, 33)
    SubmitBtn.Position = UDim2.new(0, 10, 0, 450)
    SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    SubmitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SubmitBtn.Font = Enum.Font.GothamBold
    SubmitBtn.TextSize = 13
    SubmitBtn.Text = Utils.t("ai_get_code")
    SubmitBtn.Parent = MainFrame
    Instance.new("UICorner", SubmitBtn).CornerRadius = UDim.new(0, 4)

    -- Execute Btn
    local ExecuteBtn = Instance.new("TextButton")
    ExecuteBtn.Size = UDim2.new(1, -20, 0, 33)
    ExecuteBtn.Position = UDim2.new(0, 10, 0, 450)  -- sẽ dời khi có code
    ExecuteBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    ExecuteBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    ExecuteBtn.Font = Enum.Font.GothamBold
    ExecuteBtn.TextSize = 13
    ExecuteBtn.Text = Utils.t("ai_execute_code")
    ExecuteBtn.Visible = false
    ExecuteBtn.Parent = MainFrame
    Instance.new("UICorner", ExecuteBtn).CornerRadius = UDim.new(0, 4)

    -- ==========================================
    -- HÀM RESET UI
    -- ==========================================

    -- FIX: ResetSubmitButton phải reset isProcessing
    local function ResetSubmitButton()
        isProcessing = false
        SubmitBtn.Text = Utils.t("ai_get_code")
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    end

    local function SetExecuteButtonReady(code)
        pendingCode = code
        ExecuteBtn.Visible = true
        ExecuteBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 0)
        ExecuteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        ExecuteBtn.Text = Utils.t("ai_execute_code")
    end

    local function ResetExecuteButton()
        pendingCode = nil
        ExecuteBtn.Visible = false
    end

    -- ==========================================
    -- WEBHOOK LOG
    -- ==========================================

    local function TrySendWebhookLog(prompt, logMsg)
        if not (useWebhook and WebhookModule and type(WebhookModule.SendNotification) == "function") then return end
        local finalLog = RemoveAccents("[AI Log]\nPrompt: " .. prompt .. "\n" .. logMsg)
        pcall(function() WebhookModule.SendNotification(finalLog) end)
    end

    -- ==========================================
    -- GEMINI API — hỗ trợ conversation history
    -- ==========================================

    local function RequestAICode(userPrompt)
        local savedKey = GetSavedAPIKey()
        if not savedKey then return false, Utils.t("ai_err_no_key") end

        local reqFunc = request or http_request or (syn and syn.request)
        if not reqFunc then return false, Utils.t("ai_err_no_http") end

        local modelId = MODELS[currentModelIdx].id
        local API_URL = "https://generativelanguage.googleapis.com/v1beta/models/" .. modelId .. ":generateContent?key=" .. savedKey

        -- Thêm prompt mới vào history
        table.insert(conversationHistory, {
            role = "user",
            parts = { { text = userPrompt } }
        })

        -- System instruction inject vào turn đầu tiên
        local systemInstruction = "You are a Roblox Lua exploit developer. Only respond with raw, executable Lua code. Do not include markdown blocks, do not include ```lua tags, no explanations."
        local contents = {}
        for i, turn in ipairs(conversationHistory) do
            if i == 1 then
                table.insert(contents, {
                    role = turn.role,
                    parts = { { text = systemInstruction .. "\n\n" .. turn.parts[1].text } }
                })
            else
                table.insert(contents, turn)
            end
        end

        local payload = { contents = contents }
        local success, response = pcall(function()
            return reqFunc({
                Url = API_URL, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)

        if not success then
            -- Rollback history nếu request fail
            table.remove(conversationHistory)
            return false, Utils.t("ai_err_connect")
        end

        if response.StatusCode ~= 200 then
            table.remove(conversationHistory)
            return false, Utils.t("ai_err_http") .. tostring(response.StatusCode)
        end

        local ok, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if not ok then
            table.remove(conversationHistory)
            return false, Utils.t("ai_err_json")
        end

        local part = data.candidates
            and data.candidates[1]
            and data.candidates[1].content
            and data.candidates[1].content.parts
            and data.candidates[1].content.parts[1]

        if not part then
            table.remove(conversationHistory)
            return false, Utils.t("ai_err_empty")
        end

        -- Lưu response của model vào history
        table.insert(conversationHistory, {
            role = "model",
            parts = { { text = part.text } }
        })

        return true, part.text
    end

    -- ==========================================
    -- EXECUTE CODE
    -- ==========================================

    local function ExecuteCode(code, prompt)
        local logMsg = ""
        local func, compileError = loadstring(code)
        if not func then
            logMsg = "Compile Error:\n" .. tostring(compileError)
            OutputLabel.Text = OutputLabel.Text .. "\n\n" .. Utils.t("ai_compile_error") .. "\n" .. tostring(compileError)
            ScrollOutputToBottom()
            TrySendWebhookLog(prompt or "", logMsg)
            return
        end

        local runSuccess, runtimeError = pcall(func)
        if runSuccess then
            logMsg = "OK:\n" .. code
            OutputLabel.Text = OutputLabel.Text .. "\n\n" .. Utils.t("ai_execute_success")
        else
            logMsg = "Runtime Error:\n" .. tostring(runtimeError)
            OutputLabel.Text = OutputLabel.Text .. "\n\n" .. Utils.t("ai_runtime_error") .. "\n" .. tostring(runtimeError)
        end

        ScrollOutputToBottom()
        TrySendWebhookLog(prompt or "", logMsg)
        ResetExecuteButton()
    end

    -- ==========================================
    -- SUBMIT BUTTON
    -- ==========================================

    SubmitBtn.MouseButton1Click:Connect(function()
        if isProcessing then return end
        local prompt = PromptInput.Text
        if prompt == "" then return end

        isProcessing = true
        ResetExecuteButton()
        SubmitBtn.Text = Utils.t("ai_processing")
        SubmitBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 0)
        OutputLabel.Text = Utils.t("ai_waiting")
        ScrollOutputToBottom()

        -- Timeout: isProcessing=false bên trong ResetSubmitButton → an toàn
        task.delay(API_TIMEOUT, function()
            if isProcessing then
                OutputLabel.Text = Utils.t("ai_timeout_prefix") .. API_TIMEOUT .. "s"
                ScrollOutputToBottom()
                ResetSubmitButton()
            end
        end)

        task.spawn(function()
            local success, rawCode = RequestAICode(prompt)

            if success then
                rawCode = CleanCodeResponse(rawCode)
                OutputLabel.Text = Utils.t("ai_read_code_warn") .. rawCode
                CopyToClipboard(rawCode)
                PromptInput.Text = ""
                ScrollOutputToBottom()

                -- Lưu vào prompt history
                table.insert(promptHistory, prompt)
                historyIndex = #promptHistory + 1

                SetExecuteButtonReady(rawCode)
                SubmitBtn.Text = Utils.t("ai_got_code")
                SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            else
                TrySendWebhookLog(prompt, "API Error: " .. tostring(rawCode))
                OutputLabel.Text = Utils.t("ai_error_prefix") .. tostring(rawCode)
                ScrollOutputToBottom()
                SubmitBtn.Text = Utils.t("ai_error")
                SubmitBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
            end

            isProcessing = false

            task.wait(2)
            if success then
                SubmitBtn.Text = Utils.t("ai_get_code")
                SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
            else
                ResetSubmitButton()
            end
        end)
    end)

    -- ==========================================
    -- EXECUTE BUTTON
    -- ==========================================

    ExecuteBtn.MouseButton1Click:Connect(function()
        if not pendingCode then return end
        local codeToRun = pendingCode
        local lastPrompt = PromptInput.Text
        ExecuteBtn.Text = Utils.t("ai_running")
        task.spawn(function() ExecuteCode(codeToRun, lastPrompt) end)
    end)

    -- ==========================================
    -- PHÍM TẮT
    -- ==========================================

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)) then
        MainFrame.Visible = not MainFrame.Visible
    end
end)
    print("AI Assistant Module (V4.5) Loaded!")
end
end

modules['features/auto_event.txt'] = function(...)
-- ====================================================================
-- MODULE: SMART AUTO EVENT SYSTEM V2.0 (Abuse Eggs, Chests, Robbery & Quizzes)
-- ====================================================================
return function(Window, Utils)
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local VirtualInputManager = game:GetService("VirtualInputManager")
    
    local LocalPlayer = Players.LocalPlayer

    local eventSettings = {
        enabled = false,
        xrayEnabled = false,
        priorityMode = "Smart Scoring",
        weightEgg = 80,
        weightChest = 100,
        weightGem = 50,
        weightGold = 1
    }

    local claimedCache = {}

    -- UI TAB
    local EventTab = Window:CreateTab(Utils.t("auto_event"), "calendar")
    
    EventTab:CreateParagraph({
        Title = "💡 " .. Utils.t("event_guide_title"),
        Content = Utils.t("event_guide_content")
    })
    
    -- LIVE HUD AT TOP
    EventTab:CreateSection(" " .. Utils.t("hud_obby_title") .. " ")
    local LiveHud = EventTab:CreateParagraph({
        Title = "📡 Đang chờ sự kiện bắt đầu...",
        Content = ""
    })
    
    local EventStatus = EventTab:CreateLabel(Utils.t("event_status_idle"))

    -- CONTROLS
    EventTab:CreateSection(" " .. Utils.t("sec_event_controls") .. " ")
    EventTab:CreateToggle({
        Name = Utils.t("auto_event_toggle"),
        Info = Utils.t("auto_event_info"),
        CurrentValue = false,
        Flag = "AutoClaimEventItems",
        Callback = function(Value)
            eventSettings.enabled = Value
            if not Value then
                EventStatus:Set(Utils.t("event_status_idle"))
                LiveHud:Set({ Title = "📡 Đang chờ sự kiện bắt đầu...", Content = "" })
            else
                EventStatus:Set(Utils.t("event_status_farming"))
            end
        end
    })

    EventTab:CreateToggle({
        Name = Utils.t("event_xray_toggle"),
        Info = Utils.t("event_xray_info"),
        CurrentValue = false,
        Flag = "EventXrayPreview",
        Callback = function(Value)
            eventSettings.xrayEnabled = Value
            if not Value then
                pcall(function()
                    for _, v in ipairs(Workspace:GetDescendants()) do
                        if v.Name == "EventXrayBillboard" then
                            v:Destroy()
                        end
                    end
                end)
            end
        end
    })



    -- Helper to check thread-identity bypass
    local get_thread_id = getthreadcontext or getthreadidentity or getidentity or (syn and syn.get_thread_identity)
    local set_thread_id = setthreadcontext or setthreadidentity or setidentity or (syn and syn.set_thread_identity)

    local function getEventClaimables()
        local list = {}
        for _, v in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if v:IsA("Model") or v:IsA("BasePart") then
                    local obbyId = v:GetAttribute("ObbyId")
                    local rewardIdx = v:GetAttribute("RewardIndex")
                    if obbyId and rewardIdx then
                        table.insert(list, {
                            type = "SpaceReward",
                            object = v,
                            obbyId = obbyId,
                            rewardIndex = rewardIdx,
                            pos = v:GetPivot().Position
                        })
                        return
                    end
                    
                    local robberyIndex = v:GetAttribute("Index")
                    local eventKey = v:GetAttribute("EventKey")
                    if robberyIndex and eventKey then
                        table.insert(list, {
                            type = "Robbery",
                            object = v,
                            index = robberyIndex,
                            eventKey = eventKey,
                            pos = v:GetPivot().Position
                        })
                        return
                    end
                    
                    if string.match(v.Name, "^PET_baoxiang") then
                        table.insert(list, {
                            type = "Baoxiang",
                            object = v,
                            pos = v:GetPivot().Position
                        })
                        return
                    end
                    
                    if v.Name == "AbuseEgg" or v.Name == "Abuse Egg" or v.Name == "xmas admin" then
                        table.insert(list, {
                            type = "EventEgg",
                            object = v,
                            pos = v:GetPivot().Position
                        })
                        return
                    end
                end
            end)
        end
        return list
    end

    local function getHrp()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function formatReward(rewardList)
        if not rewardList or #rewardList == 0 then return "Không có quà" end
        local parts = {}
        for _, item in ipairs(rewardList) do
            local res = item.RewardRes
            local count = item.Count or item.Amount or 1
            if res == "Egg" then
                table.insert(parts, "Trứng (ID " .. tostring(item.TmplId) .. ") x" .. tostring(count))
            elseif res == "TreasureBox" then
                table.insert(parts, "Rương (ID " .. tostring(item.TmplId) .. ") x" .. tostring(count))
            elseif res == "Value" then
                local name = (item.ValueType == "HuoBi_3" and "Kim Cương") or (item.ValueType == "HuoBi_1" and "Vàng") or item.ValueType
                table.insert(parts, name .. " x" .. tostring(count))
            else
                table.insert(parts, tostring(res) .. " x" .. tostring(count))
            end
        end
        return table.concat(parts, ", ")
    end

    local function getRewardPriorityScore(rewardList)
        if not rewardList then return 0 end
        local totalScore = 0
        for _, item in ipairs(rewardList) do
            local res = item.RewardRes
            local count = item.Count or item.Amount or 1
            local typeScore = 1
            
            if res == "Egg" then
                typeScore = eventSettings.weightEgg
            elseif res == "TreasureBox" then
                typeScore = eventSettings.weightChest
            elseif res == "PetExpItem" or res == "CommonItem" then
                typeScore = 30
            elseif res == "Value" then
                local vt = item.ValueType
                if vt == "HuoBi_3" then -- Gems
                    typeScore = eventSettings.weightGem
                elseif vt == "HuoBi_13" then
                    typeScore = eventSettings.weightGem * 0.8
                elseif vt == "HuoBi_1" then -- Gold
                    typeScore = eventSettings.weightGold * 0.001
                else
                    typeScore = 10
                end
            end
            
            totalScore = totalScore + (typeScore * count)
        end
        return totalScore
    end

    local function getNewSelectPartScore(part, CfgNewSelect)
        local selectKey = part:GetAttribute("SelectKey")
        local selectType = part:GetAttribute("SelectType")
        if selectKey and selectType and CfgNewSelect then
            local selectData = CfgNewSelect[selectKey]
            local selectInfo = selectData and selectData.SelectInfo and selectData.SelectInfo[tostring(selectType)]
            if selectInfo and selectInfo.Reward then
                return getRewardPriorityScore(selectInfo.Reward), selectInfo.Reward
            end
        end
        return 0, nil
    end

    -- Core Loop
    task.spawn(function()
        while task.wait(0.5) do
            if not eventSettings.enabled then continue end
            
            local hrp = getHrp()
            if not hrp then continue end
            
            -- ƯU TIÊN 1: KIỂM TRA SỰ KIỆN LỰA CHỌN (Q&A / CHỌN HÌNH ĐÚNG) ĐANG DIỄN RA
            local obbyFolder = Workspace:FindFirstChild("ObbyEventFolder")
            local activeObbyPart = nil
            
            if obbyFolder then
                local env = getrenv()._G.PathTool
                
                -- 1. Kiểm tra QAFolder (Chọn vòng tròn Q&A)
                local qaFolder = obbyFolder:FindFirstChild("QAFolder")
                if qaFolder and #qaFolder:GetChildren() > 0 then
                    local CfgQA = env and env.CfgQA
                    local activeKey = nil
                    local qText = "Đang diễn ra"
                    local choices = {}
                    
                    for _, part in ipairs(qaFolder:GetChildren()) do
                        local selectKey = part:GetAttribute("SelectKey")
                        local selectIdx = part:GetAttribute("SelectIdx")
                        if selectKey and selectIdx and CfgQA then
                            activeKey = selectKey
                            local qaData = CfgQA[selectKey]
                            qText = qaData and qaData.QText or qText
                            
                            if selectIdx > 0 then
                                local answer = qaData and qaData.Answers and qaData.Answers[selectIdx]
                                local ansText = answer and answer.AnswerText or ("Bục " .. tostring(selectIdx))
                                local ansCorrect = answer and (answer.Reward or (answer.RewardTips and string.find(string.lower(answer.RewardTips), "correct"))) ~= nil
                                
                                table.insert(choices, {
                                    idx = selectIdx,
                                    text = ansText,
                                    correct = ansCorrect,
                                    part = part
                                })
                                
                                if ansCorrect then
                                    activeObbyPart = part
                                end
                            end
                        end
                    end
                    
                    -- Cập nhật Live HUD Q&A
                    if activeKey then
                        local lines = { "Câu hỏi: " .. tostring(qText) }
                        for _, ch in ipairs(choices) do
                            table.insert(lines, string.format("  • Bục %d: %s%s", ch.idx, ch.text, ch.correct and " [ĐÚNG]" or ""))
                        end
                        if activeObbyPart then
                            table.insert(lines, "Đang đứng yên ở: Bục " .. tostring(activeObbyPart:GetAttribute("SelectIdx")) .. " (Chính xác!)")
                        end
                        LiveHud:Set({
                            Title = "📡 SỰ KIỆN ĐỐ VUI (Q&A) LIVE",
                            Content = table.concat(lines, "\n")
                        })
                    end
                end
                
                -- 2. Nếu không tìm thấy trong QAFolder, kiểm tra NewSelectFolder (Chọn quà)
                if not activeObbyPart then
                    local newSelectFolder = obbyFolder:FindFirstChild("NewSelectFolder")
                    if newSelectFolder and #newSelectFolder:GetChildren() > 0 then
                        local CfgNewSelect = env and env.CfgNewSelect
                        local bestPart = nil
                        local highestScore = -1
                        local hudLines = {}
                        
                        for _, part in ipairs(newSelectFolder:GetChildren()) do
                            local selectType = part:GetAttribute("SelectType")
                            local score, rewards = getNewSelectPartScore(part, CfgNewSelect)
                            local labelName = (tostring(selectType) == "1" and "Bục Trái (1)" or "Bục Phải (2)")
                            
                            if rewards then
                                table.insert(hudLines, string.format("  • %s: %s (Điểm: %.2f)", labelName, formatReward(rewards), score))
                            end
                            
                            if eventSettings.priorityMode == "Smart Scoring" then
                                if score > highestScore then
                                    highestScore = score
                                    bestPart = part
                                end
                            end
                        end
                        
                        -- Nếu ở chế độ Follow Crowd hoặc điểm bằng nhau
                        if eventSettings.priorityMode == "Follow Crowd" or highestScore <= 0 or not bestPart then
                            local maxVotes = -1
                            for _, part in ipairs(newSelectFolder:GetChildren()) do
                                local voteCount = part:GetAttribute("VoteCount") or 0
                                local selectType = part:GetAttribute("SelectType")
                                local labelName = (tostring(selectType) == "1" and "Bục Trái" or "Bục Phải")
                                table.insert(hudLines, string.format("  • %s: Số người đứng = %d", labelName, voteCount))
                                if voteCount > maxVotes then
                                    maxVotes = voteCount
                                    bestPart = part
                                end
                            end
                            table.insert(hudLines, "Đang chọn theo: Số đông người đứng")
                        else
                            table.insert(hudLines, "Đang chọn theo: Trọng số chấm điểm tự động")
                        end
                        
                        activeObbyPart = bestPart
                        
                        if activeObbyPart then
                            local chosenName = (tostring(activeObbyPart:GetAttribute("SelectType")) == "1" and "Bục Trái (1)" or "Bục Phải (2)")
                            table.insert(hudLines, "Đang đứng yên ở: " .. chosenName)
                        end
                        
                        LiveHud:Set({
                            Title = "📡 SỰ KIỆN CHỌN QUÀ LIVE",
                            Content = table.concat(hudLines, "\n")
                        })
                    end
                end
            end
            
            -- Nếu phát hiện ô lựa chọn chính xác đang hoạt động, dịch chuyển đến đó và đứng yên
            if activeObbyPart then
                EventStatus:Set(Utils.t("event_status_standing"))
                hrp.CFrame = CFrame.new(activeObbyPart.Position + Vector3.new(0, 3.5, 0))
                task.wait(0.5) -- Chờ chu kỳ quét tiếp theo (để đứng yên trên bục)
                continue
            end
            
            -- Reset Live HUD nếu không có sự kiện đố vui/lựa chọn diễn ra
            if not obbyFolder or not (obbyFolder:FindFirstChild("QAFolder") or obbyFolder:FindFirstChild("NewSelectFolder")) then
                LiveHud:Set({ Title = "📡 Đang chờ sự kiện bắt đầu...", Content = "" })
            end
            
            -- ƯU TIÊN 2: QUÉT THU THẬP VẬT PHẨM SỰ KIỆN RƠI TỰ DO (CHESTS/EGGS)
            local items = getEventClaimables()
            
            -- Tự động dọn dẹp cache của các vật phẩm không còn tồn tại
            local activeKeys = {}
            for _, it in ipairs(items) do
                activeKeys[it.object:GetFullName() .. "_" .. tostring(it.pos)] = true
            end
            for k, _ in pairs(claimedCache) do
                if not activeKeys[k] then
                    claimedCache[k] = nil
                end
            end

            if #items > 0 then
                EventStatus:Set(Utils.t("event_status_farming"))
                
                -- Sắp xếp tìm cái gần nhất
                table.sort(items, function(a, b)
                    return (hrp.Position - a.pos).Magnitude < (hrp.Position - b.pos).Magnitude
                end)
                
                local target = items[1]
                local cacheKey = target.object:GetFullName() .. "_" .. tostring(target.pos)
                
                if not claimedCache[cacheKey] then
                    print("[EventAuto] Teleporting to claim: " .. target.object.Name .. " at " .. tostring(target.pos))
                    
                    -- Dịch chuyển nhân vật đến vật thể (độ cao cách 3 studs)
                    hrp.CFrame = CFrame.new(target.pos + Vector3.new(0, 3, 0))
                    task.wait(0.3) -- Chờ game stream/load vị trí vật lý
                    
                    local env = getrenv()._G.PathTool
                    
                    -- Thực hiện claim tùy theo loại
                    if target.type == "SpaceReward" then
                        pcall(function()
                            local oldId = get_thread_id()
                            set_thread_id(2)
                            if env and env.SpaceRewardSystem and env.SpaceRewardSystem.ClientClaimFinnalReward then
                                env.SpaceRewardSystem.ClientClaimFinnalReward(target.obbyId, target.rewardIndex)
                            end
                            set_thread_id(oldId)
                        end)
                    elseif target.type == "Robbery" then
                        pcall(function()
                            local oldId = get_thread_id()
                            set_thread_id(2)
                            if env and env.SpaceRewardSystem and env.SpaceRewardSystem.ClientRobberyClaimReward then
                                env.SpaceRewardSystem.ClientRobberyClaimReward({
                                    Index = target.index,
                                    EventKey = target.eventKey
                                })
                            end
                            set_thread_id(oldId)
                        end)
                    else
                        -- Rương hoặc Trứng bình thường có ProximityPrompt
                        local prompt = target.object:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if prompt then
                            if fireproximityprompt then
                                fireproximityprompt(prompt)
                            else
                                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                                task.wait(0.02)
                                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                            end
                        else
                            -- Fallback spam E
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            task.wait(0.02)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        end
                    end
                    
                    claimedCache[cacheKey] = true
                    task.wait(0.5) -- Tránh spam mạng
                end
            else
                EventStatus:Set(Utils.t("event_status_idle"))
            end
        end
    end)

    -- X-Ray Thread for Choice/Gift Event Rewards Preview (Hiển thị 3D Billboard xem trước quà ẩn)
    task.spawn(function()
        while task.wait(1) do
            if eventSettings.xrayEnabled then
                pcall(function()
                    local obbyFolder = Workspace:FindFirstChild("ObbyEventFolder")
                    local newSelectFolder = obbyFolder and obbyFolder:FindFirstChild("NewSelectFolder")
                    local env = getrenv()._G.PathTool
                    local CfgNewSelect = env and env.CfgNewSelect
                    
                    if newSelectFolder and CfgNewSelect then
                        for _, part in ipairs(newSelectFolder:GetChildren()) do
                            local selectKey = part:GetAttribute("SelectKey")
                            local selectType = part:GetAttribute("SelectType")
                            if selectKey and selectType then
                                local selectData = CfgNewSelect[selectKey]
                                local selectInfo = selectData and selectData.SelectInfo and selectData.SelectInfo[tostring(selectType)]
                                if selectInfo and selectInfo.Reward then
                                    local rewardStr = formatReward(selectInfo.Reward)
                                    
                                    local bbg = part:FindFirstChild("EventXrayBillboard")
                                    if not bbg then
                                        bbg = Instance.new("BillboardGui")
                                        bbg.Name = "EventXrayBillboard"
                                        bbg.Size = UDim2.new(0, 200, 0, 50)
                                        bbg.StudsOffset = Vector3.new(0, 4, 0)
                                        bbg.AlwaysOnTop = true
                                        
                                        local tl = Instance.new("TextLabel")
                                        tl.Size = UDim2.new(1, 0, 1, 0)
                                        tl.BackgroundTransparency = 0.5
                                        tl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                                        tl.TextColor3 = Color3.fromRGB(0, 255, 127)
                                        tl.TextSize = 14
                                        tl.Font = Enum.Font.SourceSansBold
                                        tl.TextWrapped = true
                                        tl.Parent = bbg
                                        
                                        bbg.Parent = part
                                    end
                                    if bbg:FindFirstChild("TextLabel") then
                                        bbg.TextLabel.Text = rewardStr
                                    end
                                end
                            end
                        end
                    else
                        for _, v in ipairs(Workspace:GetDescendants()) do
                            if v.Name == "EventXrayBillboard" then
                                v:Destroy()
                            end
                        end
                    end
                end)
            end
        end
    end)


end

end

-- ========================================== --
-- MAIN LOADER START                          --
-- ========================================== --
-- ====================================================================
-- MAIN SCRIPT: Khởi chạy R-Client Pro (BẢN CHỐNG CACHE GITHUB TUYỆT ĐỐI)
-- VERSION: 2.8 - DÙNG LATEST COMMIT SHA ĐỂ XUYÊN THỦNG FASTLY CDN
-- ====================================================================
local HttpService = game:GetService("HttpService")

-- [!] CẤU HÌNH SILENT LOAD & STEALTH MODE (HƯỚNG 2)
local devMode = false -- Bật true nếu muốn xem log gỡ lỗi ra F9 Console

local scriptEnv = setmetatable({}, { __index = getfenv() })
scriptEnv.print = function(...)
    if devMode then
        print(...)
    end
end
scriptEnv.warn = function(...)
    if devMode then
        warn(...)
    else
        local args = {...}
        local msg = tostring(args[1] or "")
        pcall(function()
            if Rayfield and Rayfield.Notify then
                Rayfield:Notify({
                    Title = "Thông Báo Hệ Thống",
                    Content = msg,
                    Duration = 5
                })
            end
        end)
    end
end

-- Gán môi trường cho main.txt
setfenv(1, scriptEnv)

-- [!] BIẾN QUẢN LÝ NHÁNH
local branch = "feature/refactor-auto-farm"

-- ==========================================
-- BƯỚC 1: LẤY MÃ COMMIT MỚI NHẤT (CACHE BYPASS)
-- ==========================================
local targetRef = branch -- Mặc định dùng tên nhánh
local commitUrl = "https://api.github.com/repos/chaocauminhlason/scripts-linh-tinh/commits/" .. branch .. "?t=" .. tostring(os.time())

local successApi, apiResult = pcall(function() return game:HttpGet(commitUrl) end)

if successApi then
    local successDecode, decoded = pcall(function() return HttpService:JSONDecode(apiResult) end)
    -- Nếu lấy thành công, đổi từ "main" sang "a1b2c3d..."
    if successDecode and decoded.sha then
        targetRef = decoded.sha 
        print("Bypassed Fastly Cache. Current Commit SHA: " .. string.sub(targetRef, 1, 7))
    end
else
    print("Không lấy được Commit SHA, chuyển về dùng nhánh mặc định.")
end

-- ==========================================
-- BƯỚC 2: KHỞI TẠO URL VÀ GIAO DIỆN
-- ==========================================
-- Gắn mã Commit vào URL thay vì tên nhánh
local repoUrl = "https://raw.githubusercontent.com/chaocauminhlason/scripts-linh-tinh/" .. targetRef .. "/R-client-pro/"

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
-- R-Client Pro Tool v2.8
local Window = Rayfield:CreateWindow({
    Name = "Have a good day!",
    LoadingTitle = "Đang tải hệ thống...",
    LoadingSubtitle = "Dev by Son",
    ConfigurationSaving = { Enabled = true, FileName = "AutoFarmConfig" },
    KeySystem = false,
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true 
})

-- ==========================================
-- BƯỚC 3: HÀM TẢI AN TOÀN (SAFE LOAD)
-- ==========================================

-- ==========================================
-- HÀM TẢI LOCAL IN-MEMORY (BYPASS HTTP)
-- ==========================================
local function SafeLoad(filePath)
    local moduleFunc = modules[filePath]
    if moduleFunc then
        -- Kế thừa môi trường hiện tại cho module con
        setfenv(moduleFunc, getfenv(1))
        local success, result = pcall(moduleFunc)
        if success then
            return result
        else
            warn("❌ Lỗi thực thi module " .. filePath .. ": " .. tostring(result))
        end
    else
        warn("⚠️ Không tìm thấy module trong Bundle: " .. filePath)
    end
    return nil
end

-- 1. Kéo các file Core
local Utils = SafeLoad('core/utilities.txt')
local Controller = SafeLoad('core/system_controller.txt')
local WebhookModule = SafeLoad('core/webhook.txt')
local Localization = SafeLoad('core/localization.txt')

if Utils and Localization then
    Utils.t = Localization.t
    Utils.getLang = Localization.getLang
end

-- 2. Kéo các Features
if Utils then


    local r = SafeLoad('features/farm.txt')
    if r then r(Window, Utils, Controller) end
    
    local b = SafeLoad('features/boss_hunt.txt')
    if b then b(Window, Utils) end
    
    local sm = SafeLoad('features/server_manager.txt')
    if sm then sm(Window, Utils) end
    
    local sg = SafeLoad('features/shops_and_guis.txt')
    if sg then sg(Window, Utils) end

    local d = SafeLoad('features/auto_dungeon.txt')
    if d then d(Window, Utils, WebhookModule) end
    
    local t = SafeLoad('features/tracker.txt')
    if t then t(Window, Utils) end

    local h = SafeLoad('features/hatch_egg.txt')
    if h then h(Window, Utils) end

    local rift = SafeLoad('features/auto_rift.txt')
    if rift then rift(Window, Utils) end
    
    local o = SafeLoad('features/optimization.txt')
    if o then o(Window, Utils) end

    local ev = SafeLoad('features/auto_event.txt')
    if ev then ev(Window, Utils) end

    local a = SafeLoad('features/ai_assistant.txt')
    if a then a(Window, Utils, WebhookModule) end
end

if WebhookModule and WebhookModule.InitTab then
    WebhookModule.InitTab(Window, Rayfield, Utils)
end

Rayfield:LoadConfiguration()
Rayfield:Notify({ Title = "Thành Công!", Content = "Tool đã nạp đầy đủ!", Duration = 5 })
