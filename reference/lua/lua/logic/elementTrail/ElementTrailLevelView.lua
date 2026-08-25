
local ElementTrailLevelView = class("ElementTrailLevelView", BaseLayer)

function ElementTrailLevelView:initData(elementTrailCfg)
    self.elementTrailCfg = elementTrailCfg
    -- dump(self.elementTrailCfg)

    --三个一组拆分数据
    self.pageDatas = {}
    local tempData = {}
    local count =  0
    for i,v in ipairs(self.elementTrailCfg.dungeonID) do
        table.insert(tempData, v) -- 加入当前临时组
        count = count + 1
        -- 满3个元素，完成一组
        if count == 3 then
            table.insert(self.pageDatas, tempData) -- 存入结果
            tempData = {}
            count = 0 
        end
    end  
    -- dump(self.pageDatas)
end

function ElementTrailLevelView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.elementTrailLevelView")
end

function ElementTrailLevelView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    -- self.Panel_item = TFDirector:getChildByPath(self.Panel_root, "Panel_item"):hide()


    -- self.Button_tip   = TFDirector:getChildByPath(self.Panel_root, "Button_tip")
    -- self.Button_rank  = TFDirector:getChildByPath(self.Panel_root, "Button_rank")
    self.Button_enter = TFDirector:getChildByPath(self.Panel_root, "Button_enter")


    self.Label_name_enter  = TFDirector:getChildByPath(self.Button_enter, "Label_name_enter")
    self.Label_name_enter:setTextById(2107019)


    -- local ScrollView_items   = TFDirector:getChildByPath(self.Panel_root, "ScrollView_items")
    
    -- self.ListView = UIListView:create(ScrollView_items)
    -- self.ListView:setItemsMargin(20)
    -- self.items = {}
    -- for i=1,7 do
    --     local itemNode  = self.Panel_item:clone():show()
    --     self.ListView:pushBackCustomItem(itemNode)
    --     self.items[i] = itemNode
    --     -- itemNode.Label_elemet_name  = TFDirector:getChildByPath(itemNode, "Label_elemet_name")
    --     itemNode.Image_element_name  = TFDirector:getChildByPath(itemNode, "Image_element_name")
    --     itemNode.Image_icon  = TFDirector:getChildByPath(itemNode, "Image_icon")
    --     itemNode.Image_focus = TFDirector:getChildByPath(itemNode, "Image_focus")
    --     itemNode.Panel_lock  = TFDirector:getChildByPath(itemNode, "Panel_lock"):hide()
    --     itemNode.Button_click = TFDirector:getChildByPath(itemNode, "Button_click"):show()

    --     itemNode.itemIdx     = i
    --     itemNode.Button_click:onClick(function()
    --         self.selectIdx = itemNode.itemIdx
    --         self:refreshItem()
    --     end)
    -- end
    self.Label_prefab      = TFDirector:getChildByPath(self.Panel_root, "Label_prefab"):hide()

    self.Panel_leveldetail = TFDirector:getChildByPath(self.Panel_root, "Panel_leveldetail")
    self.Label_desc_title  = TFDirector:getChildByPath(self.Panel_leveldetail, "Label_desc_title")
    self.Label_reward      = TFDirector:getChildByPath(self.Panel_leveldetail, "Label_reward")
    self.Label_attr_title  = TFDirector:getChildByPath(self.Panel_leveldetail, "Label_attr_title")
    self.ScrollView_desc   = TFDirector:getChildByPath(self.Panel_leveldetail, "ScrollView_desc")
    self.ScrollView_reward = TFDirector:getChildByPath(self.Panel_leveldetail, "ScrollView_reward")
    self.ScrollView_attr   = TFDirector:getChildByPath(self.Panel_leveldetail, "ScrollView_attr")

    self.Label_debuff_desc   = TFDirector:getChildByPath(self.Panel_leveldetail, "Label_debuff_desc")
    self.Label_buff_desc   = TFDirector:getChildByPath(self.Panel_leveldetail, "Label_buff_desc")


    self.Label_desc_title:setTextById(320011)
    self.Label_reward:setTextById(2106003)
    self.Label_attr_title:setTextById(320009)


    -- self.ListView_desc   = UIListView:create(self.ScrollView_desc)
    -- self.ListView_attr   = UIListView:create(self.ScrollView_attr)
    self.ListView_reward = UIListView:create(self.ScrollView_reward)
    -- for i=1,2 do
    --     self.ListView_attr:pushBackCustomItem(self.Label_prefab:clone():show())
    -- end

    -- for i=1,5 do
    --     self.ListView_desc:pushBackCustomItem(self.Label_prefab:clone():show())
    -- end


    -- for i=1,5 do
    -- local Panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
    --     self.ListView_reward:pushBackCustomItem(Panel_goodsItem)
    -- end


    self.Panel_page = TFDirector:getChildByPath(self.Panel_root, "Panel_page")

    self.Panel_left = TFDirector:getChildByPath(self.Panel_root, "Panel_left")

    self.Button_right = TFDirector:getChildByPath(self.Panel_left, "Button_right") 
    self.Button_left =TFDirector:getChildByPath(self.Panel_left, "Button_left")

    local ScrollView_page = TFDirector:getChildByPath(self.Panel_left, "ScrollView_page")

    self.PageView = UIPageView:create(ScrollView_page)
    -- self.PageView:setMainIndex(2)
    self.PageView:setItemShowNum(1)



    -- self.PageView:addItem(self.Panel_page:clone():show())


    local Panel_pageIndex = TFDirector:getChildByPath(self.Panel_left, "Panel_pageIndex")
    self.pangePoint = TFDirector:getChildByPath(Panel_pageIndex, "Image_icon"):hide()

    self.pageCount = #self.pageDatas
    self.pageIndex = 1
    local breakFlag = false
    for _pageIndex = #self.pageDatas, 1, -1 do
        for i , levelCid in ipairs(self.pageDatas[_pageIndex]) do
            local enabled, preIsOpen, levelIsOpen = FubenDataMgr:checkPlotLevelEnabled(levelCid)
            dump({_pageIndex  , levelCid ,enabled, preIsOpen, levelIsOpen})
            if enabled and levelIsOpen then
                self.pageIndex = _pageIndex
                breakFlag = true
                break
            end
        end
        if breakFlag then 
            break
        end
    end
--     print("self.pageIndex: " ..self.pageIndex )
-- Box(":"..self.pageIndex )
    self:initPagePoint()
    self:refreshPagePoint()

    self.pageNodes = {}
    for i=1, self.pageCount do
        self.pageNodes[i] =  self.Panel_page:clone():show()
        self.PageView:addItem(self.pageNodes[i])
    end

    self:initPages()
end

function ElementTrailLevelView:initPages()
    for i=1, self.pageCount do
        self:initPage(i)
    end
    self.PageView:jumpToIndex(self.pageIndex)  
    self:autoSelectLevel()
end

function ElementTrailLevelView:initPage(pageIndex)
    local pageNode  = self.pageNodes[pageIndex]
    local pageData  = self.pageDatas[pageIndex]
    for i=1,3 do
        local levelCid = pageData[i]
        local levelNode = TFDirector:getChildByPath(pageNode, "Panel_levelItem"..i)
        if levelCid then 
            self:updateLevelItem(levelNode, levelCid)
        else
            levelNode:hide()
        end
    end
end



function ElementTrailLevelView:refreshSelect()
    for _i,pageNode in ipairs(self.pageNodes) do
        local pageData  = self.pageDatas[_i]
        for i=1,3 do
            local levelCid = pageData[i]
            local levelNode = TFDirector:getChildByPath(pageNode, "Panel_levelItem"..i)
            if levelCid then 
                local Image_select     = TFDirector:getChildByPath(levelNode, "Image_select")
                Image_select:setVisible(self.selectLevelId == levelCid)
                levelNode:show()
            else
                levelNode:hide()
            end
        end
    end
end




local levelTypeData = {
            icon = "ui/fuben/fighting_paly.png",
            star = "ui/fuben/fightingStar.png",
            gray_star = "ui/fuben/fightStar_gray.png",
        }


function ElementTrailLevelView:updateLevelItem(item, levelCid)
    local baseLevelCfg = FubenDataMgr:getLevelCfg(levelCid)
    local levelCfg = TabDataMgr:getData("ElementTrainDungeonLevel",levelCid)

    local enabled, preIsOpen, levelIsOpen = FubenDataMgr:checkPlotLevelEnabled(levelCid)
    -- dump({"LEVEL STATE",levelCid ,enabled, preIsOpen, levelIsOpen})
    local levelInfo = FubenDataMgr:getLevelInfo(levelCid)
    -- local levelTypeData = self.levelTypeData_[levelCfg.dungeonType]
    local Button_level     = TFDirector:getChildByPath(item, "Button_level")
    local Image_type       = TFDirector:getChildByPath(Button_level, "Image_type"):hide()
    local Label_name       = TFDirector:getChildByPath(Button_level, "Label_name")
    local Image_lock       = TFDirector:getChildByPath(item, "Image_lock")
    local Image_lock_pre   = TFDirector:getChildByPath(item, "Image_lock_pre"):hide()
    local Image_lock_level = TFDirector:getChildByPath(item, "Image_lock_level"):hide()
    local Label_lock_level = TFDirector:getChildByPath(Image_lock_level, "Label_lock_level")
    local Image_select     = TFDirector:getChildByPath(item, "Image_select")
    Image_select:setVisible(self.selectLevelId == levelCid)
    local Image_star = {}
    for i = 1, 3 do
        Image_star[i] = TFDirector:getChildByPath(item, "Image_star_" .. i):hide()
    end

    -- Image_type:setTexture(levelTypeData.icon)
    if enabled then
        local starNum = FubenDataMgr:getStarNum(levelCid)
        -- for i, v in ipairs(Image_star) do
        --     v:show()
        --     if i <= starNum then
        --         v:setTexture(levelTypeData.star)
        --     else
        --         v:setTexture(levelTypeData.gray_star)
        --     end
        -- end
    else
        if not levelIsOpen then
            Image_lock_level:show()
            Label_lock_level:setTextById(800003, baseLevelCfg.playerLv)
        else
            Image_lock_pre:show()
        end
    end
    Button_level:setTouchEnabled(true)
    Label_name:setTextById(levelCfg.levelName)
    -- Button_level:setTextureNormal(levelCfg.bossicon)
    Button_level:onClick(function()
            -- local levelGroupCid = levelCfg.levelGroupId
            -- FubenDataMgr:cacheSelectLevelGroup(levelGroupCid)
            -- FubenDataMgr:cacheSelectLevel(levelCid)
            -- Utils:openView("fuben.FubenReadyView", levelCid)
        if self.selectLevelId ~= levelCid then 
            self.selectLevelId = levelCid
            self:onSelectLevel()
        end
    end)
end

--关卡选择
function ElementTrailLevelView:onSelectLevel()
    self:refreshSelect()

    local levelCfg =TabDataMgr:getData("ElementTrainDungeonLevel",self.selectLevelId)

    -- self.ListView_attr:removeAllItems()
    -- local labelDes = self.Label_prefab:clone():show()
    -- labelDes:setTextById(levelCfg.debuffDescribe)
    -- self.ListView_attr:pushBackCustomItem(labelDes)


    -- self.ListView_desc:removeAllItems()
    -- local labelBuffDes = self.Label_prefab:clone():show()
    -- labelBuffDes:setTextById(levelCfg.buffDescribe)
    -- self.ListView_desc:pushBackCustomItem(labelBuffDes)

    self.Label_debuff_desc:setTextById(levelCfg.debuffDescribe)
    self.Label_buff_desc:setTextById(levelCfg.buffDescribe)


    self.ListView_reward:removeAllItems()
    local baseLevelCfg = FubenDataMgr:getLevelCfg(self.selectLevelId)
    -- dump(baseLevelCfg.firstDropShow)
    --baseLevelCfg.rewardShow
    local isPass  = FubenDataMgr:isPassPlotLevel(self.selectLevelId) --是否通关 
    local  rewards =  baseLevelCfg.firstDropShow or {}

    for _, goodsId in pairs(rewards) do
        -- local Panel_dropGoodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
        local Panel_dropGoodsItem = PrefabDataMgr:getPrefab("Panel_dropGoodsItem"):clone()
        Panel_dropGoodsItem:Scale(0.9)
        local arg  = {}
        local flag = EC_DropShowType.FIRST_PASS
        if isPass then 
            flag = bit.bor(EC_DropShowType.FIRST_PASS, EC_DropShowType.DATING_GETED)
        end
        -- print("goodsId:".. goodsId)
        PrefabDataMgr:setInfo(Panel_dropGoodsItem, {goodsId}, flag, arg)
        self.ListView_reward:pushBackCustomItem(Panel_dropGoodsItem)
    end






end

-- 功能：计算横向居中排列的点位坐标
-- 参数：pointCount - 点位数量（正整数）
-- 返回：包含所有点位坐标的表，格式 { {x=x1, y=0}, {x=x2, y=0}, ... }
local function calculateHorizontalPositions(pointCount)
    -- 基础参数配置
    local interval = 50        -- 相邻点位间隔
    local centerY = 0          -- 横向排列，y坐标固定为0
    local positions = {}       -- 存储结果的表

    -- 核心计算：总宽度 = (点数-1) × 间隔，起始X = -总宽度/2（实现居中）
    local totalWidth = (pointCount - 1) * interval
    local startX = -totalWidth / 2

    -- 遍历计算每个点位的坐标
    for i = 0, pointCount - 1 do
        local x = startX + i * interval
        table.insert(positions, {x = x, y = centerY})
    end

    return positions
end

function ElementTrailLevelView:initPagePoint()
    self.pageCount   = self.pageCount or 4 --总页数
    local _pageIcons = self.pagePoints or {}
    for i,v in ipairs(_pageIcons) do
        v:hide()
    end
    self.pagePoints  = {}
    local interval   = 30        -- 相邻点位间隔
    local totalWidth = (self.pageCount - 1) * interval
    local startX     = -totalWidth / 2

    for i=1, self.pageCount do
        local pagePoint
        if i <= #_pageIcons then 
            pagePoint = _pageIcons[i]
            pagePoint:show()
        else
            pagePoint = self.pangePoint:clone():show()
            pagePoint.Image_select = TFDirector:getChildByPath(pagePoint, "Image_select")
            self.pangePoint:getParent():addChild(pagePoint)
        end
        self.pagePoints[i] = pagePoint
        --计算点位位置
        local x = startX + (i-1) * interval
        pagePoint:setPosition(ccp(x,0))
    end


end
function ElementTrailLevelView:refreshPagePoint()
    if self.pageCount ~= #self.pagePoints then 
        self:initPagePoint()
    end

  
    
    self.pageIndex =  self.pageIndex or 1
    for i,v in ipairs( self.pagePoints) do
        v.Image_select:setVisible(self.pageIndex == i)
    end
end

--初始化item 填充数据
function ElementTrailLevelView:initItem()
    -- for i,itemNode in ipairs(self.items) do
    --     itemNode.Image_focus:setVisible(self.selectIdx == itemNode.itemIdx)
    -- end
end
--刷新选择状态
function ElementTrailLevelView:refreshItem()
    -- for i,itemNode in ipairs(self.items) do
    --     itemNode.Image_focus:setVisible(self.selectIdx == itemNode.itemIdx)
    -- end
end



function ElementTrailLevelView:refreshView()
    
end

--页面切换时  默认选中第一个关卡
function ElementTrailLevelView:autoSelectLevel()
    local pageData     = self.pageDatas[self.pageIndex]

    -- dump(pageData)
    
    self.selectLevelId = pageData[1]
    for i = #pageData, 1, -1 do
        local levelId = pageData[i]
        local enabled, preIsOpen, levelIsOpen = FubenDataMgr:checkPlotLevelEnabled(levelId)
        if enabled and levelIsOpen then
            self.selectLevelId = levelId
            break
        end
    end
    self:onSelectLevel()
end


function ElementTrailLevelView:onPageChange(pageIndex)
    if self.pageIndex == pageIndex then 
        return
    end
    self.pageIndex = pageIndex
    if self.PageView:getCurrentItemIndex() ~= self.pageIndex then 
        self.PageView:scrollToIndex(self.pageIndex)    
    end
    self:refreshPagePoint()

    self:autoSelectLevel()

end

function ElementTrailLevelView:registerEvents()
    -- EventMgr:addEventListener(self, EV_FUBEN_DAILYBUYCOUNT, handler(self.onDailyBuyCountEvent, self))

    self.PageView:addEventListener(function(event)
        if event.name == UIPageView.EVENT.TURNING then
            local pageIndex = self.PageView:getCurrentItemIndex()
            self:onPageChange(pageIndex) 
        end
    end)


    self.Button_right:onClick(function ()
        local pageIndex = self.pageIndex + 1
        pageIndex = math.min(pageIndex ,self.pageCount)
        self:onPageChange(pageIndex)
       
    end)
    self.Button_left:onClick(function ()
        local pageIndex = self.pageIndex - 1
        pageIndex = math.max(pageIndex ,1)
        self:onPageChange(pageIndex)
    end)


    self.Button_enter:onClick(function ()
        if self.selectLevelId then 
            local enabled, preIsOpen, levelIsOpen = FubenDataMgr:checkPlotLevelEnabled(self.selectLevelId)
            if enabled and levelIsOpen then 
                -- Utils:showTips("调用关卡布阵界面")
                local chapterCfg_ =  FubenDataMgr:getChapterCfg(EC_ActivityFubenType.ELEMENT_TRIAL)
                Utils:openView("fuben.FubenSquadView", chapterCfg_.type, chapterCfg_.id, self.selectLevelId,  self.elementTrailCfg.id)
            else
                Utils:showTips("关卡未开启")
            end
        else
            Utils:showTips("未选择关卡")
        end


    -- local enabled, preIsOpen, levelIsOpen = FubenDataMgr:checkPlotLevelEnabled(self.selectLevelId)
    -- dump({"LEVEL STATE",self.selectLevelId ,enabled, preIsOpen, levelIsOpen})

    -- dump(FubenDataMgr.levelInfo_)


    end)

    -- self.Button_rank:onClick(function ()
    --     Utils:showTips("试炼排行")
    -- end)

    -- self.Button_enter:onClick(function ()
    --     Utils:showTips("进入试炼副本")
    -- end)

end


-- --检查是否开启
-- function ElementTrailLevelView:checkLevelOpen(levelCid)
--     return false
-- end





-- function ElementTrailLevelView:removeEvents()
--     -- self:removeCountDownTimer()
-- end

-- function ElementTrailLevelView:addCountDownTimer()
--     if not self.countDownTimer_ then
--         self.countDownTimer_ = TFDirector:addTimer(1000, count, nil, handler(self.onCountDownPer, self))
--     end
-- end

-- function ElementTrailLevelView:removeCountDownTimer()
--     if self.countDownTimer_ then
--         TFDirector:removeTimer(self.countDownTimer_)
--     end
-- end

-- function ElementTrailLevelView:onCountDownPer()
--     self:updateDailyCountDonw()
-- end

-- function ElementTrailLevelView:updateDailyCountDonw()
--     local remainTime = math.max(0, self.expirationTime_ - ServerDataMgr:getServerTime())
--     local day, hour, min = Utils:getFuzzyDHMS(remainTime, true)
--     if day ~= "00" then
--         self.Label_timing:setTextById(300590, day, hour, min)
--     else
--         self.Label_timing:setTextById(300591, hour, min)
--     end
-- end

-- function ElementTrailLevelView:onDailyBuyCountEvent()
--     self:updateRemainCount()
-- end

return ElementTrailLevelView
