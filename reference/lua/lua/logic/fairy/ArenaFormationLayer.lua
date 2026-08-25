local ArenaFormationLayer = class("ArenaFormationLayer", BaseLayer)

local enum_ruleId = {
    power_up = 1,
    power_down = 2,
    level_up = 3,
    level_down = 4,
    default = 5
}

function ArenaFormationLayer:ctor(data)
    self.super.ctor(self,data)
    self.showid = HeroDataMgr:getTeamLeaderId();
    self.showidx = 1;
    self.selectCell = nil;

    self.pos = data._pos;
    self.selectImg = nil


    local showList = clone(HeroDataMgr:resetShowList(true,false))
    self.showHeroIds = {}
    for k,v in ipairs(showList) do
        local showIndex = HeroDataMgr:getSelectedHeroIdx(v);
        local heroid = HeroDataMgr:getSelectedHeroId(showIndex)
        table.insert(self.showHeroIds,heroid)
    end

    -- self.ruleId = enum_ruleId.default 
    -- self:sortHeroShowId()

    self.showCount = HeroDataMgr:getShowCount();
    -- local isformation = HeroDataMgr:getIsFormationOn_arena(self.pos);
    -- if isformation then
    --     self.showid =  HeroDataMgr:getHeroIdByFormationPos_arena(self.pos);
    --     for i,v in ipairs(self.showHeroIds) do
    --         if self.showid == v then 
    --             self.showidx = i
    --         end
    --     end
    -- else
    --      self.showidx, self.showid = 1, self.showHeroIds[1]
    -- end

    dump({"_________init:",self.showid,self.showidx ,self.pos})
    self.firstTouchIn = false;


    self.sortRule = {{lable = 14300313,ruleId = enum_ruleId.power_up,isUp = true},
                     {lable = 14300314,ruleId = enum_ruleId.power_down,isUp = false},
                     {lable = 14300315,ruleId = enum_ruleId.level_up,isUp = true},
                     {lable = 14300316,ruleId = enum_ruleId.level_down,isUp = false},
                     {lable = 14300317,ruleId = enum_ruleId.default,isUp = true}}

    self:showPopAnim(true)
    self:init("lua.uiconfig.fairy.formationLayer")
end

function ArenaFormationLayer:initUI(ui)
    self.super.initUI(self,ui)
    self.ui = ui
    ArenaFormationLayer.ui = ui
    self:addLockLayer()

    self.tableView          = TFDirector:getChildByPath(ui,"tableView")
    self.panel_item			= TFDirector:getChildByPath(ui,"Panel_item");
    self.armyLabel			= TFDirector:getChildByPath(ui,"Label_up")
    self.Button_army		= TFDirector:getChildByPath(ui,"Button_ok");
    self.Button_info		= TFDirector:getChildByPath(ui,"Button_info"):hide();
    self.Button_cancel		= TFDirector:getChildByPath(ui,"Button_cancel");
    self.Panel_hwx          = TFDirector:getChildByPath(ui,"Panel_hwx");
    self.Label_hwxnum       = TFDirector:getChildByPath(self.Panel_hwx,"Label_num");
    self.Button_change      = TFDirector:getChildByPath(self.Panel_hwx,"Button_change");
    self.Image_hwxicon      = TFDirector:getChildByPath(self.Panel_hwx,"Image_icon");

    self.qualityImg			= TFDirector:getChildByPath(ui,"Image_hero_puality");
    self.qualityImg:setScale(0.2);

    self.titleLabel			= TFDirector:getChildByPath(ui,"Label_name_title");
    self.Label_power		= TFDirector:getChildByPath(ui,"Label_power");
    self.moodValue			= TFDirector:getChildByPath(ui,"moodValue");
    self.Image_head			= TFDirector:getChildByPath(ui,"Image_head");
    self.moodValueDesc		= TFDirector:getChildByPath(ui,"moodValueDesc");

    self.Image_back2 = TFDirector:getChildByPath(ui, "Image_back2")
    self.Label_buttom_tip = TFDirector:getChildByPath(ui, "Label_buttom_tip"):hide()
    self.Label_buttom_tip:setTextById(2108112)

    self.tableViewNew = TFTableView:create()
    self.tableViewNew:setTableViewSize(self.tableView:getContentSize())
    self.tableViewNew:setDirection(TFTableView.TFSCROLLHORIZONTAL)
    self.tableViewNew:setVerticalFillOrder(TFTableView.TFTabViewFILLTOPDOWN)

    self.tableViewNew:addMEListener(TFTABLEVIEW_SIZEFORINDEX, self.cellSizeForTable)
    self.tableViewNew:addMEListener(TFTABLEVIEW_SIZEATINDEX, self.tableCellAtIndex)
    self.tableViewNew:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, self.numberOfCellsInTableView)

    self.tableViewNew.logic = self
    self.tableView:addChild(self.tableViewNew)

    
    self.Button_sort_order = TFDirector:getChildByPath(ui, "Button_sort_order")
    self.Label_order_name = TFDirector:getChildByPath(self.Button_sort_order, "Label_order_name")
    self.Image_order_icon = TFDirector:getChildByPath(self.Button_sort_order, "Image_order_icon")

    local ScrollView_rule = TFDirector:getChildByPath(ui, "ScrollView_rule"):hide()
    self.ListView_rule = UIListView:create(ScrollView_rule)
    self.Button_rule = TFDirector:getChildByPath(ui, "Button_rule")

    self:updateRuleList()
    self:changeShowOne();
    self:selectSortRule(self.defaultInfo,true)
end

function ArenaFormationLayer.cellSizeForTable(table, idx)
    local self = table.logic
    local size = self.panel_item:getContentSize() 
    return size.height, size.width
end

function ArenaFormationLayer.tableCellAtIndex(table, idx)
    local self = table.logic
    local cell = table:dequeueCell()
    if nil == cell then
        table.cells = table.cells or {}
        cell = TFTableViewCell:create()
        local parentNode = self.panel_item:clone()
        parentNode:setVisible(true)
        parentNode:setPosition(ccp(0,0))
        cell:addChild(parentNode)
        cell.node = parentNode
        table.cells[cell] = true
    end
    local itemNode = cell.node
    self:updateOneHead(itemNode, idx + 1)
    return cell
end

function ArenaFormationLayer.numberOfCellsInTableView(table)
    return HeroDataMgr:getShowCount()
end

function ArenaFormationLayer:updateUI()
    self.selectImg = nil;
    self.tableViewNew:reloadData()
end

function ArenaFormationLayer:onFormationChange(heroid)
    if self.showid then
        VoiceDataMgr:playVoiceByHeroID("battle_play",self.showid)
        AlertManager:close()
    end
end

function ArenaFormationLayer:fitSkyLadderFight()
    local heroFightCnt = SkyLadderDataMgr:getHeroFightCnt(self.showid)
    heroFightCnt = heroFightCnt or 0
    return heroFightCnt ~= 0
end

function ArenaFormationLayer:fitHwxHeroFightCnt()
    local heroFightCnt = LinkageHwxDataMgr:getHeroBuyCnt(self.showid)
    local heroBuyCnt = LinkageHwxDataMgr:getHeroBuyCnt(self.showid)
    local maxFightCnt = LinkageHwxDataMgr:getInitFightCnt() + heroBuyCnt
    local remainCnt = maxFightCnt - heroFightCnt
    remainCnt = remainCnt < 0 and 0 or remainCnt
    return remainCnt ~= 0
end

function ArenaFormationLayer:updateRuleList()

    self.defaultInfo = self.sortRule[5]
    self.ruleId = FubenDataMgr:getFormationSortRuleId()
    if not self.ruleId then
        self.ruleId = self.defaultInfo.ruleId
        FubenDataMgr:setFormationSortRuleId(self.ruleId)
    end
    
    for k,v in ipairs(self.sortRule) do
        local ruleItem = self.Button_rule:clone()
        local Label_btn_name = TFDirector:getChildByPath(ruleItem,"Label_btn_name")
        local Image_btn_icon = TFDirector:getChildByPath(ruleItem,"Image_btn_icon")
        Label_btn_name:setTextById(v.lable)
        local scaleY = v.isUp and 1 or -1
        Image_btn_icon:setScaleY(scaleY)
        self.ListView_rule:pushBackCustomItem(ruleItem)

        if v.ruleId == self.ruleId then
            self.defaultInfo = v
        end
        ruleItem:onClick(function()
            self:selectSortRule(v)
        end)
    end

    self.Label_order_name:setTextById(self.defaultInfo.lable)
    local scaleY = self.defaultInfo.isUp and 1 or -1
    self.Image_order_icon:setScaleY(scaleY)
end


function ArenaFormationLayer:resetShowId()
    local isformation = HeroDataMgr:getIsFormationOn_arena(self.pos)
    if isformation then
        self.showid =  HeroDataMgr:getHeroIdByFormationPos_arena(self.pos)
        for i,v in ipairs(self.showHeroIds) do
            if self.showid == v then 
                self.showidx = i
            end
        end
    else
         self.showidx, self.showid = 1, self.showHeroIds[1]
    end
end

function ArenaFormationLayer:selectSortRule(ruleInfo ,reset)
    self.ruleId = ruleInfo.ruleId
    FubenDataMgr:setFormationSortRuleId(self.ruleId)
    self.Label_order_name:setTextById(ruleInfo.lable)
    local scaleY = ruleInfo.isUp and 1 or -1
    self.Image_order_icon:setScaleY(scaleY)
    self.ListView_rule:s():hide()
    self:sortHeroShowId()
    if reset then 
        self:resetShowId()
    end
    self.showid =  self.showHeroIds[self.showidx]

    self:changeShowOne();

    self:updateUI()
end

function ArenaFormationLayer:sortHeroShowId()

    local function sortFunc(a,b)
        local heroInfoA = HeroDataMgr:getHero(a)
        local heroInfoB = HeroDataMgr:getHero(b)
        if self.ruleId == enum_ruleId.power_up then
            return heroInfoA.fightPower < heroInfoB.fightPower
        elseif self.ruleId == enum_ruleId.power_down then
            return heroInfoA.fightPower > heroInfoB.fightPower
        elseif self.ruleId == enum_ruleId.level_up then
            return heroInfoA.lvl < heroInfoB.lvl
        elseif self.ruleId == enum_ruleId.level_down then
            return heroInfoA.lvl > heroInfoB.lvl
        elseif self.ruleId == enum_ruleId.default then 
            local jobA  = self:getHeroJob(a)
            local jobB  = self:getHeroJob(b)
            return jobA < jobB
        end
    end
    table.sort(self.showHeroIds,sortFunc)
end

function ArenaFormationLayer:updateBaseInfo( ... )
    -- body
    self.titleLabel:setTextById(HeroDataMgr:getTitleStrId(self.showid));
    self.qualityImg:setTexture(HeroDataMgr:getQualityPic(self.showid));
    self.Label_power:setString(math.floor(HeroDataMgr:getHeroPower(self.showid)));

    local roleid = HeroDataMgr:getHeroRoleId(self.showid);
    local isHaveRole = RoleDataMgr:getIsHave(roleid) and RoleDataMgr:getCityRole(roleid) == 1
    self.Image_back2:setVisible(isHaveRole)
    if isHaveRole then
        self.moodValue:setString(RoleDataMgr:getMood(roleid));
        self.Image_head:setTexture(RoleDataMgr:getMoodIcon(roleid));
        self.moodValueDesc:setString(RoleDataMgr:getMoodDes(roleid)) 
    end



    local visible = self.Button_info:isVisible()
    local posX = visible and 218 or 272
    self.Button_sort_order:setPositionX(posX)


 self.Panel_hwx:setVisible(false)
    -- self:updateHwxCost()

end


function ArenaFormationLayer:getHeroJob(showid)
    if not self.jobs then
        self.jobs = {}
        for i = 1, 3 do
            local isOn = HeroDataMgr:getIsFormationOn_arena(i)
            if isOn then
                local id = HeroDataMgr:getHeroIdByFormationPos_arena(i)
                self.jobs[id] = i
            end
        end
    end
    -- print(self.jobs)
    return self.jobs[showid] or 4
end



function ArenaFormationLayer:updateHandleNormal()

    local job = self:getHeroJob(self.showid);
    dump({self.showid,self.pos ,job})
    if job == self.pos and HeroDataMgr:getFormationHeroCnt_arena() == 1 then
        self.armyLabel:setTextById(2100122);
        -- self.Button_army:setGrayEnabled(true);
        -- self.Button_army:setTouchEnabled(false);
        self.Button_army:setGrayEnabled(true);
        self.Button_army:setTouchEnabled(false);
    elseif job == self.pos and HeroDataMgr:getFormationHeroCnt_arena() > 1 then
        self.armyLabel:setTextById(2100122);
        -- self.Button_army:setGrayEnabled(false);
        -- self.Button_army:setTouchEnabled(true);
        self.Button_army:setGrayEnabled(true);
        self.Button_army:setTouchEnabled(false);
    elseif job < 4 then
        self.armyLabel:setTextById(2100123);
        self.Button_army:setGrayEnabled(true);
        self.Button_army:setTouchEnabled(false);
    elseif job == 4 and HeroDataMgr:checkOnFormationByRole_arena(self.showid) then
        --同一roleID 的角色我可以替换处理
        local roleId1
        local roleId2 = HeroDataMgr:getHeroRoleId(self.showid);
        local curID   = HeroDataMgr:getHeroIdByFormationPos(self.pos)
        if curID then
            roleId1 = HeroDataMgr:getHeroRoleId(curID)
        end
        if curID and roleId1 == roleId2 then
            self.Button_army:setGrayEnabled(false);
            self.Button_army:setTouchEnabled(true);
            self.armyLabel:setTextById(2100124); --更换队员
        else
            self.armyLabel:setTextById(2100125);
            self.Button_army:setGrayEnabled(false);
            self.Button_army:setTouchEnabled(true);
        end
    elseif job == 4 and not HeroDataMgr:getFormationIsFull_arena() and HeroDataMgr:getIsFormationOn_arena(self.pos) then
        self.Button_army:setGrayEnabled(false);
        self.Button_army:setTouchEnabled(true);
        self.armyLabel:setTextById(2100124); --更换队员
    elseif job == 4 and not HeroDataMgr:getFormationIsFull_arena() then
        self.Button_army:setGrayEnabled(false);
        self.Button_army:setTouchEnabled(true);
        self.armyLabel:setTextById(2100125);
    elseif job == 4 and HeroDataMgr:getFormationIsFull_arena() then
        self.Button_army:setGrayEnabled(false);
        self.Button_army:setTouchEnabled(true);
        self.armyLabel:setTextById(2100124);
    end


    local isformation = HeroDataMgr:getIsFormationOn_arena(self.pos);
    local isformationID = HeroDataMgr:getHeroIdByFormationPos_arena(self.pos);

    local ha = HeroDataMgr:getHero(self.showid) or {}
    local hb = HeroDataMgr:getHero(isformationID) or {}
    if ha.Inoperable or (isformation and hb.Inoperable) then
        self.Button_army:setGrayEnabled(true);
        self.Button_army:setTouchEnabled(false);
    end

end

function ArenaFormationLayer:changeShowOne()

    self:updateBaseInfo();


    self:updateHandleNormal()
 
end

function ArenaFormationLayer:updateOneHead(cell,idx,isChange)
    cell:setTouchEnabled(true);
    cell:onClick(function()
        if self.showidx ~= idx then
            self.showidx = idx
            self.firstTouchIn  = true;
        end
        self.showid = self.showHeroIds[idx]
        self.firstTouchIn  = false;
        self:changeShowOne();

        local Image_select = TFDirector:getChildByPath(cell,"Image_select");
        if self.showidx == idx then
            if self.selectImg then
                self.selectImg:hide();
            end
            Image_select:show()
            self.selectImg = Image_select
        end
    end)

    local selectPoints = {}

    for i=1,4 do
        local point = TFDirector:getChildByPath(cell,"Image_select"..i);
        point:setVisible(false);
        table.insert(selectPoints,point);
    end
    --
    local heroid = self.showHeroIds[idx]
    local skinid = HeroDataMgr:getCurSkin(heroid);
    local data = TabDataMgr:getData("HeroSkin", skinid)

    local Panel_mask = TFDirector:getChildByPath(cell, "Panel_mask")
    local Image_diban = TFDirector:getChildByPath(Panel_mask, "Image_diban")
    local Panel_model = TFDirector:getChildByPath(Panel_mask, "Panel_model")
    Panel_model:setBackGroundColorType(0)
    local Image_hero = TFDirector:getChildByPath(cell, "Image_hero")
    Image_diban:setTexture(data.backdrop)

    local trail_flag = TFDirector:getChildByPath(cell, "trail_flag")
    trail_flag:setVisible(HeroDataMgr:getHero(heroid).heroStatus == 2);

    if Panel_model.model then
        Panel_model.model:removeFromParent()
        Panel_model.model = nil
    end
    
    local heroImg = Utils:getHeroModelImgSrc(heroid, skinid)
    if heroImg then
        Image_hero:setTexture(heroImg)
    else
        local model = Utils:createHeroModel(heroid, Panel_model, 0.45, skinid,true)
        model:update(0.1)
        model:stop()
    end
    
    --等级
    local heroLv = HeroDataMgr:getLv(heroid)
    local Image_levelbg = TFDirector:getChildByPath(cell, "Image_levelbg")
    local Label_level 		= TFDirector:getChildByPath(Image_levelbg,"Label_level")
    Label_level:setText("Lv."..heroLv)

    --是否助战
    local assitance = HeroDataMgr:getIsAssist(heroid)
    local Image_assistant 	= TFDirector:getChildByPath(cell,"Image_assistant");
    Image_assistant:setVisible(false)

    -- local icon = TFDirector:getChildByPath(cell.item,"Image_hero");
    -- local Image_di = TFDirector:getChildByPath(cell.item, "Image_di")
    -- icon:setTexture(data.endIcon);
    -- icon:setSize(ccs(140,245))
    --Image_di:setTexture(data.backdrop)

    local name = TFDirector:getChildByPath(cell,"Label_name");
    name:setLineHeight(22)
    name:setTextById(HeroDataMgr:getNameStrId(heroid));

    local jobIcon = TFDirector:getChildByPath(cell,"Image_duty");
    local iconpath = HeroDataMgr:getHeroJobIconPath(heroid);
    jobIcon:setVisible(iconpath ~= "")
    jobIcon:setTexture(iconpath);

    local Image_select = TFDirector:getChildByPath(cell,"Image_select");
    Image_select:setVisible(self.showidx == idx)
    if Image_select:isVisible() then
        self.selectImg = Image_select;
    end

    for i=1,HeroDataMgr:getShowOneCount(idx) do
        --selectPoints[i]:setVisible(true);
        --减少精灵数量，暂时隐藏
        selectPoints[i]:setVisible(false)
        if HeroDataMgr:isSelected(idx,i) then
            selectPoints[i]:setTexture("ui/373.png");
        else
            selectPoints[i]:setTexture("ui/374.png");
        end
    end

    local hero = HeroDataMgr:getHero(heroid);
    local Image_xianding = TFDirector:getChildByPath(cell,"Image_xianding");
    Image_xianding:setVisible(tobool(hero.isLimitHero))

    local Image_shiyong = TFDirector:getChildByPath(cell,"Image_shiyong");
    Image_shiyong:setVisible(tobool(hero.heroStatus == 3))

    local Image_jinyong = TFDirector:getChildByPath(cell,"Image_jinyong");
    Image_jinyong:setVisible((hero.job > 3 and  hero.Inoperable))
    local Label_jiyong = TFDirector:getChildByPath(Image_jinyong, "Label_jiyong")
    Label_jiyong:setTextById(300017)

    -- 无尽竞速模式
    local Image_endless_hp = TFDirector:getChildByPath(cell, "Image_endless_hp"):hide()
    --天梯
    local Image_skyladder = TFDirector:getChildByPath(cell, "Image_skyladder"):hide()




end

function ArenaFormationLayer:onHide()
    self.super.onHide(self)
end

function ArenaFormationLayer:removeUI()
    self.super.removeUI(self)
    --HeroDataMgr:changeDataToSelf();
end


function ArenaFormationLayer:onShow()
    self:removeLockLayer()
    HeroDataMgr:resetShowList(true,false);
    self.showCount = HeroDataMgr:getShowCount();
    self:timeOut(function()
            GameGuide:checkGuide(self);
                 end,0)
end

function ArenaFormationLayer:checkCondition()

    return true
end

function ArenaFormationLayer:changeFormationNormal()
    if HeroDataMgr:getIsFormationOn_arena(self.pos) and HeroDataMgr:getHeroIdByFormationPos_arena(self.pos) ~= self.showid then
        HeroDataMgr:heroOnBattle(HeroDataMgr:getHeroIdByFormationPos_arena(self.pos),self.showid ,3);
        --换人
    else
        ---编入，移除
        HeroDataMgr:heroOnBattle(self.showid,nil,3);
    end
    self.Button_army:setTouchEnabled(false)
    GameGuide:checkGuideEnd(self.guideFuncId)
end

function ArenaFormationLayer:registerEvents()
    EventMgr:addEventListener(self,EV_FORMATION_CHANGE,handler(self.onFormationChange, self));
    EventMgr:addEventListener(self,EV_HERO_LEVEL_UP,handler(self.updateUI, self));
    EventMgr:addEventListener(self,EV_UPDATE_BUY_FIGHTCNT,handler(self.updateUI, self));
    EventMgr:addEventListener(self, EV_BAG_ITEM_UPDATE, handler(self.updateHwxCost, self))
    EventMgr:addEventListener(self,EV_UPDATE_PRE_TEAM,handler(self.onFormationChange, self));

    self.Button_army:onClick(function ()


            self:changeFormationNormal()

    end)

    self.Button_info:onClick(function()
        --AlertManager:changeScene(SceneType.MainScene);

        local layer = Utils:openView("fairyNew.FairyDetailsLayer",{showid=self.showid, friend=false})
        layer:onTouchFairy()
        
    end)

    self.Button_cancel:onClick(function ()
        AlertManager:close();
    end)

    self.Button_change:onClick(function()

    end)

    self.Button_sort_order:onClick(function()
        local visible = self.ListView_rule:s():isVisible()
        self.ListView_rule:s():setVisible(not visible)
    end)
end


return ArenaFormationLayer;
