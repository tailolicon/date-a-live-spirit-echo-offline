--测试包
DEBUG_PACKAGE = (HeitaoSdk and (HeitaoSdk.isTestPackage()))
-- RELEASE_TEST = DEBUG_PACKAGE
--用于海外多语言脚本资源处理相关
TFGlobalUtils = class('TFGlobalUtils')

--供SDK影射地址使用使用
MIGRATION_SERVER_LIST = {}
MIGRATION_SERVER_LIST.UNKNOW = 0
MIGRATION_SERVER_LIST.Other = 2
MIGRATION_SERVER_LIST.Taiwan = 3
MIGRATION_SERVER_LIST.Korea = 4

local KEY_CACHE_MIGRATION_SERVER_KEY = "KEY_CACHE_MIGRATION_SERVER_KEY"

--多语言ui
function TFGlobalUtils:loadUIConfigFilePath( uiPath )
	print("-------------------------------------------------uiPath: " ..uiPath)
	if string.find(uiPath ,"uiconfig_zn") then 
		return uiPath
	end

	-- if uiPath == "lua.uiconfig.secondary.uiconfig_zn.loginScene.resUpdateLayer" then  --多语言下载界面特殊处理
	-- 	return uiPath
	-- end
	
	local code = TFLanguageMgr:getUsingLanguageCode()
	local fullPath = string.gsub(uiPath , '%.' , '/')
	local secondaryFullPath = string.gsub(fullPath , 'uiconfig' , 'uiconfig/secondary/uiconfig_' ..code)
	secondaryFullPath = "src/" ..secondaryFullPath ..".lua"
	if TFFileUtil:existFile(secondaryFullPath) then
		local secondary = "uiconfig.secondary.uiconfig_" ..code
		return string.gsub(uiPath , 'uiconfig' , secondary)
	end
	return ""
end

--多语言表
function TFGlobalUtils:requireGlobalFile( path )
	local fullPath = string.gsub(path , '%.' , '/')
	local code = TFLanguageMgr:getUsingLanguageCode()
	local secondaryLanguage = ".table.secondary." ..code
	local secondaryLanguageFullPath = string.gsub(fullPath , '/table' , '/table/secondary/' ..code)   
	secondaryLanguageFullPath = "src/" ..secondaryLanguageFullPath ..".lua" 
	if TFFileUtil:existFile(secondaryLanguageFullPath) then
		local luaPath = string.gsub(path , '%.table' , secondaryLanguage)
		local file = require(luaPath)
		return file
	end

	local secondary = ".table.secondary"
	local secondaryFullPath = string.gsub(fullPath , '/table' , '/table/secondary') 
	secondaryFullPath = "src/" ..secondaryFullPath ..".lua" 
	if TFFileUtil:existFile(secondaryFullPath) then
		local file = require(string.gsub(path , '%.table' , secondary)) 
		return file
	end

	if TFFileUtil:existFile("src/" ..fullPath ..".lua") then
		local file = require(path) 
		return file
	end

	return {}
end

function TFGlobalUtils:unRequireGlobalFile( path )
	local code = TFLanguageMgr:getUsingLanguageCode()
	local fullPath = string.gsub(path , '%.' , '/')
	local secondaryLanguage = ".table.secondary." ..code
	local secondaryLanguageFullPath = string.gsub(fullPath , '/table' , '/table/secondary/' ..code)   
	secondaryLanguageFullPath = "src/" ..secondaryLanguageFullPath ..".lua" 
	if TFFileUtil:existFile(secondaryLanguageFullPath) then
		local luaPath = string.gsub(path , '%.table' , secondaryLanguage)
		TFDirector:unRequire(luaPath)
		return
	end

	local secondary = ".table.secondary."
	local secondaryFullPath = string.gsub(fullPath , '/table' , '/table/secondary/')   
	secondaryFullPath = "src/" ..secondaryFullPath ..".lua" 
	if TFFileUtil:existFile(secondaryFullPath) then
		TFDirector:unRequire(string.gsub(path , '%.table' , secondary))
		return
	end
end

--多语言动画
function TFGlobalUtils:transAniNameByLanguage( spine, name )
	if not spine:getSkeleton() then
		return name
	end
	--print(spine:getName()  .." origin play animation: " ..tostring(name))
	local aniName = spine:transToLanguageAniName(name, TFLanguageMgr:getUsingLanguage())
	--print(spine:getName()  .." new play animation: " ..tostring(aniName))
	return aniName
end

--多语言图片
function TFGlobalUtils:transTexturePath( texturePath )
	if texturePath == nil then return texturePath end
	if TFLanguageMgr:getUsingLanguage() == cc.SIMPLIFIED_CHINESE then
		return texturePath
	end

	local code = TFLanguageMgr:getUsingLanguageCode("_")
	if code ~= "" and texturePath and texturePath ~= "" then
		local engCode = TFLanguageMgr:getCodeByLanguage(cc.ENGLISH, "_")
		local engTexturePath = string.gsub(texturePath , "%." ,engCode..".")
		if type(texturePath) ~= "userdata" then --如果是传入pTexture数据则直接调用原函数
			if LanguageResMgr ~= nil then
				local pitctureData = LanguageResMgr:getData()
				if pitctureData[texturePath] and TFFileUtil:existFile(pitctureData[texturePath]) then
					texturePath = pitctureData[texturePath]
				elseif pitctureData[texturePath] and TFFileUtil:existFile(engTexturePath) then
					texturePath = engTexturePath
				end
			else
				local textureName = string.gsub(texturePath , "%." ,code..".")
				if TFFileUtil:existFile(textureName) then
					texturePath = textureName
				elseif TFFileUtil:existFile(engTexturePath) then
					texturePath = engTexturePath
				end
			end
		end
	end
	return texturePath
end

function TFGlobalUtils:checkPlayerProvision( playerName )
	local replaceTxt,count = string.gsub(playerName, "40389ef1390e11eb9" ,"******")
	return replaceTxt,count
end

-- function TFGlobalUtils:setMigrationServerId( value )
-- 	if value then
--         CCUserDefault:sharedUserDefault():setIntegerForKey(KEY_CACHE_MIGRATION_SERVER_KEY, value)
--         CCUserDefault:sharedUserDefault():flush()
--     end
-- end

-- function TFGlobalUtils:getMigrationServerId( isCache )
-- 	local value = CCUserDefault:sharedUserDefault():getIntegerForKey(KEY_CACHE_MIGRATION_SERVER_KEY, MIGRATION_SERVER_LIST.UNKNOW)
-- 	if (value > MIGRATION_SERVER_LIST.UNKNOW) and isCache then
-- 		return true, value
-- 	end
-- 	local defaultValue = MIGRATION_SERVER_LIST.Other
-- 	if NEW_APP_VERSION then
-- 		if TFLanguageMgr:getCurrentLanguage() == cc.KOREAN then
-- 			defaultValue = MIGRATION_SERVER_LIST.Korea
-- 		elseif TFLanguageMgr:getCurrentLanguage() == cc.TRADITIONAL_CHINESE then
-- 			defaultValue = MIGRATION_SERVER_LIST.Taiwan
-- 		end
-- 	end
-- 	return false, defaultValue
-- end

-- function TFGlobalUtils:getMigrationServerTextById( migrationServerId )
-- 	-- body
-- 	if migrationServerId == nil then return "" end
-- 	local textIdList = {}
-- 	textIdList[MIGRATION_SERVER_LIST.Other] = 190000819
-- 	textIdList[MIGRATION_SERVER_LIST.Taiwan] = 190000818
-- 	textIdList[MIGRATION_SERVER_LIST.Korea] = 190000817

-- 	if textIdList[migrationServerId] then return textIdList[migrationServerId] end
-- 	return ""
-- end

return TFGlobalUtils




