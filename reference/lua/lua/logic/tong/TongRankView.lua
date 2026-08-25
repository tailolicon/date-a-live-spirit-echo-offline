
local TongRankView = class("TongRankView", BaseLayer)

local askFlag = {
    normal = 1,
    up = 2,
    down = 3,
    jump = 4
}

function TongRankView:initData()

    self.rankPageNum = 20
    self.rankTitle = {}
    local activityId = ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.TONG)[1]
    local activityInfo = ActivityDataMgr2:getActivityInfo(activityId)
    if activityInfo and activityInfo.extendData then
        self.rankTitle = activityInfo.extendData.rankTitle
        self.rankPageNum = activityInfo.extendData.rankPageNum
    end
    self.vitMaxDungonInfo = TabDataMgr:getData("DungeonInfoOfVITmax")

    self.recordPage = {}
end

function TongRankView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.tong.tongRankView")
    self.block = AlertManager.BLOCK_CLOSE
end

function TongRankView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close"):hide()
    local ScrollView_type       = TFDirector:getChildByPath(ui, "ScrollView_type")
    self.UIListView_type        = UIListView:create(ScrollView_type)

    self.Panel_rankItem         = TFDirector:getChildByPath(ui, "Panel_rankItem")
    self.Button_type            = TFDirector:getChildByPath(ui, "Button_type")

    self.Panel_titleBoss        = TFDirector:getChildByPath(ui, "Panel_titleBoss")
    self.Panel_titleSpeical     = TFDirector:getChildByPath(ui, "Panel_titleSpeical")
    self.Label_tip              = TFDirector:getChildByPath(ui, "Label_tip")

    self.Label_time_tip         = TFDirector:getChildByPath(ui, "Label_time_tip")

    local ScrollView_rank       = TFDirector:getChildByPath(ui, "ScrollView_rank")
    self.UIListView_rank        = UIListView:create(ScrollView_rank)
    self.UIListView_rank:setItemModel(self.Panel_rankItem)

    self.Panel_my_rank          = TFDirector:getChildByPath(ui, "Panel_my_rank")
    self.Panel_rank             = TFDirector:getChildByPath(self.Panel_my_rank, "Panel_rank")
    self.Label_nil              = TFDirector:getChildByPath(self.Panel_my_rank, "Label_nil")
    self.Label_verify           = TFDirector:getChildByPath(self.Panel_my_rank, "Label_verify")

    self:initRankTypeList()

end

function TongRankView:initRankTypeList()

    self.Label_time_tip:setTextById(13206070)

    self.rankType_ = {}
    for i=1,2 do
        local name = i==1 and 13206071 or 13206072
        name = TextDataMgr:getText(name)
        table.insert(self.rankType_,{rankType = i, name = name, dungeonId = 0})
    end

    for k,v in ipairs(self.rankTitle) do
        local cfg = self.vitMaxDungonInfo[v]
        if cfg then
            local name = TextDataMgr:getText(13206073)..TextDataMgr:getText(cfg.eliteBossName)
            table.insert(self.rankType_,{rankType = v, name = name, dungeonId = v})
        end
    end

    self.rankItem_ = {}
    for k,v in ipairs(self.rankType_) do
        local item = self.Button_type:clone()
        self.UIListView_type:pushBackCustomItem(item)

        local Label_text      = TFDirector:getChildByPath(item, "Label_text")
        local Image_select    = TFDirector:getChildByPath(item, "Image_select")

        Label_text:setText(v.name)
        table.insert(self.rankItem_,{root = item, select = Image_select,tex = Label_text})
    end

    self:chooseList(1)
end

function TongRankView:chooseList(index)

    self.selectIndex = index

    for k,v in ipairs(self.rankItem_) do
        v.select:setVisible(k == index)
        local color = k == index and ccc3(255,255,255) or ccc3(18,98,128)
        v.tex:setFontColor(color)
    end

    local typeData = self.rankType_[index]
    if not typeData then
        return
    end

    self.rankType    = typeData.rankType

    self.Panel_titleBoss:setVisible(typeData.dungeonId  == 0)
    self.Panel_titleSpeical:setVisible(typeData.dungeonId ~= 0)

    local page = self.recordPage[self.rankType] or 1
    print("chooseList page",page)
    local data = TongDataMgr:getRankData(self.rankType,page) or {}
    if #data == 0 then
        self.askRankData = false
        TongDataMgr:Send_getRankInfo(self.rankType,nil,page,askFlag.normal)
    else
        self:updateRankData(askFlag.normal,page)
    end

end

function TongRankView:updateRankData(flag,page)


    self:updateMyRankInfo()

    local isExaming = TongDataMgr:isExamineRank(self.rankType)
    if isExaming then
        self.Label_tip:show()
        self.UIListView_rank:removeAllItems()
        TongDataMgr:clearRankDataByType(self.rankType)
    else
        self.Label_tip:hide()
    end


    self.askRankData = true

    if page then
        self.recordPage[self.rankType] = page
    end

    print("updateRankData",flag,page,self.rankType)

    if flag == askFlag.down then
        self:scrollDownRankData(page)
        return
    elseif flag == askFlag.up then
        self:scrollUpRankData(page)
        return
    end

    self.UIListView_rank:removeAllItems()
    local rankData_ = TongDataMgr:getRankData(self.rankType,page) or {}

    for k,v in ipairs(rankData_) do
        local item = self.UIListView_rank:pushBackDefaultItem()
        self:updateRankItem(item, v,page)
    end

    if flag == askFlag.jump and self.myRankInfo then
        local index = self:getListIndex(self.myRankInfo.index)
        self.UIListView_rank:jumpToItem(index)
    end
end

function TongRankView:updateMyRankInfo()
    print("self.rankType",self.rankType)
    local checking = TongDataMgr:isExamineMyRank(self.rankType)
    if checking then
        self.myRankInfo = nil
        self.Panel_rank:hide()
        self.Label_nil:hide()
        self.Label_verify:show()
        TongDataMgr:clearMyRankByType(self.rankType)
        return
    end

    self.myRankInfo = TongDataMgr:getMyRankInfo(self.rankType)
    self.Label_verify:hide()
    if self.myRankInfo then
        self:updateRankItem( self.Panel_my_rank, self.myRankInfo,1)
        self.Panel_rank:show()
        self.Label_nil:hide()
    else
        self.Panel_rank:hide()
        self.Label_nil:show()
    end
end

function TongRankView:scrollDownRankData(nextPage)

    if not nextPage then
        return
    end

    local items = self.UIListView_rank:getItems()
    local lastItem = items[#items]
    if not lastItem then
        return
    end

    local page = lastItem.page
    local rankData_ = TongDataMgr:getRankData(self.rankType,nextPage) or {}
    for k,v in ipairs(rankData_) do
        self:insertRankData(#items + 1)
        local item = self.UIListView_rank:getItem(#items)
        if item then
            self:updateRankItem(item,v,nextPage)
        end
    end

    self:removeOtherPage(page - 2)
    local index = lastItem.index
    local jumpIndex = self:getListIndex(index)

    print("lastRankId",index,jumpIndex)
    self.UIListView_rank:jumpToItem(jumpIndex-1)

    local items = self.UIListView_rank:getItems()
    print("count:",#items)

end

function TongRankView:scrollUpRankData(beforePage)

    if not beforePage then
        return
    end

    local items = self.UIListView_rank:getItems()
    local firstItem = items[1]
    if not firstItem then
        return
    end

    local page = firstItem.page
    local index = firstItem.index

    local rankData_ = TongDataMgr:getRankData(self.rankType,beforePage) or {}
    for i=#rankData_,1,-1 do
        self:insertRankData(1)
        local item = self.UIListView_rank:getItem(1)
        if item then
            self:updateRankItem(item,rankData_[i],beforePage)
        end
    end

    self:removeOtherPage(page + 2)

    local jumpIndex = self:getListIndex(index)
    print("lastRankId",index)
    self.UIListView_rank:jumpToItem(jumpIndex-2)

end

function TongRankView:insertRankData(index)
    self.UIListView_rank:insertDefaultItem(index)
end

function TongRankView:updateRankItem(item,data,page)

    item.page = page
    item.index = data.index

    local Label_rank                = TFDirector:getChildByPath(item, "Label_rank")
    local Image_icon                = TFDirector:getChildByPath(item, "Image_icon")
    local Label_name                = TFDirector:getChildByPath(item, "Label_name")
    local Image_rank                = TFDirector:getChildByPath(item, "Image_rank")

    local rankIndex = data.index
    if rankIndex >= 1 and rankIndex <= 3 then
        Image_rank:setTexture("ui/tong/boss/00"..rankIndex..".png")
    else
        Label_rank:setText(rankIndex)
    end

    Label_rank:setVisible(rankIndex >3)
    Image_rank:setVisible(rankIndex >= 1 and rankIndex <= 3)
    Label_name:setText(data.name)

    Image_icon:setTexture(AvatarDataMgr:getAvatarIconPath(data.headId))

    local Panel_boss                = TFDirector:getChildByPath(item, "Panel_boss")
    local Panel_special             = TFDirector:getChildByPath(item, "Panel_special")

    local isSpecial = self.rankType ~= 1 and self.rankType ~= 2
    Panel_boss:setVisible(not isSpecial)
    Panel_special:setVisible(isSpecial)

    if not isSpecial then
        local Label_kill            = TFDirector:getChildByPath(item, "Label_kill")
        local Label_hurtValue       = TFDirector:getChildByPath(item, "Label_hurtValue")
        local Label_battle_cnt      = TFDirector:getChildByPath(item, "Label_battle_cnt")
        Label_kill:setText((data.ratio*100).."%")
        Label_hurtValue:setText(data.hurt)
        Label_battle_cnt:setText(data.count)
    else

        local Label_time            = TFDirector:getChildByPath(item, "Label_time")
        local Label_score           = TFDirector:getChildByPath(item, "Label_score")

        Label_time:setText(data.time/10)
        Label_score:setText(data.score)

        local Button_check          = TFDirector:getChildByPath(item, "Button_check")
        if Button_check then
            Button_check:onClick(function ()
                Utils:openView("tong.TongBuffListView",true,data.affix)
            end)
        end
    end

end


function TongRankView:onScrollingBottom()

    print("onScrollingBottomonScrollingBottom")
    local items = self.UIListView_rank:getItems()
    local lastItem = items[#items]
    if not lastItem then
        return
    end

    local page = lastItem.page
    local nextPage = page + 1

    if self.askRankData then
        self.askRankData = false

        local data = TongDataMgr:getRankData(self.rankType,nextPage) or {}
        if #data == 0 then
            self.askRankData = false
            TongDataMgr:Send_getRankInfo(self.rankType,nil,nextPage,askFlag.down)
        else
            self:updateRankData(askFlag.down,nextPage)
        end

    end

   --[[ local rankData_ = self.rankData[nextPage] or {}
    for k,v in ipairs(rankData_) do
        self:insertRankData(#items + 1)
        local item = self.UIListView_rank:getItem(#items)
        if item then
            self:updateRankItem(item,v)
        end
    end

    self:removeOtherPage(page - 2)
    local rankId = lastItem.rank
    local jumpIndex = self:getListIndex(rankId)

    print("lastRankId",rankId)
    self.UIListView_rank:jumpToItem(jumpIndex-2)

    local items = self.UIListView_rank:getItems()
    print("count:",#items)]]
end


function TongRankView:onScrollingTop()

    print("onScrollingToponScrollingToponScrollingTop")
    local items = self.UIListView_rank:getItems()
    local firstItem = items[1]
    if not firstItem then
        return
    end

    local page = firstItem.page
    local beforePage = page - 1
    print("page",page)
    if beforePage <= 0 then
        return
    end

    if self.askRankData then
        self.askRankData = false
        local data = TongDataMgr:getRankData(self.rankType,beforePage) or {}
        if #data == 0 then
            self.askRankData = false
            TongDataMgr:Send_getRankInfo(self.rankType,nil,beforePage,askFlag.up)
        else
            self:updateRankData(askFlag.up,beforePage)
        end
    end

    --[[local rankId = firstItem.rank

    local rankData_ = self.rankData[beforePage] or {}
   for i=#rankData_,1,-1 do
       self:insertRankData(1)
       local item = self.UIListView_rank:getItem(1)
       if item then
           self:updateRankItem(item,rankData_[i])
       end
   end

   self:removeOtherPage(page + 2)

   local jumpIndex = self:getListIndex(rankId)
   print("lastRankId",rankId)
   self.UIListView_rank:jumpToItem(jumpIndex-2)

   local items = self.UIListView_rank:getItems()
   print("count:",#items)]]
end

function TongRankView:onShow()

end

function TongRankView:jumpToMyRankId()

    if not self.myRankInfo then
        return
    end

    local myrankId = self.myRankInfo.index
    local items = self.UIListView_rank:getItems()
    local firstItem,lastItem = items[1],items[#items]
    if not firstItem or not lastItem then
        return
    end
    if myrankId >= firstItem.index and myrankId <= lastItem.index then
        local index = self:getListIndex(myrankId)
        self.UIListView_rank:jumpToItem(index)
    else
        local pageId = (myrankId-1)/self.rankPageNum+1
        local data = TongDataMgr:getRankData(self.rankType,pageId) or {}
        if #data == 0 then
            self.askRankData = false
            TongDataMgr:Send_getRankInfo(self.rankType,nil,pageId,askFlag.jump)
        else
            self:updateRankData(askFlag.jump,pageId)
        end
    end
end

function TongRankView:getListIndex(index)

    local jumpIndex = 1
    local items = self.UIListView_rank:getItems()
    for k,v in ipairs(items) do
        if v.index == index then
            jumpIndex = k
            break
        end
    end
    return jumpIndex

end

function TongRankView:removeOtherPage(pageId)

    print("removeOtherPage",pageId)
    local items = self.UIListView_rank:getItems()
    for i=#items,1,-1 do
        if items[i].page == pageId then
            self.UIListView_rank:removeItem(i)
        end
    end
    TongDataMgr:removeRankData(self.rankType,pageId)
end

function TongRankView:registerEvents()

    --self.UIListView_rank:s():addMEListener(TFSCROLLVIEW_SCROLL_TO_BOTTOM, handler(self.onScrollingBottom, self))
    --self.UIListView_rank:s():addMEListener(TFSCROLLVIEW_SCROLL_TO_TOP, handler(self.onScrollingTop, self))
    self.UIListView_rank:s():addMEListener(TFSCROLLVIEW_BOUNCE_TOP, handler(self.onScrollingTop, self))
    self.UIListView_rank:s():addMEListener(TFSCROLLVIEW_BOUNCE_BOTTOM, handler(self.onScrollingBottom, self))

    EventMgr:addEventListener(self, EV_TONG.RankInfo, handler(self.updateRankData, self))

    self:setBackBtnCallback(function ()
        TongDataMgr:clearRankData()
        AlertManager:close()
    end)

    self:setMainBtnCallback(function()
        TongDataMgr:clearRankData()
        AlertManager:closeLayer(self)
    end)

    self.Button_close:onClick(function ()
        TongDataMgr:clearRankData()
        AlertManager:closeLayer(self)
    end)

    for k,v in ipairs(self.rankItem_) do
        v.root:onClick(function()
            if self.selectIndex == k then
                return
            end
            self:chooseList(k)
        end)
    end

    self.Panel_my_rank:onClick(function ()
        self:jumpToMyRankId()
    end)

end

return TongRankView
