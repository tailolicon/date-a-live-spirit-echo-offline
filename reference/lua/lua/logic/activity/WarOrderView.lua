
local WarOrderView = class("WarOrderView", BaseLayer)

function WarOrderView:initData(activityId)
    self.activityId = activityId
    self.activityInfo_ = ActivityDataMgr2:getActivityInfo(self.activityId)
    if not self.activityInfo_ then
        return
    end
    dump(self.activityInfo_)
    self.isHaveOneKey = false
    self.taskInfo = ActivityDataMgr2:getProgressInfo(self.activityInfo_.activityType, self.activityInfo_.extendData.itemId)

    self.isRefreshing = false
    self.allTaskProgress = {}
    self.oneKeyTaksItems = {}

end

function WarOrderView:ctor(data)
    self.super.ctor(self,data)
    self:initData(data)

    local uiName = self.activityInfo_.extendData.uiName or "warOrderActivityView"

    self:init("lua.uiconfig.secondary.uiconfig_zn.activity." .. uiName)

    -- --分享结果
    -- if HeitaoSdk then
    --     HeitaoSdk.setShareCallback(handler(self.shareCallBack,self));
    -- else
    --     setShareCallback(handler(self.shareCallBack,self));
    -- end
end

function WarOrderView:initLanguage()
    local Label_goto1 = TFDirector:getChildByPath(self.Button_open, "Label_goto")
    Label_goto1:setTextById(2107019) --TODO 开启
    local Label_goto2 = TFDirector:getChildByPath(self.Button_oneKeyGet, "Label_goto")
    Label_goto2:setTextById(700007) --TODO一键领取

     self.Label_plain = TFDirector:getChildByPath(self.Panel_root, "Label_plain")
     self.Label_plain:setTextById(190001335) --TODO 普通密函
     self.Label_secret = TFDirector:getChildByPath(self.Panel_root, "Label_secret")
     self.Label_secret:setTextById(190001336) --TODO 机密密函密函
end

function WarOrderView:initUI(ui)
    self.super.initUI(self, ui)

    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_prefab = TFDirector:getChildByPath(ui, "Panel_prefab")

    self.Button_open = TFDirector:getChildByPath(self.Panel_root, "Button_open"):hide()
    self.Button_rule = TFDirector:getChildByPath(self.Panel_root, "Button_rule")
    self.Button_oneKeyGet = TFDirector:getChildByPath(self.Panel_root, "Button_oneKeyGet")

    self.Label_descOneKey = TFDirector:getChildByPath(self.Panel_root, "Label_descOneKey")
    self.Label_progress = TFDirector:getChildByPath(self.Panel_root, "Label_progress")
    self.Image_oneKeyReward_1 = TFDirector:getChildByPath(self.Panel_root, "Image_oneKeyReward_1")
    self.Image_oneKeyReward_2 = TFDirector:getChildByPath(self.Panel_root, "Image_oneKeyReward_2")


    self.Panel_taskItem = TFDirector:getChildByPath(self.Panel_prefab, "Panel_taskItem")

    local ScrollView_task = TFDirector:getChildByPath(self.Panel_root, "ScrollView_task")
    
    self.TurnView_plot_task = UIListView:create(ScrollView_task)
    self.TurnView_plot_task:setItemModel(self.Panel_taskItem)


    self.Label_timeStart = TFDirector:getChildByPath(self.Panel_root, "Label_timeStart")
    self.Label_timeEnd = TFDirector:getChildByPath(self.Panel_root, "Label_timeEnd")

    self.Label_timeStart:setText(os.date("%Y.%m-%d",self.activityInfo_.showStartTime))
    self.Label_timeEnd:setText(os.date("%Y.%m-%d",self.activityInfo_.showEndTime))

    self:initLanguage()
    self:refreshView()
end

function WarOrderView:addTaskItem(info,status,isEnd)
    dump(info)
    local item = self.TurnView_plot_task:pushBackDefaultItem()

    -- dump(info,"任务条目状态",10)
    local Label_desc = TFDirector:getChildByPath(item, "Label_desc")
    -- Label_desc:setText(info.desId)
    --TODO
    Label_desc:setTextById(info.desId)
    
    if isEnd then
        -- self.Label_descOneKey:setText(info.desId)
        --TODO
        self.Label_descOneKey:setTextById(info.desId)
    end
    
    local Label_lock = TFDirector:getChildByPath(item, "Label_lock"):hide()
    local Image_diban = TFDirector:getChildByPath(item, "Image_diban")
    local Image_icon = TFDirector:getChildByPath(item, "Image_icon")

    local Button_running = TFDirector:getChildByPath(item, "Button_running"):hide()

    local Label_btnTip = TFDirector:getChildByPath(Button_running, "Label_btnTip")
    local Label_progress_title = TFDirector:getChildByPath(item, "Label_progress_title")
    local Label_progress = TFDirector:getChildByPath(item, "Label_progress")
Label_lock:setTextById(900212)--TODO 未解锁
Label_btnTip:setTextById(267012)--TODO 前往
    
    for i,v in ipairs(info.itemIds) do
        local taskProgressInfo = ActivityDataMgr2:getProgressInfo(self.activityInfo_.activityType, v)

        if taskProgressInfo.status == 1 then
            self.isHaveOneKey = true
        end



        local taskTtemInfo = ActivityDataMgr2:getItemInfo(self.activityInfo_.activityType, v)
        -- dump(taskProgressInfo,"任务条目状态" .. v,10)

        local Image_reward = TFDirector:getChildByPath(item, "Image_reward_" .. i)

        
        --物品展示

        local Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()

        for k,v in pairs(taskTtemInfo.reward) do
            PrefabDataMgr:setInfo(Panel_goodsItem, k, v)
        end
        Panel_goodsItem:setPosition(ccp(0,0))
        Image_reward:addChild(Panel_goodsItem)

        if isEnd then
            local Image_oneKeyReward = TFDirector:getChildByPath(self.Panel_root, "Image_oneKeyReward_" .. i)
            local Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()

            for k,v in pairs(taskTtemInfo.reward) do
                PrefabDataMgr:setInfo(Panel_goodsItem, k, v)
            end
            Panel_goodsItem:setPosition(ccp(0,0))
            Image_oneKeyReward:addChild(Panel_goodsItem)
        end


        local Image_finish = TFDirector:getChildByPath(Image_reward, "Image_finish"):hide()
        local Label_canget = TFDirector:getChildByPath(Image_reward, "Label_canget"):hide()

        -- Label_canget:setTextById() --TODO 可领取

        --展示图标
        local Button_getReward = TFDirector:getChildByPath(Image_reward, "Button_getReward")
        Button_getReward:setTouchEnabled(false)


        local Image_lock = TFDirector:getChildByPath(Image_reward, "Image_lock"):hide()

        if i == 1 then
            Button_running:onClick(function()
                FunctionDataMgr:enterByFuncId(taskTtemInfo.extendData.jumpInterface, unpack({taskTtemInfo.extendData.parameter} or {}))
            end)
        else
            Image_lock:setVisible(self.Button_open:isVisible())
        end
        if v == self.activityInfo_.extendData.showid then
            self.Label_progress:setTextById(190001334,taskProgressInfo.progress)
        end


        if taskProgressInfo.status == 1 then
            Label_canget:show()
            if i == 1 or not self.Button_open:isVisible() then
                Button_getReward:setTouchEnabled(true)
                Button_getReward:onClick(function()
                    self.listOffsetX = self.TurnView_plot_task.scrollView_:getContentOffset().x
                    ActivityDataMgr2:send_ACTIVITY_NEW_SUBMIT_ACTIVITY(self.activityId, taskTtemInfo.id)
                end)
                
                table.insert(self.oneKeyTaksItems,v)
            end
        elseif taskProgressInfo.status == 2 then
            Image_finish:show()
        elseif status then  
            if i == 1 and taskProgressInfo.status == 0 then
                Button_running:show()
            end
            if i==2 and taskProgressInfo.status == 0 then
                if Button_running:isVisible() then
                    status = false
                end

                -- Image_icon:setTexture("ui/activity/2021WarOrder/005.png")
                -- Image_lock:show()
            end
        else
            if i==1 then
                Image_diban:setTexture("ui/activity/2021WarOrder/006.png")
                Label_lock:show()
            end
            if i == 2 then
                Image_icon:setTexture("ui/activity/2021WarOrder/005.png")
            end
        end
        if Image_lock:isVisible() then
            Label_canget:hide()
        end
    end


    return status
end

function WarOrderView:refreshView()

    local specialTaskInfo = ActivityDataMgr2:getProgressInfo(self.activityInfo_.activityType, tonumber(self.activityInfo_.extendData.specialTask))
    local specialTaskItem = ActivityDataMgr2:getItemInfo(self.activityInfo_.activityType, tonumber(self.activityInfo_.extendData.specialTask))

    self.Button_open:setVisible(GoodsDataMgr:getItemCount(self.activityInfo_.extendData.hide) == 0)

    self.TurnView_plot_task:removeAllItems()

    local localStatus = true

    self.oneKeyTaksItems = {}

    for i,v in ipairs(self.activityInfo_.extendData.taskList) do
        local isEnd = false
        if i == #self.activityInfo_.extendData.taskList then
            isEnd = true
        end
        localStatus = self:addTaskItem(v,localStatus,isEnd)
    end

    if self.listOffsetX then
        self.TurnView_plot_task:jumpTo(- self.listOffsetX)
    end

    self.Button_oneKeyGet:setTouchEnabled(#self.oneKeyTaksItems~=0)
    self.Button_oneKeyGet:setGrayEnabled(#self.oneKeyTaksItems==0)
    -- local count = GoodsDataMgr:getItemCount(self.activityInfo_.extendData.showid or EC_SItemType.ACTIVITY)
end

function WarOrderView:onSubmitSuccessEvent(id,itemId,reward)
    if id == self.activityInfo_.id then
        -- if itemId == self.activityInfo_.extendData.itemId then
        --     Utils:openView("activity.AddressViewIG",self.spreadQq,self.taskInfo)
        -- end
        -- dump(reward,"奖励打印",10)
        Utils:showReward(reward)
        -- self:refreshView()
    end
end
function WarOrderView:onUpdateProgressEvent()

    if not self.isRefreshing then
        self.isRefreshing = true
        self:timeOut(function()
                self:refreshView()
                self.isRefreshing = false
        end,0.5)  
    end
    
end
function WarOrderView:onUpdateActivityEvent()
    if not self.Button_open:isVisible() then
        return
    end
    self.Button_open:setVisible(GoodsDataMgr:getItemCount(self.activityInfo_.extendData.hide) == 0)
    if not self.Button_open:isVisible() then
        self:refreshView()
    end
end

function WarOrderView:onSubmitActivity()
    self.taskInfo = ActivityDataMgr2:getProgressInfo(self.activityInfo_.activityType, self.activityInfo_.extendData.itemId)

end

function WarOrderView:registerEvents()
    EventMgr:addEventListener(self, EV_ACTIVITY_SUBMIT_SUCCESS, handler(self.onSubmitSuccessEvent, self))
    EventMgr:addEventListener(self, EV_ACTIVITY_UPDATE_PROGRESS, handler(self.onUpdateProgressEvent, self))
    -- EventMgr:addEventListener(self, EV_ACTIVITY_UPDATE_ACTIVITY, handler(self.onUpdateActivityEvent, self))
    EventMgr:addEventListener(self, EV_BAG_ITEM_UPDATE, handler(self.onUpdateActivityEvent, self))
    -- self.Button_close:onClick(function()
    --     AlertManager:closeLayer(self)
    -- end)
    -- self.Button_address:onClick(function()
    --     Utils:openView("activity.AddressViewIG",self.spreadQq,self.taskInfo)
    -- end)

    self.Button_open:onClick(function()
        Utils:openView("activity.WarOrderSecretView",self.activityInfo_)
    end)
    self.Button_rule:onClick(function()
        Utils:openView("common.HelpView",{4113})
    end)
    self.Button_oneKeyGet:onClick(function()
        ActivityDataMgr2:send_ACTIVITY_NEW_SUBMIT_ACTIVITY_TABLE(self.activityId,self.oneKeyTaksItems)
    end)
end

return WarOrderView
