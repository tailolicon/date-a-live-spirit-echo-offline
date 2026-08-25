
local battleController = require("lua.logic.battle.BattleController")
local FubenArenaMatchView = class("FubenArenaMatchView", BaseLayer)

function FubenArenaMatchView:initData()

    --进入战斗倒计时
    self.countDownTime = 5
end

function FubenArenaMatchView:getClosingStateParams()
    return {FubenDataMgr.selectChapter_}
end

function FubenArenaMatchView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaMatch")
end

function FubenArenaMatchView:initUI(ui)
    self.super.initUI(self, ui)

    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    --匹配成功后 倒计时进入UI
    self.Panel_match = TFDirector:getChildByPath(self.Panel_root, "Panel_match")
    self.Panel_match_content= TFDirector:getChildByPath(self.Panel_match, "Panel_match_content")
    self.Label_countTime = TFDirector:getChildByPath(self.Panel_match_content, "Label_countTime")
    self.Label_match_success  = TFDirector:getChildByPath(self.Panel_match_content, "Label_match_success")
    self.Label_match_success:setTextById(290000104)
    self:showMatchCountDown()
end





function FubenArenaMatchView:showMatchCountDown()
    local matchPlayer  = ArenaDataMgr:getMatchData()
    -- self.Panel_match:setVisible(true)

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


    if matchPlayer then 
        Label_name2:setText(matchPlayer.pName)
        Label_level2:setTextById(700034,matchPlayer.level)
        local acatarPath2  = AvatarDataMgr:getAvatarIconPath(matchPlayer.headId)
        Image_icon2:setTexture(acatarPath2)
    end


end






function FubenArenaMatchView:registerEvents()


end

function FubenArenaMatchView:removeEvents()
    self.super.removeEvents(self)
    self:removeTimer()
end

function FubenArenaMatchView:onMatchTime()
    if self.countDownTime > 0 then 
        self.countDownTime =  self.countDownTime - 1
        self.Label_countTime:setTextById(290000103,self.countDownTime)
    end
    if self.countDownTime <= 0 then 
        -- self.Panel_match:hide()
        self:removeTimer()
        self:fightStart()
    end
end


function FubenArenaMatchView:fightStart()
    local arenaData  = ArenaDataMgr:getArenaData()
    if arenaData then 
        local segmentCfg = TabDataMgr:getData("RankReward" ,arenaData.curCycle.segment)
        local levelCid   = segmentCfg.dungId[math.random(1,#segmentCfg.dungId)]
        battleController.requestFightStart(levelCid)
    end
    AlertManager:closeLayer(self)
    -- Box("请求战斗开始")
end









function FubenArenaMatchView:removeTimer()
    if self.matchTimer then
        TFDirector:removeTimer(self.matchTimer)
        self.matchTimer = nil
    end
end 



return FubenArenaMatchView
