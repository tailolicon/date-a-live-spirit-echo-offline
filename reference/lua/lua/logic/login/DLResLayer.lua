
require('TFFramework.net.TFClientUpdate')
local DLResLayer = class("DLResLayer", BaseLayer)
CREATE_SCENE_FUN(DLResLayer)
CREATE_PANEL_FUN(DLResLayer)
UPDATE_RETRY_TIME = 0
local TFClientUpdate =  TFClientResourceUpdate:GetClientResourceUpdate()

--多语言资源下载更新

local LangCfg = 
{
{ name= "English",        lang = cc.ENGLISH  , assetName = "en" },
{ name= "Français",       lang =  cc.FRENCH ,  assetName = "fr" },
{ name= "Deutsch",        lang = cc.GERMAN ,   assetName = "de"},
{ name= "Español",        lang = cc.SPANISH ,  assetName = "es"},
{ name= "ภาษาไทย",         lang = cc.THAI ,     assetName = "th"},
{ name= "IndonesiaName",  lang = cc.INDONESIAN ,assetName = "id"},
{ name= "한국어",          lang = cc.KOREAN ,    assetName = "ko"},
{ name= "繁體中文",        lang = cc.TRADITIONAL_CHINESE ,assetName = "zh"},
{ name= "简体中文",        lang =  cc.SIMPLIFIED_CHINESE  ,assetName = "cn"},
{ name= "Việt nam",        lang =  cc.VIETNAM  ,assetName = "vi"},
}



function DLResLayer:ctor(data)
    self.super.ctor(self,data)
    self:initData()
    self:init("lua.uiconfig.secondary.uiconfig_zn.loginScene.resUpdateLayer")
end

function DLResLayer:initUI(ui)
    self.super.initUI(self,ui)
    -- self:setName("DLResLayer")
    self:setName("UpdateLayer_new")
    self.ui = ui
    self.ui:setName("ui")


    self.Image_bg       = TFDirector:getChildByPath(ui, 'Image_bg')
    self.panel_update   = TFDirector:getChildByPath(ui, 'Panel_update')

    self.Label_tips       = TFDirector:getChildByPath(self.panel_update,"Label_tips")

    self.loadBarBg  = TFDirector:getChildByPath(  self.panel_update, 'loading_bg')
    self.loadBar    = TFDirector:getChildByPath(  self.panel_update, 'LoadingBar')
    self.txt_update  = TFDirector:getChildByPath(self.panel_update, 'Label_txt_update')

        self.txt_update:setName("txt_update")
        self.loadBar:setName("bar_load")
    self.Label_percent    = TFDirector:getChildByPath(self.panel_update,"Label_percent");
    self.Label_percent_2  = TFDirector:getChildByPath(self.panel_update,"Label_percent_2");
    self.Label_percent:setText("");
    self.Label_percent_2:setText("");
    self.Label_tips:setText("")
    self.loadBar:setPercent(0)

    --正在检查资源更新
    self.txt_update:setText("")

    --self.txt_update:setText(self.strCfg[800092].text)

    self.Panel_select   = TFDirector:getChildByPath(ui, 'Panel_select')
    self.Label_desc     = TFDirector:getChildByPath( self.Panel_select, 'Label_desc')
    self.Button_cancel  = TFDirector:getChildByPath( self.Panel_select, 'Button_cancel')
    self.Button_sure    = TFDirector:getChildByPath( self.Panel_select, 'Button_sure')
    self.Label_text     = TFDirector:getChildByPath( self.Button_sure, 'Label_text')
    self.Label_text:setText(self.strCfg[800010].text)
    self.btnLangs   = {}
    
    for i=1,10 do
        local node  = {}
        node.btn    = TFDirector:getChildByPath(self.Panel_select, 'Image_lang'..i)
        node.select = TFDirector:getChildByPath(node.btn , 'Image_select')
        node.text   = TFDirector:getChildByPath(node.btn , 'Label_lang')
        local lang  = LangCfg[i]
        node.lang   = lang
        node.text:setText(node.lang.name)
        table.insert(self.btnLangs,node)
        node.btn:onClick(function ()
            self.selectLang = node.lang
            self:refreshLangSelect()
        end)
    end

    --105 版本之后增加了越南语资源下载
    -- local resVerValue = tonumber(GAME_LANG_RES_VERSION)
    -- if resVerValue <= 105 then 
    --     self.btnLangs[10].btn:hide()
    --     self.btnLangs[10].btn:setTouchEnabled(false)
    -- end
    --Box("version : " ..GAME_LANG_RES_VERSION) 

    if self.strCfg[190012043] then 
        self.Label_desc:setText(self.strCfg[190012043].text)
    else
        self.Label_desc:setText("The app language defaults to English when you close this window \n You can switch languages in [Settings] at any time during app usage")
    end

    self.Panel_select:hide()

    -- self:showLangSelect()


    local pDirector = CCDirector:sharedDirector();
    local frameSize = pDirector:getOpenGLView():getFrameSize();
    local baseSize = CCSize(1136 , 640);
    self.realSize = CCSize(math.ceil(frameSize.width * baseSize.height / frameSize.height) , baseSize.height);
    --设置背景
    self:startChangeBgTask()    
    --倒计时
    self:timeOut(function ()
        Utils:sendHttpLog("lang_assets_check")
        if not self:isChecked() then 
            self:setChecked()
            self:changeState(0)
        else
            self:changeState(1)
        end
    end ,0.1)
end

--是否是收次进入
function DLResLayer:isChecked()
    return CCUserDefault:sharedUserDefault():getIntegerForKey(self:getKey("checked"), 0) == 1
end


function DLResLayer:setChecked()
    CCUserDefault:sharedUserDefault():setIntegerForKey(self:getKey("checked"), 1)
    CCUserDefault:sharedUserDefault():flush()
end

function DLResLayer:getKey(keyName)
    return self.baseKey..keyName
end

function DLResLayer:startChangeBgTask()
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



function DLResLayer:initData()
    self.appVersion   = TFDeviceInfo:getCurAppVersion()

    GAME_LANG_RES_VERSION = GAME_LANG_RES_VERSION or "102"
    print_("GAME_LANG_RES_VERSION:" ..tostring(GAME_LANG_RES_VERSION))
    -- URL_LANG_RES[1] ="http://192.168.22.236/distributions/"
    self.baseUrl = URL_LANG_RES[1]..GAME_LANG_RES_VERSION .."/%s.awb"
    self.strCfg = TFGlobalUtils:requireGlobalFile("lua.table.StartString")
    self.baseKey = string.format("lang_asset_%s_%s_",self.appVersion,GAME_LANG_RES_VERSION)

    --根据平台初始化扩展资源保存路径
    local writablePath = CCFileUtils:sharedFileUtils():getWritablePath()
    self.assetsSavePath = ""
    if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        self.assetsSavePath = writablePath .. '../Library/TFDebug/'
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        self.assetsSavePath = writablePath .. 'TFDebug/'
    else
        self.assetsSavePath = writablePath .. "../Library/TFDebug/"
    end
    --目录不存在的情况下创建目录
    if not TFFileUtil:existFile(self.assetsSavePath) then
        TFFileUtil:createDir(self.assetsSavePath)
    end
    --当前使用语言
    self.targetLang = TFLanguageMgr:getUsingLanguage()


    self:checkCleanUp()
end
--检查资源是否已经被清理
function DLResLayer:checkCleanUp()
    local cleanup = CCUserDefault:sharedUserDefault():getIntegerForKey("_cleanUp", 0)
    if cleanup == 1 then 
        CCUserDefault:sharedUserDefault():setIntegerForKey("_cleanUp", 0)
        for i,v in ipairs(LangCfg) do
            self:setAssetState(v.lang,0)
        end
    end
end

--0 未下载 1 已下载 2 已解压
function DLResLayer:setAssetState(lang,value)
    local key = self:getKey(lang)
    CCUserDefault:sharedUserDefault():setIntegerForKey(key, value)
    CCUserDefault:sharedUserDefault():flush()
end

function DLResLayer:getAssetState(lang)
    if lang == cc.ENGLISH or lang == cc.SIMPLIFIED_CHINESE then 
        return 2
    end
    if lang == cc.VIETNAM then 
        local resVerValue = tonumber(GAME_LANG_RES_VERSION)
        if resVerValue <= 105 then 
            return 2
        end
    end

    local key = self:getKey(lang)
    return CCUserDefault:sharedUserDefault():getIntegerForKey(key, 0)
end

-- --检查需要下载的文件列表
-- function TFAssetsManager:checkAssetsDownload(checkList)
--     for k,v in pairs(checkList) do
--         local localfilepath = self:getAwbFileName(k)
--         if TFFileUtil:existFile(localfilepath) or (self:getAwbState(tonumber(k)) > 0) then
--             checkList[tonumber(k)] = 0
--             local tmppath = string.format("%s%d.temp",self.extAssetsSavePath,tonumber(k))
--             if TFFileUtil:existFile(tmppath) then
--                 os.remove(tmppath)
--             end
--         end
--     end


--首次 询问下载
--检查 当前选择的语言是否需要下载 



function DLResLayer:refreshLangSelect()
    for i,v in ipairs(self.btnLangs) do
       v.select:setVisible(v.lang == self.selectLang)
    end
    -- local state = self:getAssetState(self.selectLang.lang)
    self.Button_sure:setVisible(true)
end

function DLResLayer:showLangSelect()
   self.selectLang = self.selectLang or LangCfg[1]
   self.Panel_select:show()
   self:refreshLangSelect()
end

function DLResLayer:hideLangSelect()
    self.Panel_select:hide()
end

function DLResLayer:removeUI()
    self.super.removeUI(self)
end

function DLResLayer:registerEvents()
    self.super.registerEvents(self)
    self.Button_sure:onClick(function ()
        self:hideLangSelect()
        self.targetLang = self.selectLang.lang
        self:changeState(1)
  
    end)
    self.Button_cancel:onClick(function ()
        self.Panel_select:hide()
        self:doCancel()
    end)
end
function DLResLayer:removeEvents()
    self.super.removeEvents(self)
end


--取消资源下载
function DLResLayer:doCancel()
--检查当前使用的语言资源是否存在
--存在的进入游戏 ，不存在的 切换英文进入游戏
    self.targetLang  = cc.ENGLISH
    self:changeState(4)
end


function DLResLayer:changeState(state)
    if self.state ~= state then  
        self.state = state 
        if self.state == 0 then  --首次进入 资源选择下载
            self:showLangSelect()
    
            self.Label_tips:setText("")
            self.loadBar:setPercent(0)
            self.Label_percent:setText("");
            self.Label_percent_2:setText("");
            self.txt_update:setText(self.strCfg[190000138].text)            --正在检查资源更新
        elseif self.state == 1 then --资源检测
            self.Label_tips:setText("")
            self.loadBar:setPercent(0)
            self.Label_percent:setText("");
            self.Label_percent_2:setText("");
            --正在检查资源更新
            self.txt_update:setText(self.strCfg[190000138].text)
            local state =  self:getAssetState(self.targetLang) 
            if state == 2 then  --完成 
                self:changeState(4)
            else
                self:changeState(2)
            end
        elseif self.state == 2 then --资源下载 
            self.txt_update:setText(self.strCfg[190000146].text)
    --     id = 800093,
    --     text = "已完成%d%%",
            local assetName = self:getAssetName(self.targetLang)
            self:startDownLoad(assetName)
        elseif self.state == 3 then  --资源解压
            self.txt_update:setText(self.strCfg[190000885].text)
            self.loadBar:setPercent(0)
            self.Label_percent:setText("");
            self.Label_percent_2:setText("");
            local assetName = self:getAssetName(self.targetLang)
            self:unzip(assetName)
        elseif self.state == 4 then  --完成
            self.Label_tips:setText("")
            self.loadBar:setPercent(0)
            self.Label_percent:setText("");
            self.Label_percent_2:setText("");
            self:CompleteUpdate()
        end
    end
end



function DLResLayer:getAssetName(lang)
    for i,v in ipairs(LangCfg) do
        if v.lang == lang then 
            return v.assetName
        end
    end
    return LangCfg[1].assetName
end

function DLResLayer:startDownLoad(assetName)
 
    local task = {
        url        = string.format(self.baseUrl,assetName),   --下载地址
        fileName   = string.format("%s.temp",assetName),   --文件名称
        folderPath = self.assetsSavePath,     --保存路径
        autoRetryTimes = 0,                      --重试次数
    }
    local tempPath =  task.folderPath..task.fileName
    if TFFileUtil:existFile(tempPath) then
        os.remove(tempPath)
    end
    print("tempPath:" ..tempPath)
    dump(task)
    print("即将开始下载:"..tostring(assetName))
    DownloadHelper:start(json.encode(task),
        handler(self.onRemoteFileFind,self),
        handler(self.onFileDownloading,self),
        handler(self.onFileDownloadRetry,self),
        handler(self.onFileDownloaded,self),
        handler(self.onFileDownloadFailed,self))
    --切换到下载状态
end


function DLResLayer:onFileDownloaded(info)
    print("onFileDownloaded")
    info = json.decode(info)
    local tmppath  = info.filePath
    local filePath = string.gsub(tmppath,".temp",".awb")
    if TFFileUtil:existFile(filePath) then
        os.remove(filePath)
    end
    os.rename(tmppath,filePath)
    if TFFileUtil:existFile(filePath) then
        self:setAssetState(self.targetLang,1)
    end
    self:changeState(3)
end


--

function DLResLayer:onRemoteFileFind()
    print("找到下载资源")
end

function DLResLayer:onFileDownloadRetry()
    print("下载重试")
end

--资源下载中
function DLResLayer:onFileDownloading(info)
    info = json.decode(info)
    local  downloadedSize  = info.downloadedSize or 0
    local  totalSize       = info.fileSize or 1
    local  downloadSpeed   = info.downloadSpeed   
    -- print(info)
    local nRate = math.floor(downloadedSize*100/totalSize)
    self.loadBar:setPercent(nRate)
    self.Label_percent:setText(string.format(self.strCfg[800093].text, nRate));  --完成进度   "已完成%d%%", 
    self.Label_percent_2:setText(string.format(self.strCfg[800094].text, downloadedSize, totalSize));   -- 下载速度 "%dKB/%dKB",

end

--下载失败
function DLResLayer:onFileDownloadFailed()
    print("下载失败")
    -- self:showFailDiag(2)
    self.Label_percent:setText(self.strCfg[111000052].text)  --资源下载失败 
    self.Label_percent_2:setText("")
end

--解压下载的资源包
function DLResLayer:unzip(assetName)
    print("开始解压"..tostring(assetName))
    --解压完成
    local completeCallBack = function( filePath )
        print("TFClientAwbBundle unzipFiles  success!!!! filePath: " ..tostring(filePath))
        if TFFileUtil:existFile(filePath) then       
            local t ,erro = os.remove(filePath)
            print("remove awb: ".. tostring(t) .. " "..tostring(erro))
        else
            print("remove awb  fail , not exist ")
        end
        self.txt_update:setText(self.strCfg[190000887].text)
        self:setAssetState(self.targetLang,2)
        self:changeState(4)
    end
    --解压失败
    local failedCallBack = function( status )
        print("TFClientAwbBundle unzipFiles  failed!!!! ")
        self.txt_update:setText(self.strCfg[190000886].text)
    end

    TFClientAwbBundle:defaultAwbBundle():unzipFiles(assetName ..".awb", completeCallBack, failedCallBack)
end
-- type == 1检查失败 type == 2 更新失败
function DLResLayer:showFailDiag(errorType)
    local function restart()
        -- self:restart();
    end
    local params = {
        _type    = 2,
        sizeDesc = desc,
        callfunc = restart
    }
    local layer = require("lua.logic.login.DownLoadingTips"):new(params)
    AlertManager:addLayer(layer,nil,AlertManager.TWEEN_1)
    AlertManager:show()
    layer.isCanNotClose = true
end



function DLResLayer:CompleteUpdate()
    if self.timeId then 
        return
    end
    local function update(delta)
        me.Director:getScheduler():unscheduleScriptEntry(self.timeId)
        self.timeId = nil
        local lang = TFLanguageMgr:getUsingLanguage()
        print("当前使用:"..tostring(lang) .." 选择语言:"..tostring(self.targetLang))
        if self.targetLang ~= lang then 
            TFLanguageMgr:setUsingLanguage(self.targetLang)
            restartLuaEngine("CompleteLangAssetUpdate")
        else
           AlertManager:changeScene(SceneType.LOGO) 
        end
    end

    self.timeId = me.Scheduler:scheduleScriptFunc(update, 0.1, false)
    -- Box("CompleteUpdate")
    -- AlertManager:changeScene(SceneType.LOGO)
end

return DLResLayer