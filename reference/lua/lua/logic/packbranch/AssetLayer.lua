
local AssetLayer = class("AssetLayer", BaseLayer)
--资源检车UI
function AssetLayer:ctor( )
    self.super.ctor(self)
    self.strCfg = TFGlobalUtils:requireGlobalFile("lua.table.StartString")
    self:init("lua.uiconfig.common.extAssetsDownloadView")
end

function AssetLayer:initUI(ui)
    self.super.initUI(self, ui)
    -- self.label_title = TFDirector:getChildByPath(self.root_panel,"label_title")
    -- self.label_title:setText(self.strCfg[190000138].text)
    -- self.Image_bg    = TFDirector:getChildByPath(ui,"img_bg")
    -- local pDirector  = CCDirector:sharedDirector()
    -- local frameSize  = pDirector:getOpenGLView():getFrameSize()
    -- local baseSize   = CCSize(1136 , 640)
    -- self.realSize    = CCSize(math.ceil(frameSize.width * baseSize.height / frameSize.height) , baseSize.height)


    self.root_panel = TFDirector:getChildByPath(ui,"Panel_root")
    self.Image_bg = TFDirector:getChildByPath(self.root_panel,"Image_bg")
    -- self.Image_bg    = TFDirector:getChildByPath(ui,"img_bg")
    local pDirector  = CCDirector:sharedDirector()
    local frameSize  = pDirector:getOpenGLView():getFrameSize()
    local baseSize   = CCSize(1136 , 640)
    self.realSize    = CCSize(math.ceil(frameSize.width * baseSize.height / frameSize.height) , baseSize.height)

    self.loadingbar = TFDirector:getChildByPath(self.root_panel,"LoadingBar_process")
    self.txt_speed = TFDirector:getChildByPath(self.root_panel,"Label_speed")
    self.txt_fileSize = TFDirector:getChildByPath(self.root_panel,"Label_filesize")
    self.tipLabel = TFDirector:getChildByPath(self.root_panel,"Label_title")
    --计时器
    self.time = 0
    --正在下载补充资源
    self:startChangeBgTask()

    self:checkUpdate()
end

--state 0 检查更新  1 下载扩展资源 2 解压资源

function AssetLayer:changeState(state)
    if self.state == state then 
        return 
    end
    self.state = state
    if self.state == 0  then --补充资源检查
        self.tipLabel:setText(self.strCfg[190000138].text)  
        self.txt_speed:setText("")
        self.txt_fileSize:setText("")
        self.loadingbar:setPercent(0)
    elseif self.state == 1 then --资源下载
        self.tipLabel:setText(self.strCfg[190000146].text)
        self.txt_speed:setText("")
        self.txt_fileSize:setText("")
        self.loadingbar:setPercent(0)
    elseif self.state == 2 then --资源解压
        self.tipLabel:setText(self.strCfg[800097].text)  --下载完成解压资源
        self.txt_speed:setText("")
        self.txt_fileSize:setText("")
        self.loadingbar:setPercent(0)
    elseif self.state == 3 then
        self.tipLabel:setText(self.strCfg[190000138].text)  
        self.txt_speed:setText("")
        self.txt_fileSize:setText("")
        self.loadingbar:setPercent(0)
    end
end

function AssetLayer:checkUpdate()
    self:changeState(0)
    AssetsMgr:checkUpdate()
end

function AssetLayer:startChangeBgTask()
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

function AssetLayer:transNetSpeed(speed)
    local speedstr = "0b/s"
    if speed < 1024 then
        speedstr = string.format("%.2fkb/s",speed)
    else
        speedstr = string.format("%.2fMb/s",speed/1024)
    end
    return speedstr
end

function AssetLayer:getInterval()
   if self.state == 1 then
        return 0.5
    elseif self.state == 2 then
        return 0.5
    elseif self.state == 3 then 
        return 0.2
    end 
    return 1
end

function AssetLayer:update(target , dt)
    self.time = self.time + dt
    if self.time < self:getInterval() then 
        return 
    end 

    self.time = 0
    if self.state == 1 then
        self:refreshDownloadProgress()
    elseif self.state == 2 then
        self:refreshUnzipProgress()
    elseif self.state == 3 then 
        self:refreshCheckProgress();
    end 
end

--刷新更新进度
function AssetLayer:refreshDownloadProgress()
    local downloadInfo = AssetsMgr:getDownloadProgress()
    -- dump(downloadInfo)
    self.txt_speed:setString(self:transNetSpeed(downloadInfo.speed))
    local totalsize = downloadInfo.totalSize
    local curSize = downloadInfo.completeSize
    local totalSizeStr = Utils:tranFileSize(totalsize)
    local curSizeStr = Utils:tranFileSize(curSize)
    self.txt_fileSize:setString(curSizeStr.." / "..totalSizeStr)
    self.loadingbar:setPercent(curSize/totalsize *100)
end


function AssetLayer:refreshUnzipProgress()
    local uncompressInfo = AssetsMgr:getUncompressProgress()
    local totalsize = uncompressInfo.totalSize
    local curSize   = uncompressInfo.completeSize
  
    self.tipLabel:setText(self.strCfg[190000885].text .." (" ..curSize .."/" ..totalsize ..")")
    -- self.txt_fileSize:setText("")
    -- self.txt_speed:setString("")
    if totalsize > 0 then 
        self.loadingbar:setPercent(curSize/totalsize *100)
    else
        self.loadingbar:setPercent(100)
    end
end

function AssetLayer:refreshCheckProgress()
    local checkInfo = AssetsMgr:getCheckProgress()
    local totalsize = checkInfo.totalSize
    local curSize   = checkInfo.completeSize
  
    self.tipLabel:setText(self.strCfg[190000138].text .." (" ..curSize .."/" ..totalsize ..")")
    -- self.txt_fileSize:setText("")
    -- self.txt_speed:setString("")
    if totalsize > 0 then 
        self.loadingbar:setPercent(curSize/totalsize *100)
    else
        self.loadingbar:setPercent(100)
    end
end



function AssetLayer:registerEvents()
    EventMgr:addEventListener(self, "DOWNLOAD_START", handler(self.onAssetDownloadStart, self))
    EventMgr:addEventListener(self, "UNZIP_START", handler(self.onUncompressStart, self))
    EventMgr:addEventListener(self, "CHECK_START", handler(self.onCheckStart, self))


    self:addMEListener(TFWIDGET_ENTERFRAME,handler(self.update,self))
end

function AssetLayer:removeEvents()
    
end

function AssetLayer:onShow()
    self.super.onShow(self)

end

function AssetLayer:onExit()
 
end

function AssetLayer:dispose()
  
end

function AssetLayer:onUncompressStart()
    self:changeState(2)
end

function AssetLayer:onCheckStart()
    self:changeState(3)
end

function AssetLayer:onAssetDownloadStart()
    self:changeState(1)

end

return AssetLayer



-- if EX_ASSETS_ENABLE == 1 then 
    --     TFAssetsManager:downloadFullAssets(function()
    --         AlertManager:changeScene(SceneType.LOGO)
    --     end,function ()
    --         me.Director:endToLua() --必要资源，取消下载的情况下退出游戏
    --     end)
    -- elseif EX_ASSETS_ENABLE == 2 then 
    --     --后台静默下载
    --     TFAssetsManager:downloadAssetsNormal(true)
    --     AlertManager:changeScene(SceneType.LOGO)
    -- elseif EX_ASSETS_ENABLE == 3 then 
    --     Utils:sendHttpLog("assets_a_start")
    --     local checkExtId = TFAssetsManager:getCheckInfo(100)
    --     if checkExtId then
    --         TFAssetsManager:downloadAssetsOfFunc(checkExtId, function ()
    --             Utils:sendHttpLog("assets_a_complet")
    --            AlertManager:changeScene(SceneType.LOGO) 
    --         end ,true,function()
    --             Utils:sendHttpLog("assets_a_exit")
    --             self:timeOut(function ()
    --                 me.Director:endToLua() --必要资源，取消下载的情况下退出游戏
    --             end,2)
    --         end)
    --     else
    --         Utils:sendHttpLog("assets_a_notfound_config")
    --         AlertManager:changeScene(SceneType.LOGO)
    --     end
    -- end