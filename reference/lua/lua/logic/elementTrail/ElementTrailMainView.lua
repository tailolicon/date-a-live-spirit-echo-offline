
local ElementTrailMainView = class("ElementTrailMainView", BaseLayer)

function ElementTrailMainView:initData(levelGroupCid)
    local datas = TabDataMgr:getData("ElementTrainDungeon")
    self.elementTrainDungeonDatas = {}
    for k , data in pairs(datas) do
        table.insert(self.elementTrainDungeonDatas,data)
    end
    table.sort(self.elementTrainDungeonDatas,function (a ,b)
        return a.id < b.id
    end)
end

function ElementTrailMainView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.elementTrailMainView")
end

function ElementTrailMainView:initUI(ui)
    self.super.initUI(self, ui)

    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_item = TFDirector:getChildByPath(self.Panel_root, "Panel_item"):hide()


    self.Button_tip   = TFDirector:getChildByPath(self.Panel_root, "Button_tip")
    self.Button_rank  = TFDirector:getChildByPath(self.Panel_root, "Button_rank")
    self.Button_rankReward  = TFDirector:getChildByPath(self.Panel_root, "Button_rankReward")

    self.Button_enter = TFDirector:getChildByPath(self.Panel_root, "Button_enter")

    self.Label_element_tips  = TFDirector:getChildByPath(self.Panel_root, "Label_element_tips")
    self.Label_element_tips:setTextById("") --元素说明
    self.Label_name_tip  = TFDirector:getChildByPath(self.Button_tip, "Label_name_tip")
    self.Label_name_tip:setTextById(2100026) --试炼说明
    self.Label_name_rank  = TFDirector:getChildByPath(self.Button_rank, "Label_name_rank")
    self.Label_name_rank:setTextById(263001) --试炼排行
    self.Label_name_enter  = TFDirector:getChildByPath(self.Button_enter, "Label_name_enter")
    self.Label_name_enter:setTextById(300992) --进入
    local ScrollView_items   = TFDirector:getChildByPath(self.Panel_root, "ScrollView_items")
    
    self.ListView = UIListView:create(ScrollView_items)
    self.ListView:setItemsMargin(0)
    self.items = {}

    for i, data in ipairs(self.elementTrainDungeonDatas) do

        local itemNode  = self.Panel_item:clone():show()
        self.ListView:pushBackCustomItem(itemNode)
        self.items[i] = itemNode
        itemNode.cfg = data
        itemNode.openTime = Utils:string2time(data.openTime)
        itemNode.closeTime = Utils:string2time(data.closeTime)

    

        itemNode.Label_elemet_name  = TFDirector:getChildByPath(itemNode, "Label_elemet_name")
        itemNode.Image_element_name  = TFDirector:getChildByPath(itemNode, "Image_element_name"):hide()
        itemNode.Image_icon  = TFDirector:getChildByPath(itemNode, "Image_icon")
        itemNode.Image_focus = TFDirector:getChildByPath(itemNode, "Image_focus")
        itemNode.Panel_lock  = TFDirector:getChildByPath(itemNode, "Panel_lock"):hide()
        itemNode.Button_click = TFDirector:getChildByPath(itemNode, "Button_click"):show()
        itemNode.Label_elemet_name:setTextById(data.capter)
        local color = data.textColor
        itemNode.Label_elemet_name:setColor(ccc3(color.r,color.g,color.b))

          --资源显示
          -- itemNode.Image_element_name:setTexture(data.titlepic)
          itemNode.Image_icon:setTexture(data.pic)
          -- itemNode.Image_focus:setTexture(data.pic)

        itemNode.itemIdx     = i
        itemNode.Button_click:onClick(function()
            -- if self:checkOpen(itemNode) then 
                self.selectNode = itemNode
                self:refreshItem()
            -- else
            --     Utils:showTips(15011479) --关卡未开启
            -- end
        end)
    end


    --自动选中第一个
    self.selectNode = self.items[1]
    self:refreshItem()
end

function ElementTrailMainView:checkOpen(itemNode)
    local serverTime = ServerDataMgr:getServerTime()
    -- return itemNode.openTime <= serverTime and itemNode.closeTime >= serverTime

    return false
end

--初始化item 填充数据
function ElementTrailMainView:initItem()

end
--刷新选择状态
function ElementTrailMainView:refreshItem()
    local serverTime = ServerDataMgr:getServerTime()
    for i,itemNode in ipairs(self.items) do
        local unlock = itemNode.openTime <= serverTime and itemNode.closeTime >= serverTime
        -- unlock = false
        itemNode.Image_icon:setGrayEnabled(not unlock)
        itemNode.Panel_lock:setVisible(not unlock)
        itemNode.Image_focus:setVisible(self.selectNode == itemNode)
    end

    if self.selectNode then 
        self.Label_element_tips:setTextById(self.selectNode.cfg.des)
    else
        self.Label_element_tips:setText("")
    end
end



function ElementTrailMainView:refreshView()
    
end

function ElementTrailMainView:registerEvents()
    -- EventMgr:addEventListener(self, EV_FUBEN_DAILYBUYCOUNT, handler(self.onDailyBuyCountEvent, self))

    self.Button_tip:onClick(function ()
        Utils:openView("common.HelpView", {4137})
    end)

    self.Button_rank:onClick(function ()
        -- Utils:showTips("试炼排行")
        Utils:openView("elementTrail.ElementTrailRankView")

    end)

    self.Button_rankReward:onClick(function ()
        -- Utils:showTips("试炼排行")
        Utils:openView("elementTrail.ElementTrailRankRewardView")
    end)


    self.Button_enter:onClick(function ()
        --Utils:showTips("进入试炼副本")
        if self.selectNode then 
            Utils:openView("elementTrail.ElementTrailLevelView",self.selectNode.cfg)
        else
            Utils:showTips("请先选择关卡")
        end
    end)

end




-- function ElementTrailMainView:removeEvents()
--     -- self:removeCountDownTimer()
-- end

-- function ElementTrailMainView:addCountDownTimer()
--     if not self.countDownTimer_ then
--         self.countDownTimer_ = TFDirector:addTimer(1000, count, nil, handler(self.onCountDownPer, self))
--     end
-- end

-- function ElementTrailMainView:removeCountDownTimer()
--     if self.countDownTimer_ then
--         TFDirector:removeTimer(self.countDownTimer_)
--     end
-- end

-- function ElementTrailMainView:onCountDownPer()
--     self:updateDailyCountDonw()
-- end

-- function ElementTrailMainView:updateDailyCountDonw()
--     local remainTime = math.max(0, self.expirationTime_ - ServerDataMgr:getServerTime())
--     local day, hour, min = Utils:getFuzzyDHMS(remainTime, true)
--     if day ~= "00" then
--         self.Label_timing:setTextById(300590, day, hour, min)
--     else
--         self.Label_timing:setTextById(300591, hour, min)
--     end
-- end

-- function ElementTrailMainView:onDailyBuyCountEvent()
--     self:updateRemainCount()
-- end

return ElementTrailMainView
