
local TongTaskView = class("TongTaskView", BaseLayer)

function TongTaskView:initData(taskId)

    self.activityId_ = taskId or 10652--ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.TASK)[1]
    self.activityInfo_ = ActivityDataMgr2:getActivityInfo(self.activityId_)

    self.taskItems_ = {}
end

function TongTaskView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.tong.tongTaskView")
    self.block = AlertManager.BLOCK_CLOSE
end

function TongTaskView:initUI(ui)
    self.super.initUI(self, ui)

    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")

    self.Panel_taskItem = TFDirector:getChildByPath(ui, "Panel_taskItem")


    local ScrollView_task = TFDirector:getChildByPath(ui, "ScrollView_list")
    self.ListView_task = UIListView:create(ScrollView_task)

    self.TableView_task = Utils:scrollView2TableView(ScrollView_task)
    --self.TableView_task:setDirection(TFTableView.TFSCROLLHORIZONTAL)
    self.TableView_task:addMEListener(TFTABLEVIEW_SIZEFORINDEX, handler(self.tableCellSize,self))
    self.TableView_task:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, handler(self.numberOfCells,self))
    self.TableView_task:addMEListener(TFTABLEVIEW_SIZEATINDEX, handler(self.tableCellAtIndex,self))

    self.Button_close = TFDirector:getChildByPath(ui, "Button_close")

    self.Label_time_tip = TFDirector:getChildByPath(ui, "Label_time_tip")
    self.Label_time_begin = TFDirector:getChildByPath(ui, "Label_time_begin")
    self.Label_time_end = TFDirector:getChildByPath(ui, "Label_time_end")
    self.Label_time_begin:setSkewX(10)
    self.Label_time_end:setSkewX(10)
    self.Label_time_tip:setSkewX(10)

    self:refreshView()
end

function TongTaskView:refreshView()

    if self.activityInfo_ then
        local startDate = Utils:getUTCDate(self.activityInfo_.startTime ,GV_UTC_TIME_ZONE)
        local startDateStr = startDate:fmt("%Y.%m.%d")
        local endDate = Utils:getUTCDate(self.activityInfo_.endTime ,GV_UTC_TIME_ZONE)
        local endDateStr = endDate:fmt("%Y.%m.%d")
        self.Label_time_begin:setText(startDateStr)
        self.Label_time_end:setText(endDateStr ..GV_UTC_TIME_STRING)
    end

    self:updateActivity()
end

function TongTaskView:updateActivity()
    self.activityInfo_ = ActivityDataMgr2:getActivityInfo(self.activityId_)
    if not self.activityInfo_ then
        return
    end
    local taskData = ActivityDataMgr2:getItems(self.activityId_)
    self.taskData_ = {}
    local unLockData = {}
    local lockData = {}
    for k,v in ipairs(taskData) do
        local itemInfo = ActivityDataMgr2:getItemInfo(self.activityInfo_.activityType, v)
        local isUnlock = true
        if itemInfo.extendData and itemInfo.extendData.level then
            isUnlock = PrivilegeDataMgr:getWishTreeLv() >= itemInfo.extendData.level
        end

        if isUnlock then
            table.insert(unLockData,v)
        else
            table.insert(lockData,v)
        end
    end

    table.insertTo(self.taskData_,unLockData)
    table.insertTo(self.taskData_,lockData)


    --[[self.ListView_task:AsyncUpdateItem(self.taskData_,function ( ... )
        return self:addTaskItem()
    end, function (v, data)
        self:updateTaskItem(v, data)
    end)--]]
    self.TableView_task:reloadData()
end

function TongTaskView:numberOfCells(tableView)
    return #self.taskData_
end

function TongTaskView:tableCellSize(tableView)
    local size = self.Panel_taskItem:getContentSize()
    return size.height, size.width
end

function TongTaskView:tableCellAtIndex(tab, idx)
    local cell = tab:dequeueCell()
    idx = idx + 1
    if not cell then
        cell = TFTableViewCell:create()
        local item = self.Panel_taskItem:clone():show()
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

function TongTaskView:updateItem(item,itemId)

    local Image_icon = TFDirector:getChildByPath(item, "Image_icon")
    local Label_desc = TFDirector:getChildByPath(item, "Label_desc")
    local Label_progress_title = TFDirector:getChildByPath(item, "Label_progress_title")
    Label_progress_title:setTextById(1890002)
    local Label_progress = TFDirector:getChildByPath(item,"Label_progress")

    local Button_receive = TFDirector:getChildByPath(item, "Button_receive")
    local Label_receive = TFDirector:getChildByPath(item, "Label_receive")
    Label_receive:setTextById(1300008)
    local Button_goto = TFDirector:getChildByPath(item, "Button_goto")
    local Label_goto = TFDirector:getChildByPath(Button_goto, "Label_goto")
    Label_goto:setTextById(1300009)
    local Label_geted_bg = TFDirector:getChildByPath(item, "Label_geted_bg")
    local Label_geted = TFDirector:getChildByPath(item, "Label_geted")
    Label_geted:setTextById(1300015)
    local Label_reward = TFDirector:getChildByPath(item, "Label_reward")
    Label_reward:setTextById(1890003)
    local Image_reset = TFDirector:getChildByPath(item, "Image_reset"):hide()
    local Image_get = TFDirector:getChildByPath(item, "Image_get")
    local Image_getted = TFDirector:getChildByPath(item, "Image_getted")
    local Image_getted_mask = TFDirector:getChildByPath(item, "Image_getted_mask")
    local Image_lock = TFDirector:getChildByPath(item, "Image_lock"):hide()
    local Label_lock = TFDirector:getChildByPath(item, "Label_lock")


    local activityInfo = self.activityInfo_
    local itemInfo = ActivityDataMgr2:getItemInfo(activityInfo.activityType, itemId)
    local progress = ActivityDataMgr2:getProgress(activityInfo.activityType, itemId)
    local progressInfo = ActivityDataMgr2:getProgressInfo(activityInfo.activityType, itemId)

    local isUnlock = true
    if itemInfo.extendData and itemInfo.extendData.level then
        isUnlock = PrivilegeDataMgr:getWishTreeLv() >= itemInfo.extendData.level
        Label_lock:setTextById(15010119,itemInfo.extendData.level)
    end
    Image_lock:setVisible(not isUnlock)

    Image_icon:setTexture(itemInfo.extendData.icon)
    Label_desc:setTextById(itemInfo.extendData.des2, itemInfo.target)
    Label_progress:setTextById(800005, progress, itemInfo.target)
    if progress > tonumber(itemInfo.target)  then
        Label_progress:setTextById(800005, itemInfo.target, itemInfo.target)
    end

    local goodsId, goodsNum
    for i = 1, 3 do
        local Image_reward_ = TFDirector:getChildByPath(item, "Image_reward_" .. i)
        local Panel_goodsItem = Image_reward_:getChildByName("Panel_goodsItem")
        if not Panel_goodsItem then
            Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
            Panel_goodsItem:AddTo(Image_reward_):Pos(0, 0):Scale(0.75)
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

    Button_receive:setVisible(progressInfo.status == EC_TaskStatus.GET)
    Label_geted:setVisible(progressInfo.status == EC_TaskStatus.GETED)
    if Label_geted_bg then
        Label_geted_bg:setVisible(progressInfo.status == EC_TaskStatus.GETED)
    end
    Button_goto:setVisible(progressInfo.status == EC_TaskStatus.ING and itemInfo.extendData.jumpInterface)
    Image_reset:setVisible(itemInfo.extendData.resetType == 2)
    if Image_get then
        Image_get:setVisible(progressInfo.status == EC_TaskStatus.GET)
    end

    if Image_getted then
        Image_getted:setVisible(progressInfo.status == EC_TaskStatus.GETED)
    end
    if Image_getted_mask then
        Image_getted_mask:setVisible(progressInfo.status == EC_TaskStatus.GETED)
    end
    Button_receive:onClick(function()
        if ServerDataMgr:getServerTime() >= self.activityInfo_.endTime then
            Utils:showTips(1710021)
            return
        end
        ActivityDataMgr2:send_ACTIVITY_NEW_SUBMIT_ACTIVITY(activityInfo.id, itemId)
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

function TongTaskView:onShow()

end

function TongTaskView:addTaskItem()
    local Panel_taskItem = self.Panel_taskItem:clone()
    local foo = {}
    foo.root = Panel_taskItem
    foo.Image_icon = TFDirector:getChildByPath(foo.root, "Image_icon")
    foo.Label_desc = TFDirector:getChildByPath(foo.root, "Label_desc")
    foo.Label_progress_title = TFDirector:getChildByPath(foo.root, "Label_progress_title")
    foo.Label_progress_title:setTextById(1890002)
    if self.isBackPlayer then
        foo.Label_progress_title:setTextById(100000002)
    end
    foo.Label_progress = TFDirector:getChildByPath(foo.root, "Label_progress")
    foo.Image_reward = {}
    for i = 1, 3 do
        local bar = {}
        bar.root = TFDirector:getChildByPath(foo.root, "Image_reward_" .. i)
        bar.Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
        bar.Panel_goodsItem:AddTo(bar.root):Pos(0, 0):Scale(0.75)
        foo.Image_reward[i] = bar
    end
    foo.Button_receive = TFDirector:getChildByPath(foo.root, "Button_receive")
    foo.Label_receive = TFDirector:getChildByPath(foo.root, "Label_receive")
    foo.Label_receive:setTextById(1300008)
    foo.Button_goto = TFDirector:getChildByPath(foo.root, "Button_goto")
    foo.Label_goto = TFDirector:getChildByPath(foo.Button_goto, "Label_goto")
    foo.Label_goto:setTextById(1300009)
    foo.Label_geted_bg = TFDirector:getChildByPath(foo.root, "Label_geted_bg")
    foo.Label_geted = TFDirector:getChildByPath(foo.root, "Label_geted")
    foo.Label_geted:setTextById(1300015)
    foo.Label_reward = TFDirector:getChildByPath(foo.root, "Label_reward")
    foo.Label_reward:setTextById(1890003)
    foo.Image_reset = TFDirector:getChildByPath(foo.root, "Image_reset"):hide()
    foo.Image_get = TFDirector:getChildByPath(foo.root, "Image_get")
    foo.Image_getted = TFDirector:getChildByPath(foo.root, "Image_getted")
    foo.Image_getted_mask = TFDirector:getChildByPath(foo.root, "Image_getted_mask")
    foo.Image_lock = TFDirector:getChildByPath(foo.root, "Image_lock"):hide()
    foo.Label_lock = TFDirector:getChildByPath(foo.root, "Label_lock")
    self.taskItems_[foo.root] = foo

    return Panel_taskItem
end

function TongTaskView:updateTaskItem(item,itemId)
    local activityInfo = self.activityInfo_
    local itemInfo = ActivityDataMgr2:getItemInfo(activityInfo.activityType, itemId)
    local progress = ActivityDataMgr2:getProgress(activityInfo.activityType, itemId)
    local progressInfo = ActivityDataMgr2:getProgressInfo(activityInfo.activityType, itemId)

    local foo = self.taskItems_[item]
    local isUnlock = true
    if itemInfo.extendData and itemInfo.extendData.level then
        isUnlock = PrivilegeDataMgr:getWishTreeLv() >= itemInfo.extendData.level
        foo.Label_lock:setTextById(15010119,itemInfo.extendData.level)
    end
    foo.Image_lock:setVisible(not isUnlock)

    foo.Image_icon:setTexture(itemInfo.extendData.icon)
    foo.Label_desc:setText(itemInfo.extendData.des2)
    foo.Label_progress:setTextById(800005, progress, itemInfo.target)
    if progress > tonumber(itemInfo.target)  then
        foo.Label_progress:setTextById(800005, itemInfo.target, itemInfo.target)
    end

    local goodsId, goodsNum
    for i, v in ipairs(foo.Image_reward) do
        local id, num = next(itemInfo.reward, goodsId)
        if id then
            goodsId = id
            goodsNum = num
        end
        v.Panel_goodsItem:setVisible(tobool(id))
        if v.Panel_goodsItem:isVisible() then
            PrefabDataMgr:setInfo(v.Panel_goodsItem, goodsId, goodsNum)
        end
    end

    foo.Button_receive:setVisible(progressInfo.status == EC_TaskStatus.GET)
    foo.Label_geted:setVisible(progressInfo.status == EC_TaskStatus.GETED)
    if foo.Label_geted_bg then
        foo.Label_geted_bg:setVisible(progressInfo.status == EC_TaskStatus.GETED)
    end
    foo.Button_goto:setVisible(progressInfo.status == EC_TaskStatus.ING and itemInfo.extendData.jumpInterface)
    foo.Image_reset:setVisible(itemInfo.extendData.resetType == 2)
    if foo.Image_get then
        foo.Image_get:setVisible(progressInfo.status == EC_TaskStatus.GET)
    end
    if foo.Image_get then
        foo.Image_getted:setVisible(progressInfo.status == EC_TaskStatus.GETED)
    end
    if foo.Image_getted_mask then
        foo.Image_getted_mask:setVisible(progressInfo.status == EC_TaskStatus.GETED)
    end
    foo.Button_receive:onClick(function()
        if ServerDataMgr:getServerTime() >= self.activityInfo_.endTime then
            Utils:showTips(1710021)
            return
        end
        ActivityDataMgr2:send_ACTIVITY_NEW_SUBMIT_ACTIVITY(activityInfo.id, itemId)
    end)
    foo.Button_goto:onClick(function()
        if ServerDataMgr:getServerTime() >= self.activityInfo_.endTime then
            Utils:showTips(1710021)
            return
        end

        local param = itemInfo.extendData.parameter or {}
        FunctionDataMgr:enterByFuncId(itemInfo.extendData.jumpInterface,unpack(param))
    end)
end

function TongTaskView:onSubmitSuccessEvent(activitId, itemId, reward)
    if self.activityId_ ~= activitId then return end
    Utils:showReward(reward)
end

function TongTaskView:onUpdateProgressEvent()
    self:updateActivity()
end

function TongTaskView:registerEvents()
    self.super.registerEvents(self)

    EventMgr:addEventListener(self, EV_ACTIVITY_SUBMIT_SUCCESS, handler(self.onSubmitSuccessEvent, self))
    EventMgr:addEventListener(self, EV_ACTIVITY_UPDATE_PROGRESS, handler(self.onUpdateProgressEvent, self))

    self.Button_close:onClick(function()
        AlertManager:closeLayer(self)
    end)
end

return TongTaskView
