local AngleStrengthenMain = class("AngleStrengthenMain", BaseLayer)

function AngleStrengthenMain:ctor(data)
    self.super.ctor(self,data)
    self.showHeroId = data.heroId
    -- dump(data)
    -- Box("self.showHeroId:"..tostring(   self.showHeroId))
    -- self:initData()
    self:init("lua.uiconfig.secondary.uiconfig_zn.fairyNew.angleStrengthenMain")
end

function AngleStrengthenMain:initData()

end


local _skillTypes = {1,2,3,4,6}

function AngleStrengthenMain:initUI(ui)
    self.super.initUI(self,ui)
    self.ui = ui
    self.Panel_content   = TFDirector:getChildByPath(ui, "Panel_content")
    self.Image_angel     = TFDirector:getChildByPath(self.Panel_content, "Image_model")
    local modelPath      = HeroDataMgr:getAngelModelPath(self.showHeroId);
    local posOffset      = HeroDataMgr:getAngelModelPosOffset(self.showHeroId);
    local scale          = HeroDataMgr:getAngelModelScale(self.showHeroId)
    local angelModel     = SkeletonAnimation:create(modelPath)
    angelModel:setAnimationFps(GameConfig.ANIM_FPS)
    angelModel:playByIndex(0, -1, -1, 1)
    self.Image_angel:addChild(angelModel)
    angelModel:setPositionX(posOffset.x)
    angelModel:setPositionY(posOffset.y)
    angelModel:setScale(scale * 0.8);
   
    self.Panel_star   = TFDirector:getChildByPath(self.Panel_content, "Panel_star")
    self.Label_level  = TFDirector:getChildByPath(self.Panel_star, "Label_level")
    self.Label_name   = TFDirector:getChildByPath(self.Panel_star, "Label_name")
    local name        = HeroDataMgr:getAngelName(self.showHeroId)
    self.Label_name:setTextById(name);
    self.Label_level:setText("Lv."..HeroDataMgr:getAngelBreakLevel(self.showHeroId, false))

    local angelLv = HeroDataMgr:getAngelLevel(self.showHeroId)
    self:refreshStar(self.Panel_star,angelLv,5)

    self.nodes = {}
    for i=1,5 do
        local skillType    = _skillTypes[i]
        local skillIcon    = AngelDataMgr:getSkillIcon(self.showHeroId ,skillType)

        local node         = TFDirector:getChildByPath(self.Panel_content, "Panel_skill"..i)
        node.Label_click   = TFDirector:getChildByPath(node, "Label_click")
        node.Label_desc    = TFDirector:getChildByPath(node, "Label_desc")
        node.Button_click  = TFDirector:getChildByPath(node, "Button_click")
        node.Image_icon    = TFDirector:getChildByPath(node, "Image_icon")
        node.Label_lv      = TFDirector:getChildByPath(node, "Label_lv")
        node.Image_icon:setTexture(skillIcon)
        node.Label_click:setTextById(2500004)

        self.nodes[i]      = node
        node.Button_click:onClick(function ()
            -- Box("1111")
             Utils:openView("fairyNew.AngleStrengthen",{heroId = self.showHeroId ,skillType = skillType})
        end)
        -- local level = AngelDataMgr:getStregthenLevel(self.showHeroId,skillType)
        -- node.Label_lv:setText("Lv."..level)
        -- -- Box("addClick "..i)
    end
    self:refreshStrengthenLevel()
end


--显示星级
function AngleStrengthenMain:refreshStar(Panel_star, star,maxStar)
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


--刷新强化等级
function AngleStrengthenMain:refreshStrengthenLevel()
    for i,node in ipairs(self.nodes) do
        local skillType    = _skillTypes[i]
        local level        = AngelDataMgr:getStregthenLevel(self.showHeroId,skillType)
        if level > 0 then 
            local strengtheCfg = AngelDataMgr:getAngleStrengtheConfig(self.showHeroId ,skillType,level)
            node.Label_desc:setTextById(strengtheCfg.nameId)
            node.Label_lv:setText("Lv."..level)
        else
            node.Label_desc:setTextById(2500003)
            node.Label_lv:setText("")
        end
    end
end

function AngleStrengthenMain:onAngelStrengthen(data)
    print("AngleStrengthenMain:onAngelStrengthen")
    dump({self.showHeroId ,data})
    if data.heroId == tostring(self.showHeroId) then 
        self:refreshStrengthenLevel()
    end
end


function AngleStrengthenMain:registerEvents()
    EventMgr:addEventListener(self,EV_HERO_ANGEL_STRENGTHEN,handler(self.onAngelStrengthen, self)) 
end

return AngleStrengthenMain