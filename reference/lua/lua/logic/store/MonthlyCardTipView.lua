
local MonthlyCardTipView = class("MonthlyCardTipView", BaseLayer)

local CardType = {
    MonthCard = 1,
    MonthCardEx = 2,
    --SeasonCard = 2,
    --HalfYearCard = 3,
}

function MonthlyCardTipView:initData()
    local cardData = RechargeDataMgr:getMonthCardList()
    local cardType = CardType.MonthCard
    self.cardData_ = cardData[cardType]
    GlobalVarDataMgr:setValue(GV_MONTH_CARD_TIP, false)
end

function MonthlyCardTipView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:showPopAnim(true)
    self:init("lua.uiconfig.recharge.monthlyCardTipView")
end

function MonthlyCardTipView:initUI(ui)
    self.super.initUI(self, ui)

    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    local Image_content = TFDirector:getChildByPath(self.Panel_root, "Image_content")
    self.Label_remain_days = TFDirector:getChildByPath(Image_content, "Label_remain_days")
    self.Button_pay = TFDirector:getChildByPath(Image_content, "Button_pay")
    self.Label_pay = TFDirector:getChildByPath(self.Button_pay, "Label_pay")
    self.Button_close = TFDirector:getChildByPath(Image_content, "Button_close")

    --修改为代币显示海外版特有
    local cfg = GoodsDataMgr:getItemCfg(self.cardData_.exchangeCost[1].id)
    local rich = TFRichText:create(ccs(110, 0))
    local formatStr = TextDataMgr:getText(1605006)
    local content = string.format(formatStr, cfg.icon, self.cardData_.exchangeCost[1].num)
    local str = string.format([[<font face="fangzheng_zhunyuan26" color="#FFFFFF">%s</font>]], content)
    rich:Text(str)
    self.Button_pay:Add(rich)
    self:refreshView()
end

function MonthlyCardTipView:refreshView()
    --self.Label_pay:setTextById(1605006, self.cardData_.rechargeCfg.price *0.01)  --配合海外版代币显示屏蔽修改
    self.Label_pay:setText("")
    self:updateRemainDay()
end

function MonthlyCardTipView:registerEvents()
    EventMgr:addEventListener(self, RechargeDataMgr.RESREWARDTOTALPAY, handler(self.onResRewardTotalPayRsp, self))
    EventMgr:addEventListener(self,EV_RECHARGE_UPDATE,handler(self.onRechargeUpdateEvent, self))

    self.Button_close:onClick(function()
            AlertManager:closeLayer(self)
    end)

    self.Button_pay:onClick(function()
        --写死调用月卡购买id为40 2021-08-10
        RechargeDataMgr:getOrderNO(40)
    end)
end

function MonthlyCardTipView:updateRemainDay()
    local remainDay = RechargeDataMgr:getMonthCardLeftTime()
    self.Label_remain_days:setTextById(1605007, remainDay)
end

function MonthlyCardTipView:onResRewardTotalPayRsp(reward)
    Utils:showReward(reward)
end

function MonthlyCardTipView:onRechargeUpdateEvent()
    self:updateRemainDay()
end

return MonthlyCardTipView
