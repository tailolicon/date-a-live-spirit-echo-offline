TFClientUpdateClass = TFClientUpdate
TFClientUpdate = TFClientResourceUpdate:GetClientResourceUpdate()

if not TFClientUpdate.initConfig then 
    function TFClientUpdate:initConfig()
        TFClientUpdate:SetUpdateLastBinFile("/../Library/lastfile.bin")
        if CC_PLATFORM_WIN32 == CC_TARGET_PLATFORM then
            TFClientUpdate:SetUpdateLastestFile("check.xml")
        else
            TFClientUpdate:SetUpdateLastestFile("check.xml?xxx=" .. TFDeviceInfo:getMachineOnlyID())
        end
        TFClientUpdate:SetUpdateDefaultVersion("1.1.18")
        --多语言资源版本（iOS 使用）
		GAME_LANG_RES_VERSION = "109"

        --安卓扩展资源版本号
        GAME_ASSET_VERSION = "1.17"
    end
end

TFClientUpdate:initConfig()
return  TFClientUpdate