
local WarOrderSecretView = class("WarOrderSecretView", BaseLayer)

function WarOrderSecretView:initData(activityInfo_)
    self.activityInfo_ = activityInfo_
    if not self.activityInfo_ then
        return
    end
    self.giftData = RechargeDataMgr:getGiftSingleData(tonumber(self.activityInfo_.extendData.giftid))
    self.exchangeCost = self.giftData.exchangeCost[1]
end

function WarOrderSecretView:ctor(data)
    self.super.ctor(self,data)
    self:initData(data)

    local uiName = self.activityInfo_.extendData.uiName or "warOrderSecretView"
    self:init("lua.uiconfig.secondary.uiconfig_zn.activity." .. uiName) 
end

function WarOrderSecretView:initUI(ui)
    self.super.initUI(self, ui)

    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Button_close = TFDirector:getChildByPath(self.Panel_root, "Button_close")
    self.Button_zs = TFDirector:getChildByPath(self.Panel_root, "Button_zs")
   
    self.Image_item = TFDirector:getChildByPath(self.Panel_root, "Image_item")
    self.Image_costIcon = TFDirector:getChildByPath(self.Panel_root, "Image_costIcon")
    self.Label_btn = TFDirector:getChildByPath(self.Panel_root, "Label_btn")
    self.Label_tipBig = TFDirector:getChildByPath(self.Panel_root, "Label_tipBig")
    self.Label_tipBig:setTextById(17000731)

    self.Label_tipfinish = TFDirector:getChildByPath(self.Panel_root, "Label_tipfinish")
    self.Label_tipfinish:setTextById(190001338)

    self.Label_tip = TFDirector:getChildByPath(self.Panel_root, "Label_tip")
    self.Label_tip:setTextById(190001337)
    self.Label_name = TFDirector:getChildByPath(self.Panel_root, "Label_name")
    self.Label_name:setTextById(190001336)
    self.Label_name:setSkewX(10)
    self.TurnView_plot_task = TFDirector:getChildByPath(self.Panel_root, "listView")

    -- self.TurnView_plot_task = UIListView:create(listView)
    -- self.TurnView_plot_task:setItemModel(self.Image_item)

    self.TurnView_plot_task_finish = TFDirector:getChildByPath(self.Panel_root, "listViewFinish")

    -- self.TurnView_plot_task_finish = UIListView:create(listViewFinish)


    self:refreshView()
end


function WarOrderSecretView:refreshView()

    -- local itemInfo = ActivityDataMgr2:getItemInfo(self.activityInfo_.activityType, self.dressTaskId)

    local specialTaskItem = ActivityDataMgr2:getItemInfo(self.activityInfo_.activityType, tonumber(self.activityInfo_.extendData.specialTask))

    Utils:createRewardListHor(self.TurnView_plot_task_finish,self.activityInfo_.extendData.showReward)
    local showItems = {}
    for i,v in ipairs(self.giftData.firstBuyItem) do
        if v.id ~= self.activityInfo_.extendData.hide then
            showItems[v.id] = v.num
        end
    end

    Utils:createRewardListHor(self.TurnView_plot_task,showItems)
    self.TurnView_plot_task.uilist:setCenterArrange()
    self.Label_btn:setText(self.exchangeCost.num)


    -- dump(GoodsDataMgr:getItemCfg(self.exchangeCost.id).icon,"花费物品配置",10)
    self.Image_costIcon:setTexture(GoodsDataMgr:getItemCfg(self.exchangeCost.id).icon)


    

end

function WarOrderSecretView:responseView()
    self.Panel_response:setVisible(true)
end


function WarOrderSecretView:currencyIsEnough()
    local enough = true
    -- for i = 1, #self.commodityCfg_.exchangeCost do
        -- local cost = self.commodityCfg_.exchangeCost[i]
        local haveNum = GoodsDataMgr:getItemCount(self.exchangeCost.id)
        if haveNum < self.exchangeCost.num then
            enough = false
            -- break;
        end     
    -- end
    return enough
end

function WarOrderSecretView:registerEvents()
    self.Button_close:onClick(function()
        AlertManager:closeLayer(self)
    end)

    self.Button_zs:onClick(function()
        -- ActivityDataMgr2:send_ACTIVITY_NEW_SUBMIT_ACTIVITY(self.activityInfo_.id, tonumber(self.activityInfo_.extendData.specialTask))

        if not self:currencyIsEnough() then
                Utils:showAccess(self.exchangeCost.id)
                return
            end
            RechargeDataMgr:RECHARGE_REQ_CHARGE_EXCHANGE(tonumber(self.activityInfo_.extendData.giftid),"",0,"", 1)
        end)
end

function WarOrderSecretView:onShow()
    self.super.onShow(self)

    self:updateBuyButtonStatus()
end

function WarOrderSecretView:updateBuyButtonStatus()
    self.Button_zs:setGrayEnabled(not (GoodsDataMgr:getItemCount(self.activityInfo_.extendData.hide) == 0))
    self.Button_zs:setTouchEnabled(GoodsDataMgr:getItemCount(self.activityInfo_.extendData.hide) == 0)
end

return WarOrderSecretView
