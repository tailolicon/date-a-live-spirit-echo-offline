
local FubenArenaRankkView = class("FubenArenaRankkView", BaseLayer)

function FubenArenaRankkView:initData(levelGroupId, diff)
    self.tabIndex = 0
end

function FubenArenaRankkView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaRank")
end

function FubenArenaRankkView:initUI(ui)
	self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Image_content = TFDirector:getChildByPath(self.Panel_root , "Image_content")
    self.Button_close = TFDirector:getChildByPath(self.Image_content , "Button_close")
    self.Panel_ScoreItem =  TFDirector:getChildByPath(self.Image_content , "Panel_ScoreItem")
    self.Label_none =  TFDirector:getChildByPath(self.Image_content , "Label_none"):hide()
    self.Label_tip =  TFDirector:getChildByPath(self.Image_content , "Label_tip")
    self.Label_tip:setTextById(63992)
    self.tab1 = TFDirector:getChildByPath(self.Image_content , "tab1")
   
    self.tab2 = TFDirector:getChildByPath(self.Image_content , "tab2")
    self.selected1= TFDirector:getChildByPath(self.tab1 , "selected")
    self.selected2= TFDirector:getChildByPath(self.tab2 , "selected")
    self.ScrollView  = TFDirector:getChildByPath(self.Image_content , "ScrollView")

    self.ListView = UIListView:create(self.ScrollView)
    self.ListView:setItemsMargin(2)
    self.recordDatas =  {{score = 10 },{score = 0},{score = 10},{score = -10},{score = 5}}
    self:setLang()
    self:selectTab(1)
end

function FubenArenaRankkView:setLang()
    self.Label_tip:setTextById(3202069)

    local Label_main_title = TFDirector:getChildByPath(self.Image_content , "Label_main_title")
    -- local Label_tip = TFDirector:getChildByPath(self.Image_content , "Label_tip")
    local Label_title_rank = TFDirector:getChildByPath(self.Image_content , "Label_title_rank")
    local Label_title_name = TFDirector:getChildByPath(self.Image_content , "Label_title_name")
    local Label_title_grade = TFDirector:getChildByPath(self.Image_content , "Label_title_grade")
    local Label_title_score = TFDirector:getChildByPath(self.Image_content , "Label_title_score")
    local Label_none = TFDirector:getChildByPath(self.Image_content , "Label_none")


    -- local  Label_title_grade = TFDirector:getChildByPath(self.Image_content , "Label_title_grade")
    -- local  Label_title_grade = TFDirector:getChildByPath(self.Image_content , "Label_title_grade")

    self.tab1Name_cn = TFDirector:getChildByPath(self.tab1 , "label_cn")
    self.tab1Name_en = TFDirector:getChildByPath(self.tab1 , "label_en")
    self.tab2Name_cn = TFDirector:getChildByPath(self.tab2 , "label_cn")
    self.tab2Name_en = TFDirector:getChildByPath(self.tab2 , "label_en")


    local isCH = Utils:isCH()
    self.tab1Name_cn:setVisible(isCH)
    self.tab2Name_cn:setVisible(isCH)
    self.tab1Name_en:setVisible(not isCH)
    self.tab2Name_en:setVisible(not isCH)
    

    if isCH then
        self.tab1Name_cn:setTextById(290000093)
        self.tab2Name_cn:setTextById(290000094)
    else
        self.tab1Name_en:setTextById(290000093)
        self.tab2Name_en:setVisible(290000094)
    end

    Label_title_rank:setTextById(12101042) 
    Label_title_name:setTextById(290000089) 
    Label_title_grade:setTextById(290000095) 
    Label_title_score:setTextById(13033)  
    Label_main_title:setTextById(290000092) 

    Label_none:setTextById(290000096)

end


function FubenArenaRankkView:selectTab(tabIndex)
    if self.tabIndex == tabIndex then 
        return
    end
    self.tabIndex = tabIndex
    self.selected1:setVisible(self.tabIndex == 1 )
    self.selected2:setVisible(self.tabIndex == 2)
    self:refreshView()
end


function FubenArenaRankkView:getRankList()
    local data  = ArenaDataMgr:getRankData() 
    if self.tabIndex == 1 then  --上期
        return data.lastTopRank or {}
    else --当前
        return data.topRank or {}
    end
end

function FubenArenaRankkView:getOwnRank()
    local data  = ArenaDataMgr:getRankData() 
    if self.tabIndex == 1 then  --上期
        return data.curLastTopRank
    else --当前
        return data.curTopRank
    end
end


function FubenArenaRankkView:refreshView()
    local rankDatas = self:getRankList()
    local items = self.ListView:getItems()
    local gap = #rankDatas - #items
    for i = 1, math.abs(gap) do
        if gap < 0 then
            self.ListView:removeItem(1)
        else
            local Panel_Item = self.Panel_ScoreItem:clone():show()
            self.ListView:pushBackCustomItem(Panel_Item)
        end
    end
    for i, v in ipairs(rankDatas) do
        local Panel_Item = self.ListView:getItem(i)
        self:updateItem(Panel_Item, v)
    end
    self.Label_none:setVisible(#rankDatas < 1)

    local ownRank = self:getOwnRank()
    if ownRank then 
        self:updateItem(self.Panel_ScoreItem, ownRank ,true)
    else
        self.Panel_ScoreItem:hide()
    end
end

-- local function _scoreToText(Label_score ,score)
--     if score > 0 then 
--         Label_score:setText("+"..score)
--         Label_score:setFontColor( ccc3(0,255,0))
    
--     elseif score < 0 then
--         Label_score:setText("-"..math.abs(score))
--         Label_score:setFontColor(ccc3(255,0,0))
--     else
--         Label_score:setText("+"..score)
--         Label_score:setFontColor( ccc3(255,255,255))
--     end
-- end


function FubenArenaRankkView:updateItem(item, data ,isOwn)
    local Image_head   = TFDirector:getChildByPath(item , "Image_head")
    local Image_icon   = TFDirector:getChildByPath(Image_head , "Image_icon")
    local Image_icon_frame   = TFDirector:getChildByPath(Image_head , "Image_icon_frame")
    local Label_level  = TFDirector:getChildByPath(item , "Label_level")
    local Label_name   = TFDirector:getChildByPath(item , "Label_name")
    local Label_rank  = TFDirector:getChildByPath(item , "Label_rank")
    local Image_rank1  = TFDirector:getChildByPath(item , "Image_rank1")
    local Image_rank2  = TFDirector:getChildByPath(item , "Image_rank2")
    local Image_rank3  = TFDirector:getChildByPath(item , "Image_rank3")
    local Label_score  = TFDirector:getChildByPath(item , "Label_score")
    local Image_segment = TFDirector:getChildByPath(item , "Image_segment")
    local Label_segment   = TFDirector:getChildByPath(item , "Label_segment")
    local Panel_bg_own = TFDirector:getChildByPath(item , "Image_bg2")
    Panel_bg_own:setVisible(isOwn)


    Label_score:setText(data.arenaScore)
    Label_segment:setTextById(ArenaDataMgr:segmentName(data.segment))
    Image_segment:setTexture(ArenaDataMgr:segmentIcon(data.segment))
    Image_segment:setScale(0.5)
    Label_name:setText(data.pName or "")
    Label_level:setTextById(800006, data.level)
    if data.rank == 0 or data.rank > 3 then
        if data.rank == 0 then
            Label_rank:setTextById(310012)
        else
            Label_rank:setText(tostring(data.rank))
        end
        Label_rank:show()
    else
        Label_rank:hide()
        -- Label_rank:setText(data.rank)
    end

    Image_rank1:setVisible(data.rank== 1)
    Image_rank2:setVisible(data.rank== 2)
    Image_rank3:setVisible(data.rank== 3)

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

function FubenArenaRankkView:registerEvents()
    EventMgr:addEventListener(self, EV_ARENA_RANK_UPDATE, handler(self.onRankUpdate, self))

    self.tab1:onClick(function ()
        self:selectTab(1)
    end)

    self.tab2:onClick(function ()
        self:selectTab(2)
    end)


    self.Button_close:onClick(function()
            AlertManager:close()
    end)

    ArenaDataMgr:send_ARENA_REQ_ARENA_RANK_LIST()
end

function FubenArenaRankkView:onRankUpdate()
    self:refreshView()
end

return FubenArenaRankkView
