
local TongStoreView = class("TongStoreView",BaseLayer)
function TongStoreView:ctor(...)
    self.super.ctor(self)
    self.block = AlertManager.BLOCK_CLOSE
    --self:showPopAnim(true)
    self:initData(...)
    self:init("lua.uiconfig.tong.tongStoreView")
end

function TongStoreView:initData(storeId)

    self.activityId = storeId or ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.STORE)[1]
    self.activityInfo = ActivityDataMgr2:getActivityInfo(self.activityId)
    self.goodsData_ = {}
end

function TongStoreView:initUI(ui)
    self.super.initUI(self,ui)

    self.tableView                      = Utils:scrollView2TableView( TFDirector:getChildByPath(ui,"ScrollView_list"))
    self.Panel_item                     = TFDirector:getChildByPath(ui,"Panel_item")
    self.Panel_root                      = TFDirector:getChildByPath(ui,"Panel_root")
    -- self.Image_icon                     = TFDirector:getChildByPath(ui,"Image_icon")
    -- self.Panel_own                      = TFDirector:getChildByPath(ui,"Panel_own")
    self.Button_close                   = TFDirector:getChildByPath(ui,"Button_close"):hide()
    self.Label_time                     = TFDirector:getChildByPath(ui,"Label_time")

    self.tableView:setDirection(TFTableView.TFSCROLLHORIZONTAL)
    self.tableView:addMEListener(TFTABLEVIEW_SIZEFORINDEX, handler(self.tableCellSize,self))
    self.tableView:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, handler(self.numberOfCells,self))
    self.tableView:addMEListener(TFTABLEVIEW_SIZEATINDEX, handler(self.tableCellAtIndex,self))

    self:initUILogic()
end

function TongStoreView:initUILogic()

    if not self.activityInfo then
        return
    end

    local st_year, st_month, st_day = Utils:getUTCDateYMD(self.activityInfo.startTime or 0 , false , GV_UTC_TIME_ZONE)
    local en_year, en_month, en_day = Utils:getUTCDateYMD(self.activityInfo.showEndTime or 0 , false , GV_UTC_TIME_ZONE)
    self.Label_time:setText(TextDataMgr:getText(63887, st_month, st_day, en_month, en_day) ..GV_UTC_TIME_STRING)

    self:updateStore()
end

function TongStoreView:onShow()

end

function TongStoreView:updateStore()
    dump(self.activityInfo)
    -- local showCurrency = tonumber(self.activityInfo.extendData.showCurrency)
    -- if showCurrency then

    --     local count = GoodsDataMgr:getItemCount(showCurrency)
    --     self.Label_own:setText(count)

    --     local cfg = GoodsDataMgr:getItemCfg(showCurrency)
    --     if cfg then
    --         self.Image_icon:setTexture(cfg.icon)
    --         self.Panel_own:onClick(function()
    --             Utils:showInfo(showCurrency)
    --         end)
    --     end
    -- end

    if self.activityInfo.extendData and self.activityInfo.extendData.showCurrency and #self.activityInfo.extendData.showCurrency > 0 then
        local asset = string.split(self.activityInfo.extendData.showCurrency, ",")
        -- self._ui.Label_tips:setVisible(table.count(asset) == 1)
        for i = 1 , 7 do
            local id = tonumber(asset[i])
            local assertItem = TFDirector:getChildByPath(self.Panel_root,"Panel_own" .. i)  -- self._ui["Panel_own"..i]
            if id then
                local itemCfg = GoodsDataMgr:getItemCfg(id)
                assertItem:getChildByName("Image_icon"):setTexture(itemCfg.icon)
                assertItem:getChildByName("Label_own"):setText(GoodsDataMgr:getItemCount(id))
                assertItem:setTouchEnabled(true)
                assertItem:onClick(function()
                    Utils:showInfo(id)
                end)
                assertItem:show()
            else
                assertItem:hide()
            end
        end
    end

    local tmpGoodsData_ = ActivityDataMgr2:getItems(self.activityId)
    local frontData = {}
    local hadUsedData = {}
    for i, id in ipairs(tmpGoodsData_) do
        local isCanBuy = ActivityDataMgr2:getRemainBuyCount(self.activityInfo.activityType, id)
        if isCanBuy then
            table.insert(frontData, id)
        else
            table.insert(hadUsedData, id)
        end
    end

    self.goodsData_ = frontData
    table.insertTo(self.goodsData_, hadUsedData)

    self.tableView:reloadData()
end


function TongStoreView:numberOfCells(tableView)
    return #self.goodsData_
end

function TongStoreView:tableCellSize(tableView)
    local size = self.Panel_item:getContentSize()
    return size.height, size.width
end

function TongStoreView:tableCellAtIndex(tab, idx)
    local cell = tab:dequeueCell()
    idx = idx + 1
    if not cell then
        cell = TFTableViewCell:create()
        local item = self.Panel_item:clone():show()
        item:setAnchorPoint(ccp(0, 0))
        item:setPosition(ccp(0, 0))
        cell:addChild(item)
        cell.item = item
    end
    cell.idx = idx

    if cell.item then
        self:updateItem(cell, self.goodsData_[idx])
    end

    return cell
end

function TongStoreView:updateItem(item, itemId)

    local Panel_goods    = TFDirector:getChildByPath(item, "Panel_goods")
    local Label_price    = TFDirector:getChildByPath(item, "Label_price")
    local Label_buyLimit = TFDirector:getChildByPath(item, "Label_buyLimit")
    local Image_coin     = TFDirector:getChildByPath(item, "Image_coin")
    local Label_itemName = TFDirector:getChildByPath(item, "Label_itemName")
    local Button_buy     = TFDirector:getChildByPath(item, "Button_buy")
    local Label_buy_tip  = TFDirector:getChildByPath(item, "Label_tips"):hide()
    local Label_tips_got = TFDirector:getChildByPath(item, "Label_tips_got"):hide()
    local Panel_cost     = TFDirector:getChildByPath(item, "Panel_cost")

    local itemInfo = ActivityDataMgr2:getItemInfo(EC_ActivityType2.STORE, itemId)

    local goodsId, goodsCount
    for k, v in pairs(itemInfo.reward) do
        goodsId = k
        goodsCount = v
        break
    end

    local goodsCfg = GoodsDataMgr:getItemCfg(goodsId)
    Label_itemName:setTextById(goodsCfg.nameTextId)

    local Panel_goodsItem = Panel_goods:getChildByName("Panel_goodsItem")
    if not Panel_goodsItem then
        Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
        Panel_goodsItem:Scale(0.9)
        Panel_goodsItem:setName("Panel_goodsItem")
        Panel_goodsItem:AddTo(Panel_goods):Pos(0, 0)
    end
    PrefabDataMgr:setInfo(Panel_goodsItem, goodsId, goodsCount)

    Button_buy:setVisible(true)
    Label_buyLimit:setVisible(true)
    Label_buy_tip:setVisible(false)

    ---信物特殊处理
    local tipId = Utils:getStoreBuyTipId(itemInfo.extendData, 1)
    if tipId then
        Button_buy:setVisible(not tipId)
        Label_buyLimit:setVisible(not tipId)
        Label_buy_tip:setTextById(tipId)
        Label_buy_tip:setVisible(tipId)
    end

    local costId,costNum
    for k, v in pairs(itemInfo.target) do
        costId,costNum = k,v
        break
    end

    if costId and costNum then

        local costCfg = GoodsDataMgr:getItemCfg(costId)
        Image_coin:setTexture(costCfg.icon)
        Label_price:setText(costNum)
        Panel_cost:onClick(function()
            Utils:showInfo(costId)
        end)
    end

    -- 限购
    local isCanBuy, remainCount = ActivityDataMgr2:getRemainBuyCount(EC_ActivityType2.STORE, itemId)
    if itemInfo.details then
        Label_buyLimit:setTextById(itemInfo.details, remainCount)
    else
        Label_buyLimit:hide()
    end
    Button_buy:setGrayEnabled(not isCanBuy)
    Button_buy:setTouchEnabled(isCanBuy)

    if not isCanBuy then
        --优先判断是否能购买
        Button_buy:setVisible(true)
        Label_buyLimit:setVisible(true)
        Label_buy_tip:setVisible(false)
    end


    Button_buy:onClick(function()
        local callFunc = function ( ... )
            local isEnough = ActivityDataMgr2:currencyIsEnough(EC_ActivityType2.STORE, itemId)
            if isEnough then
                Utils:openView("activity.ActivityBuyConfirmView", self.activityId, itemId)
            else
                Utils:showTips(302200)
            end
        end

        local tipId = Utils:getStoreBuyTipId(itemInfo.extendData, 2)
        if tipId then
            local args = {
                tittle = 2107025,
                reType = "buyGiftTip",
                content = TextDataMgr:getText(tipId),
                confirmCall = function ( ... )
                    callFunc();
                end,
            }
            Utils:showReConfirm(args)
            return
        end

        callFunc()
    end)
end

function TongStoreView:recProgressReward(reward)
    self:updateStore()
end

function TongStoreView:registerEvents()
    self.super.registerEvents(self)

    EventMgr:addEventListener(self, EV_ACTIVITY_SUBMIT_SUCCESS, handler(self.recProgressReward, self))
    EventMgr:addEventListener(self, EV_ACTIVITY_DELETED, function ( activityId )
        if self.activityId and self.activityId == activityId then
            Utils:showTips(14110403)
            AlertManager:closeLayer(self)
        end
    end)

    self.Button_close:onClick(function()
        AlertManager:closeLayer(self)
    end)
end


return TongStoreView