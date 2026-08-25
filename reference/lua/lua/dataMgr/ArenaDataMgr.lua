
local BaseDataMgr = import(".BaseDataMgr")
local ArenaDataMgr = class("ArenaDataMgr", BaseDataMgr)

function ArenaDataMgr:onLogin()
    -- self:send_ARENA_REQ_ARENA_INFO()
    self:send_ARENA_REQ_ARENA_RECORD()
    self:send_ARENA_REQ_ARENA_RANK_LIST()
    return {}
end

function ArenaDataMgr:onEnterMain()

end

function ArenaDataMgr:reset()

    self.arenaInfo      = nil
    self.arenaRankData  = nil
    self.arenaMatchData = nil
    self.arenaRecord    = nil
    self.lastCycleData = nil
end

function ArenaDataMgr:init()
    TFDirector:addProto(s2c.ARENA_RSP_ARENA_INFO, self, self.onRecv_ARENA_RSP_ARENA_INFO)
    TFDirector:addProto(s2c.ARENA_RSP_ARENA_RANK_LIST, self, self.onRecv_ARENA_RSP_ARENA_RANK_LIST)
    TFDirector:addProto(s2c.ARENA_RSP_MATCH_ARENA_PLAYER, self, self.onRecv_ARENA_RSP_MATCH_ARENA_PLAYER)
    TFDirector:addProto(s2c.ARENA_RSP_ARENA_RECORD, self, self.onRecv_ARENA_RSP_ARENA_RECORD)
    TFDirector:addProto(s2c.DUNGEON_RESP_ARENA_OVER, self, self.onRecv_DUNGEON_RESP_ARENA_OVER)
    TFDirector:addProto(s2c.ARENA_RSP_ARENA_LAST_DATA, self, self.onRecv_ARENA_RSP_ARENA_LAST_DATA)


    self.arenaInfo      = nil
    self.arenaRankData  = nil
    self.arenaMatchData = nil
    self.arenaRecord    = nil
    self.lastCycleData = nil

    --TODO testData
    self:testData()
end
function ArenaDataMgr:testData()
    self.arenaInfo = {}
    self.arenaInfo.step = 1  --活动阶段（0-准备期；1-进行期；2-结算期）
    self.arenaInfo.nextStepTime = 2 --进入下阶段的具体时刻（秒）
    self.arenaInfo.curCycle = {} -- 当前周期
    self.arenaInfo.showTips = true --是否新周期提示



    self.arenaRankData = {}
    self.arenaRankData.rankList = {}
    self.arenaRankData.topRank  = {}
    self.arenaRankData.topRankHistory  =  {}  --名人堂
    self.arenaRankData.refreshMinu = 10
    self.arenaRankData.lastTopRank  =  {}  --名人堂
end

function ArenaDataMgr:getRoundData()
    return self.arenaRoundData
end
function ArenaDataMgr:setRoundData(roundData)
    self.arenaRoundData = roundData
end

function ArenaDataMgr:getArenaData()
    return self.arenaInfo
end

--获取战斗记录
function ArenaDataMgr:getRecordData()
    return self.arenaRecord or {}
end



function ArenaDataMgr:getRankData()
    return self.arenaRankData or {}
end



function ArenaDataMgr:getMatchData()
    return self.arenaMatchData
end

--获取当前buffer
function ArenaDataMgr:getRegionBuffs()
    if self.arenaInfo then 
        return self.arenaInfo.curCycle.regionBuffs or {}
    end
    return {}
end

function ArenaDataMgr:getSegment()
    if self.arenaInfo then 
        return self.arenaInfo.curCycle.segment or 1
    end
    return 1
end

--是否新周期提示
function ArenaDataMgr:isShowTips()
    if self.arenaInfo then 
        return self.arenaInfo.showTips
    end
end



function ArenaDataMgr:getBattleScore()
    return self.battleScore or 0
end

-- EV_AREAN_UPDATE          = "EV_AREAN_UPDATE"          --竞技场信息更新
-- EV_ARENA_RANK_UPDATE     = "EV_ARENA_RANK_UPDATE"     --竞技场排行版更新    
-- EV_AREAN_MACHT_SUCCESS   = "EV_AREAN_MACHT_SUCCESS"   --匹配成功
-- EV_ARENA_RECORD_UPDATE   = "EV_ARENA_RECORD_UPDATE"   --竞技场战斗记录更新   




-- // 上周期排行榜列表
-- message ArenaLastCycleRank{
--     repeated RspArenaRank rankList = 1;//排名信息
--     required RspArenaRank rank = 2; //自身排名
-- }

-- 上周期排行榜列表
function ArenaDataMgr:onRecv_ARENA_RSP_ARENA_LAST_DATA(event)
    local data  = event.data
    dump(data)
    -- Box("111")
    if data and data.rankList then 
        self.lastCycleData = data.rankList.rank
        EventMgr:dispatchEvent(EV_AREAN_LAST_RANK_DATA ,self.lastCycleData)
    end

        -- self.lastCycleData ={ rank = 1 ,segment = 3}
        -- EventMgr:dispatchEvent(EV_AREAN_LAST_RANK_DATA ,self.lastCycleData)
end


--竞技场战斗结果返回
function ArenaDataMgr:onRecv_DUNGEON_RESP_ARENA_OVER(event)
    local data = event.data 
    self.battleScore = data.battleScore or 0
    dump(data)
    print("竞技场战斗结果返回")
    self:send_ARENA_REQ_ARENA_RANK_LIST()
    -- self:send_ARENA_REQ_ARENA_INFO()
end
--竞技场信息
function ArenaDataMgr:onRecv_ARENA_RSP_ARENA_INFO(event)
    local data = event.data 
    self.arenaInfo =  data.info
    dump(data)
    print("onRecv_ARENA_RSP_ARENA_INFO")
    
    EventMgr:dispatchEvent(EV_AREAN_UPDATE)

-- message ArenaInfo {
--     required int32 step = 1;//活动阶段（0-准备期；1-进行期；2-结算期）
--     required int32 nextStepTime = 2;//进入下阶段的具体时刻（秒）
--     required RspArenaCycle curCycle = 3;//当前周期
--     required bool showTips = 4;//是否新周期提示
-- }
    -- Box("Arena info")
end


-- message RspArenaRankList{
--     repeated RspArenaRank rankList = 1;//排名信息
--     required RspArenaRank rank = 2; //自身排名
--     required int32 refreshMinu = 3;//刷新周期,分钟
--     repeated RspArenaRank topRank = 4; //巅峰榜单
--     required RspArenaRank curTopRank = 5; //巅峰榜单自身排名
--     repeated ArenaTopRankHistory topRankHistory = 6; //近几个周期名人堂榜单
--     enum MsgID{eMsgID = 18302;}; //注意：消息id放最后,以免客户端解析异常
-- }

--排行榜返回
function ArenaDataMgr:onRecv_ARENA_RSP_ARENA_RANK_LIST(event)
    self.arenaRankData  = event.data 
    --dump(self.arenaRankData)
    print("onRecv_ARENA_RSP_ARENA_RANK_LIST")

    self.arenaRankData.rankList = self.arenaRankData.rankList or {}
    self.arenaRankData.topRank  = self.arenaRankData.topRank or {}
    self.arenaRankData.topRankHistory  = self.arenaRankData.topRankHistory or {}  --名人堂
    self.arenaRankData.refreshMinu = self.arenaRankData.refreshMinu or 10
    self.arenaRankData.lastTopRank  = self.arenaRankData.lastTopRank or {}  --名人堂
    --self.arenaRankData.rank
    --self.arenaRankData.curTopRank
    --self.arenaRankData.curLastTopRank
    EventMgr:dispatchEvent(EV_ARENA_RANK_UPDATE)
    -- Box("Arena rank list")
end

--战斗匹配
function ArenaDataMgr:onRecv_ARENA_RSP_MATCH_ARENA_PLAYER(event)
    self.arenaMatchData = event.data 
    --dump(self.arenaMatchData)
    print("onRecv_ARENA_RSP_MATCH_ARENA_PLAYER")


    -- local _selfFormation = {}
    -- for i,v in ipairs(self.arenaMatchData.selfHeroes) do
    --     table.insert(_selfFormation ,{ id = v.id ,cid = v.cid})
    -- end
    -- for i,v in ipairs(self.arenaMatchData.heroes) do
    --     table.insert(_selfFormation ,{ id = v.id ,cid = v.cid})
    -- end
    -- dump(_selfFormation)
    EventMgr:dispatchEvent(EV_AREAN_MACHT_SUCCESS)
end

--战斗记录返回
function ArenaDataMgr:onRecv_ARENA_RSP_ARENA_RECORD(event)
    self.arenaRecord  = event.data.records or {} 
    -- dump(self.arenaRecord)
    print("onRecv_ARENA_RSP_ARENA_RECORD")
    EventMgr:dispatchEvent(EV_ARENA_RECORD_UPDATE)

    -- Box("Arena Record")
end



------------------------------------------------------------

--请求竞技场信息
function ArenaDataMgr:send_ARENA_REQ_ARENA_INFO()
    TFDirector:send(c2s.ARENA_REQ_ARENA_INFO, {})
end

--请求战斗匹配
function ArenaDataMgr:send_ARENA_REQ_MATCH_ARENA_PLAYER()
    TFDirector:send(c2s.ARENA_REQ_MATCH_ARENA_PLAYER, {})
end

---请求排行榜
function ArenaDataMgr:send_ARENA_REQ_ARENA_RANK_LIST()
    TFDirector:send(c2s.ARENA_REQ_ARENA_RANK_LIST, {})
end

--请求作战记录
function ArenaDataMgr:send_ARENA_REQ_ARENA_RECORD()
    TFDirector:send(c2s.ARENA_REQ_ARENA_RECORD, {})
end

    -- local roundData = {}
    -- roundData.selfHero  = 1;//己方英雄cid
    -- roundData.enemyHero = 2;//对方英雄cid
    -- roundData.success   = MainPlayer:getPlayerId() ~= losePid

--请求竞技场战斗结束
function ArenaDataMgr:send_DUNGEON_REQ_ARENA_OVER(roundData)
    self:setRoundData(roundData) --保存回合数据
    local arenaHeroResult = {}
    for i,v in ipairs(roundData) do
        table.insert(arenaHeroResult,{v.selfHero ,v.enemyHero ,v.success  })
    end
    dump(arenaHeroResult)
    TFDirector:send(c2s.DUNGEON_REQ_ARENA_OVER , {arenaHeroResult})
end

--请求上期结算信息
function ArenaDataMgr:send_ARENA_REQ_ARENA_LAST_DATA()
    dump(self.arenaInfo)
    if self.arenaInfo and self.arenaInfo.showTips then
        self.arenaInfo.showTips = false
        TFDirector:send(c2s.ARENA_REQ_ARENA_LAST_DATA, {})
        print("请求上期结算信息")
    end
end


local SegmentNames = 
{
   [1] = "青铜" ,
   [2] = "白银" ,
   [3] = "黄金" ,
   [4] = "铂金" ,
   [5] = "钻石" ,
   [6] = "荣耀" 
}

local SegmentIcons = 
{
    [1] = "icon/skyLadder/bronze.png",
    [2] = "icon/skyLadder/silver.png",
    [3] = "icon/skyLadder/gold.png",
    [4] = "icon/skyLadder/platinum.png",
    [5] = "icon/skyLadder/diamond.png",
    [5] = "icon/skyLadder/honour.png",
}

--青铜 白银 黄金 铂金 钻石
local SegmentImageNames = 
{
    [1] = "arena/segment/name/qingtong.png",
    [2] = "arena/segment/name/baiyin.png",
    [3] = "arena/segment/name/huangjin.png",
    [4] = "arena/segment/name/bojin.png",
    [5] = "arena/segment/name/zhuanshi.png",
    [6] = "arena/segment/name/ronyao.png",
}


--段位名称
function ArenaDataMgr:segmentName(segment)
    -- return SegmentNames[segment] or SegmentNames[1]
    segment = segment > 0 and segment or 1 --容错
    local segmentCfg = TabDataMgr:getData("RankReward" ,segment)
    return segmentCfg.rankName
end

--段位名称
function ArenaDataMgr:segmentImageName(segment)
    -- return SegmentImageNames[segment] or SegmentImageNames[1]
    segment = segment > 0 and segment or 1 --容错
    local segmentCfg = TabDataMgr:getData("RankReward" ,segment)
    return segmentCfg.rankImageName or  "arena/segment/name/huangjin.png"
end

--段位图标
function ArenaDataMgr:segmentIcon(segment)
    -- return SegmentIcons[segment] or SegmentIcons[1]
    segment = segment > 0 and segment or 1 --容错
    local segmentCfg = TabDataMgr:getData("RankReward" ,segment)
    return segmentCfg.icon or "icon/skyLadder/bronze.png"
end

--段位背景图
function ArenaDataMgr:segmentPaint(segment)
    -- return SegmentIcons[segment] or SegmentIcons[1]
    segment = segment > 0 and segment or 1 --容错
    local segmentCfg = TabDataMgr:getData("RankReward" ,segment)
    return segmentCfg.paint or "arena/segment/huangjin.png"
end
--是否有奖励可以领取
function ArenaDataMgr:hasReward()
    local tasks = TaskDataMgr:getTask(EC_TaskType.ARENA)
    for i,taskCid in ipairs(tasks) do
        local taskInfo = TaskDataMgr:getTaskInfo(taskCid)
        if taskInfo and taskInfo.status == EC_TaskStatus.GET then 
            return true
        end
    end
end

return ArenaDataMgr:new()
