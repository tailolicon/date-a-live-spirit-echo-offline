
local TongFightReadyView = class("TongFightReadyView", BaseLayer)

function TongFightReadyView:initData(dungonMgrId,endTime)

    self.endTime = endTime
    self.dungonMgrId = dungonMgrId
    self.vitDungonCfg = TongDataMgr:getVitDungonCfg(dungonMgrId)
    self.vitMaxDungonInfo = TabDataMgr:getData("DungeonInfoOfVITmax")

    self.diffData_ = {
        [1] = {
            color = ccc3(255, 255, 255),
            name = 13206080,
        },
        [2] = {
            color = ccc3(112, 143, 255),
            name = 13206081,
        },
    }

    self.saveId = tonumber(Utils:getLocalSettingValue("TongDiff")) or 1

    self.challengeCount_ = 1

    self.activityId = ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.TONG)[1]
    local activityInfo = ActivityDataMgr2:getActivityInfo(self.activityId)
    if activityInfo and activityInfo.extendData then
        self.eliteRefCost = activityInfo.extendData.eliteRefCost
    end

end

function TongFightReadyView:ctor(dungonMgrId,endTime)
    self.super.ctor(self)
    self:initData(dungonMgrId,endTime)
    self:showPopAnim(true)
    self.opacity = 255 * 0.45

    self:init("lua.uiconfig.tong.tongReadyView")

end

function TongFightReadyView:initUI(ui)
    self.super.initUI(self, ui)
    self:addLockLayer()

    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")

    self.Image_content          = TFDirector:getChildByPath(ui, "Image_content")

    self.Panel_fighting         = TFDirector:getChildByPath(ui, "Panel_fighting")
    self.Button_select          = TFDirector:getChildByPath(ui, "Button_select"):hide()
    self.Button_ready           = TFDirector:getChildByPath(ui, "Button_ready")
    self.Label_name             = TFDirector:getChildByPath(ui, "Label_name")
    self.Label_cond             = TFDirector:getChildByPath(self.Panel_fighting, "Label_cond")
    self.Label_curPoint         = TFDirector:getChildByPath(self.Panel_fighting, "Label_curPoint")
    self.Label_nextPoint        = TFDirector:getChildByPath(self.Panel_fighting, "Label_nextPoint")
    self.Label_over_point       = TFDirector:getChildByPath(self.Panel_fighting, "Label_over_point")
    self.Label_fighting_decs    = TFDirector:getChildByPath(self.Panel_fighting, "Label_fighting_decs"):hide()
    self.Label_fighting_decs:setTextById(190001163)
    self.Panel_difficulty       = TFDirector:getChildByPath(self.Panel_fighting, "Panel_difficulty")
    self.Button_diff_select     = TFDirector:getChildByPath(self.Panel_fighting, "Button_diff_select")
    self.Label_time             = TFDirector:getChildByPath(self.Panel_fighting, "Label_time"):hide()
    self.Label_diff_select      = TFDirector:getChildByPath(self.Button_diff_select, "Label_diff_select")
    self.Panel_diff             = TFDirector:getChildByPath(self.Panel_fighting, "Panel_diff"):hide()
    self.Button_diff = {}
    for i = 1, 2 do
        local item = {}
        item.root               = TFDirector:getChildByPath(self.Panel_diff, "Button_diff_" .. i)
        item.Label_diff         = TFDirector:getChildByPath(item.root, "Label_diff")
        self.Button_diff[i] = item
    end

    self.Panel_dating           = TFDirector:getChildByPath(ui, "Panel_dating")
    self.Label_datingDesc       = TFDirector:getChildByPath(self.Panel_dating, "Label_datingDesc")
    self.Label_datingDescTitle  = TFDirector:getChildByPath(self.Panel_dating, "Label_datingDescTitle")
    self.Label_datingTargetTitle= TFDirector:getChildByPath(self.Panel_dating, "Label_datingTargetTitle")
    self.Label_dating_reward    = TFDirector:getChildByPath(self.Panel_dating, "Label_dating_reward")
    self.Label_datingTarget     = TFDirector:getChildByPath(self.Panel_dating, "Label_datingTarget")
    self.Image_flag             = TFDirector:getChildByPath(self.Panel_dating, "Image_flag")
    self.Image_datingDesc       = TFDirector:getChildByPath(self.Panel_dating, "Image_datingDesc")

    self.Image_datingStar       = TFDirector:getChildByPath(self.Panel_dating, "Image_datingStar")
    self.Image_datingTarget     = TFDirector:getChildByPath(self.Panel_dating, "Image_datingTarget")

    self.Button_dating          = TFDirector:getChildByPath(self.Panel_dating, "Button_dating")
    self.Label_dating           = TFDirector:getChildByPath(self.Panel_dating, "Label_dating")

    self.Panel_reward           = TFDirector:getChildByPath(ui, "Panel_reward")

    self.Image_reward_bg        = TFDirector:getChildByPath(self.Panel_reward, "Image_reward_bg")

    local ScrollView_reward     = TFDirector:getChildByPath(self.Panel_reward, "ScrollView_reward")
    self.GridView_reward = UIGridView:create(ScrollView_reward)
    self.GridView_reward:setColumn(2)
    self.GridView_reward:setColumnMargin(10)
    self.GridView_reward:setRowMargin(10)
    local Panel_dropGoodsItem   = PrefabDataMgr:getPrefab("Panel_dropGoodsItem"):clone()
    Panel_dropGoodsItem:Scale(0.65)
    self.GridView_reward:setItemModel(Panel_dropGoodsItem)

    local ScrollView_fight_award= TFDirector:getChildByPath(ui, "ScrollView_fight_award")
    self.UIListView_fight       = UIListView:create(ScrollView_fight_award)

    self.Button_cost            = TFDirector:getChildByPath(ui, "Button_cost")
    self.Panel_costPos          = TFDirector:getChildByPath(ui, "Panel_costPos"):hide()
    self.Label_costNum          = TFDirector:getChildByPath(self.Button_cost, "Label_costNum")
    self.Image_costIcon         = TFDirector:getChildByPath(self.Button_cost, "Image_costIcon")
    self.Label_cost             = TFDirector:getChildByPath(self.Button_cost, "Label_cost")

    self:refreshView()

end

function TongFightReadyView:refreshView()

    if not self.vitDungonCfg then
        return
    end

    self.isDatingMode = EC_PatongUiType.DatingFight == self.vitDungonCfg.type or EC_PatongUiType.Dating == self.vitDungonCfg.type
    self.Panel_dating:setVisible(self.isDatingMode)
    self.Panel_fighting:setVisible(not self.isDatingMode)
    self.Button_cost:setVisible(self.vitDungonCfg.type == EC_PatongUiType.FightMode)

    if self.isDatingMode then
        self:updateDatingMode()
    else
        self:selectDiff(self.saveId)
    end

    local dungeonInclude = self.vitDungonCfg.dungeonInclude
    self.Panel_difficulty:setVisible(#dungeonInclude >= 2)

    for i, v in ipairs(self.Button_diff) do
        if dungeonInclude[i] then
            v.root:show()
            local diffData = self.diffData_[i]
            v.Label_diff:setTextById(diffData.name)
        else
            v.root:hide()
        end
    end

end

function TongFightReadyView:selectDiff(index)

    local diffData = self.diffData_[index]
    self.Label_diff_select:setTextById(diffData.name)

    self.saveId = index

    self:updateFightMode()
end

function TongFightReadyView:getLevelCid()

    local dungeonInclude = self.vitDungonCfg.dungeonInclude
    local levelCid = dungeonInclude[1]
    if #dungeonInclude >= 2 then
        levelCid = dungeonInclude[self.saveId]
    end

    return levelCid
end

function TongFightReadyView:updateFeature(type_)

    local color = EC_PatongUiType.DatingFight == type_  and ccc3(10,99,111) or  ccc3(126,71,85)
    local fightRes = EC_PatongUiType.DatingFight == type_  and "ui/tong/common/btn1.png" or "ui/tong/common/btn2.png"
    local closeRes = EC_PatongUiType.DatingFight == type_  and "ui/tong/squad/012.png" or "ui/tong/squad/011.png"
    local flagRes = EC_PatongUiType.DatingFight == type_  and "ui/tong/squad/009.png" or "ui/tong/squad/015.png"
    local borderRes = EC_PatongUiType.DatingFight == type_  and "ui/tong/squad/013_2.png" or "ui/tong/squad/013.png"
    local awardRes = EC_PatongUiType.DatingFight == type_  and "ui/tong/squad/014_2.png" or "ui/tong/squad/014.png"
    local contentRes = EC_PatongUiType.DatingFight == type_  and "ui/tong/squad/fight.png" or "ui/tong/squad/dating.png"

    self.Label_datingDescTitle:setFontColor(color)
    self.Label_datingTargetTitle:setFontColor(color)
    self.Label_dating_reward:setFontColor(color)
    self.Label_datingDesc:setFontColor(color)
    self.Label_datingTarget:setFontColor(color)
    self.Label_name:setFontColor(color)
    self.Button_dating:setTextureNormal(fightRes)
    self.Button_close:setTextureNormal(closeRes)
    self.Image_flag:setTexture(flagRes)
    self.Image_datingStar:setTexture(flagRes)


    self.Image_datingTarget:setTexture(borderRes)
    self.Image_datingDesc:setTexture(borderRes)
    self.Image_reward_bg:setTexture(awardRes)
    self.Image_content:setTexture(contentRes)
end

function TongFightReadyView:updateDatingMode()

    local levelCid = self:getLevelCid()
    local levelCfg_ = FubenDataMgr:getLevelCfg(levelCid)
    if not levelCfg_ then
        return
    end
    dump(levelCfg_,self.vitDungonCfg.type)
    local levelInfo = FubenDataMgr:getLevelInfo(levelCid)
    dump(levelInfo)

    self:updateFeature(self.vitDungonCfg.type)
    self.Label_fighting_decs:setVisible(levelCfg_.dungeonType == EC_FBLevelType.TONG_FIGHT)

    if EC_PatongUiType.DatingFight == self.vitDungonCfg.type then

        if levelCfg_.dungeonType == EC_FBLevelType.TONG_DATINGFIGHT then
            self.Label_datingDesc:setTextById(levelCfg_.plotBrief)
            self.Label_datingDescTitle:setTextById(300826, TextDataMgr:getText(300827))
        else
            local desc = ""
            for i, v in ipairs(levelCfg_.victoryType) do
                desc = desc .. FubenDataMgr:getPassCondDesc(levelCid, i)
                if i < #levelCfg_.victoryType then
                    desc = desc .. ", "
                end
            end
            self.Label_datingDesc:setText(desc)
            self.Label_datingDescTitle:setTextById(300826, TextDataMgr:getText(300822))
        end
        self.Label_dating:setTextById(13206043)
    else
        self.Label_datingDesc:setTextById(levelCfg_.plotBrief)
        self.Label_datingDescTitle:setTextById(300826, TextDataMgr:getText(300827))
        self.Label_dating:setTextById(13206044)
    end

    self.Label_name:setTextById(levelCfg_.name)
    self.Label_datingTargetTitle:setTextById(300826, TextDataMgr:getText(300836))

    self.Label_dating_reward:setTextById(300826, TextDataMgr:getText(300127))

    local desc = FubenDataMgr:getStarRuleDesc(levelCid, 1)
    self.Label_datingTarget:setText(desc)

    local isReach = FubenDataMgr:judgeStarIsActive(levelCid, 1)
    print("isReach",isReach)
    --self.Label_datingTarget:setVisible(isReach)


    self.GridView_reward:removeAllItems()
    local isPass = FubenDataMgr:isPassPlotLevel(levelCid)
    for k, v in pairs(levelCfg_.rewardShow) do
        local Panel_dropGoodsItem = self.GridView_reward:pushBackDefaultItem()
        local flag = isPass and EC_DropShowType.DATING_GETED or 0
        PrefabDataMgr:setInfo(Panel_dropGoodsItem, {k,v}, flag)
    end
end

function TongFightReadyView:updateFightMode()

    local levelCid = self:getLevelCid()
    local levelCfg_ = FubenDataMgr:getLevelCfg(levelCid)
    if not levelCfg_ then
        return
    end

    self.Label_fighting_decs:setVisible(levelCfg_.dungeonType == EC_FBLevelType.TONG_FIGHT)


    local desc = ""
    for i, v in ipairs(levelCfg_.victoryType) do
        desc = desc .. FubenDataMgr:getPassCondDesc(levelCid, i)
        if i < #levelCfg_.victoryType then
            desc = desc .. ", "
        end
    end
    self.Label_cond:setText(desc)

    local itemId,maxCnt
    for k,v in pairs(self.eliteRefCost or {}) do
        itemId,maxCnt = k,v
    end

    self.Label_name:setTextById(levelCfg_.name)
    dump(levelCfg_)

    local addCnt = 0
    self.UIListView_fight:removeAllItems()
    for k, v in pairs(levelCfg_.rewardShow) do
        local num = v * self.challengeCount_
        if itemId == k then
            addCnt = num
        else
            local Panel_dropGoodsItem =  PrefabDataMgr:getPrefab("Panel_dropGoodsItem"):clone()
            Panel_dropGoodsItem:setScale(0.8)
            local flag = sdw and EC_DropShowType.DATING_GETED or 0
            PrefabDataMgr:setInfo(Panel_dropGoodsItem, {k,num}, 0)
            self.UIListView_fight:pushBackCustomItem(Panel_dropGoodsItem)
        end
    end

    if itemId and maxCnt then
        local ownCnt = GoodsDataMgr:getItemCount(itemId)
        self.Label_curPoint:setText(ownCnt.."/"..maxCnt)

        local itemCfg = GoodsDataMgr:getItemCfg(itemId)

        self.Label_over_point:hide()
        local nextCnt = addCnt + ownCnt
        if nextCnt > itemCfg.totalMax then
            nextCnt = itemCfg.totalMax
            self.Label_over_point:show()
        end
        self.Label_nextPoint:setText(nextCnt.."/"..maxCnt)

        local posX = self.Label_nextPoint:getPositionX() + self.Label_nextPoint:getContentSize().width + 2
        self.Label_over_point:setPositionX(posX)
    end


    local cost = levelCfg_.cost[1]
    if cost then
        local costItemCfg = GoodsDataMgr:getItemCfg(cost[1])
        self.Image_costIcon:setTexture(costItemCfg.icon)
        local challengeCount = math.max(1, self.challengeCount_)
        self.Label_costNum:setText(cost[2] * challengeCount)
        self.Button_cost:show()

        local showMuiltCost = false
        local bossStage = TongDataMgr:getBossStage()
        local stageCfg = TongDataMgr:getVitStageCfg(bossStage)
        if stageCfg then
            showMuiltCost = stageCfg.isVITmaxQuickBattle and levelCfg_.isQuickBattle
        end

        self.Button_select:setVisible(showMuiltCost)
        if not showMuiltCost then
            self.Button_cost:Pos(self.Panel_costPos:Pos())
        else
            self:timeOut(function()
                self:playDialog()
            end)
        end
    end
    self.Label_cost:setTextById(300020)

    self.Label_time:stopAllActions()
    if self.endTime then
        self.Label_time:show()
        local remainTime = self.endTime - ServerDataMgr:getServerTime()
        local act = CCSequence:create({
            CCCallFunc:create(function()
                remainTime = math.max(remainTime - 1,0)
                local day, hour, min, sec = Utils:getDHMS(remainTime, true)
                self.Label_time:setTextById(13316023,hour..":"..min..":"..sec)
            end),
            CCDelayTime:create(1)
        })
        self.Label_time:runAction(CCRepeatForever:create(act))
    end
end

function TongFightReadyView:playDialog()
    local dialogId = 25070
    local flag = tonumber(Utils:getLocalSettingValue("TongFightReadyView"..dialogId)) or 0
    if flag == 1 then
        return
    end

    Utils:setLocalSettingValue("TongFightReadyView"..dialogId,1)

    local function callback()
        KabalaTreeDataMgr:playStory(1,dialogId,function ()
            EventMgr:dispatchEvent(EV_CG_END,function()
            end)
        end)
    end
    KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)
end

function TongFightReadyView:openFubenSquad()

    local levelCid = self:getLevelCid()
    local levelCfg_ = FubenDataMgr:getLevelCfg(levelCid)
    if not levelCfg_ then
        return
    end

    local function func()
        local fubenType_ = FubenDataMgr:getFubenType(levelCid)
        local data = {
            type_ = self.vitDungonCfg.type,
            levelCid = levelCid
        }

        local challengeCnt = levelCfg_.isQuickBattle and self.challengeCount_ or 0
        Utils:openView("fuben.FubenSquadView", fubenType_ , data, challengeCnt)
        AlertManager:closeLayer(self)
    end
    self.Label_fighting_decs:setVisible(levelCfg_.dungeonType == EC_FBLevelType.TONG_FIGHT)

    if levelCfg_.dungeonType == EC_FBLevelType.TONG_DATING or
            levelCfg_.dungeonType == EC_FBLevelType.TONG_DATINGFIGHT then
        func()
    else
        local isOpen = ActivityDataMgr2:isInOpenTime(self.activityId)
        if not isOpen then
            local args = {
                tittle = 2107025,
                content = TextDataMgr:getText(13205113),
                reType = false,
                opacity = 255 * 0.45,
                confirmCall = function()
                    local layerName = {"TongMainView","TongFightReadyView"}
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
    end

end

function TongFightReadyView:onShow()
    self:removeLockLayer()
end

function TongFightReadyView:onHide()
    self.super.onHide(self)
    Utils:setLocalSettingValue("TongDiff",self.saveId)
end

function TongFightReadyView:onChallengeCountUpdateEvent(count)

    local levelCid = self:getLevelCid()
    local levelCfg_ = FubenDataMgr:getLevelCfg(levelCid)
    if not levelCfg_ then
        return
    end
    local cost = levelCfg_.cost[1]
    self.challengeCount_ = count
    self.Label_costNum:setText(cost[2] * count)

    self:updateFightMode()
end

function TongFightReadyView:onEnterDatingLevelEvent()
    AlertManager:closeLayer(self)
end

function TongFightReadyView:registerEvents()
    EventMgr:addEventListener(self, EV_FUBEN_UPDATE_CHALLENGE_COUNT, handler(self.onChallengeCountUpdateEvent, self))
    EventMgr:addEventListener(self, EV_FUBEN_PLOTLEVEL_BUY_COUNT, handler(self.onBuyCountEvent, self))
    EventMgr:addEventListener(self, EV_FUBEN_ENTER_DATING_LEVEL, handler(self.onEnterDatingLevelEvent, self))

    self.Button_close:onClick(function()
        AlertManager:closeLayer(self)
    end)

    self.Button_dating:onClick(function()
        if not self.vitDungonCfg then
            return
        end
        local levelCid = self:getLevelCid()
        if EC_PatongUiType.DatingFight == self.vitDungonCfg.type then
            self:openFubenSquad()
        elseif EC_PatongUiType.Dating == self.vitDungonCfg.type then
            FubenDataMgr:send_DUNGEON_FIGHT_START(levelCid)
            AlertManager:closeLayer(self)
        end
    end)

    self.Button_ready:onClick(function()
        self:openFubenSquad()
    end)

    self.Button_diff_select:onClick(function()
        local visible = self.Panel_diff:isVisible()
        self.Panel_diff:setVisible(not visible)
    end)

    for i, v in ipairs(self.Button_diff) do
        v.root:onClick(function()
            self:selectDiff(i)
            self.Panel_diff:hide()
        end)
    end

    self.Button_select:onClick(function()
        local levelCid = self:getLevelCid()
        local view = requireNew("lua.logic.fuben.FubenSelectCountView"):new(levelCid)
        AlertManager:addLayer(view, AlertManager.BLOCK_AND_GRAY_CLOSE)
        AlertManager:show()

    end)
end

---------------------------guide------------------------------

return TongFightReadyView

