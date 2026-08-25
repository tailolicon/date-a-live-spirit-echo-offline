
local PackBranchLayer = class("PackBranchLayer", BaseLayer)

function PackBranchLayer:ctor( )
    self.super.ctor(self)
    self.strCfg = TFGlobalUtils:requireGlobalFile("lua.table.StartString")
    self:init("lua.uiconfig.common.FirstExtAssetsDownLayer")

    TFAssetsManager:init(0)
    TFAssetsManager:runManager()

    self.firstShow = true
end

function PackBranchLayer:initUI(ui)
    self.super.initUI(self, ui)

    self.label_title = TFDirector:getChildByPath(ui,"label_title")
    self.label_title:setText(self.strCfg[190000138].text)

    self.Image_bg   = TFDirector:getChildByPath(ui,"img_bg")
    local pDirector = CCDirector:sharedDirector()
    local frameSize = pDirector:getOpenGLView():getFrameSize()
    local baseSize = CCSize(1136 , 640)
    self.realSize = CCSize(math.ceil(frameSize.width * baseSize.height / frameSize.height) , baseSize.height)
    self:startChangeBgTask()
end


function PackBranchLayer:startChangeBgTask()
    
    self.Image_bg:setTexture(Utils:nextADImage()) 
    local size = self.Image_bg:getSize();
    if self.realSize.width > 1386 and size.width == 1386 and size.height == 640 then
        self.Image_bg:setSize(self.realSize)
    elseif self.realSize.width > 1386 and size.width == 1386 then
        self.Image_bg:setSize(CCSizeMake(self.realSize.width,size.height))
    end
    self:timeOut(function()
        self:startChangeBgTask()
    end ,10)

end

function PackBranchLayer:registerEvents()
    if EX_ASSETS_ENABLE > 0 then
        EventMgr:addEventListener(self, EV_EXT_ASSET_DOWNLOAD_EXTLIST, handler(self.downLoadExtListFileSuc, self))
    end
end

function PackBranchLayer:removeEvents()
    
end

function PackBranchLayer:onShow()
    self.super.onShow(self)

    if not self.firstShow then
        return 
    end
    self.firstShow = false
    if EX_ASSETS_ENABLE > 0 then 
        return 
    end
    DelayCall(function()
        AlertManager:changeScene(SceneType.LOGO)
    end,1)
end

function PackBranchLayer:onExit()
 
end

function PackBranchLayer:dispose()
  
end

--[[
    根据语言获得小包资源配置ID
]]
function PackBranchLayer:getFuncIDByLangCode(langCode)
    local funcID = 46
    if (langCode == cc.SIMPLIFIED_CHINESE) then
        funcID = 41
    elseif (langCode == cc.GERMAN) then
        funcID = 42
    elseif (langCode == cc.SPANISH) then
        funcID = 43
    elseif (langCode == cc.FRENCH) then
        funcID = 44
    elseif (langCode == cc.INDONESIAN) then
        funcID = 45
    elseif (langCode == cc.ENGLISH) then
        funcID = 46
    elseif (langCode == cc.KOREAN) then
        funcID = 47
    elseif (langCode == cc.THAI) then
        funcID = 48
    elseif (langCode == cc.TRADITIONAL_CHINESE) then
        funcID = 49
    end
    return funcID
end

function PackBranchLayer:downLoadExtListFileSuc()
    if EX_ASSETS_ENABLE == 1 then 
        TFAssetsManager:downloadFullAssets(function()
            AlertManager:changeScene(SceneType.LOGO)
        end,function ()
            me.Director:endToLua() --必要资源，取消下载的情况下退出游戏
        end)
    elseif EX_ASSETS_ENABLE == 2 then 
        --后台静默下载
        TFAssetsManager:downloadAssetsNormal(true)
        AlertManager:changeScene(SceneType.LOGO)
    elseif EX_ASSETS_ENABLE == 3 then 
        Utils:sendHttpLog("assets_a_start")
        local checkExtId = TFAssetsManager:getCheckInfo(100)
        if checkExtId then
            TFAssetsManager:downloadAssetsOfFunc(checkExtId, function ()
                Utils:sendHttpLog("assets_a_complet")
               AlertManager:changeScene(SceneType.LOGO) 
            end ,true,function()
                Utils:sendHttpLog("assets_a_exit")
                self:timeOut(function ()
                    me.Director:endToLua() --必要资源，取消下载的情况下退出游戏
                end,2)
            end)
        else
            Utils:sendHttpLog("assets_a_notfound_config")
            AlertManager:changeScene(SceneType.LOGO)
        end
    end
end

return PackBranchLayer