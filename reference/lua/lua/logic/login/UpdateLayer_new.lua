
require('TFFramework.net.TFClientUpdate')
local UpdateLayer_new = class("UpdateLayer_new", BaseLayer)
CREATE_SCENE_FUN(UpdateLayer_new)
CREATE_PANEL_FUN(UpdateLayer_new)
UPDATE_RETRY_TIME = 0

local ForcedUpdateUrl = {
    [121] = "http://www.9game.cn/yzjlzl/",
    [146] = "https://a.app.qq.com/o/simple.jsp?pkgname=com.tencent.tmgp.yhdzz",
    [125] = "https://game.wali.com/game/62250046",
    [137] = "https://appgallery.cloud.huawei.com/gamecentershare/app/C100390193?locale=zh_CN&shareTo=com.tencent.mobileqq&shareFrom=gamebox",
    [130] = "",
    [151] = "http://smi.datealive.com/yhdzz/maintenance",
    [305] = "https://www.biligame.com/detail/?id=101601",
    [547] = "",
    [170] = "http://app.meizu.com/games/public/detail?package_name=com.heitao.yhdzz.meizu",
    [289] = "http://dmgame.douyucdn.cn/10714_1_300_1_3.00_18_36_12.apk",
    [101] = "http://www.datealive.com",
    [682] = "http://www.datealive.com",
    [173] = "http://www.datealive.com",
    [100] = "http://www.datealive.com",
}

local TFClientUpdate =  TFClientResourceUpdate:GetClientResourceUpdate()

function UpdateLayer_new:ctor(data)
    self.super.ctor(self,data)
    self.strCfg = TFGlobalUtils:requireGlobalFile("lua.table.StartString")
    --self.config = TFGlobalUtils:requireGlobalFile("lua.table.Downlaod")
    --self.modelCfg = TFGlobalUtils:requireGlobalFile("lua.table.HeroModle")
    self._time = os.time()
    self._downloadSize  = 0
    self.connectedArray = TFArray:new()
    self:init("lua.uiconfig.loginScene.updateLayer")
end

function UpdateLayer_new:initUI(ui)
    self.super.initUI(self,ui)
    self:setName("UpdateLayer_new")
    self.ui = ui
    self.ui:setName("ui")
    self.bar_update     = TFDirector:getChildByPath(ui, 'LoadingBar')
    self.bar_update_bg  = TFDirector:getChildByPath(ui, 'loading_bg')
    self.bar_update:setPercent(0);

    self.txt_update     = TFDirector:getChildByPath(ui, 'Label_updateLayer_1')
    self.txt_update:setName("txt_update")

    self.bar_update_bg:setVisible(false)
    self.txt_update:setVisible(true)
    self.bar_update:setVisible(false)

    self.bar_load = self.bar_update
    self.bar_load:setVisible(true)
    self.bar_load:setName("bar_load")
    local index     = 1;
    local timeCount = 1;
    local loadingStr = "";

    self.bar_update_bg:setVisible(true)
    self.bar_load:setPercent(0)

    local loadInfo      = require("lua.gamedata.FileLoader"); --GetLoadFileList()
    local addLoadNum    = 0
    local maxNum        = loadInfo.total;

    self.txt_update:setText(self.strCfg[800092].text)
    self.bar_load:setPercent((addLoadNum / maxNum) * 100)

    --ui
    self.Label_hero_ename = TFDirector:getChildByPath(ui,"Label_hero_ename"):hide();
    self.Label_hero_name  = TFDirector:getChildByPath(ui,"Label_hero_name"):hide();
    self.Image_hero       = TFDirector:getChildByPath(ui,"Image_hero"):hide();
    self.Image_hero_pos   = self.Image_hero:getPosition();
    self.Image_hero_di    = TFDirector:getChildByPath(ui,"Image_hero_di"):hide();
    self.Image_hero_di_Pos= self.Image_hero_di:getPosition();
    self.Label_desc       = TFDirector:getChildByPath(ui,"Label_desc"):hide();
    self.Image_bg         = TFDirector:getChildByPath(ui,"Image_bg");
    self.zhuangshi        = TFDirector:getChildByPath(ui,"Image_updateLayer_3"):hide();
    self.zhuangshi2       = TFDirector:getChildByPath(ui,"Image_updateLayer_3(2)"):hide();
    self.Label_tips       = TFDirector:getChildByPath(ui,"Label_tips")

    TFDirector:getChildByPath(ui,"Image_updateLayer_3(3)"):hide();

    self.Label_percent    = TFDirector:getChildByPath(ui,"Label_percent");
    self.Label_percent:setText("");
    self.Label_percent_2  = TFDirector:getChildByPath(ui,"Label_percent_2");
    self.Label_percent_2:setText("");

    local pDirector = CCDirector:sharedDirector();
    local frameSize = pDirector:getOpenGLView():getFrameSize();
    local baseSize = CCSize(1136 , 640);
    self.realSize = CCSize(math.ceil(frameSize.width * baseSize.height / frameSize.height) , baseSize.height);

    self:startChangeBgTask()
    self:timeOut(function()
            self:updateVision()
        end)
    local wifiType = TFDeviceInfo:getNetWorkType()
    print("--------------------网络类型     =", wifiType)
end

function checkFile(filePath)
    if TFFileUtil:existFile(filePath) then
        return true
    end
    return false
end

function UpdateLayer_new:startChangeBgTask()
    self.Label_tips:hide()
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


function UpdateLayer_new:removeUI()
    self.super.removeUI(self)
end

function UpdateLayer_new:registerEvents()
    self.super.registerEvents(self)
end

function UpdateLayer_new:removeEvents()
    self.super.removeEvents(self)
    ADD_KEYBOARD_CLOSE_LISTENER(self, self.ui)
end


function UpdateLayer_new:checkForcedUpdate()

    -- 去掉强更逻辑 2020-0928
    if true then
        return false;
    end

    local version       =  TFClientUpdate:getCurVersion()
    local LatestVersion =  TFClientUpdate:getLatestVersion()      
    local old = string.split(version, ".")
    local new = string.split(LatestVersion, ".")

    print("===========checkForcedUpdate===========")
    print("version          = ", version)
    print("LatestVersion    = ", LatestVersion)
    dump({old = old,new = new});
    print("=============== end ==================")

    local okhandle = function()
        if CC_TARGET_PLATFORM ~= CC_PLATFORM_WIN32 then
            local id = tonumber(HeitaoSdk.getplatformId()) % 10000;
            local url = ForcedUpdateUrl[id];
            if id and id ~= "" then
                TFDeviceInfo:openUrl(url);
            end
        end
        me.Director:endToLua()
    end

    -- if tonumber(new[1]) > tonumber(old[1]) then
    --     showMessageBox( TextDataMgr:getText(111000100) , EC_MessageBoxType.ok,okhandle)
    --     return true
    -- end

    return false;
end

function UpdateLayer_new:updateVision()
    Utils:sendHttpLog("hotfix_check")
    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
        restartLuaEngine("CompleteUpdate")
        return 
    end
    --暂时屏蔽热更检测
    -- if true then
    --     restartLuaEngine("CompleteUpdate")
    --     return 
    -- end

    -- do
    --     restartLuaEngine("CompleteUpdate")
    -- end

    local sizeX = self.bar_load:getSize().width
    local function downloadingRecvData(downloadingSize, totalSize)
        local size1 = math.floor(downloadingSize/1024)
        local size2 = math.floor(totalSize/1024)

        local nRate = (size1 / size2)*100
        if nRate > 100 then
            nRate = 100
        end
        
        nRate  = math.floor(nRate)
        local time     = os.time()
        local passTime = time - self._time
        if passTime >= 5 or nRate == 100 then 
            local offsetSize      = downloadingSize - self._downloadSize
            local speed           = math.floor((offsetSize/1024)/math.max(0.01,passTime))
            self._time            = time
            self._downloadSize    = downloadingSize       
            local info = {}
            info.size  = size1
            info.totalSize       = size2
            info.rate            = nRate
            info.speed           = tostring(speed).."kb/s"
            Utils:sendHttpLog("hotfix_ing",false,CDN_INDEX,nil,info)
        end
        self.bar_load:setPercent(nRate)
        self.Label_percent:setText(string.format(self.strCfg[800093].text, nRate));
        self.Label_percent_2:setText(string.format(self.strCfg[800094].text, size1, size2));
    end

    local function startUpdate()
        self._downloadSize  = 0
        self._time  = os.time()
        Utils:sendHttpLog("hotfix_download_zip",false,CDN_INDEX)
        self.txt_update:setText(self.strCfg[800095].text)
        TFClientUpdate:startDownloadZip(downloadingRecvData)
    end

    local function checkNewVersionCallBack()

        if self:checkForcedUpdate() then
            return;
        end

        local version       =  TFClientUpdate:getCurVersion()
        local LatestVersion =  TFClientUpdate:getLatestVersion()
        local Content       =  TFClientUpdate:GetUpdateContent(TFLanguageMgr:getUsingLanguage())
        
        --有新版资源需要更新
        local info = {} 
        info.version       = version
        info.latestVersion = LatestVersion
        Utils:sendHttpLog("hotfix_new_version",false,CDN_INDEX,0,info)
        print("===========find new version===========")
        print("version          = ", version)
        print("LatestVersion    = ", LatestVersion)
        print("Content          = ", Content)
        --print("totalSize        = ", totalSize)
        print("=============== end ==================")

        local totalSize     =  TFClientUpdate:GetTotalDownloadFileSize()

        local nTotalSize  = totalSize
        nTotalSize = nTotalSize/1000000
        local desc = "";
        if nTotalSize >= 0.1 then
            desc = string.format(" %0.1fM", nTotalSize);
        else
            desc = string.format(" %0.1fK", nTotalSize * 1000);
        end

        --local title = "检测到有新的更新内容，共"..desc
        local title = string.format(self.strCfg[800096].text,desc)

        local params = {
            _type    = 1,
            sizeDesc = desc,
            callfunc = startUpdate,
            Content  = Content,
            LatestVersion = LatestVersion
        }
        local layer = require("lua.logic.login.DownLoadingTips"):new(params)
        AlertManager:addLayer(layer,nil,AlertManager.TWEEN_1)
        AlertManager:show()

        --startUpdate();
    end

    local function StatusUpdateHandle(ret)
        -- body
        print("ret --- ",ret)
        -- 更新完成，或者当前版本已经是最新的了
        -- Utils:sendHttpLog("update_state_"..tostring(ret))
        if ret == 0 then
            local version       =  TFClientUpdate:getCurVersion()
            local LatestVersion =  TFClientUpdate:getLatestVersion()        
            print("version          = ", version)
            print("LatestVersion    = ", LatestVersion)
            print("---------------更新完成")
            print("---------------加载本地文件")
            --热更完成
            Utils:sendHttpLog("hotfix_complete",false,CDN_INDEX, ret)
            self.Label_percent:setText("");
            self.Label_percent_2:setText("");
            self.bar_load:setPercent(0);
            restartLuaEngine("CompleteUpdate")
            return

        elseif ret == 1 then
            --热更解压
            Utils:sendHttpLog("hotfix_unzip" ,false,CDN_INDEX, ret)
            print("---------------下载完成准备解压资源")
            local desc  = self.strCfg[800097].text
            self.txt_update:setText(desc)
            self.Label_percent_2:setText("");
        elseif ret == -14 then
            Utils:sendHttpLog("hotfix_fail",false,CDN_INDEX, ret)
            if not self:checkForcedUpdate() then
                self:showFailDiag(errorType);
            end
        elseif ret < 0 then
            --热更失败
            Utils:sendHttpLog("hotfix_fail",false,CDN_INDEX, ret)
            print("---------------更新出错 ret = "..ret)
            if CDN_INDEX < #URL_CDN_VERSION then
                self:restart();
            else
                self:showFailDiag(ret)
            end
        end

    end
    if CDN_INDEX == 0 then
        CDN_INDEX = 1;
    end
    print("new--------------------versionPath  = ", URL_CDN_VERSION[CDN_INDEX])
    print("new--------------------filePath     = ", URL_CDN_FILE[CDN_INDEX])
    self:checkCdnAndUrlUpdate(URL_CDN_VERSION[CDN_INDEX])
    TFClientUpdate:CheckUpdate(URL_CDN_VERSION[CDN_INDEX], URL_CDN_FILE[CDN_INDEX], checkNewVersionCallBack, StatusUpdateHandle)
end
-- type == 1检查失败 type == 2 更新失败
function UpdateLayer_new:showFailDiag(errorType)
    local function restart()
        self:restart();
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

function UpdateLayer_new:restart()
    UPDATE_RETRY_TIME = (UPDATE_RETRY_TIME or 0) + 1

    if UPDATE_RETRY_TIME % 2 == 0 then
        CDN_INDEX = CDN_INDEX + 1;
        if CDN_INDEX > #URL_CDN_VERSION then
            CDN_INDEX = 1
        end
    end
    --下载重试次数
    Utils:sendHttpLog("hotfix_retry_"..tostring(UPDATE_RETRY_TIME),false, CDN_INDEX)
    local UpdateLayer_new   = require("lua.logic.login.UpdateLayer_new")
    AlertManager:changeScene(UpdateLayer_new:scene())
end

function UpdateLayer_new:EnterGame()
    restartLuaEngine("CompleteUpdate")
end

function UpdateLayer_new:CompleteUpdate()
    if self.timeId == nil then
        local function update(delta)
            me.Director:getScheduler():unscheduleScriptEntry(self.timeId)
            self.timeId = nil
            self:EnterGame()
        end
        self.timeId = me.Scheduler:scheduleScriptFunc(update, 0.5, false)
    end
end

function UpdateLayer_new:checkCdnAndUrlUpdate(url )
    -- self.connectedArray:push(url)
    -- local time = 0
    -- for urlValue in self.connectedArray:iterator() do
    --     if urlValue == url then
    --         time = time + 1
    --     end
    -- end

    -- if HeitaoSdk and time <= 1 then
    --     local tfUrl = require("TFFramework.net.TFUrl")
    --     if tfUrl then
    --         local parsed_url = tfUrl.parse(url)
    --         HeitaoSdk.reportNetworkData(parsed_url.host)
    --     end
    -- end
end

return UpdateLayer_new