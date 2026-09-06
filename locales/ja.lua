KnSeatSelectLocales = KnSeatSelectLocales or {}

--[[
 通知 (notify.*) は ox_lib / chat 経由なので日本語で問題ない。
 どちらも無い環境では GTA 標準通知に落ちるが、そこはフォントの都合で
 自動的に英語 (en.lua) が使われる。locales/locale.lua を参照。
]]

KnSeatSelectLocales['ja'] = {
    ['chat.prefix'] = 'kn_seatselect',

    -- UI
    ['ui.close'] = 'ESC で閉じる',
    ['ui.occupied'] = '使用中',

    -- 操作ヒント
    ['hint.hold'] = '[%s] 長押しで座席を選択',

    -- 座席名
    ['seat.driver'] = '運転席',
    ['seat.passenger'] = '助手席',
    ['seat.rearLeft'] = '後部左',
    ['seat.rearRight'] = '後部右',
    ['seat.other'] = '座席 %d',

    -- 通知
    ['notify.locked'] = '車両は施錠されています。',
    ['notify.seatTaken'] = 'その席は使用中です。',
    ['notify.alreadyInVehicle'] = 'すでに乗車しています。',
    ['notify.tooFar'] = '車両から離れすぎています。',
    ['notify.noSeat'] = '空いている席がありません。',
}
