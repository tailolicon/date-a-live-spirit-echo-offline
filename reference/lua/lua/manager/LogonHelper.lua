local LogonHelper = class("LogonHelper")


local UserCenterHttpClient = TFClientNetHttp:GetInstance()

function LogonHelper:ctor(data)
    self.urlIdx = 0
    self.path = ""
    self.connectedArray = TFArray:new()

    self.account_ = nil
    self.password_ = nil
    self.code_ = nil
    self.isAuto_ = false
    self.isLogined = false;

    -- self.serverName_ = self:getCacheServerName()
    -- self.serverGroup_ = self:getCacheGroupName()

    if HeitaoSdk then
        HeitaoSdk.setLoginOutCallBack(function()
                self:HeitaoSdkLoginOutCallBack()
            end)

        HeitaoSdk.setLogincallback(function(code, msg)
                self:HeitaoSdkLoginCallback(code, msg)
            end)
    end
end

function LogonHelper:HeitaoSdkLoginCallback(code, msg)
    if not HeitaoSdk then return end
    --处理回调函数
    --[[
    dump(msg)
    -- if msg == "登录失败" then
    if msg == TextDataMgr:getText(800107) then
    -- elseif msg == "登录成功" then
    elseif msg == TextDataMgr:getText(800108) then
        --self:loginVerification();
        dump("EventMgr:dispatchEvent(LoginLayer.LoginSuccess)")
        Utils:sendHttpLog("sdk_login")
        EventMgr:dispatchEvent("LoginLayer.LoginSuccess")
    end
    --]]
    print("login callback "..tostring(code) .."   " ..tostring(msg))
    if code == HeitaoSdk.LOGIN_IN_SUC  then 
        --登录成功
        dump("EventMgr:dispatchEvent(LoginLayer.LoginSuccess)")
        Utils:sendHttpLog("sdk_login")
        EventMgr:dispatchEvent("LoginLayer.LoginSuccess")
    else  --     result == HeitaoSdk.LOGIN_IN_FAI
        --登录失败
    end
end

function LogonHelper:HeitaoSdkLoginOutCallBack()
    CommonManager:closeConnection2()
end

function LogonHelper:restart()
end

function LogonHelper:restartGame(tips)
    local function callback()
        restartLuaEngine("")
    end
    showMessageBox(tips , EC_MessageBoxType.okAndCancel,callback,callback)
end

local TFClientUpdate =  TFClientResourceUpdate:GetClientResourceUpdate()
-----历史账户登录 （登录成功过/存在账户信息/合法的测试服分组信息）
function LogonHelper:localAutoLogin()
    if ServerDataMgr:getIsActivat() then
        --获取历史登录的账号密码
        local account,password = ServerDataMgr:getUserInfo()
        dump({account,password})
        if not string.isNullOrEmpty(account) then  
            self:login(account,password,nil)
        end
    end
end

function LogonHelper:getLoginUrl()
    local url = URL_LOGIN[1]
    if GameConfig.Debug or RELEASE_TEST then --debug 模式使用测试地址
        local serverGroupConfig = ServerDataMgr:getDebugServer()
        if serverGroupConfig and serverGroupConfig.url then
            url = serverGroupConfig.url
        end
    end
    return url
end

function LogonHelper:getOsName()
    local osname = "IOS"
    if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        osname = "IOS"
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        osname = "ANDROID"
    end
    return osname
end



function LogonHelper:getToken()
    if HeitaoSdk then 
        return HeitaoSdk.gettoken()
    end
    if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        return TFDeviceInfo:getDeviceToken()
    end
    return "NULL"
end


function LogonHelper:getuserid()
    if HeitaoSdk then 
        return HeitaoSdk.getuserid()
    end
    return self.account_ or ""
end

function LogonHelper:getplatformId()
    return Utils:getplatformId()
end

function LogonHelper:getVersion()
    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 or VERSION_DEBUG  then
        return "" 
    end
    local token   = self:getToken()
    local version = md5.sumhexa("@#156qazxswedc7*$%#@!*&2dduebvgrelas"..token..(TFDeviceInfo:getMachineOnlyID(1) or "1")..TFClientUpdate:GetUpdateDefaultVersion())
    return version
end


-- {
-- [LUA-print] [03/25/24 16:56:17]  -     "data"   = "{"serverInfos":[{"serverName":"bt_game1","state":0,"areaId":0}]}"
-- [LUA-print] [03/25/24 16:56:17]  -     "msg"    = "SUCCESS"
-- [LUA-print] [03/25/24 16:56:17]  -     "status" = 0
-- [LUA-print] [03/25/24 16:56:17]  - }

--本地测试返回服务器列表
function LogonHelper:login(account,password,code)
    showLongLoading()
    self.account_ = account
    self.password_ = password 
    self.code_ = code
    self.loginCallback = function (type,ret,data)
        hideAllLoading()
        data = json.decode(data)
        dump(data)
        if not data then
            self.isLogined = false
            -- toastMessageLink("连接登录服务器失败")
            toastMessageLink(TextDataMgr:getText(800114))
            return
        end
        --游戏资源需要更新
        if data.status and data.status == 100017 then
            self:restartGame(data.msg);
            return;
        end
        --账号封停
        if data.status and data.status == 100037 then
            EventMgr:dispatchEvent("LoginLayer.AcountBan")
            return
        end

        if data.status ~= 0 then
            self.isLogined = false;
            local text = TextDataMgr:getText(data.status)
            if data.status == 100036 then
                text = text.."  "..tostring(data.msg)
            end
            Utils:showTips(text)
            ServerDataMgr:saveIsActivat(false)
        else
            if not data.data then
                return
            end
            self.isLogined = true
            --self:loadUserProtoState()-- 载入本地用户协议状态
            --保存服务器数据
            ServerDataMgr:setGameServerList(data.data.serverInfos)
            ServerDataMgr:saveToLocal(self.account_,self.password_)
            ServerDataMgr:saveIsActivat(true)
            EventMgr:dispatchEvent(EV_GAMESERVER_REFRESH)
            EventMgr:dispatchEvent("LoginLayer.LoginSuccess")
        end
    end


    local osname      = self:getOsName()
    local token       = self:getToken()
    local platformId  = self:getplatformId()
    local version     = self:getVersion()
    local userid      = self:getuserid()
    local size = CCDirector:sharedDirector():getOpenGLView():getFrameSize()
    local url = self:getLoginUrl()
    url = url.."/getServerInfo"
    url = url.."?token="..string.url_encode(token)
    url = url.."&accountId="..string.url_encode(userid)
    url = url.."&deviceid="..string.url_encode(((TFDeviceInfo:getMachineOnlyID(1)) or 1))
    url = url.."&osVersion="..string.url_encode(((TFDeviceInfo:getSystemVersion()) or 1))
    url = url.."&osName="..string.url_encode(osname)
    url = url.."&networkType="..string.url_encode((TFDeviceInfo:getNetWorkType()))
    url = url.."&networkCarrier="..string.url_encode((TFDeviceInfo:getCarrierOperator()) or "")
    url = url.."&screenWidth="..string.url_encode((size.width))
    url = url.."&screenHeight="..string.url_encode((size.height))
    url = url.."&appVersion="..string.url_encode((TFDeviceInfo:getCurAppVersion()))
    url = url.."&version="..string.url_encode(TFClientUpdate:getCurVersion())
    url = url.."&sdkVersion=".."";
    url = url.."&sdk=".."";
    url = url.."&channelAppId="..string.url_encode(platformId % 10000)
    url = url.."&myVersion="..string.url_encode(version)

    if FileCheckMgr then
        url = url.."&mimi="..FileCheckMgr:getIsSuccess();
    end    
    if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        url = url.."&deviceName="..string.url_encode(((TFDeviceInfo:getDeviceModel()) or 1))
        url = url.."&devicebrand="..string.url_encode("Apple");
        url = url.."&idfa="..string.url_encode(((TFDeviceInfo:getMachineOnlyID(1)) or 1))
        url = url.."&idfv="..string.url_encode(((TFDeviceInfo:getIDFV()) or 1));
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        url = url.."&deviceName="..string.url_encode(((TFDeviceInfo:getSystemName()) or 1))
        url = url.."&devicebrand="..string.url_encode(TFDeviceInfo:getMachineName())
        url = url.."&imei="..string.url_encode(((TFDeviceInfo:getIMEI()) or 1))
        url = url.."&androidid="..string.url_encode(((TFDeviceInfo:getAndroidId()) or 1))
    end

    if self.password_ and self.password_ ~= "" then 
        url = url.."&password="..string.url_encode(self.password_)
    end
    if self.code_ and self.code_ ~= "" then
        url = url.."&activateKey="..string.url_encode(self.code_)
    end

    --测试服
    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 or RELEASE_TEST or VERSION_DEBUG then
        -- if self.serverName_ then
        --     url = url.."&serverName="..self.serverName_;
        -- end
        local debugServer = ServerDataMgr:getDebugServer()
        if debugServer then
            url = url.."&serverGroup=" .. debugServer.group;
        else
            url = url.."&serverGroup=".."us_develop";
        end
        -- url = url.."&serverGroup=".."ios_check";


        url = url.."&channelId=".."LOCAL_TEST";
    else --正式服
        url = url.."&serverGroup=".."ios_check";
        url = url.."&channelId=".."HEI_TAO";
    end
    
    url = string.gsub(url," ","")
    print("getServer URL:"..url)
    UserCenterHttpClient:addMERecvListener(self.loginCallback)
    UserCenterHttpClient:httpRequest(TFHTTP_TYPE_GET,url)
end

--授权获取游戏服地址并进入游戏服
function LogonHelper:authorize()
    -- if ServerDataMgr:getCurrentServerID()  < 0 then --服务器列表没有选择
    --     Utils:showTips(800090)
    --     return
    -- end
    local serverInfo = ServerDataMgr:getServerInfo()
    if not serverInfo then  --未选择服务器
        Utils:showTips(800090)
        return
    end 
    --服务器维护中
    if serverInfo.state == 1 then 
        if not string.isNullOrEmpty(serverInfo.notice) then 
            Utils:showTips(serverInfo.notice)
        else
            Utils:showTips(100036)
        end
        return 
    end
    showLongLoading()
    self.authorizeCallback = function (type,ret,data)
        hideAllLoading()
        data = json.decode(data)
        dump(data)
        if not data then
            toastMessageLink(TextDataMgr:getText(800114))
            return
        end
        --游戏资源需要更新
        if data.status and data.status == 100017 then
            self:restartGame(data.msg)
            return
        end

        --账号封停
        if data.status and data.status == 100037 then
            EventMgr:dispatchEvent("LoginLayer.AcountBan")
            return
        end

        if data.status ~= 0 then
            local text = TextDataMgr:getText(data.status)
            if data.status == 100036 then
                text = text.."  "..data.msg
            end
            Utils:showTips(text)
            ServerDataMgr:saveIsActivat(false)
        else
            if not data.data then
                print("server data 不存在")
                return
            end

            print("server Tip:"..tostring(data.data.tip))
            ServerDataMgr:setServerData(data.data)
            --非官服才弹框
            --if not Utils:isOfficialChannel() then 
                --更新用户协议同意状态
                --self:updateUserProtoState(data.data.tip == 1)
                --检查用户协议是否同意
                --if self:checkOpenUserProto() then 
                    --return 
                --end
            --end


            --进入游戏服务
            Utils:sendHttpLog("server_connect_M")
            CommonManager:loginServer(true) 

             --  "data" = {
             --     "gameServerIp"   = "192.168.38.88"
             --     "gameServerPort" = 10086
             --     "groupName"      = "约战BT1"
             --     "group_id"       = 101
             --     "hasRole"        = false
             --     "serverId"       = 101001
             --     "tip"            = 0
             --     "token"          = "101_dbe78ed76fa2aa664b405345809a6d26"
             -- }
             -- "msg"    = "SUCCESS"
             -- "status" = 0
 


        end
    end

    -- local osname = self:getOsName()
    -- local token = self:getToken()

    -- local serverGroupConfig = ServerDataMgr:getDebugServers(self.serverGroup_)
    -- local url = self:getLoginUrl()
    -- url = url.."/login"
    -- url = url.."?accountId="..string.url_encode(self.account_);
    -- url = url.."&password="..(self.password_ or "");
    -- url = url.."&token="..token
    -- url = url.."&deviceid="..((TFDeviceInfo:getMachineOnlyID(1)) or 1);
    -- url = url.."&deviceName="..((TFDeviceInfo:getSystemName()) or 1);
    -- url = url.."&osVersion="..((TFDeviceInfo:getSystemVersion()) or 1);
    -- url = url.."&osName="..osname;
    -- url = url.."&version="..TFClientUpdate:getCurVersion();
    -- url = url.."&sdkVersion=".."";
    -- url = url.."&sdk=".."";
    -- url = url.."&serverId="..ServerDataMgr:getCurrentServerID()
    -- if FileCheckMgr then
    --     url = url.."&mimi="..FileCheckMgr:getIsSuccess();
    -- end
    -- url = url.."&channelAppId="..1;
    -- url = url.."&channelId=".."LOCAL_TEST";




    local osname      = self:getOsName()
    local token       = self:getToken()
    local platformId  = self:getplatformId()
    local version     = self:getVersion()
    local userid      = self:getuserid()
    local serverId    = ServerDataMgr:getCurrentServerID()
    local size = CCDirector:sharedDirector():getOpenGLView():getFrameSize()
    local url = self:getLoginUrl()
    url = url.."/login"
    url = url.."?token="..string.url_encode(token)
    url = url.."&accountId="..string.url_encode(userid)
    url = url.."&deviceid="..string.url_encode(((TFDeviceInfo:getMachineOnlyID(1)) or 1))
    url = url.."&osVersion="..string.url_encode(((TFDeviceInfo:getSystemVersion()) or 1))
    url = url.."&osName="..string.url_encode(osname)
    url = url.."&networkType="..string.url_encode((TFDeviceInfo:getNetWorkType()))
    url = url.."&networkCarrier="..string.url_encode((TFDeviceInfo:getCarrierOperator()) or "")
    url = url.."&screenWidth="..string.url_encode((size.width))
    url = url.."&screenHeight="..string.url_encode((size.height))
    url = url.."&appVersion="..string.url_encode((TFDeviceInfo:getCurAppVersion()))
    url = url.."&version="..string.url_encode(TFClientUpdate:getCurVersion())
    url = url.."&sdkVersion=".."";
    url = url.."&sdk=".."";
    url = url.."&channelAppId="..string.url_encode(platformId % 10000)
    url = url.."&myVersion="..string.url_encode(version)
    url = url.."&serverId="..string.url_encode(serverId)

    if FileCheckMgr then
        url = url.."&mimi="..FileCheckMgr:getIsSuccess();
    end    
    if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
        url = url.."&deviceName="..string.url_encode(((TFDeviceInfo:getDeviceModel()) or 1))
        url = url.."&devicebrand="..string.url_encode("Apple");
        url = url.."&idfa="..string.url_encode(((TFDeviceInfo:getMachineOnlyID(1)) or 1))
        url = url.."&idfv="..string.url_encode(((TFDeviceInfo:getIDFV()) or 1));
    elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
        url = url.."&deviceName="..string.url_encode(((TFDeviceInfo:getSystemName()) or 1))
        url = url.."&devicebrand="..string.url_encode(TFDeviceInfo:getMachineName())
        url = url.."&imei="..string.url_encode(((TFDeviceInfo:getIMEI()) or 1))
        url = url.."&androidid="..string.url_encode(((TFDeviceInfo:getAndroidId()) or 1))
    end

    if self.password_ and self.password_ ~= "" then 
        url = url.."&password="..string.url_encode(self.password_)
    end
    if self.code_ and self.code_ ~= "" then
        url = url.."&activateKey="..string.url_encode(self.code_)
    end

    --测试服
    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 or RELEASE_TEST or VERSION_DEBUG then
        url = url.."&channelId=".."LOCAL_TEST";
    else --正式服
        url = url.."&channelId=".."HEI_TAO";
    end
    url = string.gsub(url," ","")
    print("Login:"..url)
    UserCenterHttpClient:addMERecvListener(self.authorizeCallback)
    UserCenterHttpClient:httpRequest(TFHTTP_TYPE_GET,url)
end





function LogonHelper:getIsLogin()
    return self.isLogined;
end

function LogonHelper:setIsLogin(islogin)
    self.isLogined = islogin;
    if not islogin then
        self._isVerification = false;
    end
end

function LogonHelper:isVerification()
    return self._isVerification;
end

function LogonHelper:setVerification(Verification)
    self._isVerification = Verification;
end

--切换测试服
function LogonHelper:switchLogin(groupName)
    if ServerDataMgr:getServerGroup() ~= groupName then 
        ServerDataMgr:setServerGroup(groupName)
        self:setIsLogin(false)
    end
end


function LogonHelper:setLogoutFlag(flag)
    self.logoutFlag = flag
end


function LogonHelper:checkDebugServer()

end




-- function LogonHelper:getServerName()
--     return self.serverName_
-- end

-- function LogonHelper:getGroupName()
--     return self.serverGroup_
-- end

-- function LogonHelper:LoginUcCenterFailHandler( localUrl )
--     local urlList = URL_LOGIN
--     if localUrl then
--         urlList = localUrl
--     end

--     if self.connectedArray:length() >= 2*#urlList then
--         hideAllLoading()
--         toastMessageLink(TextDataMgr:getText(800114))
--         return
--     end
--     TimeOut(function()
--         self:tryLoginUcCenter()
--     end, 2)
-- end

-- function LogonHelper:tryLoginUcCenter( localUrl )
--     local urlList = URL_LOGIN
--     if localUrl then
--         urlList = localUrl
--     end

--     self.urlIdx = self.urlIdx + 1
--     if self.urlIdx > #urlList then
--         self.urlIdx = 1
--     end

--     self.connectedArray:push(urlList[self.urlIdx])
--     UserCenterHttpClient:addMERecvListener(self.loginCallback)
--     UserCenterHttpClient:httpRequest(TFHTTP_TYPE_GET, urlList[self.urlIdx] ..self.path)
--     print(urlList[self.urlIdx] ..self.path)

--     Utils:sendHttpLog("UTC_connect")

-- end


return LogonHelper:new()
--[[强制更新66234]]