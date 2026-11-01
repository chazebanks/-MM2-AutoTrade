-- MM2 TEST T8.2.5 ACCEPTED-EMPTY DIAGNOSTICS (T8.2.4 behavior retained)
-- Includes all proven modules through T5.12.
-- T6 scope only:
--   * detect opened trade
--   * identify partner
--   * read YOUR OFFER / THEIR OFFER live names
--   * scan our eligible inventory
--   * choose exactly one highest-valued eligible item
--   * OfferItem:FireServer(itemId, "Weapons")
--   * verify that exact item appears in YOUR OFFER
--   * STOP; never press Accept
--
-- Proven modules combined without changing their internal behavior:
--   1) T3.6 bot-server gate
--   2) T1 Tablet selection
--   3) T2 optional "Joining a friend?" -> Play
--   4) T4.4 live draggable/minimizable whitelist-blacklist scanner
--
-- No trade requests, balancing, webhook, or server hopping in this build.
-- Goal: verify all currently proven modules work together in one execution.

-- MM2 STARTUP SAFETY COMBINED TEST T1 + T2 + T3.6 FAST FRIEND SKIP
-- Proven modules:
--   T1   = select Tablet on MM2 device picker
--   T2   = optional "Joining a friend?" -> press Play, never Join
--   T3.6 = bot-server detector validated on known bot and normal servers
--
-- This combined test DOES NOT scan trade inventories, trade, webhook, or server-hop.
-- It only proves the startup path and bot-safety gate work together.

print("[MM2 T8.2.4] BOOT - immediate accepted-empty decline")
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

print("[MM2 Startup T1+T2] START")

local function visible(o)
    if not o then return false end

    local ok, result = pcall(function()
        local c = o
        while c do
            if c:IsA("ScreenGui") and not c.Enabled then
                return false
            end
            if c:IsA("GuiObject") and not c.Visible then
                return false
            end
            c = c.Parent
        end
        return true
    end)

    return ok and result
end

local function textOf(o, fallbackName)
    if not o then return "" end

    local s = ""
    if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
        pcall(function()
            s = tostring(o.Text or "")
        end)
    end

    if fallbackName and s == "" then
        s = tostring(o.Name or "")
    end

    return s:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function center(o)
    local ok, p, z = pcall(function()
        return o.AbsolutePosition, o.AbsoluteSize
    end)

    if not ok or not p or not z or z.X <= 1 or z.Y <= 1 then
        return nil
    end

    return p.X + z.X / 2, p.Y + z.Y / 2
end

local function roots()
    local out = {}

    local pg = LP and LP:FindFirstChildOfClass("PlayerGui")
    if pg then
        out[#out + 1] = pg
    end

    out[#out + 1] = CoreGui

    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then
            out[#out + 1] = h
        end
    end

    return out
end

local function pressButton(button)
    if not button or not visible(button) then
        return false
    end

    local attempted = false

    if firesignal then
        attempted = pcall(function()
            firesignal(button.Activated)
        end) or attempted

        pcall(function()
            firesignal(button.MouseButton1Click)
        end)
    end

    pcall(function()
        button:Activate()
        attempted = true
    end)

    local ok = pcall(function()
        local p = button.AbsolutePosition
        local z = button.AbsoluteSize
        local x = p.X + z.X / 2
        local y = p.Y + z.Y / 2

        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)

    return attempted or ok
end

-- ============================================================
-- T1: PROVEN TABLET PICKER
-- ============================================================

local function isPhone(t)
    return t == "phone"
        or t == "mobile"
        or t == "mobile phone"
end

local function isTablet(t)
    return t == "tablet"
        or t == "ipad"
        or t == "tablet / ipad"
        or t == "tablet/ipad"
end

local function descendantOf(o, scope)
    local c = o
    while c do
        if c == scope then return true end
        c = c.Parent
    end
    return false
end

local function nearestTabletButton(tabletNode, phoneNode, scope)
    -- Same direct-ancestor preference used by the successful T1 test.
    local c = tabletNode
    for _ = 1, 6 do
        if not c then break end
        if c:IsA("TextButton") or c:IsA("ImageButton") then
            return c
        end
        if c == scope then break end
        c = c.Parent
    end

    -- Same physical-nearest fallback used by the successful T1 test.
    local tx, ty = center(tabletNode)
    local px, py = center(phoneNode)
    if not tx or not px then return nil end

    local best, bestDist
    local ok, list = pcall(function()
        return scope:GetDescendants()
    end)
    if not ok then return nil end

    for _, d in ipairs(list) do
        if visible(d) and (d:IsA("TextButton") or d:IsA("ImageButton")) then
            local bx, by = center(d)
            if bx then
                local dt = (bx - tx)^2 + (by - ty)^2
                local dp = (bx - px)^2 + (by - py)^2

                if dt <= dp and (not bestDist or dt < bestDist) then
                    best = d
                    bestDist = dt
                end
            end
        end
    end

    return best
end

local function findTabletPicker()
    for _, root in ipairs(roots()) do
        local ok, list = pcall(function()
            return root:GetDescendants()
        end)

        if ok then
            local tablets = {}
            local phones = {}

            for _, d in ipairs(list) do
                if visible(d) then
                    local t = textOf(d, true)
                    if isTablet(t) then
                        tablets[#tablets + 1] = d
                    end
                    if isPhone(t) then
                        phones[#phones + 1] = d
                    end
                end
            end

            for _, tabletNode in ipairs(tablets) do
                local scope = tabletNode.Parent

                for _ = 1, 7 do
                    if not scope then break end

                    local phoneNode
                    for _, pnode in ipairs(phones) do
                        if descendantOf(pnode, scope) then
                            phoneNode = pnode
                            break
                        end
                    end

                    if phoneNode then
                        local button = nearestTabletButton(tabletNode, phoneNode, scope)
                        if button then
                            return {
                                button = button,
                                scope = scope,
                            }
                        end
                    end

                    if scope:IsA("ScreenGui") then break end
                    scope = scope.Parent
                end
            end
        end
    end

    return nil
end

local function runTabletStage()
    print("[MM2 Startup T1+T2] T1 waiting for Phone/Tablet picker...")

    local deadline = os.clock() + 25
    local attempts = 0
    local sawPicker = false

    while os.clock() < deadline do
        local picker = findTabletPicker()

        if picker then
            sawPicker = true
            attempts = attempts + 1

            local x, y = center(picker.button)
            print(
                "[MM2 Startup T1+T2] T1 picker found | attempt",
                attempts,
                "| button",
                picker.button:GetFullName(),
                "| center",
                tostring(math.floor(x or -1)),
                tostring(math.floor(y or -1))
            )

            local sent = pressButton(picker.button)
            print("[MM2 Startup T1+T2] T1 Tablet click sent:", sent)

            task.wait(0.6)

            if not findTabletPicker() then
                print("[MM2 Startup T1+T2] T1 SUCCESS - Tablet picker dismissed")
                return true
            end

            warn("[MM2 Startup T1+T2] T1 picker still visible after click")

            if attempts >= 4 then
                warn("[MM2 Startup T1+T2] T1 FAILED - picker remained after 4 attempts")
                return false
            end

            task.wait(0.5)
        else
            task.wait(0.15)
        end
    end

    if not sawPicker then
        warn("[MM2 Startup T1+T2] T1 SKIP - device picker did not appear; continuing")
        return true
    end

    warn("[MM2 Startup T1+T2] T1 FAILED - device picker did not dismiss")
    return false
end

-- ============================================================
-- T2: PROVEN OPTIONAL FRIEND-PLAY BYPASS
-- ============================================================

local function ancestorButton(o, maxDepth)
    local c = o
    for _ = 1, maxDepth or 7 do
        if not c then break end
        if c:IsA("TextButton") or c:IsA("ImageButton") then
            return c
        end
        c = c.Parent
    end
    return nil
end

local function scopeLooksLikeFriendPrompt(scope)
    if not scope then return false end

    local ok, list = pcall(function()
        return scope:GetDescendants()
    end)
    if not ok then return false end

    local hasHeading = false
    local hasJoin = false
    local hasPlay = false

    for _, d in ipairs(list) do
        if visible(d) then
            local t = textOf(d, false)

            if t == "joining a friend?"
                or t:find("joining a friend", 1, true)
            then
                hasHeading = true
            end

            if t == "join" then
                hasJoin = true
            end

            if t == "play" or t == "play anyway" then
                hasPlay = true
            end
        end
    end

    return hasHeading and hasJoin and hasPlay
end

local function findFriendPlayButton()
    for _, root in ipairs(roots()) do
        local ok, list = pcall(function()
            return root:GetDescendants()
        end)

        if ok then
            for _, d in ipairs(list) do
                if visible(d) then
                    local t = textOf(d, false)

                    if t == "play" or t == "play anyway" then
                        local button = ancestorButton(d, 7)

                        if button and visible(button) then
                            local scope = button.Parent

                            for _ = 1, 8 do
                                if not scope then break end

                                if (scope:IsA("Frame")
                                    or scope:IsA("CanvasGroup")
                                    or scope:IsA("ScrollingFrame"))
                                    and scopeLooksLikeFriendPrompt(scope)
                                then
                                    return {
                                        button = button,
                                        scope = scope,
                                    }
                                end

                                if scope:IsA("ScreenGui") then break end
                                scope = scope.Parent
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function pressFriendPlay(button)
    if not button or not visible(button) then
        return false
    end

    -- Absolute safety rule from T2: never click the small Join button.
    if textOf(button, false) == "join" then
        warn("[MM2 Startup T1+T2] T2 SAFETY BLOCK - candidate was Join")
        return false
    end

    return pressButton(button)
end

local function runFriendStage()
    print("[MM2 Startup T1+T2] T2 checking briefly for optional 'Joining a friend?' prompt...")

    local deadline = os.clock() + 3
    local attempts = 0
    local sawPrompt = false

    while os.clock() < deadline do
        local found = findFriendPlayButton()

        if found then
            sawPrompt = true
            attempts = attempts + 1

            local x, y = center(found.button)
            print(
                "[MM2 Startup T1+T2] T2 friend prompt found | attempt",
                attempts,
                "| PLAY button",
                found.button:GetFullName(),
                "| center",
                tostring(math.floor(x or -1)),
                tostring(math.floor(y or -1))
            )

            local sent = pressFriendPlay(found.button)
            print("[MM2 Startup T1+T2] T2 Play click sent:", sent)

            task.wait(0.7)

            if not findFriendPlayButton() then
                print("[MM2 Startup T1+T2] T2 SUCCESS - friend prompt dismissed with Play")
                return true
            end

            warn("[MM2 Startup T1+T2] T2 prompt still visible after Play click")

            if attempts >= 4 then
                warn("[MM2 Startup T1+T2] T2 FAILED - friend prompt remained after 4 attempts")
                return false
            end

            task.wait(0.5)
        else
            task.wait(0.12)
        end
    end

    if not sawPrompt then
        print("[MM2 Startup T1+T2] T2 SKIP - no friend prompt within 3s (normal); continuing")
        return true
    end

    warn("[MM2 Startup T1+T2] T2 FAILED - friend prompt did not dismiss")
    return false
end

-- ============================================================
-- T3.6 PROVEN BOT-SERVER DETECTOR — RUNS FIRST
-- ============================================================
local function runBotGate()
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer

    local C = {
        BotWaitForLobby = 6,
        BotConfirmDelay = 2.5,
        BotMinPlayers = 6,
        BotThreshold = 60,

        BotStrongClusterRatio = 0.55,
        BotStrongClusterMin = 5,
        BotMediumClusterRatio = 0.45,
        BotMediumClusterMin = 4,

        BotNewAccountDays = 30,
        BotVeryNewDays = 7,

        -- New diversified-farm rule.
        DiversifiedMinPlayers = 8,

        -- Strong diversified rule.
        DiversifiedSimpleRatio = 0.80,  -- >=80% avatars have <=1 accessory
        DiversifiedTrait1Ratio = 0.70,  -- >=70% usernames show >=1 generated trait
        DiversifiedTrait2Ratio = 0.40,  -- >=40% usernames show >=2 generated traits

        -- Medium diversified rule.
        DiversifiedMediumSimpleRatio = 0.70,
        DiversifiedMediumTrait1Ratio = 0.60,
        DiversifiedMediumTrait2Ratio = 0.30,

        -- Narrow rule added after a confirmed bot lobby scored only 45:
        -- 11/11 avatars had <=1 accessory, 9/11 names had >=1 generated trait,
        -- and 4/11 had >=2 generated traits.
        NearUniformMinPlayers = 9,
        NearUniformSimpleRatio = 0.90,
        NearUniformTrait1Ratio = 0.80,
        NearUniformTrait2Ratio = 0.30,

        -- Confirmed missed-bot pattern:
        -- usernames can be overwhelmingly generated even when avatars are diversified.
        NameMajorityMinPlayers = 9,
        NameMajorityTrait1Ratio = 0.90,
        NameMajorityTrait2Ratio = 0.55,

        -- Confirmed missed-bot pattern:
        -- 9/11 avatars had <=1 accessory and 10/11 names had >=1 generated trait,
        -- while only 1/11 had >=2 traits.
        BroadSimpleNameMinPlayers = 9,
        BroadSimpleRatio = 0.80,
        BroadTrait1Ratio = 0.90,

        -- Confirmed missed-bot pattern:
        -- 11/11 usernames had >=1 generated trait and 8/11 avatars were simple.
        -- This rule requires an almost unanimous weak-name signal so the simple-avatar
        -- threshold can safely be lower.
        NearUnanimousNameMinPlayers = 9,
        NearUnanimousTrait1Ratio = 0.95,
        NearUnanimousSimpleRatio = 0.70,
    }

    local DESC_FIELDS = {
        "Shirt","Pants","GraphicTShirt","Face","Head","Torso",
        "LeftArm","RightArm","LeftLeg","RightLeg",
        "HatAccessory","HairAccessory","FaceAccessory","NeckAccessory",
        "ShouldersAccessory","ShoulderAccessory","FrontAccessory",
        "BackAccessory","WaistAccessory"
    }

    local ACCESSORY_FIELDS = {
        "HatAccessory",
        "HairAccessory",
        "FaceAccessory",
        "NeckAccessory",
        "ShouldersAccessory",
        "ShoulderAccessory",
        "FrontAccessory",
        "BackAccessory",
        "WaistAccessory",
    }

    local function splitCount(v)
        local s = tostring(v or "")
        if s == "" or s == "0" then
            return 0
        end

        local n = 0
        for token in s:gmatch("[^,]+") do
            token = token:gsub("%s+","")
            if token ~= "" and token ~= "0" then
                n += 1
            end
        end
        return n
    end

    local function avatarData(plr)
        local char = plr and plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then
            return nil
        end

        local okDesc, desc = pcall(function()
            return hum:GetAppliedDescription()
        end)

        if not okDesc or not desc then
            return nil
        end

        local parts = {}
        for _, field in ipairs(DESC_FIELDS) do
            local okField, val = pcall(function()
                return desc[field]
            end)
            if okField then
                parts[#parts+1] = field.."="..tostring(val or "")
            end
        end

        for _, field in ipairs({
            "BodyTypeScale","DepthScale","HeadScale",
            "HeightScale","ProportionScale","WidthScale"
        }) do
            local okField, val = pcall(function()
                return desc[field]
            end)
            if okField then
                parts[#parts+1] =
                    field.."="..string.format("%.2f", tonumber(val) or 0)
            end
        end

        local accessoryCount = 0
        for _, field in ipairs(ACCESSORY_FIELDS) do
            local okField, val = pcall(function()
                return desc[field]
            end)
            if okField then
                accessoryCount += splitCount(val)
            end
        end

        return {
            fingerprint = table.concat(parts, "|"),
            accessories = accessoryCount,
        }
    end

    local function alphaPrefix(name)
        name = tostring(name or ""):lower():gsub("[^a-z0-9]", "")
        local p = name:match("^([a-z]+)")
        if not p or #p < 5 then
            return ""
        end
        return p:sub(1, 5)
    end

    local function generatedTraits(name)
        local raw = tostring(name or "")
        local compact = raw:gsub("[^%w]", "")
        local lower = compact:lower()
        local traits = 0

        local suffix = compact:match("(%d+)$")
        if suffix and #suffix >= 4 then
            traits += 1
        end

        local letters = compact:gsub("[^A-Za-z]", "")
        local transitions = 0

        for i = 2, #letters do
            local a = letters:sub(i-1, i-1)
            local b = letters:sub(i, i)

            if (a:match("%l") and b:match("%u"))
                or (a:match("%u") and b:match("%l"))
            then
                transitions += 1
            end
        end

        if transitions >= 3 then
            traits += 1
        end

        if lower:find("qwe",1,true)
            or lower:find("asd",1,true)
            or lower:find("zxc",1,true)
        then
            traits += 1
        end

        if #compact >= 17 then
            traits += 1
        end

        local body =
            suffix and compact:sub(1, #compact - #suffix)
            or compact

        if body:find("%d") then
            traits += 1
        end

        local _, vowels =
            letters:lower():gsub("[aeiou]", "")

        if #letters >= 10
            and vowels / math.max(1, #letters) < 0.18
        then
            traits += 1
        end

        return traits
    end

    local function scan()
        local others = {}

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                others[#others+1] = p
            end
        end

        local total = #others

        local fingerprints = {}
        local prefixes = {}

        local loaded = 0
        local new30 = 0
        local new7 = 0

        local generated1 = 0
        local generated2 = 0

        local simple1 = 0
        local simple2 = 0

        local generatedNames = {}

        for _, p in ipairs(others) do
            local av = avatarData(p)

            if av then
                loaded += 1

                fingerprints[av.fingerprint] =
                    fingerprints[av.fingerprint] or {}

                table.insert(
                    fingerprints[av.fingerprint],
                    p
                )

                if av.accessories <= 1 then
                    simple1 += 1
                end

                if av.accessories <= 2 then
                    simple2 += 1
                end
            end

            local age = tonumber(p.AccountAge) or 999999

            if age <= C.BotNewAccountDays then
                new30 += 1
            end

            if age <= C.BotVeryNewDays then
                new7 += 1
            end

            local prefix = alphaPrefix(p.Name)

            if prefix ~= "" then
                prefixes[prefix] =
                    prefixes[prefix] or {}

                table.insert(prefixes[prefix], p)
            end

            local traits = generatedTraits(p.Name)

            if traits >= 1 then
                generated1 += 1
            end

            if traits >= 2 then
                generated2 += 1
                generatedNames[#generatedNames+1] = p
            end
        end

        local largest = {}
        local unique = 0
        local repeatedGroups = 0
        local repeatedMembers = 0

        for _, group in pairs(fingerprints) do
            unique += 1

            if #group > #largest then
                largest = group
            end

            if #group >= 2 then
                repeatedGroups += 1
                repeatedMembers += #group
            end
        end

        local prefixLargest = {}

        for _, group in pairs(prefixes) do
            if #group > #prefixLargest then
                prefixLargest = group
            end
        end

        local loadedDen = math.max(1, loaded)
        local totalDen = math.max(1, total)

        local cluster = #largest
        local clusterRatio = cluster / loadedDen
        local new30Ratio = new30 / totalDen
        local new7Ratio = new7 / totalDen
        local prefixRatio = #prefixLargest / totalDen

        local trait1Ratio = generated1 / totalDen
        local trait2Ratio = generated2 / totalDen
        local simple1Ratio = simple1 / loadedDen
        local simple2Ratio = simple2 / loadedDen

        local repeatedRatio = repeatedMembers / loadedDen

        local minPlayers = math.max(2, C.BotMinPlayers)
        local score = 0
        local reasons = {}

        -- Proven old exact-avatar rules.
        if loaded >= minPlayers
            and cluster >= C.BotStrongClusterMin
            and clusterRatio >= C.BotStrongClusterRatio
        then
            score += 70
            reasons[#reasons+1] =
                ("identical avatar cluster %d/%d (%.0f%%)"):format(
                    cluster,
                    loaded,
                    clusterRatio * 100
                )

        elseif loaded >= minPlayers
            and cluster >= C.BotMediumClusterMin
            and clusterRatio >= C.BotMediumClusterRatio
        then
            score += cluster >= 5 and 60 or 45
            reasons[#reasons+1] =
                ("large avatar cluster %d/%d (%.0f%%)"):format(
                    cluster,
                    loaded,
                    clusterRatio * 100
                )
        end

        if loaded >= minPlayers
            and loaded >= math.floor(total * 0.70)
        then
            local diversity = unique / loadedDen

            if diversity <= 0.30 then
                score += 25
                reasons[#reasons+1] =
                    ("low avatar diversity %d unique/%d loaded"):format(
                        unique,
                        loaded
                    )

            elseif diversity <= 0.45 then
                score += 12
                reasons[#reasons+1] =
                    ("reduced avatar diversity %d/%d"):format(
                        unique,
                        loaded
                    )
            end
        end

        if loaded >= math.max(minPlayers, 8)
            and repeatedGroups >= 2
            and repeatedMembers >= 6
            and repeatedRatio >= 0.55
        then
            score += 60
            reasons[#reasons+1] =
                ("multiple repeated avatar groups %d/%d across %d groups"):format(
                    repeatedMembers,
                    loaded,
                    repeatedGroups
                )

        elseif loaded >= minPlayers
            and repeatedGroups >= 2
            and repeatedMembers >= 5
            and repeatedRatio >= 0.45
        then
            score += 25
            reasons[#reasons+1] =
                ("possible repeated avatar groups %d/%d across %d groups"):format(
                    repeatedMembers,
                    loaded,
                    repeatedGroups
                )
        end

        if total >= minPlayers
            and new7Ratio >= 0.45
        then
            score += 25
            reasons[#reasons+1] =
                ("%.0f%% accounts <=%d days old"):format(
                    new7Ratio * 100,
                    C.BotVeryNewDays
                )

        elseif total >= minPlayers
            and new30Ratio >= 0.60
        then
            score += 18
            reasons[#reasons+1] =
                ("%.0f%% accounts <=%d days old"):format(
                    new30Ratio * 100,
                    C.BotNewAccountDays
                )
        end

        if total >= minPlayers
            and #prefixLargest >= 4
            and prefixRatio >= 0.40
        then
            score += 12
            reasons[#reasons+1] =
                ("username-prefix cluster %d/%d"):format(
                    #prefixLargest,
                    total
                )
        end

        -- Near-unanimous weak-name + simple-avatar rule.
        -- Added after a confirmed bot lobby showed 11/11 usernames with >=1
        -- generated trait and 8/11 avatars with <=1 accessory.
        if total >= C.NearUnanimousNameMinPlayers
            and loaded >= math.floor(total * 0.80)
            and trait1Ratio >= C.NearUnanimousTrait1Ratio
            and simple1Ratio >= C.NearUnanimousSimpleRatio
        then
            score += 70

            reasons[#reasons+1] =
                ("near-unanimous generated-name/simple-avatar farm: trait1 %.0f%% | simple avatars %.0f%%"):format(
                    trait1Ratio * 100,
                    simple1Ratio * 100
                )
        end

        -- Broad simple-avatar + weak-name-majority rule.
        -- Added after a confirmed bot lobby showed 9/11 simple avatars,
        -- 10/11 usernames with >=1 generated trait, but only 1/11 with >=2.
        if total >= C.BroadSimpleNameMinPlayers
            and loaded >= math.floor(total * 0.80)
            and simple1Ratio >= C.BroadSimpleRatio
            and trait1Ratio >= C.BroadTrait1Ratio
        then
            score += 70

            reasons[#reasons+1] =
                ("broad simple-avatar/name bot farm: simple avatars %.0f%% | generated-name trait1 %.0f%%"):format(
                    simple1Ratio * 100,
                    trait1Ratio * 100
                )
        end

        -- Strong generated-name-majority rule.
        -- Added after a confirmed bot lobby showed:
        -- 11/11 names with >=1 generated-name trait and 7/11 with >=2,
        -- while avatar repetition/simple-avatar ratios were not strong enough.
        if total >= C.NameMajorityMinPlayers
            and trait1Ratio >= C.NameMajorityTrait1Ratio
            and trait2Ratio >= C.NameMajorityTrait2Ratio
        then
            score += 70

            reasons[#reasons+1] =
                ("generated-name majority bot farm: trait1 %.0f%% | trait2 %.0f%%"):format(
                    trait1Ratio * 100,
                    trait2Ratio * 100
                )
        end

        -- Narrow diversified-farm override:
        -- catches lobbies where almost every avatar is extremely simple AND
        -- most usernames look generated, even if exact avatar duplication is low.
        if total >= C.NearUniformMinPlayers
            and loaded >= math.floor(total * 0.80)
            and simple1Ratio >= C.NearUniformSimpleRatio
            and trait1Ratio >= C.NearUniformTrait1Ratio
            and trait2Ratio >= C.NearUniformTrait2Ratio
        then
            score += 70

            reasons[#reasons+1] =
                ("near-uniform simple-avatar bot farm: simple avatars %.0f%% | generated-name trait1 %.0f%% | trait2 %.0f%%"):format(
                    simple1Ratio * 100,
                    trait1Ratio * 100,
                    trait2Ratio * 100
                )
        end

        -- New diversified-farm rule.
        if not (
            total >= C.NearUniformMinPlayers
            and loaded >= math.floor(total * 0.80)
            and simple1Ratio >= C.NearUniformSimpleRatio
            and trait1Ratio >= C.NearUniformTrait1Ratio
            and trait2Ratio >= C.NearUniformTrait2Ratio
        )
            and total >= C.DiversifiedMinPlayers
            and loaded >= math.floor(total * 0.80)
            and simple1Ratio >= C.DiversifiedSimpleRatio
            and trait1Ratio >= C.DiversifiedTrait1Ratio
            and trait2Ratio >= C.DiversifiedTrait2Ratio
        then
            score += 80

            reasons[#reasons+1] =
                ("diversified bot farm: simple avatars %.0f%% | generated-name trait1 %.0f%% | trait2 %.0f%%"):format(
                    simple1Ratio * 100,
                    trait1Ratio * 100,
                    trait2Ratio * 100
                )

        elseif total >= C.DiversifiedMinPlayers
            and loaded >= math.floor(total * 0.70)
            and simple1Ratio >= C.DiversifiedMediumSimpleRatio
            and trait1Ratio >= C.DiversifiedMediumTrait1Ratio
            and trait2Ratio >= C.DiversifiedMediumTrait2Ratio
        then
            score += 45

            reasons[#reasons+1] =
                ("possible diversified farm: simple avatars %.0f%% | trait1 %.0f%% | trait2 %.0f%%"):format(
                    simple1Ratio * 100,
                    trait1Ratio * 100,
                    trait2Ratio * 100
                )
        end

        local names = {}

        local reportGroup =
            (#generatedNames >= 5)
            and generatedNames
            or largest

        for _, p in ipairs(reportGroup) do
            names[#names+1] =
                p.Name.."("..tostring(p.AccountAge).."d)"
        end

        return {
            total = total,
            loaded = loaded,

            score = score,
            bot =
                total >= minPlayers
                and score >= C.BotThreshold,

            reasons =
                #reasons > 0
                and table.concat(reasons, " | ")
                or "no strong bot pattern",

            clusterNames = names,

            cluster = cluster,
            simple1 = simple1,
            simple2 = simple2,
            simple1Ratio = simple1Ratio,
            simple2Ratio = simple2Ratio,

            trait1 = generated1,
            trait2 = generated2,
            trait1Ratio = trait1Ratio,
            trait2Ratio = trait2Ratio,

            repeatedMembers = repeatedMembers,
        }
    end

    local function printScan(label, r)
        print(
            "[MM2 Bot Test T3.6]",
            label,
            "| score", r.score,
            "| players", r.total,
            "| avatars", r.loaded,
            "| largest cluster", r.cluster,
            "| accessories<=1", r.simple1.."/"..r.loaded,
            "| trait>=1", r.trait1.."/"..r.total,
            "| trait>=2", r.trait2.."/"..r.total,
            "| repeated", r.repeatedMembers,
            "|", r.reasons
        )

        if #r.clusterNames > 0 then
            print(
                "[MM2 Bot Test T3.6]",
                label,
                "| flagged group:",
                table.concat(r.clusterNames, ", ")
            )
        end
    end

    print("[MM2 Bot Test T3.6] START")
    print(
        "[MM2 Bot Test T3.6] Waiting",
        C.BotWaitForLobby,
        "seconds for lobby/avatar data..."
    )

    task.wait(C.BotWaitForLobby)

    local first = scan()
    printScan("SCAN 1", first)

    if not first.bot then
        print(
            "[MM2 Bot Test T3.6] SUCCESS - SERVER APPROVED | score",
            first.score,
            "| below threshold",
            C.BotThreshold
        )
        return true
    end

    warn(
        "[MM2 Bot Test T3.6] SUSPICIOUS SERVER - confirming in",
        C.BotConfirmDelay,
        "seconds"
    )

    task.wait(C.BotConfirmDelay)

    local second = scan()
    printScan("SCAN 2", second)

    if second.bot then
        warn(
            "[MM2 Bot Test T3.6] BOT SERVER CONFIRMED | score",
            second.score,
            "|", second.reasons
        )

        if #second.clusterNames > 0 then
            warn(
                "[MM2 Bot Test T3.6] BOT GROUP:",
                table.concat(second.clusterNames, ", ")
            )
        end

        warn(
            "[MM2 Bot Test T3.6] BOT GATE BLOCKED - startup modules will NOT run"
        )
        return false
    else
        print(
            "[MM2 Bot Test T3.6] SUCCESS - SUSPICION CLEARED ON CONFIRMATION | score",
            second.score
        )
        return true
    end
end


-- ============================================================
-- COMBINED PROVEN STARTUP ORDER: BOT -> TABLET -> FRIEND PLAY
-- ============================================================

local botOK = runBotGate()
if not botOK then
    warn("[MM2 Startup Safety] STOPPED - bot server rejected before startup UI")
    return
end

print("[MM2 Startup Safety] BOT GATE PASSED - starting Tablet stage")

local tabletOK = runTabletStage()
if not tabletOK then
    warn("[MM2 Startup Safety] STOPPED - Tablet stage failed")
    return
end

local friendOK = runFriendStage()
if not friendOK then
    warn("[MM2 Startup Safety] STOPPED - Friend Play stage failed")
    return
end

print("[MM2 Startup Safety] SUCCESS - bot gate + Tablet + optional Friend Play complete")

-- ============================================================
-- INTEGRATION HANDOFF: STARTUP SAFETY -> LIVE ELIGIBILITY SCANNER
-- ============================================================

print("[MM2 Integration I1] STARTUP SAFETY COMPLETE - launching T4.4 scanner")
task.wait(0.35)

-- Purpose:
--   1) load the retained Ancient/Godly/Chroma Godly value + identity layer ONCE
--   2) scan every OTHER player in the current server
--   3) classify WHITELIST vs BLACKLIST
--   4) print every eligible item + value for whitelisted players
--
-- NO tablet/friend startup handling
-- NO bot detection
-- NO trade requests
-- NO trade UI
-- NO webhook
-- NO server hopping
--
-- Sunset / Chroma Sunset are intentionally ignored and contribute 0.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
if not LP then
    warn("[MM2 Scanner T4] LocalPlayer missing")
    return
end

local C = {
    TargetScanRetries = 3,
    TargetScanRetryDelay = 0.55,

    -- New-player profiles can take several seconds to become readable.
    JoinScanRetries = 12,
    JoinScanRetryDelay = 1.25,

    -- If a player is still unreadable after the join window, keep retrying
    -- in the background instead of leaving them permanently UNKNOWN.
    UnknownRetryDelay = 2.5,
    UnknownRetryMax = 12,
}

local State = {
    targetReader = nil,
    targetMode = nil,
    targetReaderCheckedAt = 0,
}

local function log(...)
    print("[MM2 Scanner T4]", ...)
end

local function norm(x)
    return tostring(x or ""):gsub("’","'"):lower():gsub("[^%w]","")
end

log("START")

-- ============================================================================
-- T4.1 ON-SCREEN TEST GUI
-- ============================================================================

local GUI = {
    screen = nil,
    frame = nil,
    titleBar = nil,
    status = nil,
    summary = nil,
    list = nil,
    layout = nil,
    minimize = nil,
    rows = {},
    minimized = false,
    fullSize = UDim2.fromOffset(470, 520),
    miniSize = UDim2.fromOffset(470, 105),
}

local function guiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then
            return h
        end
    end

    return LP:WaitForChild("PlayerGui")
end

local function destroyOldGui()
    local roots = {
        LP:FindFirstChildOfClass("PlayerGui"),
        CoreGui,
    }

    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then
            roots[#roots + 1] = h
        end
    end

    for _, root in ipairs(roots) do
        if root then
            local old = root:FindFirstChild("MM2EligibilityScannerT41")
            if old then
                pcall(function()
                    old:Destroy()
                end)
            end
        end
    end
end

local function makeText(parent, name, text, size, pos, fontSize)
    local x = Instance.new("TextLabel")
    x.Name = name
    x.Parent = parent
    x.BackgroundTransparency = 1
    x.BorderSizePixel = 0
    x.Size = size
    x.Position = pos or UDim2.new()
    x.Font = Enum.Font.Gotham
    x.TextSize = fontSize or 16
    x.TextColor3 = Color3.fromRGB(238, 241, 245)
    x.TextXAlignment = Enum.TextXAlignment.Left
    x.TextYAlignment = Enum.TextYAlignment.Center
    x.TextWrapped = true
    x.Text = text or ""
    return x
end

local function createGui()
    destroyOldGui()

    local screen = Instance.new("ScreenGui")
    screen.Name = "MM2EligibilityScannerT41"
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function()
        screen.IgnoreGuiInset = true
    end)
    screen.Parent = guiParent()

    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.Parent = screen
    frame.Size = GUI.fullSize
    frame.Position = UDim2.new(0, 14, 0.14, 0)
    frame.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.ClipsDescendants = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Transparency = 0.35
    stroke.Color = Color3.fromRGB(120, 126, 138)
    stroke.Parent = frame

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Parent = frame
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.Position = UDim2.fromOffset(0, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.BorderSizePixel = 0
    titleBar.Active = true

    local title = makeText(
        titleBar,
        "Title",
        "MM2 T4.4 Live Eligibility Scanner",
        UDim2.new(1, -74, 1, 0),
        UDim2.fromOffset(14, 0),
        18
    )
    title.Font = Enum.Font.GothamBold

    local minimize = Instance.new("TextButton")
    minimize.Name = "Minimize"
    minimize.Parent = titleBar
    minimize.Size = UDim2.fromOffset(42, 30)
    minimize.Position = UDim2.new(1, -52, 0, 5)
    minimize.BackgroundColor3 = Color3.fromRGB(45, 49, 58)
    minimize.BackgroundTransparency = 0.08
    minimize.BorderSizePixel = 0
    minimize.Font = Enum.Font.GothamBold
    minimize.TextSize = 18
    minimize.TextColor3 = Color3.fromRGB(238, 241, 245)
    minimize.Text = "—"

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 8)
    minCorner.Parent = minimize

    local status = makeText(
        frame,
        "Status",
        "Starting scanner...",
        UDim2.new(1, -28, 0, 42),
        UDim2.fromOffset(14, 42),
        14
    )
    status.TextColor3 = Color3.fromRGB(188, 199, 216)

    local summary = makeText(
        frame,
        "Summary",
        "Whitelist 0  |  Blacklist 0  |  Unknown 0",
        UDim2.new(1, -28, 0, 28),
        UDim2.fromOffset(14, 84),
        14
    )
    summary.Font = Enum.Font.GothamSemibold

    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Parent = frame
    divider.BorderSizePixel = 0
    divider.BackgroundColor3 = Color3.fromRGB(76, 82, 94)
    divider.BackgroundTransparency = 0.25
    divider.Size = UDim2.new(1, -28, 0, 1)
    divider.Position = UDim2.fromOffset(14, 116)

    local list = Instance.new("ScrollingFrame")
    list.Name = "PlayerList"
    list.Parent = frame
    list.Position = UDim2.fromOffset(12, 126)
    list.Size = UDim2.new(1, -24, 1, -138)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.ScrollingDirection = Enum.ScrollingDirection.Y
    pcall(function()
        list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    end)

    local padding = Instance.new("UIPadding")
    padding.Parent = list
    padding.PaddingBottom = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.PaddingRight = UDim.new(0, 2)
    padding.PaddingTop = UDim.new(0, 2)

    local layout = Instance.new("UIListLayout")
    layout.Parent = list
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        list.CanvasSize = UDim2.fromOffset(
            0,
            layout.AbsoluteContentSize.Y + 12
        )
    end)

    -- Dragging: touch or mouse from the title bar.
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function updateDrag(input)
        if not dragging or not dragStart or not startPos then
            return
        end

        local delta = input.Position - dragStart

        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == dragInput then
            updateDrag(input)
        end
    end)

    local function applyMinimized()
        if GUI.minimized then
            frame.Size = GUI.miniSize
            list.Visible = false
            divider.Visible = false
            summary.Position = UDim2.fromOffset(14, 72)
            status.Size = UDim2.new(1, -28, 0, 30)
            status.Position = UDim2.fromOffset(14, 40)
            minimize.Text = "+"
        else
            frame.Size = GUI.fullSize
            list.Visible = true
            divider.Visible = true
            summary.Position = UDim2.fromOffset(14, 84)
            status.Size = UDim2.new(1, -28, 0, 42)
            status.Position = UDim2.fromOffset(14, 42)
            minimize.Text = "—"
        end
    end

    minimize.MouseButton1Click:Connect(function()
        GUI.minimized = not GUI.minimized
        applyMinimized()
    end)

    GUI.screen = screen
    GUI.frame = frame
    GUI.titleBar = titleBar
    GUI.status = status
    GUI.summary = summary
    GUI.list = list
    GUI.layout = layout
    GUI.minimize = minimize

    applyMinimized()
end

local function guiSetStatus(text)
    if GUI.status then
        GUI.status.Text = tostring(text or "")
    end
end

local function guiSetSummary(white, black, unknown)
    if GUI.summary then
        GUI.summary.Text = string.format(
            "Whitelist %d  |  Blacklist %d  |  Unknown %d",
            tonumber(white) or 0,
            tonumber(black) or 0,
            tonumber(unknown) or 0
        )
    end
end

local function rowColor(state)
    if state == "whitelist" then
        return Color3.fromRGB(25, 88, 55)
    elseif state == "blacklist" then
        return Color3.fromRGB(75, 35, 38)
    elseif state == "unknown" then
        return Color3.fromRGB(86, 71, 31)
    elseif state == "sending" then
        return Color3.fromRGB(48, 63, 92)
    elseif state == "requesting" then
        return Color3.fromRGB(40, 72, 120)
    elseif state == "ignored" then
        return Color3.fromRGB(92, 66, 31)
    elseif state == "declined" then
        return Color3.fromRGB(96, 45, 45)
    elseif state == "accepted" then
        return Color3.fromRGB(28, 108, 66)
    elseif state == "left" then
        return Color3.fromRGB(64, 64, 68)
    elseif state == "sendfailed" then
        return Color3.fromRGB(112, 52, 52)
    elseif state == "processed" then
        return Color3.fromRGB(48, 58, 72)
    end

    return Color3.fromRGB(38, 49, 67)
end

local function rowTitle(state)
    if state == "whitelist" then
        return "WHITELIST"
    elseif state == "blacklist" then
        return "BLACKLIST"
    elseif state == "unknown" then
        return "UNKNOWN"
    elseif state == "sending" then
        return "SENDING"
    elseif state == "requesting" then
        return "REQUESTING"
    elseif state == "ignored" then
        return "IGNORED"
    elseif state == "declined" then
        return "DECLINED"
    elseif state == "accepted" then
        return "ACCEPTED"
    elseif state == "left" then
        return "LEFT"
    elseif state == "sendfailed" then
        return "SEND FAILED"
    elseif state == "processed" then
        return "PROCESSED"
    end

    return "SCANNING"
end

local function guiSetPlayer(player, state, detail, order)
    if not GUI.list or not player then
        return
    end

    local key = tostring(player.UserId)
    local label = GUI.rows[key]

    if not label then
        label = Instance.new("TextLabel")
        label.Name = "P_" .. key
        label.Parent = GUI.list
        label.Size = UDim2.new(1, -6, 0, 58)
        label.AutomaticSize = Enum.AutomaticSize.Y
        label.BackgroundColor3 = rowColor(state)
        label.BackgroundTransparency = 0.08
        label.BorderSizePixel = 0
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(245, 247, 250)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextWrapped = true
        label.RichText = false
        label.LayoutOrder = order or 0

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = label

        local padding = Instance.new("UIPadding")
        padding.Parent = label
        padding.PaddingTop = UDim.new(0, 8)
        padding.PaddingBottom = UDim.new(0, 8)
        padding.PaddingLeft = UDim.new(0, 10)
        padding.PaddingRight = UDim.new(0, 10)

        GUI.rows[key] = label
    end

    label.BackgroundColor3 = rowColor(state)
    label.LayoutOrder = order or label.LayoutOrder

    local username = tostring(player.Name or "?")
    local display = tostring(player.DisplayName or username)
    local nameText = username

    if display ~= username then
        nameText = display .. "  @" .. username
    end

    label.Text = string.format(
        "[%s]  %s\n%s",
        rowTitle(state),
        nameText,
        tostring(detail or "")
    )
end

createGui()

-- ============================================================================
-- STRICT VALUE / IDENTITY LAYER
-- ============================================================================

local function req(mod)
 if not mod then return end
 local ok,x=pcall(require,mod)
 if ok then return x end
 if setthreadidentity then
  local old
  if getthreadidentity then pcall(function() old=getthreadidentity() end) end
  pcall(setthreadidentity,2)
  ok,x=pcall(require,mod)
  pcall(setthreadidentity,old or 8)
  if ok then return x end
 end
end

local DB=RS:FindFirstChild("Database")
local Mods=RS:FindFirstChild("Modules")
local Sync=req(DB and DB:FindFirstChild("Sync")) or {}
local ProfileData=req(Mods and Mods:FindFirstChild("ProfileData")) or {}
local Meta={}
local NameCandidates={}
local AssetCandidates={}

local function candidateAdd(map,q,m)
 if not q or q=="" or not m then return end
 map[q]=map[q] or {}
 for _,x in ipairs(map[q]) do if x==m then return end end
 map[q][#map[q]+1]=m
end

local function assetKey(x)
 local raw=tostring(x or "")
 if raw=="" then return "" end
 return raw:match("(%d%d%d%d%d+)") or norm(raw)
end

local function indexCatalogAssets(d,m)
 for k,v in pairs(d or {}) do
  local nk=norm(k)
  if (type(v)=="string" or type(v)=="number")
   and (nk:find("image",1,true) or nk:find("icon",1,true) or nk:find("texture",1,true) or nk:find("thumbnail",1,true))
  then
   local a=assetKey(v)
   if a~="" then candidateAdd(AssetCandidates,a,m) end
  end
 end
end

local function addNameMeta(q,m) candidateAdd(NameCandidates,q,m) end

local function indexItems(src)
 if type(src)~="table" then return end
 for id,d in pairs(src) do
  if type(d)=="table" and (d.ItemType=="Knife" or d.ItemType=="Gun") then
   local m={id=tostring(id),cat="Weapons",data=d,name=d.ItemName or d.Name or tostring(id),chroma=d.Chroma==true,type=d.ItemType or "",rarity=d.Rarity or ""}
   Meta["Weapons|"..tostring(id)]=m
   indexCatalogAssets(d,m)
   local display=m.chroma and (m.name:lower():match("^chroma%s") and m.name or ("Chroma "..m.name)) or m.name
   addNameMeta(norm(display),m)
  end
 end
end
indexItems(Sync.Weapons or Sync.Item)

local function tradable(d)
 return type(d)=="table" and d.Tradable~=false and d.CanTrade~=false and d.Untradable~=true and d.NonTradable~=true and d.Locked~=true
end

local VariantPrefixes={{"gold","Gold"},{"silver","Silver"},{"bronze","Bronze"},{"blue","Blue"},{"red","Red"},{"purple","Purple"},{"green","Green"},{"yellow","Yellow"},{"orange","Orange"},{"pink","Pink"}}
local function identityName(meta)
 if not meta then return "" end
 local name=tostring(meta.name or meta.id or "")
 local d=meta.data or {}
 if meta.chroma then return name:lower():match("^chroma%s") and name or ("Chroma "..name) end
 local nameq=norm(name)
 if norm(meta.rarity)=="unique" then
  for _,field in ipairs({"Variant","VariantName","Color","Colour","LeaderboardColor","LeaderboardColour","Edition","Version"}) do
   local rq=norm(d[field])
   if rq~="" then
    for _,pair in ipairs(VariantPrefixes) do
     if (rq==pair[1] or rq:find(pair[1],1,true)) and not nameq:find(pair[1],1,true) then return pair[2].." "..name end
    end
   end
  end
 end
 return name
end

local Checker={rows={},byId={},ready=false}
Checker.raw=[==[
ancient|1|250000000|NiksScythe.png
ancient|771|15250|Gingerscope.png
ancient|743|7700|TravellersAxe.png
ancient|860|1950|Celestial.png
ancient|829|1375|vampsaxe.png
ancient|1026|325|Emberbow.png
ancient|1027|300|Emberscythe.png
ancient|526|250|harvester.png
ancient|661|165|Icepiercer.png
ancient|480|70|Icebreaker.png
ancient|3|45|BatwingUpdated.png
ancient|2|40|ewscythe.png
ancient|529|40|SwirlAxe.png
ancient|471|32|HallowscytheUp.png
ancient|404|20|LogchopperUp.png
ancient|4|15|IcewingknifeUp.png
chroma|739|140000|ChromaTravGun.png
chroma|772|47000|Chroma_Evergun.png
chroma|773|33000|Chroma_Evergreen.png
chroma|855|29000|CBauble.png
chroma|857|26000|ChromaConstellation.png
chroma|831|25000|chromavampsgun.png
chroma|927|23000|ChromaAlienbeam.png
chroma|1036|10000|Chroma_Emberscythe.png
chroma|928|12500|ChromaRaygun.png
chroma|899|8250|ChromaSunsetGun.png
chroma|962|7650|Chroma_Snowcannon.png
chroma|1030|4450|Chroma_Emberbow.png
chroma|900|5500|ChromaSunsetKnife.png
chroma|957|5500|ChromaBlizzard.png
chroma|958|4250|Chroma_Snowstorm.png
chroma|990|3400|CHeartwand.png
chroma|960|2400|Chroma_Snow_Dagger.png
chroma|810|2350|Chroma_Watergun.png
chroma|1006|1875|C_Icecream.png
chroma|1033|1800|coming.png
chroma|1034|1800|coming.png
chroma|985|1800|Chroma_Ornament.png
chroma|992|1800|Ctreat.png
chroma|991|1750|Csweet.png
chroma|1007|1325|CSands.png
chroma|1008|1275|CBeachy.png
chroma|1029|1100|Chroma_Embersickle.png
chroma|447|60|Chroma_Darkbringer.png
chroma|446|55|Chroma_Lightbringer.png
chroma|6|48|chromaluger.png
chroma|8|40|chromalaser.png
chroma|525|40|chromacandle.png
chroma|13|35|chromads.png
chroma|527|35|chromaswirlygun.png
chroma|616|35|ChromaElderwoodBlade.png
chroma|7|33|chromashark.png
chroma|9|33|chromaslasher.png
chroma|10|33|chromafang.png
chroma|439|33|chromagem.png
chroma|11|30|chromaheat.png
chroma|659|30|ChromaCookiecane.png
chroma|14|25|chromatides.png
chroma|15|25|chromaseer.png
chroma|17|25|Chroma_Gingerblade.png
chroma|12|22|chromasaw.png
chroma|16|20|Chroma_Boneblade.png
godly|740|5150|TravGun.png
godly|770|3425|Evergun.png
godly|769|2700|Evergreen.png
godly|856|2475|2024Constellation.png
godly|830|1875|vampsgun.png
godly|762|1850|Turkey.png
godly|926|1850|Alienbeam.png
godly|925|1825|Raygun.png
godly|741|1600|Darkshot.png
godly|742|1575|Darksword.png
godly|696|1160|BlossomGun.png
godly|697|1150|Sakura.png
godly|901|775|SunsetGun.png
godly|961|680|Snowcannon.png
godly|854|675|Bauble.png
godly|902|650|SunsetKnife.png
godly|833|640|soul.png
godly|832|630|spirit.png
godly|924|440|Xenoshot.png
godly|923|435|Xenoknife.png
godly|715|410|rainbowgun.png
godly|891|405|Flora_Gun.png
godly|714|400|Rainbowblade.png
godly|890|395|Bloom_Knife.png
godly|989|350|Heartwand.png
godly|955|250|Blizzard.png
godly|956|250|Snowstorm.png
godly|728|240|Ocean_gun.png
godly|795|235|Flowerwood_Gun.png
godly|727|235|Waves_knife.png
godly|794|230|Flowerwood_Knife.png
godly|959|170|Snow_Dagger.png
godly|988|155|Treat.png
godly|1005|155|Icecream_knife.png
godly|811|150|WaterGun.png
godly|987|150|Sweet.png
godly|1031|140|Mortal.png
godly|1032|140|Immortal.png
godly|859|140|2024Borealis.png
godly|858|135|2024Australis.png
godly|618|120|Bat_Zombie.png
godly|23|90|Updated_Candy.png
godly|1028|80|Embersickle.png
godly|813|80|Pearlsh.png
godly|1003|80|BeachyGodly2026.png
godly|1004|80|SandsGodly2026.png
godly|812|75|Pearl.png
godly|512|65|HeartBladeUp.png
godly|984|60|ornagodly.png
godly|20|38|Red_Luger.png
godly|620|37|Phantom_Shop.png
godly|621|37|Spectre.png
godly|524|35|candleflame.png
godly|18|35|ewrev.png
godly|448|35|DarkbringerUpdated.png
godly|481|35|IceblasterUP.png
godly|22|33|Sugar_v2.png
godly|617|33|Makeshift.png
godly|445|33|LightbringerUpdated.png
godly|619|32|ElderwoodBlade.png
godly|21|25|Green_Luger.png
godly|30|23|AmeriUP.png
godly|46|23|LaserUpdated.png
godly|472|22|hallowgunup.png
godly|532|20|IceBeamUP.png
godly|48|20|SharkUP.png
godly|572|20|Plasmabeam.png
godly|63|20|NightBladeUp.png
godly|528|18|SwirlGunUP.png
godly|531|18|IceFlakeUP.png
godly|32|18|BattleAxe2UP.png
godly|34|18|PixelUp.png
godly|36|18|Ginger_LugerUP.png
godly|31|17|OldGloryUp.png
godly|35|17|BlasterUP.png
godly|39|17|LugerUpdated.png
godly|573|17|Plasmablade.png
godly|37|15|VirtualUP.png
godly|43|15|SlasherUP.png
godly|405|15|MintyUp.png
godly|408|15|LugerCaneUP.png
godly|473|15|VampiresedgeUP.png
godly|482|15|JinglegunUP.png
godly|660|14|Cookiecane.png
godly|662|14|Gingermint.png
godly|522|13|NebulaUp.png
godly|530|13|SwirlyBladeUP.png
godly|49|13|DeathshardUp.png
godly|57|13|Battleaxe1UP.png
godly|60|13|GingerbladeUP.png
godly|379|13|eternalcane.png
godly|440|13|GemstoneUP.png
godly|24|12|ChillUpdated4.png
godly|28|12|ClockworkUp.png
godly|33|12|SpiderUP.png
godly|40|12|HeatUP.png
godly|42|12|TidesUP.png
godly|47|12|FangUp.png
godly|26|10|EternalUpdated.png
godly|41|10|XmasUP.png
godly|58|10|FrostsaberUP.png
godly|441|10|eternal3.png
godly|444|10|Mm2bioblade.png
godly|467|10|Eternal4UP.png
godly|25|9|Handsaw_Png.png
godly|29|9|HallowEdgeUp.png
godly|59|9|IceShardUP.png
godly|19|8|Eternal_2UP.png
godly|27|8|BonebladeUP.png
godly|44|8|PumpkingUP.png
godly|45|8|SawUP.png
godly|62|8|ghostblade.png
godly|38|7|FlamesUp.png
godly|50|7|WinterEdgeUP.png
godly|51|7|IceDragonUp.png
godly|64|7|HallowsbladeUP.png
godly|407|7|FrostbiteUP.png
godly|521|5|EggbladeUP.png
godly|61|5|SnowflakeUP.png
godly|468|5|PrismaticUp.png
godly|479|4|peppermint.png
godly|483|4|CookiebladeUP.png
godly|52|3|redseer.png
godly|53|3|blueseer.png
godly|54|3|purpleseer.png
godly|889|3|Seer.png
godly|55|2|orangeseer.png
godly|56|2|yellowseer.png
]==]

local function checkerPage(meta)
 if not meta then return nil end
 if meta.chroma then return "chroma" end
 local r=norm(meta.rarity)
 if r=="ancient" or r=="godly" then return r end
 return nil
end

local function allowedPage(page) return page=="ancient" or page=="godly" or page=="chroma" end

local function checkerBuild()
 if Checker.ready then return true end
 local count=0
 for line in tostring(Checker.raw):gmatch("[^\r\n]+") do
  local page,id,val,img=line:match("^([^|]+)|([^|]+)|([^|]+)|(.+)$")
  val=tonumber(val)
  if page and id and val and img then
   Checker.rows[page]=Checker.rows[page] or {}
   Checker.byId[page]=Checker.byId[page] or {}
   local rec={page=page,id=tostring(id),v=val,img=tostring(img)}
   Checker.rows[page][#Checker.rows[page]+1]=rec
   Checker.byId[page][rec.id]=rec
   count=count+1
  end
 end
 Checker.ready=count>0
 log("VALUE SNAPSHOT READY",count,"rows (loaded once)")
 return Checker.ready
end

local function checkerCanon(x,page,itemType,level)
 local raw=tostring(x or ""):gsub("%.[^%.]+$","")
 local q=norm(raw)
 q=q:gsub("travellers","traveler"):gsub("travelers","traveler"):gsub("strarry","starry"):gsub("knfie","knife"):gsub("spearmingun","spearmintgun"):gsub("brozen","bronze"):gsub("pumpin","pumpkin")
 if q:sub(1,8)=="travsaxe" then q="traveleraxe"..q:sub(9)
 elseif q:sub(1,7)=="travgun" then q="travelergun"..q:sub(8)
 elseif q:sub(1,8)=="vampsaxe" then q="vampiresaxe"..q:sub(9)
 elseif q:sub(1,8)=="vampsgun" then q="vampiresgun"..q:sub(9)
 elseif q:sub(1,7)=="vampaxe" then q="vampiresaxe"..q:sub(8)
 elseif q:sub(1,6)=="gscope" then q="gingerscope"..q:sub(7)
 elseif q:sub(1,8)=="ewscythe" then q="elderwoodscythe"..q:sub(9) end
 if (tonumber(level) or 0)>=1 then
  q=q:gsub("20%d%d",""):gsub("updated",""):gsub("update",""):gsub("godly","")
  if #q>4 and q:sub(-2)=="up" then q=q:sub(1,-3) end
  if #q>4 and q:sub(-2)=="v2" then q=q:sub(1,-3) end
  if page=="chroma" then
   if q:sub(1,6)=="chroma" then q=q:sub(7) elseif q:sub(1,1)=="c" and #q>4 then q=q:sub(2) end
  end
 end
 if (tonumber(level) or 0)>=2 then
  local t=norm(itemType)
  if t~="" and #q>#t+2 and q:sub(-#t)==t then q=q:sub(1,#q-#t) end
  if t=="knife" and #q>4 and q:sub(-1)=="k" then q=q:sub(1,-2)
  elseif t=="gun" and #q>4 and q:sub(-1)=="g" then q=q:sub(1,-2) end
 end
 return q
end

local function checkerAlias(page,name,typ)
 local q,t=norm(name),norm(typ)
 if page=="godly" and q=="sunrise" and (t=="" or t=="gun") then return "901" end
 if page=="godly" and q=="sunset" and (t=="" or t=="knife") then return "902" end
 if page=="chroma" and (q=="chromasunrise" or q=="sunrise") and (t=="" or t=="gun") then return "899" end
 if page=="chroma" and (q=="chromasunset" or q=="sunset") and (t=="" or t=="knife") then return "900" end
 if page=="chroma" and (q=="chromagemstone" or q=="gemstone") then return "439" end
 if page=="chroma" and (q=="chromamortal" or q=="mortal") then return "1033" end
 if page=="chroma" and (q=="chromaimmortal" or q=="immortal") then return "1034" end
end

local function isSunset(page,id,name)
 local q=norm(name)
 return tostring(id or "")=="902" or tostring(id or "")=="900" or q=="sunset" or q=="chromasunset"
end

local checkerCache={}
local function checkerResolve(name,opts)
 if not checkerBuild() then return nil,"snapshot unavailable" end
 opts=type(opts)=="table" and opts or {}
 local shown=tostring(name or "")
 local pageHint=tostring(opts.page or "")
 local typ=tostring(opts.type or "")
 local iid=tostring(opts.id or "")
 local chroma=opts.chroma==true
 local meta=opts.meta
 if shown=="" and meta then shown=identityName(meta) end
 if pageHint=="" and meta then pageHint=checkerPage(meta) or "" end
 if typ=="" and meta then typ=tostring(meta.type or "") end
 if iid=="" and meta then iid=tostring(meta.id or "") end
 if meta and meta.chroma then chroma=true end
 if pageHint~="" and not allowedPage(pageHint) then return nil,"tier excluded" end
 local ck=table.concat({norm(shown),pageHint,norm(typ),norm(iid),chroma and "1" or "0"},"|")
 if checkerCache[ck] then return checkerCache[ck],"cache" end
 if pageHint~="" then
  local aid=checkerAlias(pageHint,shown,typ)
  local rec=aid and Checker.byId[pageHint] and Checker.byId[pageHint][aid]
  if rec then
   if isSunset(rec.page,rec.id,shown) then return nil,"sunset ignored" end
   checkerCache[ck]=rec; return rec,"alias"
  end
 end
 local pages={}
 if pageHint~="" then pages[#pages+1]=pageHint end
 for _,p in ipairs({"ancient","chroma","godly"}) do
  local seen=false; for _,x in ipairs(pages) do if x==p then seen=true break end end
  if not seen and ((chroma and p=="chroma") or (not chroma and p~="chroma")) then pages[#pages+1]=p end
 end
 local best,bestScore,tied,tiedSame=nil,-100000,false,true
 local itemYear=iid:match("(20%d%d)")
 for _,page in ipairs(pages) do
  local n0,n1,n2=checkerCanon(shown,page,typ,0),checkerCanon(shown,page,typ,1),checkerCanon(shown,page,typ,2)
  local mn=meta and identityName(meta) or ""
  local m0,m1,m2=checkerCanon(mn,page,typ,0),checkerCanon(mn,page,typ,1),checkerCanon(mn,page,typ,2)
  local i0,i1,i2=checkerCanon(iid,page,typ,0),checkerCanon(iid,page,typ,1),checkerCanon(iid,page,typ,2)
  for _,rec in ipairs(Checker.rows[page] or {}) do
   local c0,c1,c2=checkerCanon(rec.img,page,typ,0),checkerCanon(rec.img,page,typ,1),checkerCanon(rec.img,page,typ,2)
   local score=-100000
   if n0~="" and c0==n0 then score=340 elseif n1~="" and c1==n1 then score=285 elseif n2~="" and c2==n2 then score=240 end
   if m0~="" and c0==m0 then score=math.max(score,360) elseif m1~="" and c1==m1 then score=math.max(score,300) elseif m2~="" and c2==m2 then score=math.max(score,255) end
   if i0~="" and c0==i0 then score=math.max(score,430) elseif i1~="" and c1==i1 then score=math.max(score,350) elseif i2~="" and c2==i2 then score=math.max(score,290) end
   if score<240 and n2~="" and c2~="" and math.min(#n2,#c2)>=5 and (n2:find(c2,1,true) or c2:find(n2,1,true)) then score=205 end
   if page==pageHint then score=score+45 end
   local rawImg,t=norm(rec.img),norm(typ)
   if t=="gun" then if rawImg:find("knife",1,true) then score=score-180 elseif rawImg:find("gun",1,true) then score=score+20 end
   elseif t=="knife" then if rawImg:find("gun",1,true) then score=score-180 elseif rawImg:find("knife",1,true) then score=score+20 end end
   local checkerYear=tostring(rec.img):match("(20%d%d)")
   if itemYear and checkerYear then if itemYear==checkerYear then score=score+65 else score=score-120 end end
   if score>bestScore then best,bestScore,tied,tiedSame=rec,score,false,true
   elseif score==bestScore and best and rec.id~=best.id then tied=true; if math.abs((rec.v or 0)-(best.v or 0))>.000001 then tiedSame=false end end
  end
 end
 if best and bestScore>=200 and (not tied or tiedSame) then
  if isSunset(best.page,best.id,shown) then return nil,"sunset ignored" end
  checkerCache[ck]=best
  return best,tied and "value-equivalent" or ("match:"..bestScore)
 end
 if tied then return nil,"ambiguous" end
 return nil,"unresolved"
end

local function checkerMarket(meta)
 local page=checkerPage(meta)
 if not allowedPage(page) then return nil end
 local rec,why=checkerResolve(identityName(meta),{page=page,type=meta.type,id=meta.id,chroma=meta.chroma,meta=meta})
 if not rec then return nil,why end
 return {v=rec.v,id=rec.id,page=rec.page,img=rec.img},nil
end

checkerBuild()

local function ownProfile(forceRemote)
 local rem=RS:FindFirstChild("Remotes")
 local inv=rem and rem:FindFirstChild("Inventory")
 local rf=inv and inv:FindFirstChild("GetProfileData")
 if forceRemote and rf and rf:IsA("RemoteFunction") then
  local ok,x=pcall(function() return rf:InvokeServer() end)
  if ok and type(x)=="table" then return x end
 end
 if type(ProfileData)=="table" and ProfileData.Weapons then return ProfileData end
 if rf and rf:IsA("RemoteFunction") then
  local ok,x=pcall(function() return rf:InvokeServer() end)
  if ok and type(x)=="table" then return x end
 end
end

local function inventoryFromProfile(prof)
 if type(prof)~="table" then return nil end
 local out={items={},total=0}
 local owned=prof.Weapons and prof.Weapons.Owned
 if type(owned)~="table" then return out end
 for id,count in pairs(owned) do
  local qty=type(count)=="number" and math.max(0,math.floor(count)) or 1
  local m=Meta["Weapons|"..tostring(id)]
  if qty>0 and m and tradable(m.data) and allowedPage(checkerPage(m)) then
   local e=checkerMarket(m)
   if e and not isSunset(e.page,e.id,identityName(m)) then
    out.items[#out.items+1]={id=m.id,cat="Weapons",name=identityName(m),qty=qty,value=e.v,type=m.type,page=e.page,checkerId=e.id}
    out.total=out.total+e.v*qty
   end
  end
 end
 table.sort(out.items,function(a,b) if a.value~=b.value then return a.value>b.value end return tostring(a.id)<tostring(b.id) end)
 return out
end

local function scanOwn() return inventoryFromProfile(ownProfile(true) or ownProfile(false)) end

local function unwrapProfile(x,depth)
 depth=depth or 0
 if type(x)~="table" or depth>4 then return nil end
 if type(x.Weapons)=="table" and type(x.Weapons.Owned)=="table" then return x end
 for _,n in ipairs({"ProfileData","Profile","PlayerData","Data","Inventory","FullInventory"}) do
  local p=unwrapProfile(x[n],depth+1); if p then return p end
 end
end

local function callReader(r,p,mode)
 if mode==1 then return r:InvokeServer(p) end
 if mode==2 then return r:InvokeServer(p.UserId) end
 return r:InvokeServer(p.Name)
end

local function findTargetReader(p,force)
 if State.targetReader then return State.targetReader,State.targetMode end
 if not force and State.targetReaderCheckedAt>0 and os.clock()-State.targetReaderCheckedAt<5 then return nil end
 State.targetReaderCheckedAt=os.clock()
 local wanted={getfullinventory=true,getplayerinventory=true,getplayerprofile=true,viewinventory=true,viewprofile=true,getinventory=true}
 local candidates={}
 for _,r in ipairs(RS:GetDescendants()) do
  if r:IsA("RemoteFunction") and wanted[r.Name:lower()] then candidates[#candidates+1]=r end
 end
 table.sort(candidates,function(a,b)
  local an=a.Name:lower()=="getfullinventory" and 0 or 1
  local bn=b.Name:lower()=="getfullinventory" and 0 or 1
  return an<bn
 end)
 for _,r in ipairs(candidates) do
  for mode=1,3 do
   local ok,raw=pcall(function() return callReader(r,p,mode) end)
   local prof=ok and unwrapProfile(raw)
   if prof then State.targetReader,State.targetMode=r,mode; log("target reader",r:GetFullName(),"mode",mode); return r,mode,prof end
  end
 end
end

local function targetInventory(p,force)
 local r,mode,prof=findTargetReader(p,force)
 if not prof and r then
  local ok,raw=pcall(function() return callReader(r,p,mode) end)
  if ok then prof=unwrapProfile(raw) end
  if not prof then State.targetReader=nil; State.targetMode=nil; State.targetReaderCheckedAt=0 end
 end
 return prof and inventoryFromProfile(prof) or nil
end



-- ============================================================================
-- T4.3 SERVER SCAN + ROBUST LIVE JOIN/LEAVE TRACKING
-- ============================================================================

local function fmtValue(v)
    v = tonumber(v) or 0
    if math.floor(v) == v then
        return tostring(math.floor(v))
    end
    return string.format("%.2f", v)
end

local function itemLine(it)
    return string.format(
        "%s | %s | x%d | each=%s | subtotal=%s | checker=%s",
        tostring(it.page or "?"):upper(),
        tostring(it.name or it.id or "?"),
        tonumber(it.qty) or 1,
        fmtValue(it.value),
        fmtValue((tonumber(it.value) or 0) * (tonumber(it.qty) or 1)),
        tostring(it.checkerId or "?")
    )
end

local function eligibleCopies(inv)
    local n = 0
    for _, it in ipairs((inv and inv.items) or {}) do
        n += math.max(1, tonumber(it.qty) or 1)
    end
    return n
end

local function eligibleSummary(inv)
    local parts = {}

    for _, it in ipairs((inv and inv.items) or {}) do
        local qty = math.max(1, tonumber(it.qty) or 1)
        local subtotal = (tonumber(it.value) or 0) * qty

        parts[#parts + 1] = string.format(
            "%s%s (%s)",
            tostring(it.name or it.id or "?"),
            qty > 1 and (" x" .. tostring(qty)) or "",
            fmtValue(subtotal)
        )
    end

    if #parts == 0 then
        return "No eligible Ancient/Godly/Chroma Godly"
    end

    return table.concat(parts, ", ")
end

local Live = {
    byUserId = {},
    order = {},
    nextOrder = 0,
    scanning = {},
    retrying = {},
    retryCount = {},
    white = 0,
    black = 0,
    unknown = 0,
}

local function trackedCount()
    local n = 0
    for _ in pairs(Live.byUserId) do
        n += 1
    end
    return n
end

local function recount()
    local white, black, unknown = 0, 0, 0

    for _, rec in pairs(Live.byUserId) do
        if rec.state == "whitelist" then
            white += 1
        elseif rec.state == "blacklist" then
            black += 1
        elseif rec.state == "unknown" then
            unknown += 1
        end
    end

    Live.white = white
    Live.black = black
    Live.unknown = unknown
    guiSetSummary(white, black, unknown)
end

local function getOrder(p)
    local uid = tostring(p.UserId)

    if not Live.order[uid] then
        Live.nextOrder += 1
        Live.order[uid] = Live.nextOrder
    end

    return Live.order[uid]
end

local function scanOne(p, reason)
    local isJoinLike =
        reason == "join"
        or reason == "retry"

    local retries =
        isJoinLike
        and C.JoinScanRetries
        or C.TargetScanRetries

    local retryDelay =
        isJoinLike
        and C.JoinScanRetryDelay
        or C.TargetScanRetryDelay

    local inv

    for attempt = 1, retries do
        if not p or not p.Parent then
            return "left", nil
        end

        inv = targetInventory(p, attempt > 1)

        if inv then
            return (#inv.items > 0) and "whitelist" or "blacklist", inv
        end

        if attempt < retries then
            guiSetStatus(
                string.format(
                    "%s inventory not ready — retry %d/%d",
                    p.Name,
                    attempt,
                    retries
                )
            )

            task.wait(retryDelay)
        end
    end

    if not p or not p.Parent then
        return "left", nil
    end

    return "unknown", nil
end

local function removePlayerState(p)
    if not p then
        return
    end

    local uid = tostring(p.UserId)

    Live.scanning[uid] = nil
    Live.retrying[uid] = nil
    Live.retryCount[uid] = nil
    Live.byUserId[uid] = nil
    Live.order[uid] = nil

    local row = GUI.rows[uid]
    if row then
        pcall(function()
            row:Destroy()
        end)
        GUI.rows[uid] = nil
    end

    recount()

    guiSetStatus(
        string.format(
            "%s left — removed from live scanner",
            p.Name
        )
    )

    print(
        "[MM2 Scanner T4.3] PLAYER LEFT",
        p.Name,
        "| removed from live state"
    )
end

local scanPlayerLive
local scheduleUnknownRetry

local function applyPlayerResult(p, state, inv)
    if not p or not p.Parent then
        return
    end

    local uid = tostring(p.UserId)
    local order = getOrder(p)

    Live.byUserId[uid] = {
        player = p,
        state = state,
        inv = inv,
    }

    if state == "whitelist" then
        Live.retrying[uid] = nil
        Live.retryCount[uid] = nil

        guiSetPlayer(
            p,
            "whitelist",
            string.format(
                "Eligible: %d  |  Total value: %s\nItems: %s",
                eligibleCopies(inv),
                fmtValue(inv.total),
                eligibleSummary(inv)
            ),
            order
        )

        print(
            "[MM2 Scanner T4.3] WHITELIST",
            p.Name,
            "| eligible copies", eligibleCopies(inv),
            "| eligible total value", fmtValue(inv.total)
        )

    elseif state == "blacklist" then
        Live.retrying[uid] = nil
        Live.retryCount[uid] = nil

        guiSetPlayer(
            p,
            "blacklist",
            "No eligible Ancient / Godly / Chroma Godly",
            order
        )

        print(
            "[MM2 Scanner T4.3] BLACKLIST",
            p.Name,
            "| no eligible Ancient/Godly/Chroma Godly"
        )

    else
        guiSetPlayer(
            p,
            "unknown",
            "Inventory not ready yet — automatic retry active",
            order
        )

        warn(
            "[MM2 Scanner T4.3] TEMP UNKNOWN",
            p.Name,
            "| scheduling background retry"
        )
    end

    recount()
end

scheduleUnknownRetry = function(p)
    if not p or not p.Parent then
        return
    end

    local uid = tostring(p.UserId)

    if Live.retrying[uid] then
        return
    end

    local count = tonumber(Live.retryCount[uid]) or 0

    if count >= C.UnknownRetryMax then
        guiSetPlayer(
            p,
            "unknown",
            "Inventory stayed unreadable after extended retries",
            getOrder(p)
        )

        warn(
            "[MM2 Scanner T4.3] UNKNOWN FINAL",
            p.Name,
            "| extended retry limit reached"
        )
        return
    end

    Live.retrying[uid] = true
    Live.retryCount[uid] = count + 1

    task.spawn(function()
        task.wait(C.UnknownRetryDelay)

        Live.retrying[uid] = nil

        if not p.Parent then
            return
        end

        scanPlayerLive(p, "retry")
    end)
end

scanPlayerLive = function(p, reason)
    if not p or p == LP or not p.Parent then
        return
    end

    local uid = tostring(p.UserId)

    if Live.scanning[uid] then
        return
    end

    Live.scanning[uid] = true

    local order = getOrder(p)

    guiSetPlayer(
        p,
        "scanning",
        reason == "join"
            and "New player joined — waiting for MM2 inventory..."
            or reason == "retry"
                and "Retrying inventory read..."
                or "Reading inventory...",
        order
    )

    guiSetStatus(
        string.format(
            "%s: %s",
            reason == "join"
                and "New join"
                or reason == "retry"
                    and "Retrying"
                    or "Scanning",
            p.Name
        )
    )

    print(
        "[MM2 Scanner T4.3] SCAN",
        reason or "initial",
        p.Name
    )

    local state, inv = scanOne(p, reason)

    Live.scanning[uid] = nil

    if state == "left" or not p.Parent then
        removePlayerState(p)
        return
    end

    applyPlayerResult(p, state, inv)

    if state == "unknown" then
        scheduleUnknownRetry(p)
    else
        guiSetStatus(
            string.format(
                "LIVE — %d tracked | W:%d B:%d U:%d",
                trackedCount(),
                Live.white,
                Live.black,
                Live.unknown
            )
        )
    end
end

-- Attach live listeners BEFORE the initial snapshot so nobody joining/leaving
-- during the initial scan can be missed.
Players.PlayerAdded:Connect(function(p)
    if p == LP then
        return
    end

    print(
        "[MM2 Scanner T4.3] PLAYER JOINED",
        p.Name
    )

    guiSetPlayer(
        p,
        "scanning",
        "Joined server — waiting for inventory data...",
        getOrder(p)
    )

    guiSetStatus(
        "New player joined: "
        .. p.Name
        .. " — preparing inventory scan"
    )

    task.spawn(function()
        -- Small settle delay, followed by the longer progressive read window.
        task.wait(1.5)

        if p.Parent then
            scanPlayerLive(p, "join")
        end
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    if p == LP then
        return
    end

    removePlayerState(p)
end)

-- Initial server scan.
local initial = {}

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        initial[#initial + 1] = p
    end
end

table.sort(initial, function(a, b)
    return a.Name:lower() < b.Name:lower()
end)

print(
    "[MM2 Scanner T4.3] INITIAL FULL SERVER SCAN START | players",
    #initial
)

guiSetStatus(
    "Initial scan — "
    .. tostring(#initial)
    .. " players"
)

for i, p in ipairs(initial) do
    if p.Parent then
        guiSetStatus(
            string.format(
                "Initial scan %d/%d: %s",
                i,
                #initial,
                p.Name
            )
        )

        scanPlayerLive(p, "initial")
    end

    task.wait(0.08)
end

-- Reconcile once after the initial scan in case a player joined during setup.
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        local uid = tostring(p.UserId)

        if not Live.byUserId[uid]
            and not Live.scanning[uid]
        then
            task.spawn(function()
                scanPlayerLive(p, "join")
            end)
        end
    end
end

guiSetStatus(
    string.format(
        "LIVE — tracking joins/leaves | W:%d B:%d U:%d",
        Live.white,
        Live.black,
        Live.unknown
    )
)

print(
    "[MM2 Scanner T4.3] INITIAL SCAN COMPLETE",
    "| whitelist", Live.white,
    "| blacklist", Live.black,
    "| unknown", Live.unknown
)

print(
    "[MM2 Scanner T4.3] LIVE MODE ACTIVE - joins auto-scan with progressive retries; leavers auto-remove"
)

print(
    "[MM2 Scanner T4.3] CHECK: 'VALUE SNAPSHOT READY' should have appeared exactly ONCE"
)


-- ============================================================================
-- T5 OUTGOING REQUEST ROTATION TEST
-- Uses the proven T4.4 live whitelist.
--
-- TEST SCOPE ONLY:
--   * send one outgoing request at a time to WHITELIST players
--   * wait up to 10 seconds
--   * ignored -> click/remote-cancel pending request -> move on
--   * declined/closed -> move on
--   * target leaves -> move on
--   * accepted / trade GUI opens -> STOP T5 HERE (trade engine is next module)
--
-- No item offering, balancing, accepting, webhook, or hopping yet.
-- ============================================================================

local PG_T5 = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
local TradeFolder_T5 = RS:FindFirstChild("Trade")
local SendRequest_T5 = TradeFolder_T5 and TradeFolder_T5:FindFirstChild("SendRequest")
local DeclineRequest_T5 = TradeFolder_T5 and TradeFolder_T5:FindFirstChild("DeclineRequest")

local T5 = {
    processed = {},
    active = nil,
    stopped = false,
    accepted = false,
    sent = 0,
    ignored = 0,
    declined = 0,
    left = 0,
    failed = 0,
    declineSignalAt = 0,
    declineSignalUid = nil,

    -- New players may appear in T4's whitelist before MM2 has made them
    -- trade-ready. Existing players at script start are immediately mature;
    -- PlayerAdded entries must age for 15 seconds before an outgoing request.
    joinedAt = {},
    JoinTradeGrace = 15,
}

-- Existing players were already present when this script reached T5, so they
-- do not need the new-join delay.
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        T5.joinedAt[p.UserId] = 0
    end
end

Players.PlayerAdded:Connect(function(p)
    if p == LP then
        return
    end

    T5.joinedAt[p.UserId] = os.clock()

    print(
        "[MM2 T5.19] NEW PLAYER GRACE START",
        p.Name,
        "| 15s before outgoing request eligibility"
    )
end)

Players.PlayerRemoving:Connect(function(p)
    T5.joinedAt[p.UserId] = nil
end)

local function t517JoinGraceRemaining(p)
    if not p or p == LP then
        return math.huge
    end

    local joined = T5.joinedAt[p.UserId]

    -- Missing/zero means the player existed before T5 startup.
    if not joined or joined <= 0 then
        return 0
    end

    return math.max(
        0,
        T5.JoinTradeGrace - (os.clock() - joined)
    )
end

local function t517TradeReadyByAge(p)
    return t517JoinGraceRemaining(p) <= 0
end

local function t5InventoryDetail(p)
    if not p then
        return ""
    end

    local rec = Live.byUserId[tostring(p.UserId)]
    local inv = rec and rec.inv

    if not inv then
        return "Eligible trader"
    end

    return string.format(
        "Eligible: %d | Total value: %s\nItems: %s",
        eligibleCopies(inv),
        fmtValue(inv.total),
        eligibleSummary(inv)
    )
end

local function t5Row(p, state, extra)
    if not p then
        return
    end

    local base = t5InventoryDetail(p)

    if extra and extra ~= "" then
        base = tostring(extra) .. "\n" .. base
    end

    guiSetPlayer(
        p,
        state,
        base,
        Live.order[tostring(p.UserId)] or 0
    )
end

local function t5RestoreWhitelistRow(p, prefix)
    if not p or not p.Parent then
        return
    end

    local rec = Live.byUserId[tostring(p.UserId)]

    if rec and rec.state == "whitelist" then
        guiSetPlayer(
            p,
            "whitelist",
            (prefix and (tostring(prefix) .. "\n") or "")
            .. string.format(
                "Eligible: %d  |  Total value: %s\nItems: %s",
                eligibleCopies(rec.inv),
                fmtValue(rec.inv.total),
                eligibleSummary(rec.inv)
            ),
            Live.order[tostring(p.UserId)] or 0
        )
    end
end

local function t5Key(x)
    return tostring(x or ""):lower():gsub("[^%w]", "")
end

local function t5Visible(o)
    if not o then
        return false
    end

    local ok, result = pcall(function()
        local c = o

        while c do
            if c:IsA("ScreenGui") and not c.Enabled then
                return false
            end

            if c:IsA("GuiObject") and not c.Visible then
                return false
            end

            c = c.Parent
        end

        return true
    end)

    return ok and result
end

local function t5Text(o)
    if not o then
        return ""
    end

    local s = ""

    if o:IsA("TextLabel")
        or o:IsA("TextButton")
        or o:IsA("TextBox")
    then
        pcall(function()
            s = tostring(o.Text or "")
        end)
    end

    return s
end


local function t5NearestButton(x)
    local cur = x

    for _ = 1, 8 do
        if not cur then
            break
        end

        if cur:IsA("GuiButton") then
            return cur
        end

        cur = cur.Parent
    end

    return nil
end


local function t54ScreenWidth()
    local cam = workspace.CurrentCamera
    if cam then
        local ok, vp = pcall(function()
            return cam.ViewportSize
        end)
        if ok and vp then
            return vp.X
        end
    end
    return 1500
end

local function t54ClickableAncestor(o, limit)
    local c = o

    for _ = 1, (limit or 8) do
        if not c then
            break
        end

        if c:IsA("GuiButton") then
            return c
        end

        c = c.Parent
    end

    return nil
end

local function t56FindMM2LeaderboardRoot()
    local exact = PG_T5:FindFirstChild("MainGUI")
    exact = exact and exact:FindFirstChild("Game")
    exact = exact and exact:FindFirstChild("Leaderboard")

    if exact then
        return exact
    end

    -- Fallback: locate the MM2 trade controls, then climb to the ancestor
    -- named Leaderboard.
    local ok, descendants = pcall(function()
        return PG_T5:GetDescendants()
    end)

    if not ok then
        return nil
    end

    for _, d in ipairs(descendants) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
        )
            and t5Visible(d)
        then
            local text = t5Text(d):upper()

            if text:find("TRADE REQUESTS", 1, true)
                or text:find("CLICK ON A PLAYER TO TRADE", 1, true)
            then
                local p = d

                for _ = 1, 12 do
                    if not p then
                        break
                    end

                    if t5Key(p.Name) == "leaderboard" then
                        return p
                    end

                    p = p.Parent
                end
            end
        end
    end

    return nil
end

local function t55FindMM2TradePanel()
    local root = t56FindMM2LeaderboardRoot()
    if not root then
        return nil
    end

    -- Keep this helper for diagnostics/status. The player search itself uses
    -- the entire Leaderboard root because MM2 stores player rows outside the
    -- lower trade-controls Container.
    return root:FindFirstChild("Container") or root
end

local function t56NameMatchesLeaderboardText(raw, plr)
    if not plr or plr == LP or plr.UserId == LP.UserId then
        return false
    end

    local text = t5Key(raw)
    local user = t5Key(plr.Name)
    local display = t5Key(plr.DisplayName)

    if text == "" then
        return false
    end

    -- Username is the authoritative identity.
    -- MM2 may decorate it, e.g. "[ELITE] username".
    if user ~= "" and text:find(user, 1, true) then
        return true
    end

    -- Display name is fallback only and must not resemble our own identity.
    local lpUser = t5Key(LP.Name)
    local lpDisplay = t5Key(LP.DisplayName)

    if display ~= ""
        and #display >= 4
        and display ~= lpUser
        and display ~= lpDisplay
        and text:find(display, 1, true)
    then
        return true
    end

    return false
end

local function t55FindMM2TradePlayerTarget(plr)
    local root = t56FindMM2LeaderboardRoot()

    if not root then
        return nil, "MM2 Leaderboard root not found"
    end

    local candidates = {}

    local ok, descendants = pcall(function()
        return root:GetDescendants()
    end)

    if not ok then
        return nil, "cannot inspect MM2 Leaderboard"
    end

    for _, d in ipairs(descendants) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
        )
            and t5Visible(d)
            and t56NameMatchesLeaderboardText(t5Text(d), plr)
        then
            local pos, size
            local okPos = pcall(function()
                pos = d.AbsolutePosition
                size = d.AbsoluteSize
            end)

            if okPos and pos and size
                and size.X > 3
                and size.Y > 3
            then
                local button = d:IsA("GuiButton")
                    and d
                    or t54ClickableAncestor(d, 8)

                candidates[#candidates + 1] = {
                    node = d,
                    button = button,
                    x = pos.X,
                    y = pos.Y,
                    area = size.X * size.Y,
                    text = t5Text(d),
                }
            end
        end
    end

    table.sort(candidates, function(a, b)
        -- Prefer an actual clickable row when available.
        if (a.button ~= nil) ~= (b.button ~= nil) then
            return a.button ~= nil
        end

        -- MM2's player names are in the upper/right portion of the leaderboard.
        if a.y ~= b.y then
            return a.y < b.y
        end

        return a.area < b.area
    end)

    local best = candidates[1]

    if not best then
        -- Helpful diagnostic: dump the visible text labels in the actual MM2
        -- Leaderboard root so the next mismatch is obvious.
        print(
            "[MM2 T5.6] TARGET MATCH FAILED",
            plr.Name,
            "| visible leaderboard texts:"
        )

        local shown = 0
        for _, d in ipairs(descendants) do
            if shown >= 20 then
                break
            end

            if (
                d:IsA("TextLabel")
                or d:IsA("TextButton")
            )
                and t5Visible(d)
            then
                local tx = tostring(t5Text(d) or "")
                if tx ~= "" then
                    shown += 1
                    print(
                        "[MM2 T5.6] LB TEXT",
                        shown,
                        "|", tx,
                        "|", d:GetFullName()
                    )
                end
            end
        end

        return nil, "target not found inside full MM2 Leaderboard root"
    end

    print(
        "[MM2 T5.19] TARGET ROW MATCH",
        plr.Name,
        "| visible text:", best.text,
        "| object:", best.node:GetFullName()
    )

    -- MM2's row is normally:
    -- Leaderboard.Container.<username>.PlayerLabel
    -- Tapping only PlayerLabel can hit the wrong/stale row on tablet.
    -- Prefer the row container named after the username/display name.
    local row = best.node.Parent
    local userKey = t5Key(plr.Name)
    local displayKey = t5Key(plr.DisplayName)

    for _ = 1, 4 do
        if not row then
            break
        end

        local nk = t5Key(row.Name)

        if nk == userKey
            or (
                displayKey ~= ""
                and nk == displayKey
            )
        then
            print(
                "[MM2 T5.19] USING ROW CONTAINER",
                row:GetFullName()
            )
            return row, nil
        end

        row = row.Parent
    end

    return best.button or best.node, nil
end

local function t54AncestorContainsTarget(node, plr)
    local wantUser = t5Key(plr.Name)
    local wantDisplay = t5Key(plr.DisplayName)
    local p = node

    for _ = 1, 10 do
        if not p then
            break
        end

        local ok, desc = pcall(function()
            return p:GetDescendants()
        end)

        if ok then
            for _, d in ipairs(desc) do
                if (
                    d:IsA("TextLabel")
                    or d:IsA("TextButton")
                )
                    and t5Visible(d)
                then
                    local q = t5Key(t5Text(d))

                    if q == wantUser
                        or (
                            wantDisplay ~= ""
                            and q == wantDisplay
                        )
                    then
                        return true, p
                    end
                end
            end
        end

        p = p.Parent
    end

    return false, nil
end

local function t57CardContainerForTradeButton(tradeButton)
    local p = tradeButton

    for _ = 1, 10 do
        if not p then
            break
        end

        local hasProfile = false
        local hasTrade = false

        local ok, desc = pcall(function()
            return p:GetDescendants()
        end)

        if ok then
            for _, d in ipairs(desc) do
                if (
                    d:IsA("TextLabel")
                    or d:IsA("TextButton")
                )
                    and t5Visible(d)
                then
                    local q = t5Key(t5Text(d))

                    if q == "profile" then
                        hasProfile = true
                    elseif q == "trade" then
                        hasTrade = true
                    end
                end
            end
        end

        if hasProfile and hasTrade then
            return p
        end

        p = p.Parent
    end

    return nil
end

local function t57CardTextList(card)
    local out = {}

    if not card then
        return out
    end

    local ok, desc = pcall(function()
        return card:GetDescendants()
    end)

    if not ok then
        return out
    end

    for _, d in ipairs(desc) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
        )
            and t5Visible(d)
        then
            local tx = tostring(t5Text(d) or "")

            if tx ~= "" then
                out[#out + 1] = tx
            end
        end
    end

    return out
end

local function t57CardMatchesPlayer(card, plr)
    if not plr or plr == LP or plr.UserId == LP.UserId then
        return false
    end

    local user = t5Key(plr.Name)
    local display = t5Key(plr.DisplayName)
    local lpUser = t5Key(LP.Name)
    local lpDisplay = t5Key(LP.DisplayName)

    for _, tx in ipairs(t57CardTextList(card)) do
        local q = t5Key(tx)

        -- Real username is authoritative.
        if user ~= ""
            and q:find(user, 1, true)
        then
            return true
        end

        -- Display-name fallback only if it cannot collide with us.
        if display ~= ""
            and #display >= 4
            and display ~= lpUser
            and display ~= lpDisplay
            and q:find(display, 1, true)
        then
            return true
        end
    end

    return false
end

local function t57FindCardCloseButton(card)
    if not card then
        return nil
    end

    local ok, desc = pcall(function()
        return card:GetDescendants()
    end)

    if not ok then
        return nil
    end

    for _, d in ipairs(desc) do
        if d:IsA("GuiButton")
            and t5Visible(d)
        then
            local q = t5Key(t5Text(d) .. " " .. tostring(d.Name or ""))

            if q == "x"
                or q == "close"
                or q:find("close", 1, true)
            then
                return d
            end
        end
    end

    return nil
end

local function t57FindOpenPlayerCard(plr)
    local roots = {PG_T5}

    for _, root in ipairs(roots) do
        local ok, desc = pcall(function()
            return root:GetDescendants()
        end)

        if ok then
            for _, d in ipairs(desc) do
                if d:IsA("GuiButton")
                    and t5Visible(d)
                    and t5Key(t5Text(d)) == "trade"
                then
                    local card = t57CardContainerForTradeButton(d)

                    if card then
                        if t57CardMatchesPlayer(card, plr) then
                            return card, d, true
                        end

                        -- A Profile/Trade card is open, but for somebody else.
                        return card, d, false
                    end
                end
            end
        end
    end

    -- Text can be nested inside the actual button.
    for _, root in ipairs(roots) do
        local ok, desc = pcall(function()
            return root:GetDescendants()
        end)

        if ok then
            for _, d in ipairs(desc) do
                if (
                    d:IsA("TextLabel")
                    or d:IsA("TextButton")
                )
                    and t5Visible(d)
                    and t5Key(t5Text(d)) == "trade"
                then
                    local b = d:IsA("GuiButton")
                        and d
                        or t54ClickableAncestor(d, 6)

                    if b then
                        local card = t57CardContainerForTradeButton(b)

                        if card then
                            if t57CardMatchesPlayer(card, plr) then
                                return card, b, true
                            end

                            return card, b, false
                        end
                    end
                end
            end
        end
    end

    return nil, nil, nil
end

local function t54FindTradeCardButton(plr)
    local card, tradeButton, matched = t57FindOpenPlayerCard(plr)

    if matched == true then
        print(
            "[MM2 T5.19] VERIFIED PLAYER CARD",
            plr.Name,
            "|", card:GetFullName()
        )

        return tradeButton, nil
    end

    if card and matched == false then
        local texts = table.concat(t57CardTextList(card), " | ")

        warn(
            "[MM2 T5.19] WRONG PLAYER CARD OPEN",
            "wanted", plr.Name,
            "| card text:", texts
        )

        local close = t57FindCardCloseButton(card)

        if close then
            t59DirectTap(close)
            task.wait(0.20)
        end

        return nil, "Profile/Trade card opened for a different player"
    end

    return nil, "Profile/Trade card not visible"
end

local function t59DirectTap(o)
    if not o or not t5Visible(o) then
        return false
    end

    local attempted = false

    -- If it's a button, fire its normal signals first.
    if o:IsA("GuiButton") and firesignal then
        local ok1 = pcall(function()
            firesignal(o.Activated)
        end)

        local ok2 = pcall(function()
            firesignal(o.MouseButton1Click)
        end)

        attempted = attempted or ok1 or ok2
    end

    if o:IsA("GuiButton") then
        local okActivate = pcall(function()
            o:Activate()
        end)

        attempted = attempted or okActivate
    end

    -- Always also perform a real center-screen tap/click for Delta/iPad.
    local okInput = pcall(function()
        local p = o.AbsolutePosition
        local s = o.AbsoluteSize
        local x = p.X + s.X / 2
        local y = p.Y + s.Y / 2

        local touchWorked = false

        if VIM and VIM.SendTouchEvent then
            local okTouch = pcall(function()
                VIM:SendTouchEvent(1, 0, x, y)
                task.wait(0.08)
                VIM:SendTouchEvent(1, 2, x, y)
            end)

            touchWorked = okTouch
        end

        if not touchWorked and VIM then
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end
    end)

    attempted = attempted or okInput

    return attempted
end

local function t54TapGuiObject(o)
    return t59DirectTap(o)
end

local function t58Center(o)
    local ok, p, s = pcall(function()
        return o.AbsolutePosition, o.AbsoluteSize
    end)

    if not ok or not p or not s then
        return nil, nil
    end

    return p.X + s.X / 2, p.Y + s.Y / 2
end

local function t58FindTargetPlayerLabel(plr)
    if not plr then
        return nil, "target missing"
    end

    if plr == LP or plr.UserId == LP.UserId then
        warn(
            "[MM2 T5.19] SELF TARGET BLOCKED",
            plr.Name
        )
        return nil, "refusing to target LocalPlayer"
    end

    local root = t56FindMM2LeaderboardRoot()

    if not root then
        return nil, "MM2 Leaderboard root not found"
    end

    local container = root:FindFirstChild("Container")
    local userKey = t5Key(plr.Name)

    -- Best/authoritative path:
    -- MainGUI.Game.Leaderboard.Container.<REAL USERNAME>.PlayerLabel
    if container then
        for _, row in ipairs(container:GetChildren()) do
            if row ~= nil
                and t5Key(row.Name) == userKey
                and t5Key(row.Name) ~= t5Key(LP.Name)
            then
                local label =
                    row:FindFirstChild("PlayerLabel")
                    or row:FindFirstChildWhichIsA("TextButton")
                    or row:FindFirstChildWhichIsA("TextLabel")

                if label and t5Visible(label) then
                    print(
                        "[MM2 T5.19] EXACT USERNAME ROW",
                        plr.Name,
                        "| row:", row:GetFullName(),
                        "| label:", label:GetFullName()
                    )

                    return label, nil
                end
            end
        end
    end

    -- Fallback for layout changes: search text, but still reject our own row.
    local display = t5Key(plr.DisplayName)
    local candidates = {}

    local ok, desc = pcall(function()
        return root:GetDescendants()
    end)

    if not ok then
        return nil, "cannot inspect MM2 Leaderboard"
    end

    for _, d in ipairs(desc) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
        )
            and t5Visible(d)
        then
            local tx = t5Key(t5Text(d))
            local parentName = d.Parent and t5Key(d.Parent.Name) or ""

            -- Never accept our own MM2 row.
            if parentName ~= t5Key(LP.Name) then
                local userMatch =
                    userKey ~= ""
                    and tx:find(userKey, 1, true)

                local displayMatch =
                    display ~= ""
                    and #display >= 4
                    and display ~= t5Key(LP.Name)
                    and display ~= t5Key(LP.DisplayName)
                    and tx:find(display, 1, true)

                if userMatch or displayMatch then
                    local score = 0

                    if parentName == userKey then
                        score += 200
                    end

                    if t5Key(d.Name) == "playerlabel" then
                        score += 100
                    end

                    if userMatch then
                        score += 40
                    end

                    if tx == userKey then
                        score += 20
                    end

                    candidates[#candidates + 1] = {
                        node = d,
                        score = score,
                        text = t5Text(d),
                    }
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.score > b.score
    end)

    local best = candidates[1]

    if not best then
        return nil, "target PlayerLabel not found"
    end

    print(
        "[MM2 T5.19] FALLBACK PLAYERLABEL MATCH",
        plr.Name,
        "|", best.text,
        "|", best.node:GetFullName()
    )

    return best.node, nil
end

local function t58FindAnyOpenCard()
    local ok, desc = pcall(function()
        return PG_T5:GetDescendants()
    end)

    if not ok then
        return nil, nil
    end

    for _, d in ipairs(desc) do
        if d:IsA("GuiButton")
            and t5Visible(d)
            and t5Key(t5Text(d)) == "trade"
        then
            local card = t57CardContainerForTradeButton(d)

            if card then
                return card, d
            end
        end
    end

    for _, d in ipairs(desc) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
        )
            and t5Visible(d)
            and t5Key(t5Text(d)) == "trade"
        then
            local b = d:IsA("GuiButton")
                and d
                or t54ClickableAncestor(d, 6)

            if b then
                local card = t57CardContainerForTradeButton(b)

                if card then
                    return card, b
                end
            end
        end
    end

    return nil, nil
end

local function t58FindCloseNearCard(card, tradeButton)
    -- First try the old card-local lookup.
    local old = t57FindCardCloseButton(card)

    if old then
        return old
    end

    local tx, ty = t58Center(tradeButton)
    if not tx then
        return nil
    end

    local best = nil
    local bestDist = math.huge

    local ok, desc = pcall(function()
        return PG_T5:GetDescendants()
    end)

    if not ok then
        return nil
    end

    for _, d in ipairs(desc) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
            or d:IsA("ImageButton")
        )
            and t5Visible(d)
        then
            local keyText = t5Key(t5Text(d))
            local keyName = t5Key(d.Name)
            local looksClose =
                keyText == "x"
                or keyText == "close"
                or keyName == "close"
                or keyName:find("close", 1, true)

            if looksClose then
                local cx, cy = t58Center(d)

                if cx then
                    local dx = cx - tx
                    local dy = cy - ty
                    local dist = math.sqrt(dx * dx + dy * dy)

                    -- The card X is visually very close to Profile/Trade.
                    if dist < bestDist and dist < 500 then
                        bestDist = dist
                        best = d
                    end
                end
            end
        end
    end

    return best
end

local function t58CloseAnyOpenCard()
    for attempt = 1, 3 do
        local card, tradeButton = t58FindAnyOpenCard()

        if not card then
            return true
        end

        local texts = table.concat(t57CardTextList(card), " | ")

        print(
            "[MM2 T5.19] STALE CARD PRESENT",
            "|", texts
        )

        local close = t58FindCloseNearCard(card, tradeButton)

        if not close then
            warn(
                "[MM2 T5.19] STALE CARD CLOSE FAILED",
                "| no nearby X/Close control found"
            )
            return false
        end

        print(
            "[MM2 T5.19] CLOSING STALE CARD",
            close:GetFullName()
        )

        local clicked = t54TapGuiObject(close)

        if not clicked then
            clicked = t59DirectTap(close)
        end

        task.wait(0.30)

        if not t58FindAnyOpenCard() then
            print("[MM2 T5.19] STALE CARD CLEARED")
            return true
        end
    end

    return t58FindAnyOpenCard() == nil
end


local function t511MouseClickPlayerLabel(label, plr)
    if not label or not t5Visible(label) then
        return false
    end

    local ok, pos, size = pcall(function()
        return label.AbsolutePosition, label.AbsoluteSize
    end)

    if not ok or not pos or not size then
        return false
    end

    local rawX = pos.X + size.X / 2
    local rawY = pos.Y + size.Y / 2

    local insetX, insetY = 0, 0
    pcall(function()
        local topLeft = GuiService:GetGuiInset()
        insetX = topLeft.X
        insetY = topLeft.Y
    end)

    -- IMPORTANT:
    -- MM2's PlayerGui AbsolutePosition is measured below Roblox's top inset,
    -- while VirtualInputManager expects full-screen coordinates on this iPad.
    -- The screen recording proved our old clicks were exactly insetY pixels
    -- too high (58 px in the captured session).
    local x = rawX + insetX
    local y = rawY + insetY

    print(
        "[MM2 T5.19] PLAYERLABEL CLICK COORDS",
        plr and plr.Name or "?",
        "| raw", math.floor(rawX), math.floor(rawY),
        "| corrected", math.floor(x), math.floor(y),
        "| w", math.floor(size.X),
        "| h", math.floor(size.Y),
        "| guiInset", math.floor(insetX), math.floor(insetY)
    )

    local clicked = pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.07)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)

    return clicked
end

local function t54OpenTargetCard(plr)
    local cleared = t58CloseAnyOpenCard()

    if not cleared then
        return false, "could not clear stale Profile/Trade card"
    end

    task.wait(0.20)

    local label, why = t58FindTargetPlayerLabel(plr)

    if not label then
        return false, why
    end

    print(
        "[MM2 T5.19] EXACT PLAYERLABEL",
        plr.Name,
        "|", label:GetFullName()
    )

    local clicked = t511MouseClickPlayerLabel(label, plr)

    if not clicked then
        return false, "mouse-style PlayerLabel click failed"
    end

    local deadline = os.clock() + 3.0
    local lastWrong = nil

    while os.clock() < deadline do
        local card, tradeButton, matched = t57FindOpenPlayerCard(plr)

        if card and matched == true then
            print(
                "[MM2 T5.19] VERIFIED FRESH CARD",
                plr.Name,
                "|", card:GetFullName()
            )

            return true, tradeButton
        end

        if card and matched == false then
            local texts = table.concat(t57CardTextList(card), " | ")

            if texts ~= lastWrong then
                lastWrong = texts

                warn(
                    "[MM2 T5.19] WRONG CARD AFTER EXACT MOUSE CLICK",
                    "wanted", plr.Name,
                    "| card text:", texts
                )
            end

            t58CloseAnyOpenCard()

            return false, "exact mouse click opened a different player's card"
        end

        task.wait(0.08)
    end

    return false, "exact mouse click produced no fresh Profile/Trade card"
end

local function t5FindTradePanel()
    for _, d in ipairs(PG_T5:GetDescendants()) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
        )
            and t5Visible(d)
            and t5Text(d):upper():find(
                "TRADE REQUESTS",
                1,
                true
            )
        then
            local p = d

            for _ = 1, 8 do
                if not p then
                    break
                end

                local ok, desc = pcall(function()
                    return p:GetDescendants()
                end)

                if ok and #desc >= 5 then
                    return p
                end

                p = p.Parent
            end
        end
    end

    return nil
end

local function t5FindTradeListPlayerButton(plr)
    local panel = t5FindTradePanel()

    if not panel then
        return nil, "trade panel not found"
    end

    local wantName = t5Key(plr.Name)
    local wantDisplay = t5Key(plr.DisplayName)

    local ok, desc = pcall(function()
        return panel:GetDescendants()
    end)

    if not ok then
        return nil, "cannot inspect trade panel"
    end

    for _, d in ipairs(desc) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
        )
            and t5Visible(d)
        then
            local q = t5Key(t5Text(d))

            if q == wantName
                or (
                    wantDisplay ~= ""
                    and q == wantDisplay
                )
            then
                local b =
                    d:IsA("GuiButton")
                    and d
                    or t5NearestButton(d)

                if b then
                    return b, nil
                end
            end
        end
    end

    return nil, "player row/button not found"
end

local function t5Roots()
    local out = {PG_T5, CoreGui}

    if gethui then
        local ok, h = pcall(gethui)

        if ok and h then
            out[#out + 1] = h
        end
    end

    return out
end

local function t5ClickButton(b)
    if not b or not t5Visible(b) then
        return false
    end

    local attempted = false

    if firesignal then
        attempted = pcall(function()
            firesignal(b.Activated)
        end) or attempted

        pcall(function()
            firesignal(b.MouseButton1Click)
        end)
    end

    pcall(function()
        b:Activate()
        attempted = true
    end)

    pcall(function()
        local p = b.AbsolutePosition
        local sz = b.AbsoluteSize
        local x = p.X + sz.X / 2
        local y = p.Y + sz.Y / 2

        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.04)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)

        attempted = true
    end)

    return attempted
end

local function t5FindPendingCancel()
    for _, root in ipairs(t5Roots()) do
        if root then
            local ok, list = pcall(function()
                return root:GetDescendants()
            end)

            if ok then
                for _, marker in ipairs(list) do
                    if t5Visible(marker)
                        and (
                            marker:IsA("TextLabel")
                            or marker:IsA("TextButton")
                            or marker:IsA("TextBox")
                        )
                        and t5Text(marker):upper():find(
                            "TRADE REQUEST PENDING",
                            1,
                            true
                        )
                    then
                        local p = marker

                        for _ = 1, 10 do
                            if not p then
                                break
                            end

                            local ok2, desc = pcall(function()
                                return p:GetDescendants()
                            end)

                            if ok2 then
                                for _, d in ipairs(desc) do
                                    if d:IsA("GuiButton")
                                        and t5Visible(d)
                                    then
                                        local label = t5Key(t5Text(d))

                                        if label == "cancel"
                                            or t5Key(d.Name) == "cancel"
                                        then
                                            return marker, d
                                        end

                                        local ok3, inner = pcall(function()
                                            return d:GetDescendants()
                                        end)

                                        if ok3 then
                                            for _, q in ipairs(inner) do
                                                if (
                                                    q:IsA("TextLabel")
                                                    or q:IsA("TextButton")
                                                )
                                                    and t5Key(t5Text(q)) == "cancel"
                                                then
                                                    return marker, d
                                                end
                                            end
                                        end
                                    end
                                end
                            end

                            p = p.Parent
                        end

                        return marker, nil
                    end
                end
            end
        end
    end

    return nil, nil
end

local function t5PendingVisible()
    return select(1, t5FindPendingCancel()) ~= nil
end

local function t5Trade()
    for _, name in ipairs({"TradeGUI_Phone", "TradeGUI"}) do
        local g = PG_T5:FindFirstChild(name)
        local c = g and g:FindFirstChild("Container")
        local t = c and c:FindFirstChild("Trade")

        if t then
            local ok, enabled = pcall(function()
                return g.Enabled
            end)

            if not ok or enabled then
                return t
            end
        end
    end

    return nil
end

local function t5Partner(t)
    local o = t and t:FindFirstChild("TheirOffer")
    local u = o and o:FindFirstChild("Username")
    local s = u and tostring(u.Text or "") or ""

    s = s:match("^%s*%((.-)%)%s*$") or s

    return s
        :gsub("^@", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end


-- Explicit outgoing-decline signal from MM2.
-- Old working builds used this RemoteEvent as the strongest decline evidence.
if DeclineRequest_T5
    and DeclineRequest_T5:IsA("RemoteEvent")
then
    DeclineRequest_T5.OnClientEvent:Connect(function(...)
        local active = T5.active

        if not active then
            return
        end

        T5.declineSignalAt = os.clock()
        T5.declineSignalUid = active.UserId

        print(
            "[MM2 T5.2] DECLINE SIGNAL",
            active.Name,
            "| DeclineRequest.OnClientEvent"
        )

        t5Row(
            active,
            "declined",
            "MM2 decline signal received | verifying trade did not open"
        )
    end)
end

local function t5CancelPending(reason)
    local remoteSent = false
    local uiClicked = false

    local function pulse()
        if DeclineRequest_T5
            and DeclineRequest_T5:IsA("RemoteEvent")
        then
            local ok = pcall(function()
                DeclineRequest_T5:FireServer()
            end)

            remoteSent = remoteSent or ok
        end

        local _, button = t5FindPendingCancel()

        if button then
            uiClicked = t5ClickButton(button) or uiClicked
        end
    end

    for _ = 1, 4 do
        pulse()

        if not t5PendingVisible() then
            break
        end

        task.wait(0.10)
    end

    local untilAt = os.clock() + 1.0

    while os.clock() < untilAt
        and t5PendingVisible()
    do
        pulse()
        task.wait(0.10)
    end

    local cleared = not t5PendingVisible()

    print(
        "[MM2 T5] REQUEST CANCEL",
        tostring(reason or "timeout"),
        "| remote", remoteSent,
        "| UI", uiClicked,
        "| cleared", cleared
    )

    return cleared
end

local function t5MarkProcessed(p, result)
    if not p then
        return
    end

    T5.processed[p.UserId] = tostring(result or "done")
end

local function t5PendingScannerWork()
    for _, rec in pairs(Live.byUserId) do
        if rec.state == "unknown" then
            return true
        end
    end

    for _, v in pairs(Live.scanning) do
        if v then
            return true
        end
    end

    for _, v in pairs(Live.retrying) do
        if v then
            return true
        end
    end

    return false
end

local function t5NextTarget()
    local choices = {}

    for uid, rec in pairs(Live.byUserId) do
        local p = rec.player

        if rec.state == "whitelist"
            and p
            and p.Parent == Players
            and not T5.processed[p.UserId]
            and t517TradeReadyByAge(p)
        then
            choices[#choices + 1] = p
        end
    end

    table.sort(choices, function(a, b)
        local ao = Live.order[tostring(a.UserId)] or math.huge
        local bo = Live.order[tostring(b.UserId)] or math.huge

        if ao ~= bo then
            return ao < bo
        end

        return a.Name:lower() < b.Name:lower()
    end)

    return choices[1]
end

local function t517SoonestMaturingWhitelist()
    local bestPlayer = nil
    local bestRemain = math.huge

    for _, rec in pairs(Live.byUserId) do
        local p = rec.player

        if rec.state == "whitelist"
            and p
            and p.Parent == Players
            and not T5.processed[p.UserId]
        then
            local remain = t517JoinGraceRemaining(p)

            if remain > 0 and remain < bestRemain then
                bestRemain = remain
                bestPlayer = p
            end
        end
    end

    return bestPlayer, bestRemain
end

local function t5SetStatus(text)
    guiSetStatus("T5 — " .. tostring(text or ""))
end


local function t513ClickVerifiedTradeButton(button, target)
    if not button or not t5Visible(button) then
        return false
    end

    local ok, pos, size = pcall(function()
        return button.AbsolutePosition, button.AbsoluteSize
    end)

    if not ok or not pos or not size then
        return false
    end

    local insetX, insetY = 0, 0

    pcall(function()
        local topLeft = GuiService:GetGuiInset()
        insetX = topLeft.X
        insetY = topLeft.Y
    end)

    local rawX = pos.X + size.X / 2
    local rawY = pos.Y + size.Y / 2
    local x = rawX + insetX
    local y = rawY + insetY

    print(
        "[MM2 T5.19] TRADE BUTTON CLICK COORDS",
        target and target.Name or "?",
        "| raw", math.floor(rawX), math.floor(rawY),
        "| corrected", math.floor(x), math.floor(y),
        "| guiInset", math.floor(insetX), math.floor(insetY)
    )

    -- IMPORTANT:
    -- Do NOT call the older t5ClickButton here. That helper also sends a raw
    -- physical click after firing button signals, which can land ~58 px high
    -- on this iPad and hit Profile instead of Trade.
    local clicked = pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.07)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)

    return clicked
end


local function t515WaitForTradeOpen(target, seconds, reason)
    local deadline = os.clock() + (tonumber(seconds) or 3.0)

    while os.clock() < deadline do
        local trade = t5Trade()

        if trade then
            T5.accepted = true

            t5Row(
                target,
                "accepted",
                tostring(reason or "Request closed")
                .. " | trade window opened"
            )

            print(
                "[MM2 T5.19] TRADE-OPEN PRECEDENCE",
                target and target.Name or "?",
                "|", tostring(reason or "request close")
            )

            return true
        end

        if not target
            or not target.Parent
            or Players:GetPlayerByUserId(target.UserId) ~= target
        then
            return false
        end

        task.wait(0.08)
    end

    return t5Trade() ~= nil
end


local function t516PendingOwnerName()
    local marker = select(1, t5FindPendingCancel())

    if not marker then
        return nil
    end

    -- Search nearby visible text for an exact current-player username/display.
    local p = marker

    for _ = 1, 8 do
        if not p then
            break
        end

        local ok, desc = pcall(function()
            return p:GetDescendants()
        end)

        if ok then
            for _, d in ipairs(desc) do
                if (
                    d:IsA("TextLabel")
                    or d:IsA("TextButton")
                )
                    and t5Visible(d)
                then
                    local q = t5Key(t5Text(d))

                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LP then
                            if q == t5Key(plr.Name)
                                or q == t5Key(plr.DisplayName)
                            then
                                return plr.Name
                            end
                        end
                    end
                end
            end
        end

        p = p.Parent
    end

    return nil
end

local function t516DeclineAllowed(target, reason)
    -- Absolute precedence:
    -- 1) open trade wins
    -- 2) visible pending request wins over decline
    -- 3) only then can decline be finalized
    if t5Trade() then
        print(
            "[MM2 T5.19] DECLINE BLOCKED",
            target and target.Name or "?",
            "| trade window is open",
            "|", tostring(reason or "")
        )
        return false, "trade-open"
    end

    if t5PendingVisible() then
        print(
            "[MM2 T5.19] DECLINE BLOCKED",
            target and target.Name or "?",
            "| pending request still visible",
            "| owner", tostring(t516PendingOwnerName() or "unknown"),
            "|", tostring(reason or "")
        )

        T5.declineSignalAt = 0
        T5.declineSignalUid = nil

        return false, "still-pending"
    end

    -- Small redraw guard. MM2 can briefly destroy/recreate the pending panel.
    task.wait(0.30)

    if t5Trade() then
        return false, "trade-open"
    end

    if t5PendingVisible() then
        print(
            "[MM2 T5.19] DECLINE BLOCKED AFTER REDRAW CHECK",
            target and target.Name or "?",
            "| owner", tostring(t516PendingOwnerName() or "unknown")
        )

        T5.declineSignalAt = 0
        T5.declineSignalUid = nil

        return false, "still-pending"
    end

    return true, "declined"
end

local function t516ResumeVisiblePending(target, maxSeconds)
    local started = os.clock()
    local timeout = tonumber(maxSeconds) or 10

    print(
        "[MM2 T5.19] RESUME EXISTING PENDING",
        target and target.Name or "?",
        "| owner", tostring(t516PendingOwnerName() or "unknown")
    )

    while os.clock() - started < timeout do
        if t5Trade() then
            T5.accepted = true

            t5Row(
                target,
                "accepted",
                "Trade window opened while recovering visible pending request"
            )

            return "trade-open"
        end

        if not target
            or not target.Parent
            or Players:GetPlayerByUserId(target.UserId) ~= target
        then
            return "left"
        end

        if not t5PendingVisible() then
            -- Give accept animation/GUI construction a final grace window.
            if t515WaitForTradeOpen(
                target,
                2.5,
                "Recovered pending request closed"
            ) then
                return "trade-open"
            end

            local allowed, state = t516DeclineAllowed(
                target,
                "recovered pending request closed"
            )

            if allowed then
                return "declined"
            elseif state == "trade-open" then
                return "trade-open"
            end
        end

        local left = math.max(0, timeout - (os.clock() - started))

        t5Row(
            target,
            "requesting",
            string.format(
                "Pending request still active | %.1fs recovery watch",
                left
            )
        )

        t5SetStatus(
            string.format(
                "pending request still active for %s | %.1fs",
                target.Name,
                left
            )
        )

        task.wait(0.12)
    end

    -- A request that is truly still pending after the recovery watch is an
    -- ignored/stale request, not a decline. Cancel it before rotation resumes.
    if t5PendingVisible() then
        t5CancelPending("pending-state recovery timeout")
    end

    return "ignored"
end

local function t5SendAndWatch(target)
    if not target
        or target.Parent ~= Players
    then
        return "left"
    end

    -- Last-moment new-join maturity guard. This prevents a race where the
    -- player was selected just before their 15-second grace was enforced.
    local joinRemain = t517JoinGraceRemaining(target)

    if joinRemain > 0 then
        print(
            "[MM2 T5.19] SEND HELD FOR JOIN GRACE",
            target.Name,
            "| remaining", string.format("%.2f", joinRemain)
        )

        t5Row(
            target,
            "whitelist",
            string.format(
                "New player | waiting %.1fs before outgoing trade request\n%s",
                joinRemain,
                t5InventoryDetail(target)
            )
        )

        while joinRemain > 0 do
            if not target.Parent
                or Players:GetPlayerByUserId(target.UserId) ~= target
            then
                return "left"
            end

            if t5Trade() then
                return "trade-open"
            end

            task.wait(math.min(0.25, joinRemain))
            joinRemain = t517JoinGraceRemaining(target)
        end
    end

    -- Absolute safety guard: this build must never initiate a trade with self.
    if target == LP or target.UserId == LP.UserId then
        warn(
            "[MM2 T5.19] HARD SELF-TARGET BLOCK",
            target.Name,
            "| uid", target.UserId
        )

        return "self-blocked"
    end

    T5.active = target
    T5.sent += 1
    T5.declineSignalAt = 0
    T5.declineSignalUid = nil

    local maxAttempts = 3
    local delivered = false

    for attempt = 1, maxAttempts do
        if not target.Parent
            or Players:GetPlayerByUserId(target.UserId) ~= target
        then
            T5.left += 1

            t5Row(
                target,
                "left",
                "Player left before tablet request flow completed"
            )

            return "left"
        end

        if t5Trade() then
            T5.accepted = true

            t5Row(
                target,
                "accepted",
                "Trade window already open"
            )

            return "trade-open"
        end

        local mm2Root = t56FindMM2LeaderboardRoot()
        local mm2Panel = t55FindMM2TradePanel()

        print(
            "[MM2 T5.19] MM2 LEADERBOARD ROOT",
            mm2Root and mm2Root:GetFullName() or "NOT FOUND"
        )

        print(
            "[MM2 T5.19] TRADE CONTROLS",
            mm2Panel and mm2Panel:GetFullName() or "NOT FOUND"
        )

        t5Row(
            target,
            "sending",
            string.format(
                "MM2 panel attempt %d/%d | tapping target name",
                attempt,
                maxAttempts
            )
        )

        t5SetStatus(
            string.format(
                "MM2 trade-panel send to %s | opening player card %d/%d",
                target.Name,
                attempt,
                maxAttempts
            )
        )

        print(
            "[MM2 T5.19] STEP 1",
            target.Name,
            "| tap target in MM2 trade panel",
            "| attempt", attempt
        )

        local opened, tradeButtonOrWhy = t54OpenTargetCard(target)

        if not opened then
            warn(
                "[MM2 T5.19] CARD OPEN FAILED",
                target.Name,
                "|", tostring(tradeButtonOrWhy)
            )

            t5Row(
                target,
                "sending",
                "Could not open target Profile/Trade card from MM2 panel | retrying"
            )

            if attempt < maxAttempts then
                task.wait(0.8)
                continue
            end

            T5.failed += 1

            t5Row(
                target,
                "sendfailed",
                "Failed at MM2 trade-panel/card stage after 3 attempts"
            )

            return "send-failed"
        end

        local tradeButton = tradeButtonOrWhy

        t5Row(
            target,
            "sending",
            "Player card opened | tapping Trade"
        )

        print(
            "[MM2 T5.19] STEP 2",
            target.Name,
            "| Trade button found | clicking"
        )

        local clickedTrade = t513ClickVerifiedTradeButton(
            tradeButton,
            target
        )

        if not clickedTrade then
            warn(
                "[MM2 T5.19] TRADE BUTTON CLICK FAILED",
                target.Name
            )

            t5Row(
                target,
                "sending",
                "Trade button click failed | retrying"
            )

            if attempt < maxAttempts then
                task.wait(0.8)
                continue
            end

            T5.failed += 1

            t5Row(
                target,
                "sendfailed",
                "Failed to click Trade after 3 attempts"
            )

            return "send-failed"
        end

        print(
            "[MM2 T5.19] STEP 3",
            target.Name,
            "| waiting for TRADE REQUEST PENDING"
        )

        t5Row(
            target,
            "sending",
            "Trade tapped | verifying TRADE REQUEST PENDING"
        )

        local proofDeadline = os.clock() + 2.75

        while os.clock() < proofDeadline do
            if not target.Parent
                or Players:GetPlayerByUserId(target.UserId) ~= target
            then
                T5.left += 1

                t5Row(
                    target,
                    "left",
                    "Player left while verifying pending request"
                )

                return "left"
            end

            if t5Trade() then
                T5.accepted = true

                t5Row(
                    target,
                    "accepted",
                    "Trade accepted immediately | trade window opened"
                )

                return "trade-open"
            end

            if T5.declineSignalUid == target.UserId
                and T5.declineSignalAt > 0
            then
                -- MM2 can emit DeclineRequest when the pending channel closes
                -- for an ACCEPTED request too. Treat this as provisional.
                t5Row(
                    target,
                    "requesting",
                    "Request channel changed | checking for trade window..."
                )

                if t515WaitForTradeOpen(
                    target,
                    3.0,
                    "Request signal received"
                ) then
                    return "trade-open"
                end

                local allowed, state = t516DeclineAllowed(
                    target,
                    "request signal after trade-open grace"
                )

                if allowed then
                    T5.declined += 1

                    t5Row(
                        target,
                        "declined",
                        "Request closed and no trade/pending remained | outgoing turn complete"
                    )

                    return "declined"
                elseif state == "trade-open" then
                    return "trade-open"
                end

                -- Pending is still real/visible. Stay on this SAME target.
                T5.declineSignalAt = 0
                T5.declineSignalUid = nil
            end

            if t5PendingVisible() then
                delivered = true
                break
            end

            task.wait(0.08)
        end

        if delivered then
            print(
                "[MM2 T5.19] DELIVERY CONFIRMED",
                target.Name,
                "| MM2 panel -> card -> Trade -> pending"
            )
            break
        end

        warn(
            "[MM2 T5.19] PENDING NOT FOUND",
            target.Name,
            "| tablet attempt", attempt
        )

        t5Row(
            target,
            "sending",
            string.format(
                "Trade tapped but no pending prompt | attempt %d/%d",
                attempt,
                maxAttempts
            )
        )

        if attempt < maxAttempts then
            task.wait(0.9)
        end
    end

    if not delivered then
        T5.failed += 1

        t5Row(
            target,
            "sendfailed",
            "MM2 trade-panel flow never produced TRADE REQUEST PENDING | NOT ignored"
        )

        return "send-failed"
    end

    -- The request is now proven to exist on the sender side.
    local responseStarted = os.clock()

    t5Row(
        target,
        "requesting",
        "TRADE REQUEST PENDING confirmed | waiting 10.0s"
    )

    t5SetStatus(
        "confirmed request to "
        .. target.Name
        .. " | 10.0s"
    )

    while os.clock() - responseStarted < 10 do
        if not target.Parent
            or Players:GetPlayerByUserId(target.UserId) ~= target
        then
            T5.left += 1

            t5Row(
                target,
                "left",
                "Player left after confirmed request"
            )

            return "left"
        end

        local trade = t5Trade()

        if trade then
            T5.accepted = true

            t5Row(
                target,
                "accepted",
                "Trade request accepted | trade window opened"
            )

            return "trade-open"
        end

        if T5.declineSignalUid == target.UserId
            and T5.declineSignalAt > 0
        then
            -- Do not equate DeclineRequest.OnClientEvent with an actual
            -- decline. MM2 also uses request-channel closure during accept.
            t5Row(
                target,
                "requesting",
                "Request response received | checking whether trade opens..."
            )

            if t515WaitForTradeOpen(
                target,
                3.0,
                "Request response received"
            ) then
                return "trade-open"
            end

            if not t5PendingVisible() then
                T5.declined += 1

                t5Row(
                    target,
                    "declined",
                    "Request closed and no trade opened | outgoing turn complete"
                )

                return "declined"
            end

            T5.declineSignalAt = 0
            T5.declineSignalUid = nil
        end

        if not t5PendingVisible() then
            t5Row(
                target,
                "requesting",
                "Pending request closed | waiting for possible trade window..."
            )

            if t515WaitForTradeOpen(
                target,
                3.0,
                "Pending request closed"
            ) then
                return "trade-open"
            end

            local allowed, state = t516DeclineAllowed(
                target,
                "pending disappeared after trade-open grace"
            )

            if state == "trade-open" then
                T5.accepted = true

                t5Row(
                    target,
                    "accepted",
                    "Trade window opened at final decline check"
                )

                return "trade-open"
            end

            if not allowed then
                -- MM2 recreated the pending panel; remain on the same request.
                t5Row(
                    target,
                    "requesting",
                    "Pending request reappeared | continuing same target"
                )

                task.wait(0.10)
                continue
            end

            T5.declined += 1

            t5Row(
                target,
                "declined",
                "Pending request truly closed and no trade opened"
            )

            return "declined"
        end

        local left = math.max(
            0,
            10 - (os.clock() - responseStarted)
        )

        t5Row(
            target,
            "requesting",
            string.format(
                "Pending confirmed | waiting for response | %.1fs",
                left
            )
        )

        t5SetStatus(
            string.format(
                "waiting on %s | %.1fs",
                target.Name,
                left
            )
        )

        task.wait(0.12)
    end

    T5.ignored += 1

    t5Row(
        target,
        "ignored",
        "Confirmed pending request | no response for 10s | cancelling"
    )

    local cancelled = t5CancelPending(
        "10s no response after MM2 trade-panel request"
    )

    t5Row(
        target,
        "ignored",
        cancelled
            and "Processed | real pending request ignored 10s | cancelled"
            or "Processed | real pending request ignored 10s | cancel attempted"
    )

    return "ignored"
end


local TestLoop = {
    confirmed = {},
    confirmLabel = {},
    lastResult = {},
}

task.spawn(function()
    print("[MM2 T5.19] START - live whitelist queue with join monitoring")

    -- Let T4.4 finish its initial scan before request rotation begins.
    task.wait(0.75)

    local idleAnnounced = false
    local scannerWaitAnnounced = false
    local orphanPendingSince = nil

    while not T5.stopped do
        if t5Trade() then
            T5.accepted = true
            t5SetStatus("trade already open — T5 paused")
            break
        end

        -- MM2 has one outgoing pending-request channel. Never start a new
        -- target while that channel is still occupied.
        if t5PendingVisible() then
            if not orphanPendingSince then
                orphanPendingSince = os.clock()

                print(
                    "[MM2 T5.19] QUEUE BLOCKED BY PENDING",
                    "| owner", tostring(t516PendingOwnerName() or "unknown")
                )
            end

            t5SetStatus(
                "existing pending request still active — queue paused"
            )

            -- This branch should only be reached if no request watcher owns
            -- the pending UI anymore. Clean it up after a conservative delay.
            if os.clock() - orphanPendingSince >= 12 then
                print(
                    "[MM2 T5.19] ORPHAN PENDING CLEANUP",
                    "| cancelling before next target"
                )

                t5CancelPending("orphan pending before next target")
                orphanPendingSince = nil
            end

            task.wait(0.25)
            continue
        else
            orphanPendingSince = nil
        end

        local target = t5NextTarget()

        if not target then
            -- A newly joined WHITELIST player may already be scanned but still
            -- be inside the 15-second MM2 trade-readiness grace period.
            local maturing, remain = t517SoonestMaturingWhitelist()

            if maturing then
                idleAnnounced = false
                scannerWaitAnnounced = false

                t5SetStatus(
                    string.format(
                        "NEW JOIN — %s trade-ready in %.1fs",
                        maturing.Name,
                        remain
                    )
                )

                t5Row(
                    maturing,
                    "whitelist",
                    string.format(
                        "New player loaded into whitelist | waiting %.1fs before outgoing request\n%s",
                        remain,
                        t5InventoryDetail(maturing)
                    )
                )

                task.wait(0.25)
                continue
            end

            -- T4 may currently be resolving a player who just joined.
            if t5PendingScannerWork() then
                if not scannerWaitAnnounced then
                    print(
                        "[MM2 T5.19] WAITING",
                        "| live scanner is resolving joined player inventory"
                    )
                    scannerWaitAnnounced = true
                end

                idleAnnounced = false

                t5SetStatus(
                    "waiting for live scanner to resolve joined players..."
                )

                task.wait(0.35)
                continue
            end

            scannerWaitAnnounced = false

            -- IMPORTANT: an empty queue is no longer terminal.
            -- Stay alive so T4's PlayerAdded scanner can feed new whitelist
            -- entries into t5NextTarget() later.
            if not idleAnnounced then
                print(
                    "[MM2 T5.19] LIVE QUEUE IDLE",
                    "| no unprocessed whitelist targets",
                    "| watching for new players",
                    "| sent", T5.sent,
                    "| ignored", T5.ignored,
                    "| declined", T5.declined,
                    "| left", T5.left,
                    "| failed", T5.failed
                )

                idleAnnounced = true
            end

            t5SetStatus(
                string.format(
                    "IDLE — watching new joins | sent %d | ignored %d | declined %d | left %d",
                    T5.sent,
                    T5.ignored,
                    T5.declined,
                    T5.left
                )
            )

            task.wait(0.40)
            continue
        end

        -- A new/unprocessed whitelist target appeared. Wake the queue.
        if idleAnnounced or scannerWaitAnnounced then
            print(
                "[MM2 T5.19] LIVE QUEUE WAKE",
                "| target", target.Name,
                "| uid", target.UserId
            )
        end

        idleAnnounced = false
        scannerWaitAnnounced = false

        local result = t5SendAndWatch(target)

        -- HARD INVARIANT:
        -- Never finalize this player or advance the queue while MM2 still
        -- shows a pending outgoing request. Resume watching the same request
        -- instead of sending anything to a new target.
        if result ~= "trade-open" and t5PendingVisible() then
            print(
                "[MM2 T5.19] RESULT HELD",
                target.Name,
                "| watcher returned", tostring(result),
                "| pending still visible",
                "| owner", tostring(t516PendingOwnerName() or "unknown")
            )

            result = t516ResumeVisiblePending(target, 10)
        end

        -- Final race guard: an accepted trade always outranks any request
        -- close/decline classification.
        if result ~= "trade-open" and t5Trade() then
            print(
                "[MM2 T5.19] RESULT OVERRIDE",
                target.Name,
                "|", tostring(result),
                "-> trade-open"
            )

            result = "trade-open"
            T5.accepted = true

            t5Row(
                target,
                "accepted",
                "Trade window open | overriding prior request-close state"
            )
        end

        if result == "trade-open" then
            t5SetStatus(
                "TRADE TEST — "
                .. target.Name
                .. " | waiting for T6/T7 confirmation"
            )

            print(
                "[MM2 T5.19] REQUEST ACCEPTED",
                target.Name,
                "| pausing queue until this trade test ends"
            )

            -- Keep this exact player as the active partner while T6/T7 run.
            T5.active = target

            while t5Trade() do
                if not target.Parent
                    or Players:GetPlayerByUserId(target.UserId) ~= target
                then
                    break
                end

                task.wait(0.12)
            end

            local confirmed = TestLoop.confirmed[target.UserId] == true
            local confirmLabel =
                TestLoop.confirmLabel[target.UserId]
                or "TEST CONFIRMED"
            local finalResult = confirmed and "test-confirmed" or "trade-closed"

            TestLoop.lastResult[target.UserId] = finalResult
            t5MarkProcessed(target, finalResult)

            if confirmed then
                guiSetPlayer(
                    target,
                    "accepted",
                    confirmLabel
                    .. " | test trade stopped | moving to next player\n"
                    .. t5InventoryDetail(target),
                    Live.order[tostring(target.UserId)] or 0
                )

                print(
                    "[MM2 T5.19] TEST TURN COMPLETE",
                    target.Name,
                    "|", confirmLabel,
                    "| moving to next whitelist player"
                )
            else
                guiSetPlayer(
                    target,
                    "processed",
                    "Trade closed before current test confirmation | processed for this test run\n"
                    .. t5InventoryDetail(target),
                    Live.order[tostring(target.UserId)] or 0
                )

                print(
                    "[MM2 T5.19] TEST TURN CLOSED",
                    target.Name,
                    "| no T7 confirmation"
                )
            end

            T5.active = nil
            T5.accepted = false

            -- Give MM2 time to fully remove TradeGUI before requesting next.
            local closeDeadline = os.clock() + 2.0
            while t5Trade() and os.clock() < closeDeadline do
                task.wait(0.08)
            end

            task.wait(0.75)
            continue
        end

        t5MarkProcessed(target, result)

        if result == "ignored" then
            t5Row(
                target,
                "ignored",
                "Processed | ignored after 10s | no more outgoing requests this server"
            )
        elseif result == "declined" then
            t5Row(
                target,
                "declined",
                "Processed | declined/closed | no more outgoing requests this server"
            )
        elseif result == "left" then
            t5Row(
                target,
                "left",
                "Processed | player left server"
            )
        elseif result == "send-failed" then
            t5Row(
                target,
                "sendfailed",
                "Processed | request send failed"
            )
        elseif result == "self-blocked" then
            warn(
                "[MM2 T5.19] SELF BLOCKED DURING ROTATION",
                target and target.Name or "nil"
            )
        else
            t5Row(
                target,
                "processed",
                "Processed | result: " .. tostring(result)
            )
        end

        print(
            "[MM2 T5.19] TURN COMPLETE",
            target.Name,
            "| result", result
        )

        T5.active = nil

        -- Brief separation between request turns.
        task.wait(0.65)
    end
end)


-- ============================================================================
-- T6.1 TRADE WINDOW READ + ONE HIGHEST-ITEM OPENING OFFER
-- NO ACCEPT / NO BALANCING / NO PROFIT LOGIC IN THIS TEST.
-- ============================================================================

local TradeFolder_T6 = RS:FindFirstChild("Trade")
local OfferItem_T6 = TradeFolder_T6 and TradeFolder_T6:FindFirstChild("OfferItem")

local T6 = {
    started = false,
    finished = false,
    result = nil,
    partner = nil,
    offered = nil,
}

local function t6Norm(x)
    return tostring(x or "")
        :gsub("’", "'")
        :lower()
        :gsub("[^%w]", "")
end

local function t6Trade()
    return t5Trade()
end

local function t6PartnerName(t)
    local name = t5Partner(t)
    if name and name ~= "" then
        return name
    end
    return "unknown"
end

local function t6SlotName(slot)
    if not slot or not slot.Visible then
        return nil
    end

    local itemName = slot:FindFirstChild("ItemName")
    local label = itemName and itemName:FindFirstChild("Label")

    if label
        and (
            label:IsA("TextLabel")
            or label:IsA("TextButton")
        )
    then
        local s = tostring(label.Text or "")
        if s ~= "" then
            return s
        end
    end

    -- Fallback for UI layout changes: select a useful visible text label.
    for _, d in ipairs(slot:GetDescendants()) do
        if (
            d:IsA("TextLabel")
            or d:IsA("TextButton")
        )
            and d.Visible
        then
            local s = tostring(d.Text or "")
                :gsub("^%s+", "")
                :gsub("%s+$", "")

            if s ~= ""
                and not s:match("^[xX]%s*%d+$")
            then
                return s
            end
        end
    end

    return nil
end


local function t62Visible(o)
    if not o then
        return false
    end

    local ok, result = pcall(function()
        local c = o

        while c do
            if c:IsA("GuiObject") and not c.Visible then
                return false
            end

            if c:IsA("ScreenGui") and not c.Enabled then
                return false
            end

            c = c.Parent
        end

        return true
    end)

    return ok and result
end

local function t62SlotInternalId(slot)
    if not slot then
        return nil
    end

    for _, attr in ipairs({
        "ItemId",
        "ItemID",
        "ID",
        "WeaponId",
        "WeaponID",
    }) do
        local ok, v = pcall(function()
            return slot:GetAttribute(attr)
        end)

        if ok and v ~= nil and tostring(v) ~= "" then
            return tostring(v)
        end
    end

    for _, name in ipairs({
        "ItemId",
        "ItemID",
        "ID",
        "WeaponId",
        "WeaponID",
    }) do
        local v = slot:FindFirstChild(name, true)

        if v and (
            v:IsA("StringValue")
            or v:IsA("IntValue")
            or v:IsA("NumberValue")
        ) then
            return tostring(v.Value)
        end
    end

    return nil
end

local function t62SlotIsChroma(slot)
    if not slot then
        return false
    end

    local tags = slot:FindFirstChild("Tags")

    if not tags then
        return false
    end

    local chroma = tags:FindFirstChild("Chroma")

    if not chroma then
        return false
    end

    return t62Visible(chroma)
end

local function t62StripChromaPrefix(name)
    local s = tostring(name or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    s = s:gsub("^[Cc][Hh][Rr][Oo][Mm][Aa]%s+", "")
    return s
end

local function t6ReadSide(t, sideName)
    local side = t and t:FindFirstChild(sideName)
    local container = side and side:FindFirstChild("Container")

    local out = {
        slots = 0,
        names = {},
        entries = {},
    }

    if not container then
        return out
    end

    for i = 1, 4 do
        local slot = container:FindFirstChild("NewItem" .. i)

        if slot and slot.Visible then
            local name = t6SlotName(slot)

            if name and name ~= "" then
                local isChroma = t62SlotIsChroma(slot)
                local internalId = t62SlotInternalId(slot)

                out.slots += 1

                out.entries[#out.entries + 1] = {
                    slot = i,
                    name = name,
                    isChroma = isChroma,
                    internalId = internalId,
                }

                out.names[#out.names + 1] =
                    (isChroma and "Chroma " or "")
                    .. name
            end
        end
    end

    return out
end

local function t6SideText(side)
    if not side or side.slots == 0 then
        return "empty"
    end

    return table.concat(side.names, ", ")
end

local function t6HighestOwn()
    local own = scanOwn()

    if not own or type(own.items) ~= "table" then
        return nil, own
    end

    local best = nil

    for _, it in ipairs(own.items) do
        local qty = tonumber(it.qty) or 0
        local value = tonumber(it.value) or 0

        if qty > 0
            and it.id
            and tostring(it.id) ~= ""
        then
            if not best
                or value > (tonumber(best.value) or 0)
                or (
                    value == (tonumber(best.value) or 0)
                    and tostring(it.id) < tostring(best.id)
                )
            then
                best = it
            end
        end
    end

    return best, own
end

local function t6YourOfferContains(t, wanted)
    local side = t6ReadSide(t, "YourOffer")

    local wantedId = t6Norm(wanted and wanted.id)
    local wantedName = tostring(wanted and wanted.name or "")
    local wantedNorm = t6Norm(wantedName)
    local wantedBaseNorm = t6Norm(t62StripChromaPrefix(wantedName))

    local wantedIsChroma =
        wantedName:lower():match("^%s*chroma%s+") ~= nil
        or wantedId:find("chroma", 1, true) ~= nil

    for _, entry in ipairs(side.entries or {}) do
        local entryId = t6Norm(entry.internalId)
        local entryName = t6Norm(entry.name)

        -- Strongest proof: MM2 exposed the exact internal item ID.
        if wantedId ~= ""
            and entryId ~= ""
            and entryId == wantedId
        then
            return true, side, "internal-id"
        end

        -- Chroma items are displayed by MM2 as the base weapon name plus a
        -- separate Tags.Chroma marker. Example:
        --   expected: "Chroma Watergun"
        --   UI text:  "Watergun"
        --   tag:      Chroma = visible
        if wantedIsChroma then
            if entry.isChroma
                and entryName == wantedBaseNorm
            then
                return true, side, "base-name+chroma-tag"
            end
        else
            if not entry.isChroma
                and entryName == wantedNorm
            then
                return true, side, "display-name"
            end
        end
    end

    return false, side, "no-match"
end

local function t6TargetPlayer(partnerName)
    if T5 and T5.active and T5.active.Parent == Players then
        return T5.active
    end

    local key = t6Norm(partnerName)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP
            and (
                t6Norm(p.Name) == key
                or t6Norm(p.DisplayName) == key
            )
        then
            return p
        end
    end

    return nil
end

local function t6Gui(target, line)
    guiSetStatus("T6 — " .. tostring(line or ""))

    if target and target.Parent then
        local base = t5InventoryDetail(target)

        guiSetPlayer(
            target,
            "accepted",
            tostring(line or "") .. "\n" .. base,
            Live.order[tostring(target.UserId)] or 0
        )
    end
end

local function t6Run()
    if T6.started then
        return
    end

    T6.started = true

    local t = t6Trade()
    if not t then
        T6.result = "trade-missing"
        return
    end

    local partner = t6PartnerName(t)
    local target = t6TargetPlayer(partner)

    T6.partner = partner

    local oursBefore = t6ReadSide(t, "YourOffer")
    local theirsBefore = t6ReadSide(t, "TheirOffer")

    print(
        "[MM2 T6.9] TRADE OPEN",
        "| partner", partner,
        "| ours", t6SideText(oursBefore),
        "| theirs", t6SideText(theirsBefore)
    )

    t6Gui(
        target,
        string.format(
            "Trade open with %s | ours: %s | theirs: %s",
            partner,
            t6SideText(oursBefore),
            t6SideText(theirsBefore)
        )
    )

    -- T6 assumes a fresh trade. If our side is unexpectedly non-empty,
    -- do NOT clear it in this isolated test; stop instead.
    if oursBefore.slots > 0 then
        T6.result = "our-offer-not-empty"

        warn(
            "[MM2 T6.9] STOP",
            "| YOUR OFFER was already non-empty; test will not modify it"
        )

        t6Gui(
            target,
            "STOP — YOUR OFFER was already non-empty; no item changed"
        )

        T6.finished = true
        return
    end

    local highest, own = t6HighestOwn()

    if not highest then
        T6.result = "no-eligible-own-item"

        warn(
            "[MM2 T6.9] STOP",
            "| no eligible Ancient/Godly/Chroma Godly found in own inventory"
        )

        t6Gui(
            target,
            "STOP — no eligible own item available"
        )

        T6.finished = true
        return
    end

    T6.offered = highest

    print(
        "[MM2 T6.9] HIGHEST OWN",
        "| id", tostring(highest.id),
        "| name", tostring(highest.name),
        "| value", tostring(highest.value),
        "| qty", tostring(highest.qty)
    )

    t6Gui(
        target,
        string.format(
            "Opening offer: %s (%s) | placing exactly 1 item",
            tostring(highest.name),
            tostring(highest.value)
        )
    )

    if not OfferItem_T6
        or not OfferItem_T6:IsA("RemoteEvent")
    then
        T6.result = "offer-remote-missing"

        warn(
            "[MM2 T6.9] OFFER FAILED",
            "| ReplicatedStorage.Trade.OfferItem missing/wrong class"
        )

        t6Gui(
            target,
            "OFFER FAILED — OfferItem remote unavailable"
        )

        T6.finished = true
        return
    end

    local ok, err = pcall(function()
        OfferItem_T6:FireServer(highest.id, "Weapons")
    end)

    print(
        "[MM2 T6.9] OFFER FIRE",
        "| ok", tostring(ok),
        "| item", tostring(highest.name),
        "| id", tostring(highest.id),
        "| error", tostring(err)
    )

    if not ok then
        T6.result = "offer-fire-error"

        t6Gui(
            target,
            "OFFER FAILED — remote call errored"
        )

        T6.finished = true
        return
    end

    -- Verify UI instead of trusting the remote call.
    local deadline = os.clock() + 3.0
    local lastSide = nil

    while os.clock() < deadline do
        local now = t6Trade()

        if not now then
            T6.result = "trade-closed-during-verify"

            warn(
                "[MM2 T6.9] VERIFY FAILED",
                "| trade closed before offer appeared"
            )

            T6.finished = true
            return
        end

        local found, side, proof = t6YourOfferContains(now, highest)
        lastSide = side

        if found then
            T6.result = "success"
            T6.finished = true

            local theirNow = t6ReadSide(now, "TheirOffer")

            print(
                "[MM2 T6.9] SUCCESS",
                "| opening item verified in YOUR OFFER",
                "| proof", tostring(proof),
                "| item", tostring(highest.name),
                "| value", tostring(highest.value),
                "| ours", t6SideText(side),
                "| theirs", t6SideText(theirNow),
                "| ACCEPT NOT PRESSED"
            )

            t6Gui(
                target,
                string.format(
                    "T6 SUCCESS — offered %s (%s) | verified in YOUR OFFER | ACCEPT disabled for this test",
                    tostring(highest.name),
                    tostring(highest.value)
                )
            )

            return
        end

        task.wait(0.10)
    end

    T6.result = "offer-not-visible"
    T6.finished = true

    warn(
        "[MM2 T6.9] VERIFY FAILED",
        "| expected", tostring(highest.name),
        "| YOUR OFFER", t6SideText(lastSide)
    )

    t6Gui(
        target,
        string.format(
            "OFFER VERIFY FAILED — expected %s | saw: %s",
            tostring(highest.name),
            t6SideText(lastSide)
        )
    )
end

-- Independent observer: the proven T5.12 module stops when a trade opens.
-- T6 starts only after that real trade GUI is visible.
task.spawn(function()
    print(
        "[MM2 T6.9] ARMED",
        "- reusable per-trade opening-offer test"
    )

    local seenAt = nil
    local hadTrade = false

    while true do
        local t = t6Trade()

        if t then
            hadTrade = true

            if not seenAt then
                seenAt = os.clock()
            end

            if not T6.started
                and os.clock() - seenAt >= 0.30
            then
                t6Run()
            end
        else
            seenAt = nil

            if hadTrade then
                -- Reset only after the previous trade GUI is fully gone.
                T6.started = false
                T6.finished = false
                T6.result = nil
                T6.partner = nil
                T6.offered = nil
                hadTrade = false

                print(
                    "[MM2 T6.9] RESET",
                    "- ready for next player's trade"
                )
            end
        end

        task.wait(0.08)
    end
end)


-- ============================================================================
-- T7.1 LIVE THEIR-OFFER VALUATION
--
-- TEST SCOPE ONLY:
--   * starts after T6 successfully places/verifies our one opening item
--   * continuously reads THEIR OFFER
--   * values only Ancient / Godly / Chroma Godly items
--   * resolves against the already-scanned inventory for the exact partner
--   * unresolved slots contribute 0 and are shown explicitly
--   * shows our value / their eligible value / live profit / +15 PASS or FAIL
--   * NO REBALANCING
--   * NO ACCEPT
--   * NO DECLINE
-- ============================================================================

local T7 = {
    started = false,
    finished = false,
    lastSignature = nil,
    baselineSignature = nil,
    sawChange = false,
}

local function t7SlotQty(slot)
    if not slot then
        return 1
    end

    local box = slot:FindFirstChild("Container")
    local amount = box and box:FindFirstChild("Amount")

    if amount and (
        amount:IsA("TextLabel")
        or amount:IsA("TextButton")
    ) then
        local n = tonumber(
            tostring(amount.Text or ""):match("^[xX]%s*(%d+)$")
        )

        if n and n >= 1 then
            return math.floor(n)
        end
    end

    return 1
end

local function t7ReadLiveSide(t, sideName)
    local side = t and t:FindFirstChild(sideName)
    local container = side and side:FindFirstChild("Container")

    local out = {
        slots = 0,
        entries = {},
    }

    if not container then
        return out
    end

    for i = 1, 4 do
        local slot = container:FindFirstChild("NewItem" .. i)

        if slot and slot.Visible then
            local shown = t6SlotName(slot)

            if shown and shown ~= "" then
                out.slots += 1

                out.entries[#out.entries + 1] = {
                    index = i,
                    node = slot,
                    shown = shown,
                    isChroma = t62SlotIsChroma(slot),
                    internalId = t62SlotInternalId(slot),
                    qty = t7SlotQty(slot),
                }
            end
        end
    end

    return out
end

local function t7FullShownName(entry)
    local shown = tostring(entry and entry.shown or "")
    local q = shown:lower()

    if entry and entry.isChroma
        and not q:match("^%s*chroma%s+")
    then
        return "Chroma " .. shown
    end

    return shown
end

local function t7PartnerInventory(target)
    if not target then
        return nil
    end

    local rec = Live.byUserId[tostring(target.UserId)]

    if rec and rec.state == "whitelist" and rec.inv then
        return rec.inv
    end

    return nil
end

local function t7ResolveAgainstPartnerInventory(entry, partnerInv)
    if not entry or not partnerInv or type(partnerInv.items) ~= "table" then
        return nil, "partner inventory unavailable"
    end

    local liveId = t6Norm(entry.internalId)
    local liveName = t6Norm(t7FullShownName(entry))

    local hits = {}

    for _, it in ipairs(partnerInv.items) do
        local itemId = t6Norm(it.id)
        local itemName = t6Norm(it.name)

        local idMatch =
            liveId ~= ""
            and itemId ~= ""
            and liveId == itemId

        local nameMatch =
            liveName ~= ""
            and itemName == liveName

        if idMatch or nameMatch then
            hits[#hits + 1] = it
        end
    end

    if #hits == 0 then
        return nil, "not found in scanned eligible inventory"
    end

    -- If multiple copies/aliases match, only accept the identity when they
    -- agree on value and canonical name. Never guess between differing values.
    local first = hits[1]

    for i = 2, #hits do
        local x = hits[i]

        if tonumber(x.value) ~= tonumber(first.value)
            or t6Norm(x.name) ~= t6Norm(first.name)
        then
            return nil, "ambiguous scanned identity"
        end
    end

    return {
        id = first.id,
        name = first.name,
        value = tonumber(first.value) or 0,
        page = first.page,
        qty = math.max(1, tonumber(entry.qty) or 1),
        shown = t7FullShownName(entry),
    }, "partner-inventory"
end

local function t7EvaluateTheirOffer(t, target)
    local side = t7ReadLiveSide(t, "TheirOffer")
    local partnerInv = t7PartnerInventory(target)

    local out = {
        total = 0,
        eligibleCopies = 0,
        resolved = {},
        unresolved = {},
        slots = side.slots,
    }

    for _, entry in ipairs(side.entries) do
        local item, why = t7ResolveAgainstPartnerInventory(
            entry,
            partnerInv
        )

        if item then
            local qty = math.max(1, tonumber(item.qty) or 1)

            out.total += item.value * qty
            out.eligibleCopies += qty

            out.resolved[#out.resolved + 1] = {
                name = item.name,
                value = item.value,
                qty = qty,
                proof = why,
            }
        else
            out.unresolved[#out.unresolved + 1] = {
                name = t7FullShownName(entry),
                qty = math.max(1, tonumber(entry.qty) or 1),
                reason = why,
            }
        end
    end

    return out
end

local function t7ResolvedText(ev)
    if not ev or #ev.resolved == 0 then
        return "none"
    end

    local parts = {}

    for _, it in ipairs(ev.resolved) do
        local suffix = it.qty > 1 and (" x" .. it.qty) or ""

        parts[#parts + 1] = string.format(
            "%s%s (%s)",
            tostring(it.name),
            suffix,
            tostring(it.value)
        )
    end

    return table.concat(parts, ", ")
end

local function t7UnresolvedText(ev)
    if not ev or #ev.unresolved == 0 then
        return "none"
    end

    local parts = {}

    for _, it in ipairs(ev.unresolved) do
        local suffix = it.qty > 1 and (" x" .. it.qty) or ""

        parts[#parts + 1] =
            tostring(it.name)
            .. suffix
            .. " [UNRESOLVED]"
    end

    return table.concat(parts, ", ")
end

local function t7Signature(ev, ourValue)
    local parts = {
        tostring(ourValue or 0),
        tostring(ev and ev.total or 0),
        tostring(ev and ev.eligibleCopies or 0),
    }

    for _, it in ipairs(ev and ev.resolved or {}) do
        parts[#parts + 1] =
            t6Norm(it.name)
            .. ":"
            .. tostring(it.value)
            .. "x"
            .. tostring(it.qty)
    end

    for _, it in ipairs(ev and ev.unresolved or {}) do
        parts[#parts + 1] =
            "?"
            .. t6Norm(it.name)
            .. "x"
            .. tostring(it.qty)
    end

    return table.concat(parts, "|")
end

local function t7Gui(target, ourValue, theirEval)
    local theirValue = tonumber(theirEval.total) or 0
    local profit = theirValue - ourValue
    local passes = profit >= 15

    local status = string.format(
        "T7 — OUR %s | THEIR %s | PROFIT %+g | +15 %s",
        tostring(ourValue),
        tostring(theirValue),
        profit,
        passes and "PASS" or "FAIL"
    )

    guiSetStatus(status)

    if target and target.Parent then
        local detail = string.format(
            "LIVE TRADE VALUE\nOur offer: %s\nTheir eligible: %s\nProfit: %+g | +15 floor: %s\nTheir items: %s\nUnresolved: %s\nACCEPT DISABLED FOR T7 TEST",
            tostring(ourValue),
            tostring(theirValue),
            profit,
            passes and "PASS" or "FAIL",
            t7ResolvedText(theirEval),
            t7UnresolvedText(theirEval)
        )

        guiSetPlayer(
            target,
            "accepted",
            detail,
            Live.order[tostring(target.UserId)] or 0
        )
    end
end


local DeclineTrade_T72 =
    TradeFolder_T6
    and TradeFolder_T6:FindFirstChild("DeclineTrade")

local function t72StopConfirmedTrade(t, target)
    print(
        "[MM2 T7.3] STOPPING CONFIRMED TEST TRADE",
        target and target.Name or "?"
    )

    guiSetStatus(
        "T7 CONFIRMED — stopping test trade, then moving to next player"
    )

    local fired = false

    if DeclineTrade_T72
        and DeclineTrade_T72:IsA("RemoteEvent")
    then
        fired = pcall(function()
            DeclineTrade_T72:FireServer()
        end)
    end

    -- UI fallback if the remote does not close the trade quickly.
    local deadline = os.clock() + 1.2

    while t6Trade()
        and os.clock() < deadline
    do
        task.wait(0.08)
    end

    if t6Trade() then
        local live = t6Trade()
        local actions = live and live:FindFirstChild("Actions")
        local decline = actions and actions:FindFirstChild("Decline")
        local button = decline and decline:FindFirstChild("ActionButton")

        if button then
            pcall(function()
                t5ClickButton(button)
            end)
        end
    end

    local closeDeadline = os.clock() + 2.5

    while t6Trade()
        and os.clock() < closeDeadline
    do
        task.wait(0.08)
    end

    print(
        "[MM2 T7.3] TEST TRADE STOP RESULT",
        "| remote", tostring(fired),
        "| closed", tostring(t6Trade() == nil)
    )
end

local function t7Run()
    if T7.started then
        return
    end

    T7.started = true
    T7.finished = false
    T7.lastSignature = nil
    T7.baselineSignature = nil
    T7.sawChange = false

    local target = T5 and T5.active or nil
    local partnerName = T6 and T6.partner or nil

    if not target or not target.Parent then
        target = t6TargetPlayer(partnerName)
    end

    if not target then
        warn(
            "[MM2 T7.3] STOP",
            "| could not resolve current trade partner"
        )

        T7.finished = true
        return
    end

    local ourValue =
        tonumber(
            T6
            and T6.offered
            and T6.offered.value
        )
        or 0

    print(
        "[MM2 T7.3] START",
        "| partner", target.Name,
        "| our opening value", ourValue,
        "| waiting for THEIR OFFER to change once"
    )

    while true do
        local t = t6Trade()

        if not t then
            print(
                "[MM2 T7.3] STOP",
                "| trade window closed before/after confirmation"
            )

            T7.finished = true
            return
        end

        local ev = t7EvaluateTheirOffer(t, target)
        local sig = t7Signature(ev, ourValue)

        if not T7.baselineSignature then
            T7.baselineSignature = sig
            T7.lastSignature = sig

            local profit = ev.total - ourValue

            print(
                "[MM2 T7.3] BASELINE",
                "| partner", target.Name,
                "| ours", ourValue,
                "| theirs", ev.total,
                "| profit", profit,
                "| resolved", t7ResolvedText(ev),
                "| unresolved", t7UnresolvedText(ev)
            )

            t7Gui(target, ourValue, ev)
        elseif sig ~= T7.lastSignature then
            T7.sawChange = true
            T7.lastSignature = sig

            local profit = ev.total - ourValue
            local passes = profit >= 15

            print(
                "[MM2 T7.3] LIVE CHANGE",
                "| partner", target.Name,
                "| ours", ourValue,
                "| theirs", ev.total,
                "| profit", profit,
                "| +15", passes and "PASS" or "FAIL",
                "| resolved", t7ResolvedText(ev),
                "| unresolved", t7UnresolvedText(ev)
            )

            t7Gui(target, ourValue, ev)

            -- T7 is already proven. In T8 builds it remains a read-only
            -- live valuation layer and does not stop the trade itself.
            if #ev.unresolved == 0 then
                print(
                    "[MM2 T7.3] LIVE CHANGE RESOLVED",
                    target.Name,
                    "| their eligible value", ev.total,
                    "| T8 planner may act"
                )
            end
        end

        task.wait(0.12)
    end
end

task.spawn(function()
    print(
        "[MM2 T7.3] ARMED",
        "- live valuation feed for T8 planner"
    )

    while true do
        if T6
            and T6.finished
            and T6.result == "success"
            and t6Trade()
            and not T7.started
        then
            task.wait(0.15)
            t7Run()
        end

        if not t6Trade()
            and T7.started
        then
            T7.started = false
            T7.finished = false
            T7.lastSignature = nil
            T7.baselineSignature = nil
            T7.sawChange = false

            print(
                "[MM2 T7.3] RESET",
                "- ready for next player's trade valuation test"
            )
        end

        task.wait(0.10)
    end
end)


-- ============================================================================
-- T8.1 +15 PROFIT REBALANCE PLANNER
--
-- TEST SCOPE:
--   * wait for a fully-resolved eligible THEIR OFFER
--   * enumerate our eligible inventory combinations using 1..4 slots
--   * HARD RULE: theirValue - ourValue >= 15
--   * preserve the established growth-first initial-plan policy
--   * replace T6's opening item with the selected safe plan
--   * lock THEIR OFFER during apply; recompute if it changes
--   * verify the exact rendered offer against our scanned inventory
--   * once verified, stop the test trade and move to the next whitelist player
--   * NO ACCEPT
--   * NO SWEETENING YET
-- ============================================================================

local T8 = {
    started = false,
    finished = false,
    result = nil,
    plan = nil,
}

local function t8TheirSig(ev)
    local parts = {
        tostring(ev and ev.total or 0),
        tostring(ev and ev.eligibleCopies or 0),
    }

    for _, it in ipairs(ev and ev.resolved or {}) do
        parts[#parts + 1] =
            t6Norm(it.name)
            .. ":"
            .. tostring(it.value)
            .. "x"
            .. tostring(it.qty)
    end

    for _, it in ipairs(ev and ev.unresolved or {}) do
        parts[#parts + 1] =
            "?"
            .. t6Norm(it.name)
            .. "x"
            .. tostring(it.qty)
    end

    return table.concat(parts, "|")
end

local function t8AggregatePicks(list)
    local map = {}
    local order = {}

    for _, u in ipairs(list) do
        local k = tostring(u.id)

        if not map[k] then
            map[k] = {
                id = u.id,
                name = u.name,
                value = tonumber(u.value) or 0,
                type = u.type,
                qty = 0,
            }
            order[#order + 1] = k
        end

        map[k].qty += 1
    end

    local out = {}

    for _, k in ipairs(order) do
        out[#out + 1] = map[k]
    end

    return out
end

local function t8MakeUnits(inv)
    local units = {}

    for _, it in ipairs(inv and inv.items or {}) do
        local qty = math.min(
            4,
            math.max(0, tonumber(it.qty) or 0)
        )
        local value = tonumber(it.value) or 0

        if qty > 0
            and value > 0
            and it.id
            and tostring(it.id) ~= ""
        then
            for _ = 1, qty do
                units[#units + 1] = {
                    id = it.id,
                    name = it.name,
                    value = value,
                    type = it.type,
                }
            end
        end
    end

    return units
end

local function t8BuildPlans(inv, theirValue, theirItems)
    theirValue = tonumber(theirValue) or 0
    local cap = theirValue - 15

    if cap <= 0 then
        return {}, cap
    end

    local capC = math.floor(cap * 100 + 0.5)
    local units = t8MakeUnits(inv)

    local dp = {
        [0] = {[0] = {}},
        [1] = {},
        [2] = {},
        [3] = {},
        [4] = {},
    }

    for _, u in ipairs(units) do
        local vc = math.floor((tonumber(u.value) or 0) * 100 + 0.5)

        if vc > 0 then
            for slots = 4, 1, -1 do
                local additions = {}

                for sum, list in pairs(dp[slots - 1]) do
                    local ns = sum + vc

                    if ns <= capC
                        and not dp[slots][ns]
                    then
                        local nl = {}

                        for i = 1, #list do
                            nl[i] = list[i]
                        end

                        nl[#nl + 1] = u
                        additions[ns] = nl
                    end
                end

                for ns, nl in pairs(additions) do
                    if not dp[slots][ns] then
                        dp[slots][ns] = nl
                    end
                end
            end
        end
    end

    local plans = {}

    for slots = 1, 4 do
        for cents, list in pairs(dp[slots]) do
            local total = cents / 100
            local profit = theirValue - total

            if total > 0 and profit >= 15 - 0.0001 then
                plans[#plans + 1] = {
                    picks = t8AggregatePicks(list),
                    total = total,
                    units = slots,
                    growth = (tonumber(theirItems) or 0) - slots,
                    profit = profit,
                }
            end
        end
    end

    table.sort(plans, function(a, b)
        if a.total ~= b.total then
            return a.total < b.total
        end

        return a.units < b.units
    end)

    return plans, cap
end

local function t8InitialPlan(plans)
    if #plans == 0 then
        return nil
    end

    local bestGrowth = -999

    for _, p in ipairs(plans) do
        if p.growth > bestGrowth then
            bestGrowth = p.growth
        end
    end

    local positiveGrowth = bestGrowth > 0
    local best = nil

    for _, p in ipairs(plans) do
        if p.growth == bestGrowth then
            if not best then
                best = p
            elseif positiveGrowth then
                if p.total > best.total
                    or (
                        p.total == best.total
                        and p.units < best.units
                    )
                then
                    best = p
                end
            else
                if p.total < best.total
                    or (
                        p.total == best.total
                        and p.units < best.units
                    )
                then
                    best = p
                end
            end
        end
    end

    return best
end

local function t8PlanText(plan)
    if not plan then
        return "none"
    end

    local parts = {}

    for _, it in ipairs(plan.picks or {}) do
        local qty = tonumber(it.qty) or 1
        local suffix = qty > 1 and (" x" .. tostring(qty)) or ""

        parts[#parts + 1] =
            tostring(it.name)
            .. suffix
            .. " ("
            .. tostring(it.value)
            .. ")"
    end

    return table.concat(parts, ", ")
end

local function t8SafeClick(button)
    if not button or not t5Visible(button) then
        return false
    end

    local attempted = false

    if firesignal then
        local ok1 = pcall(function()
            firesignal(button.Activated)
        end)

        local ok2 = pcall(function()
            firesignal(button.MouseButton1Click)
        end)

        attempted = ok1 or ok2 or attempted
    end

    local okActivate = pcall(function()
        button:Activate()
    end)

    attempted = okActivate or attempted

    local okPhysical = pcall(function()
        local p = button.AbsolutePosition
        local s = button.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        local x = p.X + s.X / 2 + inset.X
        local y = p.Y + s.Y / 2 + inset.Y

        VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)

    return attempted or okPhysical
end

local function t8RemoveOne(t)
    local side = t and t:FindFirstChild("YourOffer")
    local container = side and side:FindFirstChild("Container")

    if not container then
        return false
    end

    for i = 4, 1, -1 do
        local slot = container:FindFirstChild("NewItem" .. i)
        local box = slot and slot.Visible and slot:FindFirstChild("Container")
        local button = box and box:FindFirstChild("ActionButton")

        if button then
            return t8SafeClick(button)
        end
    end

    return false
end

local function t8ClearOurOffer(expectedTheirSig, target)
    for _ = 1, 8 do
        local t = t6Trade()

        if not t then
            return false, "trade-closed"
        end

        local theirEval = t7EvaluateTheirOffer(t, target)

        if t8TheirSig(theirEval) ~= expectedTheirSig then
            return false, "their-offer-changed"
        end

        local ours = t7ReadLiveSide(t, "YourOffer")

        if ours.slots == 0 then
            return true, "cleared"
        end

        local before = ours.slots

        if not t8RemoveOne(t) then
            return false, "remove-click-failed"
        end

        local deadline = os.clock() + 0.8

        while os.clock() < deadline do
            local now = t6Trade()

            if not now then
                return false, "trade-closed"
            end

            local nowTheir = t7EvaluateTheirOffer(now, target)

            if t8TheirSig(nowTheir) ~= expectedTheirSig then
                return false, "their-offer-changed"
            end

            local nowOurs = t7ReadLiveSide(now, "YourOffer")

            if nowOurs.slots < before then
                break
            end

            task.wait(0.06)
        end

        task.wait(0.08)
    end

    local t = t6Trade()
    local ours = t and t7ReadLiveSide(t, "YourOffer")

    return ours and ours.slots == 0 or false, "clear-timeout"
end

local function t8ResolveOurEntry(entry, inv)
    if not entry or not inv or type(inv.items) ~= "table" then
        return nil, "inventory-unavailable"
    end

    local liveId = t6Norm(entry.internalId)
    local liveFull = t6Norm(t7FullShownName(entry))
    local hits = {}

    for _, it in ipairs(inv.items) do
        local itemId = t6Norm(it.id)
        local itemName = t6Norm(it.name)

        local idMatch =
            liveId ~= ""
            and itemId ~= ""
            and liveId == itemId

        local nameMatch =
            liveFull ~= ""
            and itemName == liveFull

        if idMatch or nameMatch then
            hits[#hits + 1] = it
        end
    end

    if #hits == 0 then
        return nil, "unresolved"
    end

    local first = hits[1]

    for i = 2, #hits do
        local x = hits[i]

        if t6Norm(x.id) ~= t6Norm(first.id)
            or tonumber(x.value) ~= tonumber(first.value)
        then
            return nil, "ambiguous"
        end
    end

    return first, "resolved"
end

local function t8ReadOurResolved(t, inv)
    local side = t7ReadLiveSide(t, "YourOffer")
    local out = {
        slots = side.slots,
        total = 0,
        counts = {},
        unresolved = {},
    }

    for _, entry in ipairs(side.entries) do
        local item, why = t8ResolveOurEntry(entry, inv)
        local qty = math.max(1, tonumber(entry.qty) or 1)

        if item then
            local key = tostring(item.id)
            out.counts[key] = (out.counts[key] or 0) + qty
            out.total += (tonumber(item.value) or 0) * qty
        else
            out.unresolved[#out.unresolved + 1] =
                t7FullShownName(entry)
                .. " ["
                .. tostring(why)
                .. "]"
        end
    end

    return out
end

local function t8PlanMatches(plan, live)
    if not plan or not live then
        return false
    end

    if #live.unresolved > 0 then
        return false
    end

    if live.slots ~= plan.units then
        return false
    end

    if math.abs((tonumber(live.total) or 0) - plan.total) > 0.001 then
        return false
    end

    local expected = {}

    for _, p in ipairs(plan.picks) do
        expected[tostring(p.id)] =
            (expected[tostring(p.id)] or 0)
            + (tonumber(p.qty) or 1)
    end

    for id, qty in pairs(expected) do
        if (live.counts[id] or 0) ~= qty then
            return false
        end
    end

    for id, qty in pairs(live.counts) do
        if (expected[id] or 0) ~= qty then
            return false
        end
    end

    return true
end

local function t8AddPlan(plan, expectedTheirSig, target)
    for _, it in ipairs(plan.picks) do
        for _ = 1, (tonumber(it.qty) or 1) do
            local t = t6Trade()

            if not t then
                return false, "trade-closed"
            end

            local theirEval = t7EvaluateTheirOffer(t, target)

            if t8TheirSig(theirEval) ~= expectedTheirSig then
                return false, "their-offer-changed"
            end

            local ours = t7ReadLiveSide(t, "YourOffer")

            if ours.slots >= 4 then
                return false, "slot-limit"
            end

            local ok = pcall(function()
                OfferItem_T6:FireServer(it.id, "Weapons")
            end)

            if not ok then
                return false, "offer-fire-error"
            end

            task.wait(0.15)
        end
    end

    return true, "added"
end

local function t8ApplyPlan(plan, target, ownInv, expectedTheirSig)
    local cleared, why = t8ClearOurOffer(
        expectedTheirSig,
        target
    )

    if not cleared then
        return false, why
    end

    local t = t6Trade()

    if not t then
        return false, "trade-closed"
    end

    local theirEval = t7EvaluateTheirOffer(t, target)

    if t8TheirSig(theirEval) ~= expectedTheirSig then
        return false, "their-offer-changed"
    end

    local added, addWhy = t8AddPlan(
        plan,
        expectedTheirSig,
        target
    )

    if not added then
        return false, addWhy
    end

    local deadline = os.clock() + 2.5

    while os.clock() < deadline do
        local now = t6Trade()

        if not now then
            return false, "trade-closed"
        end

        local nowTheir = t7EvaluateTheirOffer(now, target)

        if t8TheirSig(nowTheir) ~= expectedTheirSig then
            return false, "their-offer-changed"
        end

        local liveOurs = t8ReadOurResolved(now, ownInv)

        if t8PlanMatches(plan, liveOurs) then
            return true, liveOurs
        end

        task.wait(0.08)
    end

    return false, "verify-timeout"
end

local DeclineTrade_T81 =
    TradeFolder_T6
    and TradeFolder_T6:FindFirstChild("DeclineTrade")

local function t81StopTrade(target)
    guiSetStatus(
        "T8 CONFIRMED — stopping test trade, then moving to next player"
    )

    local fired = false

    if DeclineTrade_T81
        and DeclineTrade_T81:IsA("RemoteEvent")
    then
        fired = pcall(function()
            DeclineTrade_T81:FireServer()
        end)
    end

    local deadline = os.clock() + 1.2

    while t6Trade() and os.clock() < deadline do
        task.wait(0.08)
    end

    if t6Trade() then
        local live = t6Trade()
        local actions = live and live:FindFirstChild("Actions")
        local decline = actions and actions:FindFirstChild("Decline")
        local button = decline and decline:FindFirstChild("ActionButton")

        if button then
            t8SafeClick(button)
        end
    end

    local closeDeadline = os.clock() + 2.5

    while t6Trade() and os.clock() < closeDeadline do
        task.wait(0.08)
    end

    print(
        "[MM2 T8.1] TEST TRADE STOP",
        target and target.Name or "?",
        "| remote", tostring(fired),
        "| closed", tostring(t6Trade() == nil)
    )
end

local function t8ConfirmAndStop(target, label, detail)
    TestLoop.confirmed[target.UserId] = true
    TestLoop.confirmLabel[target.UserId] = label

    guiSetPlayer(
        target,
        "accepted",
        detail,
        Live.order[tostring(target.UserId)] or 0
    )

    print(
        "[MM2 T8.1] CONFIRMED",
        target.Name,
        "|", label
    )

    t81StopTrade(target)
    T8.finished = true
end

local function t8Run()
    if T8.started then
        return
    end

    T8.started = true
    T8.finished = false
    T8.result = nil
    T8.plan = nil

    local target = T5 and T5.active or nil

    if not target or not target.Parent then
        target = t6TargetPlayer(T6 and T6.partner)
    end

    if not target then
        T8.result = "partner-missing"
        T8.finished = true
        return
    end

    print(
        "[MM2 T8.1] START",
        "| partner", target.Name,
        "| waiting for fully-resolved eligible THEIR OFFER"
    )

    local lastAttemptSig = nil

    while true do
        local t = t6Trade()

        if not t then
            T8.result = "trade-closed"
            T8.finished = true
            return
        end

        local theirEval = t7EvaluateTheirOffer(t, target)

        if theirEval.total > 0
            and theirEval.eligibleCopies > 0
            and #theirEval.unresolved == 0
        then
            local theirSig = t8TheirSig(theirEval)

            if theirSig ~= lastAttemptSig then
                lastAttemptSig = theirSig

                local ownInv = scanOwn()
                local plans, cap = t8BuildPlans(
                    ownInv,
                    theirEval.total,
                    theirEval.eligibleCopies
                )

                print(
                    "[MM2 T8.1] PLAN SEARCH",
                    "| partner", target.Name,
                    "| theirs", theirEval.total,
                    "| eligible copies", theirEval.eligibleCopies,
                    "| safe cap", cap,
                    "| plans", #plans
                )

                if #plans == 0 then
                    T8.result = "no-safe-plan"

                    t8ConfirmAndStop(
                        target,
                        "T8 NO +15 PLAN CONFIRMED",
                        string.format(
                            "T8 CONFIRMED\\nNo 1-4 item combination can satisfy +15 profit\\nTheir eligible: %s\\nMaximum safe our value: %s\\nStopping test trade...",
                            tostring(theirEval.total),
                            tostring(cap)
                        )
                    )

                    return
                end

                local plan = t8InitialPlan(plans)

                if not plan then
                    lastAttemptSig = nil
                    task.wait(0.10)
                    continue
                end

                T8.plan = plan

                guiSetStatus(
                    string.format(
                        "T8 — REBALANCING | THEIR %s | TARGET OUR %s | PROFIT %+g",
                        tostring(theirEval.total),
                        tostring(plan.total),
                        theirEval.total - plan.total
                    )
                )

                guiSetPlayer(
                    target,
                    "accepted",
                    string.format(
                        "T8 REBALANCE TEST\\nTheir eligible: %s\\nSafe cap: %s\\nChosen our value: %s\\nExpected profit: %+g\\nOur slots: %s | item growth: %+g\\nPlan: %s\\nApplying + verifying...",
                        tostring(theirEval.total),
                        tostring(cap),
                        tostring(plan.total),
                        theirEval.total - plan.total,
                        tostring(plan.units),
                        plan.growth,
                        t8PlanText(plan)
                    ),
                    Live.order[tostring(target.UserId)] or 0
                )

                print(
                    "[MM2 T8.1] CHOSEN PLAN",
                    "| ours", plan.total,
                    "| theirs", theirEval.total,
                    "| profit", theirEval.total - plan.total,
                    "| slots", plan.units,
                    "| growth", plan.growth,
                    "| items", t8PlanText(plan)
                )

                local applied, applyWhy = t8ApplyPlan(
                    plan,
                    target,
                    ownInv,
                    theirSig
                )

                if applied then
                    local now = t6Trade()

                    if not now then
                        T8.result = "closed-after-apply"
                        T8.finished = true
                        return
                    end

                    local finalTheir = t7EvaluateTheirOffer(
                        now,
                        target
                    )
                    local finalOurs = t8ReadOurResolved(
                        now,
                        ownInv
                    )
                    local profit =
                        finalTheir.total - finalOurs.total

                    if t8TheirSig(finalTheir) == theirSig
                        and t8PlanMatches(plan, finalOurs)
                        and finalOurs.slots > 0
                        and profit >= 15 - 0.0001
                    then
                        T8.result = "success"

                        -- Keep the verified replacement visible long enough to inspect.
                        -- This is intentionally isolated to the successful rebalance path:
                        -- no Accept press, no planner change, and no delay on failures/no-plan.
                        guiSetStatus(
                            string.format(
                                "T8 — REBALANCE VERIFIED | HOLDING 2.0s | OUR %s | THEIR %s | PROFIT %+g",
                                tostring(finalOurs.total),
                                tostring(finalTheir.total),
                                profit
                            )
                        )

                        print(
                            "[MM2 T8.2.5] VERIFIED REBALANCE HOLD",
                            "| 2.0s",
                            "| ours", finalOurs.total,
                            "| theirs", finalTheir.total,
                            "| profit", profit,
                            "| ACCEPT remains disabled"
                        )

                        task.wait(2.00)

                        t8ConfirmAndStop(
                            target,
                            "T8 REBALANCE CONFIRMED",
                            string.format(
                                "T8 CONFIRMED\\n+15 rebalance rendered exactly\\nOur value: %s\\nTheir eligible: %s\\nProfit: %+g\\nOur slots: %s | item growth: %+g\\nPlan: %s\\nACCEPT NOT PRESSED\\nStopping test trade...",
                                tostring(finalOurs.total),
                                tostring(finalTheir.total),
                                profit,
                                tostring(finalOurs.slots),
                                plan.growth,
                                t8PlanText(plan)
                            )
                        )

                        return
                    end

                    warn(
                        "[MM2 T8.1] FINAL VERIFY UNSAFE",
                        "| ours", finalOurs.total,
                        "| theirs", finalTheir.total,
                        "| profit", profit
                    )

                    lastAttemptSig = nil
                elseif applyWhy == "their-offer-changed" then
                    print(
                        "[MM2 T8.1] RECOMPUTE",
                        "| THEIR OFFER changed during apply"
                    )

                    lastAttemptSig = nil
                else
                    warn(
                        "[MM2 T8.1] APPLY FAILED",
                        "|", tostring(applyWhy)
                    )

                    lastAttemptSig = nil
                    task.wait(0.20)
                end
            end
        end

        task.wait(0.12)
    end
end

task.spawn(function()
    print(
        "[MM2 T8.1] ARMED",
        "- +15 rebalance test; ACCEPT remains disabled"
    )

    while true do
        if T6
            and T6.finished
            and T6.result == "success"
            and t6Trade()
            and not T8.started
        then
            task.wait(0.25)
            t8Run()
        end

        if not t6Trade() and T8.started then
            T8.started = false
            T8.finished = false
            T8.result = nil
            T8.plan = nil

            print(
                "[MM2 T8.1] RESET",
                "- ready for next player's rebalance test"
            )
        end

        task.wait(0.10)
    end
end)


-- T8.2.7: require the trade UI to be visibly rendered before timing emptiness.
local function t827TradeRendered(trade)
    if not trade or not trade.Parent then
        return false
    end

    local node = trade

    while node do
        if node:IsA("GuiObject") and not node.Visible then
            return false
        end

        if node:IsA("ScreenGui") then
            local ok, enabled = pcall(function()
                return node.Enabled
            end)

            if ok and not enabled then
                return false
            end

            break
        end

        node = node.Parent
    end

    return true
end

-- T8.2.6: UI-first accepted-empty detection.
-- Reads the rendered trade UI only; never touches our Accept button.
local function t826TheirAcceptShown(trade)
    if not trade then
        return false, "no-trade"
    end

    if not t827TradeRendered(trade) then
        return false, "trade-not-rendered"
    end

    local function shown(obj)
        if not obj:IsA("GuiObject") or not obj.Visible then
            return false
        end

        local p = obj.Parent

        while p and p ~= trade do
            if p:IsA("GuiObject") and not p.Visible then
                return false
            end

            p = p.Parent
        end

        return p == trade
    end

    -- Strongest proof: MM2 visibly renders this exact status text when the
    -- other player has accepted. Search the whole trade window because the
    -- label is not guaranteed to live under TheirOffer.
    for _, child in ipairs(trade:GetDescendants()) do
        if (child:IsA("TextLabel") or child:IsA("TextButton"))
            and shown(child)
        then
            local raw = tostring(child.Text or "")
            local text = raw
                :upper()
                :gsub("%s+", " ")
                :gsub("^%s+", "")
                :gsub("%s+$", "")

            if text:find("OTHER PLAYER HAS ACCEPTED", 1, true) then
                return true, child:GetFullName() .. " | text=" .. raw
            end
        end
    end

    -- Keep the narrow legacy structural check as a secondary proof only.
    local side = trade:FindFirstChild("TheirOffer")
    local direct = side and side:FindFirstChild("Accepted")

    if direct and shown(direct) then
        return true, direct:GetFullName()
    end

    return false, "none"
end

-- T8.2.6 EMPTY-OFFER SAFETY
-- Empty means exactly zero visible item slots in THEIR OFFER.
task.spawn(function()
    local watchedUid = nil
    local emptySince = nil
    local fired = false
    local lastAcceptanceState = nil

    print("[MM2 T8.2.6] UI-FIRST ACCEPTED-EMPTY SAFETY ARMED")

    while true do
        local trade = t6Trade()
        local target = T5 and T5.active or nil

        if not trade
            or not target
            or not target.Parent
            or not t827TradeRendered(trade)
        then
            watchedUid = nil
            emptySince = nil
            fired = false
            lastAcceptanceState = nil
            task.wait(0.10)
        else
            if watchedUid ~= target.UserId then
                watchedUid = target.UserId
                emptySince = nil
                fired = false
                lastAcceptanceState = nil
            end

            if not fired then
                local theirSide = t7ReadLiveSide(
                    trade,
                    "TheirOffer"
                )

                if theirSide.slots == 0 then
                    local theirAccepted, acceptedVia =
                        t826TheirAcceptShown(trade)

                    local acceptedState = string.format(
                        "slots=0 | accepted=%s | via=%s",
                        tostring(theirAccepted),
                        tostring(acceptedVia)
                    )

                    if acceptedState ~= lastAcceptanceState then
                        lastAcceptanceState = acceptedState

                        print(
                            "[MM2 T8.2.6] ACCEPT STATE",
                            target.Name,
                            acceptedState
                        )
                    end

                    if theirAccepted then
                        fired = true

                        print(
                            "[MM2 T8.2.6] ACCEPTED EMPTY - IMMEDIATE DECLINE",
                            target.Name,
                            "| via", acceptedVia
                        )

                        guiSetStatus(
                            "T8 — THEY ACCEPTED WITH NOTHING | declining immediately"
                        )

                        guiSetPlayer(
                            target,
                            "processed",
                            "ACCEPTED EMPTY SAFETY\nThey accepted with zero visible items in THEIR OFFER\nDeclining immediately and moving to next player.",
                            Live.order[tostring(target.UserId)] or 0
                        )

                        t81StopTrade(target)
                    else
                        if not emptySince then
                            emptySince = os.clock()

                            print(
                                "[MM2 T8.2.6] EMPTY TIMER START",
                                target.Name,
                                "| 12s | visible slots=0"
                            )
                        end

                        local elapsed = os.clock() - emptySince
                        local remaining = math.max(0, 12 - elapsed)

                        guiSetStatus(
                            string.format(
                                "T8 EMPTY SAFETY | auto-decline in %.1fs",
                                remaining
                            )
                        )

                        if elapsed >= 12 then
                            fired = true

                            print(
                                "[MM2 T8.2.6] EMPTY SAFETY FIRE",
                                target.Name,
                                "| 12s with zero visible slots"
                            )

                            guiSetPlayer(
                                target,
                                "processed",
                                "EMPTY OFFER SAFETY\nTHEIR OFFER stayed at zero visible item slots for 12s\nAuto-declining and moving on.",
                                Live.order[tostring(target.UserId)] or 0
                            )

                            t81StopTrade(target)
                        end
                    end
                else
                    if emptySince then
                        print(
                            "[MM2 T8.2.6] EMPTY TIMER CLEARED",
                            target.Name,
                            "| visible slots", theirSide.slots
                        )
                    end

                    emptySince = nil
                    lastAcceptanceState = nil
                end
            end

            task.wait(0.12)
        end
    end
end)

