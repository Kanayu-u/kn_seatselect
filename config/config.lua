--[[
===============================================================================
 kn_seatselect / config
-----------------------------------------------------------------------------
 車両の近くでキーを長押しすると座席選択 UI を開き、選んだ席へ乗車する。
 ロジック側 (client/main.lua) はこのテーブルを読むだけで書き換えない。
===============================================================================
]]

KnSeatSelectConfig = {
    -- 表示言語 ('ja' | 'en')
    -- 通知は ox_lib / chat 経由なので日本語で問題ない。
    -- どちらも無い環境では GTA 標準の通知にフォールバックし、その場合のみ
    -- 文字化けを避けるため英語で表示する (locales/locale.lua の feed 用取得を参照)。
    locale = 'ja',

    -- 長押しに使う control ID (control group 0)
    -- 既定 23 = INPUT_ENTER = 徒歩時の「乗車」(キーボード F / パッドの乗車ボタン)
    -- 一覧: https://docs.fivem.net/docs/game-references/controls/
    enterControl = 23,

    -- UI に表示するキー名。enterControl を変えたらここも合わせる (表示専用)
    keyLabel = 'F',

    -- この時間(ms)以上押し続けたら座席選択 UI を開く
    holdMs = 300,

    -- 対象車両を拾う最大距離 (m)
    maxDistance = 5.0,

    -- true: 車両の近くにいる間だけバニラの乗車操作を無効化し、
    --       短押し(= holdMs 未満)の乗車をこのリソースで再現する。
    --       長押しの開始でバニラが勝手に乗車を始めてしまうのを防ぐために必要。
    -- false: バニラの乗車をそのまま残す。長押しを始めた瞬間に運転席へ乗り始めるため、
    --        UI で席を選ぶ前に乗車が完了することがある (enterControl を F 以外にする場合向け)
    suppressDefaultEnter = true,

    -- 短押しの挙動 ('nearest' | 'driver')。suppressDefaultEnter = true のときのみ使う
    --   nearest = 一番近いドアの空席に乗る (バニラより「ドア基準」で素直)
    --   driver  = 運転席を優先し、埋まっていれば一番近い空席
    shortPress = 'nearest',

    -- 施錠された車両を弾く。false にすると施錠中でも乗車を試みる (バニラ同様に失敗する)
    checkDoorLock = true,

    -- 破損して動かない車両を対象から外す
    ignoreWreckedVehicles = true,

    -- 経路探索で乗車させず直接座らせる車両クラス。
    -- TaskEnterVehicle はヘリ/飛行機の後部席でドアまで歩けず失敗することがあるため、
    -- 実機で乗れない機体があれば [15] = true (ヘリ) / [16] = true (飛行機) を有効にする。
    -- 既定は空 = 常に歩いて乗車 (瞬間移動に見えないため)
    warpVehicleClasses = {},

    -- TaskEnterVehicle の待ち時間(ms) と移動速度 (1.0 = 歩き, 2.0 = 走り)
    enterTimeoutMs = 10000,
    enterSpeed = 2.0,

    -- 乗り終わったあと、実際に座った席が選んだ席と違っていたら座り直す。
    -- TaskEnterVehicle はゲーム側の都合で別の席に座らせることがあるため
    -- (助手席側から運転席を選ぶと助手席で止まる、など)。
    correctSeatAfterEntry = true,

    -- 座り直しの判定を遅らせる時間(ms)。ゲーム側の自動シャッフルが
    -- 走り切るのを待ってから判定するためのもの。短すぎると競合する
    seatCorrectionDelayMs = 700,

    -- 短押しで席を選ぶとき、前席の距離からこの値(m)を引いて前席を優先する。
    -- B ピラー付近に立つと前後の座席がほぼ等距離になり、
    -- わずかな差で後席が選ばれてしまうため。0.0 で純粋な最短距離になる
    frontSeatBias = 0.35,

    -- UI に並べる座席数の上限 (バス等で列が伸びすぎるのを防ぐ)
    maxSeatsInUi = 16,

    -- 車両に近づいたときに操作ヒントを表示する (NUI 描画なので日本語でも化けない)
    showHint = true,

    -- true にすると判定の内訳を F8 に出す (英数字のみ)
    debug = false,
}
