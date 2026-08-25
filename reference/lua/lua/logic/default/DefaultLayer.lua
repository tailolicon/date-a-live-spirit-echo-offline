
local DefaultLayer = class("DefaultLayer", function(...)
	local layer = TFPanel:create()
	return layer
end)


local displayResList = require('default.defultdisplay')

function DefaultLayer:ctor(data)

	if not CUtils.getVersion or CUtils.getVersion() ~= "1.0.0" then
		me.Director:endToLua();
	end

	--删除热更起始版本设置文件
	if CC_TARGET_PLATFORM == CC_PLATFORM_ANDROID then
		local uName = "src/TFFramework/net/TFClientUpdate.lua"
	 	if TFFileUtil:existFile(uName) then
	 		local fullpath = me.FileUtils:fullPathForFilename(uName);
	 		if not string.find(fullpath,"assets") then
	 			me.FileUtils:removeFile(fullpath);
	 		end
	 	end
	 end
	
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

	Utils:sendHttpLog("icon_C")
	local __path = "video0/shanpin.mp4";
	if not TFFileUtil:existFile(__path) then
		TimeOut(function()
				self:enterGame();
			end,0)
		return
	end

	TimeOut(function()
			MovieScene:create({
			path = __path,
			showSkip = false,
			endCall = function() 
				self:enterGame()
			end
		})
		end,0);

	do return end

end



function DefaultLayer:removeUI()

end

function DefaultLayer:registerEvents()

end

function DefaultLayer:removeEvents()
	TFDirector:removeTimer(self.timer)
    self.timer = nil
end

function DefaultLayer:changeImage()

	if self.showImage then
		self.showImage:removeFromParent()
		self.showImage = nil
	end

	-- print("显示图片 = ", displayResList[self.picIndex].name)

	local image = TFImage:create()

    image:setTexture(displayResList[self.picIndex].name)
    image:setAnchorPoint(ccp(0.5, 0.5))
    self:addChild(image)

    local pDirector = CCDirector:sharedDirector()


    -- local frameSize = pDirector:getOpenGLView():getFrameSize()
    local frameSize = GameConfig.WS--pDirector:getOpenGLView():getFrameSize()
    image:setPosition(ccp(frameSize.width/2, frameSize.height/2))

    local imageSize  	= image:getSize()
    local imageWidth 	= imageSize.width
    local imageHeight 	= imageSize.height

    --image:setScaleX(frameSize.width/imageWidth)
    --image:setScaleY(frameSize.height/imageHeight)


    -- print("frameSize = ", frameSize)
    -- print("imageWidth = ", imageWidth)
    -- print("imageHeight = ", imageHeight)
    --
    self.showImage = image
end

-- 开始
function DefaultLayer:startAction()
	function fadeOut()
		-- print("imageAction")
		local tween =
	    {
	        target = self.showImage,

	        {
            	duration = 1,
            	alpha 	 = 0,
	    	},

	        {
		        duration = 0,
	            onComplete = function ()
		            TFDirector:killAllTween()
	                -- print("step action complete")
	                self.picIndex = self.picIndex + 1
	                -- print("self.picIndex = ", self.picIndex)
	                if self.picIndex > self.picNum then
	                	-- print("显示完成，准备进入游戏")
	                	self:enterGame();
	                	--self:showLogo()
	                else
	                	-- print("开始下一场图片")
	                	self:changeImage()
	                	self:startAction()
	                end
	            end,
	        }

	    }
	    TFDirector:toTween(tween)
	end

	-- self:enterGame()

	local function fadeInAndOut()
		local tween =
	    {
	        target = self.showImage,

	        {
	         	ease = {type=TFEaseType.EASE_IN, rate=5}, --由慢到快
            	duration = 1,
            	alpha 	 = 1,
	    	},

	        {
            	duration = 1,
            	alpha 	 = 0,
	    	},

	        {
		        duration = 0,
	            onComplete = function ()
		            TFDirector:killAllTween()
	                self.picIndex = self.picIndex + 1
	                if self.picIndex > self.picNum then
	                	-- print("显示完成，准备进入游戏")
	                	self:enterGame();
	                	--self:showLogo()
	                else
	                	-- print("开始下一场图片")
	                	self:changeImage()
	                	self:startAction()
	                end
	            end,
	        }

	    }
	    TFDirector:toTween(tween)
	end

	if self.picIndex > 1 then
		self.showImage:setAlpha(0)
		fadeInAndOut()
	else
		fadeOut()
	end

end

function DefaultLayer:showLogo()
	local logoAni = SkeletonAnimation:create("ui/logo/logoAni/logo");
	logoAni:setPosition(ccp(GameConfig.WS.width / 2,GameConfig.WS.height / 2));
	logoAni:playByIndex(0, -1, -1, 0)
	self:addChild(logoAni)


	local timer
	local function delayToAction()
    	TFDirector:removeTimer(timer)
        timer = nil
        self:enterGame()
    end
    timer = TFDirector:addTimer(3500, -1, nil, delayToAction)
end

function DefaultLayer:enterGame()
    local UpdateLayer   = require("lua.logic.login.UpdateLayer_new")
    AlertManager:changeScene(UpdateLayer:scene())
 
end

return DefaultLayer