local GoogleAssetPackLayer = class("GoogleAssetPackLayer", BaseLayer)

function GoogleAssetPackLayer:ctor( )
    self:initData()
    self.super.ctor(self)
    self.strCfg = TFGlobalUtils:requireGlobalFile("lua.table.StartString")
    self:init("lua.uiconfig.googleAsset.googleAssetPackLayer")
end

function GoogleAssetPackLayer:initData( )
    self.assetPacks = {{packName = "FastFollowPackOne"},{packName = "FastFollowPackTwo"},{packName = "FastFollowPackThree"},{packName = "FastFollowPackFour"}}
    self.readyAssetPacks = {}

    self.timeDelay = 0
    self.complete = false
end

function GoogleAssetPackLayer:initUI(ui)
    self.super.initUI(self, ui)

    self.tipLabel = TFDirector:getChildByPath(ui, "label_tip")
    self.tipLabel:setText(self.strCfg[190000138].text)

    self.percentLabel = TFDirector:getChildByPath(ui, "label_percent"):hide()

    self.loadingBar = TFDirector:getChildByPath(ui, 'loadingBar')
    self.loadingBar:setPercent(0)

    self.bgImg = TFDirector:getChildByPath(ui,"img_bg")
    local path,desc = Utils:randomAD(3)
    self.bgImg:setTexture(path)

    local pDirector = CCDirector:sharedDirector()
    local frameSize = pDirector:getOpenGLView():getFrameSize()
    local baseSize = CCSize(1136 , 640)
    local realSize = CCSize(math.ceil(frameSize.width * baseSize.height / frameSize.height) , baseSize.height)
    local size = self.bgImg:getSize();
    if realSize.width > 1386 and size.width == 1386 and size.height == 640 then
        self.bgImg:setSize(realSize)
    elseif realSize.width > 1386 and size.width == 1386 then
        self.bgImg:setSize(CCSizeMake(realSize.width, size.height))
    end

    TFClientGameAssetManager:registerListener()
end

function GoogleAssetPackLayer:registerEvents()
    self:addMEListener(TFWIDGET_ENTERFRAME, self.update)
end

function GoogleAssetPackLayer:update( )
    if self.complete then return end
    if self.timeDelay <= 0 then
        self:checkAssetPackStatus()
        self.timeDelay = 120
    end
    self.timeDelay = self.timeDelay - 1
end

function GoogleAssetPackLayer:checkAssetPackStatus( )
    for i,_info in ipairs(self.assetPacks) do
        local packStatus = TFClientGameAssetManager:getAssetPackStatus(_info.packName)
        if packStatus == TFClientGameAssetManager.ASSET_UNKNOWN then
            self:displayDefault(_info.packName)
        elseif packStatus == TFClientGameAssetManager.ASSET_PENDING then

        elseif packStatus == TFClientGameAssetManager.ASSET_DOWNLOADING then
            --self:displayDownLoading(_info.packName)
        elseif packStatus == TFClientGameAssetManager.ASSET_TRANSFERRING then
            self:displayTransFerring(_info.packName)
        elseif packStatus == TFClientGameAssetManager.ASSET_COMPLETED then
            self:displayComplete(_info.packName)
        elseif packStatus == TFClientGameAssetManager.ASSET_FAILED then

        elseif packStatus == TFClientGameAssetManager.ASSET_CANCELED then
            TFClientGameAssetManager:registerListener()
        elseif packStatus == TFClientGameAssetManager.ASSET_WAITING_FOR_WIFI then

        elseif packStatus == TFClientGameAssetManager.ASSET_NOT_INSTALLED then

        end
    end

    local downLoadingPacks = {}
    for i,_info in ipairs(self.assetPacks) do
        local packStatus = TFClientGameAssetManager:getAssetPackStatus(_info.packName)
        if packStatus == TFClientGameAssetManager.ASSET_DOWNLOADING then
            local totalSize = TFClientGameAssetManager:getAssetPackTotalSize(_info.packName)
            local downLoadedSize = TFClientGameAssetManager:getAssetPackDownLoaded(_info.packName)
            local percent = 100*downLoadedSize/totalSize
            if percent < 100 then
                table.insert(downLoadingPacks, {idx = i, downLoadedPercent = percent,  packName = _info.packName})
            end
        end
    end
    table.sort(downLoadingPacks, function(a, b)
        if a.downLoadedPercent > b.downLoadedPercent then
            return true
        elseif a.downLoadedPercent < b.downLoadedPercent then
            return false
        else
            return a.idx < b.idx
        end
    end)

    if #downLoadingPacks > 0 then
        self:displayDownLoading(downLoadingPacks[1].packName)
    end
end

function GoogleAssetPackLayer:displayDefault( assetPackName )
    self.tipLabel:setText(self.strCfg[190000138].text .."(google)")
    self.percentLabel:hide()
    self.loadingBar:setPercent(0)
    self.loadingBar:hide()
end

function GoogleAssetPackLayer:displayDownLoading( assetPackName )
    local downLoadedSize = TFClientGameAssetManager:getAssetPackDownLoaded(assetPackName)
    local totalSize = TFClientGameAssetManager:getAssetPackTotalSize(assetPackName)
    local percent = 100*downLoadedSize/totalSize
    self.loadingBar:setPercent(percent)
    self.loadingBar:show()

    self.tipLabel:setText(string.format(self.strCfg[190012039].text, assetPackName))
    self.tipLabel:show()
    
    local downLoadedSizeMb = math.ceil(downLoadedSize/(1024*1024))
    local totalSizeMb = math.ceil(totalSize/(1024*1024))

    self.percentLabel:setText(string.format(self.strCfg[800093].text, percent) .." (" ..downLoadedSizeMb .."M/" ..totalSizeMb .."M)")
    self.percentLabel:show()
    
end

function GoogleAssetPackLayer:displayTransFerring( assetPackName )
    self.percentLabel:hide()
    self.loadingBar:setPercent(100)
    self.loadingBar:show()

    self.tipLabel:setText(string.format(self.strCfg[190012040].text, assetPackName))
    self.tipLabel:show()
end

function GoogleAssetPackLayer:displayComplete( assetPackName )
    if (assetPackName == nil) or (assetPackName == "") then return end
    local exit = false
    for _,_packName in ipairs(self.readyAssetPacks) do
        if _packName == assetPackName then
            exit = true
            break
        end
    end

    if not exit then
        table.insert(self.readyAssetPacks, assetPackName)
    end

    if #self.readyAssetPacks >= #self.assetPacks then
        self.complete = true
        AlertManager:changeScene(SceneType.LOGO)
    end
end

function GoogleAssetPackLayer:removeEvents()
    self.super.removeEvents(self)
end

function GoogleAssetPackLayer:onShow()
    self.super.onShow(self)
end


return GoogleAssetPackLayer