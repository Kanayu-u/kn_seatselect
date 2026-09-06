--[[
===============================================================================
 kn_seatselect / locale runtime
-----------------------------------------------------------------------------
 KnSeatSelectLocales[lang][key] = 文字列 (string.format 用の書式を含む)

 KnSeatSelectL(key, ...)     : 通常の翻訳取得 (NUI / ox_lib / chat 向け)
 KnSeatSelectFeedL(key, ...) : GTA 標準通知 (BeginTextCommandThefeedPost) 向け。
                               ゲーム側フォントに日本語グリフが無く文字化けするため、
                               非 ASCII を含む場合は英語へフォールバックする。
===============================================================================
]]

KnSeatSelectLocales = KnSeatSelectLocales or {}

local FALLBACK_LANG = 'en'

local function resolve(lang, key)
    local table_ = KnSeatSelectLocales[lang]
    if type(table_) == 'table' and table_[key] ~= nil then
        return table_[key]
    end

    return nil
end

local function currentLang()
    local config = KnSeatSelectConfig
    if type(config) == 'table' and type(config.locale) == 'string' and config.locale ~= '' then
        return config.locale
    end

    return FALLBACK_LANG
end

local function format(template, ...)
    if select('#', ...) == 0 then
        return template
    end

    local ok, result = pcall(string.format, template, ...)
    if ok then
        return result
    end

    -- 書式と引数が食い違っても表示を止めない
    return template
end

local function hasNonAscii(text)
    if type(text) ~= 'string' then
        return false
    end

    for i = 1, #text do
        if text:byte(i) > 127 then
            return true
        end
    end

    return false
end

function KnSeatSelectL(key, ...)
    local template = resolve(currentLang(), key)
        or resolve(FALLBACK_LANG, key)
        or key

    return format(template, ...)
end

function KnSeatSelectFeedL(key, ...)
    local template = resolve(currentLang(), key)

    if template == nil or hasNonAscii(template) then
        template = resolve(FALLBACK_LANG, key) or template or key
    end

    return format(template, ...)
end
