local AssetsMgr = AssetsMgr or {}

local strCfg = TFGlobalUtils:requireGlobalFile("lua.table.StartString")

-- local  StateEnum = 
-- {
--     Init = 0,                       --初始化
--     GetVersionInfo = 1,             --获取CDN版本信息
--     GetDownloadFileSize = 2,        --计算还需下载的文件大小
--     PreDownloadFile = 3,            --准备下载文件
--     DownloadAssets = 4,             --下载文件
--     UnCompressAssets = 5,           --解压文件
--     UpdateOver = 6,                 --更新完成，清除临时文件
-- }

-- local HotUpdatePauseEnum =
--     {
--         Maintained = 0,                 --维护中
--         NeedManuelDown = 1,             --需要手动更新
--         GetVersionFailed = 2,           --获取CDN版本文件失败，请检查网络连接
--         GetDownloadSizeFailed = 3,      --获取文件大小失败
--         DisSpaceError = 4,              --磁盘空间不足
--         NoticeUserSize = 5,             --检查到有更新资源需要下载，大小为多少（超过7M必须告知）
--         DownloadFailed = 6,             --下载文件失败
--         UnCompressFailed = 7,           --解压文件失败
--         GoogleAssetPackFailed = 8,      --Google AssetPack
--     }


--0状态初始加载本地版本信息 1 获取远程列表 2

AssetsMgr.State = 
{
	Init              = 0 , --初始化
	GetRemoteVersion  = 1 , --获取远程版本信息
	CheckFileState    = 2 , --检查文件状态是否需要更新
	Download          = 3 , --资源下载

	VerifyFiles        = 4 , --校验文件
	
	Uncompress         = 5 , --资源解压

	Complete          = 10 , -- 资源处理完成 
	ExitGame          = 100,  --退出游戏
}

--资源管理器初始化
function AssetsMgr:init()
	--应哟版本
	self.appVersion    = TFDeviceInfo:getCurAppVersion()
	--需要下载的资源版本号(通常这个打在包里)
	self.assetVersion  = GAME_ASSET_VERSION or "1.15"
	--本地存储的KEY
	self.asset_version_key = "asset_"..tostring(self.appVersion) .."_"..tostring(self.assetVersion)
    --根据平台初始化扩展资源保存路径
	local writablePath = CCFileUtils:sharedFileUtils():getWritablePath()
	--资源下载保存路径
	self.assetsSavePath = writablePath .. 'TFDebug/'
	self.unzipPath = writablePath.."TFAwbUnzipFiles/"  --默认解压目录无需设置，游戏启动时C++部分已设置
	__print("AssetsMgr:init----------------------")
	__print("appVersion: "..tostring(self.appVersion))
	__print("assetVersion: "..tostring(self.assetVersion))
	__print("download Path: "..tostring(self.assetsSavePath))
	__print("uncompress Path: "..tostring(self.unzipPath))
	__print("asset version key: "..tostring(self.asset_version_key))
	--目录不存在的情况下创建目录
	if not TFFileUtil:existFile(self.assetsSavePath) then
		TFFileUtil:createDir(self.assetsSavePath)
	end
	self.baseURL    = URL_REMOTE[1] ..tostring(self.assetVersion).."/"
	self.extlistURL = self.baseURL.. "extlist.json" 
	--读取本地版本信息
	self.state      = 0  

 

    --下载失败的文件列表
    self.downloadFailedFiles = {}
    --下载失败的文件列表
    self.unzipFailedFiles  = {}

    --当前节点资源文件
	self.nodeFiles = {}


    --下载的文件列表
    self.downloadFiles  = {}
    --解压的文件列表
    self.uncompressFiles   = {}
    --下载进度信息
    self.downloadProgress =  {} 
	self.downloadProgress.speed = 0
	self.downloadProgress.totalSize    = 100
	self.downloadProgress.completeSize = 10 


	self.uncompressProgress = {}
	self.uncompressProgress.totalSize    = 0
	self.uncompressProgress.completeSize = 0 

	--检查更新
	self.checkProgress = {}
	self.checkProgress.totalSize    = 0
	self.checkProgress.completeSize = 0 

	self:load()
end



--检查更新，从获取远程版本信息开始
function AssetsMgr:checkUpdate()
	self:exceuteState(AssetsMgr.State.GetRemoteVersion)
end


function AssetsMgr:exceuteState(state)
	self.state = state
	if self.state == AssetsMgr.State.Init then
		self:init()
	elseif self.state == AssetsMgr.State.GetRemoteVersion then
		self:getRemoteVersions()
    elseif self.state == AssetsMgr.State.CheckFileState then
    	self:checkFileState()
    elseif self.state == AssetsMgr.State.Download then 
    	self:startDownLoad()
    elseif self.state == AssetsMgr.State.VerifyFiles then 
   		self:verifyFiles()
   	elseif self.state == AssetsMgr.State.Uncompress then
   		self:startUncompress()
   	elseif self.state == AssetsMgr.State.Complete then 
    	self:onUpdateComplete()
    elseif self.state == AssetsMgr.State.ExitGame then 
		self:exitGame()
	end
end


function AssetsMgr:onUpdateComplete()
	--切换到正常游戏流程
	AlertManager:changeScene(SceneType.LOGO)
end
function AssetsMgr:showBox( content ,comfirmCallback ,cancelCallback ,confirm_title ,cancel_title ,title)
	local alertparams = clone(EC_GameAlertParams)
	alertparams.msg   = content
	alertparams.title = title or 270001 --下载提示
	alertparams.confirm_title   = confirm_title or alertparams.confirm_title
	alertparams.cancel_title    = cancel_title   or alertparams.cancel_title
	alertparams.comfirmCallback = comfirmCallback
	alertparams.cancelCallback  = cancelCallback
	alertparams.outsideClose    = false
	showGameAlert(alertparams)
end

-- --处理下载列表
-- function AssetsMgr:extraFileInfo(fileInfo)
-- 	local _fileInfo      = clone(fileInfo)
-- 	_fileInfo.url        = self.baseURL.._fileInfo.name..".awb"
-- 	_fileInfo.saveName   = self.assetsSavePath ..string.format("%s_%s.temp",_fileInfo.name,_fileInfo.md5) --使用名字加md5 作为主键 作为下载的文件
-- 	return _fileInfo
-- end



function AssetsMgr:getLocalFliePath( fileInfo )
	local saveName   = self.assetsSavePath ..string.format("%s_%s.temp",fileInfo.name,fileInfo.md5)
	return saveName
end


--显示下载弹框
function AssetsMgr:showDownloadBox()
	local totalSize = 0 
	for i, file in pairs(self.downloadFiles) do
		totalSize = totalSize + file.size 
	end
	
	local tipID = TFDeviceInfo:getNetWorkType() == "WIFI" and 270004 or 270005
	--虽然有断点续传，这里以文件为单位显示需要下载的大小，实际下载大小可能要小于展示的大小，避免获取文件大小
	local content = TextDataMgr:getText(tipID,Utils:tranFileSize(totalSize))
	self:showBox(content ,function ( )
		-- print("点击确定了")
		self:exceuteState(AssetsMgr.State.Download)
	end ,function ( )
		print("点击取消了")
		self:exceuteState(AssetsMgr.State.ExitGame)
	end)
end






function AssetsMgr:showDownloadFailedBox(failedFiles)
	self:showBox(270008 ,function ()
		self.downloadFiles = {}
		--准备下载文件的列表
		for i,fileName in ipairs(failedFiles) do		
			local fileInfo = self:getFileInfo(fileName)
			self.downloadFiles[fileInfo.name] = fileInfo
		end
		dump(self.downloadFiles)
		print("确定重试")
		self:exceuteState(AssetsMgr.State.Download)
	end ,function ( )
		print("点击取消退出游戏")
		self:exceuteState(AssetsMgr.State.ExitGame)
	end ,800085 ,3005051 ,270001)



	-- local alertparams = clone(EC_GameAlertParams)
	-- alertparams.msg = 270008
	-- alertparams.title = 270001
	-- alertparams.confirm_title = 800085
	-- alertparams.cancel_title = 3005051
	-- alertparams.cancelCallback = function()
	-- 	self:exceuteState(AssetsMgr.State.ExitGame)
	-- end
	-- alertparams.comfirmCallback = function()

	-- end
	-- showGameAlert(alertparams)

end


function AssetsMgr:getLocalFileInfo(name)
	return self.localVersions[name]
end

function AssetsMgr:checkFileState()
	local fileInfos = {}
	for k, v in pairs(self.remoteVersions) do
		table.insert(fileInfos,v)
	end
	local fileSize = #fileInfos
	self.downloadFiles   = {}
    self.uncompressFiles = {}
    self.checkProgress.totalSize    = fileSize
    self.checkProgress.completeSize = 0
    self.checkStateTimer = TFDirector:addTimer(10, #fileInfos, function()
    	print("检查文件完成")
      	self.checkProgress.completeSize = self.checkProgress.totalSize
      	TFDirector:removeTimer(self.checkStateTimer)
		if table.count(self.downloadFiles) > 0 then 
			print("有文件需要下载")
			self:showDownloadBox() --弹框提示下载
			return
		end
		if table.count(self.uncompressFiles) > 1 then
			print("有文件需要解压")
			self:exceuteState(AssetsMgr.State.Uncompress)	
		else
			print("没有文件需要处理")
			self:exceuteState(AssetsMgr.State.Complete)	
		end
    end ,function ()
    	if #fileInfos > 0 then 
    		local fileInfo      = fileInfos[1]
    		print("检查文件:"..tostring(fileInfo.name))
    		table.remove(fileInfos, 1)
    		self.checkProgress.completeSize = self.checkProgress.totalSize - #fileInfos
    		local localFileInfo = self:getLocalFileInfo(fileInfo.name)
    		if not localFileInfo then 
    			print("本地无文件信息 添加到下载列表"..tostring(fileInfo.saveName)) 
    			self.downloadFiles[fileInfo.name] = fileInfo
    			return
    		end
    		local localFilePath = self:getLocalFliePath( localFileInfo )
    		if fileInfo.md5 ~= localFileInfo.md5 then 
    			print("文件md5不一致下载新文件 添加到下载列表"..tostring(fileInfo.saveName)) 
    			self.downloadFiles[fileInfo.name] = fileInfo
    			--删除贝蒂旧文件
    			if TFFileUtil:existFile(localFilePath) then
    				local result, err = os.remove(localFilePath) --必须绝对路径
			        print("删除旧版资源："..tostring(localFilePath).." ret:"..tostring(result).." erro:"..tostring(err))
    			end
    			return
    		end
    		if not localFileInfo.state  or  localFileInfo.state < 1 then  --小于的表示未下载
    			print("文件未下载 添加到下载列表"..tostring(fileInfo.saveName)) 
    			self.downloadFiles[fileInfo.name] = fileInfo
    			return 
    		end
    		if localFileInfo.state == 1 then  --下载完成未解压添加至解压列表
    			local fileSize = self:getFileSize(fileInfo.saveName)
    			if fileInfo.size == fileSize then
    			    print("文件大小一致 添加到解压列表"..tostring(fileInfo.saveName)) 
                	self.uncompressFiles[fileInfo.name] = fileInfo
            	else
            		self.downloadFiles[fileInfo.name] = fileInfo
            		print("文件大小不一致 重新下载"..tostring(fileInfo.saveName))
            	end
    			return
    		end
    	end
    end)
    EventMgr:dispatchEvent("CHECK_START")
end


--退出游戏
function AssetsMgr:exitGame()
    DelayCall(function()
        me.Director:endToLua()
    end)
end


--获取下载进度
function AssetsMgr:getDownloadProgress()


	return self.downloadProgress
end

function AssetsMgr:startDownLoad()

	print("开始下")
	self._downloadFiles = {}


	local totalSize = 0
	for i, file in pairs(self.downloadFiles) do
		totalSize = totalSize + file.size 
	end

	if not self:checkFreeSpace(totalSize) then
		print("设备存储空间不足停止下载")
		DelayCall(function ()
			self:showNotEnoughFreeSpaceBox()
		end)
		return
	end

	self.downloadProgress.speed        = 0
	self.downloadProgress.completeSize = 0  
	self.downloadProgress.totalSize    = totalSize 
	local jsonContent = json.encode(self.downloadFiles)
	dump(self.downloadFiles)
	--组织下载文件列表
	DownloadHelper:starts(jsonContent,
		handler(self.onDownloadStart,self),
		handler(self.onDownloadProgress,self),
		handler(self.onDownloadedFile,self),
		handler(self.onDownloadComplete,self),
		handler(self.onDownloadFailed,self))

	EventMgr:dispatchEvent("DOWNLOAD_START")
end

--加载本地版本信息
function AssetsMgr:load()
	self.localVersions = {}
	local jsonString   = CCUserDefault:sharedUserDefault():getStringForKey(self.asset_version_key)
	print("jsonString"..tostring(jsonString))
	self.localVersions = json.decode(jsonString) or {}
	dump(self.localVersions)

end

--保存版本信息
function AssetsMgr:save()
	self.localVersions = self.localVersions or {}
	local content = json.encode(self.localVersions)
	CCUserDefault:sharedUserDefault():setStringForKey(self.asset_version_key, content)
	CCUserDefault:sharedUserDefault():flush()

end
--保存下载文件的状态
function AssetsMgr:setLocalFileState(name ,md5 ,state)
	self.localVersions = self.localVersions or {}
	self.localVersions[name] = {name = name ,md5 = md5 ,state = state}
end
-- {
--  "md5"   = "83afb59f0f0da607cc2fb0b74dfcae32"
--  "name"  = "7038"
-- 	"size"  = 66679986
-- 	"state" = 0 
-- }

--[[
下载临时文件名 name_md5 

--]]

--远程版本信息返回
function AssetsMgr:onRemoteVersion(data)
	self.remoteVersions  = json.decode(data)
	--组装补充完整数据
	for k , v in pairs(self.remoteVersions) do
		v.name       = k
		v.url        = self.baseURL..v.name..".awb"
	    v.saveName   = self.assetsSavePath ..string.format("%s_%s.temp",v.name,v.md5)
	end
	dump(self.remoteVersions)

	-- --TODO 暂不做分包下载全资源，如果做分包当前只需要下载第一个节点资源
	-- for k,v in pairs(self.remoteVersions) do
	-- 	self.nodeFiles[k] = v
	-- end

	--获取版本信息成功，开始比较文件需要下载哪些资源
	self:exceuteState(AssetsMgr.State.CheckFileState)
end

function AssetsMgr:onRemoteVersionError(resposeCode)
	local textID = 100048
	if resposeCode == -1 then --网络连接错误
		textID = 100048
	else  --其他错误信息
		textID = 100048
	end

	self:showBox(textID,function ()
		self:getRemoteVersions()
	end,function ()
		self:exitGame()				
	end)

end


--获取远程版本信息
function AssetsMgr:getRemoteVersions()
	print("getRemoteVersions()")
	--获取远程资源局列表
	-- Utils:sendHttpLog("assets_extlist_new",false,1)
    local UserCenterHttpClient = TFClientNetHttp:GetInstance()
    UserCenterHttpClient:addMERecvListener(function (httpType,resposeCode,data )
        print("resposeCode:"..tostring(resposeCode))
       	if resposeCode == 200 or resposeCode == 206 then 
       		self:onRemoteVersion(data)
       	else -- 网路连接失败
       		self:onRemoteVersionError(resposeCode)
       	end
    end)
    UserCenterHttpClient:httpRequest(TFHTTP_TYPE_GET,self.extlistURL)
end

function AssetsMgr:showNotEnoughFreeSpaceBox()
	local alertparams = clone(EC_GameAlertParams)
	alertparams.msg = 270007
	alertparams.title = 270001
	alertparams.showtype = 1
	alertparams.outsideClose = false
    alertparams.comfirmCallback = function()
    	self:exceuteState(AssetsMgr.State.ExitGame)
    end
	showGameAlert(alertparams)
end


--检查设备剩余空间
function AssetsMgr:checkFreeSpace(filesSize)

	local freedisksize = TFDeviceInfo:getAppPrivateFreeSpace()
	print("PrivateFreeSpace :"..tostring(freedisksize))
	if freedisksize then 
		filesSize = filesSize/1048576
		if freedisksize < filesSize then
			local errorInfo     = {}
			errorInfo.freedisksize = freedisksize
			errorInfo.filesSize = filesSize
			Utils:sendHttpLog("assets_not_enough_space",false,1,nil,errorInfo)
			print("设备空间不足")
			return false
		end
	end
	return true
end


function AssetsMgr:onDownloadStart(info)
		print("onDownloadStart")
end
--所有文件下载完成
function AssetsMgr:onDownloadComplete(info)
	print("onDownloadComplete")
	local info = json.decode(info)
	dump(info)
 --所有文件标记为已下载
 	
	-- _fileInfo.url        = self.baseURL.._fileInfo.name..".awb"
	-- _fileInfo.saveName   = self.assetsSavePath ..string.format("%s_%s.temp",_fileInfo.name,_fileInfo.md5) --使用名字加md5 作为主键 作为下载的文件
	-- return _fileInfo
	--开始校验文件
	self:exceuteState(AssetsMgr.State.CheckFileState)
end


--获取文件大小
function AssetsMgr:getFileSize(filename)
    if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
    	local ok,ret = TFLuaOcJava.callStaticMethod("org/phanta/util/Downloader", "getFileSize", {filename}, "(Ljava/lang/String;)I")
    	return HeitaoSdk.checkResult(ok,ret)
	end
	print("当前平台不支持 getFileSize")
	return 0
end

--获取文件大小
function AssetsMgr:removeAllDownloadTask()
    if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
    	local ok,ret = TFLuaOcJava.callStaticMethod("org/phanta/util/Downloader", "removeAllTask", nil, "()V")
	end
end


--删除本地文件(只能删除本地文件或空文件夹需要完整的绝对路径)
function AssetsMgr:deleteLocalFile(filename)
	if TFFileUtil:existFile(filename) then 
		local ret ,erro = os.remove(filename)
		print("删除文件:"..filename .." ret:"..tostring(ret) .. " erro:".. tostring(erro))
	end
end


function AssetsMgr:verifyFileSingle(fileInfo)
	local size = self:getFileSize(fileInfo.saveName)
	if fileInfo.size == size then 
		return true
	end
end 
--验证文件的正确性
function AssetsMgr:verifyFiles()
	self.uncompressFiles    = {}
	self.verifyFailedFiles = {}
	local time = os.clock()*1000
    for i, fileInfo in pairs(self.remoteVersions) do  --TODO 正常情况需要检查文件的完好性
    	if self:verifyFileSingle(fileInfo) then 
    		self:setLocalFileState(fileInfo.name , fileInfo.md5, 1) --标记为下载完成
    		self.uncompressFiles[fileInfo.name] = fileInfo
    	else
    		self.verifyFailedFiles[fileInfo.name] = fileInfo
    		print("file 不完整需重先下载："..v.name  )
    	end
 	end
 	self:save()
 	print("PassTime: " .. (os.clock()*1000 -time) .." ms")

 	--检查完成后
 	if table.count(self.verifyFailedFiles)  > 0 then 
 		--todo 跳转下载
 		print("待解压的文件校验失败跳转下载")

 	else
 		--解压
 		self:exceuteState(AssetsMgr.State.Uncompress)
 	end
end


function AssetsMgr:getCheckProgress()
	return self.checkProgress
end


function AssetsMgr:getUncompressProgress()
	return self.uncompressProgress
end


function AssetsMgr:startUncompress()
	print("开始解压")
	dump(self.uncompressFiles)
	
	self.uncompressFailedFiles = {}
    self.uncompressProgress.completeSize = 0
	self.uncompressProgress.totalSize = table.count(self.uncompressFiles)
	local jsonContent = json.encode(self.uncompressFiles)
	DownloadHelper:unzip(jsonContent,
		handler(self.onUnzipStart,self),
		handler(self.onUnzipProgress,self),
		handler(self.onUnzipFileSuccess,self),
		handler(self.onUnzipFileFailed,self),
		handler(self.onUnzipComplete,self))
	EventMgr:dispatchEvent("UNZIP_START")

end
--开始解压
function AssetsMgr:onUnzipStart(info)
	print("onUnzipStart")
end
--解压进度更新
function AssetsMgr:onUnzipProgress(info)
	print("onUnzipProgress:" ..info)
	local progress = json.decode(info)
    self.uncompressProgress.completeSize = progress.completeSize
	self.uncompressProgress.totalSize = progress.totalSize
end

function AssetsMgr:getFileInfo(fileName)
	return self.remoteVersions[fileName]
end
--单个文件解压
function AssetsMgr:onUnzipFileSuccess(fileName)
	print("onUnzipFileSuccess:" ..fileName)
	local fileInfo = self:getFileInfo(fileName)
	dump(fileInfo)
	--标记为已解压
	if fileInfo then 
		--保存已解压状态
		self:setLocalFileState(fileInfo.name ,fileInfo.md5,2)  
		self:save()
		--删除本地文件
		self:deleteLocalFile(fileInfo.saveName)
	end
end
--解压失败
function AssetsMgr:onUnzipFileFailed(fileName)
	print("onUnzipFileFailed:" ..tostring(fileName))
	table.insert(self.uncompressFailedFiles,fileName)
end

--所有文件解压完成
function AssetsMgr:onUnzipComplete(info)
	print("onUnzipComplete:"..tostring(info))

	if #self.uncompressFailedFiles > 0 then --有解压失败情况 
		print("解压失败--")
		dump(self.uncompressFailedFiles)
		self:exceuteState(AssetsMgr.State.CheckFileState)
	else
		print("解压完成--再次验证文件")
		self:exceuteState(AssetsMgr.State.CheckFileState)
	end 
end


--下载进度更新
function AssetsMgr:onDownloadProgress(info)
	print("onFileDownloadProgress")
	local info = json.decode(info)
	dump(info)
	self.downloadProgress.speed        = info.speed
	self.downloadProgress.completeSize = info.completeSize  
	self.downloadProgress.totalSize    = info.totalSize 


end


--文件下载完成()
function AssetsMgr:onDownloadedFile(info)
	local info = json.decode(info)
	print("Single file download complete ")	  
	--这里可以保存文件的下载状态
	print(info)

	for k,fileName in pairs(info) do
		local fileInfo = self:getFileInfo(fileName)
		if fileInfo then
			self:setLocalFileState(fileInfo.name,fileInfo.md5,1) 
		end
	end
	--保存文件状态
	self:save()


	--TODO 测试用 后续删除
	self._downloadFiles = self._downloadFiles or {}
	for k,v in pairs(info) do
		table.insert(self._downloadFiles,v)
	end
	print("self._downloadFiles size " .. #self._downloadFiles)
	dump(self._downloadFiles)
end


function AssetsMgr:onDownloadFailed(info)
	print("file download failed"..tostring(info))
	local failedFiles = json.decode(info)
	dump(failedFiles)
	--TODO 提示下载失败弹框然后重试
	self:showDownloadFailedBox(failedFiles)

	
end









function AssetsMgr:checkCdnAndUrlUpdate( url )
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





AssetsMgr:init()
-- --初始化
-- local time = os.time()
-- AssetsMgr:init()
-- print("PassTime:" ..(os.time() -time))
return AssetsMgr

