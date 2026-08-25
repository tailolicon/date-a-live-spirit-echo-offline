
local ElementTrailRankView = class("ElementTrailRankView", BaseLayer)


function ElementTrailRankView:createSelfData()
    local data = {}
    data.rank  = 0 
    data.score = 0     --[分数(dungeonID,用于显示通关层数信息)    //分数(dungeonID,用于显示通关层数信息)]
    data.playerId  =  MainPlayer:getPlayerId()
    data.name  = MainPlayer:getPlayerName()
    data.lv    = MainPlayer:getPlayerLv()
    data.portraitCid      = AvatarDataMgr:getCurUsingCid()
    data.portraitFrameCid = AvatarDataMgr:getCurUsingFrameCid()
    return data
end


function ElementTrailRankView:initData()


    local ElementTrainDungeons = TabDataMgr:getData("ElementTrainDungeon")
    self.rankTypes = {}
    for i,v in ipairs(ElementTrainDungeons) do    
        table.insert(self.rankTypes,v)
    end    
    table.sort(self.rankTypes,function ( a,b)
        return a.id < b.id
    end)

    --排行刷新的标识
    self.rankTypeUpdated = self.rankTypeUpdated or {}

    self.elementTrainRankDatas = ActivityDataMgr:getElementTrailRankDatas()

    -- --TODO 生成临时数据
    -- self.elementTrainRankDatas = {}
    -- for i,v in ipairs(self.rankTypes) do
    --     self.elementTrainRankDatas[v.id] = {}
    --     for ii=1,3 do
    --         table.insert(self.elementTrainRankDatas[v.id],createSelfData((i-1)*10+ ii))
    --     end
    -- end

end

function ElementTrailRankView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    -- self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.elementTrailRankView")
end

function ElementTrailRankView:initUI(ui)
	self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_prefab = TFDirector:getChildByPath(ui, "Panel_prefab"):hide()
    self.Panel_reward_item = TFDirector:getChildByPath(self.Panel_prefab, "Panel_reward_item")
    self.Button_grade  = TFDirector:getChildByPath(self.Panel_prefab, "Button_grade")

    local Image_bg = TFDirector:getChildByPath(self.Panel_root, "Image_bg")
    self.Button_reward = TFDirector:getChildByPath(Image_bg, "Button_reward")

    self.Label_reward = TFDirector:getChildByPath(self.Button_reward, "Label_reward")
    self.Label_reward:setSkewX(10)
    self.Label_reward:setTextById(14220070)

    local Panel_titles = TFDirector:getChildByPath(Image_bg, "Panel_titles")
    local Lang_titles  = {12101042,290000089 ,320008}
    for i=1,3 do
        local Label_title = TFDirector:getChildByPath(Panel_titles, "Label_title"..i)
        Label_title:setSkewX(10)

        Label_title:setTextById(Lang_titles[i])
    end


    self.Panel_reward_item_self = TFDirector:getChildByPath(Image_bg, "Panel_reward_item_self")
    self.Panel_reward_item_self.Label_rank         = TFDirector:getChildByPath(self.Panel_reward_item_self, "Label_rank")
    self.Panel_reward_item_self.Label_level        = TFDirector:getChildByPath(self.Panel_reward_item_self, "Label_level")
    self.Panel_reward_item_self.Label_name         = TFDirector:getChildByPath(self.Panel_reward_item_self, "Label_name")
    self.Panel_reward_item_self.Image_rank1        = TFDirector:getChildByPath(self.Panel_reward_item_self, "Image_rank1")
    self.Panel_reward_item_self.Image_rank2        = TFDirector:getChildByPath(self.Panel_reward_item_self, "Image_rank2")
    self.Panel_reward_item_self.Image_rank3        = TFDirector:getChildByPath(self.Panel_reward_item_self, "Image_rank3")
    self.Panel_reward_item_self.Image_head         = TFDirector:getChildByPath(self.Panel_reward_item_self, "Image_head")
    self.Panel_reward_item_self.Image_frame        = TFDirector:getChildByPath(self.Panel_reward_item_self.Image_head , "Image_frame")

    -- self.Label_tip = TFDirector:getChildByPath(Image_bg, "Label_tip")
    -- self.Label_tip:setTextById(63991)
    self.ScrollViewReward = TFDirector:getChildByPath(Image_bg, "ScrollViewReward")
    -- self.ListView = UIListView:create(self.ScrollViewReward)

    self:initTableView()

    -- self.Button_close = TFDirector:getChildByPath(Image_bg, "Button_close")
    self.ScrollViewGrade  = TFDirector:getChildByPath(Image_bg, "ScrollViewGrade")
    self.ListViewGrade = UIListView:create(self.ScrollViewGrade)
    self.buttonGrades = {}

    local attrNames = {"暗","风","光","混乱","雷","霜","炎"}
    for i,v in ipairs(self.rankTypes) do
  
        local item = self.Button_grade:clone():show()
        item.bindID            = v.id
        item.Image_select      = TFDirector:getChildByPath(item, "Image_select")
        item.Image_normal      = TFDirector:getChildByPath(item, "Image_normal")
        item.Lable_name        = TFDirector:getChildByPath(item.Image_normal, "Label_name")
        item.Label_name_select = TFDirector:getChildByPath( item.Image_select , "Label_name_select")
        -- item.Lable_name:setTextById(v.attrName)

        item.Lable_name:setSkewX(10)
        item.Label_name_select:setSkewX(10)
        --TODO 这里名字是零时的
        -- item.Lable_name:setText(attrNames[i])
        -- item.Label_name_select:setText(attrNames[i])
        item.Lable_name:setTextById(v.rankeName)
        item.Label_name_select:setTextById(v.rankeName)
        
        item:onClick(function ()
            self:setSelect(item.bindID )
        end)
        self.ListViewGrade:pushBackCustomItem(item)
    end

    self:setSelect(self.rankTypes[1].id)

    -- self.tableView:reloadData()
end


function ElementTrailRankView:refreshSelfRank()

        local datas = self:getData()

        local data  = self:createSelfData()
        for i,v in ipairs(datas) do
           if data.playerId == v.playerId then 
                data = v
                break
           end
        end
        -- dump(data)
        if data.rank > 0 then 
            self.Panel_reward_item_self.Label_rank:setText(data.rank)
  
        else
            self.Panel_reward_item_self.Label_rank:setTextById(16000305) -- "未上榜"
        end


        self.Panel_reward_item_self.Label_rank:setVisible(data.rank > 3 or data.rank < 1)
        self.Panel_reward_item_self.Image_rank1:setVisible(data.rank == 1)
        self.Panel_reward_item_self.Image_rank2:setVisible(data.rank == 2)
        self.Panel_reward_item_self.Image_rank3:setVisible(data.rank == 3)

        if data.score > 0 then 
            local levelCfg = TabDataMgr:getData("ElementTrainDungeonLevel",data.score)
            local levelName = levelCfg.levelNumber[1].."-" ..levelCfg.levelNumber[2]
            self.Panel_reward_item_self.Label_level:setText(levelName)  
        else
            self.Panel_reward_item_self.Label_level:setTextById(290000088) 
        end
        self.Panel_reward_item_self.Label_name:setText(data.name)    
        local frame_path = AvatarDataMgr:getAvatarFrameIconPath(data.portraitFrameCid)
        local icon       = AvatarDataMgr:getAvatarIconPath(data.portraitCid)
        self.Panel_reward_item_self.Image_head:setTexture(icon)
        self.Panel_reward_item_self.Image_frame:setTexture(frame_path)


end

function ElementTrailRankView:setSelect(selectId)
    if self.selectId == selectId then 
        return
    end
    self.selectId = selectId
    local items = self.ListViewGrade:getItems()
    for i,v in ipairs(items) do
        v.Image_select:setVisible(v.bindID == self.selectId)
    end
    self.tableView:reloadData()
    self:refreshSelfRank()
    --切换对应段位的奖励
    -- self:refreshView()
    if not self.rankTypeUpdated[self.selectId] then
        self.rankTypeUpdated[self.selectId] = true
        ActivityDataMgr:reqElementTrailRank(self.selectId)
    end 
end

function ElementTrailRankView:refreshView()

end


function ElementTrailRankView:getData()
    return self.elementTrainRankDatas[self.selectId] or {}
end
function ElementTrailRankView:initTableView()
    self.tableView                  = Utils:scrollView2TableView( self.ScrollViewReward)
    self.tableView:setDirection(TFTableView.TFSCROLLVERTICAL)
    self.tableView:setVerticalFillOrder(TFTableView.TFTabViewFILLTOPDOWN)
    self.tableView:addMEListener(TFTABLEVIEW_SIZEFORINDEX, handler(self.tableCellSize,self))
    self.tableView:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, handler(self.numberOfCells,self))
    self.tableView:addMEListener(TFTABLEVIEW_SIZEATINDEX, handler(self.tableCellAtIndex,self))
end

function ElementTrailRankView:numberOfCells(tableView)
    local data  = self:getData() or {}
    return #data
end

function ElementTrailRankView:tableCellSize(tableView)

    local size = self.Panel_reward_item:getContentSize()
    return size.height, size.width
end

function ElementTrailRankView:tableCellAtIndex(tableView, idx)

    local cell = tableView:dequeueCell()
    local item = nil
    if nil == cell then

        cell = TFTableViewCell:create()
        item = self.Panel_reward_item:clone()
        item.idx = idx
        item:show()
        item:setPosition(ccp(0, 0))
        cell:addChild(item)
        cell.item = item

        self:initCell(item) 
    else
        item = cell.item
    end
    self:updateCell(item, (idx + 1))
    return cell
end

function ElementTrailRankView:initCell(item, data)

    item.Label_rank         = TFDirector:getChildByPath(item, "Label_rank")
    item.Label_level        = TFDirector:getChildByPath(item, "Label_level")
    item.Label_name         = TFDirector:getChildByPath(item, "Label_name")
    item.Image_rank1        = TFDirector:getChildByPath(item, "Image_rank1")
    item.Image_rank2        = TFDirector:getChildByPath(item, "Image_rank2")
    item.Image_rank3        = TFDirector:getChildByPath(item, "Image_rank3")
    item.Image_head         = TFDirector:getChildByPath(item, "Image_head")
    item.Image_frame        = TFDirector:getChildByPath(item.Image_head , "Image_frame")
end







function ElementTrailRankView:updateCell(item, idx)
        local datas = self:getData()
        local data = datas[idx] 
        -- dump(data)
        item.Label_rank:setText(""..data.rank)
        item.Label_rank:setVisible(data.rank > 3)
        item.Image_rank1:setVisible(data.rank == 1)
        item.Image_rank2:setVisible(data.rank == 2)
        item.Image_rank3:setVisible(data.rank == 3)

        local levelCfg = TabDataMgr:getData("ElementTrainDungeonLevel",data.score)

        local levelName = levelCfg.levelNumber[1].."-" ..levelCfg.levelNumber[2]
        item.Label_level:setText(levelName)  
        item.Label_name:setText(data.name)    
        local frame_path = AvatarDataMgr:getAvatarFrameIconPath(data.portraitFrameCid)
        local icon       = AvatarDataMgr:getAvatarIconPath(data.portraitCid)
        item.Image_head:setTexture(icon)
        item.Image_frame:setTexture(frame_path)



        -- Box("222")
        item.Image_head:setTouchEnabled(data.playerId ~= MainPlayer:getPlayerId())
        item.Image_head:onClick(function()
            MainPlayer:sendPlayerId(data.playerId)
        end)
    

end

function ElementTrailRankView:onRankUpdate(rankType)
    self.elementTrainRankDatas = ActivityDataMgr:getElementTrailRankDatas()
    self.tableView:reloadData()
    self:refreshSelfRank()
end

function ElementTrailRankView:registerEvents()
    EventMgr:addEventListener(self, EV_ACTIVITY_ELEMENT_TRAIL_RANK_UPDATE, handler(self.onRankUpdate, self))
    EventMgr:addEventListener(self, EV_RECV_PLAYERINFO, handler(self.onQueryInfoEvent, self))
    self.Button_reward:onClick(function (  )
        Utils:openView("elementTrail.ElementTrailRankRewardView")
    end)
end

function ElementTrailRankView:onQueryInfoEvent(playerInfo)
    local view = AlertManager:getLayer(-1)
    if view.__cname == self.__cname then
        Utils:openView("chat.PlayerInfoView", playerInfo)
    end
end


return ElementTrailRankView
