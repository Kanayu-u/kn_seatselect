--[[
===============================================================================
 kn_seatselect / client
-----------------------------------------------------------------------------
 車両の近くで乗車キーを長押し → 座席選択 UI → 選んだ席へ乗車する。
 短押しは従来どおり乗車 (一番近いドアの空席 / 運転席優先は config で選択)。

 原案: SeatSelection by BeereMgM (MIT) — 座席 UI と乗車の考え方を借用し、
 長押し判定・占有表示・施錠判定・入力ガード・座席番号の扱いを作り直している。
===============================================================================
]]

local Config = KnSeatSelectConfig
local L = KnSeatSelectL
local FeedL = KnSeatSelectFeedL

-- 解錠扱いにするドアロック状態 (それ以外は施錠とみなす)
-- https://docs.fivem.net/natives/?_0x25BC98A59C2EA962
local UNLOCKED_LOCK_STATES = {
    [0] = true, -- ロック機構なし
    [1] = true, -- 解錠
}

-- 座席インデックス → 座席のボーン名 (短押しの距離判定に使う)。
-- ここに無い席 (5 席目以降) は位置を測らず TaskEnterVehicle にそのまま任せる。
--
-- ドアのボーン (door_dside_f 等) は使わない。ドアボーンは「ヒンジ」の位置にあり、
-- 後席ドアのヒンジは B ピラー = 車体のほぼ中央にあるため、車の横に立つと
-- 前席ドアのヒンジ (A ピラー) より必ず近くなり、左右問わず後席に判定が吸われる。
local SEAT_BONES = {
    [-1] = { bone = 'seat_dside_f', front = true  }, -- 運転席
    [0]  = { bone = 'seat_pside_f', front = true  }, -- 助手席
    [1]  = { bone = 'seat_dside_r', front = false }, -- 後部左
    [2]  = { bone = 'seat_pside_r', front = false }, -- 後部右
}

local SCAN_INTERVAL_MS = 250 -- 近くの車両を探し直す間隔

local uiOpen = false
local activeVehicle = nil
local hintVisible = false
local nearVehicle = nil
local lastScanAt = 0
local pressStartedAt = nil
local holdConsumed = false

-- ---------------------------------------------------------------- utilities

local function debugPrint(message)
    if Config.debug then
        -- F8 は非 ASCII を落とすため、デバッグ出力は英数字のみで組み立てる
        print(('[kn_seatselect] %s'):format(message))
    end
end

--- 通知を出す。ox_lib → chat → GTA 標準通知 の順に試す。
--- GTA 標準通知はゲーム側フォントの都合で日本語が化けるため英語に落とす。
local function notify(key)
    if GetResourceState('ox_lib') == 'started' then
        local ok = pcall(function()
            exports.ox_lib:notify({ title = L('chat.prefix'), description = L(key), type = 'inform' })
        end)
        if ok then
            return
        end
    end

    if GetResourceState('chat') == 'started' then
        TriggerEvent('chat:addMessage', {
            color = { 255, 255, 255 },
            multiline = true,
            args = { L('chat.prefix'), L(key) },
        })
        return
    end

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(FeedL(key))
    EndTextCommandThefeedPostTicker(false, false)
end

local function seatLabel(index)
    if index == -1 then
        return L('seat.driver')
    elseif index == 0 then
        return L('seat.passenger')
    elseif index == 1 then
        return L('seat.rearLeft')
    elseif index == 2 then
        return L('seat.rearRight')
    end

    -- 表示は 1 始まりの通し番号 (index -1 が 1 番目)
    return L('seat.other', index + 2)
end

local function isLocked(vehicle)
    if not Config.checkDoorLock then
        return false
    end

    return not UNLOCKED_LOCK_STATES[GetVehicleDoorLockStatus(vehicle)]
end

local function isUsableVehicle(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end

    if Config.ignoreWreckedVehicles then
        if IsEntityDead(vehicle) or not IsVehicleDriveable(vehicle, false) then
            return false
        end
    end

    return true
end

local function findClosestVehicle(pedCoords)
    local closest, closestDist = nil, Config.maxDistance

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if isUsableVehicle(vehicle) then
            local dist = #(pedCoords - GetEntityCoords(vehicle))
            if dist < closestDist then
                closest, closestDist = vehicle, dist
            end
        end
    end

    return closest
end

local function seatCount(vehicle)
    local total = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
    if type(total) ~= 'number' or total <= 0 then
        return 0
    end

    return math.min(total, Config.maxSeatsInUi)
end

--- ドアの位置が一番近い空席を返す。ドアボーンを持たない車両では
--- 先頭の空席にフォールバックする (nil = 空席なし)。
local function nearestFreeSeat(vehicle, pedCoords)
    local total = seatCount(vehicle)
    local best, bestDist = nil, math.huge

    -- IsVehicleSeatFree は存在しない座席にも true を返すため、
    -- 座席数から出る範囲 (-1 .. total-2) に必ず収める
    for seat, entry in pairs(SEAT_BONES) do
        if seat <= total - 2 and IsVehicleSeatFree(vehicle, seat) then
            local boneIndex = GetEntityBoneIndexByName(vehicle, entry.bone)
            if boneIndex ~= -1 then
                local dist = #(pedCoords - GetWorldPositionOfEntityBone(vehicle, boneIndex))

                -- B ピラー付近に立つと前後がほぼ等距離になるため、前席を少しだけ優先する
                if entry.front then
                    dist = dist - (Config.frontSeatBias or 0.0)
                end

                if dist < bestDist then
                    best, bestDist = seat, dist
                end
            end
        end
    end

    if best then
        return best
    end

    for i = 1, total do
        local seat = i - 2
        if IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end

    return nil
end

-- ---------------------------------------------------------------- 乗車処理

-- 乗車指示の世代。新しい指示が出たら古い監視スレッドは何もせず降りる
local enterGeneration = 0

--- TaskEnterVehicle は狙った席とは別の席で乗車を完了させることがある。
--- (助手席側から運転席を選ぶと助手席で止まる等。ゲーム側が近い乗車口の席を選ぶ、
---  アンチシャッフル系リソースが自動シャッフルを止めている、などが原因になりうる)
--- 原因を問わず直せるよう、乗り終わってから実際の座席を確認して座り直す。
local function watchEnteredSeat(vehicle, seat, generation)
    CreateThread(function()
        local deadline = GetGameTimer() + Config.enterTimeoutMs + 3000
        local seated = false

        while GetGameTimer() < deadline do
            Wait(150)

            if generation ~= enterGeneration or not DoesEntityExist(vehicle) then
                return
            end

            if IsPedInVehicle(PlayerPedId(), vehicle, false) then
                seated = true
                break
            end
        end

        if not seated then
            return
        end

        -- ゲーム側の自動シャッフルが走ることがあるので、決着してから判定する
        Wait(Config.seatCorrectionDelayMs)

        if generation ~= enterGeneration or not DoesEntityExist(vehicle) then
            return
        end

        local ped = PlayerPedId()
        if not IsPedInVehicle(ped, vehicle, false) then
            return
        end

        if GetPedInVehicleSeat(vehicle, seat) == ped then
            return
        end

        if IsVehicleSeatFree(vehicle, seat) then
            debugPrint(('correcting seat -> %d'):format(seat))
            SetPedIntoVehicle(ped, vehicle, seat)
        else
            -- 乗っている間に他の誰かに座られた
            notify('notify.seatTaken')
        end
    end)
end

local function enterSeat(vehicle, seat)
    local ped = PlayerPedId()

    if not DoesEntityExist(vehicle) then
        return
    end

    if IsPedInAnyVehicle(ped, true) then
        notify('notify.alreadyInVehicle')
        return
    end

    -- UI を開いている間に歩いて離れている可能性があるので測り直す
    -- (UI 操作中のずれを見込んで少しだけ余裕を持たせる)
    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > (Config.maxDistance + 2.0) then
        notify('notify.tooFar')
        return
    end

    if isLocked(vehicle) then
        notify('notify.locked')
        return
    end

    if not IsVehicleSeatFree(vehicle, seat) then
        notify('notify.seatTaken')
        return
    end

    debugPrint(('enter seat %d (class %d)'):format(seat, GetVehicleClass(vehicle)))

    enterGeneration = enterGeneration + 1

    local warpClasses = Config.warpVehicleClasses
    if type(warpClasses) == 'table' and warpClasses[GetVehicleClass(vehicle)] then
        SetPedIntoVehicle(ped, vehicle, seat)
        return
    end

    -- ドアまでの移動は TaskEnterVehicle 側に任せる (座席ごとに正しいドアへ歩く)
    TaskEnterVehicle(ped, vehicle, Config.enterTimeoutMs, seat, Config.enterSpeed, 1, 0)

    if Config.correctSeatAfterEntry then
        watchEnteredSeat(vehicle, seat, enterGeneration)
    end
end

local function shortPressEnter(vehicle)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    if isLocked(vehicle) then
        notify('notify.locked')
        return
    end

    local seat
    if Config.shortPress == 'driver' and IsVehicleSeatFree(vehicle, -1) then
        seat = -1
    else
        seat = nearestFreeSeat(vehicle, pedCoords)
    end

    if not seat then
        notify('notify.noSeat')
        return
    end

    enterSeat(vehicle, seat)
end

-- ---------------------------------------------------------------- UI 制御

local function setHint(visible)
    if not Config.showHint or hintVisible == visible then
        return
    end

    hintVisible = visible
    SendNUIMessage({
        action = 'hint',
        visible = visible,
        text = L('hint.hold', Config.keyLabel),
    })
end

local function closeMenu()
    if not uiOpen then
        return
    end

    uiOpen = false
    activeVehicle = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openMenu(vehicle)
    if uiOpen or not DoesEntityExist(vehicle) then
        return
    end

    if isLocked(vehicle) then
        notify('notify.locked')
        return
    end

    local total = seatCount(vehicle)
    if total <= 0 then
        return
    end

    local seats = {}
    for i = 1, total do
        local index = i - 2 -- 1 番目 = 運転席 (-1)、2 番目 = 助手席 (0) ...
        seats[#seats + 1] = {
            index = index,
            label = seatLabel(index),
            free = IsVehicleSeatFree(vehicle, index) and true or false,
        }
    end

    activeVehicle = vehicle
    uiOpen = true
    setHint(false)

    SendNUIMessage({
        action = 'open',
        closeHint = L('ui.close'),
        occupiedLabel = L('ui.occupied'),
        seats = seats,
    })
    SetNuiFocus(true, true)
end

RegisterNUICallback('selectSeat', function(data, cb)
    cb('ok')

    local vehicle = activeVehicle
    local seat = tonumber(data and data.seat)

    closeMenu()

    if not vehicle or not seat then
        return
    end

    enterSeat(vehicle, seat)
end)

RegisterNUICallback('closeUi', function(_, cb)
    cb('ok')
    closeMenu()
end)

-- ---------------------------------------------------------------- 入力ループ

--- 座席選択を受け付けてよい状態か。
--- RegisterKeyMapping ではなく control 監視だが、NUI 入力中・ポーズ中は
--- どちらにせよ拾ってはいけないので同じガードを掛ける。
local function canInteract(ped)
    return not IsPauseMenuActive()
        and not IsNuiFocused()
        and not IsPedInAnyVehicle(ped, true)
        and not IsEntityDead(ped)
end

CreateThread(function()
    if type(Config) ~= 'table' then
        print('[kn_seatselect] config/config.lua was not loaded; resource disabled')
        return
    end

    while true do
        local sleep = 500
        local ped = PlayerPedId()

        if canInteract(ped) then
            local now = GetGameTimer()

            if now - lastScanAt >= SCAN_INTERVAL_MS then
                lastScanAt = now
                nearVehicle = findClosestVehicle(GetEntityCoords(ped))
            end

            if nearVehicle and DoesEntityExist(nearVehicle) then
                sleep = 0
                setHint(true)

                if Config.suppressDefaultEnter then
                    DisableControlAction(0, Config.enterControl, true)

                    if IsDisabledControlJustPressed(0, Config.enterControl) then
                        pressStartedAt = now
                        holdConsumed = false
                    elseif pressStartedAt and not holdConsumed and IsDisabledControlPressed(0, Config.enterControl) then
                        if now - pressStartedAt >= Config.holdMs then
                            holdConsumed = true
                            pressStartedAt = nil
                            openMenu(nearVehicle)
                        end
                    elseif IsDisabledControlJustReleased(0, Config.enterControl) then
                        if pressStartedAt and not holdConsumed then
                            shortPressEnter(nearVehicle)
                        end
                        pressStartedAt = nil
                        holdConsumed = false
                    end
                else
                    -- バニラの乗車はそのまま。長押しだけ拾う
                    if IsControlJustPressed(0, Config.enterControl) then
                        pressStartedAt = now
                        holdConsumed = false
                    elseif pressStartedAt and not holdConsumed and IsControlPressed(0, Config.enterControl) then
                        if now - pressStartedAt >= Config.holdMs then
                            holdConsumed = true
                            pressStartedAt = nil
                            openMenu(nearVehicle)
                        end
                    elseif IsControlJustReleased(0, Config.enterControl) then
                        pressStartedAt = nil
                        holdConsumed = false
                    end
                end
            else
                nearVehicle = nil
                pressStartedAt = nil
                holdConsumed = false
                setHint(false)
            end
        else
            nearVehicle = nil
            pressStartedAt = nil
            holdConsumed = false
            setHint(false)
        end

        Wait(sleep)
    end
end)

-- リソース停止時に NUI フォーカスを掴んだままにしない
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    if uiOpen then
        SetNuiFocus(false, false)
    end
end)
