
local TongBossView = class("TongBossView", BaseLayer)
function TongBossView:initData()

    self.vitProgressCfg = TabDataMgr:getData("VITmaxProgress")
    self.vITmaxStageCfg = TabDataMgr:getData("VITmaxStage")
    self.dialogScriptId = {25067,25068,25069}

    self.reportItem_ = {}


    self.deltaDisX = {-20,-10,0,10,20}

    self.actParam_ = self:getActionParam()

    self.reportIndex = 1
    self.bossLogClearTime = 3

    local activityId = ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.TONG)[1]
    local activityInfo = ActivityDataMgr2:getActivityInfo(activityId)
    if activityInfo and activityInfo.extendData then
        self.baseBattleNum = activityInfo.extendData.eliteInitBattleNum
        self.buyInfo = activityInfo.extendData.eliteBattleNumPrice
        self.bossLogClearTime = activityInfo.extendData.bossLogClearTime or 3
    end

end

function TongBossView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.tong.tongBossView")
end

function TongBossView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Label_percent          = TFDirector:getChildByPath(self.Panel_root, "Label_percent")
    self.Image_bar              = TFDirector:getChildByPath(self.Panel_root, "Image_bar")
    self.LoadingBar             = TFDirector:getChildByPath(self.Panel_root, "LoadingBar")
    self.Panel_spineBg          = TFDirector:getChildByPath(self.Panel_root, "Panel_spineBg")

    local ScrollView_report     = TFDirector:getChildByPath(self.Panel_root, "ScrollView_report")
    self.ListView_report        = UIListView:create(ScrollView_report)

    self.Panel_report           = TFDirector:getChildByPath(self.Panel_root, "Panel_report")

    self.Spine_point            = TFDirector:getChildByPath(self.Panel_root, "Spine_point")

    self.Label_tip              = TFDirector:getChildByPath(self.Panel_root, "Label_tip")
    self.Label_hurt             = TFDirector:getChildByPath(self.Panel_root, "Label_sigle_hurt")
    self.Button_rank            = TFDirector:getChildByPath(self.Panel_root, "Button_rank")

    self.Button_award           = TFDirector:getChildByPath(self.Panel_root, "Button_award")

    self.Label_max_lv           = TFDirector:getChildByPath(self.Panel_root, "Label_max_lv")
    self.Label_blood_tip        = TFDirector:getChildByPath(self.Panel_root, "Label_blood_tip")

    self.Panel_prefab           = TFDirector:getChildByPath(ui, "Panel_prefab")
    self.Panel_rankItem         = TFDirector:getChildByPath(self.Panel_prefab, "Panel_rankItem")
    self.Panel_reportItem       = TFDirector:getChildByPath(self.Panel_prefab, "Panel_reportItem")
    self.Panel_awardItem        = TFDirector:getChildByPath(self.Panel_prefab, "Panel_awardItem")

    self.rankPL = {}
    for i=1,3 do
        local Panel_rankItem    = TFDirector:getChildByPath(self.Panel_root, "Panel_rankItem"..i)
        local Label_name        = TFDirector:getChildByPath(Panel_rankItem, "Label_name")
        local Label_hurt        = TFDirector:getChildByPath(Panel_rankItem, "Label_hurt")
        table.insert(self.rankPL,{pl = Panel_rankItem,nameTx = Label_name, hurtTx = Label_hurt})
    end

    self.originalSize = self.Panel_spineBg:getContentSize()

    self:updateBaseInfo()

    local act = CCSequence:create({
        CCCallFunc:create(function()
            TongDataMgr:Send_getFightReport()
        end),
        CCDelayTime:create(self.bossLogClearTime)
    })
    self.Panel_root:runAction(CCRepeatForever:create(act))

end

function TongBossView:updateBaseInfo()

    self:updateRankList()
    self:updateProgress()
    self:updateServerTask()

    self:timeOut(function()
        self:playDialog()
    end,0)
end

function TongBossView:updateReport()

    self.Panel_report:stopAllActions()
    local reportInfos = TongDataMgr:getReportList()
    local num = #reportInfos
    dump(num)
    if num == 0 then
        return
    end

    local time = self.bossLogClearTime/num
    self.reportIndex = 1
    local act = CCSequence:create({
        CCCallFunc:create(function()
            self:playReport(self.reportIndex)
        end),
        CCDelayTime:create(time),
    })
    self.Panel_report:runAction(CCRepeatForever:create(act))

end

function TongBossView:playDialog()

    local bossInfo = TongDataMgr:getWorldBossInfo()
    if not bossInfo then
        return
    end

    local dialogId = self.dialogScriptId[bossInfo.stageId]
    local flag = tonumber(Utils:getLocalSettingValue("TongMainView"..dialogId)) or 0
    if flag == 1 then
        return
    end

    Utils:setLocalSettingValue("TongMainView"..dialogId,1)

    local function callback()
        KabalaTreeDataMgr:playStory(1,dialogId,function ()
            EventMgr:dispatchEvent(EV_CG_END,function()
            end)
        end)
    end
    KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)

end

function TongBossView:playReport(index)

    local reportInfo = TongDataMgr:getReportList(index)
    if not reportInfo then
        return
    end

    self.reportIndex = index + 1

    local item = self:getReportItem()
    if not item then
        item = self.Panel_reportItem:clone()
        self.Panel_report:addChild(item)
    end

    local Label_report = TFDirector:getChildByPath(item, "Label_report")
    Label_report:setTextById(13206504,reportInfo.name,reportInfo.hurt)
    local Image_text_bg = TFDirector:getChildByPath(item, "Image_text_bg")

    local size = Label_report:getContentSize()
    local width,height = size.width+16,size.height + 6
    item:setContentSize(CCSizeMake(width,height))
    Image_text_bg:setContentSize(CCSizeMake(width,height))

    Label_report:setPositionY(-height/2)

    local randomIndex = math.random(1,#self.deltaDisX)
    local deltaDis = self.deltaDisX[randomIndex]

    for i=1,4 do
        self.actParam_[i].x = self.actParam_[i].x + deltaDis
    end

    item:setOpacity(0)
    item:setPosition(self.actParam_[1])

    local act1 = CCSpawn:create({CCFadeIn:create(0.5),CCMoveTo:create(0.5,self.actParam_[2])})
    local act2 = CCMoveTo:create(2,self.actParam_[3])

    local act3 = CCSpawn:create({CCFadeOut:create(0.5),CCMoveTo:create(0.5,self.actParam_[4])})
    local act4 = CCCallFunc:create(function()
        table.insert(self.reportItem_,item)
    end)
    item:runAction(CCSequence:create({act1,act2,act3,act4}))
end

function TongBossView:getActionParam()

    local startPos = ccp(0 ,32)
    local endPos = ccp(238,451)
    local speed = self:calcSpeed(startPos,endPos)
    local k1,k2 = self:calcK(startPos,endPos)

    local dis1 = speed * 0.5
    local pos1 = self:calcPosByDis(dis1,k1,k2)

    local dis2 = speed * 2.5
    local pos2 = self:calcPosByDis(dis2,k1,k2)

    return {startPos,pos1,pos2,endPos}
end

function TongBossView:calcDis(pos1,pos2)

    local deltaY = pos2.y - pos1.y
    local deltaX = pos2.x - pos1.x

    local s = math.sqrt(deltaY * deltaY + deltaX * deltaX)

    return s
end

function TongBossView:calcSpeed(pos1,pos2)
    local dis = self:calcDis(pos1,pos2)
    local speed = dis/3
    return speed
end

function TongBossView:calcK(pos1,pos2)

    local deltaX = pos2.x - pos1.x
    local deltaY = pos2.y - pos1.y
    local dis = self:calcDis(pos1,pos2)

    local k1 = deltaX /dis
    local k2 = deltaY /dis

    return k1,k2
end

function TongBossView:calcPosByDis(dis,k1,k2)
    return ccp(dis * k1,dis * k2)
end

function TongBossView:getReportItem()
    local item = table.remove(self.reportItem_,1)
    return item
end


function TongBossView:updateRankList()

    local bossInfo = TongDataMgr:getWorldBossInfo()
    if not bossInfo then
        return
    end

    local myName = MainPlayer:getPlayerName()
    local rankData = bossInfo.rank or {}
    for k,v in ipairs(self.rankPL) do
        local rankInfo = rankData[k]
        if rankInfo then
            v.pl:setVisible(true)
            local color = myName == rankInfo.name and ccc3(93,255,221) or ccc3(255,255,255)
            v.nameTx:setColor(color)
            v.nameTx:setText(rankInfo.name)
            v.hurtTx:setText(rankInfo.hurt)
        else
            v.pl:setVisible(false)
        end
    end
    dump(bossInfo.myHurt)
    self.Label_hurt:setText(bossInfo.myHurt)

end

function TongBossView:updateProgress()

    local bossInfo = TongDataMgr:getWorldBossInfo()
    if not bossInfo then
        return
    end
    dump(bossInfo)
    local maxPro = self.vitProgressCfg[#self.vitProgressCfg].progress
    local bossProgress = bossInfo.progress
 
    local curProgress       = math.max(maxPro - bossProgress,0)
    local percent           = math.floor(curProgress/maxPro*100)

    self.Label_percent:setText(percent.."%")
    self.LoadingBar:setPercent(percent)

    local w = self.originalSize.width*curProgress/maxPro
    self.Panel_spineBg:setContentSize(CCSizeMake(w, self.originalSize.height))

    local w = self.Image_bar:getContentSize().width
    local pointX = -w/2 + w *curProgress/maxPro
    self.Spine_point:setPositionX(-7+pointX)

    local stageId = bossInfo.stageId
    local cfg = self.vITmaxStageCfg[stageId]
    if cfg then
        self.Label_max_lv:setText(cfg.eliteLevelLmt)
        local nextStageId = stageId + 1
        local nextStageCfg = self.vITmaxStageCfg[nextStageId]
        if nextStageCfg then
            local percent           = math.floor(nextStageCfg.condByProgress/maxPro*100)
            self.Label_blood_tip:setTextById(13206040,percent.."%")
        else
            self.Label_blood_tip:setText("")
        end
    end

end


function TongBossView:updateServerTask()

    local bossInfo = TongDataMgr:getWorldBossInfo()
    if not bossInfo then
        return
    end

    local maxPro = self.vitProgressCfg[#self.vitProgressCfg].progress

    local bossProgress      = bossInfo.progress
    local curProgress       = math.max(maxPro - bossProgress,0)

    local w = self.Image_bar:getContentSize().width
    local startPosX = -w/2

    dump(bossInfo)

    local showIndex = 0

    for k,v in ipairs(self.vitProgressCfg) do

        local progress = maxPro - v.progress
        local itemId,itemNum = v.rewardShow
        local Panel_awardItem = self.Image_bar:getChildByName("Panel_awardItem"..k)
        if not Panel_awardItem then
            Panel_awardItem = self.Panel_awardItem:clone()
            Panel_awardItem:setName("Panel_awardItem"..k)
            self.Image_bar:addChild(Panel_awardItem)

            local Label_num = Panel_awardItem:getChildByName("Label_num")
            local percent = math.floor(progress/maxPro*100)
            Label_num:setText(percent.."%")
            local x = progress/maxPro*w + startPosX
            Panel_awardItem:setPosition(ccp(x,63))
        end

        local isReceive = curProgress <= progress
        local isGet = TongDataMgr:isGetBossAward(k)
        local Label_get = Panel_awardItem:getChildByName("Label_get")
        local Label_geted = Panel_awardItem:getChildByName("Label_geted")
        local Label_not = Panel_awardItem:getChildByName("Label_not")
        local Image_item = Panel_awardItem:getChildByName("Image_item")
        local Image_arrow = Panel_awardItem:getChildByName("Image_arrow"):hide()

        Label_get:setVisible(isReceive and not isGet)
        Label_geted:setVisible(isGet)

        Label_not:setVisible(not isReceive and not isGet)

        if isGet then
            showIndex = k
        end

        local cfg = GoodsDataMgr:getItemCfg(itemId)
        if cfg then
            Image_item:setTexture(cfg.icon)
        end

        Panel_awardItem:setTouchEnabled(false)
        Panel_awardItem:onClick(function()
            if isReceive then
                TongDataMgr:Send_getBossStageAward(k)
            else
                --Utils:showInfo(itemId)
                Utils:openView("tong.TongBossRewardView")
            end
        end)
    end

    showIndex = math.min(showIndex + 1,#self.vitProgressCfg)

    local Panel_awardItem = self.Image_bar:getChildByName("Panel_awardItem"..showIndex)
    local Image_arrow = Panel_awardItem:getChildByName("Image_arrow")
    Image_arrow:show()
    Panel_awardItem:setTouchEnabled(showIndex)
end

function TongBossView:onShow()
    --self.super.onShow(self)
end

function TongBossView:onHide()
    self.super.onHide(self)
end

function TongBossView:registerEvents()

    EventMgr:addEventListener(self, EV_TONG.BossAward, handler(self.updateServerTask, self))
    EventMgr:addEventListener(self, EV_TONG.WorldBoss, handler(self.updateBaseInfo, self))
    EventMgr:addEventListener(self, EV_TONG.Report, handler(self.updateReport, self))

    self.Button_award:onClick(function()
        Utils:openView("tong.TongBossRewardView")
    end)

    self.Button_rank:onClick(function()
        Utils:openView("tong.TongRankView")
    end)
end

return TongBossView
