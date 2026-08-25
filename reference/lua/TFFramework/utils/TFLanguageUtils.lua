--[[--
	--By:zhangliguo
]]
TFLanguageMgr = class('TFLanguageMgr')
--多语言处理
-------------------------------------------------------
cc = {}
cc.ENGLISH = ENGLISH
cc.SIMPLIFIED_CHINESE = SIMPLIFIED_CHINESE
cc.TRADITIONAL_CHINESE = TRADITIONAL_CHINESE
cc.FRENCH = FRENCH
cc.ITALIAN = ITALIAN
cc.GERMAN = GERMAN
cc.SPANISH = SPANISH
cc.DUTCH = DUTCH
cc.RUSSIAN = RUSSIAN
cc.KOREAN = KOREAN
cc.JAPANESE = JAPANESE
cc.HUNGARIAN = HUNGARIAN
cc.PORTUGUESE = PORTUGUESE
cc.ARABIC = ARABIC
cc.NORWEGIAN = NORWEGIAN
cc.POLISH = POLISH
cc.TURKISH = TURKISH
cc.UKRAINIAN = UKRAINIAN
cc.ROMANIAN = ROMANIAN
cc.BULGARIAN = BULGARIAN
cc.BELARUSIAN = BELARUSIAN
cc.THAI = THAI
cc.INDONESIAN = INDONESIAN
cc.MALAYSIA = MALAYSIA
cc.VIETNAM = VIETNAM



local langCfg = {
    [cc.ENGLISH] = 190012001,
    [cc.FRENCH] = 190012002,
    [cc.GERMAN] = 190012003,
    [cc.SPANISH] = 190012004,
    [cc.THAI] = 190012005,
    [cc.INDONESIAN] = 190012006,
    [cc.KOREAN] = 190012007,
    [cc.TRADITIONAL_CHINESE] = 190012008,
    [cc.SIMPLIFIED_CHINESE] = 190012009,
    [cc.VIETNAM] = 18000333
}


--英语(en)，法语(fr)，德语(de)，西班牙语(es)，泰语(th)，印尼语(id)，韩语(ko)，繁体中文(zh) ,简体中文(zn)，越南语（vi）
local allLanguages      = {cc.ENGLISH, cc.FRENCH , cc.GERMAN, cc.SPANISH, cc.THAI, cc.INDONESIAN, cc.KOREAN, cc.TRADITIONAL_CHINESE, cc.SIMPLIFIED_CHINESE ,cc.VIETNAM}
local oneStoreLanguages = {cc.ENGLISH, cc.KOREAN }
local enabledLanguages  = allLanguages
--[[
    获得全部的语言枚举
]]
function TFLanguageMgr:getLanguages()
    return enabledLanguages
end

function TFLanguageMgr:getLanguageTextId( language )
    -- local textList = {190012001,190012002,190012003,190012004,190012005,190012006,190012007,190012008,190012009 ,18000333}
    return langCfg[language] or  langCfg[cc.ENGLISH]
end

--当前使用语言是否可用
function TFLanguageMgr:languageEnable( language )
    local list = self:getLanguages()
    if table.find(list, language) ~= -1 then
        return true, language
    end

    local deviceLanguage = TFLanguageMgr:getCurrentLanguage() or cc.ENGLISH
    if table.find(list, deviceLanguage) ~= -1 then
        return false, deviceLanguage
    end
    return false, list[1]
end

function TFLanguageMgr:getCurrentLanguage( )
    return TFLanguageManager:shareLanguageManager():getCurrentLanguage()
end

function TFLanguageMgr:getCurrentLanguageCode( )
    return TFLanguageManager:shareLanguageManager():getCurrentLanguageCode()
end

function TFLanguageMgr:getCurrentCountryCode( )
    return TFLanguageManager:shareLanguageManager():getCurrentCountryCode()
end

function TFLanguageMgr:getCodeByLanguage( language, suffix )
    suffix = suffix or ""
    return suffix ..TFLanguageManager:shareLanguageManager():getCodeByLanguage(language)
end

--获得当前语言对应的后缀
function TFLanguageMgr:getUsingLanguageCode( suffix )
    local str = suffix or ""
    return str ..self:getCodeByLanguage(self:getUsingLanguage())
end

--获得当前的语言
function TFLanguageMgr:getUsingLanguage()
    local language = TFLanguageManager:shareLanguageManager():getAppUsingLanguage()
    local _,_language = self:languageEnable(language)
    return _language
end

--设置当前的语言
function TFLanguageMgr:setUsingLanguage( language )
    if not (type(language) == "number") then return end
    local _,_language = self:languageEnable(language)
    TFLanguageManager:shareLanguageManager():setAppUsingLanguage(_language)
end


--返回sdk需要的映射语言值
function TFLanguageMgr:getSdkUsingLanguage()
    local languageCodeMap = {}
    languageCodeMap[cc.FRENCH] = "fr"
    languageCodeMap[cc.GERMAN] = "de"
    languageCodeMap[cc.SPANISH] = "es"
    languageCodeMap[cc.THAI] = "th"
    languageCodeMap[cc.INDONESIAN] = "id"
    languageCodeMap[cc.KOREAN] = "ko"
    languageCodeMap[cc.TRADITIONAL_CHINESE] = "zh-Hant"
    languageCodeMap[cc.ENGLISH] = "en"
    languageCodeMap[cc.SIMPLIFIED_CHINESE] = "cn"
    languageCodeMap[cc.VIETNAM] = "vi"
    local language = "en"
    if languageCodeMap[TFLanguageMgr:getUsingLanguage()] then
        language = languageCodeMap[TFLanguageMgr:getUsingLanguage()]
    end
    return language
end

function TFLanguageMgr:getWindowsTestTextByLanguage( language )
    local languageText = {}
    languageText[cc.ENGLISH] = "英语"
    languageText[cc.FRENCH] = "法语"
    languageText[cc.GERMAN] = "德语"
    languageText[cc.SPANISH] = "西班牙语"
    languageText[cc.THAI] = "泰语"
    languageText[cc.INDONESIAN] = "印尼语"
    languageText[cc.KOREAN] = "韩语"
    languageText[cc.TRADITIONAL_CHINESE] = "繁体中文"
    languageText[cc.SIMPLIFIED_CHINESE] = "简体中文"
    languageText[cc.VIETNAM] = "越南语"
    return languageText[language] or ""
end


-- __print("设置默认语言 Start")
--设置平台的初始语言
if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID   then
    if HeitaoSdk then
        local platformId =  HeitaoSdk.getplatformId()
        __print("platformId:"..tostring(platformId))
        if platformId == "101" then --oneStore
            enabledLanguages  = oneStoreLanguages
            local lang = TFLanguageMgr:getUsingLanguage()
            if lang ~= cc.ENGLISH and lang ~= cc.KOREAN then
                TFLanguageMgr:setUsingLanguage(cc.ENGLISH)
                __print("设置默认语言英文")
            end
        end
    end
end

return TFLanguageMgr




