local PetStrengthenView = class("PetStrengthenView", BaseLayer)

function PetStrengthenView:ctor(data)
    self.super.ctor(self,data)
    self.petId = data -- 或者当前使用的宠物ID
    self:initData()
    self:init("lua.uiconfig.secondary.uiconfig_zn.fairyNew.petStrengthenView")
end

function PetStrengthenView:initData()
    --组织科用来来强化的资源
    self.itemDatas = {
     {
         id = 510101,
         num    = 16
     },
     {
         id = 510102,
         num    = 5
     },
     {
         id = 510103,
         num    = 22
     },
     {
         id = 510104,
         num    = 67
     },
     {
         id = 510105,
         num    = 9906
     }
 }
end

function PetStrengthenView:getClosingStateParams()
    return {self.paramData_}
end

function PetStrengthenView:initUI(ui)
    self.super.initUI(self,ui)
    self.ui = ui



    self.Panel_content   = TFDirector:getChildByPath(ui, "Panel_content")


    self.Button_sure = TFDirector:getChildByPath(self.Panel_content, "Button_sure")

    self.Label_change = TFDirector:getChildByPath(self.Button_sure, "Label_change")

    self.Label_pet_name = TFDirector:getChildByPath(self.Panel_content, "Label_pet_name")
    self.Image_pet =  TFDirector:getChildByPath(self.Panel_content, "Image_pet") --宠物动画节点



    self.Panel_starup =  TFDirector:getChildByPath(self.Panel_content, "Panel_starup")
    self.Panel_star =  TFDirector:getChildByPath(self.Panel_content, "Panel_star")


    self.Panel_star1 =  TFDirector:getChildByPath(self.Panel_starup, "Panel_star1")
    self.Panel_star2 =  TFDirector:getChildByPath(self.Panel_starup, "Panel_star2")






    self.Label_pet_skill_desc = TFDirector:getChildByPath(self.Panel_content, "Label_pet_skill_desc")


    self.Label_pet_skill_desc2 = TFDirector:getChildByPath(self.Panel_content, "Label_pet_skill_desc2")
    local Panel_pet_level =TFDirector:getChildByPath(self.Panel_content, "Panel_pet_level")
    self.Label_pet_level = TFDirector:getChildByPath(Panel_pet_level, "Label_pet_level")
    self.Label_pet_level_next = TFDirector:getChildByPath(Panel_pet_level, "Label_pet_level_next")
    self.Spine_levelup = TFDirector:getChildByPath(Panel_pet_level, "Spine_levelup")
    self.Spine_levelup:hide()

    -- self.Label_pet_attrs = {}
    -- self.Label_pet_attrs_next = {}
    -- for i=1,3 do --属性以此 攻击、防御、血量 
    --     local Panel_pet_attr_item = TFDirector:getChildByPath(self.Panel_content, "Panel_pet_attr_item"..i)
    --     self.Label_pet_attrs[i]  = TFDirector:getChildByPath(Panel_pet_attr_item, "Label_att_value")
    --     self.Label_pet_attrs_next[i]  = TFDirector:getChildByPath(Panel_pet_attr_item, "Label_att_value_next")
    -- end


    self.node_pet_attrs = {}
    for i=1,3 do --属性以此 攻击、防御、血量 
        self.node_pet_attrs[i]         = {}
        local Panel_pet_attr_item      = TFDirector:getChildByPath(self.Panel_content, "Panel_pet_attr_item"..i)
        self.node_pet_attrs[i].node    = Panel_pet_attr_item
        self.node_pet_attrs[i].value   = TFDirector:getChildByPath(Panel_pet_attr_item, "Label_att_value")
        self.node_pet_attrs[i].icon    = TFDirector:getChildByPath(Panel_pet_attr_item, "Image_att_icon")
        self.node_pet_attrs[i].name    = TFDirector:getChildByPath(Panel_pet_attr_item, "Label_att_name") 
        self.node_pet_attrs[i].value_next   = TFDirector:getChildByPath(Panel_pet_attr_item, "Label_att_value_next")  
    end



    self.Panel_item = TFDirector:getChildByPath(self.Panel_content, "Panel_item")
    self.Panel_goodsItem = TFDirector:getChildByPath(self.Panel_content, "Panel_goodsItem")





    local ScrollView_items = TFDirector:getChildByPath(self.Panel_content,"ScrollView_items")
 
    self.ListView_items = UIListView:create(ScrollView_items)
    self.ListView_items:setItemsMargin(2)
    self:setLang()
    -- self:refreshConsumeItems()
    self:refreshPetInfo()

    self:refreshLeveUpInfo()
end

function PetStrengthenView:setLang()
    local Label_attr_title = TFDirector:getChildByPath(self.Panel_content, "Label_attr_title")
    local Label_skill_title = TFDirector:getChildByPath(self.Panel_content, "Label_skill_title")
    local Label_consume_title = TFDirector:getChildByPath(self.Panel_content, "Label_consume_title")
    Label_attr_title:setTextById(290000098)
    Label_skill_title:setTextById(290000099)
    Label_consume_title:setTextById(300020)
end

--显示宠物星
function PetStrengthenView:refreshPetStar(Panel_star, star,maxStar)
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




function PetStrengthenView:refreshPetInfo()


    
    local petData = PetDataMgr:getPetData(self.petId)
    if not petData then 
        return
    end

    local petId   = petData.cid

    local petCfg  = PetDataMgr:getPetCfg(petId)   
    --名称
    self.Label_pet_name:setTextById(petCfg.nameTextId)


    --宠物spine 创建
    self.Image_pet:setVisible(true)

    if self.modelPet and self.modelPet._paint ~=  petCfg.paint then 
        self.modelPet:removeFromParent()
        self.modelPet = nil
    end
    if not self.modelPet then --刷新宠物模型
        self.modelPet = SkeletonAnimation:create(petCfg.paint)
        -- self.modelPet:setAnimationFps(GameConfig.ANIM_FPS)
        --self.modelPet:playByIndex(0, -1, -1, 1)         
        self.modelPet:play(petCfg.defaultAct or "idle",1)
        self.modelPet:setScale(petCfg.paintSize or 1)
        self.modelPet:setPosition(ccp(0,-50))
        self.Image_pet:addChild(self.modelPet)
        self.modelPet._paint = petCfg.paint
    end



end
function PetStrengthenView:refreshLeveUpInfo()


    local petData     = PetDataMgr:getPetData(self.petId)
    if not petData then 
        return
    end

    local petCid       = petData.cid
    local petCfg      = PetDataMgr:getPetCfg(petCid)   
    local upgradeType = PetDataMgr:getUpgradeType(self.petId)

    --等级
    self.Label_pet_level:setText(tostring(petData.level))
    
    local nextStar  = petData.star
    local nextLevel = petData.level
    local consume   = {}

    if upgradeType == 1 then --升级
        --升级后的等级
        nextLevel = nextLevel + 1
        consume = PetDataMgr:getStrengthenCfg(nextLevel).consume
        self.Label_pet_skill_desc2:setText("")

        self.Panel_star:show()
        self.Panel_starup:hide()
        self:refreshPetStar(self.Panel_star, petData.star,petCfg.endStar)
        self.Label_change:setTextById(290000101)

    elseif upgradeType == 2 then   --升阶
        nextStar   = nextStar + 1
        consume  = PetDataMgr:getAdvanceCfg(petCid, petData.star).consume
        local des2    = PetDataMgr:getPetSkillDes2(petCid,petData.star) 
        self.Label_pet_skill_desc2:setTextById(des2)
        self.Panel_star:hide()
        self.Panel_starup:show()
        self:refreshPetStar(self.Panel_star1, petData.star   , petCfg.endStar)
        self:refreshPetStar(self.Panel_star2, petData.star +1, petCfg.endStar)
        self.Label_change:setTextById(290000111)
    else
        self.Panel_star:show()
        self.Panel_starup:hide()
            self.Label_pet_skill_desc2:setText("")
        self:refreshPetStar(self.Panel_star, petData.star,petCfg.endStar)
        -- self.Label_change:setText("进 化")
        self.Label_change:setTextById(500037)

        self.Button_sure:setGrayEnabled(true)
        self.Button_sure:setTouchEnabled(false)
    end


   

    -- dump({ nextLevel , nextStar})
    -- Box("ss")
    self.Label_pet_level_next:setText(tostring(nextLevel))
    --属性
    local attrs      = PetDataMgr:getAttributes(petCid, petData.star, petData.level)
    local nextAttrKV = PetDataMgr:getAttributeKV(petCid,nextStar, nextLevel)
    for i,v in ipairs(self.node_pet_attrs) do
        if i <= #attrs then 
            local attr   = attrs[i]
            local attrCfg = HeroDataMgr:getAttributeConfig(attr.id)
            v.icon:setTexture(attrCfg.icon)
            v.name:setTextById(attrCfg.name)
            v.value:setText(tostring(attr.value))
            v.value_next:setText(tostring(nextAttrKV[attr.id] or 0))
        end
    end


    local des    = PetDataMgr:getPetSkillDes(petCid,petData.star) 


    --技能描述
    self.Label_pet_skill_desc:setTextById(des)




    self:refreshCostItems(consume)
end

--刷新消耗的道具
-- function PetStrengthenView:refreshConsumeItems()
--     for i,data in ipairs(self.itemDatas) do
--         local panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
--         PrefabDataMgr:setInfo(panel_goodsItem, data.id ,data.num,nil,true)
--         self.ListView_items:pushBackCustomItem(panel_goodsItem)
--     end
-- end


function PetStrengthenView:refreshCostItems(consume)
    self.ListView_items:removeAllItems()
    -- self.gold_cost = 0
    consume = consume or {}
    for k, v in pairs(consume) do
        -- if v[1] == EC_SItemType.GOLD then
        --     self.gold_cost = v[2]
        -- else
            local item = self.Panel_item:clone()
            self:updateCostItem(item, v)
            self.ListView_items:pushBackCustomItem(item)
            item:setScale(0.8)
            item:setTouchEnabled(true)
            item:onClick(function()
                Utils:showInfo(v[1], nil, true)
            end)
        -- end
    end
end

function PetStrengthenView:updateCostItem(item, data)
    local itemCfg = GoodsDataMgr:getItemCfg(data[1])
    local Image_back = TFDirector:getChildByPath(item,"Image_back")
    local Image_icon = TFDirector:getChildByPath(item,"Image_icon")
    local Label_own_count = TFDirector:getChildByPath(item,"Label_own_count")
    Image_back:setTexture(EC_ItemIcon[itemCfg.quality])
    Image_icon:setTexture(itemCfg.icon)
    local haveNum = GoodsDataMgr:getItemCount(data[1])
    Label_own_count:setString(Utils:format_number(haveNum).."/"..data[2])
    if haveNum < data[2] then
        self.Button_sure:setGrayEnabled(true)
        self.Button_sure:setTouchEnabled(false)
        Label_own_count:setFontColor(ccc3(255,0,0))
        Label_own_count:enableStroke(ccc3(255, 255, 255), 1)
    else
        self.Button_sure:setGrayEnabled(false)
        self.Button_sure:setTouchEnabled(true)
        Label_own_count:setFontColor(ccc3(255,255,255))
        Label_own_count:enableStroke(ccc3(0, 0, 0), 1)
    end
end

function PetStrengthenView:playLevelUpAnimation()

    --播放升级动画
    self.Spine_levelup:show()
    self.Spine_levelup:playByIndex(0, -1, -1, 0)
    self.Spine_levelup:addMEListener(TFARMATURE_COMPLETE,function()
        self.Spine_levelup:hide()
    end)

end

--宠物升级
function PetStrengthenView:onLevelUp(_type)
    self:refreshPetInfo()
    self:refreshLeveUpInfo()
    -- self:refreshConsumeItems()
    if _type == 1 then 
        self:playLevelUpAnimation()
    elseif _type == 2 then
        Utils:openView("fairyNew.PetStarUpSuccess", self.petId)
    end
    


    --TODO 需要区分是升级 还是升阶
end

function PetStrengthenView:onShow()

    self:refreshPetInfo()   
    self:refreshLeveUpInfo()
end

function PetStrengthenView:onPetDataUpdate()
    self:refreshPetInfo()   
    self:refreshLeveUpInfo()
    --Box("1111")
end

function PetStrengthenView:registerEvents()
    EventMgr:addEventListener(self,EV_PET_LEVEUP,handler(self.onLevelUp, self))
    EventMgr:addEventListener(self,EV_BAG_PET_UPDATE,handler(self.onPetDataUpdate, self))
    self.Button_sure:onClick(function ()
        print("sendUpgradePet:"..tostring(self.petId))
        PetDataMgr:sendUpgradePet(self.petId)
    end)
end

return PetStrengthenView




