
local ReplaceAppView = class("ReplaceAppView", BaseLayer)

function ReplaceAppView:initData(activityId)
    self.activityId = activityId
    self.activityInfo_ = ActivityDataMgr2:getActivityInfo(self.activityId)



    dump(self.activityInfo_)
    -- Box("xxxxx")


end

function ReplaceAppView:ctor(data)
    self.super.ctor(self,data)
    self:initData(data)

    -- local uiName = self.activityInfo_.extendData.uiName or "ReplaceAppView"
    self:init("lua.uiconfig.secondary.uiconfig_zn.activity.replaceAppView") 
end

function ReplaceAppView:initUI(ui)
    self.super.initUI(self, ui)

       -- ui:setPosition(ccp(600,320))

    self.Panel_root   = TFDirector:getChildByPath(ui, "Panel_root")
    self.Button_zs    = TFDirector:getChildByPath(self.Panel_root, "Button_zs")
    self.Label_tipBig = TFDirector:getChildByPath(self.Button_zs, "Label_btn")
    self.Label_tipBig:setTextById(1820002)

    self.ScrollView_award = TFDirector:getChildByPath(self.Panel_root, "ScrollView_award")
    self.Label_tip      = TFDirector:getChildByPath(self.Panel_root, "Label_tip")
    self.Image_time     = TFDirector:getChildByPath(self.Panel_root, "Image_time")


    self.Label_timing  = TFDirector:getChildByPath(self.Panel_root, "Label_timing")
    -- self.Image_time:hide()

    self.Label_tip:setTextById(self.activityInfo_.extendData.tip)









    self:refreshView()
    --ext  配置文本 tip  taskid
end




function ReplaceAppView:updateCountDonw()

    -- local startDate = Utils:getLocalDate(self.activityInfo_.startTime)
    -- local startDateStr = startDate:fmt("%m.%d")
    -- local endDate = Utils:getLocalDate(self.activityInfo_.endTime)
    -- local endDateStr = endDate:fmt("%m.%d")
    -- self.Label_timing:setTextById(800041, startDateStr, endDateStr)

    -- local isEnd = ActivityDataMgr2:isEnd(self.activityId)
    -- local serverTime = ServerDataMgr:getServerTime()
    -- if isEnd then
    --     local remainTime = math.max(0, self.activityInfo_.showEndTime - serverTime)
    --     local day, hour, min = Utils:getFuzzyDHMS(remainTime, true)
    --     if day == "00" then
    --         self.Label_timing:setTextById("r41004", hour, min)
    --     else
    --         self.Label_timing:setTextById("r41003", day, hour)
    --     end
    -- else
    --     local remainTime = math.max(0, self.activityInfo_.endTime - serverTime)
    --     local day, hour, min = Utils:getFuzzyDHMS(remainTime, true)
    --     if day == "00" then
    --         self.Label_timing:setTextById("r41002", hour, min)
    --     else
    --         self.Label_timing:setTextById("r41001", day, hour)
    --     end
    -- end


    self.Label_timing:setText("")
    if self.activityInfo_.startTime and self.activityInfo_.endTime then
        self.Label_timing:setText(Utils:getActivityDateString(self.activityInfo_.startTime, self.activityInfo_.endTime))
    end
end

-- function ReplaceAppView:onUpdateCountDownEvent()
--     self:updateCountDonw()
-- end

function ReplaceAppView:refreshView()
    -- local specialTaskItem = ActivityDataMgr2:getItemInfo(self.activityInfo_.activityType, tonumber(self.activityInfo_.extendData.specialTask))
    local showReward = self.activityInfo_.extendData.reward or {}
    Utils:createRewardListHor(self.ScrollView_award,showReward)
    self:updateCountDonw()
end




function ReplaceAppView:registerEvents()
    EventMgr:addEventListener(self, EV_ACTIVITY_SUBMIT_SUCCESS, handler(self.onRespGetReward, self))
    self.Button_zs:onClick(function()
        ActivityDataMgr2:send_ACTIVITY_NEW_SUBMIT_ACTIVITY(self.activityInfo_.id, tonumber(self.activityInfo_.extendData.taskid))
    end)

end
function ReplaceAppView:onShow()
    self.super.onShow(self)
    self:updateBuyButtonStatus()
end

function ReplaceAppView:updateBuyButtonStatus()
    local progressInfo = ActivityDataMgr2:getProgressInfo(self.activityInfo_.activityType, self.activityInfo_.extendData.taskid)
    dump(progressInfo)
    if progressInfo and progressInfo.status == EC_TaskStatus.GET then
        self.Button_zs:setGrayEnabled(false)
        self.Button_zs:setTouchEnabled(true)  
        self.Label_tipBig:setTextById(1820002) --领取
    elseif progressInfo and progressInfo.status == EC_TaskStatus.GETED then
        self.Button_zs:setGrayEnabled(true)
        self.Button_zs:setTouchEnabled(false)  
        self.Label_tipBig:setTextById(1300015) --领取
    else
        self.Button_zs:setGrayEnabled(true)
        self.Button_zs:setTouchEnabled(false)  
        self.Label_tipBig:setTextById(1300007) --未达成
    end

end

function ReplaceAppView:onRespGetReward(actId, entryID, reward)
    print("获得奖励-------------------------------")
    if actId == self.activityId then
        Utils:showReward(reward)
        self:updateBuyButtonStatus()
    end
end

return ReplaceAppView
