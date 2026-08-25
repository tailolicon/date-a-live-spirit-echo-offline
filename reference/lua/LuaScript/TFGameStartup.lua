--[[--
    游戏启动器:

    --By: yun.bo
    --2013/7/8
]]

CCLog_setDebugFileEnabled(0)



SINGLE_LANG_VERSION = false
-- if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
--     if not TFFileUtil:existFile("lua/table/secondary/vi/String.lua") then 
--         SINGLE_LANG_VERSION = true
--     end
-- else
--     SINGLE_LANG_VERSION = true
-- end

-- -- 单语言版本判定
-- if SINGLE_LANG_VERSION then 
--     TFLanguageMgr:setUsingLanguage( cc.TRADITIONAL_CHINESE )
--     NEW_APP_VERSION = false
-- end

 -- TFLanguageMgr:setUsingLanguage( cc.TRADITIONAL_CHINESE )
--扩展资源下 0 不开启 /1开启进游戏强制下载 / 2开启按需动态下载 /3 强制下载部分其他按需下载
EX_ASSETS_ENABLE = 0


if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID   then
    EX_ASSETS_ENABLE = 3
end


-- 如果是模拟器则直接打开调试模式
if not (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32) then
    --非win32下只做日志输出
    Box = function( ... )
        print(...)
    end
end


CDN_INDEX    = 0;

local __addMEListener = CCNode.addMEListener
local function addMEListener(sender, nType, handle, clickEffectType)
    local self = sender
    if nType == TFWIDGET_CLICK then

        if sender.haveAddMEListener == nil then
            -- 判断是否在滚动页面中
            local function isInScrl(node)
                local parent = node:getParent();
                if parent then
                    local nodetype = tolua.type(parent)
                    -- print("nodetype",nodetype,sender:getName())
                    if nodetype == 'TFScrollView' or nodetype == 'TFTableViewCell' or nodetype == 'TFPageView' then
                        -- print("isInScrl true")
                        return true;
                    else
                        return isInScrl(parent);
                    end
                else
                    -- print("isInScrl false")
                    return false;
                end
            end


            if isInScrl(sender) then
                -- sender:setClickAreaLength(10);
            else
                sender:setClickAreaLength(100);
            end


            clickEffectType = clickEffectType or 0;
            if tolua.type(sender) == 'TFButton' and clickEffectType == 1 then
                sender:setClickScaleEnabled(true)
                sender:setClickHighLightEnabled(false)
            end

            sender.haveAddMEListener = true;
        end

        local function tHandle(sender, ...)
            -- sender:setTouchEnabled(false)
            -- TFDirector:setTouchEnabled(false);
            -- if sender.timeOut then
            --     local nDT  = 0
            --     sender:timeOut(function()
            --         sender:setTouchEnabled(true)
            --     end, nDT)
            -- end

            local function timerCom()
                TFDirector:setTouchEnabled(true);
            end
            -- TFDirector:addTimer(0, 1, nil, timerCom);

            handle(sender, ...)
        end
        __addMEListener(self, nType, tHandle)
    else
        __addMEListener(self, nType, handle)
    end
end
rawset(CCNode, "addMEListener", addMEListener)


if CC_TARGET_PLATFORM ~= CC_PLATFORM_IOS then
    --重写TFLabel setFontSize方法
    --处理跨平台字体大小不一致的情况

    local ios_width = 528;
    local ios_height = 29;

    local testLabel = TFLabel:create()
    testLabel:setText("中中中中中中中中中中中中中中中中中中中中中中")
    testLabel:setFontSize(24)
    local testSize = testLabel:getSize();

    local scale_width = ios_width/testSize.width;
    local scale_height = ios_height/testSize.height;
    -- scale_width = math.min(1,scale_width);
    -- scale_height = math.min(1,scale_height);

    -- local scale = math.min(scale_width,scale_height);

    local scale = scale_width

    local __MELabel_setFontSize = TFLabel.setFontSize
    local function TFLabel_setFontSize(obj,size)
        __MELabel_setFontSize(obj,math.floor(size * scale))
    end
    rawset(TFLabel, "setFontSize", TFLabel_setFontSize)


    local __METextArea_setFontSize = TFTextArea.setFontSize
    local function TFTextArea_setFontSize(obj,size)
        __METextArea_setFontSize(obj,math.floor(size * scale))
    end
    rawset(TFTextArea, "setFontSize", TFTextArea_setFontSize)


    local __METextField_setFontSize = TFTextField.setFontSize
    local function TFTextField_setFontSize(obj,size)
        __METextField_setFontSize(obj,math.floor(size * scale))
    end
    rawset(TFTextField, "setFontSize", TFTextField_setFontSize)

    local __MERichText_create = TFRichText.create
    local function TFRichText_create(obj,size)
        local obj_new = __MERichText_create(obj,size)
        obj_new:setScale(scale);
        return obj_new;
    end
    rawset(TFRichText, "create", TFRichText_create)

    local __MERichText_setScale = CCNode.setScale
    local function TFRichText_setScale(obj,_scale)
        __MERichText_setScale(obj,_scale * scale)
    end
    rawset(TFRichText, "setScale", TFRichText_setScale)
end

function setClickScaleEnabled(sender,isEnabled)
    -- sender:setClickScaleEnabled(isEnabled)
    -- sender:setClickHighLightEnabled(not isEnabled)
end

local TFGameStartup = class('TFGameStartup')

--


function TFGameStartup:startGame1()
    CCDirector:sharedDirector():setDisplayStats(true)
    TFResolution:setResolutionRect(960, 640, 960, 640)
    AlertManager:changeScene(SceneType.LOGIN)
end

function TFGameStartup:startGame()
    CCDirector:sharedDirector():setDisplayStats(true)
    TFResolution:setResolutionRect(1300, 780, 1300, 780)
    AlertManager:changeScene('M_pro.LuaScript.scene.server.ServerScene')
end

function TFGameStartup.completeHandle(szversion, szName , nLen ,nLeft, nMax)
    if nLeft == 0 then
        TFGameStartup:startGame1()
        return
    end
end

function TFGameStartup:run(strrest)
    print("TFGameStartup.run : "..tostring(strrest))
    TFDirector:setTouchEnabled(true);

    if TFClientResourceUpdate == nil then
        print("---TFGameStartup:run 没有最新的资源更新功能")

    else
        print("---TFGameStartup:run 有最新的资源更新功能")
    end
    print("{英语(en)，法语(fr)，德语(de)，西班牙语(es)，泰语(th)，印尼语(id)，韩语(ko)，简体中文(zn)，繁体中文(zh)，越南语(vi)} using language = " ..tostring(TFLanguageMgr:getUsingLanguage())  .. " code= " ..tostring(TFLanguageMgr:getUsingLanguageCode()))

    print("Lang "..tostring(TFLanguageMgr:getUsingLanguageCode()) .." : "..tostring(TFLanguageMgr:getUsingLanguage()))

    -- SCREEN_ORIENTATION_PORTRAIT --竖屏
    -- SCREEN_ORIENTATION_LANDSCAPE --横屏
    if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        -- TFLuaOcJava.setScreenOrientation(SCREEN_ORIENTATION_LANDSCAPE)
    end

    -- TFClientUpdate:SetUpdateDefaultVersion("1.2.0")

    local pDirector = CCDirector:sharedDirector();

    -- local frameSize = pDirector:getOpenGLView():getFrameSize()
    -- print("frameSize = ", frameSize)

    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        local width = CCUserDefault:sharedUserDefault():getIntegerForKey("fenbianlvX")
        local height = CCUserDefault:sharedUserDefault():getIntegerForKey("fenbianlvY")
        pDirector:getOpenGLView():setFrameSize(width, height);
        -- pDirector:getOpenGLView():setFrameSize(1024, 768);
        -- pDirector:getOpenGLView():setFrameSize(1280, 720);
        --pDirector:getOpenGLView():setFrameSize(2436 * 0.6   , 1125 * 0.6);
        -- pDirector:getOpenGLView():setFrameSize(960, 640);
        -- mi pad
        --pDirector:getOpenGLView():setFrameSize(2048 * 0.6, 1536 * 0.6);
    end

    --适配方案实现  by ghd
    local frameSize = pDirector:getOpenGLView():getFrameSize();
    local baseSize = CCSize(1136 , 640);

     local realSize = CCSize(math.ceil(frameSize.width * baseSize.height / frameSize.height) , baseSize.height);

    -- if (realSize.width >= 1136)  then
    --    --背景图片最长为1136，所以设置上限
    --    pDirector:getOpenGLView():setDesignResolutionSize(1136, realSize.height, kResolutionShowAll);
    if (realSize.width >= baseSize.width) then
        --960 - 1136，通过对齐等方案，实现适配
        pDirector:getOpenGLView():setDesignResolutionSize(realSize.width, realSize.height, kResolutionShowAll);
    else
        -- realSize = CCSize(baseSize.width, math.ceil(frameSize.height * baseSize.width / frameSize.width));
        -- pDirector:getOpenGLView():setDesignResolutionSize(realSize.width, realSize.height, kResolutionShowAll);

        --UI制作安全大小为960，所以设置下限
        pDirector:getOpenGLView():setDesignResolutionSize(baseSize.width, realSize.height, kResolutionShowAll);
    end

    --pDirector:getOpenGLView():setDesignResolutionSize(baseSize.width, baseSize.height, kResolutionShowAll);

    -- use multiple touch event
    TFDirector:setTouchSingled(true)

    -- turn on display FPS
    pDirector:setDisplayStats(false);

    --set FPS. the default value is 1.0/60 if you don't call this
    pDirector:setAnimationInterval(1.0 / 60.0);


    -- -- TF_DEBUG_UPDATE_FLAG == 1 or
    -- -- if TF_DEBUG_UPDATE_FLAG == 1 or  CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 or strrest == "CompleteUpdate" then
     --    collectgarbage("stop")
        -- TFLuaTime:b()
     --    require('lua.gameinit')
        -- TFLuaTime:e("Init: ")
     --    collectgarbage("collect")
     --    TFDirector:changeScene:changeScene(SceneType.LOGIN)
    -- -- else
    -- --     self:initSDK()
    -- -- end

    -- self:enterGameWithUpdate()

    self:initSDK()

    self.MainPlayLoadOver = function(event)
       if self.func then
            self.func()
       end
    end

    TFDirector:addMEGlobalListener("MainPlayer.LoadOver", self.MainPlayLoadOver)
    --Box("strrestL:"..tostring(strrest))
    -- 资源更新检查完成走这个逻辑

    if strrest == "CompleteLangAssetUpdate" then
        -- Box("CompleteLangAssetUpdate")
        self:loadGameInitFile(function ()
            AlertManager:changeScene(SceneType.LOGO)
        end)
        return
    elseif strrest == "CompleteUpdate" then
        print("============检查更新完成 CompleteUpdate==============")
        self:loadGameInitFile(function ()
            if  CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
                local UpdateLayer = require("lua.logic.login.DLResLayer")
                AlertManager:changeScene(UpdateLayer:scene())
            elseif  CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then  
                AlertManager:changeScene(SceneType.PACKBRANCH)
            else
                AlertManager:changeScene(SceneType.LOGO)
            end
        end)
        return
    elseif strrest == "EnterGame" then
        print("============显示完默认界面马上进入游戏 EnterGame==============")
        self:loadGameInitFile(function ()
            local UpdateLayer   = require("lua.logic.login.UpdateLayer_new")
            AlertManager:changeScene(UpdateLayer:scene())
        end)
        return
    else
        print("============进入游戏 默认界面 ==============")
        self:loadGameInitFile(function ()
            if TFFileUtil:existFile("default/defultdisplay.lua") then
                print("进入默认界面")
                AlertManager:changeScene(SceneType.DEFAULT)
            -- 直接进入游戏逻辑
            else
                print("进入游戏界面")
                local UpdateLayer   = require("lua.logic.login.UpdateLayer_new")
                AlertManager:changeScene(UpdateLayer:scene())
            end
            
        end, true)
    end


    if me.Director.setAutoFreeEnabled and me.platform == "android" then
        me.isAutoFreeRes = true
        me.Director:setAutoFreeEnabled(true, 150, 33)
    end

end


function TFGameStartup:initSDK()
    --showLoading()
    local function onSdkPlatformLogout()
        print("onSdkPlatformLogout")
        MainPlayer:reset()
        AlertManager:clearAllCache()
        CommonManager:closeConnection()
        AlertManager:changeScene(SceneType.LOGIN)
    end

    if HeitaoSdk then
        print("---TFGameStartup setLoginOutCallBack ----")
        HeitaoSdk.setLoginOutCallBack(onSdkPlatformLogout)
    end
end

local ix = 0
function TFGameStartup:loadGameInitFile( func, loadBasedata )
    ix = ix + 1;
    print("TFGameStartup:loadGameInitFile ... "..ix);
    if self.loadGameInitTimer then
        TFDirector:removeTimer(self.loadGameInitTimer)
        self.loadGameInitTimer = nil
    end

    self.func = func

    local szGameInitFile = {
        "lua.UtilHelper",
        "lua.gameinit",
        "lua.gameinitPart1",
        "lua.gameinitPart2",
    }
    local addCount = 3
    if loadBasedata then
        szGameInitFile = nil
        szGameInitFile = {"lua.UtilHelper","lua.gameinit"};
        addCount = 1
        require(szGameInitFile[1])
        require(szGameInitFile[2])
        if func then
            func()
        end
    else
        require(szGameInitFile[1])
        require(szGameInitFile[2])
        require(szGameInitFile[3])
    end
end
return TFGameStartup
--[[强制更新66234]]
