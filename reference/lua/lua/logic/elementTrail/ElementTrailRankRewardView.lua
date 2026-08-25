
local ElementTrailRankRewardView = class("ElementTrailRankRewardView", BaseLayer)


local function createTempData(rank)
    local data = {}
    data.rank  = rank 
    data.score =  999     --[分数(dungeonID,用于显示通关层数信息)    //分数(dungeonID,用于显示通关层数信息)]
    data.playerId  =  111  --[玩家id]
    data.name  = "[玩家名字]"
    data.lv    = 18       --[等级]
    data.portraitCid      = AvatarDataMgr:getCurUsingCid()
    data.portraitFrameCid = AvatarDataMgr:getCurUsingFrameCid()
    return data
end


function ElementTrailRankRewardView:initData()


    local datas = TabDataMgr:getData("ElementTrainRankReward")
    self.rankTypes = {}
    for i,v in ipairs(datas) do    
        table.insert(self.rankTypes,v)
    end    
    table.sort(self.rankTypes,function ( a,b)
        return a.id < b.id
    end)

    --排行刷新的标识
    self.rankTypeUpdated = self.rankTypeUpdated or {}

    --TODO 生成临时数据
    self.elementTrainRankDatas = {}
    for _,v in ipairs(self.rankTypes) do
        self.elementTrainRankDatas[v.id] = {}
        for i = 1, #v.rankAward, 2 do
            -- 提取当前组的 排行名次 和 奖励配置
            local _rank = v.rankAward[i]
            local _s_rank = v.rankAward[i-2] or 0
            if _s_rank > 0 and (_rank - _s_rank)  > 1 then 
                 _rank = (_s_rank+1) .."-" .. _rank 
            -- else
  
            end

            if ( #v.rankAward - i) < 2  then 
                _rank = ">".. _s_rank
            end

            local _award = v.rankAward[i + 1]
       
            -- 封装成结构化子表，插入新数组
            table.insert(self.elementTrainRankDatas[v.id], {
                rank  = _rank,   -- 排行名次
                rankIndex =  v.rankAward[i],
                award = _award  -- 对应奖励
            })
        end

    end
  
-- dump(self.elementTrainRankDatas)
        -- for ii=1,3 do
        --     table.insert(self.elementTrainRankDatas[v.id],createTempData((i-1)*10+ ii))
        -- end
    -- end

end

function ElementTrailRankRewardView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.elementTrailRankRewardView")
end

function ElementTrailRankRewardView:initUI(ui)
	self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_prefab = TFDirector:getChildByPath(ui, "Panel_prefab"):hide()
    self.Panel_reward_item = TFDirector:getChildByPath(self.Panel_prefab, "Panel_reward_item")
    self.Button_grade  = TFDirector:getChildByPath(self.Panel_prefab, "Button_grade")

    local Image_bg = TFDirector:getChildByPath(self.Panel_root, "Image_bg")
    self.Button_close  = TFDirector:getChildByPath(Image_bg, "Button_close")

    local Panel_titles = TFDirector:getChildByPath(Image_bg, "Panel_titles")
    local Lang_titles  = {2108166,12101042 ,14220070}
    for i=1,3 do
        local Label_title = TFDirector:getChildByPath(Panel_titles, "Label_title"..i)
        Label_title:setSkewX(10)
        Label_title:setTextById(Lang_titles[i])
    end


    -- self.Label_tip = TFDirector:getChildByPath(Image_bg, "Label_tip")
    -- self.Label_tip:setTextById(63991)
    self.ScrollViewReward = TFDirector:getChildByPath(Image_bg, "ScrollViewReward")
    -- self.ListView = UIListView:create(self.ScrollViewReward)

    self:initTableView()

    self.ScrollViewGrade  = TFDirector:getChildByPath(Image_bg, "ScrollViewGrade")
    self.ListViewGrade = UIListView:create(self.ScrollViewGrade)
    self.buttonGrades = {}

    -- local attrNames = {"暗","风","光","混乱","雷","霜","炎"}
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

function ElementTrailRankRewardView:setSelect(selectId)
    if self.selectId == selectId then 
        return
    end
    self.selectId = selectId
    local items = self.ListViewGrade:getItems()
    for i,v in ipairs(items) do
        v.Image_select:setVisible(v.bindID == self.selectId)
    end
    self.tableView:reloadData()
    --切换对应段位的奖励
    -- self:refreshView()
    if not self.rankTypeUpdated[self.selectId] then
        self.rankTypeUpdated[self.selectId] = true
        -- ActivityDataMgr:reqElementTrailRank(self.selectId)
    end 
end

function ElementTrailRankRewardView:refreshView()

end


function ElementTrailRankRewardView:getData()
    return self.elementTrainRankDatas[self.selectId] or {}
end
function ElementTrailRankRewardView:initTableView()
    self.tableView                  = Utils:scrollView2TableView( self.ScrollViewReward)
    self.tableView:setDirection(TFTableView.TFSCROLLVERTICAL)
    self.tableView:setVerticalFillOrder(TFTableView.TFTabViewFILLTOPDOWN)
    self.tableView:addMEListener(TFTABLEVIEW_SIZEFORINDEX, handler(self.tableCellSize,self))
    self.tableView:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, handler(self.numberOfCells,self))
    self.tableView:addMEListener(TFTABLEVIEW_SIZEATINDEX, handler(self.tableCellAtIndex,self))
end

function ElementTrailRankRewardView:numberOfCells(tableView)
    local data  = self:getData() or {}
    return #data
end

function ElementTrailRankRewardView:tableCellSize(tableView)

    local size = self.Panel_reward_item:getContentSize()
    return size.height, size.width
end

function ElementTrailRankRewardView:tableCellAtIndex(tableView, idx)

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

function ElementTrailRankRewardView:initCell(item, data)

    item.Label_rank         = TFDirector:getChildByPath(item, "Label_rank")

    item.Image_rank1        = TFDirector:getChildByPath(item, "Image_rank1")
    item.Image_rank2        = TFDirector:getChildByPath(item, "Image_rank2")
    item.Image_rank3        = TFDirector:getChildByPath(item, "Image_rank3")


    --     item.Label_level        = TFDirector:getChildByPath(item, "Label_level")
    -- item.Label_name         = TFDirector:getChildByPath(item, "Label_name")
    -- item.Image_head         = TFDirector:getChildByPath(item, "Image_head")
    -- item.Image_frame        = TFDirector:getChildByPath(item.Image_head , "Image_frame")



local ScrollView_reward = TFDirector:getChildByPath( item , "ScrollView_reward")
item.listView  = UIListView:create(ScrollView_reward)
item.listView:setItemsMargin(2)
        



end







function ElementTrailRankRewardView:updateCell(item, idx)
        local datas = self:getData()
        local data = datas[idx] 
        -- dump(data)
        item.Label_rank:setText(""..data.rank)
        -- item.Label_rank:setVisible(data.rank > 3)
        -- item.Image_rank1:setVisible(data.rank == 1)
        -- item.Image_rank2:setVisible(data.rank == 2)
        -- item.Image_rank3:setVisible(data.rank == 3)

        -- item.Label_level:setText(data.score)  
        -- item.Label_name:setText(data.name)    
        -- local frame_path = AvatarDataMgr:getAvatarFrameIconPath(data.portraitFrameCid)
        -- local icon       = AvatarDataMgr:getAvatarIconPath(data.portraitCid)
        -- item.Image_head:setTexture(icon)
        -- item.Image_frame:setTexture(frame_path)

    local items = item.listView:getItems()

    local itemCount =  table.count(data.award)

    local needAdd = itemCount - #items
    if needAdd > 0 then 
        for i=1,needAdd do
            local panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
            panel_goodsItem:setScale(0.7)
            item.listView:pushBackCustomItem(panel_goodsItem)
        end
    end
    items = item.listView:getItems()
    for i,v in ipairs(items) do
        v:hide()
    end

    -- item.listView:removeAllItems()
    local itemIndex = 1
    for k, v in pairs(data.award) do  --需要奖励列表
        local panel_goodsItem = item.listView:getItem(itemIndex)
        panel_goodsItem:show()
        PrefabDataMgr:setInfo(panel_goodsItem, tonumber(k ), tonumber(v))
        itemIndex = itemIndex + 1
    end
end

-- function ElementTrailRankRewardView:onRankUpdate(rankType)
--     -- self.elementTrainRankDatas = AvatarDataMgr:getElementTrailRankDatas()
--     -- self.tableView:reloadData()
-- end

function ElementTrailRankRewardView:registerEvents()
    -- EventMgr:addEventListener(self, EV_ACTIVITY_ELEMENT_TRAIL_RANK_UPDATE, handler(self.onRankUpdate, self))
    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)
end

return ElementTrailRankRewardView
