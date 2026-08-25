local DatingEditScene = class("DatingEditScene", BaseScene)
function DatingEditScene:ctor(data)
	self.super.ctor(self,data)
 	local layer = require("lua.logic.dating.DatingTestView"):new()
    self:addLayer(layer)
end

function DatingEditScene:onEnter(re)
	self.super.onEnter(self)
end

function DatingEditScene:onExit()
	self.super.onExit(self)
end

return DatingEditScene;