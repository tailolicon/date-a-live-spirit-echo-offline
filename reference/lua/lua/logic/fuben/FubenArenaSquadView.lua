
local FubenArenaSquadView = class("FubenArenaSquadView", BaseLayer)

function FubenArenaSquadView:initData(...)


    self:initFormationData()
    

end


function FubenArenaSquadView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaSquadView")
end

function FubenArenaSquadView:initUI(ui)
    self.super.initUI(self, ui)
    self:addLockLayer()

    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    -- self.Panel_prefab = TFDirector:getChildByPath(ui, "Panel_prefab"):hide()
    self.Panel_formation = TFDirector:getChildByPath(self.Panel_root, "Panel_formation"):show()
        --竞技场UI
    self.Panel_arena        = TFDirector:getChildByPath(self.Panel_root, "Panel_arena"):show()

    self.Panel_member = {}
    for i = 1, 3 do
        local item = {}
        item.root = TFDirector:getChildByPath(self.Panel_formation, "Panel_memeber_" .. i)
        item.Panel_role = TFDirector:getChildByPath(item.root, "Panel_role"):hide()
        item.Button_head = TFDirector:getChildByPath(item.root, "Button_head")
        item.Panel_model = TFDirector:getChildByPath(item.Panel_role, "Panel_model")
        item.Image_captain = TFDirector:getChildByPath(item.Panel_role, "Image_captain")
        item.Label_name = TFDirector:getChildByPath(item.Panel_role, "Label_name")
        -- item.Image_limit_type = TFDirector:getChildByPath(item.Panel_role, "Image_limit_type")
        -- item.Label_limit_type = TFDirector:getChildByPath(item.Image_limit_type, "Label_limit_type")
        -- item.Image_disable_type = TFDirector:getChildByPath(item.Panel_role, "Image_disable_type")
        -- item.Label_disable_type = TFDirector:getChildByPath(item.Image_disable_type, "Label_disable_type")
        -- item.Image_try_type = TFDirector:getChildByPath(item.root, "Image_try_type")
        -- item.Label_try_type = TFDirector:getChildByPath(item.Image_try_type, "Label_try_type")
        item.Panel_add = TFDirector:getChildByPath(item.root, "Panel_add"):hide()
        item.Button_add = TFDirector:getChildByPath(item.Panel_add, "Button_add")
        item.Label_empty = TFDirector:getChildByPath(item.Panel_add, "Label_empty")
        item.Panel_lock = TFDirector:getChildByPath(item.root, "Panel_lock"):hide()
        item.Button_lock = TFDirector:getChildByPath(item.Panel_lock, "Button_lock")
        -- item.Image_hp = TFDirector:getChildByPath(item.Panel_role, "Image_hp"):hide()
        -- item.Label_hp = TFDirector:getChildByPath(item.Image_hp, "Label_hp")
        -- item.LoadingBar_hp_progress = TFDirector:getChildByPath(item.Image_hp, "Image_hp_progress.LoadingBar_hp_progress")
        -- item.Label_hp_percent = TFDirector:getChildByPath(item.Image_hp, "Label_hp_percent")
        -- item.Image_endless_dead = TFDirector:getChildByPath(item.Panel_role, "Image_endless_dead"):hide()
        -- item.Label_endless_dead = TFDirector:getChildByPath(item.Image_endless_dead, "Label_endless_dead")
        -- item.Label_endless_dead:setTextById(310018)
        -- item.Image_skayladder = TFDirector:getChildByPath(item.Panel_role, "Image_skayladder"):hide()
        -- item.Label_remain_cnt = TFDirector:getChildByPath(item.Image_skayladder, "Label_remain_cnt")
        -- item.Button_check = TFDirector:getChildByPath(item.Image_skayladder, "Button_check")
        -- item.Panel_mojin_coin = TFDirector:getChildByPath(item.Panel_role, "Panel_mojin_coin"):hide()
        -- item.Panel_hwx_tip = TFDirector:getChildByPath(item.Panel_role, "Panel_hwx_tip"):hide()
        -- item.Panel_ksan_coin = TFDirector:getChildByPath(item.Panel_role, "Panel_ksan_coin"):hide()

        item.Image_fightPower= TFDirector:getChildByPath(item.Panel_role, "Image_fightPower")
        item.Label_fightPower = TFDirector:getChildByPath(item.Image_fightPower, "Label_fightPower")
        item.Image_quality = TFDirector:getChildByPath(item.Panel_role, "Image_quality")



        self.Panel_member[i] = item
    end

    --竞技场
    self.Panel_arena  = TFDirector:getChildByPath(self.Panel_root, "Panel_arena")
    self.Label_fightPower = TFDirector:getChildByPath(self.Panel_arena, "Label_fightPower") --总战力
    self.Label_fightPower_tip = TFDirector:getChildByPath(self.Panel_arena, "Label_fightPower_tip") --总战力


    -- self.Image_cost = TFDirector:getChildByPath(self.Panel_root, "Image_cost"):hide()
    -- self.Label_costNum = TFDirector:getChildByPath(self.Image_cost, "Label_costNum")
    -- self.Image_costIcon = TFDirector:getChildByPath(self.Image_cost, "Image_costIcon")
    -- self.Label_cost = TFDirector:getChildByPath(self.Image_cost, "Label_cost")
    self.Button_fighting = TFDirector:getChildByPath(self.Panel_root, "Button_fighting")
    self.Label_fighting = TFDirector:getChildByPath(self.Button_fighting, "Label_fighting")
    self.Button_preTeam = TFDirector:getChildByPath(self.Panel_root, "Button_preTeam")
    self.Label_preTeam  = TFDirector:getChildByPath(self.Button_preTeam, "Label_preTeam")
    self.Label_fighting:setTextById(15011276)
    self.Label_preTeam:setTextById(15010200)
    self:setLang()
    self:refreshView()
end

function FubenArenaSquadView:setLang()
   
    self.Label_fightPower_tip:setTextById(700012)
    local Label_myTeam = TFDirector:getChildByPath(self.Panel_formation , "Label_myTeam")
    Label_myTeam:setTextById(100000063)

end

--刷新战力
function FubenArenaSquadView:refreshFightPower()
    
    local fightPower = 0
    for i,v in ipairs(self.formationData_) do
        if v and v.data then 
            fightPower = fightPower + v.data.fightPower
        end
    end

    self.Label_fightPower:setText(tostring(fightPower))
end


function FubenArenaSquadView:calMoveRect()
    self.moveRect_ = {}
    for i, v in ipairs(self.Panel_member) do
        local anchorPoint = v.root:getAnchorPoint()
        local size = v.root:getContentSize()
        local offset = ccp(size.width * anchorPoint.x, size.height * anchorPoint.y)
        local pos = v.root:getPosition()
        local origin = me.pSub(pos, offset)
        self.moveRect_[i] = me.rect(origin.x, origin.y, size.width, size.height)
    end
end










function FubenArenaSquadView:refreshView()
    self:calMoveRect()
    self:updateFormation()
    self:refreshFightPower()
end





function FubenArenaSquadView:removeEvents()
    EventMgr:removeEventListenerByTarget(self)
end

function FubenArenaSquadView:onFightingClick()
    Utils:showTips(290000107)
    AlertManager:closeLayer(self)
end

function FubenArenaSquadView:registerEvents()
    EventMgr:addEventListener(self, EV_FORMATION_CHANGE, handler(self.onUpdateFormationEvent, self))
    -- EventMgr:addEventListener(self,EV_UPDATE_BUY_FIGHTCNT,handler(self.updateFormation, self));
    self.Button_fighting:onClick(handler(self.onFightingClick, self))

    self:setBackBtnCallback(function()
        --HeroDataMgr:changeDataToSelf()
        AlertManager:close()
    end)

    self:setMainBtnCallback(function()
        --HeroDataMgr:changeDataToSelf()
    end)


    --预编队选择
    self.Button_preTeam:onClick(function()
        
     local param = {
            isSkyLadder = false,
            isHwx = false,
            isEndless = false,
            isArena = true
        }
        Utils:openView("fairy.PreTeamSetView",param)

    end)
end



function FubenArenaSquadView:updateFormation()


    for i, v in ipairs(self.Panel_member) do
        local formationData = self.formationData_[i]
        -- print("I>>>>>>:"..i)
        --dump(formationData)
        local isBattle = tobool(formationData)
        v.Panel_role:setVisible(isBattle)
        v.Panel_lock:hide()
        v.Panel_add:setVisible(not v.Panel_lock:isVisible())
 
        v.Label_empty:setTextById(300018)

        if isBattle then



            local heroData = formationData.data
            local skinData = TabDataMgr:getData("HeroSkin", heroData.skinCid)
            v.Label_name:setTextById(heroData.nameTextId)
            v.Button_head:setTextureNormal(skinData.backdrop)

            local model = Utils:createHeroModel(heroData.id, v.Panel_model, 0.45, heroData.skinCid)
            model:update(0.1)
            model:stop()


            v.Label_fightPower:setText(formationData.data.fightPower)
            -- dump(formationData.data)
            -- Box("11"..tostring(formationData.data.id))
            v.Image_quality:setTexture(HeroDataMgr:getQualityPic(formationData.data.id))
           
        end

        v.Button_head:onTouch(function(event)
                if self.moveFlag_ then return end
                local target = event.target
                if event.name == "began" then
                    if not self.formationData_[i] then return end
                    local heroData = self.formationData_[i].data
                    self.Panel_cloneRole = v.Panel_role:clone():hide()
                    local Panel_model = TFDirector:getChildByPath(self.Panel_cloneRole, "Panel_role.Panel_model")
                    local model = Utils:createHeroModel(heroData.id, Panel_model, 0.45, heroData.skinCid)
                    model:update(0.1)
                    model:stop()
                    v.Panel_add:show()
                    for j, foo in ipairs(self.Panel_member) do
                        if j == i then
                            foo.root:ZO(2)
                        else
                            foo.root:ZO(1)
                        end
                    end
                    v.Panel_role:getParent():Add(self.Panel_cloneRole)
                    v.__movePos = target:getTouchStartPos()
                elseif event.name == "moved" then
                    if not self.Panel_cloneRole then return end
                    if not self.formationData_[i] then return end
                    local movePos = target:getTouchMovePos()
                    local offset = me.pSub(movePos, v.__movePos)
                    v.__movePos = movePos
                    local pos = self.Panel_cloneRole:getPosition()
                    self.Panel_cloneRole:Pos(me.pAdd(pos, offset)):show()
                    v.Panel_role:hide()
                elseif event.name == "ended" then
                    if not self.Panel_cloneRole then return end
                    if not self.formationData_[i] then return end
                    local endPos = target:getTouchEndPos()
                    local np = self.Panel_root:convertToNodeSpaceAR(endPos)
                    local index
                    for i, v in ipairs(self.moveRect_) do
                        if me.rectContainsPoint(v, np) then
                            index = i
                            break
                        end
                    end
                    if index and index ~= i and self.formationData_[index] then
                        local fromFormationData = self.formationData_[i]
                        local toFormationData = self.formationData_[index]
                        if fromFormationData.type == EC_BattleHeroType.LIMIT or toFormationData.type == EC_BattleHeroType.LIMIT 
                            or fromFormationData.type == 3 or toFormationData.type == 3 then
                            Utils:showTips(300024)
                        else
                            self:replaceFormation(i, index)
                        end
                    end
                    v.Panel_role:show()
                    v.Panel_add:hide()
                    self.Panel_cloneRole:removeFromParent()
                end
        end)
        v.Button_head:onClick(function()
                local heroTab = HeroDataMgr:getHero()
                if i < #heroTab then
                    Utils:showTips(300011)
                else

                    self:changeFormation(i)
                    
                end
        end)
        v.Button_add:onClick(function()
                local heroTab = HeroDataMgr:getHero()
                if i < #heroTab then
                    Utils:showTips(300011)
                else
                    self:changeFormation(i)
                end
        end)
        v.Button_lock:onClick(function()
                Utils:showTips(300023)
        end)
        -- v.Button_check:onClick(function()
        --     local heroData = formationData.data
        --     HeroDataMgr.showid = heroData.id;
        --     Utils:openView("fairyNew.FairyDetailsLayer", {showid= heroData.id, friend=false, gotoWhichTab = 3,skyladder = true})
        --     SkyLadderDataMgr:setCheckHeroId(heroData.id)
        -- end)
    end
end

function FubenArenaSquadView:replaceFormation(fromIndex, toIndex)
    local fromId = HeroDataMgr:getHeroIdByFormationPos_arena(fromIndex)
    local toId = HeroDataMgr:getHeroIdByFormationPos_arena(toIndex)
    HeroDataMgr:heroOnBattle(fromId, toId ,3)
end


function FubenArenaSquadView:changeFormation(_pos)
    local layer = requireNew("lua.logic.fairy.ArenaFormationLayer"):new({
        _pos = _pos,
        changeToServer = changeToServer,
    });
    AlertManager:addLayer(layer)
    AlertManager:show()


end


function FubenArenaSquadView:onUpdateFormationEvent(heroCid, oldHeroCid)
    -- self.formationData_ = {}
    -- for i = 1, 3 do
    --     local id       = HeroDataMgr:getHeroIdByFormationPos(i)
    --     local heroData = HeroDataMgr:getHero(id)
    --     table.insert(self.formationData_, FubenDataMgr:makeFormationData(heroData, EC_BattleHeroType.OWN, heroData.cid))
    -- end

    self:initFormationData()
    self:updateFormation()
    self:refreshFightPower()
end


function FubenArenaSquadView:initFormationData()
    self.formationData_ = {}
    for i = 1, 3 do
        local isOn = HeroDataMgr:getIsFormationOn_arena(i)
        if isOn then
            local id = HeroDataMgr:getHeroIdByFormationPos_arena(i)
            local heroData = HeroDataMgr:getHero(id)
            print("id:   " .. tostring(id))


            table.insert(self.formationData_, FubenDataMgr:makeFormationData(heroData, EC_BattleHeroType.OWN, heroData.cid))
        end
    end
end
function FubenArenaSquadView:onShow()
    self.super.onShow(self)
    self:removeLockLayer()
end

return FubenArenaSquadView

