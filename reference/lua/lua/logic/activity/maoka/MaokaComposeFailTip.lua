--[[
*                       .::::.
*                     .::::::::.
*                    :::::::::::
*                 ..:::::::::::'
*              '::::::::::::'
*                .::::::::::
*           '::::::::::::::..
*                ..::::::::::::.
*              ``::::::::::::::::
*               ::::``:::::::::'        .:::.
*              ::::'   ':::::'       .::::::::.
*            .::::'      ::::     .:::::::'::::.
*           .:::'       :::::  .:::::::::' ':::::.
*          .::'        :::::.:::::::::'      ':::::.
*         .::'         ::::::::::::::'         ``::::.
*     ...:::           ::::::::::::'              ``::.
*    ```` ':.          ':::::::::'                  ::::..
*                       '.:::::'                    ':'````..
*
* 
]]

local MaokaComposeFailTip = class("MaokaComposeFailTip",BaseLayer)

function MaokaComposeFailTip:ctor( rewards )
	-- body
	self.super.ctor(self)
    self:showPopAnim(true)
	self.rewards = rewards
	self:init("lua.uiconfig.secondary.uiconfig_zn.activity.composFail")
end

function MaokaComposeFailTip:initUI( ui )
	-- body
	self.super.initUI(self,ui)
	self.Panel_base = TFDirector:getChildByPath(ui,"Panel_base")
	self.Button_close = TFDirector:getChildByPath(ui,"Button_close")
	self.Image_itemIcon = TFDirector:getChildByPath(ui,"Image_itemIcon")
	self.Label_num = TFDirector:getChildByPath(ui,"Label_num")


    self.Label_title = TFDirector:getChildByPath(self.Panel_base,"Label_title")
    self.Label_1 = TFDirector:getChildByPath(self.Panel_base,"Label_1")
    self.Label_title:setTextById(800063) -- 失败
    self.Label_1:setTextById(13317159) --很遗憾，调制失败啦！获得安慰奖：


	if self.rewards then
		local itemId = self.rewards[1].id
		local num = self.rewards[1].num

		self.Image_itemIcon:setTexture(GoodsDataMgr:getItemCfg(itemId).icon)
		self.Label_num:setText("x"..num)
	else
		self.Image_itemIcon:hide()
		self.Label_num:hide()
	end
end

function MaokaComposeFailTip:registerEvents( ... )
	self.super.registerEvents(self)
	-- body
	self.Button_close:onClick(function ( ... )
		-- body
		AlertManager:closeLayer(self)
	end)
end
return MaokaComposeFailTip