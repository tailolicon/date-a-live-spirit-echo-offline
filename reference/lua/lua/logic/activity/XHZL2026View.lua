local XHZL2026View = class("XHZL2026View",BaseLayer)
local GIFT_STATE = {
	LOCK  = 0,
    ING   = 1,    -- 进行中
    GETED = 2,    -- 已
}


local function swap_pairs(arr)
    -- 从索引 3 开始，每次递增 4 来处理需要交换的索引对
    for i = 3, #arr, 4 do
        -- 检查当前索引 i 和 i + 1 是否在数组范围内
        if i + 1 <= #arr then
            -- 交换索引 i 和 i + 1 的值
            arr[i], arr[i + 1] = arr[i + 1], arr[i]
        end
    end
    -- 返回交换后的数组
    return arr
end


function XHZL2026View:ctor( data )
	-- body
	self.super.ctor(self,data)
	-- self.investorCfg = TabDataMgr:getData("Investor",1)
	self.activityId   = data or 295
    self.activityInfo = ActivityDataMgr2:getActivityInfo(self.activityId)
    self.rechargeIds = self.activityInfo.extendData.rechargeId or {}
	self.showRechargeIds = swap_pairs(clone(self.rechargeIds))
	dump(self.rechargeIds)
    dump(self.showRechargeIds)
	local pair = math.floor(#self.rechargeIds/2) 
	for i = 1 , pair do
	    
	end


	self:init("lua.uiconfig.secondary.uiconfig_zn.activity.xhzl2026View")
end


function XHZL2026View:refreshArrow(node ,idx)
	local arrowIndex = 0
	local LR = (idx-1) %2  == 0
	local TB = math.floor((idx-1) /2) %2 == 0 
	if TB  then  --奇数行
		arrowIndex = LR and 1 or 3
	else --偶数行
		arrowIndex = LR and 2 or 1
	end
	arrowIndex = (idx -1) == 0 and  0  or  arrowIndex
	for i=1,3 do
		local nodeArrow = TFDirector:getChildByPath(node,"Image_arrow"..i)
		nodeArrow:setVisible(arrowIndex == i)
	end




	--print(string.format("----------------------------------------------idx: %s  行: %s ", idx ,math.floor(idx/2)))

end



--获取礼包状态
function XHZL2026View:getGiftState(giftId)
	local preBuyed = true
	for i,v in ipairs(self.rechargeIds) do
		local giftData = RechargeDataMgr:getGiftSingleData(v)
		if v == giftId then 
			if preBuyed  then
				if RechargeDataMgr:getBuyCount(giftId) < giftData.buyCount then 
					return GIFT_STATE.ING
				else
					return GIFT_STATE.GETED
				end
			else
				return GIFT_STATE.LOCK
			end
		else
			preBuyed = RechargeDataMgr:getBuyCount(v) >= giftData.buyCount 
		end
	end
	return GIFT_STATE.LOCK
end

function XHZL2026View:updateItem(node , itemId ,idx)
	self:refreshArrow(node, idx)

	node:setVisible(true)


	local giftData = RechargeDataMgr:getGiftSingleData(itemId)
	--dump(giftData)

    local Image_task_des= TFDirector:getChildByPath(node,"Image_task_des")
    Image_task_des:hide()
	local lableDes= TFDirector:getChildByPath(node,"Label_task_des")
	lableDes:setText(giftData.name)
	-- dump(itemInfo)
	--if true then return end
	-- dump(progressInfo)
	local reward1 = TFDirector:getChildByPath(node,"Image_reward_1")
	local reward2 = TFDirector:getChildByPath(node,"Image_reward_2")

	local reward3 = TFDirector:getChildByPath(node,"Image_reward_3")
	local reward4 = TFDirector:getChildByPath(node,"Image_reward_4")

	if not node.Panel_goodsItem1 then 
	    node.Panel_goodsItem1 = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
	    node.Panel_goodsItem1:Scale(0.75)
	    node.Panel_goodsItem1:Pos(0, 0):AddTo(reward1)
	end
	if not node.Panel_goodsItem2 then 
	    node.Panel_goodsItem2 = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
	    node.Panel_goodsItem2:Scale(0.75)
	    node.Panel_goodsItem2:Pos(0, 0):AddTo(reward2)
	end


	if not node.Panel_goodsItem3 then 
	    node.Panel_goodsItem3 = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
	    node.Panel_goodsItem3:Scale(0.75)
	    node.Panel_goodsItem3:Pos(0, 0):AddTo(reward3)
	end
	if not node.Panel_goodsItem4 then 
	    node.Panel_goodsItem4 = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
	    node.Panel_goodsItem4:Scale(0.75)
	    node.Panel_goodsItem4:Pos(0, 0):AddTo(reward4)
	end


	-- node.Panel_goodsItem1:setVisible(false)
	-- node.Panel_goodsItem2:setVisible(false)
	-- node.Panel_goodsItem3:setVisible(false)
	-- node.Panel_goodsItem4:setVisible(false)

	node.Panel_goodsItem1:getParent():setVisible(false)
	node.Panel_goodsItem2:getParent():setVisible(false)

    node.Panel_goodsItem3:getParent():setVisible(false)
	node.Panel_goodsItem4:getParent():setVisible(false)


	local rewardIdx = 1
	for k,v in pairs(giftData.item or {}) do
		local itemNode = node["Panel_goodsItem"..rewardIdx]
		if itemNode then 
			itemNode:getParent():setVisible(true)
			PrefabDataMgr:setInfo(itemNode, tonumber(v.id), v.num)
		end
		rewardIdx = rewardIdx + 1
	end


	local button_action  = TFDirector:getChildByPath(node,"Button_action")
	local Label_name = TFDirector:getChildByPath(button_action,"Label_name")
	local Image_icon = TFDirector:getChildByPath(button_action,"Image_icon")
	Image_icon:hide()
	Label_name:setPosition(ccp(0,0))
	
	button_action:onClick(function()
		self:buy(giftData)
	end)

	local state  = self:getGiftState(itemId)
	if state == GIFT_STATE.LOCK then
		-- Label_name:setTextById(450010) 
		button_action:setGrayEnabled(true)
		button_action:setTouchEnabled(false)
		if giftData.buyType == 1 then --兑换
			local exchangeCost = giftData.exchangeCost[1]
			if exchangeCost and exchangeCost.num > 0 then
				local iconPath  = TabDataMgr:getData("Item",exchangeCost.id).icon
				Label_name:setText(tostring(Utils:format_number(exchangeCost.num,10000)))
				Label_name:setPosition(ccp(12,0))
				Image_icon:setTexture(iconPath)
				Image_icon:show()
			else
				Label_name:setTextById(1820002)
				Label_name:setPosition(ccp(0,0))
			end
		else --购买
			Label_name:setTextById(1605003,giftData.rechargeCfg.price*0.01)
		end

	elseif state == GIFT_STATE.ING then
		if itemId == 57580 then 
			Label_name:setTextById(1820002)
			Label_name:setPosition(ccp(0,0))
		else
			if giftData.buyType == 1 then --兑换
				local exchangeCost = giftData.exchangeCost[1]
				if exchangeCost and exchangeCost.num > 0 then
					local iconPath  = TabDataMgr:getData("Item",exchangeCost.id).icon
					Label_name:setText(tostring(Utils:format_number(exchangeCost.num,10000)))
					Label_name:setPosition(ccp(12,0))
					Image_icon:setTexture(iconPath)
					Image_icon:show()
				else
					Label_name:setTextById(1820002)
					Label_name:setPosition(ccp(0,0))
				end
			else --购买
				Label_name:setTextById(1605003,giftData.rechargeCfg.price*0.01)
			end
		end
		button_action:setGrayEnabled(false)
		button_action:setTouchEnabled(true)
	elseif state == GIFT_STATE.GETED then
		Label_name:setTextById(1300015) 
		button_action:setGrayEnabled(true)
		button_action:setTouchEnabled(false)
	end
end


function XHZL2026View:refreshView()
	self.Grid_task:AsyncUpdateItem(self.showRechargeIds ,function (item,v ,idx)
		self:updateItem(item,v ,idx);
	end)
end
function XHZL2026View:initUI( ui )
	-- body
	self.super.initUI(self,ui)

	local Image_bg = TFDirector:getChildByPath(ui,"Image_bg")

	self.act_time		= TFDirector:getChildByPath(Image_bg,"act_time")
	self.act_time:setSkewX(10)
	self.act_time.Start = TFDirector:getChildByPath(self.act_time,"act_timeStart")
	self.act_time.Start:setSkewX(5)
	self.act_time.End	= TFDirector:getChildByPath(self.act_time,"act_timeEnd")
	self.act_time.End:setSkewX(5)


	local year, month, day = Utils:getDate(self.activityInfo.showStartTime or 0)
	self.act_time.Start:setTextById(1410001,year, month, day)

	year, month, day = Utils:getDate(self.activityInfo.endTime or 0)
	self.act_time.End:setTextById(1410001,year, month, day)


	self.prefab = TFDirector:getChildByPath(ui,"prefab")
	self.ScrollView_tasks = TFDirector:getChildByPath(ui,"ScrollView_tasks")
	self.Grid_task = UIGridView:create(self.ScrollView_tasks )
    self.Grid_task:setItemModel(self.prefab)
    self.Grid_task:setColumn(2)
    self.Grid_task:setColumnMargin(10)
    self.Grid_task:setRowMargin(10)
    self:refreshView()

end

function XHZL2026View:registerEvents()
    EventMgr:addEventListener(self,EV_RECHARGE_UPDATE,handler(self.updateGifts, self))
end


function XHZL2026View:updateGifts(reward)
    --Utils:showReward(reward)
    self:refreshView()
end


function XHZL2026View:buy(giftData)
	if giftData.buyType == 1 then  --兑换
		local exchangeCost = giftData.exchangeCost[1]
        local haveNum = GoodsDataMgr:getItemCount(exchangeCost.id)
        if haveNum <  exchangeCost.num then
            Utils:showAccess(exchangeCost.id)
            return
        end
        RechargeDataMgr:RECHARGE_REQ_CHARGE_EXCHANGE(giftData.rechargeCfg.id,"",0,"",1)
	else --直购
		RechargeDataMgr:getOrderNO(giftData.rechargeCfg.id)
	end
end


return XHZL2026View