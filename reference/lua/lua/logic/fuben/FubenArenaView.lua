
local battleController = require("lua.logic.battle.BattleController")
local FubenArenaView = class("FubenArenaView", BaseLayer)

function FubenArenaView:initData(chapterCid)
    -- self.chapterCid_ = chapterCid
    -- self.chapterCfg_ = FubenDataMgr:getChapterCfg(chapterCid)
    --排行数据
    -- self.rankData_   = self.rankData_ or {{},{},{},{},{},{}}
    -- --个人排行数据
    -- self.myRankData_ = {}
    --进入战斗倒计时
    self.countDownTime = 5
end

function FubenArenaView:getClosingStateParams()
    return {FubenDataMgr.selectChapter_}
end

function FubenArenaView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaView")
end

function FubenArenaView:initUI(ui)
    self.super.initUI(self, ui)

    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_prefab = TFDirector:getChildByPath(ui, "Panel_prefab"):hide()

    self.Panel_rankItem =  TFDirector:getChildByPath(self.Panel_prefab, "Panel_rankItem")

    self.Button_record = TFDirector:getChildByPath(self.Panel_root, "Button_record")
    self.Button_task = TFDirector:getChildByPath(self.Panel_root, "Button_task")
    self.Image_task_red = TFDirector:getChildByPath(self.Button_task, "Image_red"):hide()

    self.Button_reward = TFDirector:getChildByPath(self.Panel_root, "Button_reward")
    self.Button_store = TFDirector:getChildByPath(self.Panel_root, "Button_store")
    self.Button_rank = TFDirector:getChildByPath(self.Panel_root, "Button_rank")
    self.Button_formation = TFDirector:getChildByPath(self.Panel_root, "Button_formation")
    self.Button_match = TFDirector:getChildByPath(self.Panel_root, "Button_match")
    self.Button_fame  = TFDirector:getChildByPath(self.Panel_root, "Button_fame")

    self.Label_match    = TFDirector:getChildByPath(self.Button_match, "Label_match")
    self.Image_cost_icon   = TFDirector:getChildByPath(self.Button_match, "Image_cost_icon")
    self.Label_cost_num = TFDirector:getChildByPath(self.Button_match, "Label_cost_num")



    -- self.Image_match = TFDirector:getChildByPath(self.Panel_root, "Image_match")
    -- self.Label_match_time = TFDirector:getChildByPath(self.Image_match, "Label_match_time")
    -- self.Image_match:setVisible(false)

    self.Panel_content = TFDirector:getChildByPath(self.Panel_root, "Panel_content")
    self.Label_title = TFDirector:getChildByPath(self.Panel_content, "Label_title")
    -- self.Label_score = TFDirector:getChildByPath(self.Panel_content, "Label_score"):hide()
    self.Label_title_score = TFDirector:getChildByPath(self.Panel_content, "Label_title_score")

    self.Panel_paint = TFDirector:getChildByPath(self.Panel_content, "Panel_paint")
    self.Image_paint = TFDirector:getChildByPath(self.Panel_paint, "Image_paint")

    self.Panel_rank = TFDirector:getChildByPath(self.Panel_content, "Panel_rank")
    
    self.ScrollView_rank =  TFDirector:getChildByPath(self.Panel_rank, "ScrollView_rank")
    self.ListView_rank   = UIListView:create(self.ScrollView_rank )


    self.Panel_myRank = TFDirector:getChildByPath(self.Panel_rank, "Panel_myRank")
    self.Label_racing_update_time = TFDirector:getChildByPath(self.Panel_myRank, "Label_racing_update_time")

    self.Panel_myRankItem = TFDirector:getChildByPath(self.Panel_myRank, "Panel_myRankItem")
    -- self.Panel_myRankItem:AddTo(self.Panel_myRank):Pos(0, 0):ZO(1)

    --匹配成功后 倒计时进入UI
    self.Panel_match = TFDirector:getChildByPath(self.Panel_root, "Panel_match")

    self.Panel_match_content= TFDirector:getChildByPath(self.Panel_match, "Panel_match_content")
    self.Label_countTime = TFDirector:getChildByPath(self.Panel_match_content, "Label_countTime")
    self.Panel_match:setVisible(false)




    self:setLang()


    self:onArenaRefresh()
    self:showRank()

    --上赛季结算
    self:timeOut(function()
            ArenaDataMgr:send_ARENA_REQ_ARENA_LAST_DATA()
            --Utils:openView("fuben.FubenArenaSeason",{name = "aaddf" ,value =100})
    end,0.2)
end
function FubenArenaView:setLang()
    self.Label_match:setTextById(290000090)
    self.Label_title_score:setTextById(262011,0)

    local Label_record = TFDirector:getChildByPath(self.Button_record, "Label_record")
    local Label_task = TFDirector:getChildByPath(self.Button_task, "Label_task")
    local Label_reward = TFDirector:getChildByPath(self.Button_reward, "Label_reward")
    local Label_store = TFDirector:getChildByPath(self.Button_store, "Label_store")
    local Label_rank = TFDirector:getChildByPath(self.Button_rank, "Label_rank")
    local Label_formation = TFDirector:getChildByPath(self.Button_formation, "Label_formation")
    local Label_match = TFDirector:getChildByPath(self.Button_match, "Label_match")
    local Label_fame  = TFDirector:getChildByPath(self.Button_fame, "Label_fame")
    Label_record:setTextById(2100003)
    Label_task:setTextById(1454023)
    Label_reward:setTextById(310008)
    Label_store:setTextById(500003)
    Label_rank:setTextById(290000087)
    Label_formation:setTextById(213183)
    Label_match:setTextById(290000090)
    Label_fame:setTextById(290000086)

    local Image_titles = TFDirector:getChildByPath(self.Panel_rank, "Image_titles")
    local titleTextIDs = {12101042,290000089,3005046,13033}
    for i=1,4 do
        local Label_title = TFDirector:getChildByPath(Image_titles, "Label_title"..i)
        Label_title:setTextById(titleTextIDs[i])
    end
    self.Label_racing_update_time:setTextById(14110404)
end


function FubenArenaView:onArenaRefresh()
    local arenaData =  ArenaDataMgr:getArenaData()
    if not arenaData then 
        return
    end 
    -- dump(arenaData)
    self.Label_title:setText(TextDataMgr:getText(ArenaDataMgr:segmentName(arenaData.curCycle.segment)) )
    --self.Label_score:setText(arenaData.curCycle.arenaScore)
    self.Label_title_score:setTextById(262011,arenaData.curCycle.arenaScore)
    
    self.Image_paint:setTexture(ArenaDataMgr:segmentPaint(arenaData.curCycle.segment))

    local itemId ,itemCount = self:getCostData(arenaData.curCycle.segment)
    if itemId and itemCount > 0 then 
        local costItemCfg = GoodsDataMgr:getItemCfg(itemId)
        self.Image_cost_icon:setTexture(costItemCfg.icon)
        self.Label_cost_num:setText(tostring(itemCount))
        self.Image_cost_icon:show()
        self.Label_cost_num:show()
        self.Label_match:setPosition(ccp(0,-14))
    else
        self.Image_cost_icon:hide()
        self.Label_cost_num:hide()
        self.Label_match:setPosition(ccp(0,0))
    end

    self.Image_task_red:setVisible(ArenaDataMgr:hasReward())
end

--TODO 暂不使用 ，在新的窗口打开
function FubenArenaView:showMatchCountDown()
    local matchPlayer  = ArenaDataMgr:getMatchData()
    self.Panel_match:setVisible(true)

    local Image_head1 = TFDirector:getChildByPath(self.Panel_match_content, "Image_head1")
    local Image_head2 = TFDirector:getChildByPath(self.Panel_match_content, "Image_head2")
    
    local Label_level1 = TFDirector:getChildByPath(Image_head1, "Label_level")
    local Label_name1  = TFDirector:getChildByPath(Image_head1, "Label_name")
    local Image_icon1  = TFDirector:getChildByPath(Image_head1, "Image_icon")
    local Image_icon_frame1 = TFDirector:getChildByPath(Image_head1, "Image_icon_frame")

    local Label_level2 = TFDirector:getChildByPath(Image_head2, "Label_level")
    local Label_name2  = TFDirector:getChildByPath(Image_head2, "Label_name")
    local Image_icon2  = TFDirector:getChildByPath(Image_head2, "Image_icon")
    local Image_icon_frame2 = TFDirector:getChildByPath(Image_head2, "Image_icon_frame")

    self.countDownTime = 5
    self.Label_countTime:setTextById(290000103,self.countDownTime)

    if self.matchTimer then
        TFDirector:removeTimer(self.matchTimer)
    end
    self.matchTimer = TFDirector:addTimer(1000, 5, nil, handler(self.onMatchTime, self))



    local curCid     = AvatarDataMgr:getCurUsingCid()
    local acatarPath1  = AvatarDataMgr:getAvatarIconPath(curCid)

    Label_name1:setText(MainPlayer:getPlayerName())
    Label_level1:setTextById(700034,MainPlayer:getPlayerLv())
    Image_icon1:setTexture(acatarPath1)



    Label_name2:setText(matchPlayer.pName)
    Label_level2:setTextById(700034,matchPlayer.level)
    local acatarPath2  = AvatarDataMgr:getAvatarIconPath(matchPlayer.headId)
    Image_icon2:setTexture(acatarPath2)
end


--排行暂时 
function FubenArenaView:showRank()

    local data  = ArenaDataMgr:getRankData() 
    local items = self.ListView_rank:getItems()
    local _rankList = data.rankList or {}
    --只显示前100名数据
    local rankList = {}
    for i,v in ipairs(_rankList) do
        rankList[i] = v
        if i >= 100 then 
            break
        end
    end

    local gap   = #rankList - #items
    for i = 1, math.abs(gap) do
        if gap < 0 then
            self.ListView_rank:removeItem(1)
        else
            local Panel_rankItem = self.Panel_rankItem:clone()
            self.ListView_rank:pushBackCustomItem(Panel_rankItem)
        end
    end

    for i, v in ipairs(rankList) do
        local Panel_rankItem = self.ListView_rank:getItem(i)
        self:updateRankItem(Panel_rankItem, v)
    end


    --TODO 更新自己的排行信息
    if data.rank  then
        self.Panel_myRankItem:show()
        self:updateRankItem(self.Panel_myRankItem, data.rank, true)
    else
        self.Panel_myRankItem:hide()
    end

end

--  = {
-- [LUA-print] [04/16/25 16:12:00]  -             "arenaScore" = 1000
-- [LUA-print] [04/16/25 16:12:00]  -             "headId"     = 101
-- [LUA-print] [04/16/25 16:12:00]  -             "level"      = 67
-- [LUA-print] [04/16/25 16:12:00]  -             "pName"      = "神奇的大象"
-- [LUA-print] [04/16/25 16:12:00]  -             "pid"        = 539936786
-- [LUA-print] [04/16/25 16:12:00]  -             "rank"       = 2
-- [LUA-print] [04/16/25 16:12:00]  -             "segment"    = 1
-- [LUA-print] [04/16/25 16:12:00]  -         }
-- [LUA-print] [04/16/25 16:12:00]  -     }

function FubenArenaView:updateRankItem(item, data, isOwn)
    isOwn = tobool(isOwn)
    -- local Image_normal = TFDirector:getChildByPath(item, "Image_normal")
    -- local Image_select = TFDirector:getChildByPath(item, "Image_select")
    local Label_rank   = TFDirector:getChildByPath(item, "Label_rank")
    local Label_name   = TFDirector:getChildByPath(item, "Label_name")
    local Label_level  = TFDirector:getChildByPath(item, "Label_level")
    local Label_score  = TFDirector:getChildByPath(item, "Label_score")
    local Image_icon = TFDirector:getChildByPath(item, "Image_icon")
    local Label_power  = TFDirector:getChildByPath(item, "Label_power")

    local Image_rank1  = TFDirector:getChildByPath(item, "Image_rank1")
    local Image_rank2  = TFDirector:getChildByPath(item, "Image_rank2")
    local Image_rank3  = TFDirector:getChildByPath(item, "Image_rank3")

    Label_score:setText(data.arenaScore)
    Label_power:setText(data.fightPower or 0)
    -- Image_normal:setVisible(not isOwn)
    -- Image_select:setVisible(isOwn)

    Label_name:setText(data.pName or "")
    Label_level:setTextById(800006, data.level or 1)
    if data.rank == 0 or data.rank > 3 then
        if data.rank == 0 then 
            Label_rank:setTextById(310012)
        else
            Label_rank:setText(data.rank)
        end
        Label_rank:show()
    else
        Label_rank:hide()
    end
    Image_rank1:setVisible(data.rank == 1)
    Image_rank2:setVisible(data.rank == 2)
    Image_rank3:setVisible(data.rank == 3)
    if isOwn then
        local icon = AvatarDataMgr:getSelfAvatarIconPath()
        Image_icon:setTexture(icon)
    else
        local headIcon = data.headId
        if headIcon == 0 then
            headIcon = 101
        end
        local icon = AvatarDataMgr:getAvatarIconPath(headIcon)
        Image_icon:setTexture(icon)

        if data.pid ~= MainPlayer:getPlayerId() then
            Image_icon:onClick(function()
                    MainPlayer:sendPlayerId(data.pid)
            end)
        end
    end
end

function FubenArenaView:onShowPlayerInfoView(playerInfo)
    local PlayerInfoView = require("lua.logic.chat.PlayerInfoView"):new(playerInfo)
    AlertManager:addLayer(PlayerInfoView,AlertManager.BLOCK_AND_GRAY_CLOSE)
    AlertManager:show()
end


function FubenArenaView:onLastRankData(data)
    Utils:openView("fuben.FubenArenaSeason",data)
end


function FubenArenaView:registerEvents()

    EventMgr:addEventListener(self, EV_RECV_PLAYERINFO, handler(self.onShowPlayerInfoView, self))
    EventMgr:addEventListener(self, EV_ARENA_RANK_UPDATE, handler(self.onUpdateRank, self))
    EventMgr:addEventListener(self, EV_AREAN_MACHT_SUCCESS, handler(self.onMatchSuccess, self))
    EventMgr:addEventListener(self, EV_AREAN_UPDATE, handler(self.onArenaRefresh, self))
    EventMgr:addEventListener(self, EV_AREAN_LAST_RANK_DATA, handler(self.onLastRankData, self))
    EventMgr:addEventListener(self, EV_TASK_UPDATE, handler(self.onTaskUpdateEvent, self))


    self:setMainBtnCallback(function()
        return self.Panel_match:isVisible()
    end)

    self:setBackBtnCallback(function()
        AlertManager:closeLayer(self)
        local view = AlertManager:getLayer(-1)
        if view and view.__cname == "FubenChapterView" then
        else
            Utils:openView("fuben.FubenChapterView")
        end
   
    end)

    self.Button_record:onClick(function()
        Utils:openView("fuben.FubenArenaRecordView")
    end)
    
    self.Button_reward:onClick(function()
        Utils:openView("fuben.FubenArenaRewardView")
    end)
    
    self.Button_store:onClick(function()
        -- Box("store")
        Utils:openView("store.StoreMainView", 160002)
    end)
    
    self.Button_rank:onClick(function()
        Utils:openView("fuben.FubenArenaRankView")
    end)
    
    self.Button_formation:onClick(function()
        --确认布阵界面
        -- local chapterType = EC_FBType.ACTIVITY 
        -- local chapterCid  = EC_ActivityFubenType.ARENA
        -- local levelCid    = 620105
        Utils:openView("fuben.FubenArenaSquadView")

    end)

    self.Button_task:onClick(function()
        --Box("task")
        Utils:openView("fuben.FubenArenaTaskView")
    end)
    
    self.Button_match:onClick(function()

        if self:check() then 
            ArenaDataMgr:send_ARENA_REQ_MATCH_ARENA_PLAYER()
        else
            Utils:showTips(202002)
        end

        --ArenaDataMgr:send_ARENA_REQ_ARENA_RECORD()
        -- self:showMatchCountDown()
    end)

    self.Button_fame:onClick(function()
        --Box("task")
        Utils:openView("fuben.FubenArenaFameHallView")
    end)

    ArenaDataMgr:send_ARENA_REQ_ARENA_RANK_LIST()
end

function FubenArenaView:removeEvents()
    self:removeTimer()
end

function FubenArenaView:onMatchTime()
    if self.countDownTime > 0 then 
        self.countDownTime =  self.countDownTime - 1
        self.Label_countTime:setTextById(290000103 , self.countDownTime)
    end
    if self.countDownTime <= 0 then 
        self.Panel_match:hide()
        self:removeTimer()
        self:fightStart()
    end
end


function FubenArenaView:fightStart()
    local arenaData  = ArenaDataMgr:getArenaData()
    local segmentCfg = TabDataMgr:getData("RankReward" ,arenaData.curCycle.segment)
    local levelCid   = segmentCfg.dungId[math.random(1,#segmentCfg.dungId)]
    battleController.requestFightStart(levelCid)
    -- Box("请求战斗开始")
end


function FubenArenaView:getCostData(segment)
    local segmentCfg = TabDataMgr:getData("RankReward" ,segment)
    local levelCid   = segmentCfg.dungId[1] or 450001
    local dungeonCfg = TabDataMgr:getData("DungeonLevel",levelCid)
    local costs      = dungeonCfg.cost
    if costs and costs[1] then 
        return costs[1][1] ,costs[1][2] 
    end
end


function FubenArenaView:check()
    local arenaData         =  ArenaDataMgr:getArenaData()
    local itemId ,itemCount = self:getCostData(arenaData.curCycle.segment)
    dump({itemId ,itemCount})
    if itemId then 
        return GoodsDataMgr:getItemCount(itemId) >= itemCount
    end
    return true
end



function FubenArenaView:removeTimer()
    if self.matchTimer then
        TFDirector:removeTimer(self.matchTimer)
        self.matchTimer = nil
    end
end 

function FubenArenaView:onMatchSuccess()

    -- self:showMatchCountDown()

    Utils:openView("fuben.FubenArenaMatchView")


end

--排行刷新
function FubenArenaView:onUpdateRank()
    self:showRank()
end

--任务状态刷新
function FubenArenaView:onTaskUpdateEvent(tasks)
    self.Image_task_red:setVisible(ArenaDataMgr:hasReward())
end


return FubenArenaView
