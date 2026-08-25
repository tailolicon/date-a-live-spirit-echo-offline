
local BaseDataMgr = import(".BaseDataMgr")
local TongDataMgr = class("TongDataMgr", BaseDataMgr)

function TongDataMgr:init()

    self:registerMsgEvent()
    self.vitSkillCfg            = TabDataMgr:getData("VITmaxSkill")
    self.vITmaxAttribute        = TabDataMgr:getData("VITmaxAttribute")
    self.vitAffixCfg            = TabDataMgr:getData("VITmaxAffix")
    self.vitmaxAffixGroup       = TabDataMgr:getData("VITmaxAffixGroup")
    self.vitMaxMapCfg           = TabDataMgr:getData("VITmaxMap")
    self.vitmaxDungeonMgrCfg    = TabDataMgr:getData("VITmaxDungeonMgr")
    self.vitmaxStageCfg         = TabDataMgr:getData("VITmaxStage")

    self.vitmaxThreatCfg        = TabDataMgr:getData("VITmaxEIPointThreat")
    self.combatBuffMgrCfg       = TabDataMgr:getData("OfflineBuffMgr")

    self.mapInfo_ = {}
    self.VITmaxMapCfg = TabDataMgr:getData("VITmaxMap")
    for k,v in ipairs( self.VITmaxMapCfg) do
        local mapId = v.map
        local posId = v.posId
        if mapId > 0 then
            if not self.mapInfo_[mapId] then
                self.mapInfo_[mapId] = {}
            end
            self.mapInfo_[mapId][posId] = v
        end
    end
end

function TongDataMgr:registerMsgEvent()

    TFDirector:addProto(s2c.FEAR_PAIN_RES_FEAR_PAIN_FIGHT_INFO, self, self.onRecvBaseInfo)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_ELITE_INFO, self, self.onRecvMonsterInfo)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_ELITE_RETREAT, self, self.onRecvAfterRetreat)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_ELITE_HELP, self, self.onRecvAskHelp)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_HELP_OTHER, self, self.onRecvHelpOther)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_HELP_INFO, self, self.onRecvHelpInfo)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_BUY_COUNT, self, self.onRecvBuyCount)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_REFRESH_AIR, self, self.onRecvRefreshAir)

    TFDirector:addProto(s2c.FEAR_PAIN_RES_WORLD_BOSS, self, self.onRecvWorldBossInfo)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_FIGHT_REPORT, self, self.onRecvFightReport)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_FEAR_PAIN_RANK, self, self.onRecvRankInfo)

    TFDirector:addProto(s2c.FEAR_PAIN_RES_FINISH_ELITE, self, self.onRecvGetMonserReward)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_CHOOSE_AFFIX, self, self.onRecvChooseAffix)

    TFDirector:addProto(s2c.FEAR_PAIN_RES_SKILL_INFO, self, self.onRecvStudyInfo)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_DISTRIBUTE, self, self.onRecvStudyAttrInfo)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_EQUIP_SKILL, self, self.onRecvEquipSkill)
    TFDirector:addProto(s2c.FEAR_PAIN_UNLOCK_SKILL_NOTICE, self, self.onRecvUnLockNotice)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_RESET_ATTR, self, self.onRecvResetAttr)

    TFDirector:addProto(s2c.FEAR_PAIN_RES_TAKE_PROGRESS_REWARD, self, self.onRecvGetBossReward)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_REFRESH_ELITE, self, self.onRecvRefreshElite)

    TFDirector:addProto(s2c.FEAR_PAIN_HELP_BUFF_NOTICE, self, self.onRecvHelpBuffNotice)
    TFDirector:addProto(s2c.FEAR_PAIN_RES_EFFECT_PLAYED, self, self.onRecvIsPlayEffect)


end

function TongDataMgr:onLogin()
    self:Send_getBaseInfo()
    return {s2c.FEAR_PAIN_RES_FEAR_PAIN_FIGHT_INFO}
end

function TongDataMgr:reset()

    self.equipedBuffer = {}
    self.attrInfo = {}
    self.leftHelpCnt = 0
    self.report = {}
    self.rankData = {}
    self.fearRankData = {}
    self.bossRewardStage = {}
    self.extrMapDot = {}
    self.threatLv = 0
    self.threatExp = 0
    self.helpList = {}
    self.unLockSkill = {}
    self.myRankInfo = {}
    self.examineRank = {}
    self.examineMyRank = {}
    self.eliteRecord = {}
end

function TongDataMgr:initData()

end

function TongDataMgr:getMapCfg(mapId)
    if not mapId then
        return self.mapInfo_
    end
    return self.mapInfo_[mapId]
end

---只针对地图1
function TongDataMgr:getMapCfgByBossStage(stage)

    local map1Cfg = self:getMapCfg(1)
    if not map1Cfg then
        return
    end

    local stageCfg = {}
    for k,v in ipairs(map1Cfg) do
        if v.stage == stage then
            table.insert(stageCfg,v)
        end
    end
    return stageCfg
end

function TongDataMgr:getDungeonCidByStage(stage)

    local stageCfg = self:getMapCfgByBossStage(stage)
    if not stageCfg then
        return
    end

    local first = self:getDungeonCid(stageCfg[1].defaultDungeon)
    local last  = self:getDungeonCid(stageCfg[#stageCfg].defaultDungeon)
    return first,last
end


function TongDataMgr:getDungeonCid(dungonMgrId)
    local vitDungonCfg = self:getVitDungonCfg(dungonMgrId)
    if not vitDungonCfg then
        return
    end
    return vitDungonCfg.dungeonInclude[1]
end

function TongDataMgr:getVitMaxMapCfg(cid)
    return self.VITmaxMapCfg[cid]
end


function TongDataMgr:getVitDungonCfg(id)
    return self.vitmaxDungeonMgrCfg[id]
end

function TongDataMgr:getAffixCfg(id)

    if not id then
        return self.vitAffixCfg
    end
    return self.vitAffixCfg[id]
end

function TongDataMgr:getCombatMgrCfg(id)
    return self.combatBuffMgrCfg[id]
end

function TongDataMgr:getVitStageCfg(stage)
    return self.vitmaxStageCfg[stage]
end

function TongDataMgr:getMaxThreatLv()
    for k,v in ipairs(self.vitmaxThreatCfg) do
        if v.isLevelMax then
            return v.threatLevel
        end
    end
end

function TongDataMgr:getThreatCfgByLv(lv)

    for k,v in ipairs(self.vitmaxThreatCfg) do
        if v.threatLevel == lv then
            return v
        end
    end
end

function TongDataMgr:getSkillCfgById(buffCid)

    return self.vitSkillCfg[buffCid]
end

function TongDataMgr:getEquipedBufferCid(slotId)
    return self.equipedBuffer[slotId] or 0
end

function TongDataMgr:isEquip(buffCid)

    for k,v in pairs(self.equipedBuffer) do
        if v == buffCid then
            return true
        end
    end

    return false
end

function TongDataMgr:isUnLockSkill(buffCid)
    local index = table.indexOf(self.unLockSkill,buffCid)
    return index ~= -1
end

function TongDataMgr:getAttrNum(attr)
    return self.attrInfo[attr] or 0
end

function TongDataMgr:getAttrPoint()
    return self.attrPointNum or 0
end

function TongDataMgr:getLeftHelpCnt()
    return self.leftHelpCnt or 0
end

function TongDataMgr:isSelfActiveAffix(id)

    if not self.eliteInfo then
        return false
    end

    local fearlessAffix = self.eliteInfo.fearlessAffix or {}
    local index = table.indexOf(fearlessAffix, id)
    return index ~= -1
end

function TongDataMgr:isActiveAffix(id)

    if not self.eliteInfo then
        return false
    end

    local affix = self.eliteInfo.affix or {}
    local index = table.indexOf(affix, id)
    return index ~= -1
end


function TongDataMgr:getReportList(index)

    if not index then
        return self.report
    end

    return self.report[index]
end

function TongDataMgr:getRankData(rankType,page)

    if not self.rankData[rankType] then
        return
    end
    return self.rankData[rankType][page]
end

function TongDataMgr:removeRankData(rankType,page)

    if not self.rankData[rankType] then
        return
    end
    self.rankData[rankType][page] = nil
end

function TongDataMgr:clearRankDataByType(rankType)
    self.rankData[rankType] = nil
end

function TongDataMgr:clearMyRankByType(rankType)
    self.myRankInfo[rankType] = nil
end

function TongDataMgr:clearRankData()
    self.rankData = {}
    self.myRankInfo = {}
end

function TongDataMgr:getMyRankInfo(rankType)
    return self.myRankInfo[rankType]
end

function TongDataMgr:isExamineRank(rankType)
    return self.examineRank[rankType]
end

function TongDataMgr:isExamineMyRank(rankType)
    return self.examineMyRank[rankType]
end

function TongDataMgr:isGetBossAward(id)
    return self.bossRewardStage[id] == 1
end

function TongDataMgr:getBossStage()

    local bossInfo = self:getWorldBossInfo()
    if not bossInfo then
        return 1
    end

    local stageId = bossInfo.stageId
    return stageId
end

function TongDataMgr:getEliteBuff()

    local eliteInfo = self:getEliteInfo()
    if not eliteInfo then
        return {}
    end

    local buff = {}
    local affix = eliteInfo.affix or {}
    local fearlessAffix = eliteInfo.fearlessAffix or {}

    table.insertTo(buff,affix)
    table.insertTo(buff,fearlessAffix)

    return buff
end

function TongDataMgr:getTongEliteBuff()

    local buffMgrIds = {}
    local buff = self:getEliteBuff()
    for k,v in ipairs(buff) do
        local cfg = self.vitAffixCfg[v]
        if cfg then
            table.insertTo(buffMgrIds,cfg.buffGroup)
        end
    end

    if self.monsterHelpBuff then
        table.insert(buffMgrIds,self.monsterHelpBuff)
    end

    dump(buffMgrIds,"getTongEliteBuff")

    return buffMgrIds
end

function TongDataMgr:getFightExtraBuff()

    local buffMgrIds = {}
    for k,v in pairs(self.equipedBuffer or {}) do
        local cfg = self:getSkillCfgById(v)
        if v ~= 0 and cfg and cfg.addAttribute == 0 then
            table.insert(buffMgrIds,v)
        end
    end

    dump(buffMgrIds,"getFightExtraBuff")

    return buffMgrIds
end

function TongDataMgr:getMapExtrDot(pos)

    local cfg = self:getMapCfg(2)
    if cfg and cfg[pos] then
        local cid = cfg[pos].id
        return self.extrMapDot[cid]
    end
end

function TongDataMgr:getCurThreatLv()
    return self.threatLv or 0
end

function TongDataMgr:getCurThreatExp()
    return self.threatExp
end

function TongDataMgr:getNextAirDropInfo()
    return self.nextAirDropTime,self.nextAirDropNum
end

function TongDataMgr:getEliteInfo()
    return self.eliteInfo
end

function TongDataMgr:getHelpList()
    return self.helpList
end

function TongDataMgr:getThreatLvByLevelCid(levelCid)

    local threatLevel = 0
    for k,v in ipairs(self.vitmaxThreatCfg) do
        local index = table.indexOf(v.eliteDungeonInclude,levelCid)
        if index ~= -1 then
            threatLevel = v.threatLevel
            break
        end
    end
    return threatLevel
end

function TongDataMgr:getBarMaxValue(cid)

    local threatValueLmt = self.vitmaxThreatCfg[cid].threatValueLmt
    local berforeValue = 0
    if self.vitmaxThreatCfg[cid-1] then
        berforeValue = self.vitmaxThreatCfg[cid-1].threatValueLmt
    end

    local maxValue = threatValueLmt - berforeValue

    return maxValue,berforeValue
end

function TongDataMgr:getWorldBossInfo()
    return self.woldBossInfo
end

function TongDataMgr:getBattleCntInfo()
    return self.leftCount,self.buyIndex
end

function TongDataMgr:getExtraAttr()

    local extra = {}
    local percentAttr = self:getAddAttr()
    for k,v in pairs(self.attrInfo) do
        local percent = percentAttr[k] or 0
        v = math.ceil(v + v * percent / 10000)
        print(k,v,percent)
        extra[k] = v
    end
    dump(extra,"extra")
    return extra
end

function TongDataMgr:coverAttr(attrType,value)

    local attr = {}
    local cfg = self.vITmaxAttribute[attrType]
    if cfg then
        for attrType,attrValue in pairs(cfg.conversion) do
            if not attr[attrType] then
                attr[attrType] = 0
            end
            attr[attrType] = attr[attrType] + attrValue * value
        end
    end
    print(attrType,value)
    dump(attr,"coverAttr")
    return attr
end

function TongDataMgr:getAddAttr()

    local addattr = {}
    for k,v in pairs(self.equipedBuffer or {}) do
        local cfg = self:getSkillCfgById(v)
        if v ~= 0 and cfg then
            local attrType =  cfg.addAttribute
            local value = cfg.proportion
            if not addattr[attrType] then
                addattr[attrType] = 0
            end
            addattr[attrType] = addattr[attrType] + value
        end
    end
    return addattr
end

function TongDataMgr:isExistSpecialDot(_type)

    local specialInfo
    for k,v in pairs(self.extrMapDot) do
        local vitDungonCfg = self:getVitDungonCfg(v.mgrId)
        if vitDungonCfg and vitDungonCfg.type == _type then
            specialInfo = v
            break
        end
    end
    return specialInfo
end

function TongDataMgr:setGuideFightFlag(flage)
    self.guideFightIndex = flage
end

function TongDataMgr:getGuideFightFlag()
    return self.guideFightIndex
end

function TongDataMgr:guideFight(levelCid,fightIndex)

    if fightIndex == 1 then
        FubenDataMgr:send_DUNGEON_FIGHT_START(levelCid)
    elseif fightIndex == 2 then
        FubenDataMgr:send_DUNGEON_LIMIT_HERO_DUNGEON(levelCid)
    end

    self:setGuideFightFlag(fightIndex)

end

function TongDataMgr:getHelpBuff()
    return self.monsterHelpBuff
end

function TongDataMgr:getRecordList()
    return self.eliteRecord or {}
end

function TongDataMgr:guideLimitHeroFight(levelCid)

    local levelCfg = FubenDataMgr:getLevelCfg(levelCid)
    if not levelCfg then
        return
    end

    local heroLimitID = levelCfg.heroLimitID[1]
    if not heroLimitID then
        return
    end

    if not FubenDataMgr:getLimitHero(heroLimitID) then
        return
    end

    local levelCfg = FubenDataMgr:getLevelCfg(levelCid)
    local levelGroupCfg = FubenDataMgr:getLevelGroupCfg(levelCfg.levelGroupId)
    local chapterCfg = FubenDataMgr:getChapterCfg(levelGroupCfg.dungeonChapterId)
    FubenDataMgr:cacheSelectFubenType(chapterCfg.type)
    FubenDataMgr:cacheSelectChapter(levelGroupCfg.dungeonChapterId)
    FubenDataMgr:cacheSelectLevel(levelCid)
    local formationData = FubenDataMgr:getInitFormation(levelCid)
    HeroDataMgr:changeDataByFuben(levelCid, formationData)
    local heros = {}
    for i, v in ipairs(formationData) do
        table.insert(heros, {v.type, v.id})
    end
    local battleController = require("lua.logic.battle.BattleController")
    battleController.requestFightStart(levelCid, 0, 0, heros, 0, false)

    return true

end

function TongDataMgr:guideLevelState(index)

    local mapInfo_ = self:getMapCfg()
    local info = mapInfo_[1][index]

    local dungonMgrId = info.defaultDungeon
    local vitDungonCfg = self:getVitDungonCfg(dungonMgrId)
    if not vitDungonCfg then
        return
    end
    local dungeonInclude = vitDungonCfg.dungeonInclude
    local levelCid = dungeonInclude[1]
    local isPass = FubenDataMgr:isPassPlotLevel(levelCid)

    return isPass,levelCid
end

function TongDataMgr:setActivityViewState(viewState)
    self.viewState = viewState
end

function TongDataMgr:getActivityViewState()
    return self.viewState
end

function TongDataMgr:setFightMonsterState(state)
    self.fightMonsterState = state
end

function TongDataMgr:getFightMonsterState()
    return self.fightMonsterState
end

---基本信息
function TongDataMgr:Send_getBaseInfo()
    TFDirector:send(c2s.FEAR_PAIN_REQ_FEAR_PAIN_FIGHT_INFO, {})
end

---支援别人
function TongDataMgr:Send_helpOthers(playerId,uid)
    TFDirector:send(c2s.FEAR_PAIN_REQ_HELP_OTHER, {playerId,uid})
end

function TongDataMgr:Send_askHelp(list)
    TFDirector:send(c2s.FEAR_PAIN_REQ_ELITE_HELP, {list})
end

---支援页面信息
function TongDataMgr:Send_getHelpInfo()
    TFDirector:send(c2s.FEAR_PAIN_REQ_HELP_INFO, {})
end

---领取boss阶段奖励
function TongDataMgr:Send_getBossStageAward(id)
    TFDirector:send(c2s.FEAR_PAIN_REQ_TAKE_PROGRESS_REWARD, {id})
end

---请求刷新空投
function TongDataMgr:Send_refreshAirDrop()
    TFDirector:send(c2s.FEAR_PAIN_REQ_REFRESH_AIR, {})
end

---精英关卡撤退
function TongDataMgr:Send_retreatMonsterFight(retreatMgrID)
    TFDirector:send(c2s.FEAR_PAIN_REQ_ELITE_RETREAT, {})
end

---领取精英关卡奖励
function TongDataMgr:Send_getMonsterFightAward()
    TFDirector:send(c2s.FEAR_PAIN_REQ_FINISH_ELITE, {})
end

---增加精英关卡挑战次数
function TongDataMgr:Send_AddBattleCount()
    TFDirector:send(c2s.FEAR_PAIN_REQ_BUY_COUNT, {})
end

---请求精英关卡信息
function TongDataMgr:Send_GetMonsterInfo()
    TFDirector:send(c2s.FEAR_PAIN_REQ_ELITE_INFO, {})
end

---请求世界boss
function TongDataMgr:Send_getBossInfo()
    TFDirector:send(c2s.FEAR_PAIN_REQ_WORLD_BOSS, {})
end

---世界boss战报
function TongDataMgr:Send_getFightReport()
    TFDirector:send(c2s.FEAR_PAIN_REQ_FIGHT_REPORT, {})
end

function TongDataMgr:Send_getRankInfo(type,dungeonId,page,flag)
    dungeonId = dungeonId or 0
    if type ~= 1 and type ~= 2 then
        dungeonId = type
        type = 3
    end
    dump({type,dungeonId,page,flag})
    TFDirector:send(c2s.FEAR_PAIN_REQ_FEAR_PAIN_RANK, {type,dungeonId,page,flag})
end

function TongDataMgr:Send_activeOrCancle(id,handleType)

    TFDirector:send(c2s.FEAR_PAIN_REQ_CHOOSE_AFFIX, {handleType,id})

end

function TongDataMgr:Send_getStudyInfo()
    TFDirector:send(c2s.FEAR_PAIN_REQ_SKILL_INFO, {})
end

---装备技能
function TongDataMgr:Send_equipSkill(slotId,buffCid,type_)

    local type_ = buffCid == 0 and 2 or 1
    TFDirector:send(c2s.FEAR_PAIN_REQ_EQUIP_SKILL, {slotId,buffCid,type_})
end

---保存属性
function TongDataMgr:Send_saveAttr(list)
    TFDirector:send(c2s.FEAR_PAIN_REQ_DISTRIBUTE, {list})
end

---重置属性点数
function TongDataMgr:Send_resetAttr()
    TFDirector:send(c2s.FEAR_PAIN_REQ_RESET_ATTR, {})
end

function TongDataMgr:onRecvBaseInfo(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    self.extrMapDot = {}
    for k,v in ipairs(data.passInfo or {}) do
        self.extrMapDot[v.cid] = v
    end

    self.nextAirDropTime = data.nextRefreshTime
    self.nextAirDropNum = data.nextNum

    local cfg = self.vitmaxThreatCfg[data.threatId]
    if cfg then
        self.threatLv = cfg.threatLevel
    end


    EventMgr:dispatchEvent(EV_TONG.BaseInfo)

end

function TongDataMgr:onRecvMonsterInfo(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    self.eliteInfo = data

    local cfg = self.vitmaxThreatCfg[data.threatId]
    if cfg then
        self.threatLv = cfg.threatLevel
    end
    self.threatExp = data.threat

    self.buyIndex = data.buyIndex
    self.leftCount = data.leftCount

    self.monsterHelpBuff = data.helpBuff
    self.eliteRecord = data.eliteRecord or {}

    EventMgr:dispatchEvent(EV_TONG.EliteInfo)
end

function TongDataMgr:onRecvIsPlayEffect(event)
    if not self.eliteInfo then
        return
    end
    self.eliteInfo.played = true
end

function TongDataMgr:onRecvHelpBuffNotice(event)

    local data = event.data
    if not data then
        return
    end

    self.monsterHelpBuff = data.helpBuff
    self.eliteRecord = data.eliteRecord or {}
    EventMgr:dispatchEvent(EV_TONG.UpdateHelpBuff)
end

function TongDataMgr:onRecvAfterRetreat(event)

    local data = event.data
    if not data then
        return
    end
    EventMgr:dispatchEvent(EV_TONG.Retreat,data.mgrId)
end

function TongDataMgr:onRecvAskHelp(event)

end

function TongDataMgr:onRecvHelpOther(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    self.leftHelpCnt = data.leftHelp

    for i=#self.helpList,1,-1 do
        if self.helpList[i].uid == data.uid then
            table.remove(self.helpList,i)
        end
    end

    Utils:showReward(data.reward or {})

    EventMgr:dispatchEvent(EV_TONG.HelpInfo)

end

function TongDataMgr:onRecvHelpInfo(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    self.helpList = data.Help
    self.leftHelpCnt = data.leftHelp

    EventMgr:dispatchEvent(EV_TONG.HelpInfo)

end

function TongDataMgr:onRecvBuyCount(event)

    local data = event.data
    if not data then
        return
    end

    self.buyIndex = data.buyIndex
    self.leftCount = data.leftCount

    EventMgr:dispatchEvent(EV_TONG.BattleCnt)

end

function TongDataMgr:onRecvWorldBossInfo(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    self.woldBossInfo = data

    for k,v in ipairs(data.finishedReward or {}) do
        self.bossRewardStage[v] = 1
    end

    EventMgr:dispatchEvent(EV_TONG.WorldBoss)

end

function TongDataMgr:onRecvRankInfo(event)

    local data = event.data
    if not data then
        return
    end

    dump(data,"onRecvRankInfo")

    local dungeonId     = data.dungeonId

    local rankType = data.type
    local page     = data.page
    local show     = data.show or false
    local checking = data.checking or false

    local rank = data.worldBossRank or {}
    local myRankData = data.myWorldBossRank
    if rankType == 3 then
        rankType = dungeonId
        rank = data.fearlessRank or {}
        myRankData = data.myFearlessRank
    end

    self.myRankInfo[rankType] = myRankData
    self.examineRank[rankType] = (not show)
    self.examineMyRank[rankType] = checking

    for k,v in ipairs(rank) do
        if not self.rankData[rankType] then
            self.rankData[rankType] = {}
        end

        if not self.rankData[rankType][page] then
            self.rankData[rankType][page] = {}
        end
        table.insert(self.rankData[rankType][page],v)
    end

    if #rank == 0 then
        page = nil
    end

    EventMgr:dispatchEvent(EV_TONG.RankInfo,data.flag,page)

end

function TongDataMgr:onRecvGetMonserReward(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    --Utils:showReward(data.reward or {})

    EventMgr:dispatchEvent(EV_TONG.FinishElite,data.reward or {})
end

function TongDataMgr:onRecvChooseAffix(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    self.eliteInfo.fearlessAffix = data.affix
    EventMgr:dispatchEvent(EV_TONG.ActiveAffix)
end

function TongDataMgr:onRecvFightReport(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    self.report = data.fightReport or {}

    EventMgr:dispatchEvent(EV_TONG.Report)
end

function TongDataMgr:onRecvRefreshAir(event)

    local data = event.data
    if not data then
        return
    end

    dump(data)

    local passInfo = data.passInfo or {}
    local ct = data.changeType

    for k,v in ipairs(passInfo) do
        if ct == EC_SChangeType.DELETE then
            self.extrMapDot[v.cid] = nil
        else
            self.extrMapDot[v.cid] = v
        end
    end

    self.nextAirDropTime = data.nextRefreshTime
    self.nextAirDropNum = data.nextNum

    EventMgr:dispatchEvent(EV_TONG.UpdateAir,ct,passInfo)

end

function TongDataMgr:onRecvRefreshElite(event)

    local data = event.data
    if not data then
        return
    end

    dump(data)

    local passInfo = data.passInfo
    if not passInfo then
        return
    end

    local ct = data.changeType

    if ct == EC_SChangeType.DELETE then
        self.extrMapDot[passInfo.cid] = nil
    else
        self.extrMapDot[passInfo.cid] = passInfo
    end

    EventMgr:dispatchEvent(EV_TONG.UpdateElite,ct,passInfo)


end

function TongDataMgr:onRecvStudyInfo(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    self.equipedBuffer = {}
    for k,v in ipairs(data.equipSkill or {}) do
        self.equipedBuffer[v.pos] = v.skillId
    end

    self.attrInfo = {}
    for k,v in ipairs(data.attrDistribute or {}) do
        self.attrInfo[v.attr] = v.point
    end

   local oldSkill = clone(self.unLockSkill or {})

    self.unLockSkill = {}
    self.unLockSkill = data.unlockSkill or {}

    self.attrPointNum = data.attrPointNum or 0

    EventMgr:dispatchEvent(EV_TONG.ResetStudy,oldSkill)

end

function TongDataMgr:onRecvStudyAttrInfo(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    for k,v in ipairs(data.attrDistribute or {}) do
        self.attrInfo[v.attr] = v.point
    end

    EventMgr:dispatchEvent(EV_TONG.SaveAttr)
end

function TongDataMgr:onRecvEquipSkill(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)
    for k,v in ipairs(data.equipSkill or {}) do
        self.equipedBuffer[v.pos] = v.skillId
    end

    EventMgr:dispatchEvent(EV_TONG.AfterEquip)

end

function TongDataMgr:onRecvUnLockNotice(event)

    local data = event.data
    if not data then
        return
    end
    dump(data)

    local skillIds = data.skillId or {}
    table.insertTo(self.unLockSkill,skillIds)

    EventMgr:dispatchEvent(EV_TONG.UnLockSkill,skillIds)
end

function TongDataMgr:onRecvGetBossReward(event)

    local data = event.data
    if not data then
        return
    end

    Utils:showReward(data.reward or {})
    self.bossRewardStage[data.id] = 1
    EventMgr:dispatchEvent(EV_TONG.BossAward)

end

function TongDataMgr:onRecvResetAttr(event)

    local data = event.data
    if not data then
        return
    end

    EventMgr:dispatchEvent(EV_TONG.SaveAttr)
end

return TongDataMgr:new()
