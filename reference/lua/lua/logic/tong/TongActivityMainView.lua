
local TongActivityMainView = class("TongActivityMainView", BaseLayer)

function TongActivityMainView:initData(isOpen)

    self.isStoryMode = true
    self.isPlayGuide = false

    self.activityId = ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.TONG)[1]
    local activityInfo = ActivityDataMgr2:getActivityInfo(self.activityId)
    if activityInfo and activityInfo.extendData then
        self.eliteRefCost = activityInfo.extendData.eliteRefCost
        self.lastDunStage1 = activityInfo.extendData.lastDunStage1NS
        self.helpInterface = activityInfo.extendData.helpInterface or {2404,2405}
        if activityInfo.extendData.isStoryMode ~= nil then
            self.isStoryMode = activityInfo.extendData.isStoryMode
        end
        self.storeId = tonumber(activityInfo.extendData.storeId)
        self.taskId = tonumber(activityInfo.extendData.taskId)
    end
    dump(activityInfo)
    --self.isStoryMode = false
    self.guideInfo = {}
    self.guideInfo[1] = {guideGroupId = 34, dialogScriptId = 25053, guideClick = false}
    self.guideInfo[2] = {guideGroupId = 35, dialogScriptId = 25055, guideClick = false}

    self.taskaAtivityId = self.taskId or 10652
end

function TongActivityMainView:ctor()
    self.super.ctor(self)
    self:initData()
    self:init("lua.uiconfig.tong.tongActivityMainView")
end

function TongActivityMainView:initUI(ui)
    self.super.initUI(self, ui)
    --self:setAnchorPoint(me.p(0.5,0.5))

    self.Panel_root             = TFDirector:getChildByPath(self.ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(self.ui, "Button_close"):hide()

    self.Button_store           = TFDirector:getChildByPath(self.ui, "Button_store")
    self.Button_skill           = TFDirector:getChildByPath(self.ui, "Button_skill")
    self.Button_map             = TFDirector:getChildByPath(self.ui, "Button_map")
    self.Button_boss            = TFDirector:getChildByPath(self.ui, "Button_boss")
    self.Button_task            = TFDirector:getChildByPath(self.ui, "Button_task")
    self.Image_redtip           = TFDirector:getChildByPath(self.Button_task, "Image_redtip")
    self.Button_rank            = TFDirector:getChildByPath(self.ui, "Button_rank")
    self.Panel_mask             = TFDirector:getChildByPath(self.ui, "Panel_mask")
    self.Button_other           = TFDirector:getChildByPath(self.ui, "Button_other")
    self.Button_guide           = TFDirector:getChildByPath(self.ui, "Button_guide")

    self.Spine_elite_flag       = TFDirector:getChildByPath(self.ui, "Spine_elite_flag"):hide()
    self.Spine_supply_flag      = TFDirector:getChildByPath(self.ui, "Spine_supply_flag"):hide()

    self.Panel_mask:setSize(GameConfig.WS)
    self.Panel_mask:setVisible(false)

    GuideDataMgr:setIsBattle(false)

    self:loadRes()

    self:initUILogic()
end

function TongActivityMainView:loadRes()
    me.TextureCache:addImage("effect/eff_vitmax/VITmax_effect_level_elite.png")
    me.TextureCache:addImage("effect/eff_vitmax/VITmax_effect_level_story.png")
    me.TextureCache:addImage("effect/eff_vitmax/VITmax_effect_level_storyBattle.png")
    me.TextureCache:addImage("effect/eff_vitmax/bornEffect_maple/skeleton.png")
    me.TextureCache:addImage("modle/hero/paintshow_13701/paintshow_13701.png")
end

function TongActivityMainView:initUILogic()

    if self.isPlayGuide then

        if self.isStoryMode then
            local canfightIndex = 1
            local isPass,levelCid = TongDataMgr:guideLevelState(1)
            if isPass then
                isPass,levelCid = TongDataMgr:guideLevelState(2)
                canfightIndex = 2
            end
            if not isPass then
                self.Panel_mask:show()
                TongDataMgr:guideFight(levelCid,canfightIndex)
            end

        end

        if self.isStoryMode then
            local isPass3rd,levelCid  = TongDataMgr:guideLevelState(3)
            self.Button_skill:setTouchEnabled(isPass3rd)
            self.Button_skill:setGrayEnabled(not isPass3rd)
        end

    end
end

function TongActivityMainView:onShow()
    self.super.onShow(self)

    self:onReconect()

    if self.isPlayGuide then

        if self.isStoryMode then

            local state = TongDataMgr:getActivityViewState()
            if state then
                TongDataMgr:setActivityViewState(false)
                return
            end

            local isPass,levelCid = TongDataMgr:guideLevelState(2)
            if isPass then
                local isPlay = self:playDialog(1)
                if isPlay then
                    return
                end
            end

        end

        if self.isStoryMode then
            local isPass3rd,levelCid = TongDataMgr:guideLevelState(3)
            if isPass3rd then
                self:playDialog(2)
            end
        end

    end

end

function TongActivityMainView:playDialog(guideIndex)

    local guide = self.guideInfo[guideIndex]
    if not guide then
        return false
    end

    local isSave = GuideDataMgr:isSaveGuideGroup(guide.guideGroupId)
    if not isSave then
        local function callback()
            KabalaTreeDataMgr:playStory(1,guide.dialogScriptId,function ()
                EventMgr:dispatchEvent(EV_CG_END,function()
                    self.checkGroupId = guide.guideGroupId
                    GameGuide:checkGuide(self)
                    guide.guideClick = true
                end)
            end)
        end
        KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)
        return true
    end

    return false
end

function TongActivityMainView:onUpdateProgressEvent()
    self:showRedTip()
end

function TongActivityMainView:datingfightOver()

    if self.isPlayGuide then

        if not self.isStoryMode then
            return
        end

        local isPass,levelCid = TongDataMgr:guideLevelState(2)
        if not isPass then
            self.Panel_mask:show()
            TongDataMgr:guideFight(levelCid,2)
        end

    end
end

function TongActivityMainView:limitHero()

    if self.isPlayGuide then
        local isPass,levelCid = TongDataMgr:guideLevelState(2)
        if not isPass then
            TongDataMgr:guideLimitHeroFight(levelCid)
        end
    end

end

function TongActivityMainView:onReconect()

    TongDataMgr:Send_getStudyInfo()
    TongDataMgr:Send_getBossInfo()
    TongDataMgr:Send_getFightReport()
    TongDataMgr:Send_getBaseInfo()

    self:showRedTip()

end

function TongActivityMainView:onDatingExit()

    if self.isPlayGuide then
        if not self.isStoryMode then
            return
        end

        local isPass,levelCid = TongDataMgr:guideLevelState(1)
        if not isPass then
            AlertManager:closeLayer(self)
        end
    end
end

function TongActivityMainView:updateFlag()

    local isOpen = ActivityDataMgr2:isInOpenTime(self.activityId)
    if not isOpen then
        self.Spine_elite_flag:hide()
        self.Spine_supply_flag:hide()
        return
    end

    local exist = TongDataMgr:isExistSpecialDot(EC_PatongUiType.MonsterMode)
    if exist then
        self.Spine_elite_flag:show()
        TongDataMgr:Send_GetMonsterInfo()
    else
        self.Spine_elite_flag:hide()
    end

    local existAirDrop = TongDataMgr:isExistSpecialDot(EC_PatongUiType.AirDrop)
    local existAirDropIns = TongDataMgr:isExistSpecialDot(EC_PatongUiType.AirDropInterest)

    if existAirDrop or existAirDropIns then
        self.Spine_supply_flag:show()
    else
        self.Spine_supply_flag:hide()
    end

end

function TongActivityMainView:showRedTip()

    local show = ActivityDataMgr2:isCanGet(self.taskaAtivityId)
    self.Image_redtip:setVisible(show)
end

function TongActivityMainView:registerEvents()

    EventMgr:addEventListener(self, EV_ACTIVITY_UPDATE_PROGRESS, handler(self.onUpdateProgressEvent, self))
    EventMgr:addEventListener(self, EV_RECONECT_EVENT, handler(self.onReconect, self))

    EventMgr:addEventListener(self, EV_BATTLE_FIGHTOVER, handler(self.datingfightOver, self))
    EventMgr:addEventListener(self, EV_FUBEN_UPDATE_LIMITHERO, handler(self.limitHero, self))

    EventMgr:addEventListener(self, EV_DATING_EVENT.exitScriptView, handler(self.onDatingExit, self))

    EventMgr:addEventListener(self, EV_TONG.FinishElite, handler(self.updateFlag, self))
    EventMgr:addEventListener(self, EV_TONG.UpdateElite, handler(self.updateFlag, self))
    EventMgr:addEventListener(self, EV_TONG.UpdateAir, handler(self.updateFlag, self))
    EventMgr:addEventListener(self, EV_TONG.BaseInfo, handler(self.updateFlag, self))

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    self.Button_store:onClick(function()
        local isOpen = ActivityDataMgr2:isInOpenTimeByType(EC_ActivityType2.STORE)
        if not isOpen then
            Utils:showTips(1710021)
            return
        end
        Utils:openView("tong.TongStoreView",self.storeId)
    end)

    self.Button_skill:onClick(function()
        Utils:openView("tong.TongStudyMainView",self.guideInfo[2].guideClick)
        self.guideInfo[2].guideClick = false
    end)

    self.Button_map:onClick(function()
        Utils:openView("tong.TongMainView",nil,nil,self.guideInfo[1].guideClick)
        self.guideInfo[1].guideClick = false
    end)

    self.Button_boss:onClick(function()
        Utils:openView("tong.TongBossView")
    end)

    self.Button_task:onClick(function()

        local isOpen = ActivityDataMgr2:isInOpenTime(self.taskaAtivityId)
        if not isOpen then
            Utils:showTips(1710021)
            return
        end
        Utils:openView("tong.TongTaskView",self.taskId)
    end)

    self.Button_rank:onClick(function()
        Utils:openView("tong.TongRankView")
    end)

    self.Button_other:onClick(function()
        FunctionDataMgr:jActivity()
    end)

    self.Button_guide:onClick(function()
        Utils:openView("common.HelpView",self.helpInterface)
    end)
end

return TongActivityMainView
