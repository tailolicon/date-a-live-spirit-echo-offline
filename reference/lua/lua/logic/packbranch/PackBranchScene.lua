local PackBranchScene = class("PackBranchScene", BaseScene)

function PackBranchScene:ctor(data)
    self.super.ctor(self,data)
end

function PackBranchScene:onEnter()
	self.super.onEnter(self)
    self:autoSelect()
end

function PackBranchScene:isNewAssetDownLoad()
    return tonumber(TFDeviceInfo:getCurAppVersion()) >= 1.33 
end

function PackBranchScene:autoSelect()
    if not self.___mainLayer then
        if self:isNewAssetDownLoad() then 
            EX_ASSETS_ENABLE = 0 --
            self.___mainLayer = requireNew("lua.logic.packbranch.AssetLayer"):new()
        else
            self.___mainLayer = requireNew("lua.logic.packbranch.PackBranchLayer"):new()
        end
        self:addLayer(self.___mainLayer)
    end
end

function PackBranchScene:dispose()
    self.layer:dispose()
end

return PackBranchScene