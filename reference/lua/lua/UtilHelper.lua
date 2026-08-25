-- 测试版本 true为调试版本  false为发布版本
VERSION_DEBUG = false
if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
    VERSION_DEBUG = true
end

--是否打开日志 print debug lua log
DEBUG_LOG = false
if (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32) or DEBUG_PACKAGE then
    DEBUG_LOG = true
end

EXPERIENCE 	= false--体验服标识
GM_MODE 	= false;--GM模式



if VERSION_DEBUG == true then
    HeitaoSdk = nil
    CCLog_setDebugFileEnabled(1) --开启调试模式
end

if GM_MODE then
     HeitaoSdk = nil
end

if DEBUG_LOG == false then
    print = function()    
    end

    dump = function()
    end
end




--cdn address
URL_CDN_VERSION = {}
URL_CDN_FILE = {}
if DEBUG_PACKAGE then
    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        URL_CDN_VERSION[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/test/"
        URL_CDN_FILE[1]    = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/test/"
        URL_CDN_VERSION[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/test/"
        URL_CDN_FILE[2]    = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/test/"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        URL_CDN_VERSION[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/ios/"
        URL_CDN_FILE[1]    = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/ios/"
        URL_CDN_VERSION[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/ios/"
        URL_CDN_FILE[2]    = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/ios/"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        URL_CDN_VERSION[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/test/"
        URL_CDN_FILE[1]    = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/test/"
        URL_CDN_VERSION[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/test/"
        URL_CDN_FILE[2]    = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/test/"
    end
else
    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        URL_CDN_VERSION[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/android/"
        URL_CDN_FILE[1]    = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/android/"
        URL_CDN_VERSION[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/android/"
        URL_CDN_FILE[2]    = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/android/"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        URL_CDN_VERSION[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/ios/"
        URL_CDN_FILE[1]    = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/ios/"
        URL_CDN_VERSION[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/ios/"
        URL_CDN_FILE[2]    = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/ios/"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        URL_CDN_VERSION[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/android/"
        URL_CDN_FILE[1]    = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/assets/android/"
        URL_CDN_VERSION[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/android/"
        URL_CDN_FILE[2]    = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/assets/android/"
    end
end


--login address
URL_LOGIN = {}
if DEBUG_PACKAGE then
    if  CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        URL_LOGIN[1] = "http://192.168.38.150:8081/account"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        URL_LOGIN[1] = "http://43.130.144.246:7070/account"
        URL_LOGIN[2] = "http://43.130.144.246:7070/account"
    else
        URL_LOGIN[1] = "http://43.130.144.246:7070/account"
        URL_LOGIN[2] = "http://43.130.144.246:7070/account"
    end
else
    if  CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        URL_LOGIN[1] = "http://192.168.38.150:8081/account"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        URL_LOGIN[1] = "https://dal-login-us.heitaoglobal.com:8082/account"
        URL_LOGIN[2] = "https://dal-login-us.heitaoglobal.com:8082/account"
    else
        URL_LOGIN[1] = "https://dal-login-us.heitaoglobal.com:8082/account"
        URL_LOGIN[2] = "https://dal-login-us.heitaoglobal.com:8082/account"
    end
end



--query server date address
if DEBUG_PACKAGE then
    if  CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        URL_LOGIN_QUERYDATE = "http://192.168.38.150:8081/account/querydate"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        URL_LOGIN_QUERYDATE = "http://43.130.144.246:7070/account/querydate"
    else
        URL_LOGIN_QUERYDATE = "http://43.130.144.246:7070/account/querydate"
    end
else
    if  CC_TARGET_PLATFORM == CC_PLATFORM_WIN32  then
        URL_LOGIN_QUERYDATE = "http://192.168.38.150:8081/account/querydate"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        URL_LOGIN_QUERYDATE = "https://dal-login-us.heitaoglobal.com:8082/account/querydate"
    else
        URL_LOGIN_QUERYDATE = "https://dal-login-us.heitaoglobal.com:8082/account/querydate"
    end
end


--多语言资源下载
URL_LANG_RES = {}
if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
    URL_LANG_RES[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/lang_assets/ios/"
    URL_LANG_RES[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/lang_assets/ios/"
elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
    URL_LANG_RES[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/lang_assets/android/"
    URL_LANG_RES[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/lang_assets/android/"
else
    URL_LANG_RES[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/lang_assets/ios/"
    URL_LANG_RES[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/lang_assets/ios/"
end





--ext assets address
URL_REMOTE = {}


if DEBUG_PACKAGE then 
     if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        URL_REMOTE[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/ext_assets/ios/"
        URL_REMOTE[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/ext_assets/ios/"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        URL_REMOTE[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/ext_assets/test/"
        URL_REMOTE[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/ext_assets/test/"
    else
        URL_REMOTE[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/ext_assets/test/"
        URL_REMOTE[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/ext_assets/test/"
    end
else
    if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        URL_REMOTE[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/ext_assets/ios/"
        URL_REMOTE[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/ext_assets/ios/"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        URL_REMOTE[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/ext_assets/android/"
        URL_REMOTE[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/ext_assets/android/"
    else
        URL_REMOTE[1] = "https://dal-huaijiu-us-cdn.moonramble.com/dal_global_us/ext_assets/android/"
        URL_REMOTE[2] = "https://dal-huaijiu-us-cdn2.moonramble.com/dal_global_us/ext_assets/android/"
    end

end

--notice board address
URL_NOTICEBOARD = "http://api-en.datealive.com/yhdzz/special/1"

--announcement address
URL_ANNOUNCEMENT = {}

if DEBUG_PACKAGE then
    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        URL_ANNOUNCEMENT[1] = "http://192.168.38.150:8081/globalNotice/get_global_notice"
        URL_ANNOUNCEMENT[2] = "http://192.168.38.150:8081/globalNotice/get_global_notice"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        URL_ANNOUNCEMENT[1] = "http://43.130.144.246:7070/globalNotice/get_global_notice"
        URL_ANNOUNCEMENT[2] = "http://43.130.144.246:7070/globalNotice/get_global_notice"

    else
        URL_ANNOUNCEMENT[1] = "http://43.130.144.246:7070/globalNotice/get_global_notice"
        URL_ANNOUNCEMENT[2] = "http://43.130.144.246:7070/globalNotice/get_global_notice"
    end
else
    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        URL_ANNOUNCEMENT[1] = "http://192.168.38.150:8081/globalNotice/get_global_notice"
        URL_ANNOUNCEMENT[2] = "http://192.168.38.150:8081/globalNotice/get_global_notice"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        URL_ANNOUNCEMENT[1] = "https://dal-login-us.heitaoglobal.com:8082/globalNotice/get_global_notice"
        URL_ANNOUNCEMENT[2] = "https://dal-login-us.heitaoglobal.com:8082/globalNotice/get_global_notice"
    else
        URL_ANNOUNCEMENT[1] = "https://dal-login-us.heitaoglobal.com:8082/globalNotice/get_global_notice"
        URL_ANNOUNCEMENT[2] = "https://dal-login-us.heitaoglobal.com:8082/globalNotice/get_global_notice"
    end
end


