local PetChangelView = class("PetChangelView", BaseLayer)

function PetChangelView:ctor(data)
    self.super.ctor(self,data)
    self.heroId = data
    self:initData()
    self:init("lua.uiconfig.secondary.uiconfig_zn.fairyNew.petChangeView")
end

function PetChangelView:initData()
    self.configs = {} 
    local cfgs  = PetDataMgr:getPetCfgs() 
    for k,v in pairs(cfgs) do
        if v.display then 
            table.insert(self.configs ,v)
        end
    end

    table.sort(self.configs,function (a , b)
        local dataA  = PetDataMgr:getPetDataByCid(a.id)
        local dataB  = PetDataMgr:getPetDataByCid(b.id)
        -- if dataA and dataB then 
        --     return dataA.star > dataB.star
        -- elseif dataA then 
        --     return true
        -- elseif dataB then
        --     return false
        -- else
        --     return a.endStar > b.endStar
        -- end
        if dataA or dataB then 
            return (dataA and dataA.star or -1) >  (dataB and dataB.star or -1)
        else
            return a.endStar > b.endStar
        end

    end)

end

function PetChangelView:initUI(ui)
    self.super.initUI(self,ui)
    self.ui = ui
    self.Panel_content   = TFDirector:getChildByPath(ui, "Panel_content")


    self.Button_change_pet = TFDirector:getChildByPath(self.Panel_content, "Button_change_pet")

    self.Label_change   = TFDirector:getChildByPath(self.Button_change_pet, "Label_change")
    self.Label_pet_name = TFDirector:getChildByPath(self.Panel_content, "Label_pet_name")
    self.Label_name = TFDirector:getChildByPath(self.Panel_content, "Label_name")
    self.Image_pet =  TFDirector:getChildByPath(self.Panel_content, "Image_pet") --宠物动画节点
    self.nodePetStars   = {}
    local Panel_star =  TFDirector:getChildByPath(self.Panel_content, "Panel_star")
    for i=1,6 do
        self.nodePetStars[i] = TFDirector:getChildByPath(Panel_star, "Image_star"..i)
        self.nodePetStars[i].imageStar = TFDirector:getChildByPath(self.nodePetStars[i], "Image_star")
    end

    self.Label_pet_skill_desc = TFDirector:getChildByPath(self.Panel_content, "Label_pet_skill_desc")
    local Panel_pet_level =TFDirector:getChildByPath(self.Panel_content, "Panel_pet_level")
    self.Label_pet_level = TFDirector:getChildByPath(Panel_pet_level, "Label_pet_level")
    self.Label_pet_level_max = TFDirector:getChildByPath(Panel_pet_level, "Label_pet_level_max")
    self.node_pet_attrs = {}
    for i=1,3 do --属性以此 攻击、防御、血量 
        self.node_pet_attrs[i]         = {}
        local Panel_pet_attr_item      = TFDirector:getChildByPath(self.Panel_content, "Panel_pet_attr_item"..i)
        self.node_pet_attrs[i].node    = Panel_pet_attr_item
        self.node_pet_attrs[i].value   = TFDirector:getChildByPath(Panel_pet_attr_item, "Label_att_value")
        self.node_pet_attrs[i].icon    = TFDirector:getChildByPath(Panel_pet_attr_item, "Image_att_icon")
        self.node_pet_attrs[i].name    = TFDirector:getChildByPath(Panel_pet_attr_item, "Label_att_name")   

    end



    self.Panel_pet_item = TFDirector:getChildByPath(self.Panel_content, "Panel_pet_item2")



    local ScrollView_pets = TFDirector:getChildByPath(self.Panel_content,"ScrollView_pets")
    self.ListView_pet = UIGridView:create(ScrollView_pets)
    self.ListView_pet:setItemModel(self.Panel_pet_item)
    self.ListView_pet:setColumn(4)
    self.ListView_pet:setRowMargin(0)
    self.ListView_pet:setColumnMargin(0)

    self:initItems()

end

function PetChangelView:setLang()
    self.Label_name:setTextById(290000108)
end

--显示宠物星
function PetChangelView:refreshPetStar(star,maxStar)
        -- print("star"..tostring(star) .." > " ..tostring(maxStar))
        --重置星显示的位置
    -- local startPosX = math.floor(maxStar/2)* -30 - (maxStar%2)*15
    local startPosX  =  maxStar * (-30)/2 -15
    for i,v in ipairs(self.nodePetStars) do
        v:setPositionX(startPosX + i*30)
    end
    for i,v in ipairs(self.nodePetStars) do
        v:setVisible(i<= maxStar)
        v.imageStar:setVisible(i <= star)
    end
end
function PetChangelView:getSelectConfigs()
    return self.configs[self.selectIndex]
end

function PetChangelView:setSelectIndex(index)
    self.selectIndex = index
    self:refreshItems()
    self:refresPetInfo()
end

function PetChangelView:initItems()
    local targetCount = #self.configs  
    -- local items     = self.ListView_pet:getItems()
    -- local itemCount = #items
    self.ListView_pet:removeAllItems()
    for i = 1, targetCount do
        local cfg  = self.configs[i]     --PetDataMgr:getPetCfg(data.cid)
        local data =  PetDataMgr:getPetDataByCid(cfg.id)       --TODO  临时测试数据

        local maxStar = cfg.endStar
        local level  = data and data.level or 1
        local star   = data and data.star or 0
        local heroId = data and data.heroId or ""
        local item  = self.ListView_pet:pushBackDefaultItem()
        item._id   = cfg.id
        local Image_bg = TFDirector:getChildByPath(item,"Image_bg")
        local Image_level_bg = TFDirector:getChildByPath(item,"Image_level_bg")
        local Image_icon = TFDirector:getChildByPath(item,"Image_icon")
        item.Image_select = TFDirector:getChildByPath(item,"Image_select")
        local Label_level_title = TFDirector:getChildByPath(item,"Label_level_title")
        local Label_level = TFDirector:getChildByPath(item,"Label_level")
        item.Image_use = TFDirector:getChildByPath(item,"Image_use")
        item.Image_lock = TFDirector:getChildByPath(item,"Image_lock")
        Label_level_title:setString("Lv.")
        Image_icon:setTexture(cfg.icon)
        Image_bg:setTexture(EquipmentDataMgr:getNewEquipQualityIcon(cfg.quality))
        item.Image_lock:setVisible(not data)
        local Panel_stars = TFDirector:getChildByPath(item,"Panel_stars")
        for i=1,6 do
            local Image_star = TFDirector:getChildByPath(Panel_stars,"Image_star"..i)
            if i <= maxStar then
                Image_star:setVisible(true)
                Image_star:setPositionX(-55 + (5 - maxStar) * 10 + i * 18)
                if i <= star then
                    Image_star:setTexture("ui/common/star.png")
                else
                    Image_star:setTexture("ui/common/starBack.png")
                end
            else
                Image_star:setVisible(false)
            end
        end
        Image_bg:setTexture(EC_ItemIcon[cfg.quality])
        Image_level_bg:setTexture(EC_ItemLevelIcon[cfg.quality])
        Label_level:setString(tostring(level))
        item.Image_select:setVisible(false)

        item.Image_use:setVisible(not string.isNullOrEmptyOrZero(heroId))
        item:setTouchEnabled(true)
        item:onClick(function()
            print("click Itgem ")
            self:setSelectIndex(i)
        end)
    end
    self:setSelectIndex(1)
end

function PetChangelView:refreshItems()
    local items = self.ListView_pet:getItems()
    for i , item in ipairs(items) do
        item.Image_select:setVisible(i == self.selectIndex)
        local cfg = self.configs[i]
        local data = PetDataMgr:getPetDataByCid(cfg.id)
        local heroId  = data and data.heroId or "0" 
        print("heroId:" ..tostring(heroId))
        item.Image_use:setVisible(not string.isNullOrEmptyOrZero(heroId))
    end
end

function PetChangelView:refresPetInfo()

    local petCfg  = self:getSelectConfigs()    
    if not petCfg then return end    
    local petData = PetDataMgr:getPetDataByCid(petCfg.id)
    local star  = petData and petData.star or 0
    local level = petData and petData.level or 1
    --名称
    self.Label_pet_name:setTextById(petCfg.nameTextId)

    local des    = PetDataMgr:getPetSkillDes(petCfg.id,star) 
    --登录
    self.Label_pet_skill_desc:setTextById(des)
    --等级
    self.Label_pet_level:setText(tostring(level))

    self.Label_pet_level_max:setText("")

    --属性
    local attrs = PetDataMgr:getAttributes(petCfg.id, star,level)

    for i,v in ipairs(self.node_pet_attrs) do
        if i <= #attrs then 
            local attr   = attrs[i]
            local attrCfg = HeroDataMgr:getAttributeConfig(attr.id)
            v.icon:setTexture(attrCfg.icon)
            v.name:setTextById(attrCfg.name)
            v.value:setText(tostring(attr.value))
        end
    end


    --星级
    self:refreshPetStar(star,petCfg.endStar)

    --宠物spine 创建
    self.Image_pet:setVisible(true)
    if self.modelPet and self.modelPet._paint ~=  petCfg.paint then 
        self.modelPet:removeFromParent()
        self.modelPet = nil
    end
    if not self.modelPet then --刷新宠物模型
        self.modelPet = SkeletonAnimation:create(petCfg.paint)
        -- self.modelPet:setAnimationFps(GameConfig.ANIM_FPS)
        self.modelPet:play(petCfg.defaultAct or "idle",1)
        self.modelPet:setScale(petCfg.paintSize or 1)
        self.modelPet:setPosition(ccp(0,-50))
        self.Image_pet:addChild(self.modelPet)
        self.modelPet._paint = petCfg.paint
    end

    self.Button_change_pet:setVisible(petData ~= nil)

    local _petData = HeroDataMgr:getPet(self.heroId)

    if _petData and petData and _petData.id  == petData.id  then 
        self.Label_change:setTextById(1100006)
    else
        self.Label_change:setTextById(3202043)
    end
end

function PetChangelView:onPetChange()
    -- AlertManager:closeLayer(self)
    self:refreshItems()
    self:refresPetInfo()
    Utils:showTips(800068)
end

--背包宠物数量变更
function PetChangelView:onBagPetUpdate()

end

function PetChangelView:registerEvents()
    EventMgr:addEventListener(self,EV_PET_CHANGE,handler(self.onPetChange, self))
    EventMgr:addEventListener(self,EV_BAG_PET_UPDATE,handler(self.onBagPetUpdate, self))
    
    self.Button_change_pet:onClick(function ()
            local _petData = HeroDataMgr:getPet(self.heroId)
            local cfg      = self:getSelectConfigs()
            local data     = PetDataMgr:getPetDataByCid(cfg.id)
            if not data then  --TODO 容错
                Utils:showTips(290000109)
                return 
            end
            local petId    = data.id
            if _petData and _petData.id  == petId then --卸下
                PetDataMgr:sendEquipPet(2,self.heroId,petId)
            else
                if not string.isNullOrEmptyOrZero(data.heroId)  then  --已经装备在其他精灵 二次确认提示
                    local heroData = HeroDataMgr:getHero(tonumber(data.heroId))
                    local heroName = TextDataMgr:getText(heroData.name)
                    -- print(data.heroId)
                    -- dump(heroData)
                    local args = {
                        tittle  = 2107025,
                        content = TextDataMgr:getText(290000110,heroName),
                        reType  = nil,
                        confirmCall = function()
                             PetDataMgr:sendEquipPet(1,self.heroId,petId)
                        end,
                    }
                     Utils:showReConfirm(args)
                else
                    PetDataMgr:sendEquipPet(1,self.heroId,petId)
                end   
            end
            print("确认更换宠物:" .. petId)

    end)
end

return PetChangelView