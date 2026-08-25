local GoogleAssetPackScene = class("GoogleAssetPackScene", BaseScene)

function GoogleAssetPackScene:ctor(data)
    self.super.ctor(self,data)
end

function GoogleAssetPackScene:onEnter()
	self.super.onEnter(self)

    if not self.___mainLayer then
        local layer = requireNew("lua.logic.googleAssetPack.GoogleAssetPackLayer"):new()
        self:addLayer(layer)
        self.___mainLayer = layer;
        --self.___mainLayer:onShow()
    end
end

function GoogleAssetPackScene:dispose()
    self.layer:dispose()
end

return GoogleAssetPackScene