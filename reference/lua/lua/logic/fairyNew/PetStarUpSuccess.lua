
--宠物升阶成功
local PetStarUpSuccess = class("PetStarUpSuccess", BaseLayer)

function PetStarUpSuccess:initData(id)
    self.petId = id
    -- Box("self.petId:" ..tostring(self.petId))
end

function PetStarUpSuccess:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fairyNew.petStarUpSuccess")
end

function PetStarUpSuccess:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_touch = TFDirector:getChildByPath(ui, "Panel_touch")

    self.Panel_content = TFDirector:getChildByPath(self.Panel_root, "Panel_content")
    self.Spine_star_Up = TFDirector:getChildByPath(self.Panel_root, "Spine_star_Up")

    self.Panel_info = TFDirector:getChildByPath(self.Panel_content, "Panel_info")
    self.Label_name = TFDirector:getChildByPath(self.Panel_info, "Label_name")
    self.Image_icon1 = TFDirector:getChildByPath(self.Panel_info, "Image_icon1")
    self.Image_icon2 = TFDirector:getChildByPath(self.Panel_info, "Image_icon2")
    self.Label_level_now = TFDirector:getChildByPath(self.Panel_info, "Label_level_now")
    self.Label_level_next = TFDirector:getChildByPath(self.Panel_info, "Label_level_next")
    self.Panel_attr = TFDirector:getChildByPath(self.Panel_info, "Panel_attr")
    self.Panel_hp = TFDirector:getChildByPath(self.Panel_attr,"Panel_hp")
    self.Panel_atk = TFDirector:getChildByPath(self.Panel_attr,"Panel_atk")
    self.Panel_def = TFDirector:getChildByPath(self.Panel_attr,"Panel_def")

    self.old_atk = TFDirector:getChildByPath(self.Panel_atk, "old_atk")
    self.old_def = TFDirector:getChildByPath(self.Panel_def, "old_def")
    self.old_hp = TFDirector:getChildByPath(self.Panel_hp, "old_hp")
    self.new_atk = TFDirector:getChildByPath(self.Panel_atk, "new_atk")
    self.new_def = TFDirector:getChildByPath(self.Panel_def, "new_def")
    self.new_hp = TFDirector:getChildByPath(self.Panel_hp, "new_hp")

    self.label_hp = TFDirector:getChildByPath(self.Panel_hp, "label_hp")
    self.label_atk = TFDirector:getChildByPath(self.Panel_atk, "label_atk")
    self.label_def = TFDirector:getChildByPath(self.Panel_def, "label_def")
    local attrAtkCfg = HeroDataMgr:getAttributeConfig(EC_Attr.ATK)
    local attrDefCfg = HeroDataMgr:getAttributeConfig(EC_Attr.DEF)
    local attrHpCfg = HeroDataMgr:getAttributeConfig(EC_Attr.HP)
    self.label_hp:setTextById(attrHpCfg.name)
    self.label_atk:setTextById(attrAtkCfg.name)
    self.label_def:setTextById(attrDefCfg.name)


    self.equip_stars = {}
    for i = 1, 12 do
        self.equip_stars[i] = TFDirector:getChildByPath(self.Panel_content,"Image_star"..i)
    end

    self.Spine_star_Up:play("chuxian",false)
    self.Spine_star_Up:addMEListener(TFARMATURE_COMPLETE,function()
        self:timeOut(function()
            self.Spine_star_Up:removeMEListener(TFARMATURE_COMPLETE)
            self.Spine_star_Up:play("xunhuan",true)
        end, 0)
    end) 

    self:refreshView()
end

function PetStarUpSuccess:refreshView()

    local petData = PetDataMgr:getPetData(self.petId)
    if not petData then 
        return
    end
    local petCid  = petData.cid
    local petCfg  = PetDataMgr:getPetCfg(petCid)   

    self.Label_name:setTextById(petCfg.nameTextId)
    self.Image_icon1:setTexture(petCfg.icon)
    self.Image_icon2:setTexture(petCfg.icon)
    self.Label_level_now:setString(tostring(petData.level))
    self.Label_level_next:setString(tostring(petData.level))


    local maxStar = petCfg.endStar
    -- dump(petCfg)
    -- Box("maxStar:" ..tostring(maxStar))
    for i,v in ipairs(self.equip_stars) do
        if i < 7 then
            if i <= maxStar then
                v:setVisible(true)
                v:setPositionX(118 + (6 - maxStar) * 12 + i * 24)
                if i <= petData.star - 1 then
                    v:setTexture("ui/common/star.png")
                else
                    v:setTexture("ui/common/starBack.png")
                end
            else
                v:setVisible(false)
            end
        else
            if (i - 6) <= maxStar then
                v:setVisible(true)
                v:setPositionX(338 + (6 - maxStar) * 12 + (i - 6) * 24)
                if (i - 6) <= petData.star then
                    v:setTexture("ui/common/star.png")
                else
                    v:setTexture("ui/common/starBack.png")
                end
            else
                v:setVisible(false)
            end
        end
    end
    local star  = petData.star
    local attrValues1 = PetDataMgr:getAttributeKV(petCid, star  -1 , petData.level)
    local attrValues2 = PetDataMgr:getAttributeKV(petCid, star  , petData.level)
    self.old_atk:setText(tostring(attrValues1[EC_Attr.ATK] or 0))
    self.old_def:setText(tostring(attrValues1[EC_Attr.DEF] or 0))
    self.old_hp:setText(tostring(attrValues1[EC_Attr.HP] or 0))
    self.new_atk:setText(tostring(attrValues2[EC_Attr.ATK] or 0))
    self.new_def:setText(tostring(attrValues2[EC_Attr.DEF] or 0))
    self.new_hp:setText(tostring(attrValues2[EC_Attr.HP] or 0))

    local position = {ccp(17, 80), ccp(17, 50), ccp(17,20)}
    local hpValue = attrValues2[EC_Attr.HP] or 0 
    local atkValue = attrValues2[EC_Attr.ATK] or 0
    local defValue = attrValues2[EC_Attr.DEF] or 0
    self.Panel_hp:setVisible(true)
    self.Panel_atk:setVisible(true)
    self.Panel_def:setVisible(true)
    self.Panel_hp:setPosition(position[1])
    self.Panel_atk:setPosition(position[2])
    self.Panel_def:setPosition(position[3])

    if hpValue <= 0 then
        self.Panel_def:setPosition(self.Panel_atk:getPosition())
        self.Panel_atk:setPosition(self.Panel_hp:getPosition())
        self.Panel_hp:setVisible(false)
    end
    if atkValue <= 0 then
        self.Panel_def:setPosition(self.Panel_atk:getPosition())
        self.Panel_atk:setVisible(false)
    end
    if defValue <= 0 then
        self.Panel_def:setVisible(false)
    end
end

function PetStarUpSuccess:registerEvents()
    self.Panel_touch:setTouchEnabled(true)
    self.Panel_touch:onClick(function()
        AlertManager:closeLayer(self)
    end)
end

return PetStarUpSuccess
