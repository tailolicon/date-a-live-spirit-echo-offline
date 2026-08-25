local AngleStrengthen = class("AngleStrengthen", BaseLayer)
local maxLevel = 6
--通用消耗道具ID
local Common_Consume_Item_Id = 667005 
function AngleStrengthen:ctor(data)
    self.super.ctor(self,data)
    self.showHeroId    = data.heroId
    self.skillType     = data.skillType
    self.strengthLevel = AngelDataMgr:getStregthenLevel(self.showHeroId,self.skillType)
    self.selectLevel   = math.min(maxLevel, self.strengthLevel + 1)
    self.comsumeSelected     = false 
    self:init("lua.uiconfig.secondary.uiconfig_zn.fairyNew.angleStrengthen")
end

function AngleStrengthen:initData()


end

function AngleStrengthen:initUI(ui)
    self.super.initUI(self,ui)
    self.ui = ui
    self.Panel_content   = TFDirector:getChildByPath(ui, "Panel_content")
    self.Image_angel = TFDirector:getChildByPath(self.Panel_content, "Image_model")
    self.Label_skill_title  = TFDirector:getChildByPath(self.Panel_content, "Label_skill_title")
    self.Label_skill_title:setTextById(300020)
    local modelPath = HeroDataMgr:getAngelModelPath(self.showHeroId);
    local posOffset = HeroDataMgr:getAngelModelPosOffset(self.showHeroId);
    local scale     = HeroDataMgr:getAngelModelScale(self.showHeroId)
    local angelModel = SkeletonAnimation:create(modelPath)
    angelModel:setAnimationFps(GameConfig.ANIM_FPS)
    angelModel:playByIndex(0, -1, -1, 1)
    self.Image_angel:addChild(angelModel)
    angelModel:setPositionX(posOffset.x)
    angelModel:setPositionY(posOffset.y)
    angelModel:setScale(scale * 0.8)
   

    self.Spine_levelup = TFDirector:getChildByPath(self.Panel_content, "Spine_levelup")
    self.Spine_levelup:hide()



    self.Panel_star   = TFDirector:getChildByPath(self.Panel_content, "Panel_star")
    self.Label_level  = TFDirector:getChildByPath(self.Panel_star, "Label_level")
    self.Label_name   = TFDirector:getChildByPath(self.Panel_star, "Label_name")
    local name        = HeroDataMgr:getAngelName(self.showHeroId)
    self.Label_name:setTextById(name);
    self.Label_level:setText("Lv."..HeroDataMgr:getAngelBreakLevel(self.showHeroId, false))

    local angelLv = HeroDataMgr:getAngelLevel(self.showHeroId)
    self:refreshStar(self.Panel_star,angelLv,5)




    self.Button_sure  = TFDirector:getChildByPath(self.Panel_content, "Button_strengthen")
    self.Label_strengthen = TFDirector:getChildByPath(self.Button_sure, "Label_strengthen")
    self.Label_strengthen:setTextById(2500004)
    self.Labels_skill_desc = TFDirector:getChildByPath(self.Panel_content, "Labels_skill_desc")


    self.Image_scrollBar      = TFDirector:getChildByPath(self.Panel_content, "Image_scrollBar")
    self.Image_scrollBarInner = TFDirector:getChildByPath(self.Image_scrollBar, "Image_scrollBarInner")
    local skillIcon       = AngelDataMgr:getSkillIcon(self.showHeroId ,self.skillType)
    local _nodes = TFDirector:getChildByPath(self.Panel_content, "nodes")


    if maxLevel < 12  then 
        local ScrollView = TFDirector:getChildByPath(self.Panel_content, "ScrollView")
        ScrollView:hide()
        _nodes:retain()
        _nodes:removeFromParent()
        _nodes:AddTo(self.Panel_content)
        _nodes:setPosition(ccp(856,274))
        _nodes:release()

    end

    self.nodes = {}
    for i=1,12 do
        if i < 12 then
            local ImageArrow  = TFDirector:getChildByPath(_nodes, "ImageArrow"..i)
            ImageArrow:setVisible(i < maxLevel)
        end
        local node        = TFDirector:getChildByPath(_nodes, "NodeLevel"..i);
        node:setVisible(i <= maxLevel)

        node.Image_lock   = TFDirector:getChildByPath(node, "Image_lock")
        node.Image_icon   = TFDirector:getChildByPath(node, "Image_icon")
        node.Label_lv     = TFDirector:getChildByPath(node, "Label_lv")
        node.Image_select = TFDirector:getChildByPath(node, "Image_select")
        node.Image_select:setVisible(self.selectLevel == i)
        node.Image_icon:setTexture(skillIcon)
        node.Label_lv:setText("Lv."..i)
        node.Image_lock:setVisible( i > self.strengthLevel)
        self.nodes[i]     = node
        node:onClick(function ()
            -- self.selectLevel == i
            if self.selectLevel ~= i then 
                self:onSelect(i)
            end
        end)

    end

    self.scrollView_ = TFDirector:getChildByPath(self.Panel_content, "ScrollView")
    self.scrollViewAp_ = self.scrollView_:getAnchorPoint()
    self.scrollView_:addMEListener(TFSCROLLVIEW_SCROLLING, handler(self.onScrollingEvent, self))

    self.scrollBar_ = UIScrollBar:create(self.Image_scrollBar, self.Image_scrollBarInner)
    self.contentSize_ = self.scrollView_:getContentSize()
    self.innerContentSize_ = clone(_nodes:getContentSize())


    local ratio = self.contentSize_.height / self.innerContentSize_.height
    self.scrollBar_:setRatio(ratio)
    self.scrollBar_:setPercent(1)

    -- self.ScrollView_ranking:setScrollBar(scrollBar)


    self.Panel_consume = TFDirector:getChildByPath(self.Panel_content, "Panel_consume")
    self.Image_select  = TFDirector:getChildByPath(self.Panel_consume, "Image_select")
    self.Label_consume_tip = TFDirector:getChildByPath(self.Panel_consume, "Label_consume_tip")
    self.Label_item_count         = TFDirector:getChildByPath(self.Panel_consume, "Label_item_count")
    self.Image_consume_item_icon         = TFDirector:getChildByPath(self.Panel_consume, "Image_consume_item_icon")
    local itemCfg = GoodsDataMgr:getItemCfg(Common_Consume_Item_Id)
    self.Image_consume_item_icon:setTexture(itemCfg.icon)
    self.Label_consume_tip:setTextById(3005052)


    self.Panel_item = TFDirector:getChildByPath(self.Panel_content, "Panel_item")
    local ScrollView_items = TFDirector:getChildByPath(self.Panel_content,"ScrollView_items")
    self.ListView_items = UIListView:create(ScrollView_items)
    self.ListView_items:setItemsMargin(2)
    -- self:refreshCost()
    self:onSelect(self.selectLevel)
end

function AngleStrengthen:playLevelUpAnimation()

    --播放升级动画
    self.Spine_levelup:show()
    self.Spine_levelup:playByIndex(0, -1, -1, 0)
    self.Spine_levelup:addMEListener(TFARMATURE_COMPLETE,function()
        self.Spine_levelup:hide()
    end)

end

function AngleStrengthen:onSelect(selectIndex)
    self.selectLevel = selectIndex
    self:refreshCost()
    for i,node in ipairs( self.nodes) do
        node.Image_select:setVisible(self.selectLevel == i)
        node.Image_lock:setVisible( i > (self.strengthLevel + 1))
    end
end

--显示星级
function AngleStrengthen:refreshStar(Panel_star, star,maxStar)
    -- print("star"..tostring(star) .." > " ..tostring(maxStar))
    --重置星显示的位置
    
    local nodePetStars   = {}
    for i=1,6 do
        nodePetStars[i] = TFDirector:getChildByPath(Panel_star, "Image_star"..i)
        nodePetStars[i].imageStar = TFDirector:getChildByPath(nodePetStars[i], "Image_star")
    end
    local startPosX  =  maxStar * (-30)/2 -15
    -- local startPosX = math.floor(maxStar/2)* (-30) - ((maxStar+1)%2)*15 
    for i,v in ipairs(nodePetStars) do
        v:setPositionX(startPosX + i*30)
    end
    for i,v in ipairs(nodePetStars) do
        v:setVisible(i<= maxStar)
        v.imageStar:setVisible(i <= star)
    end
end

function AngleStrengthen:onScrollingEvent()
    if self.scrollBar_ then
        local position = self.scrollView_:getContentOffset()
        local offsetY = self.contentSize_.height * self.scrollViewAp_.y
        local y = math.min(position.y + offsetY, 0)
        local ty = self.innerContentSize_.height - self.contentSize_.height
        local percent = me.clampf(math.abs(y) / ty, 0, 1)
        self.scrollBar_:setPercent(percent)
        -- print("AngleStrengthen:onScrollingEvent()" ..percent)
    end
end




function AngleStrengthen:refreshCost()
    -- self.strengthLevel = 1
    dump({self.showHeroId ,self.skillType,self.selectLevel})
    local cfg = AngelDataMgr:getAngleStrengtheConfig(self.showHeroId ,self.skillType,self.selectLevel)
    self.Labels_skill_desc:setTextById(cfg.nameId)
    if self.comsumeSelected then 
        self:refreshCostItems(cfg.needCost2)
    else
        self:refreshCostItems(cfg.needCost)
    end
    self.Image_select:setVisible(self.comsumeSelected)
end



function AngleStrengthen:updateCostItem(item, data)
    local enough  = false
    local itemCfg = GoodsDataMgr:getItemCfg(data[1])
    local Image_back = TFDirector:getChildByPath(item,"Image_back")
    local Image_icon = TFDirector:getChildByPath(item,"Image_icon")
    local Label_own_count = TFDirector:getChildByPath(item,"Label_own_count")
    Image_back:setTexture(EC_ItemIcon[itemCfg.quality])
    Image_icon:setTexture(itemCfg.icon)
    local haveNum = GoodsDataMgr:getItemCount(data[1])
    Label_own_count:setString(Utils:format_number(haveNum).."/"..data[2])
    if haveNum < data[2] then
        Label_own_count:setFontColor(ccc3(219,50,50))
        enough = false
    else
        Label_own_count:setFontColor(ccc3(255,255,255))
        enough = true
    end
    return enough
end



function AngleStrengthen:refreshCostItems(consume)

    self.ListView_items:removeAllItems()
    local common_consume_count = 0
    consume = consume or {}
    local enough = true
    for k, v in pairs(consume) do
        if v[1] == Common_Consume_Item_Id then  --特殊道具额外显示
            common_consume_count = common_consume_count + v[2]
        end

        local item   = self.Panel_item:clone()
        local _enough =self:updateCostItem(item, v)
        if not _enough then 
            enough = false
        end
        self.ListView_items:pushBackCustomItem(item)
        item:setScale(0.8)
        item:setTouchEnabled(true)
        item:onClick(function()
            Utils:showInfo(v[1], nil, true)
        end)
    
    end

    local haveNum = GoodsDataMgr:getItemCount(Common_Consume_Item_Id)
    local _enough = haveNum >= common_consume_count 
    -- if not _enough then 
    --     enough = false
    -- end
    if common_consume_count > 0 then 
        self.Label_item_count:setString(Utils:format_number(haveNum).."/"..common_consume_count)
        self.Label_item_count:setFontColor(_enough and ccc3(255, 255, 255) or ccc3(255, 0, 0))
    else
        self.Label_item_count:setString(Utils:format_number(haveNum))
        self.Label_item_count:setFontColor(ccc3(255, 255, 255)) 
    end

    local show  = self.selectLevel == self.strengthLevel + 1
    --dump({"locked" ,locked  ,self.selectLevel  , self.strengthLevel})
    if show then 
        self.Button_sure:show()
        self.Button_sure:setGrayEnabled(not enough)
        self.Button_sure:setTouchEnabled(enough)
    else
        self.Button_sure:hide()
    end


end



function AngleStrengthen:registerEvents()
    EventMgr:addEventListener(self,EV_HERO_ANGEL_STRENGTHEN,handler(self.onAngelStrengthen, self)) 
    self.Button_sure:onClick(function ()
        -- print("sendUpgradePet:"..tostring(self.petId))
        -- PetDataMgr:sendUpgradePet(self.petId)
        AngelDataMgr:sendAngelStregthen(self.showHeroId, self.skillType ,self.comsumeSelected)
    end)
    self.Panel_consume:setTouchEnabled(true)
    self.Panel_consume:onClick(function ()
        self.comsumeSelected = not self.comsumeSelected
        self:refreshCost()
    end)
end


function AngleStrengthen:onAngelStrengthen(data)
    -- print("AngleStrengthen:onAngelStrengthen")
    -- dump({self.showHeroId ,data})
    -- Box("111")
    if data.heroId == tostring(self.showHeroId) then 
        self.strengthLevel = data.lv
        self:onSelect(self.selectLevel)
        -- Utils:showTips("强化成功")
        self:playLevelUpAnimation()
    end
end











-- function AngleStrengthen:registerEvents()
--     EventMgr:addEventListener(self,EV_PET_CHANGE,handler(self.onPetChange, self))
--     EventMgr:addEventListener(self,EV_BAG_PET_UPDATE,handler(self.onBagPetUpdate, self))
    
--     self.Button_change_pet:onClick(function ()
--             local _petData = HeroDataMgr:getPet(self.heroId)
--             local cfg      = self:getSelectConfigs()
--             local data     = PetDataMgr:getPetDataByCid(cfg.id)
--             if not data then  --TODO 容错
--                 Utils:showTips("还未获得该宠物")
--                 return 
--             end
--             local petId    = data.id
--             if _petData and _petData.id  == petId then --卸下
--                 PetDataMgr:sendEquipPet(2,self.heroId,petId)
--             else
--                 if not string.isNullOrEmptyOrZero(data.heroId)  then  --已经装备在其他精灵 二次确认提示
--                     local heroData = HeroDataMgr:getHero(tonumber(data.heroId))
--                     local heroName = TextDataMgr:getText(heroData.name)
--                     -- print(data.heroId)
--                     -- dump(heroData)
--                     local args = {
--                         tittle  = 2107025,
--                         content = "宠物已经装备于[".. heroName .."]精灵是否确认卸下并装备",   --TextDataMgr:getText(18000212),
--                         reType  = nil,
--                         confirmCall = function()
--                              PetDataMgr:sendEquipPet(1,self.heroId,petId)
--                         end,
--                     }
--                      Utils:showReConfirm(args)
--                 else
--                     PetDataMgr:sendEquipPet(1,self.heroId,petId)
--                 end   
--             end
--             print("确认更换宠物:" .. petId)

--     end)
-- end

return AngleStrengthen