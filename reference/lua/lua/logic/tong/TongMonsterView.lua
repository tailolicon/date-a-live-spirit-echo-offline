local TongMonsterView = class("TongMonsterView", BaseLayer)

function TongMonsterView:initData(dungonMgrId)

    self.vitmaxThreatCfg        = TabDataMgr:getData("VITmaxEIPointThreat")

    self.dungonMgrId = dungonMgrId
    self.vitDungonCfg = TongDataMgr:getVitDungonCfg(dungonMgrId)
    self.challengeCount_ = 1
    print("TongMonsterView",dungonMgrId)
    local dungeonInclude = self.vitDungonCfg.dungeonInclude
    self.levelCid = dungeonInclude[1]
    self.fubenType_ = FubenDataMgr:getFubenType(self.levelCid)
    self.vitMaxDungonInfo = TabDataMgr:getData("DungeonInfoOfVITmax")[self.levelCid]

    self.activityId = ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.TONG)[1]
    local activityInfo = ActivityDataMgr2:getActivityInfo(self.activityId)
    dump(activityInfo)
    if activityInfo and activityInfo.extendData then
        self.baseBattleNum = activityInfo.extendData.eliteInitBattleNum
        self.buyInfo = activityInfo.extendData.eliteBattleNumPrice
    end

    --self.stateText = {"未开始","战斗中","已逃跑","已击杀","已逃跑"}
    self.stateText = {13206058,13206059,13206060,13206061,13206060}
    dump(self.buyInfo)

    --60未挑战 61未击杀 62击杀 63无 72逃跑
    self.dialogId = {25060,25061,25062,25063,25072}
end

function TongMonsterView:ctor(dungonMgrId)
    self.super.ctor(self)
    self:initData(dungonMgrId)
    self:init("lua.uiconfig.tong.tongMonsterView")
    self.opacity = 255 * 0.45
end

function TongMonsterView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Label_monsterName      = TFDirector:getChildByPath(ui, "Label_monsterName")
    self.Image_monster          = TFDirector:getChildByPath(ui, "Image_monster")
    self.Image_bornEffect       = TFDirector:getChildByPath(ui, "Image_bornEffect")
    self.LoadingBar_level       = TFDirector:getChildByPath(ui, "LoadingBar_level")
    self.Label_level            = TFDirector:getChildByPath(ui, "Label_level")
    self.LoadingBar_hp          = TFDirector:getChildByPath(ui, "LoadingBar_hp")
    self.Label_hp               = TFDirector:getChildByPath(ui, "Label_hp")
    self.Label_monster_state    = TFDirector:getChildByPath(ui, "Label_monster_state")
    self.Label_state_title      = TFDirector:getChildByPath(ui, "Label_state_title")
    self.Label_leftcnt          = TFDirector:getChildByPath(ui, "Label_leftcnt")
    self.Label_lefttime         = TFDirector:getChildByPath(ui, "Label_lefttime")
    self.Label_lefttime_title   = TFDirector:getChildByPath(ui, "Label_lefttime_title")
    self.Label_difficulty       = TFDirector:getChildByPath(ui, "Label_difficulty")

    self.Panel_reward           = TFDirector:getChildByPath(ui, "Panel_reward")
    self.Panel_remain_change    = TFDirector:getChildByPath(ui, "Panel_remain_change")

    self.Spine_level_up         = TFDirector:getChildByPath(ui, "Spine_level_up")

    self.Image_nil_award        = TFDirector:getChildByPath(ui, "Image_nil_award")
    self.Label_nil_buff         = TFDirector:getChildByPath(ui, "Label_nil_buff")

    self.Panel_cur_reward       = TFDirector:getChildByPath(ui, "Panel_cur_reward")
    local ScrollView_award      = TFDirector:getChildByPath(ui, "ScrollView_award")
    self.UIListView_award       = UIListView:create(ScrollView_award)
    self.Label_cur_tip          = TFDirector:getChildByPath(ui, "Label_cur_tip")

    self.Panel_next_reward      = TFDirector:getChildByPath(ui, "Panel_next_reward")
    local ScrollView_next_award = TFDirector:getChildByPath(ui, "ScrollView_next_award")
    self.UIListView_next_award  = UIListView:create(ScrollView_next_award)
    self.Label_blood_tip        = TFDirector:getChildByPath(self.Panel_next_reward, "Label_blood_tip")

    self.Panel_one_reward       = TFDirector:getChildByPath(ui, "Panel_one_reward")
    local ScrollView_award      = TFDirector:getChildByPath(self.Panel_one_reward, "ScrollView_award")
    self.UIListView_one_award   = UIListView:create(ScrollView_award)
    self.UIListView_one_award:setItemsMargin(40)
    self.Label_one_tip          = TFDirector:getChildByPath(self.Panel_one_reward, "Label_cur_tip")

    self.Label_special          = TFDirector:getChildByPath(ui, "Label_special")
    local ScrollView_buff       = TFDirector:getChildByPath(ui, "ScrollView_buff")
    self.GridView_buff          = UIGridView:create(ScrollView_buff)

    local ScrollView_buff_big   = TFDirector:getChildByPath(ui, "ScrollView_buff_big")
    self.UIListView_buffBig     = UIListView:create(ScrollView_buff_big)

    self.Panel_buff_item        = TFDirector:getChildByPath(ui, "Panel_buff_item")
    self.Panel_buff_item_b        = TFDirector:getChildByPath(ui, "Panel_buff_item_b")
    self.Label_askHelp_effect   = TFDirector:getChildByPath(ui, "Label_askHelp_effect")
    self.Panel_threat_level     = TFDirector:getChildByPath(ui, "Panel_threat_level")

    self.Button_detail          = TFDirector:getChildByPath(ui, "Button_detail")
    self.Button_record          = TFDirector:getChildByPath(ui, "Button_record")
    self.Button_fight_ready     = TFDirector:getChildByPath(ui, "Button_fight_ready")
    self.Button_ask_help        = TFDirector:getChildByPath(ui, "Button_ask_help")
    self.Button_retreat         = TFDirector:getChildByPath(ui, "Button_retreat")
    self.Button_get_award       = TFDirector:getChildByPath(ui, "Button_get_award")
    self.Label_btn_award        = TFDirector:getChildByPath(ui, "Label_btn_award")
    self.Button_add_cnt         = TFDirector:getChildByPath(ui, "Button_add_cnt")
    self.Image_gray             = TFDirector:getChildByPath(ui, "Image_gray")

    self.Image_left_bg          = TFDirector:getChildByPath(ui, "Image_left_bg")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")

    self.GridView_buff:setItemModel(self.Panel_buff_item)
    self.GridView_buff:setColumn(6)
    self.GridView_buff:setColumnMargin(10)
    self.GridView_buff:setRowMargin(10)

    self.UIListView_buffBig:setItemModel(self.Panel_buff_item_b)

    self.Image_gray:setGrayEnabled(true)

    TongDataMgr:setFightMonsterState(false)

    self:initUILogic()

    self:timeOut(function()
        --TongDataMgr:Send_GetMonsterInfo()
    end,0)
end

function TongMonsterView:initUILogic()

    if not self.vitMaxDungonInfo then
        return
    end
    dump(self.vitMaxDungonInfo)
    self.Label_monsterName:setTextById(self.vitMaxDungonInfo.eliteBossName)
    self.Image_left_bg:setTexture(self.vitMaxDungonInfo.eliteBossBg)
    self.Label_difficulty:setText(self.vitMaxDungonInfo.eliteLevel)
    Utils:playSound(8154, false)
    -- local bornEffect = self.Image_bornEffect:getChildByName("bornEffect")
    -- if not bornEffect then
    --     bornEffect = SkeletonAnimation:create(self.vitMaxDungonInfo.bornEffect)
    --     bornEffect:setAnimationFps(GameConfig.ANIM_FPS)
    --     bornEffect:playByIndex(0, -1, -1, 0)
    --     bornEffect:setName("Spine_paint")
    --     self.Image_bornEffect:addChild(bornEffect, 100)
    -- end

    -- bornEffect:addMEListener(TFARMATURE_COMPLETE,function()
    --     bornEffect:removeMEListener(TFARMATURE_COMPLETE)
    --     bornEffect:hide()

    local Spine_paint = self.Image_monster:getChildByName("Spine_paint")
    if not Spine_paint then
        Spine_paint = SkeletonAnimation:create(self.vitMaxDungonInfo.eliteBossPaint)
        Spine_paint:setAnimationFps(GameConfig.ANIM_FPS)
        Spine_paint:playByIndex(0, -1, -1, 1)
        Spine_paint:setName("Spine_paint")
        self.Image_monster:addChild(Spine_paint, 100)
    end
    self.Image_monster:setScale(0.55)

    -- end)

    self:updateBaseInfo()
end

function TongMonsterView:updateBaseInfo()

    self:updateHpInfo()
    self:updateTime()
    self:bossStateShow()
    self:updateBattleCnt()
    self:updateBuff()
    self:updateThreatBar()
    self:updateHelpBuff()
    self:timeOut(function()
        self:playGuide()
    end ,0)
end

function TongMonsterView:playGuide()

    local eliteInfo = TongDataMgr:getEliteInfo()
    if not eliteInfo then
        return
    end
    local state = eliteInfo.status
    local fearlessUnlock = eliteInfo.fearlessUnlock
    local isSkillState = state == EC_EliteStatus.KILL
    local index = state
    if isSkillState then
        index = 3
    end

    local isRetreatState = state == EC_EliteStatus.RETREAT or state == EC_EliteStatus.NOT_START_RETREAT
    if isRetreatState then
        index = 5
    end
    --60未挑战 61未击杀 62击杀 63无 72逃跑
    --self.dialogId = {25060,25061,25062,25063,25072}


    local dialogId = self.dialogId[index]

    dump({index,state,dialogId})

    local flag = tonumber(Utils:getLocalSettingValue("TongMonsterView"..dialogId)) or 0
    if flag == 1 then
        return
    end

    Utils:setLocalSettingValue("TongMonsterView"..dialogId,1)

    self:timeOut(function()
        local function callback()
            KabalaTreeDataMgr:playStory(1,dialogId,function ()
                self.guideClick = false
                EventMgr:dispatchEvent(EV_CG_END)
            end)
        end
        KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)
    end)

end

function TongMonsterView:updateThreatBar()

    local eliteInfo = TongDataMgr:getEliteInfo()
    if not eliteInfo then
        return
    end
    local state = eliteInfo.status
    local isPlay = eliteInfo.played
    local isAwardState = state == EC_EliteStatus.RETREAT or state == EC_EliteStatus.KILL or state == EC_EliteStatus.NOT_START_RETREAT
    local changValue = isAwardState and eliteInfo.threatChange or 0 --需要服务器传变化
    local curThreatExp = TongDataMgr:getCurThreatExp()
    local maxThreatCfg = self.vitmaxThreatCfg[#self.vitmaxThreatCfg]
    local curId,curLv = maxThreatCfg.id,maxThreatCfg.threatLevel
    for k,v in ipairs(self.vitmaxThreatCfg) do
        if curThreatExp <= v.threatValueLmt then
            curId = k
            curLv = v.threatLevel
            break
        end
    end
    print("curId",curId,isPlay,isAwardState,curLv)
    if not curId then
        return
    end

    local maxValue,beforValue = TongDataMgr:getBarMaxValue(curId)
    local percent = math.floor((curThreatExp-beforValue)/maxValue*100)
    print(curId,percent,curThreatExp)
    self.LoadingBar_level:setPercent(percent)
    self.Label_level:setText(curLv)

    --[[
    if not isPlay and isAwardState then


        local newExp = math.max(curThreatExp + changValue,0)
        print(curThreatExp,newExp,curThreatExp,changValue)
        local newId,newLv = maxThreatCfg.id,maxThreatCfg.threatLevel

        for k,v in ipairs(self.vitmaxThreatCfg) do
            if newExp <= v.threatValueLmt then
                newId = k
                newLv = v.threatLevel
                break
            end
        end
        print("new",newId,newLv)
        if not newId then
            return
        end

        --local maxValue,beforValue = TongDataMgr:getBarMaxValue(curId)
        --local percent = math.floor((newExp-beforValue)/maxValue*100)
        --self.LoadingBar_level:setPercent(percent)
        --self.Label_level:setText(curLv)

        if curId == newId then
            local maxValue,beforValue = TongDataMgr:getBarMaxValue(curId)
            percent = math.floor((newExp-beforValue)/maxValue*100)
            Utils:loadingBarChangeActionInTime(self.LoadingBar_level,percent,0.5)
        else

            local borderValue,resetValue = 0,100
            if newId > curId then
                borderValue,resetValue = 100,0
            end

            local function completeCallback()

                self.LoadingBar_level:setPercent(resetValue)
                local maxValue,newValue = TongDataMgr:getBarMaxValue(newId)
                percent = math.floor((newExp-newValue)/maxValue*100)
                Utils:loadingBarChangeActionInTime(self.LoadingBar_level,percent,0.5)

                local musicId = curLv > newLv and 8153 or 8152
                Utils:playSound(musicId, false)

                self:timeOut(function()
                    self.Label_level:setText(newLv)
                    self.Spine_level_up:playByIndex(0,-1,-1,0)
                    self.Spine_level_up:addMEListener(TFARMATURE_COMPLETE,function(event)
                        self.Spine_level_up:removeMEListener(TFARMATURE_COMPLETE)
                    end)

                end)
            end

            Utils:loadingBarChangeActionInTime(self.LoadingBar_level,borderValue,0.5,nil, completeCallback)
        end

        TFDirector:send(c2s.FEAR_PAIN_REQ_EFFECT_PLAYED, {})
    end]]
end

function TongMonsterView:updateHpInfo()

    local eliteInfo = TongDataMgr:getEliteInfo()
    if not eliteInfo then
        return
    end

    local maxHp = eliteInfo.maxHp
    local curHp = math.max(eliteInfo.hp,0)
    self.Label_hp:setText(curHp.."/"..maxHp)
    local percent = math.floor(curHp/maxHp*100)
    self.LoadingBar_hp:setPercent(percent)

    local curThreatLv = TongDataMgr:getCurThreatLv()
    local threatCfg = TongDataMgr:getThreatCfgByLv(curThreatLv)
    if not threatCfg then
        return
    end

    local awardInfo = {}
    for k,v in pairs(threatCfg.eliteReward) do
        table.insert(awardInfo, {hpPercent = k, award = v})
    end

    table.sort(awardInfo,function(a,b)
        return a.hpPercent < b.hpPercent
    end)

    local index = #awardInfo
    for i=#awardInfo,1,-1 do
        if percent <= awardInfo[i].hpPercent then
            index = i
        end
    end


    local nextIndex = math.max(index-1,1)
    local state = eliteInfo.status
    local isShowAwardState = state == EC_EliteStatus.FIGHTING
    local showNextReward = isShowAwardState and (nextIndex ~= index)
    self.Panel_next_reward:setVisible(showNextReward)
    self.Panel_cur_reward:setVisible(showNextReward)

    self.Panel_one_reward:setVisible(not showNextReward)

    local nextBlood = awardInfo[nextIndex].hpPercent

    self.Label_blood_tip:setTextById(13206501,nextBlood.."%")

    local str = 13206062
    if EC_EliteStatus.NOT_START == state then
        index = 1
        str = 13206063
    end
    self.Label_one_tip:setTextById(str)

    dump(awardInfo,"curThreatLv: "..curThreatLv..", nextIndex:"..nextIndex.." ,index:"..index.." ,percent:"..percent)

    if not showNextReward then

        self.UIListView_one_award:removeAllItems()
        for k,v in pairs(awardInfo[index].award) do
            local prefebItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
            PrefabDataMgr:setInfo(prefebItem, k, v)
            prefebItem:setScale(0.6)
            self.UIListView_one_award:pushBackCustomItem(prefebItem)
        end
        Utils:setAliginCenterByListView(self.UIListView_one_award,true)
    else
        self.UIListView_award:removeAllItems()
        for k,v in pairs(awardInfo[index].award) do
            local prefebItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
            PrefabDataMgr:setInfo(prefebItem, k, v)
            prefebItem:setScale(0.6)
            self.UIListView_award:pushBackCustomItem(prefebItem)
        end

        self.UIListView_next_award:removeAllItems()
        for k,v in pairs(awardInfo[nextIndex].award) do
            local prefebItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
            PrefabDataMgr:setInfo(prefebItem, k, v)
            prefebItem:setScale(0.6)
            self.UIListView_next_award:pushBackCustomItem(prefebItem)
        end
    end
end


function TongMonsterView:updateTime()

    self.Label_lefttime:stopAllActions()

    local eliteInfo = TongDataMgr:getEliteInfo()
    if not eliteInfo then
        return
    end

    local state = eliteInfo.status
    local isAwardState = state == EC_EliteStatus.RETREAT or state == EC_EliteStatus.KILL or state == EC_EliteStatus.NOT_START_RETREAT
    if isAwardState then
        return
    end

    local remainTime = eliteInfo.leftTime
    local act = CCSequence:create({
        CCCallFunc:create(function()
            remainTime = math.max(remainTime - 1,0)
            if remainTime <= 0 then
                self.Label_lefttime:stopAllActions()
            end
            local day, hour, min, sec = Utils:getDHMS(remainTime, true)
            self.Label_lefttime:setTextById(13206078,hour,min,sec)

            if remainTime == 0 then
                TongDataMgr:Send_GetMonsterInfo()
                EventMgr:dispatchEvent(EV_TONG.MonsterTimeOut)
                AlertManager:closeLayer(self)
            end
        end),
        CCDelayTime:create(1)
    })
    self.Label_lefttime:runAction(CCRepeatForever:create(act))
end

function TongMonsterView:updateBattleCnt()

    if not self.buyInfo then
        return
    end

    local leftCount,buyIndex = TongDataMgr:getBattleCntInfo()
    print(leftCount,buyIndex)
    if not leftCount or not buyIndex then
        return
    end

    local maxBuyCnt = #self.buyInfo

    local index = math.min(buyIndex + 1,maxBuyCnt)

    self.remainCnt = leftCount
    self.Label_leftcnt:setTextById(13206064,self.remainCnt)
   -- self.Button_add_cnt:setGrayEnabled(index >= #self.buyInfo)
    self.Image_gray:setGrayEnabled(buyIndex >= maxBuyCnt)

end

function TongMonsterView:bossStateShow()

    local eliteInfo = TongDataMgr:getEliteInfo()
    if not eliteInfo then
        return
    end

    dump(eliteInfo,"eliteInfo")
    local state = eliteInfo.status
    local isAwardState = state == EC_EliteStatus.RETREAT or state == EC_EliteStatus.KILL or state == EC_EliteStatus.NOT_START_RETREAT
    self.Button_fight_ready:setVisible(not isAwardState)

    self.Panel_reward:setVisible(state ~= EC_EliteStatus.NOT_START_RETREAT)
    self.Image_nil_award:setVisible(state == EC_EliteStatus.NOT_START_RETREAT)

    self.Button_get_award:setVisible(isAwardState)
    self.Button_retreat:setVisible(state == EC_EliteStatus.FIGHTING)
    self.Button_ask_help:setVisible(not isAwardState)

    local posX = self.Button_retreat:isVisible() and 517 or 381
    self.Button_ask_help:setPositionX(posX)

    self.Panel_remain_change:setVisible(not isAwardState)

    local posX = state == EC_EliteStatus.NOT_START and 80 or 144
    self.Label_leftcnt:setPositionX(posX)
    self.Button_add_cnt:setVisible(state ~= EC_EliteStatus.NOT_START)
    self.Image_gray:setVisible(state ~= EC_EliteStatus.NOT_START)

    self.Label_monster_state:setTextById(self.stateText[state])
    self.Label_monster_state:setVisible(isAwardState)
    self.Label_state_title:setVisible(isAwardState)

    self.Label_lefttime:setVisible(not isAwardState)
    self.Label_lefttime_title:setVisible(not isAwardState)

    self.Label_level:setVisible(isAwardState)
    self.Label_difficulty:setVisible(not isAwardState)

    local str = state == EC_EliteStatus.NOT_START_RETREAT and 491011 or 2400013
    self.Label_btn_award:setTextById(str)
end

function TongMonsterView:isShowSpecial(levelCid)
    local lv = TongDataMgr:getMaxThreatLv()
    local cfg = TongDataMgr:getThreatCfgByLv(lv)
    if not cfg then
        return false
    end
    local index = table.indexOf(cfg.eliteDungeonInclude,levelCid)
    return index ~= -1
end

function TongMonsterView:updateBuff()

    local eliteInfo = TongDataMgr:getEliteInfo()
    if not eliteInfo then
        return
    end

    local buff = {}
    local affix = eliteInfo.affix or {}
    local fearlessAffix = eliteInfo.fearlessAffix or {}

    local text = #fearlessAffix > 0 and 13206066 or 13206067
    self.Label_special:setTextById(text)
    local isShowSpecial = self:isShowSpecial(self.levelCid)
    self.Label_special:setVisible(isShowSpecial and eliteInfo.fearlessUnlock)

    table.insertTo(buff,affix)
    table.insertTo(buff,fearlessAffix)

    local buffCnt = #buff
    self.Label_nil_buff:setVisible(buffCnt <= 0)

    self.GridView_buff:removeAllItems()
    self.UIListView_buffBig:removeAllItems()
    local listView = self.UIListView_buffBig
    if buffCnt> 4 then
        listView = self.GridView_buff
    end

    for k,v in ipairs(buff) do
        local cfg = TongDataMgr:getAffixCfg(v)
        if cfg then
            local item = listView:pushBackDefaultItem()
            local img = TFDirector:getChildByPath(item, "Image_icon")
            img:setTexture(cfg.icon)
        end
    end

    if buffCnt <= 4 then
        Utils:setAliginCenterByListView(listView,true)
    end
end

function TongMonsterView:updateHelpBuff()
    local helpBuff = TongDataMgr:getHelpBuff()
    if not helpBuff then
        self.Label_askHelp_effect:setTextById(13400066)
        return
    end

    local cfg = TongDataMgr:getCombatMgrCfg(helpBuff)
    if cfg then
        self.Label_askHelp_effect:setTextById(cfg.buffDescribe)
    else
        self.Label_askHelp_effect:setTextById(13400066)
    end
end

function TongMonsterView:addBattleNum()
    if not self.remainCnt or not self.baseBattleNum or not self.buyInfo then
        return
    end

    local leftCount,buyIndex = TongDataMgr:getBattleCntInfo()
    if not leftCount or not buyIndex then
        return
    end


    local index = buyIndex + 1

    dump(self.buyInfo)

    local info = self.buyInfo[index]
    if not info then
        Utils:showTips(13206068)
        return
    end

    print(self.remainCnt , self.baseBattleNum)
    if self.remainCnt >= self.baseBattleNum then
        Utils:showTips(13206069)
        return
    end

    dump( self.buyInfo)

    local costIcon = TabDataMgr:getData("Item",info[1]).icon
    local rstr = TextDataMgr:getTextAttr(13206079)
    local formatStr = rstr and rstr.text or ""
    local content = string.format(formatStr, info[2], costIcon)

    local args = {
        tittle = 13206082,
        content = content,
        confirmCall = function()
            TongDataMgr:Send_AddBattleCount()
        end,
    }
   Utils:openView("tong.TongAddNumConfirmView",args)
end

function TongMonsterView:registerEvents()

    EventMgr:addEventListener(self, EV_TONG.ActiveAffix, handler(self.updateBuff, self))
    EventMgr:addEventListener(self, EV_TONG.EliteInfo, handler(self.updateBaseInfo, self))
    EventMgr:addEventListener(self, EV_TONG.BattleCnt, handler(self.updateBattleCnt, self))
    EventMgr:addEventListener(self, EV_TONG.UpdateHelpBuff, handler(self.updateHelpBuff, self))

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    self.Panel_root:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    self.Button_ask_help:onClick(function()
        Utils:openView("tong.TongAskHelpView")
    end)

    self.Button_fight_ready:onClick(function()

        local function func()
            if not self.remainCnt then
                return
            end

            if self.remainCnt <= 0 then
                self:addBattleNum()
                return
            end

            local data = {
                type_ = self.vitDungonCfg.type,
                levelCid = self.levelCid,
                bossId = self.vitMaxDungonInfo.eliteBossId,
            }
            Utils:openView("fuben.FubenSquadView", self.fubenType_ , data, self.challengeCount_)
        end


        local isOpen = ActivityDataMgr2:isInOpenTime(self.activityId)
        if not isOpen then
            local args = {
                tittle = 2107025,
                content = TextDataMgr:getText(13205113),
                reType = false,
                opacity = 255 * 0.45,
                confirmCall = function()
                    local layerName = {"TongMonsterView","TongMainView"}
                    for k,v in ipairs(layerName) do
                        local isLayerInQueue,layer = AlertManager:isLayerInQueue(v)
                        if isLayerInQueue then
                            AlertManager:closeLayer(layer)
                        end
                    end
                end,
                showCancel = false,
                showClose = false
            }
            Utils:openView("tong.TongAddNumConfirmView",args)
        else
            func()
        end

    end)

    self.Button_retreat:onClick(function()
        Utils:openView("tong.TongRetreatConfirmView",self.dungonMgrId)
    end)

    self.Button_get_award:onClick(function()
        TongDataMgr:Send_getMonsterFightAward()
        AlertManager:closeLayer(self)
    end)

    self.Button_add_cnt:onClick(function()
        self:addBattleNum()
    end)

    self.Button_record:onClick(function()
        Utils:openView("tong.TongFightRecordView",self.vitMaxDungonInfo.eliteBossName)
    end)

    self.Button_detail:onClick(function()
        Utils:openView("tong.TongBossInfoView",self.levelCid)
    end)

    self.GridView_buff:s():onClick(function()

        local eliteInfo = TongDataMgr:getEliteInfo()
        if not eliteInfo then
            return
        end

        if not eliteInfo.fearless then
        end

        Utils:openView("tong.TongBuffListView")
    end)

    self.UIListView_buffBig:s():onClick(function()

        local eliteInfo = TongDataMgr:getEliteInfo()
        if not eliteInfo then
            return
        end

        if not eliteInfo.fearless then
        end

        Utils:openView("tong.TongBuffListView")
    end)
end

return TongMonsterView
