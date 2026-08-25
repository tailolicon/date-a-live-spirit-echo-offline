
local TongMainView = class("TongMainView",BaseLayer)

function TongMainView:ctor(mapId,foucusId,guideClick)
    -- body
    self.super.ctor(self)

    self:initData(mapId,foucusId,guideClick)

    self:init("lua.uiconfig.tong.tongMainView")

end

function TongMainView:initData(mapId,foucusIds,guideClick)

    self.mapId = mapId
    self.foucusIds = foucusIds or {}

    self.guideClick = guideClick
    self.mapInfo_ = TongDataMgr:getMapCfg()
    self.hideTargetPosX = GameConfig.WS.width/2 - 10
    self.showTargetPosX = GameConfig.WS.width/2 - 360
    self.isStoryMode = true
    self.isPlayGuide = false
    self.activityId = ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.TONG)[1]
    local activityInfo = ActivityDataMgr2:getActivityInfo(self.activityId)
    dump(activityInfo)
    if activityInfo and activityInfo.extendData then
        self.eliteRefCost = activityInfo.extendData.eliteRefCost
        self.lastDunStage1 = activityInfo.extendData.lastDunStage1
        if activityInfo.extendData.isStoryMode ~= nil then
            self.isStoryMode = activityInfo.extendData.isStoryMode
        end
    end

    --self.isStoryMode = false
    self.disappearInfo = {}
    self.spawnTab = {}

    self.cache = {}                 ---地图上存在的精英关卡还未消失，精英点数达标而又生成精英关卡

    self.guideInfo = {}
    self.guideInfo[1] = {guideGroupId = 36, dialogScriptId = 25056}
    self.guideInfo[2] = {guideGroupId = 37, dialogScriptId = 25057}
    self.guideInfo[3] = {guideGroupId = 38, dialogScriptId = 25058}
    self.guideInfo[4] = {guideGroupId = 39, dialogScriptId = 25059}
    self.guideInfo[5] = {guideGroupId = 40, dialogScriptId = 25064}

    self.dialogScriptId = {25054,25065,25066}

    self.vitProgressCfg = TabDataMgr:getData("VITmaxProgress")

end

function TongMainView:getClosingStateParams()
    return {self.mapId, self.foucusIds}
end

function TongMainView:initUI( ui )
    -- body
    self.super.initUI(self,ui)
    self:showTopBar()

    self.Panel_ui               = TFDirector:getChildByPath(ui,"Panel_ui")
    self.map_scrollView         = TFDirector:getChildByPath(ui,"ScrollView_map")
    self.map_scrollView:setContentSize(GameConfig.WS)
    self.map_scrollView:setPositionX(-GameConfig.WS.width/2)

    self.Panel_mask             = TFDirector:getChildByPath(ui,"Panel_mask"):hide()
    self.panel_point            = TFDirector:getChildByPath(ui,"panel_point")

    self.Button_fight_info      = TFDirector:getChildByPath(ui,"Button_fight_info")
    self.Image_info_bg          = TFDirector:getChildByPath(ui,"Image_info_bg")
    self.Image_info_bg:setPositionX(GameConfig.WS.width/2-10)

    self.Button_airDrop         = TFDirector:getChildByPath(ui,"Button_airDrop")
    self.Button_airDrop:setPositionX(GameConfig.WS.width/2-100)

    self.Panel_type             = TFDirector:getChildByPath(ui,"Panel_type")
    self.Panel_type:setPositionX(GameConfig.WS.width/2-170)

    self.Label_ariDropRefresh   = TFDirector:getChildByPath(ui,"Label_ariDropRefresh")
    self.mapTypeBtn_ = {}
    for i=1,2 do
        local root = TFDirector:getChildByPath(ui,"Button_map"..i)
        local posX = root:getPositionX()
        local select = TFDirector:getChildByPath(root,"Image_select")
        local normal = TFDirector:getChildByPath(root,"Image_normal")
        self.mapTypeBtn_[i] = {btn = root,posX = posX, select = select, normal = normal}
    end

    self.Label_nextFreashTime   = TFDirector:getChildByPath(ui,"Label_nextFreashTime")
    self.Label_nextCount        = TFDirector:getChildByPath(ui,"Label_nextCount")
    self.Label_threat_level     = TFDirector:getChildByPath(ui,"Label_threat_level")
    self.Label_elitePoint       = TFDirector:getChildByPath(ui,"Label_elitePoint")
    self.Button_skill           = TFDirector:getChildByPath(ui,"Button_skill")
    self.Button_helpList        = TFDirector:getChildByPath(ui,"Button_helpList")
    self.Button_store           = TFDirector:getChildByPath(ui,"Button_store")
    self.Button_task            = TFDirector:getChildByPath(ui,"Button_task")
    self.Spine_supply           = TFDirector:getChildByPath(ui,"Spine_supply")
    self.Spine_elite            = TFDirector:getChildByPath(ui,"Spine_elite")
    self.Panel_mask:setContentSize(GameConfig.WS)

    self:initUILogic()

end

function TongMainView:onShow()
    self.super.onShow(self)
    TongDataMgr:Send_getBossInfo()
    self:playGuide()
end

function TongMainView:initUILogic()

    self:initMapInfo()
    self:updateBaseInfo()

end

function TongMainView:playGuide()
    if self.guideClick then
        if self.lastDunStage1 then
            local isPass = FubenDataMgr:isPassPlotLevel(self.lastDunStage1)
            self.mapTypeBtn_[2].btn:setVisible(isPass)
            local Id = isPass and 1 or 2
            local posX = self.mapTypeBtn_[Id].posX
            self.mapTypeBtn_[1].btn:setPositionX(posX)
        end

        local function callback()
            KabalaTreeDataMgr:playStory(1,self.dialogScriptId[1],function ()
                self.guideClick = false
                EventMgr:dispatchEvent(EV_CG_END)
            end)
        end
        KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)
        return
    end

    if self.isPlayGuide then
        if self.isStoryMode then
            if self.lastDunStage1 then
                local isPass = FubenDataMgr:isPassPlotLevel(self.lastDunStage1)
                self.mapTypeBtn_[2].btn:setVisible(isPass)
                local Id = isPass and 1 or 2
                local posX = self.mapTypeBtn_[Id].posX
                self.mapTypeBtn_[1].btn:setPositionX(posX)
                if isPass then
                    self:playDialog(1)
                end
            end
        else
            self.mapTypeBtn_[2].btn:setVisible(true)
            self.mapTypeBtn_[1].btn:setVisible(false)
        end
    else

        self.mapTypeBtn_[2].btn:setVisible(true)
        self.mapTypeBtn_[1].btn:setVisible(true)

        local dialogId = 25073
        local flag = tonumber(Utils:getLocalSettingValue("TongMainView"..dialogId)) or 0
        if flag == 1 then
            return true
        end

        local function callback()
            KabalaTreeDataMgr:playStory(1,dialogId,function ()
                Utils:setLocalSettingValue("TongMainView"..dialogId,1)
                EventMgr:dispatchEvent(EV_CG_END,function()
                end)
            end)
        end
        KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)
    end

end

function TongMainView:playDialog(guideIndex)

    local guide = self.guideInfo[guideIndex]
    if not guide then
        return
    end

    local isSave = GuideDataMgr:isSaveGuideGroup(guide.guideGroupId)
    if not isSave then
        local function callback()
            KabalaTreeDataMgr:playStory(1,guide.dialogScriptId,function ()
                EventMgr:dispatchEvent(EV_CG_END,function()

                    self:timeOut(function ()
                        self.checkGroupId = guide.guideGroupId
                        GameGuide:checkGuide(self)
                        guide.guideClick = true
                    end,0)

                end)
            end)
        end
        KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)
    end
end


function TongMainView:initMapInfo()

    self.cityNodes = {}
    if not self.cityMap then
        self.cityMap = createUIByLuaNew("lua.uiconfig.tong.tongMap")
        self.map_scrollView:addChild(self.cityMap)
        self.map_scrollView:setInnerContainerSize(CCSizeMake(self.cityMap:getSize()))
        self.Panel_tower = TFDirector:getChildByPath(self.cityMap,"Panel_tower")
        self.LoadingBar_boss = TFDirector:getChildByPath(self.Panel_tower,"LoadingBar_boss")
        self.Spine_point     = TFDirector:getChildByPath(self.Panel_tower,"Spine_point")
        self.Spine_point:playByIndex(1,-1,-1,1)
        self.Panel_point     = TFDirector:getChildByPath(self.Panel_tower,"Panel_point")
        self.panelMap_ = {}
        for mapId=1,2 do
            self.panelMap_[mapId] = TFDirector:getChildByPath(self.cityMap,"Panel_map_"..mapId)
            if not self.cityNodes[mapId] then
                self.cityNodes[mapId] = {}
            end
            for i, v in ipairs(self.panelMap_[mapId]:getChildren()) do
                v:setBackGroundColorType(0)
                v:setTouchEnabled(true)
                local name = v:getName()
                local prefix, id = string.match(name, "(.*)_(.*)")
                local index = tonumber(id)
                if index then

                    local mapItem = v:getChildByName("mapItem")
                    if not mapItem then
                        mapItem = self.panel_point:clone()
                        mapItem:setPosition(ccp(0,0))
                        mapItem:setName("mapItem")
                        v:addChild(mapItem)
                        self.cityNodes[mapId][index] = v
                    end
                end
            end
        end
    end
end

function TongMainView:updateMapItem(mapId,index,defaultData,animationCallBack,disapperAniCallBack,changeCallBack)

    if not self.cityNodes[mapId] then
        return
    end

    local item = self.cityNodes[mapId][index]
    if not item then
        return
    end

    local Image_normal      = TFDirector:getChildByPath(item,"Image_normal")
    local Image_monster     = TFDirector:getChildByPath(item,"Image_monster")
    local Image_airdrop     = TFDirector:getChildByPath(item,"Image_airdrop")
    local Image_normal_s    = TFDirector:getChildByPath(item,"Image_normal_s")
    local Label_tag         = TFDirector:getChildByPath(item,"Label_tag")
    local Label_tag_normal  = TFDirector:getChildByPath(item,"Label_tag_normal")
    local Spine_air         = Image_airdrop:getChildByName("Spine_air") --TFDirector:getChildByPath(Image_airdrop,"Spine_air")
    if not Spine_air then
        Spine_air = SkeletonAnimation:create("effect/eff_vitmax/VITmax_effect_level_supply")
        Spine_air:setAnimationFps(GameConfig.ANIM_FPS)
        Spine_air:setName("Spine_air")
        Image_airdrop:addChild(Spine_air)
    end

    local Spine_monster     = Image_monster:getChildByName("Spine_monster") --TFDirector:getChildByPath(item,"Spine_monster")
    if not Spine_monster then
        Spine_monster = SkeletonAnimation:create("effect/eff_vitmax/VITmax_effect_level_elite")
        Spine_monster:setAnimationFps(GameConfig.ANIM_FPS)
        Spine_monster:setName("Spine_monster")
        Spine_monster:setPosition(ccp(10,24))
        Image_monster:addChild(Spine_monster)
    end

    local Spine_dating      = Image_normal:getChildByName("Spine_dating") --TFDirector:getChildByPath(item,"Spine_dating")
    if not Spine_dating then
        Spine_dating = SkeletonAnimation:create("effect/eff_vitmax/VITmax_effect_level_story")
        Spine_dating:setAnimationFps(GameConfig.ANIM_FPS)
        Spine_dating:setName("Spine_dating")
        Image_normal:addChild(Spine_dating)
    end

    local Spine_fight       = Image_normal:getChildByName("Spine_fight") --TFDirector:getChildByPath(item,"Spine_fight")
    if not Spine_fight then
        Spine_fight = SkeletonAnimation:create("effect/eff_vitmax/VITmax_effect_level_storyBattle")
        Spine_fight:setAnimationFps(GameConfig.ANIM_FPS)
        Spine_fight:setName("Spine_fight")
        Image_normal:addChild(Spine_fight)
    end

    local Spine_mask        = item:getChildByName("Spine_mask") --TFDirector:getChildByPath(item,"Spine_mask")

    Spine_air:stop()
    Spine_monster:stop()
    Spine_dating:stop()
    Spine_fight:stop()
    Spine_mask:stop()
    Spine_mask:hide()

    local isOpen = ActivityDataMgr2:isInOpenTime(self.activityId)

    local dungonMgrId = defaultData.defaultDungeon
    if mapId == 2 and isOpen then
        local info = TongDataMgr:getMapExtrDot(index)
        if info then
            dungonMgrId = info.mgrId
        end
    end

    local vitDungonCfg = TongDataMgr:getVitDungonCfg(dungonMgrId)
    if not vitDungonCfg then
        return
    end


    local isMonster = vitDungonCfg.type == EC_PatongUiType.MonsterMode
    local isAirDrop = vitDungonCfg.type == EC_PatongUiType.AirDrop or vitDungonCfg.type == EC_PatongUiType.AirDropInterest


    Image_normal_s:setVisible(mapId == 2)
    Image_normal:setVisible(mapId == 1)

    Label_tag:setText(defaultData.tag)
    Label_tag_normal:setText(defaultData.tag)

    if mapId == 2 then

        if animationCallBack or disapperAniCallBack then

            if animationCallBack then
                Image_normal_s:setVisible(not isMonster and not isAirDrop)
            end

            if disapperAniCallBack then
                Image_monster:setVisible(isMonster)
                Image_airdrop:setVisible(isAirDrop)
            end

            Utils:playSound(8148, false)
            Spine_mask:show()
            Spine_mask:play("fort_disapear",false)
            Spine_mask:addMEListener(TFARMATURE_COMPLETE,function()
                Spine_mask:removeMEListener(TFARMATURE_COMPLETE)
                Spine_mask:hide()

                if animationCallBack then
                    Image_monster:setVisible(isMonster)
                    Image_airdrop:setVisible(isAirDrop)
                end

                if disapperAniCallBack then
                    Image_normal_s:setVisible(not isMonster and not isAirDrop)
                end

                if Image_airdrop:isVisible() then
                    Spine_air:playByIndex(0,-1,-1,1)
                end

                if Image_monster:isVisible() then
                    Spine_monster:playByIndex(2,-1,-1,1)
                end

                self:timeOut(function()

                    if animationCallBack then
                        animationCallBack()
                    end

                    if disapperAniCallBack then
                        disapperAniCallBack()
                    end

                end,0.1)
            end)
        else
            Image_normal_s:setVisible(not isMonster and not isAirDrop)
            Image_monster:setVisible(isMonster)
            Image_airdrop:setVisible(isAirDrop)

            if Image_airdrop:isVisible() then
                Spine_air:playByIndex(0,-1,-1,1)
            end

            if Image_monster:isVisible() then

                if  not changeCallBack then
                    local animationIndex = 2
                    local eliteInfo = TongDataMgr:getEliteInfo()
                    if eliteInfo and not self.mapId then                    --mapId不为空就是通过战斗后的缓存参数传入的
                        local state = eliteInfo.status
                        local isEnd = state == EC_EliteStatus.RETREAT or state == EC_EliteStatus.KILL or state == EC_EliteStatus.NOT_START_RETREAT
                        if isEnd then
                            animationIndex = 1
                        end
                    end
                    dump(eliteInfo,"animationIndex")
                    print("animationIndex",animationIndex,self.mapId)
                    Spine_monster:playByIndex(animationIndex,-1,-1,1)
                else
                    Spine_monster:stop()
                    Spine_monster:addMEListener(TFARMATURE_COMPLETE,function(event)
                        self:completeCallBack(event)
                    end)
                    self:playAction(Spine_monster,2)
                    self.changeCallBack = changeCallBack
                end

            end
        end
    end

    local canFigth = true
    if mapId == 1 then
        local dungeonInclude = vitDungonCfg.dungeonInclude
        local levelCid = dungeonInclude[1]
        canFigth = FubenDataMgr:checkPlotLevelEnabled(levelCid)
        local isPass = FubenDataMgr:isPassPlotLevel(levelCid)

        if canFigth and not isPass then

            if EC_PatongUiType.Dating == vitDungonCfg.type then
                Spine_dating:playByIndex(0,-1,-1,1)
            end

            if EC_PatongUiType.DatingFight == vitDungonCfg.type then
                Spine_fight:playByIndex(0,-1,-1,1)
            end
        end

        local Image_dating = Image_normal:getChildByName("Image_dating")
        local Image_fight  = Image_normal:getChildByName("Image_fight")

        Image_dating:setVisible(isPass and EC_PatongUiType.Dating == vitDungonCfg.type)
        Image_fight:setVisible(isPass and EC_PatongUiType.DatingFight == vitDungonCfg.type)

    end

    local showItem = true

    local isPass = defaultData.showByPreDun == 0 and true or FubenDataMgr:isPassPlotLevel(defaultData.showByPreDun)

    showItem = isPass

    if mapId == 2 then
        local bossStage = TongDataMgr:getBossStage()
        showItem = isPass and bossStage >= defaultData.stage
    end

    print(mapId,index,showItem,canFigth)
    item:setVisible(showItem and canFigth)

    --isOpen

    if EC_PatongUiType.Dating == vitDungonCfg.type or EC_PatongUiType.DatingFight == vitDungonCfg.type then
    else
        item:setGrayEnabled(not isOpen)
    end
end

function TongMainView:playAction(Spine_monster,index,isloop)
    self.spineIndex = index
    local l = isloop and 1 or 0
    Spine_monster:playByIndex(index,-1,-1,l)
end

function TongMainView:completeCallBack(skeletonNode)
    if self.spineIndex == 2 then
        Utils:playSound(8151, false)
        self:timeOut(function()
            self:playAction(skeletonNode,0)
        end,0)
    elseif self.spineIndex == 0 then
        skeletonNode:removeMEListener(TFARMATURE_COMPLETE)
        self:timeOut(function()
            self:playAction(skeletonNode,1,true)
            self.Panel_mask:hide()
            if self.changeCallBack then
                self.changeCallBack()
            end
        end,0)
    end
end

function TongMainView:updateBaseInfo()
    self:updateInfo()
    self:updateMap()
    self:updateBossPercent()
end

function TongMainView:updateBossPercent()

    local bossInfo = TongDataMgr:getWorldBossInfo()
    if not bossInfo then
        return
    end

    dump(bossInfo)
    local progress = bossInfo.progress
    local maxPro = self.vitProgressCfg[#self.vitProgressCfg].progress
    local curProgress       = math.max(maxPro - progress,0)
    local percent           = math.floor(curProgress/maxPro*100)
    self.LoadingBar_boss:setPercent(percent)

    local pos = self:getBarEffectPos(percent)
    self.Panel_point:setPosition(pos)

end

function TongMainView:getBarEffectPos(percent)

    local r = 48
    local m = 360 * (100 - percent)/100
    local radians =math.rad(m)

    print("radians",radians,m)
    local pos = ccp(r * math.sin(radians),r * math.cos(radians))
    dump(pos)
    return pos
end

function TongMainView:updateInfo()


    local nextFreshTime,nextCnt = TongDataMgr:getNextAirDropInfo()
    if not nextFreshTime or not nextCnt then
        return
    end

    self.Label_nextFreashTime:stopAllActions()
    local isOpen = ActivityDataMgr2:isInOpenTime(self.activityId)
    if isOpen then
        local act = CCSequence:create({
            CCCallFunc:create(function()
                local remainTime = nextFreshTime - ServerDataMgr:getServerTime()
                remainTime = math.max(remainTime,0)
                if remainTime <= 0 then
                    self.Label_ariDropRefresh:setTextById(13206052)
                    self.Button_airDrop:setTextureNormal("ui/tong/map/info/009.png")
                    self.Label_nextFreashTime:stopAllActions()
                else
                    self.Label_ariDropRefresh:setTextById(13206053)
                    self.Button_airDrop:setTextureNormal("ui/tong/map/info/008.png")
                end
                local day, hour, min, sec = Utils:getDHMS(remainTime, true)
                local str = TextDataMgr:getText(13202001)
                self.Label_nextFreashTime:setText(str..hour..":"..min..":"..sec)
            end),
            CCDelayTime:create(1)
        })

        self.Label_nextFreashTime:runAction(CCRepeatForever:create(act))
    else
        local str = TextDataMgr:getText(13202001)
        local str1 = TextDataMgr:getText(13200922)
        self.Label_nextFreashTime:setText(str..str1)
    end

    self.Label_nextCount:setTextById(13206054,nextCnt)
    local threatLv = TongDataMgr:getCurThreatLv()
    self.Label_threat_level:setTextById(13206055,threatLv)

    local itemId,maxCnt
    for k,v in pairs(self.eliteRefCost or {}) do
        itemId,maxCnt = k,v
    end

    if itemId and maxCnt then
        local ownCnt = GoodsDataMgr:getItemCount(itemId)
        self.Label_elitePoint:setTextById(13206056,ownCnt.."/"..maxCnt)
    end
end

function TongMainView:focusMap(mapId,index,isDelay,callBack)

    local cityNode = index
    if type(index) == "number" then
        if not self.cityNodes[mapId] then
            return
        end
        cityNode = self.cityNodes[mapId][index]
        if not cityNode then
            return
        end
        self.foucusIds[mapId] = index
    end

    local position = cityNode:Pos()

    local innerContainer = self.map_scrollView:getInnerContainer()
    innerContainer:stopAllActions()
    local innerSize = innerContainer:getSize()
    local offset = self.map_scrollView:getContentOffset()
    local posX = -(position.x - GameConfig.WS.width  / 2)
    local posY = -(position.y - 640 / 2)
    local maxX = 0
    local maxY = 0
    local minX = 1136 - innerSize.width
    local minY = 640 - innerSize.height
    posX = posX > maxX and maxX or posX
    posX = posX < minX and minX or posX
    posY = posY > maxY and maxY or posY
    posY = posY < minY and minY or posY
    local distancX = math.abs(posX - offset.x)
    local distancY = math.abs(posY - offset.y)
    local distance = math.max(distancX, distancY)
    local time = distance / 1000
    time = isDelay and time or 0

    self.Panel_mask:setVisible(time ~= 0)
    if type(index) ~= "number" then
        print("11111111111111111111111",time,posX,posY)
    end
    if isDelay then
        self.Panel_ui:stopAllActions()
        local s = CCSequence:create({
            CCDelayTime:create(time),
            CCCallFunc:create(function()
                self.Panel_mask:hide()
                if callBack then
                    callBack()
                end
            end)
        })
        self.Panel_ui:runAction(s)
    end
    self.map_scrollView:setContentOffset(ccp(posX,posY), time)
end

function TongMainView:chooseMap(mapId)

    self.mapId = mapId

    for i=1,2 do
        self.panelMap_[i]:setVisible(mapId == i)
        self.mapTypeBtn_[i].select:setVisible(mapId == i)
    end

    self.Button_airDrop:setVisible(self.mapId == 2)
    self.Button_fight_info:setVisible(self.mapId == 2)

    local id = self:getFocusId()
    if self.mapId == 2 and self.foucusIds[mapId]  then
        id = self.foucusIds[mapId]
    end
    self:focusMap(mapId,id,false)

    if mapId == 2 then
        self:timeOut(function()
            self:playDialog(2)
        end,0.1)
    elseif mapId == 1 then

        local isPlayed2 = self:isPlayedStageDialog(2)
        if not isPlayed2 then
            local isCould = self:couldPlayStage(2)
            if isCould then
                self:timeOut(function()
                    self:playStageOpenDialog(2)
                end,0)
            end
        else
            local isPlayed3 = self:isPlayedStageDialog(3)
            if not isPlayed3 then
                local isCould = self:couldPlayStage(3)
                if isCould then
                    self:timeOut(function()
                        self:playStageOpenDialog(3)
                    end,0)
                end
            end
        end
    end
end

function TongMainView:isPlayedStageDialog(stage)
    local dialogId = self.dialogScriptId[stage]
    local flag = tonumber(Utils:getLocalSettingValue("TongMainView"..dialogId)) or 0
    if flag == 1 then
        return true
    end

    return false
end

function TongMainView:playStageOpenDialog(stage)

    local dialogId = self.dialogScriptId[stage]
    local flag = tonumber(Utils:getLocalSettingValue("TongMainView"..dialogId)) or 0
    if flag == 1 then
        return
    end

    local function callback()
        KabalaTreeDataMgr:playStory(1,dialogId,function ()
            Utils:setLocalSettingValue("TongMainView"..dialogId,1)
            EventMgr:dispatchEvent(EV_CG_END,function()
            end)
        end)
    end
    KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)
end

function TongMainView:getFocusId()


    if self.mapId == 1 then
        local lastFousId = self.foucusIds[self.mapId]
        local foucusId = 1
        local info = self.mapInfo_[1]
        for k,v in ipairs(info) do
            local dungonMgrId = v.defaultDungeon
            local vitDungonCfg = TongDataMgr:getVitDungonCfg(dungonMgrId)
            if not vitDungonCfg then
                return
            end
            local dungeonInclude = vitDungonCfg.dungeonInclude
            local levelCid = dungeonInclude[1]
            local canFigth = FubenDataMgr:isPassPlotLevel(levelCid)
            if canFigth then
                foucusId = k
            end
        end
        foucusId = math.min(foucusId+1,#info)

        if lastFousId and lastFousId < foucusId - 1 then
            foucusId = lastFousId
        end

        return foucusId

    else
        local foucusId = self.Panel_tower
        local info = self.mapInfo_[2]
        if info then
            for k,v in ipairs(info) do
                local extrDotInfo = TongDataMgr:getMapExtrDot(k)
                if extrDotInfo then
                    foucusId = k
                    break
                end
            end
        end

        return foucusId
    end
end

function TongMainView:showOrhideFightInfo(visible)

    if self.move then
        return
    end
    self.move = true
    self.Image_info_bg:stopAllActions()
    local posX = visible and self.showTargetPosX or self.hideTargetPosX
    local act = CCSequence:create({
        CCMoveTo:create(0.6, ccp(posX,-53)),
        CallFunc:create(function()
            self.move = false
        end)
    })
    self.Image_info_bg:runAction(act)
end

function TongMainView:onHide()
    self.super.onHide(self)
end

function TongMainView:onExit()
    self.super.onExit(self)
end

function TongMainView:removeEvents( ... )
    self.super.removeEvents(self)
end

function TongMainView:openFightReady(mapId,index)

    local isOpen = ActivityDataMgr2:isInOpenTime(self.activityId)

    local info = self.mapInfo_[mapId][index]
    if not info then
        return
    end

    local endTime
    local dungonMgrId = info.defaultDungeon
    if mapId == 2 then
        local info = TongDataMgr:getMapExtrDot(index)
        if info then
            dungonMgrId = info.mgrId
            endTime = info.endTime
        end
    end

    local vitDungonCfg = TongDataMgr:getVitDungonCfg(dungonMgrId)
    if not vitDungonCfg then
        return
    end

    if EC_PatongUiType.Dating == vitDungonCfg.type or EC_PatongUiType.DatingFight == vitDungonCfg.type then
    else
        if not isOpen then
            Utils:showTips(13200922)
            return
        end
    end


    self.dungonMgrId = dungonMgrId


    if mapId == 1 then
        local dungeonInclude = vitDungonCfg.dungeonInclude
        local levelCid = dungeonInclude[1]
        local canFigth = FubenDataMgr:checkPlotLevelEnabled(levelCid)
        if not canFigth then
            Utils:showTips(13206057)
            return
        end
    end


    self.foucusIds[mapId] = index

    local isMonster = vitDungonCfg.type == EC_PatongUiType.MonsterMode
    if isMonster then
        Utils:openView("tong.TongMonsterView",dungonMgrId)
    else
        Utils:openView("tong.TongFightReadyView",dungonMgrId,endTime)
    end
end

function TongMainView:updateMap()

    for mapId,dots in ipairs(self.mapInfo_) do
        for k,v in ipairs(dots) do
            self:updateMapItem(mapId,k,v)
        end
    end

    self:updateInfo()

    if not self.mapId then
        local isCouldStage2 = self:couldPlayStage(2)
        local isCouldStage3 = self:couldPlayStage(3)
        if isCouldStage2 or isCouldStage3 then
            self.mapId = 1
        end
    end

    local jumpMapId = self.mapId
    if not jumpMapId then
        if self.isStoryMode then
            jumpMapId = self:couldFight() and 1 or 2
        else
            jumpMapId = 2
        end
    end

    self:chooseMap(jumpMapId)

    local state = TongDataMgr:getFightMonsterState()
    if state then
        self:timeOut(function()
            self:afterFightMonster()
        end,0.1)
    end

    local isOpen = ActivityDataMgr2:isInOpenTime(self.activityId)
    --self.Button_airDrop:setVisible(isOpen)
end

function TongMainView:couldFight()

    local exist = false
    local stage = TongDataMgr:getBossStage()
    for i=1,stage do
        local first,last = TongDataMgr:getDungeonCidByStage(stage)
        local isPass = FubenDataMgr:isPassPlotLevel(last)
        if not isPass then
            exist = true
            break
        end
    end

    return exist
end

function TongMainView:couldPlayStage(stage)

    local beforeFirst,beforeLast = TongDataMgr:getDungeonCidByStage(stage-1)
    local curFirst,curLast = TongDataMgr:getDungeonCidByStage(stage)

    local curFirstPass = FubenDataMgr:isPassPlotLevel(curFirst)
    local beforeLastPass = FubenDataMgr:isPassPlotLevel(beforeLast)

    local bosStage = TongDataMgr:getBossStage()
    if bosStage >= stage and beforeLastPass and (not curFirstPass) then
        return true
    end

    return false
end

function TongMainView:afterRetreat(dungonMgrId)
    local layerName = {"TongRetreatConfirmView","TongMonsterView"}
    for k,v in ipairs(layerName) do
        local isLayerInQueue,layer = AlertManager:isLayerInQueue(v)
        if isLayerInQueue then
            AlertManager:closeLayer(layer)
        end
    end

    TongDataMgr:Send_GetMonsterInfo()

    local eliteInfo = TongDataMgr:isExistSpecialDot(EC_PatongUiType.MonsterMode)
    dump(eliteInfo,"afterRetreat")
    if eliteInfo then
        local mapCfg = TongDataMgr:getVitMaxMapCfg(eliteInfo.cid)
        self.Panel_mask:show()
        self:updateMapItem(2,mapCfg.posId,mapCfg,nil,nil,function()
            self:openMonsterView(dungonMgrId)
        end)
    end
end

function TongMainView:RefreshAirItem(ct,tab)

    self:updateInfo()

    if ct == EC_SChangeType.DELETE then
        self:updateMap()
    else

        local function callfunc()
            self.spawnTab = tab
            local function callback()
                self:playDialog(3)
            end
            self:spawnItem(callback)
        end

        if ct == EC_SChangeType.ADD then
            Utils:playSound(8149, false)
            self.Spine_supply:playByIndex(0,-1,-1,0)
            self.Spine_supply:addMEListener(TFARMATURE_COMPLETE,function()
                self.Spine_supply:removeMEListener(TFARMATURE_COMPLETE)
                callfunc()
            end)
        else
            callfunc()
        end
    end
end

function TongMainView:spawnItem(callback)

    if #self.spawnTab == 0 then
        if callback then
            callback()
        end
        return
    end

    local itemInfo = table.remove(self.spawnTab,1)
    local mapCfg = TongDataMgr:getVitMaxMapCfg(itemInfo.cid)
    if not mapCfg then
        self:spawnItem(callback)
    else
        local function callBack()

            local function animationCallBack()
                self:spawnItem(callback)
            end
            self.Panel_ui:stopAllActions()
            local mapInfo = TongDataMgr:getMapCfg(2)[mapCfg.posId]
            self:updateMapItem(2,mapCfg.posId,mapInfo,animationCallBack)

        end
        self:focusMap(2,mapCfg.posId,true,callBack)
    end
end

function TongMainView:disappearItem()

    if #self.disappearInfo == 0 then
        self.isDisappearing = false
        return
    end

    local itemInfo = table.remove(self.disappearInfo,1)
    local mapCfg = TongDataMgr:getVitMaxMapCfg(itemInfo.cid)
    if not mapCfg then
        self.isDisappearing = false
        return
    end

    local function callBack()
        local function disapperAniCallBack()
            self.isDisappearing = false

            local cacheData = table.remove(self.cache,1)
            if cacheData then
                self:RefreshEliteItem(cacheData.ct,cacheData.tab)
            else
                local function callBack()
                    self:playDialog(5)
                end
                self:focusMap(2,self.Panel_tower,true,callBack)
            end
        end
        self.Panel_ui:stopAllActions()
        local mapInfo = TongDataMgr:getMapCfg(2)[mapCfg.posId]
        self:updateMapItem(2,mapCfg.posId,mapInfo,nil,disapperAniCallBack)

    end
    self:focusMap(2,mapCfg.posId,true,callBack)

end



function TongMainView:RefreshEliteItem(ct,tab)

    if self.isDisappearing then
        table.insert(self.cache,{ct = ct, tab = tab})
        return
    end

    self.disappearInfo = {}
    self.spawnTab = {}
    if ct == EC_SChangeType.DELETE then
        table.insert(self.disappearInfo,tab)
    else

        local function callfunc()
            TongDataMgr:Send_GetMonsterInfo()
            table.insert(self.spawnTab,tab)
            local function callBack()
                self:playDialog(4)
            end
            self:spawnItem(callBack)
        end

        Utils:playSound(8150, false)
        self.Spine_elite:playByIndex(0,-1,-1,0)
        self.Spine_elite:addMEListener(TFARMATURE_COMPLETE,function()
            self.Spine_elite:removeMEListener(TFARMATURE_COMPLETE)
            callfunc()
        end)
    end

    dump(self.disappearInfo)
end

function TongMainView:finishElite(reward)

    self.isDisappearing = true

    local function hideCallBack()
        self:disappearItem()
    end

    if #reward > 0 then
        Utils:showReward(reward,nil,hideCallBack)
    else
        self:disappearItem()
    end
end

function TongMainView:excuteGuideFunc905001(guideFuncId)

    if self.mapId ~= 2 then
        return
    end

    local airDropIndex
    local dots = self.mapInfo_[2] or {}
    for k,v in ipairs(dots) do
        local info = TongDataMgr:getMapExtrDot(k)
        if info then
            local vitDungonCfg = TongDataMgr:getVitDungonCfg(info.mgrId)
            if vitDungonCfg and (vitDungonCfg.type == EC_PatongUiType.AirDrop or vitDungonCfg.type == EC_PatongUiType.AirDropInterest) then
                airDropIndex = k
                break
            end
        end
    end

    if not airDropIndex then
        return
    end

    local cityNodes = self.cityNodes[2]
    if not cityNodes then
        return
    end

    local targetNode = cityNodes[airDropIndex]
    if not targetNode then
        return
    end

    self.guideFuncId = guideFuncId

    local function callBack()
        GameGuide:guideTargetNode(targetNode)
    end
    self:focusMap(2,airDropIndex,true,callBack)
end

function TongMainView:getIndexByType(tab)
    local foucusId = 1
    local info = self.mapInfo_[2]
    if info then
        for k,v in ipairs(info) do
            local extrDotInfo = TongDataMgr:getMapExtrDot(k)
            if extrDotInfo then
                local vitDungonCfg = TongDataMgr:getVitDungonCfg(extrDotInfo.mgrId)
                if vitDungonCfg then
                    local index = table.indexOf(tab,vitDungonCfg.type)
                    if index ~= -1 then
                        foucusId = k
                        break
                    end
                end
            end
        end
    end
    return foucusId
end


function TongMainView:excuteGuideFunc905001(guideFuncId)

    if self.mapId ~= 2 then
        return
    end

    local airDropIndex = self:getIndexByType({21,22})
    if not airDropIndex then
        return
    end

    local cityNodes = self.cityNodes[2]
    if not cityNodes then
        return
    end

    local targetNode = cityNodes[airDropIndex]
    if not targetNode then
        return
    end

    self.guideFuncId = guideFuncId

    local function callBack()
        GameGuide:guideTargetNode(targetNode)
    end
    self:focusMap(2,airDropIndex,true,callBack)
end

function TongMainView:excuteGuideFunc905002(guideFuncId)

    if self.mapId ~= 2 then
        return
    end

    local airDropIndex = self:getIndexByType({31})
    if not airDropIndex then
        return
    end

    local cityNodes = self.cityNodes[2]
    if not cityNodes then
        return
    end

    local targetNode = cityNodes[airDropIndex]
    if not targetNode then
        return
    end

    self.guideFuncId = guideFuncId

    local function callBack()
        GameGuide:guideTargetNode(targetNode)
    end
    self:focusMap(2,airDropIndex,true,callBack)
end

function TongMainView:onScrolling()
    self:showOrhideFightInfo(false)
end

function TongMainView:afterFightMonster()

    local playChange = false
    local eliteInfo = TongDataMgr:getEliteInfo()
    if eliteInfo then
        local state = eliteInfo.status
        local isEnd = state == EC_EliteStatus.RETREAT or state == EC_EliteStatus.KILL or state == EC_EliteStatus.NOT_START_RETREAT
        if isEnd then
            playChange = true
        end
    end

    local eliteDotInfo = TongDataMgr:isExistSpecialDot(EC_PatongUiType.MonsterMode)
    if not eliteDotInfo then
        return
    end

    local dungonMgrId = eliteDotInfo.mgrId

    if playChange then
        local mapCfg = TongDataMgr:getVitMaxMapCfg(eliteDotInfo.cid)
        self.Panel_mask:show()
        self:updateMapItem(2,mapCfg.posId,mapCfg,nil,nil,function()
            self:openMonsterView(dungonMgrId)
        end)
    else
        self:timeOut(function()
            self:openMonsterView(dungonMgrId)
        end,0)
    end

end

function TongMainView:monserTimeOut()

    local eliteDotInfo = TongDataMgr:isExistSpecialDot(EC_PatongUiType.MonsterMode)
    if not eliteDotInfo then
        return
    end

    local dungonMgrId = eliteDotInfo.mgrId

    local mapCfg = TongDataMgr:getVitMaxMapCfg(eliteDotInfo.cid)
    self.Panel_mask:show()
    self:updateMapItem(2,mapCfg.posId,mapCfg,nil,nil,function()
        self:openMonsterView(dungonMgrId)
    end)
end

function TongMainView:openMonsterView(dungonMgrId)
    local isOpen = ActivityDataMgr2:isInOpenTime(self.activityId)
    if isOpen then
        Utils:openView("tong.TongMonsterView",dungonMgrId)
    end
end

function TongMainView:onReconect()
    self.mapId = nil
end

function TongMainView:registerEvents(  )
    self.super.registerEvents(self)

    EventMgr:addEventListener(self, EV_BAG_ITEM_UPDATE, handler(self.updateInfo, self))
    EventMgr:addEventListener(self, EV_RECONECT_EVENT, handler(self.onReconect, self))

    EventMgr:addEventListener(self, EV_TONG.FinishElite, handler(self.finishElite, self))
    EventMgr:addEventListener(self, EV_TONG.UpdateElite, handler(self.RefreshEliteItem, self))
    EventMgr:addEventListener(self, EV_TONG.UpdateAir, handler(self.RefreshAirItem, self))
    EventMgr:addEventListener(self, EV_TONG.BaseInfo, handler(self.updateBaseInfo, self))
    EventMgr:addEventListener(self, EV_TONG.Retreat, handler(self.afterRetreat, self))
    EventMgr:addEventListener(self, EV_BATTLE_FIGHTOVER, handler(self.updateMap, self))

    EventMgr:addEventListener(self, EV_TONG.MonsterTimeOut, handler(self.monserTimeOut, self))

    self.map_scrollView:addMEListener(TFSCROLLVIEW_SCROLLING, handler(self.onScrolling, self))

    --EventMgr:addEventListener(self, EV_ACTIVITY_UPDATE_ACTIVITY, handler(self.updateActivity, self))

    for k,v in ipairs(self.mapTypeBtn_) do
        v.btn:onClick(function()
            self:showOrhideFightInfo(false)
            if self.mapId == k then
                return
            end
            self:chooseMap(k)
        end)
    end

    self.Button_fight_info:onClick(function()
        self:showOrhideFightInfo(true)
    end)

    self.Panel_tower:onClick(function()
        Utils:openView("tong.TongBossView")
    end)

    for mapId,items in ipairs(self.cityNodes) do
        for index,item in ipairs(items) do
            item:onClick(function()
                GameGuide:checkGuideEnd(self.guideFuncId)
                self:openFightReady(mapId,index)
            end)
        end
    end

    self.Button_airDrop:onClick(function ()
        TongDataMgr:Send_refreshAirDrop()
    end)

    self.Button_skill:onClick(function()
        Utils:openView("tong.TongStudyMainView")
    end)

    self.Button_helpList:onClick(function()
        Utils:openView("tong.TongHelpListView")
    end)
end

return TongMainView