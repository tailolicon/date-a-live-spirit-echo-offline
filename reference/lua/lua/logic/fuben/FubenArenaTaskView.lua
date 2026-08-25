
local FubenArenaTaskView = class("FubenArenaTaskView", BaseLayer)

function FubenArenaTaskView:initData(levelGroupId, diff)

end

function FubenArenaTaskView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaTask")
end

function FubenArenaTaskView:initUI(ui)
	self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_item = TFDirector:getChildByPath(self.Panel_root , "Panel_item"):hide()
    self.Image_content =  TFDirector:getChildByPath(self.Panel_root, "Image_content")
    self.Button_close = TFDirector:getChildByPath(self.Image_content, "Button_close")
    local ScrollView = TFDirector:getChildByPath(self.Image_content, "ScrollView")
    self:setLang()
    self.ListView = UIListView:create(ScrollView)
    self.taskDatas = { }
    self:refreshView()
end

--多语言设置
function FubenArenaTaskView:setLang()
    local Label_title_name = TFDirector:getChildByPath(self.Image_content, "Label_title_name")
    Label_title_name:setTextById(212098) 
    local label     = TFDirector:getChildByPath(self.Panel_item, "label")
    label:setTextById(310008)
    
end

function FubenArenaTaskView:addTaskItem()
    

    local item          = self.Panel_item:clone():show()    
    item.Label_Title    = TFDirector:getChildByPath(item, "Label_Title")
    item.Label_desc     = TFDirector:getChildByPath(item, "Label_desc")
    item.Label_progress = TFDirector:getChildByPath(item, "Label_progress")
    item.Button_get     = TFDirector:getChildByPath(item, "Button_get")
    item.Label_btn_name = TFDirector:getChildByPath(item.Button_get, "Label_btn_name")
    item.Label_geted    = TFDirector:getChildByPath(item, "Label_geted")
    item.ScrollView     = TFDirector:getChildByPath(item, "ScrollView")
    item.ListView       = UIListView:create(item.ScrollView)
    return item
end




function FubenArenaTaskView:refreshView()
    self.taskDatas = TaskDataMgr:getTask(EC_TaskType.ARENA)
    local items = self.ListView:getItems()
    local gap = #self.taskDatas - #items
    if gap > 0 then
        for i = 1, math.abs(gap) do
            local taskItem = self:addTaskItem()
            taskItem:setName("taskItem"..i)
            self.ListView:pushBackCustomItem(taskItem)
        end
    else
        for i = 1, math.abs(gap) do
            self.ListView:removeItem(1)
        end
    end


    for i,v in ipairs(self.taskDatas) do
        local item = self.ListView:getItem(i)
        self:updateItem(item, v)
    end
end

function FubenArenaTaskView:updateItem(item, taskCid)
    local taskCfg  = TaskDataMgr:getTaskCfg(taskCid)
    local taskInfo = TaskDataMgr:getTaskInfo(taskCid)
    local progress = math.min(taskInfo.progress, taskCfg.progress)
    if taskCfg.name and #taskCfg.name >0 then 
        item.Label_Title:setTextById(taskCfg.name)
    else
        item.Label_Title:setText("")
    end
    local desc = TaskDataMgr:getTaskDesc(taskCid)
    item.Label_desc:setText(desc)

    item.Label_progress:setText("("..progress.."/"..taskCfg.progress..")")
    --奖励列表
    local rewards = taskCfg.reward

    local rewardItems = item.ListView:getItems()
    local gap = #rewards - #rewardItems
    for i = 1, math.abs(gap) do
        if gap < 0 then
            item.ListView:removeItem(1)
        else
            local panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
            panel_goodsItem:setScale(0.75)
            item.ListView:pushBackCustomItem(panel_goodsItem)
        end
    end

    for i, reward in ipairs(rewards) do
        local panel_goodsItem = item.ListView:getItem(i)
        PrefabDataMgr:setInfo(panel_goodsItem, reward[1], reward[2])
    end
    if taskInfo.status == EC_TaskStatus.GETED then 
        item.Label_geted:setTextById(1300015)
    elseif taskInfo.status == EC_TaskStatus.ING  then 
        item.Label_geted:setTextById(3202063)
    end
    item.Label_geted:setVisible(taskInfo.status == EC_TaskStatus.GETED or taskInfo.status == EC_TaskStatus.ING )

    item.Label_btn_name:setTextById(1200015)
    -- item.Button_get:setGrayEnabled(false)
    -- item.Button_get:setTouchEnabled(true)
    item.Button_get:setVisible(taskInfo.status == EC_TaskStatus.GET)
    item.Button_get:onClick(function ()
        -- print("Item on click")
           TaskDataMgr:send_TASK_SUBMIT_TASK(taskInfo.cid)
    end)
      --item.Button_get:hide()
end




        -- local taskCid = self.task_[i]
        -- local taskCfg = TaskDataMgr:getTaskCfg(taskCid)
        -- local taskInfo = TaskDataMgr:getTaskInfo(taskCid)
        -- local progress = math.min(taskInfo.progress, taskCfg.progress)
        -- tab.itemLabTip:setTextById(taskCfg.name)
        -- tab.labProcesShow:setPositionX(tab.itemLabTip:getContentSize().width)
        -- tab.labProcesShow:setText("("..progress.."/"..taskCfg.progress..")")
        -- tab.rewards:removeAllChildren()
        -- for j,reward in ipairs(taskCfg.reward) do
        --     local goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
        --     goodsItem:Scale(0.75)
        --     goodsItem:Pos(40 + (j - 1) * 85, 45):AddTo(tab.rewards)
        --     PrefabDataMgr:setInfo(goodsItem, reward[1], reward[2])
        -- end
        -- tab.btnComplete:setVisible(taskInfo.status == EC_TaskStatus.GET)
        -- tab.label_geted:setVisible(taskInfo.status == EC_TaskStatus.GETED)
        -- tab.Image_not_complete:setVisible(taskInfo.status == EC_TaskStatus.ING)
        -- tab.btnComplete:onClick(function()
        --     TaskDataMgr:send_TASK_SUBMIT_TASK(taskInfo.cid)
        -- end)




function FubenArenaTaskView:registerEvents()
    EventMgr:addEventListener(self, EV_TASK_RECEIVE, handler(self.onTaskGetRewardBack, self))
    self.Button_close:onClick(function()
        AlertManager:close()
    end)
end

function FubenArenaTaskView:onTaskGetRewardBack(reward)
    if reward then
        Utils:showReward(reward)
    end
    self:refreshView()
end


return FubenArenaTaskView
