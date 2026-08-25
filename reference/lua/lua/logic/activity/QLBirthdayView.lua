local QLBirthdayView = class("QLBirthdayView", BaseLayer)
function QLBirthdayView:ctor(...)
    self.super.ctor(self)

    self:showPopAnim(true)
    self:initData(...)
    self:init("lua.uiconfig.activity.qlBirthdayView")

end

function QLBirthdayView:initData(activityId)
    self.activityId_ = activityId
    self.activityInfo_ = ActivityDataMgr2:getActivityInfo(self.activityId_)

    if self.activityInfo_ and self.activityInfo_.extendData.costItemId then
        self.costItemId = self.activityInfo_.extendData.costItemId
    end


end

function QLBirthdayView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")

    local listView  = TFDirector:getChildByPath(self.Panel_root, "listView")

    self.TableView_task = Utils:scrollView2TableView(listView)
    self.TableView_task:addMEListener(TFTABLEVIEW_SIZEFORINDEX, handler(self.tableCellSize,self))
    self.TableView_task:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, handler(self.numberOfCells,self))
    self.TableView_task:addMEListener(TFTABLEVIEW_SIZEATINDEX, handler(self.tableCellAtIndex,self))

    self.Button_zs  = TFDirector:getChildByPath(self.Panel_root, "Button_zs")
    self.Button_zs:getChildByName("Label_btn"):setTextById(700014)
    self.Label_tip  = TFDirector:getChildByPath(self.Panel_root, "Label_tip")
    self.panel_item = TFDirector:getChildByPath(ui, "panel_item")

    self.act_timeStart  = TFDirector:getChildByPath(self.Panel_root, "act_timeStart")
    self.act_timeEnd    = TFDirector:getChildByPath(self.Panel_root, "act_timeEnd")
    self.act_time_title = TFDirector:getChildByPath(self.Panel_root, "act_time_title")

    self.act_timeStart:setSkewX(15)
    self.act_timeEnd:setSkewX(15)
    self.act_time_title:setSkewX(15)
    self.act_time_title:setTextById(1710002)

    self:refreshView()
end

function QLBirthdayView:refreshView()

    local startStr =  Utils:getUTCDateString(self.activityInfo_.startTime)
    local endStr =  Utils:getUTCDateString(self.activityInfo_.endTime)
    self.act_timeStart:setText(startStr)
    self.act_timeEnd:setText(endStr..GV_UTC_TIME_STRING)

    self.Label_tip:setTextById(22177)

end

function QLBirthdayView:updateActivity()

    self.activityInfo_ = ActivityDataMgr2:getActivityInfo(self.activityId_)
    self.taskData_ = ActivityDataMgr2:getItems(self.activityId_)

    self.TableView_task:reloadData()
end

function QLBirthdayView:numberOfCells(tableView)
    return #self.taskData_
end

function QLBirthdayView:tableCellSize(tableView)
    local size = self.panel_item:getContentSize()
    return size.height, size.width
end

function QLBirthdayView:tableCellAtIndex(tab, idx)
    local cell = tab:dequeueCell()
    idx = idx + 1
    if not cell then
        cell = TFTableViewCell:create()
        local item = self.panel_item:clone():show()
        item:setAnchorPoint(ccp(0, 0))
        item:setPosition(ccp(0, 0))
        cell:addChild(item)
        cell.item = item
    end
    cell.idx = idx

    if cell.item then
        self:updateItem(cell, self.taskData_[idx])
    end
    return cell
end

function QLBirthdayView:updateItem(item,itemId)

    local itemInfo = ActivityDataMgr2:getItemInfo(self.activityInfo_.activityType, itemId)
    local progress = ActivityDataMgr2:getProgress(self.activityInfo_.activityType, itemId)
    local progressInfo = ActivityDataMgr2:getProgressInfo(self.activityInfo_.activityType, itemId)

    local Label_name = TFDirector:getChildByPath(item, "Label_name")
    Label_name:setTextById(itemInfo.extendData.des2 , itemInfo.target)

    local Label_progress_title = TFDirector:getChildByPath(item , "Label_progress_title")
    Label_progress_title:setTextById(1890002)

    local Label_progress = TFDirector:getChildByPath(item, "Label_progress")
    Label_progress:setTextById(800005, progress, itemInfo.target)
    if progress > tonumber(itemInfo.target)  then
        Label_progress:setTextById(800005, itemInfo.target, itemInfo.target)
    end

    local Label_geted = TFDirector:getChildByPath(item, "Label_geted")
    local Button_get = TFDirector:getChildByPath(item, "Button_get")
    local Button_goto = TFDirector:getChildByPath(item, "Button_goto")
    Button_goto:getChildByName("Label_btn"):setTextById(310016)
    Button_get:getChildByName("Label_btn"):setTextById(1200015)
    Label_geted:setTextById(700033)


    local goodsId, goodsNum
    for i = 1, 3 do
        local Image_reward_ = TFDirector:getChildByPath(item, "Panel_reward_" .. i)
        local Panel_goodsItem = Image_reward_:getChildByName("Panel_goodsItem")
        if not Panel_goodsItem then
            Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
            Panel_goodsItem:AddTo(Image_reward_):Pos(0, 0):Scale(0.6)
        end

        local id, num = next(itemInfo.reward, goodsId)
        if id then
            goodsId = id
            goodsNum = num
        end
        Panel_goodsItem:setVisible(tobool(id))
        if Panel_goodsItem:isVisible() then
            PrefabDataMgr:setInfo(Panel_goodsItem, goodsId, goodsNum)
        end
    end

    Button_get:setVisible(progressInfo.status == EC_TaskStatus.GET)
    Label_geted:setVisible(progressInfo.status == EC_TaskStatus.GETED)

    Button_goto:setVisible(progressInfo.status == EC_TaskStatus.ING and itemInfo.extendData.jumpInterface)

    Button_get:onClick(function()
        if ServerDataMgr:getServerTime() >= self.activityInfo_.endTime then
            Utils:showTips(1710021)
            return
        end
        ActivityDataMgr2:send_ACTIVITY_NEW_SUBMIT_ACTIVITY(self.activityInfo_.id, itemId)
    end)

    Button_goto:onClick(function()
        if ServerDataMgr:getServerTime() >= self.activityInfo_.endTime then
            Utils:showTips(1710021)
            return
        end

        local param = itemInfo.extendData.parameter or {}
        FunctionDataMgr:enterByFuncId(itemInfo.extendData.jumpInterface,unpack(param))
    end)
end

function QLBirthdayView:zsGift()

    if not self.costItemId then
        return
    end

    local cnt = GoodsDataMgr:getItemCount(self.costItemId)
    if cnt <= 0 then
        Utils:showTips(22178)
        return
    end

    Utils:openView("activity.QLBirthdayGiveView",self.costItemId)
end

function QLBirthdayView:onSubmitSuccessEvent(activitId, itemId, reward)
    if self.activityId_ ~= activitId then return end
    Utils:showReward(reward)
end

function QLBirthdayView:onUpdateProgressEvent()
    self:updateActivity()
end

function QLBirthdayView:registerEvents()
    self.super.registerEvents(self)

    EventMgr:addEventListener(self, EV_ACTIVITY_SUBMIT_SUCCESS, handler(self.onSubmitSuccessEvent, self))
    EventMgr:addEventListener(self, EV_ACTIVITY_UPDATE_PROGRESS, handler(self.onUpdateProgressEvent, self))

    self.Button_zs:onClick(function()
        self:zsGift()
    end)

end

return QLBirthdayView



--endregion
