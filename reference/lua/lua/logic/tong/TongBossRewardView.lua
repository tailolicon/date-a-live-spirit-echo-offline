
local TongBossRewardView = class("TongBossRewardView", BaseLayer)
function TongBossRewardView:initData()
    self.vitProgressCfg = TabDataMgr:getData("VITmaxProgress")
end

function TongBossRewardView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.tong.tongBossRewardView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongBossRewardView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")
    local ScrollView_reward     = TFDirector:getChildByPath(ui, "ScrollView_reward")
    self.UIListView_reward      = UIListView:create(ScrollView_reward)

    self.Panel_item             = TFDirector:getChildByPath(ui, "Panel_item")

    self:initRewardList()
end

function TongBossRewardView:initRewardList()

    local bossInfo = TongDataMgr:getWorldBossInfo()
    if not bossInfo then
        return
    end
    local curProgress       = tonumber(bossInfo.progress)

    local maxPro = self.vitProgressCfg[#self.vitProgressCfg].progress

    self.rewardList_ = {}
    for k,v in ipairs(self.vitProgressCfg) do
        local item = self.Panel_item:clone()
        self.UIListView_reward:pushBackCustomItem(item)

        local Image_item        = TFDirector:getChildByPath(item, "Image_item")
        local Label_progress    = TFDirector:getChildByPath(item, "Label_progress")

        local Button_get        = TFDirector:getChildByPath(item, "Button_get")
        local Label_cannot      = TFDirector:getChildByPath(item, "Label_cannot")
        local Label_btn         = TFDirector:getChildByPath(item, "Label_btn")

        local percent           = math.floor(v.progress/maxPro*100)
        local tx = TextDataMgr:getText(13206038)
        Label_progress:setText(percent..tx)

        local isReceive = curProgress >= v.progress
        local isGet = TongDataMgr:isGetBossAward(k)

        local Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
        Panel_goodsItem:Pos(0, 0):AddTo(Image_item)
        PrefabDataMgr:setInfo(Panel_goodsItem, v.rewardShow)

        Button_get:setVisible(isReceive)
        Label_cannot:setVisible(not isReceive)

        Button_get:setTouchEnabled(not isGet)
        Button_get:setGrayEnabled(isGet)

        table.insert(self.rewardList_,{btn = Button_get, btnTx = Label_btn})
    end

    self:updateRewardList()
end

function TongBossRewardView:updateRewardList()

    for k,v in ipairs(self.rewardList_) do
        local isGet = TongDataMgr:isGetBossAward(k)
        v.btn:setTouchEnabled(not isGet)
        v.btn:setGrayEnabled(isGet)
        local strId = isGet and 1300015 or 1820002
        v.btnTx:setTextById(strId)
    end

end

function TongBossRewardView:registerEvents()

    EventMgr:addEventListener(self, EV_TONG.BossAward, handler(self.updateRewardList, self))

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    for k,v in ipairs(self.rewardList_) do
        v.btn:onClick(function()

            local isGet = TongDataMgr:isGetBossAward(k)
            if isGet then
                return
            end

            TongDataMgr:Send_getBossStageAward(k)

            local reward = {}
            table.insert(reward,{id = self.vitProgressCfg[k].rewardShow,num = 1})

            Utils:showReward(reward)
        end)
    end

end

return TongBossRewardView
