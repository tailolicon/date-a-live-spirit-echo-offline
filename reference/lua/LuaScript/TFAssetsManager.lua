local TFAssetsManager = TFAssetsManager or {}

local strCfg = TFGlobalUtils:requireGlobalFile("lua.table.StartString")

--TODO fix1.08 bug
local fixPackID = {
            [1] = 7014,
            [2] = 7015,
            [3] = 7016,
            [4] = 7017,
            [5] = 7018,
            [6] = 7019,
            [7] = 7020,
            [8] = 7021,
            [9] = 7022,
            [10] = 7023,
            [11] = 7024,
            [12] = 7025,
            [13] = 7026,
            [14] = 7027,
            [15] = 7028,
            [16] = 706,
            [17] = 305,
            [18] = 705,
            [19] = 704,
            [20] = 303,
            [21] = 703,
            [22] = 702,
        }
function TFAssetsManager:init( tag )
	self._time          = 0
	self._awbName       = ""
	self._awbRetryTimes = 0
	self._extListRetryTimes = 0

	self.connectedArray = TFArray:new()
	self.normalQuene    = {} --静默后台下载队列
	self.priorityQuene  = {} --优先插队下载队列
	self.priorityAssets = nil --当前需要的远程资源(未开始下载及静默下载中的)

	 --删除小包配置文件
	if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
		local uName = "src/lua/table/PackBranch.lua"
	 	if TFFileUtil:existFile(uName) then
	 		local fullpath = me.FileUtils:fullPathForFilename(uName);
	 		if not string.find(fullpath,"assets") then
	 			me.FileUtils:removeFile(fullpath);
	 		end
	 	end
	end

	if package.loaded["lua.table.PackBranch"] then
		package.loaded["lua.table.PackBranch"] = nil;
	end
	--应哟版本
	self.appVersion      = TFDeviceInfo:getCurAppVersion()
	local _extAssetsCfg  = TabDataMgr:getData("PackBranch")
	self.extAssetsCfg    = {}
	--2类型非强制下载包已包含完整的首包资源，无需从远程下载首包补充资源，所以从下载配置里移除
	for k,v in pairs(_extAssetsCfg) do
		if v.triggerType == 100 and v.version == "1.08" then 
			v.packID = fixPackID
		end
		if EX_ASSETS_ENABLE ~= 2 or v.triggerType ~= 100 then 
			self.extAssetsCfg[k] = v
		end
	end
	--扩展资源版本号
	self.baseAssetVersion  = self.extAssetsCfg[1].version or "1.02";

	self.allowedPriority = false
	self.curTasks = {
		normalTask = nil,
		priorityTask = nil,
	} --当前下载中的任务
	self.priorityTasks_process = {speed = 0,completeSize = 0,totalsize = 0,cursize = 0,curtasksize = 0}


	--local addPackIDs = {[1] = 998}
	--table.insert(self.extAssetsCfg,{note = "遗漏资源小包",version = self.baseAssetVersion, id = (#self.extAssetsCfg +1), triggerType = 21,extParam = {},packID = addPackIDs,})

	self.extAssetsSeriesCfg = {}
	for k,v in pairs(self.extAssetsCfg) do
		self.extAssetsSeriesCfg[v.triggerType]       = self.extAssetsSeriesCfg[v.triggerType] or {}
		self.extAssetsSeriesCfg[v.triggerType][v.id] = v
	end


	--根据平台初始化扩展资源保存路径
	local writablePath = CCFileUtils:sharedFileUtils():getWritablePath()
	self.extAssetsSavePath = ""
	if CC_TARGET_PLATFORM == CC_PLATFORM_IOS then
	    self.extAssetsSavePath = writablePath .. '../Library/TFDebug/'
	elseif CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
	    self.extAssetsSavePath = writablePath .. 'TFDebug/'
	else
		self.extAssetsSavePath = writablePath .. "../Library/TFDebug/"
	end

	--目录不存在的情况下创建目录
	if not TFFileUtil:existFile(self.extAssetsSavePath) then
		TFFileUtil:createDir(self.extAssetsSavePath)
	end

	--tag  干啥的 ？
	self.tag = tag or 1

    --组装资源下载地址
	self.remoteUrlIdx = 1
	self.remoteUrlList = {}
	for _,_url in ipairs(URL_REMOTE) do
		table.insert(self.remoteUrlList, _url ..self.baseAssetVersion.."/")
		-- table.insert(self.remoteUrlList, _url ..self.baseAssetVersion.."/")
	end
	self.remoteUrlBasicList = {}
	for _,_url in ipairs(URL_REMOTE) do
		table.insert(self.remoteUrlBasicList, _url ..self.baseAssetVersion.."/" .."%s.awb")
		-- table.insert(self.remoteUrlBasicList, _url ..self.baseAssetVersion.."/" .."%s.awb")
	end

	self.extListFileList = {}
	for _,_url in ipairs(URL_REMOTE) do
		table.insert(self.extListFileList, "extlist.json")
		-- table.insert(self.extListFileList, "extlist.json")
	end
end




function TFAssetsManager:getCheckInfo(series,param)
	--Box("getCheckInfo:"..tostring(series))
	local seriesCfg = self.extAssetsSeriesCfg[series]
	if seriesCfg == nil then
		return nil
	end
	for k,v in pairs(seriesCfg) do
		if table.count(v.extParam) > 0 then
			for s,t in pairs(v.extParam) do
				if t == param then
					return v.id
				end
			end
		else
			return v.id
		end
	end
	return nil
end

function TFAssetsManager:getRemoteFileList(bReTry)
	--获取远程资源局列表
	Utils:sendHttpLog("assets_extlist",false,self.remoteUrlIdx)
	local cfgName = self.extListFileList[self.remoteUrlIdx]
	local task = {
			url = self.remoteUrlList[self.remoteUrlIdx] ..cfgName,
			fileName = cfgName,
			folderPath = self.extAssetsSavePath,
			autoRetryTimes = 3,
		}

	dump("task.url:"..tostring(task.url))
	self:checkCdnAndUrlUpdate(task.url)
	DownloadHelper:start(json.encode(task),
		function(info)
			
		end,
		function(info)
			
		end,
		function(info)
			
		end,
		function(info)
			self:onRemoteListGot(bReTry)
		end,
		function(info)
			self:retryGetRemoteList()
		end)
end

function TFAssetsManager:retryGetRemoteList()
	self.remoteUrlIdx = self.remoteUrlIdx + 1
	if self.remoteUrlIdx > #self.remoteUrlList then
		self.remoteUrlIdx = 1
	end
	self._extListRetryTimes = self._extListRetryTimes or 0
	self._extListRetryTimes = self._extListRetryTimes + 1
	Utils:sendHttpLog("assets_extlist_retry_"..tostring(self._extListRetryTimes),false,self.remoteUrlIdx)
	self:getRemoteFileList(true)
	EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_RETRY_EXTLIST)
end

--获取到远程资源化列表
function TFAssetsManager:onRemoteListGot(bReTry)
	--远程资源列表获取成功
	Utils:sendHttpLog("assets_extlist_complete",false,self.remoteUrlIdx)
	local cfgName       = self.extListFileList[self.remoteUrlIdx]
	local jsonContent   = io.readfile(self.extAssetsSavePath..cfgName)
	self.remoteListDict = json.decode(jsonContent)
	if self.remoteListDict == nil then
		self:retryGetRemoteList()
		return
	end
	dump(self.remoteListDict)


	EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_EXTLIST)
end

function TFAssetsManager:getAwbFileName(id)
	return  string.format("%s%d.awb",self.extAssetsSavePath,tonumber(id))   
end


function TFAssetsManager:getAwbFileKey(id)

	local key = string.format("extasset_%s_%s_%s",tostring(self.appVersion),tostring(self.baseAssetVersion),tostring(id))
	print("key:" ..tostring(key))
	return key
end

--0 未下载 1 已下载 2 已解压
function TFAssetsManager:setAwbState( id, value )
	if id and (id > 0) then
		local key = self:getAwbFileKey(id)
		CCUserDefault:sharedUserDefault():setIntegerForKey(key, value)
		CCUserDefault:sharedUserDefault():flush()
	end
end

function TFAssetsManager:getAwbState(id)
	if id and (id > 0) then
		local key = self:getAwbFileKey(id)
		return CCUserDefault:sharedUserDefault():getIntegerForKey(key, 0)
	end
	return 0
end

--检查需要下载的文件列表
function TFAssetsManager:checkAssetsDownload(checkList)
	for k,v in pairs(checkList) do
		local localfilepath = self:getAwbFileName(k)
		if TFFileUtil:existFile(localfilepath) or (self:getAwbState(tonumber(k)) > 0) then
			checkList[tonumber(k)] = 0
			local tmppath = string.format("%s%d.temp",self.extAssetsSavePath,tonumber(k))
			if TFFileUtil:existFile(tmppath) then
				os.remove(tmppath)
			end
		end
	end

	local downloadList = {}
	for k,v in pairs(checkList) do
		if v == 1 then
			downloadList[#downloadList + 1] = k
		end
	end
	return downloadList
end



function TFAssetsManager:runManager()
	if EX_ASSETS_ENABLE > 0 then
		self._extListRetryTimes = 0
		self:getRemoteFileList()
	end
end

function TFAssetsManager:getAllCfgFileList()
	local allExtFileList = {}
	for k,v in pairs(self.extAssetsCfg) do
		if table.count(v.packID) > 0 then
			for s,t in pairs(v.packID) do
				allExtFileList[t] = 1
			end
		else
			-- if self.remoteListDict then
			-- 	for s,t in pairs(self.remoteListDict) do
			-- 		allExtFileList[tonumber(s)] = 1
			-- 	end
			-- end
		end
	end
	return allExtFileList
end

function TFAssetsManager:checkAssets(checkList,isfirst)
	print("checkAssets"..tostring(isfirst))

	for k,v in pairs(checkList) do
		local localfilepath = string.format("%s%d.awb",self.extAssetsSavePath,tonumber(k))
		--Box("localfilepath:"..localfilepath .."  "..tostring(isfirst))


		if TFFileUtil:existFile(localfilepath) or (self:getAwbState(tonumber(k)) > 0) then
			-- local fileins = io.open(localfilepath,"rb")
			-- local fileContent = fileins:read("*a")
			-- local hashcode = md5.sumhexa(fileContent)
			-- fileins:close()
   --          local remotehash = self.remoteListDict[tostring(k)].md5
			-- if hashcode == remotehash then
			-- 	checkList[tonumber(k)] = 0
			-- 	if isfirst == true then
			-- 		MEAssetsBundle:defaultBundle():load(string.format("%d.awb",tonumber(k)))
			-- 	end
			-- 	local tmppath = string.format("%s%d.temp",self.extAssetsSavePath,tonumber(k))
			-- 	if TFFileUtil:existFile(tmppath) then
			-- 		os.remove(tmppath)
			-- 	end
			-- end
			checkList[tonumber(k)] = 0
			if isfirst == true then
				--MEAssetsBundle:defaultBundle():load(string.format("%d.awb",tonumber(k)))
				self:loadAssetFile(tonumber(k), false)
			end
			local tmppath = string.format("%s%d.temp",self.extAssetsSavePath,tonumber(k))
			if TFFileUtil:existFile(tmppath) then
				os.remove(tmppath)
			end
		end
	end
	if checkList == nil then
		return
	end
	local downloadList = {}
	for k,v in pairs(checkList) do
		if v == 1 then
			downloadList[#downloadList + 1] = k
		end
	end
	if table.count(downloadList) >= 2 then
		table.sort( downloadList, function(a,b)
			return a > b
		end )
	end
	return downloadList
end

function TFAssetsManager:tranFileSize(filesize)
	local filesizestr = "0kb"
	if filesize < 1048576 then
		filesizestr = string.format("%.2fkb",filesize/1024)
	else
		filesizestr = string.format("%.2fMb",filesize/1048576)
	end
	return filesizestr
end

function TFAssetsManager:downloadAssetsNormal(isfirst)

	local normalList = self:getAllCfgFileList()
	local downloadList = self:checkAssets(normalList,isfirst)

	dump({"downloadAssetsNormal:"..tostring(isfirst),downloadList})
	if table.count(downloadList) == 0 then
		return
	end
	local filesSize = 0
	for i,v in ipairs(downloadList) do
		local remoteFileInfo = self.remoteListDict[tostring(v)]
		if remoteFileInfo then
			local tmsize = tonumber(self.remoteListDict[tostring(v)].size)
			filesSize = filesSize + tmsize
		else
			print("No extAsset File:"..v)
		end
	end
	if CC_TARGET_PLATFORM ~= CC_PLATFORM_WIN32 then
		local freedisksize = TFDeviceInfo:getMachineFreeSpace()
		print("free:"..freedisksize)
		filesSize = filesSize/1048576
		if freedisksize < filesSize then
			local alertparams = clone(EC_GameAlertParams)
			alertparams.msg = 270007
			alertparams.title = 270001
			alertparams.showtype = 1
			showGameAlert(alertparams)
			return
		end
	end

	self.normalQuene = self:handleTaskList(downloadList)
	
	if CC_TARGET_PLATFORM == CC_PLATFORM_WIN32 then
		self:runNextDownload()
	else
		local network = TFDeviceInfo:getNetWorkType()
		if network == "WIFI" then
			-- modify by beck 台湾小包去掉wifi自动下载
			-- self:runNextDownload()
		end
	end
	
end

--高级账号下载全部资源
function TFAssetsManager:downloadFullAssets(callback,cancelCallback)
	if EX_ASSETS_ENABLE < 1 then
		if callback then
			callback()
		end
		return
	end
	if self.tag and self.tag > 0 then
		if CommonManager:getConnectionStatus() == false then
			Utils:showError(strCfg[111000051].text)
			return
		end
	end
	if self.remoteListDict == nil then
		--CDN未连接成功
		Utils:showError(strCfg[111000052].text)
		Bugly:ReportLuaException("assets list url: ========================= " .. tostring(self.remoteListUrl))
		return
	end
	self.priorityCallback = callback
	local normalList   = self:getAllCfgFileList()
	local downloadList = self:checkAssetsDownload(normalList,false)
	dump(downloadList)
	if self:priorityDownload(downloadList,false) == false then
		self:unZipAwb(function( )
			if self.priorityCallback then
				self.priorityCallback()
				self.priorityCallback = nil
			end
		end)
		print("暂无需要下载的资源")
		return
	end

	local network = TFDeviceInfo:getNetWorkType()
	local tipcont = ""
	if network == "WIFI" then
		tipcont = TextDataMgr:getText(270002,self:tranFileSize(self.priorityTasks_process.totalsize))
	else
		tipcont = TextDataMgr:getText(270003,self:tranFileSize(self.priorityTasks_process.totalsize))
	end
	local alertparams = clone(EC_GameAlertParams)
	alertparams.msg = tipcont
	alertparams.title = 270001
	alertparams.comfirmCallback = function()
		Utils:sendHttpLog("assets_full_comfirm")
		Utils:openView("common.ExtAssetsDownloadView")
		self.allowedPriority = true
		if network ~= "WIFI" then
			self.allowAnyConnect = true
		end
		self:runNextDownload()

	end
	alertparams.cancelCallback = function( ... )
		Utils:sendHttpLog("assets_full_cancel")
		self.priorityAssets = nil
		EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_VIEW_CLOSE)
		self.priorityQuene = {}
		self.allowedPriority = false
		if network == "WIFI" then
			-- modify by beck 台湾小包去掉wifi自动下载
			-- self:runNextDownload()
		end
		if cancelCallback then 
			cancelCallback()
		end
		--Box("取消下载")
	end
	showGameAlert(alertparams)
end

function TFAssetsManager:downloadAssetsOfFunc(funcId,callback,isconfirm,cancelCallback)
	if EX_ASSETS_ENABLE < 2 then
		if callback then
			callback()
		end
		return
	end

	if self.tag and self.tag > 0 then
		if CommonManager:getConnectionStatus() == false then
			Utils:showError(strCfg[111000051].text)
			return
		end
	end
	
	if self.remoteListDict == nil then
		--CDN未连接成功
		Utils:showError(strCfg[111000052].text)
		return
	end
	self.priorityCallback = callback
	local funcAssetsList = self.extAssetsCfg[funcId].packID
	local extHeroCfg = self.extAssetsSeriesCfg[4]
	if funcAssetsList == nil and extHeroCfg == nil then
		self:unZipAwb(function( )
			if self.priorityCallback then
				self.priorityCallback()
				self.priorityCallback = nil
			end
		end)
		return
	end
	local checkList = {}

	if table.count(funcAssetsList) == 0 then
		for k,v in pairs(self.remoteListDict) do
			table.insert(funcAssetsList,tonumber(k))
		end
	end
	for k,v in pairs(funcAssetsList) do
		checkList[v] = 1
	end
	--checkList[999] = 1
	
	if extHeroCfg then
		for k,v in pairs(extHeroCfg) do
			for p,q in pairs(v.extParam) do	
				if HeroDataMgr:getIsHave(q) == true then
					for s,t in pairs(v.packID) do
						checkList[t] = 1
					end
					break
				end
			end
		end
	end
	local downloadList = self:checkAssets(checkList)
	if self:priorityDownload(downloadList, false) == false then
		self:unZipAwb(function( )
			if self.priorityCallback then
				self.priorityCallback()
				self.priorityCallback = nil
			end
		end)
		return
	end
	--显示插队下载界面
	if isconfirm and isconfirm == true then
		local network = TFDeviceInfo:getNetWorkType()
		local tipcont = ""
		if network == "WIFI" then
			tipcont = TextDataMgr:getText(270004,self:tranFileSize(self.priorityTasks_process.totalsize))
		else
			tipcont = TextDataMgr:getText(270005,self:tranFileSize(self.priorityTasks_process.totalsize))
		end
		local alertparams = clone(EC_GameAlertParams)
		alertparams.msg = tipcont
		alertparams.title = 270001
		alertparams.comfirmCallback = function()
			
			Utils:sendHttpLog("assets_func_"..tostring(funcId).."_comfirm")
			Utils:openView("common.ExtAssetsDownloadView")
			self.allowedPriority = true
			if network ~= "WIFI" then
				self.allowAnyConnect = true
			end
			self:runNextDownload()
		end
		alertparams.cancelCallback = function( ... )
			Utils:sendHttpLog("assets_func_"..tostring(funcId).."_cancel")
			self.priorityAssets = nil
			EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_VIEW_CLOSE)
			self.priorityQuene = {}
			self.allowedPriority = true
			if network == "WIFI" then
				-- modify by beck 台湾小包去掉wifi自动下载
				-- self:runNextDownload()
			end
			if cancelCallback then 
				cancelCallback()
			end
		end
		showGameAlert(alertparams)
	else
		Utils:openView("common.ExtAssetsDownloadView")
		self.allowedPriority = true
		self:runNextDownload()
	end
end

function TFAssetsManager:checkAllHeroComplete()
	if EX_ASSETS_ENABLE < 2 then
		return true
	end
	local extHeroCfg = self.extAssetsSeriesCfg[4]
	local checkList = {}
	for k,v in pairs(extHeroCfg) do
		for s,t in pairs(v.packID) do
			checkList[t] = 1
		end
	end
	local downloadList = self:checkAssets(checkList)
	if table.count(downloadList) > 0 then
		return false
	end
	return true
end

function TFAssetsManager:checkChapterComplete(fubenType,chapterId)
	if EX_ASSETS_ENABLE < 2 then
		return true
	end
	local isComplete = false
	local fubenCheckCfg = {[1] = {1,chapterId},[2] = {2,2},[4] = {3,chapterId},[5] = {6,chapterId}}
	local fubenCheckParam = fubenCheckCfg[fubenType]
    if fubenCheckParam then
        local checkExtId = TFAssetsManager:getCheckInfo(fubenCheckParam[1],fubenCheckParam[2])
        if checkExtId then
            local funcAssetsList = self.extAssetsCfg[checkExtId].packID
			if funcAssetsList == nil then
				isComplete = true
			else
				local checkList = {}
				for k,v in pairs(funcAssetsList) do
					checkList[v] = 1
				end
				local downloadList = self:checkAssets(checkList)
				if table.count(downloadList) == 0 then
					isComplete = true
				end
			end
        end
    end
    return isComplete
end

function TFAssetsManager:downloadHeroAssets(callback,isconfirm)

	if EX_ASSETS_ENABLE < 2 then
		if callback then
			callback()
		end
		return
	end

	if self.tag and self.tag > 0 then
		if CommonManager:getConnectionStatus() == false then
			Utils:showError(strCfg[111000051].text)
			return
		end
	end
	
	if self.remoteListDict == nil then
		--CDN未连接成功
		Utils:showError(strCfg[111000052].text)
		return
	end
	self.priorityCallback = callback
	local extHeroCfg = self.extAssetsSeriesCfg[4]
	local checkList = {}
	for k,v in pairs(extHeroCfg) do
		for p,q in pairs(v.extParam) do
			if HeroDataMgr:getIsHave(q) == true then
				for s,t in pairs(v.packID) do
					checkList[t] = 1
				end
				break
			end
		end
	end
	local downloadList = self:checkAssets(checkList)
	if self:priorityDownload(downloadList,false) == false then
		self:unZipAwb(function( )
			if self.priorityCallback then
				self.priorityCallback()
				self.priorityCallback = nil
			end
		end)
		return
	end
	--显示插队下载界面
	if isconfirm and isconfirm == true then
		local network = TFDeviceInfo:getNetWorkType()
		local tipcont = ""
		if network == "WIFI" then
			tipcont = TextDataMgr:getText(270004,self:tranFileSize(self.priorityTasks_process.totalsize))
		else
			tipcont = TextDataMgr:getText(270005,self:tranFileSize(self.priorityTasks_process.totalsize))
		end
		local alertparams = clone(EC_GameAlertParams)
		alertparams.msg = tipcont
		alertparams.title = 270001
		alertparams.comfirmCallback = function()
			Utils:sendHttpLog("assets_hero_comfirm")
			Utils:openView("common.ExtAssetsDownloadView")
			self.allowedPriority = true
			if network ~= "WIFI" then
				self.allowAnyConnect = true
			end
			self:runNextDownload()
		end
		alertparams.cancelCallback = function( ... )
			Utils:sendHttpLog("assets_hero_cancel")
			self.priorityAssets = nil
			EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_VIEW_CLOSE)
			self.priorityQuene = {}
			self.allowedPriority = false
			if network == "WIFI" then
				-- modify by beck 台湾小包去掉wifi自动下载
				-- self:runNextDownload()
			end
		end
		showGameAlert(alertparams)
	else
		Utils:openView("common.ExtAssetsDownloadView")
		self.allowedPriority = true
		self:runNextDownload()
	end
end

function TFAssetsManager:priorityDownload(downloadList, priorityCallbackEnable)
	if priorityCallbackEnable == nil then priorityCallbackEnable = true end
	if table.count(downloadList) == 0 then
		if priorityCallbackEnable then
			self:unZipAwb(function( )
				Utils:sendHttpLog("assets_unzip")
				if self.priorityCallback then
					self.priorityCallback()
					self.priorityCallback = nil
				end
			end)
		end
		return false
	end
	self.priorityAssets = {}
	for i,v in ipairs(downloadList) do
		self.priorityAssets[v] = 1
	end
	-- if table.count(downloadList) == 0 then
	-- 	if priorityCallbackEnable then
	-- 		self:unZipAwb(function( )
	-- 			if self.priorityCallback then
	-- 				self.priorityCallback()
	-- 				self.priorityCallback = nil
	-- 			end
	-- 		end)
	-- 	end
	-- 	return false
	-- end
	--插队下载
	self.priorityTasks_process = {speed = 0,completeSize = 0,totalsize = 0,cursize = 0,curtasksize = 0}
	for k,v in ipairs(downloadList) do
		local tmRemoteFileInfo = self.remoteListDict[tostring(v)]
		if tmRemoteFileInfo then
			local tmsize = tonumber(tmRemoteFileInfo.size)
			self.priorityTasks_process.totalsize = self.priorityTasks_process.totalsize + tmsize
		else
			Box("No file:"..v)
		end
		
	end
	if self.curTasks.normalTask then
		local fileName = self.curTasks.normalTask.fileName
		local fileInfo = string.split(fileName,".")
		local needplus = true
		for i,v in ipairs(downloadList) do
			if tonumber(v) == tonumber(fileInfo[1]) then
				needplus = false
				break
			end
		end
		if needplus == true then
			local tmsize = tonumber(self.remoteListDict[tostring(fileInfo[1])].size)
			self.priorityAssets[tonumber(fileInfo[1])] = 1
			self.priorityTasks_process.totalsize = self.priorityTasks_process.totalsize + tmsize
		end
	end
	self.priorityQuene = self:handleTaskList(downloadList)
	return true
end

function TFAssetsManager:handleTaskList(downloadList)
	local remoteUrlBasic = self.remoteUrlBasicList[self.remoteUrlIdx]
	local downloadQuene = {}
	for k,v in pairs(downloadList) do
		local task = {
			url = string.format(remoteUrlBasic,v),
			fileName = string.format("%s.temp",v),
			folderPath = self.extAssetsSavePath,
			autoRetryTimes = 0,
		}
		downloadQuene[#downloadQuene + 1] = task
	end
	return downloadQuene
end

function TFAssetsManager:runNextDownload()
	dump("TFAssetsManager:runNextDownload(")
	local network = TFDeviceInfo:getNetWorkType()
	if table.count(self.priorityQuene) > 0 then
		if self.allowedPriority == false then
			return
		end
		if self.curTasks.priorityTask == nil and self.curTasks.normalTask == nil then
			if network ~= "WIFI" then
				if self.allowAnyConnect and self.allowAnyConnect == true then
					self.curTasks.priorityTask = self:startDownLoad(self.priorityQuene[1])
					table.remove(self.priorityQuene,1)
				else
					local alertparams = clone(EC_GameAlertParams)
					alertparams.msg = 270009
					alertparams.title = 270001
					alertparams.comfirmCallback = function()
						Utils:sendHttpLog("assets_no_wifi_confirm")
						self.allowAnyConnect = true
						self.curTasks.priorityTask = self:startDownLoad(self.priorityQuene[1])
						table.remove(self.priorityQuene,1)
					end
					alertparams.cancelCallback = function( ... )
						Utils:sendHttpLog("assets_no_wifi_cancel")
						EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_VIEW_CLOSE)
					end
					showGameAlert(alertparams)
				end
			else
				self.curTasks.priorityTask = self:startDownLoad(self.priorityQuene[1])
				table.remove(self.priorityQuene,1)
			end
		end
	else
		if network ~= "WIFI" then
			return
		end
		if self.curTasks.priorityTask == nil and self.curTasks.normalTask == nil then
			if table.count(self.normalQuene) > 0 then
				self.curTasks.normalTask = self:startDownLoad(self.normalQuene[1])
				table.remove(self.normalQuene,1)
			else
				EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_VIEW_CLOSE)
			end
		end
	end
end

function TFAssetsManager:startDownLoad(task)
	dump(task)
	local awbName       = string.gsub(task.fileName, ".temp", "") 
	self._time          = os.time()
	self._awbName       = awbName
	self._awbRetryTimes = 0
	print("startDownLoad:"..tostring(awbName))
	Utils:sendHttpLog("assets_awb_"..tostring(awbName),false,self.remoteUrlIdx,nil)
	DownloadHelper:start(json.encode(task),
		handler(self.onRemoteFileFond,self),
		handler(self.onFileDownloading,self),
		handler(self.onFileDownloadRetry,self),
		handler(self.onFileDownloaded,self),
		handler(self.onFileDownloadFailed,self))
	return clone(task)
end

function TFAssetsManager:onRemoteFileFond(info)
		print("onRemoteFileFond")
end

function TFAssetsManager:onFileDownloaded(info)
	print("onFileDownloaded")
	info = json.decode(info)
	local fileName = ""
	if self.curTasks.normalTask then
		if info.url == self.curTasks.normalTask.url then
			fileName = self.curTasks.normalTask.fileName
		end
		self.curTasks.normalTask = nil
	end
	if self.curTasks.priorityTask then
		if info.url == self.curTasks.priorityTask.url then
			fileName = self.curTasks.priorityTask.fileName
		end
		self.curTasks.priorityTask = nil
	end
	if fileName == "" then
		return
	end
	local fileInfo = string.split(fileName,".")
	local awdId    = tonumber(fileInfo[1])
	local tmppath  = info.filePath
	local savePath = string.format("%s%d.awb",self.extAssetsSavePath,awdId)
	if TFFileUtil:existFile(savePath) then
		os.remove(savePath)
	end
	os.rename(tmppath,savePath)
	if TFFileUtil:existFile(savePath) then
		self:setAwbState(awdId,1)
	end

	--MEAssetsBundle:defaultBundle():load(string.format("%d.awb",tonumber(fileInfo[1])))
	local ret = self:loadAssetFile(tonumber(fileInfo[1]), true)
	if ret then
		if self.priorityAssets then
			if self.priorityAssets[tonumber(fileInfo[1])] then
				self.priorityAssets[tonumber(fileInfo[1])] = 0
			end
			if table.count(self.priorityQuene) > 0 then
				for i = table.count(self.priorityQuene),1,-1 do
					if fileName == self.priorityQuene[i].fileName then
						table.remove(self.priorityQuene,i)
					end
				end

			end
			
			local tmcurSize = 0
			for k,v in pairs(self.priorityAssets) do
				if self.priorityAssets[tonumber(k)] == 0 then
					local tmoksize = tonumber(self.remoteListDict[tostring(k)].size)
					tmcurSize = tmcurSize + tmoksize
				end
			end
			self.priorityTasks_process.cursize = 0
			self.priorityTasks_process.curtasksize = 0
			self.priorityTasks_process.completeSize = tmcurSize
			local priorityAllOk = true
			for k,v in pairs(self.priorityAssets) do
				if v == 1 then
					priorityAllOk = false
					break
				end
			end
			if priorityAllOk == true then
				EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_VIEW_CLOSE)
				self:unZipAwb(function( )
					if self.priorityCallback then
						self.priorityCallback()
						self.priorityCallback = nil
					end
				end)
				self.priorityAssets = nil
				self.allowedPriority = false
				self:downloadAssetsNormal()
				return
			end
		end
	else
		local tmcurSize = 0
		for k,v in pairs(self.priorityAssets) do
			if self.priorityAssets[tonumber(k)] == 0 then
				local tmoksize = tonumber(self.remoteListDict[tostring(k)].size)
				tmcurSize = tmcurSize + tmoksize
			end
		end
		self.priorityTasks_process.completeSize = math.max(0,self.priorityTasks_process.completeSize - tmcurSize)
		self.priorityTasks_process.cursize = 0
		self.priorityTasks_process.curtasksize = 0
	end
	self:runNextDownload()
end

function TFAssetsManager:onFileDownloading(info)

	info = json.decode(info)
	self.priorityTasks_process.cursize = info.downloadedSize
	self.priorityTasks_process.curtasksize = info.fileSize
	self.priorityTasks_process.speed = info.downloadSpeed

-- dump(info)

-- 定时5秒更新状态
	local time = os.time() 
	if time - self._time >= 5 then 
		self._time = time
		local awbName = string.match(info.filePath, "[/\\%.](%d+)%.temp$")
		local _info = {}
		_info.size      = info.downloadedSize
		_info.totalSize = info.fileSize
		_info.speed     = info.downloadSpeed ..tostring("kb/s")
		Utils:sendHttpLog("assets_awb_"..tostring(awbName).."_ing",false,self.remoteUrlIdx,nil,_info)	
	end
end

function TFAssetsManager:onFileDownloadFailed(info)
	-- dump(info)
	local awbName = self._awbName or "none"
	-- Box("onFileDownloadFailed:"..tostring(awbName))
	Utils:sendHttpLog("assets_awb_"..tostring(awbName).."_fail",false,self.remoteUrlIdx,nil)
	-- Utils:sendHttpLog("assets_down_fail")
	print("onFileDownloadFailed")
	if self.allowedPriority == false then
		EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_VIEW_CLOSE)
		return
	end
	local alertparams = clone(EC_GameAlertParams)
	alertparams.msg = 270008
	alertparams.title = 270001
	alertparams.confirm_title = 800085
	alertparams.cancel_title = 3005051
	alertparams.cancelCallback = function()
		Utils:sendHttpLog("assets_awb_"..tostring(awbName).."_retry_cancel",false,self.remoteUrlIdx,nil)
		self.curTasks.priorityTask = nil 
		self.curTasks.normalTask = nil
		EventMgr:dispatchEvent(EV_EXT_ASSET_DOWNLOAD_VIEW_CLOSE)
        DelayCall(function () --延迟退出游戏
            me.Director:endToLua()
        end,2)
	end
	alertparams.comfirmCallback = function()
		self._awbRetryTimes = self._awbRetryTimes + 1
		Utils:sendHttpLog("assets_awb_"..tostring(awbName).."_retry_"..tostring(self._awbRetryTimes),false,self.remoteUrlIdx,nil)

		local faildTask = self.curTasks.normalTask
		if faildTask == nil then
			faildTask = self.curTasks.priorityTask
		end
		table.insert(self.priorityQuene,1,clone(faildTask))
		self.curTasks.priorityTask = nil 
		self.curTasks.normalTask = nil
		self:runNextDownload()
	end
	showGameAlert(alertparams)
    
	self.priorityTasks_process.cursize = 0
	self.priorityTasks_process.curtasksize = 0
	self.priorityTasks_process.speed = 0
	
end

function TFAssetsManager:onFileDownloadRetry(info)
	
end

function TFAssetsManager:getDownloading()
	return self.priorityTasks_process
end

function TFAssetsManager:getRemoteListDict( )
	return self.remoteListDict
end




function TFAssetsManager:loadAssetFile( id, downLoad )
	if id == nil then return false end
	print("loadAssetFile" ..tostring(string.format("%s%d.awb", self.extAssetsSavePath, id)))
	--检测awb的md5
	-- if downLoad then
	-- 	local localfilepath = string.format("%s%d.awb", self.extAssetsSavePath, id)
	-- 	if TFFileUtil:existFile(localfilepath) then
	-- 		local fileins = io.open(localfilepath,"rb")
	-- 		local fileContent = fileins:read("*a")
	-- 		local hashcode = md5.sumhexa(fileContent)
	-- 		fileins:close()
	-- 		local remotehash = self.remoteListDict[tostring(id)].md5
	-- 		dump({hashcode ,remotehash})
	-- 		if not(hashcode == remotehash) then
	-- 			os.remove(localfilepath)
	-- 			print("loadAssetFile  return ")
	-- 			return false
	-- 		end
	-- 	end
	-- end

	self.loadedAssetFile = self.loadedAssetFile or {}
	if self.loadedAssetFile[id] then return true end
	--不能解压的情况下LOAD
	if not self:canUnzipAwb() then
		MEAssetsBundle:defaultBundle():load(string.format("%d.awb", id))
	end
	-- MEAssetsBundle:defaultBundle():load(string.format("%d.awb", id))
	self.loadedAssetFile[id] = true
	return true
end




function TFAssetsManager:checkCdnAndUrlUpdate( url )
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
    --     	local parsed_url = tfUrl.parse(url)
    --     	HeitaoSdk.reportNetworkData(parsed_url.host)
    --     end
    -- end
end

--待解压的资源
function TFAssetsManager:getDownLoadedAwbFiles( )
	if self.extAssetsCfg == nil then return {} end
	local downLoadedList = {}
	for _,_cfg in pairs(self.extAssetsCfg) do
		if _cfg.packID then
			for _,_awbId in pairs(_cfg.packID) do
				local localfilepath = string.format("%s%d.awb",self.extAssetsSavePath, _awbId)
				if TFFileUtil:existFile(localfilepath) then
					if table.find(downLoadedList,_awbId) < 0 then 
						table.insert(downLoadedList, _awbId)
					end
				end
			end
		end
	end
	return downLoadedList
end


function TFAssetsManager:unZipAwb( callBack )
	--Box("unZipAwb")
	if TFClientAwbBundle == nil then 
		if callBack then callBack() end
		return
	end
	local downLoadedAwbList = self:getDownLoadedAwbFiles()
	print("unZipAwb:"..#downLoadedAwbList)	
	if #downLoadedAwbList < 1 then
		if callBack then callBack() end
		return
	end
	if self:canUnzipAwb() then
		Utils:openView("common.UnZipFileLayer", callBack)
	else
		--dump(downLoadedAwbList)
		--Box("xxx")
		for k,v in pairs(downLoadedAwbList) do
			self:loadAssetFile(v)
		end

		if callBack then 
			callBack() 
		end
	end
end

--canUnzipAwb
function TFAssetsManager:canUnzipAwb()
	if TFClientAwbBundle == nil then 
		return false
	end

	if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
		if TFClientGameAssetManager then
			print("canUnzipAwb true "..tostring(TFDeviceInfo:getSystemVersion()))
			return true
		end
	end
	return false
end

return TFAssetsManager

