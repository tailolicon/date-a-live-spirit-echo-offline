local SummonPetView = class("SummonPetView", BaseLayer)

function SummonPetView:ctor(summonId)
    self.super.ctor(self)
    self:initData(summonId)
    self:init("lua.uiconfig.secondary.uiconfig_zn.summon.summonPetView")
end





    
    -- EventMgr:addEventListener(self, EV_SUMMON_UPATE_EQUIP, handler(self.onRecvUpdateData, self))



function SummonPetView:initData(summonId)
    self.summonId  = summonId
    self.wishDatas = SummonDataMgr:getPetWishCard(self.summonId)
    -- table.sort(self.wishDatas,function (a , b)
    --     return a.item.endStar > b.item.endStar
    -- end)
    local wishPool = SummonDataMgr:getWishSummonPool(self.summonId)
    self.selectIndex = 1
    if wishPool > 0 then 
        for i,v in ipairs(self.wishDatas) do
            if v.pool == wishPool then 
                self.selectIndex = i
                break
            end
        end
    end
end

function SummonPetView:initUI(ui)
    self.super.initUI(self,ui)
    self.ui = ui
    self.Panel_content   = TFDirector:getChildByPath(ui, "Panel_content")
    self.Button_change_pet = TFDirector:getChildByPath(self.Panel_content, "Button_change_pet")
    self.Label_title_name  = TFDirector:getChildByPath(self.Panel_content, "Label_title_name")

    self.Label_change   = TFDirector:getChildByPath(self.Button_change_pet, "Label_change")
    self.Label_pet_name = TFDirector:getChildByPath(self.Panel_content, "Label_pet_name")
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
    self:setLang()
    self:initItems()

end
function SummonPetView:setLang()
    self.Label_title_name:setTextById(290000108)
end


--显示宠物星
function SummonPetView:refreshPetStar(star,maxStar)
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
function SummonPetView:getSelectData()
    return self.wishDatas[self.selectIndex]
end

function SummonPetView:setSelectIndex(index)
    self.selectIndex = index
    self:refreshItems()
    self:refresPetInfo()
end

function SummonPetView:initItems()
    local targetCount = #self.wishDatas  
    -- local items     = self.ListView_pet:getItems()
    -- local itemCount = #items
    self.ListView_pet:removeAllItems()
    local wishPool = SummonDataMgr:getWishSummonPool(self.summonId)

    for i = 1, targetCount do
        local wishData =self.wishDatas[i]

        local cfg   =   PetDataMgr:getPetCfg(wishData.item)
        local data = nil 

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
        item.Image_lock:setVisible(false)
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

        item.Image_use:setVisible(wishData.pool == wishPool)
        item:setTouchEnabled(true)
        item:onClick(function()
            print("click Itgem ")
            self:setSelectIndex(i)
        end)
    end
    self:setSelectIndex(self.selectIndex or 1)
end

function SummonPetView:refreshItems()
    local items = self.ListView_pet:getItems()
    local wishPool = SummonDataMgr:getWishSummonPool(self.summonId)
    for i , item in ipairs(items) do
        local wishData = self.wishDatas[i]
        item.Image_select:setVisible(i == self.selectIndex)
        item.Image_use:setVisible(wishData.pool == wishPool)
    end
end

function SummonPetView:refresPetInfo()
    local data    = self:getSelectData()   
    local petCfg  =  PetDataMgr:getPetCfg(data.item)        


    local star  =  0
    local level =  1
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

    local wishPool = SummonDataMgr:getWishSummonPool(self.summonId)
    if data.pool == wishPool then 
        self.Label_change:setTextById(290000114)
    else
        self.Label_change:setTextById(290000113)
    end

    self.Button_change_pet:setVisible(true)

end

function SummonPetView:onWishChange()
    -- AlertManager:closeLayer(self)
    self:refreshItems()
    self:refresPetInfo()
    Utils:showTips("设置成功")
end


function SummonPetView:registerEvents()

    EventMgr:addEventListener(self, EV_SUMMON_WISH_CHANGE, handler(self.onWishChange, self))
    self.Button_change_pet:onClick(function ()
        local data      = self:getSelectData()
   

        local wishPool = SummonDataMgr:getWishSummonPool(self.summonId)

        local summonPoolId = data.pool
        if summonPoolId == wishPool then 
            summonPoolId = 0
        end    
        print("选择心愿卡:" .. self.summonId .." > " ..tostring(summonPoolId))
        SummonDataMgr:send_SUMMON_REQ_SET_WISH_I(self.summonId, summonPoolId)

    end)
end



return SummonPetView