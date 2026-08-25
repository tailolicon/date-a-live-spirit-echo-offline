require('TFFramework.net.TFClientUpdate')
local TFClientUpdate =  TFClientResourceUpdate:GetClientResourceUpdate()

local LoginLayer = class("LoginLayer", BaseLayer)

function LoginLayer:ctor(data)
    self.super.ctor(self,data)
    self.isShowLoingBoard = data;
    self.isEnter = false;
    EventMgr:addEventListener(self, EV_LOGIN_UPDATESERVERNAME, handler(self.refreshDebugServer, self))

    EventMgr:addEventListener(self, EV_GAMESERVER_REFRESH, handler(self.onGameServerRefresh, self))
	self:init("lua.uiconfig.loginScene.loginLayerNew1")

end

function LoginLayer:initUI(ui)
	self.super.initUI(self,ui)
	self.ui = ui
	LoginLayer.ui = ui


	self.continue = TFDirector:getChildByPath(ui,"continue");
	self.continue:setTextById(800086)
	local tween =
	    {
	        target = self.continue,
	        repeated = -1,
	        {
            	duration = 1,
            	alpha 	 = 0,
	    	},

	        {
            	duration = 1,
            	alpha 	 = 1,
	    	},
	    }
	TFDirector:toTween(tween)

	self.loginBoard = TFDirector:getChildByPath(ui,"loginBoard");
	self.loginBoard:setVisible(false);

	self.versionLabel = TFDirector:getChildByPath(ui,"version")
	local versionTex = "version:1.01_1.0.01"
	if not (CC_TARGET_PLATFORM == CC_PLATFORM_WIN32) then
		local apkVersion = TFDeviceInfo:getCurAppVersion()
		local updateZipVersion = TFClientUpdate:getCurVersion()
		versionTex = "version:" ..apkVersion .."_" ..updateZipVersion
	end
	self.versionLabel:setText(versionTex)

	self.apkVersionLabel = TFDirector:getChildByPath(ui,"label_apkVersion"):hide()


	self.touchLayer = TFDirector:getChildByPath(ui,"backLayer");
	self.touchLayer:setTouchEnabled(true);
	self.touchLayer.logic = self;
	self.touchLayer:addMEListener(TFWIDGET_CLICK, audioClickfun(function ( ... )
		self:onClickNext()
	end))

	self.chooseImge = {}
	for i=1,3 do
		local Image_shurudi  = TFDirector:getChildByPath(ui,"Image_shurudi"..i)
		self.chooseImge[i]  = TFDirector:getChildByPath(Image_shurudi,"Image_choose")
	end
	
	self.accountInput  = TFDirector:getChildByPath(ui,"account_input");
	self.passwordInput = TFDirector:getChildByPath(ui,"password_input");
	self.codeInput 	   = TFDirector:getChildByPath(ui,"code_input");
	self.Button_closeLogin = TFDirector:getChildByPath(ui,"Button_closeLogin");

	self.passwordInput:setPlaceHolder(TextDataMgr:getText(800087));
	self.passwordInput:setText("");
	self.accountInput:setPlaceHolder(TextDataMgr:getText(800087));
	self.codeInput:setPlaceHolder(TextDataMgr:getText(800088));

	self.loginBtn = TFDirector:getChildByPath(ui,"Button_login");
	self.actBtn   = TFDirector:getChildByPath(ui,"Button_activation");
	self.loginBtn:addMEListener(TFWIDGET_CLICK,audioClickfun(function ( ... )
		self:loginBtnCallback();
	end))
	self.actBtn:addMEListener(TFWIDGET_CLICK,audioClickfun(function ( ... )
		self:loginBtnCallback();
	end))

	self.accountBtn = TFDirector:getChildByPath(ui,"TextButton_account");
	self.accountBtn:setVisible(self:isLocalTest())
	self.accountBtn:addMEListener(TFWIDGET_CLICK,audioClickfun(function ()
			if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
				self:showLoingBoard()
			end
		end));

	self.Button_User_proto = TFDirector:getChildByPath(ui,"Button_User_proto")
	if self.Button_User_proto then
		--TODO CLOSE
		-- self.Button_User_proto:getChildByName("Label_user_proto"):setSkewX(5)
		-- self.Button_User_proto:addMEListener(TFWIDGET_CLICK,audioClickfun(function ()
		-- 	Utils:openView("login.UserProto")
		-- end));
		self.Button_User_proto:hide()
	end

	self.Button_Conceal_proto = TFDirector:getChildByPath(ui,"Button_Conceal_proto")
	if self.Button_Conceal_proto then
		self.Button_Conceal_proto:hide()
	end

	self.Button_notice = TFDirector:getChildByPath(ui,"Button_notice")
	self.Button_notice:getChildByName("Label_notice"):setSkewX(5)
	--TODO CLOSE
	if CC_TARGET_PLATFORM ~= CC_PLATFORM_WIN32 then
		-- self.Button_notice:addMEListener(TFWIDGET_CLICK,audioClickfun(function ()
		-- 	self:openNewNoticeLayer()
		-- end));
		self.Button_notice:hide()
	else
		self.Button_notice:hide()
	end
	self.accountBtn:setPosition(self.Button_notice:getPosition())
	self.cleanUpBtn = TFDirector:getChildByPath(ui,"Button_cleanup");
	self.cleanUpBtn:getChildByName("Label_cleanup"):setSkewX(5)
	self.cleanUpBtn:addMEListener(TFWIDGET_CLICK,audioClickfun(function ()
		--Utils:openView("login.CleanUpView")
		local fullModuleName = string.format("lua.logic.%s", "login.CleanUpView")
	    local view = requireNew(fullModuleName):new()
	    self:addLayer(view,998)
	    self.cleanUpView = view
	end));

	self.cleanUpBtn:setPosition(self.Button_User_proto:getPosition())
	self.thanksBtn = TFDirector:getChildByPath(ui,"Button_thanks");
	self.thanksBtn:hide()
	--TODO CLOSE
	-- self.thanksBtn:addMEListener(TFWIDGET_CLICK,audioClickfun(function ()

	-- 		local currentScene = Public:currentScene();
	-- 		--currentScene:removeVideoView();

	-- 		TFAudio.pauseMusic();

	-- 		if CC_PLATFORM_IOS == CC_TARGET_PLATFORM then
	-- 			currentScene:changeVideo("video/thanks.mp4");
	-- 		else
	-- 			MovieScene:create({
	-- 				path = "video/thanks.mp4",
	-- 				showSkip = true,
	-- 				endCall = function() 
	-- 					TFAudio.resumeMusic()
	-- 					TimeOut(function()
	-- 							currentScene:showVideoView(true);
	-- 						end,0)
	-- 				end
	-- 			})
	-- 		end
	-- 	end));

	self.Button_pv = TFDirector:getChildByPath(ui,"Button_pv");
	self.Button_pv:getChildByName("Label_pv"):setSkewX(5)
	local vedioPath = "video0/openpv.mp4"
	self.Button_pv:addMEListener(TFWIDGET_CLICK,audioClickfun(function ()
		local currentScene = Public:currentScene();
		TFAudio.pauseMusic();
		if CC_PLATFORM_IOS == CC_TARGET_PLATFORM then
			currentScene:changeVideo(vedioPath);
		else
			MovieScene:create({
				path = vedioPath,
				showSkip = true,
				endCall = function()
					TFAudio.resumeMusic()
					TimeOut(function()
						currentScene:showVideoView(true);
					end,0)
				end
			})
		end
	end));
	
	--用户中心按钮
	self.Button_useCenter= TFDirector:getChildByPath(ui,"Button_migrationServer"):hide()
	if HeitaoSdk then
		self.Button_useCenter:show()
		self.Button_useCenter:setPosition(self.Button_Conceal_proto:getPosition())
		self.Button_useCenter:setTextureNormal(self.accountBtn:getTextureNormalName())
		self.Button_useCenter:setTexturePressed(self.accountBtn:getTextureNormalName())
		self.Button_useCenter:addMEListener(TFWIDGET_CLICK,audioClickfun(function ()
			local result = HeitaoSdk.userCenter()
			if not result then --未登录的情况调用登录
				HeitaoSdk.login()
			end
		end))
	end

    self.Panel_serverList = TFDirector:getChildByPath(ui, "Panel_serverList")
   self.Panel_serverList:setVisible(GameConfig.Debug)
    self.Label_serverName = TFDirector:getChildByPath(self.Panel_serverList, "Label_serverName")
    self.Label_serverName:setTextById(800090)

    self.roleListPanel = TFDirector:getChildByPath(ui, "panel_roleList")
    self.roleListPanel:setVisible(false)
    self.curRoleNameLabel = TFDirector:getChildByPath(self.roleListPanel, "label_roleName")


    self.gameServerList = TFDirector:getChildByPath(ui, "game_serverList")
    self.gameServerList:setVisible(false)
    self.gameServerName = TFDirector:getChildByPath(self.gameServerList, "Label_serverName")
    self.Label_click = TFDirector:getChildByPath(self.gameServerList, "Label_click")
    self.Label_click:setTextById(18000375)  --点击选服

	self.Panel_logo = TFDirector:getChildByPath(ui, "Panel_logo")

	self.Panel_base = TFDirector:getChildByPath(ui,"Panel_base");
	local params = {
		_type = EC_InputLayerType.OK
	}
	self.accInputLayer = require("lua.logic.common.InputLayer"):new(params);
    self:addLayer(self.accInputLayer,1000);

    self.pdInputLayer = require("lua.logic.common.InputLayer"):new(params);
    self:addLayer(self.pdInputLayer,1000);

    self.codeInputLayer = require("lua.logic.common.InputLayer"):new(params);
    self:addLayer(self.codeInputLayer,1000);

    self:refreshView()

    self:tryLogin();
end

-- function LoginLayer:login()
-- 	if CC_TARGET_PLATFORM ~= CC_PLATFORM_WIN32 and HeitaoSdk then
-- 		HeitaoSdk.disableDeviceSleep(true)
-- 		if not self.isShowLoingBoard then
-- 			Utils:sendHttpLog("sdk_activate")
-- 			HeitaoSdk.login();
-- 		else
-- 			HeitaoSdk.loginOut();
-- 		end
-- 		self.accountBtn:setVisible(false)
-- 	else

-- 		if not self.isShowLoingBoard then
-- 			local pluginTimer
-- 			pluginTimer = TFDirector:addTimer(0,1,nil,function ()
-- 		        TFDirector:removeTimer(pluginTimer)
-- 		        self:autoLogin();
-- 			end)
-- 		else
-- 			self:showLoingBoard();
-- 		end
-- 		self.accountBtn:setVisible(true)
-- 	end

-- end




--本地测试
function LoginLayer:isLocalTest()
	return CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 or not HeitaoSdk
end

function LoginLayer:tryLogin()
	if self:isLocalTest() then 
		if not self.isShowLoingBoard then
			local pluginTimer
			pluginTimer = TFDirector:addTimer(0,1,nil,function ()
                TFDirector:removeTimer(pluginTimer)
                LogonHelper:localAutoLogin()
			end)
		else
			self:showLoingBoard()
		end
	else  --Sdk 登录拉起
		HeitaoSdk.disableDeviceSleep(true)
		if not self.isShowLoingBoard then
			Utils:sendHttpLog("sdk_activate")
			HeitaoSdk.login()
		end
	end
end


function LoginLayer:refreshView()
    self:refreshDebugServer()
end


function LoginLayer:loginAccountSuccess()
	if self.loginBoard then
		self.loginBoard:setVisible(false);
	end

	local newPlayer = false
    if HeitaoSdk then
        newPlayer = (tonumber(HeitaoSdk.isNewPlayer()) <= 0)
    end

    if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
    	local curScene = Public:currentScene()
        if curScene  and curScene.changeGameLanguage then
            curScene:changeGameLanguage()
        end
    end
	

	
	-- if CC_TARGET_PLATFORM ~= CC_PLATFORM_WIN32 then
	-- 	if not LogonHelper:isVerification() then
	-- 		LogonHelper:loginVerification();
	-- 	end
	-- end

	-- if CC_TARGET_PLATFORM ~= CC_PLATFORM_WIN32 then
	-- 	if self.showWebView then
	-- 		self:showWebView();
	-- 	end
	-- end
end

function LoginLayer:loginBtnCallback()
	print("account  : "..self.accountInput:getText())
	print("password : "..self.passwordInput:getText())
	print("code     : "..self.codeInput:getText())
	local account  = self.accountInput:getText();
	local password = self.passwordInput:getText();
	local code     = self.codeInput:getText();
	account 	= string.gsub(account," ","");
	password 	= string.gsub(password," ","");
	code 		= string.gsub(code," ","");

	if string.len(account) <= 0 then
		-- toastMessage("用户名不能为空")
		Utils:showTips(800089)
		return
	end

	-- if string.len(password) <= 0 and not GM_MODE then
	-- 	toastMessage("密码不能为空")
	-- 	return
	-- end

	if string.len(account) < 1 then
		-- toastMessage("请输入6-12位字母数字")
		Utils:showTips(800087)
		return
	end

	-- if string.len(password) < 6 and not GM_MODE then
	-- 	toastMessage("请输入6-12位字母数字")
	-- 	return
	-- end


	LogonHelper:login(account,password,code)
	-- if GM_MODE then
	-- 	LogonHelper:GMLogin(account);
	-- else
	-- 	LogonHelper:loginTest(account,password,code)
	-- end
end

function LoginLayer:initDefault()
	-- local password  = ServerDataMgr:getUserInfo()
	-- local username = userInfo.userName
	-- if username then
	-- 	self.input_name:setText(username)
	-- end
end

function LoginLayer:removeUI()
	self.super.removeUI(self)
end

function LoginLayer:onWebViewClose()
	-- if not LogonHelper:isVerification() then
	-- 	LogonHelper:loginVerification();
	-- end
	--self.touchLayer:setTouchEnabled(true);
end

function LoginLayer:registerEvents()
	self.super.registerEvents(self)

    EventMgr:addEventListener(self, "LoginLayer.LoginComplete", handler(self.loginGameServerSuccess, self))
    EventMgr:addEventListener(self, "LoginLayer.LoginSuccess", handler(self.loginAccountSuccess, self))
    EventMgr:addEventListener(self, EV_WEBVIEW_CLOSE, handler(self.onWebViewClose, self))
     EventMgr:addEventListener(self, "LoginLayer.AcountBan", handler(self.accountBan, self))

	local function onTextFieldChangedHandleAcc(input)
       	local text = input:getText()
        local new_text = string.gsub(text, "[^a-zA-Z0-9_]", "")
        input:setText(new_text)
        self.accInputLayer:listener(new_text);
	    self.pdInputLayer:hideAction();
	    self.codeInputLayer:hideAction();
    end

    local function onTextFieldAttachAcc(input)
    	local text = input:getText()
        local new_text = string.gsub(text, "[^a-zA-Z0-9_]", "")
        input:setText(new_text)
        self.accInputLayer:show();
        self.accInputLayer:listener(new_text);
	    self.pdInputLayer:hideAction();
	    self.codeInputLayer:hideAction();

	    self:chooseBox(1)
    end

    self.accountInput:addMEListener(TFTEXTFIELD_DETACH, onTextFieldChangedHandleAcc)
    self.accountInput:addMEListener(TFTEXTFIELD_ATTACH, onTextFieldAttachAcc)
    self.accountInput:addMEListener(TFTEXTFIELD_TEXTCHANGE, onTextFieldChangedHandleAcc)

    local function onTextFieldChangedHandlePD(input)
       	local text = input:getText()
        local new_text = string.gsub(text, "[^a-zA-Z0-9]", "")
        input:setText(new_text)
        self.pdInputLayer:listener(new_text);
	    self.accInputLayer:hideAction();
	    self.codeInputLayer:hideAction();
    end

    local function onTextFieldAttachPD(input)
    	local text = input:getText()
        local new_text = string.gsub(text, "[^a-zA-Z0-9]", "")
        input:setText(new_text)
        self.pdInputLayer:listener(new_text);
    	self.pdInputLayer:show();
	    self.accInputLayer:hideAction();
	    self.codeInputLayer:hideAction();

	    self:chooseBox(2)
    end

    self.passwordInput:addMEListener(TFTEXTFIELD_DETACH, onTextFieldChangedHandlePD)
    self.passwordInput:addMEListener(TFTEXTFIELD_ATTACH, onTextFieldAttachPD)
    self.passwordInput:addMEListener(TFTEXTFIELD_TEXTCHANGE, onTextFieldChangedHandlePD)


    local function onTextFieldChangedHandleCD(input)
       	local text = input:getText()
        local new_text = string.gsub(text, "[^a-zA-Z0-9]", "")
        input:setText(new_text)
        self.codeInputLayer:listener(new_text);
	    self.accInputLayer:hideAction();
	    self.pdInputLayer:hideAction();
    end

    local function onTextFieldAttachCD(input)
    	local text = input:getText()
        local new_text = string.gsub(text, "[^a-zA-Z0-9]", "")
        input:setText(new_text)
    	self.codeInputLayer:show();
    	self.codeInputLayer:listener(new_text);
	    self.accInputLayer:hideAction();
	    self.pdInputLayer:hideAction();

	    self:chooseBox(3)
    end

    self.codeInput:addMEListener(TFTEXTFIELD_DETACH, onTextFieldChangedHandleCD)
    self.codeInput:addMEListener(TFTEXTFIELD_ATTACH, onTextFieldAttachCD)
    self.codeInput:addMEListener(TFTEXTFIELD_TEXTCHANGE, onTextFieldChangedHandleCD)

    self.Panel_serverList:onClick(function()
        --Utils:openView("test.ServerListView")
        local view = requireNew("lua.logic.test.ServerListView"):new()
        self:addLayer(view, AlertManager.BLOCK)
        --AlertManager:show()
    end)

    self.gameServerList:onClick(function()
		if self.loginBoard:isVisible() then
			self:hideLoginBoard()
		end


        local view = requireNew("lua.logic.login.ServerChoose"):new()
        self:addLayer(view, AlertManager.BLOCK)
        --AlertManager:show()
    end)


    --与返回键功能冲突 屏蔽 2020-09-21
	--ADD_KEYBOARD_CLOSE_LISTENER(self, self.ui)

	self.Button_closeLogin:onClick(function()
       	self.loginBoard:setVisible(false)
    end)
end

function LoginLayer:removeEvents()
	self.super.removeEvents(self)
	TFDirector:removeMEGlobalListener("LoginLayer.LoginSuccess", handler(self.loginAccountSuccess, self))
    TFDirector:removeMEGlobalListener("LoginLayer.LoginComplete", handler(self.loginGameServerSuccess, self))
    TFDirector:removeMEGlobalListener("LoginLayer.AcountBan", handler(self.accountBan, self))
end

function LoginLayer:showLoingBoard()
	self.loginBoard:setVisible(not self.loginBoard:isVisible());
	self.loginBoard:setTouchEnabled(self.loginBoard:isVisible());
	self.loginBoard:setScale(0);

	local tween =
	    {
	        target = self.loginBoard,
	        {
            	duration = 0.2,
            	scale 	 = 1,
	    	},
	    }
	TFDirector:toTween(tween)

	if ServerDataMgr:getIsActivat() then
		local account,password = ServerDataMgr:getUserInfo()
		self.accountInput:setText(account or "")
		self.passwordInput:setText(password or "")
	end
end

function LoginLayer:hideLoginBoard()
	self.loginBoard:setVisible(false);
	self.loginBoard:setTouchEnabled(false);
end


function LoginLayer:loginServer()

end

function LoginLayer:loginGameServerSuccess(event)
    hideAllLoading()
    TFDirector:removeMEGlobalListener("LoginLayer.LoginComplete", handler(self.loginGameServerSuccess, self))
    dump("loginGameServerSuccess")
    Utils:sendHttpLog("server_connected")
    local currentScene = Public:currentScene()
    if currentScene ~= nil and currentScene.getTopLayer then
        if currentScene.__cname == "LoginScene" then
        	MainPlayer:stopLoadTimer()
    		local playerLv = MainPlayer:getPlayerLv()
        	if playerLv <= 5 then
        		MainPlayer:enterGame()
            	AlertManager:changeScene(SceneType.MainScene)
        	else
        		TFAssetsManager:downloadFullAssets(function()
        			MainPlayer:enterGame()
            		AlertManager:changeScene(SceneType.MainScene)
        		end)
        	end
        end
	end
end


----
function LoginLayer:onClickNext(sender)

	dump("onClickNext===================")
	--SDK 登录
	if CC_TARGET_PLATFORM ~= CC_PLATFORM_WIN32 and HeitaoSdk then
		self:onClickNext_SDK()
	else
		self:onClickNext_Test()
	end
end


function LoginLayer:onClickNext_SDK()
	--SDK 是否登录
	if not HeitaoSdk.isLogined() then
		print("sdk login")
		HeitaoSdk.login()
		return
	end

		
	-- if LogonHelper:checkOpenUserProto() then 
	-- 	print("show user proto")
	-- 	return
	-- end

	--是否验证通过
	if not LogonHelper:getIsLogin() then
		print("LogonHelper:login")
		LogonHelper:login(LogonHelper:getuserid())
		return
	end

	-- --官网渠道实名认证查询
	-- if Utils:isOfficialChannel() then 
	-- 	print("showCertificationDialog")
	-- 	HeitaoSdk.isFunctionSupported("showCertificationDialog")
	-- else
	-- 	print("LogonHelper:authorize")
	-- 	--验证并进入游戏服
	-- 	LogonHelper:authorize()
	-- end
	
	--验证并进入游戏服
	LogonHelper:authorize()
end

--原来中间插来一步实名认证 ，现在直接登录服务器
function LoginLayer:onClickNext_Test()
	if not ServerDataMgr:getIsActivat() or not LogonHelper:getIsLogin() then
		self:showLoingBoard()
		return
	end
	if self.loginBoard:isVisible() then
		self:hideLoginBoard()
		return
	end

	-- if LogonHelper:checkOpenUserProto() then 
	-- 	return
	-- end
	
	--账户登录成功 验证并进入游戏服
	LogonHelper:authorize()


	--print("--账户登录成功 登录游戏服")
	--CommonManager:loginServer();

end

function LoginLayer:onGameServerRefresh()
    --登录成功才会显示
    local logined = LogonHelper:getIsLogin()
    self.gameServerList:setVisible(logined)
    if logined then
    	self.gameServerName:setString(ServerDataMgr:getCurServerName())
    end
end


--刷新登录测试服务器
function LoginLayer:refreshDebugServer()
	local serverGroup = ServerDataMgr:getDebugServer()
	if serverGroup then 
        self.Label_serverName:setText(tostring(serverGroup.name))
    else
        self.Label_serverName:setTextById(800090)
    end
    --登录成功才会显示
    self:onGameServerRefresh()
end



--封停
function LoginLayer:accountBan()
	local tips = TextDataMgr:getText(190001266)
    local okhandle = function()
    	if self.accountBanTipLayer then
    		self.accountBanTipLayer:removeFromParent()
    	end
    end
    self.accountBanTipLayer = showMessageBox(tips,EC_MessageBoxType.ok,okhandle);
end


function LoginLayer:showWebView()
	dump("show1")
	if not self.isShowWeb then
		--屏蔽弹出公告上报
		--Utils:sendHttpLog("informed_page_L")
		self.isShowWeb = true;
     	self:openNewNoticeLayer()
	else
		if HeitaoSdk then
			HeitaoSdk.doAntiAddicationQuery();
		end
	end
end

function LoginLayer:openNewNoticeLayer( ... )

	if true  then return end  ---暂时屏蔽唤起公告界面
	if HeitaoSdk then 
        HeitaoSdk.isFunctionSupported("showAnnouncement")
    end
	--TODO 登录界面特殊显示公告
	-- local fullModuleName = string.format("lua.logic.%s", "common.AnnouncementLayer")
	--  local view = requireNew(fullModuleName):new()
	--  self:addLayer(view,998)
	--  self.noticeLayer = view
	--  view:setCloseCallBack(function( ... )
	--  	self:removeLayer(self.noticeLayer, true)
 --        self.noticeLayer = nil
	--  end)

end

function LoginLayer:chooseBox(index)

	for i=1,3 do
		if i==index then
			self.chooseImge[i]:setVisible(true)
		else
			self.chooseImge[i]:setVisible(false)
		end
	end
end

function LoginLayer:onKeyBack()
    if self.cleanUpView or self.noticeLayer or self.migrationServerView then
    	if self.noticeLayer then
    		self:removeLayer(self.noticeLayer, true)
        	self.noticeLayer = nil
    	elseif self.cleanUpView then
    		self:removeLayer(self.cleanUpView, true)
        	self.cleanUpView = nil
        elseif self.migrationServerView then
        	self:removeLayer(self.migrationServerView, true)
        	self.migrationServerView = nil
    	end
    else
        if HeitaoSdk then
            HeitaoSdk.loginExit()
        else
            Box("真机上调用退出")
        end
    end
end

return LoginLayer;
