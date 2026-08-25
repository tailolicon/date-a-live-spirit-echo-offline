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
*  连充好礼
]]

local VoucherSevenDayView = class("VoucherSevenDayView",BaseLayer)

function VoucherSevenDayView:ctor( data )
	-- body
	self.super.ctor(self,data)
	self.time = 0
	self:init("lua.uiconfig.secondary.uiconfig_zn.activity.voucherSevenDay")
end

function VoucherSevenDayView:initUI( ui )
	-- body
	self.super.initUI(self,ui)

	local Image_content = TFDirector:getChildByPath(ui,"Image_content")

	--前往充值
	self.Button_go = TFDirector:getChildByPath(Image_content,"Button_go")
	self.Label_go  = TFDirector:getChildByPath(self.Button_go ,"Label_go")
	self.Label_go:setTextById(1454001)
    self.Label_time		= TFDirector:getChildByPath(Image_content,"Label_time")
    self.Image_mask60 = TFDirector:getChildByPath(Image_content,"Image_mask60")
    self.Image_mask300 = TFDirector:getChildByPath(Image_content,"Image_mask300")

    self.Label_recharge_t   =  TFDirector:getChildByPath(Image_content,"Label_recharge_t")
    self.Label_recharge_v   =  TFDirector:getChildByPath(Image_content,"Label_recharge_v")
    self.Label_recharge_t:setTextById(2600006) --今日已充

    --当前第几天
    self.Label_currentDay   =  TFDirector:getChildByPath(Image_content,"Label_currentDay")
    self.Label_currentDay:hide()

	self.dayIndex = 1
	self.tabIndex = 1
	self.nodeTabs = {}
	local tabNameIds = {2600007 ,2600008} 
	for i=1,2 do
		local node  = TFDirector:getChildByPath(Image_content,"Button_tab"..i)
		node.Image_select   = TFDirector:getChildByPath(node,"Image_select")
		node.Label_tab_name     = TFDirector:getChildByPath(node,"Label_tab_name")
		node.Label_tab_name:setTextById(tabNameIds[i]) 
		node.Image_select:setVisible(i==self.tabIndex )
		self.nodeTabs[i]    = node
		node:onClick(function ()
			self:onClickTab(i)
		end)
	end

	self.nodeItems = {}
	for i=1,7 do
		local node  = TFDirector:getChildByPath(Image_content,"Panel_rewad"..i)
		node.Panel_item   = TFDirector:getChildByPath(node,"Panel_item")
		node.Button_state = TFDirector:getChildByPath(node,"Button_state")
		node.Label_state  = TFDirector:getChildByPath(node.Button_state,"Label_state")
      	node.Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
        node.Panel_goodsItem:AddTo(node.Panel_item):Pos(0, 0):Scale(0.75)
		self.nodeItems[i] = node
	    node.Button_state:onClick(function ()
			self:onClickReward(i)
		end)
	end



	self:refreshItems()
end



function VoucherSevenDayView:getDayRechargeCfg(groupId,day)
	local cfgs = TabDataMgr:getData("DayRecharge")
	for k,v in pairs(cfgs) do
		if v.groupId == groupId and v.order == day then 
			return  v
		end
	end
end

--获取奖励的状态
function VoucherSevenDayView:getRewardState(day)
	local recharge = self.tabIndex
	local voucherSevenDayData = ActivityDataMgr:getVoucherSevenDayData()
	if voucherSevenDayData then 
	   -- dump(voucherSevenDayData)
	   if voucherSevenDayData.curDay >= day then 
	   	   local rechargeCfg = self:getDayRechargeCfg(recharge,day)
           if table.find(voucherSevenDayData.alreadyClaimedId ,rechargeCfg.id) == -1 then --未领取的情况
                local payAmount = voucherSevenDayData.payAmountByDay[day] or 0
                if payAmount >= rechargeCfg.recharge then
                	return 2  --可领取
                else
                	return 1  --未达成
                end
           else --已经购买
           		return 3 --已领取
           end
       else
       	   return 0 --未满足条件
	   end
	end
	return 0
end




function VoucherSevenDayView:getDayRechargeId(day)
	local recharge = self.tabIndex
    local cfg = self:getDayRechargeCfg(recharge,day)
    return cfg.id
end


function VoucherSevenDayView:getReward(day)
	-- local cfgs = TabDataMgr:getData("DayRecharge")
	local recharge = self.tabIndex
	local cfg = self:getDayRechargeCfg(recharge,day)
	for itemId , num in pairs(cfg.reward) do
		return itemId ,num
	end
end


--点击领奖
function VoucherSevenDayView:onClickReward(day)
    local dayRechargeId = self:getDayRechargeId(day)
    ActivityDataMgr:reqVoucherSevenDayGetReward(dayRechargeId)
    -- Utils:showTips("click day: " ..day .."  id: "..dayRechargeId)

end

function VoucherSevenDayView:onClickTab(tabIndex)
	self.tabIndex = tabIndex
	for i,v in ipairs(self.nodeTabs) do
		v.Image_select:setVisible(self.tabIndex== i)
	end

	self.Image_mask60:setVisible(self.tabIndex == 1)
	self.Image_mask300:setVisible(self.tabIndex == 2)
	self:refreshItems()
end



function VoucherSevenDayView:refreshItems()
	--TODO 奖励刷新 /档位刷新
   
    -- local sevenDayData = ActivityDataMgr:getVoucherSevenDayData()
	for _day,node in ipairs(self.nodeItems) do
		local id , num   = self:getReward(_day)
        PrefabDataMgr:setInfo(node.Panel_goodsItem, id, num) --TODO test
		local state = self:getRewardState(_day)
        if state ==  2 then --可领取
        	node.Label_state:setTextById(1820002)
	        node.Button_state:setGrayEnabled(false)
	        node.Button_state:setTouchEnabled(true)
        elseif state == 1 then --未达成
        	node.Label_state:setTextById(1890017)
	        node.Button_state:setGrayEnabled(true)
	        node.Button_state:setTouchEnabled(false)
        elseif state == 3 then --已领取
            node.Label_state:setTextById(1890018)
	        node.Button_state:setGrayEnabled(true)
	        node.Button_state:setTouchEnabled(false)
        elseif state == 0 then --为满足条件
            node.Label_state:setTextById(1890017)
	        node.Button_state:setGrayEnabled(true)
	        node.Button_state:setTouchEnabled(false)
        end  
	end

	-- 当日充值金额
	local rechargeValue = ActivityDataMgr:getVoucherRechargeValue()
	rechargeValue = rechargeValue*0.01
    self.Label_recharge_v:setText(rechargeValue)

    self.time = 0
    self:onRefreshTime()
end


function VoucherSevenDayView:onRefreshTime()
	local time_ = os.time()
	if (time_- self.time) > 30 then --30s 更新一次
		self.time = time_
		local sevenDayData = ActivityDataMgr:getVoucherSevenDayData()
		if sevenDayData and sevenDayData.activityId > 0 then 
	        local remainTime = math.max(0, sevenDayData.endTime - ServerDataMgr:getServerTime())
	        local day, hour, min = Utils:getFuzzyDHMS(remainTime)
	        self.Label_time:setTextById(300982, day, hour, min)
	        
		else
			self.Label_time:setTextById(300982, 0, 0, 0)
		end
		print("onRefreshTime")
    end
end

function VoucherSevenDayView:onRefresh()
	self:refreshItems()
end

--循环更新
function VoucherSevenDayView:onUpdate(dt)
	self:onRefreshTime()
end




function VoucherSevenDayView:registerEvents()
    EventMgr:addEventListener(self,EV_VOUCHER_SEVEN_DAY_DATA_UPDATE,handler(self.onRefresh, self))
    EventMgr:addEventListener(self,EV_VOUCHER_SEVEN_DAY_GET_REWARD,handler(self.onGetReward, self))

    -- self:addMEListener(TFWIDGET_ENTERFRAME, handler(self.onRefreshTime, self))


    self.Button_go:onClick(function ()
		--跳转充值界面
		FunctionDataMgr:enterByFuncId(1)
	end)
end





-- function VoucherSevenDayView:removeEvents()
--     self.super.removeEvents(self)
--     self:removeMEListener(TFWIDGET_ENTERFRAME)
-- end


function VoucherSevenDayView:onGetReward(data)
	dump(data)
  	if data.rewardItems then
  		Utils:showReward(data.rewardItems)
    end
    self:onRefresh()
end




return VoucherSevenDayView