
local TongEquipTipView = class("TongEquipTipView", BaseLayer)
function TongEquipTipView:initData(buffCid,targetSlotId)
    self.buffCid = buffCid
    self.targetSlotId  = targetSlotId

    self.stateStr = {3202043,1100006,3202045}
end

function TongEquipTipView:ctor(buffCid,targetSlotId)
    self.super.ctor(self)
    self:initData(buffCid,targetSlotId)
    self:init("lua.uiconfig.tong.tongEquipTipView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongEquipTipView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")

    self.Image_skill            = TFDirector:getChildByPath(ui, "Image_skill")
    self.Label_skill_desc       = TFDirector:getChildByPath(ui, "Label_skill_desc")
    self.Button_handle          = TFDirector:getChildByPath(ui, "Button_handle")
    self.Label_handle           = TFDirector:getChildByPath(ui, "Label_handle")
    self.Label_unlock_desc      = TFDirector:getChildByPath(ui, "Label_unlock_desc")
    self:initUILogic()
end

function TongEquipTipView:initUILogic()

    local skillCfg = TongDataMgr:getSkillCfgById(self.buffCid)
    if not skillCfg then
        return
    end

    self.Image_skill:setTexture(skillCfg.buffIcon)

    local combatMgrCfg = TongDataMgr:getCombatMgrCfg(self.buffCid)
    if combatMgrCfg then
        self.Label_skill_desc:setTextById(combatMgrCfg.buffDescribe)
    else
        self.Label_skill_desc:setText("")
    end

    local handleState = self:getHandleState()
    self.Label_handle:setTextById(self.stateStr[handleState])

    local isUnLock = TongDataMgr:isUnLockSkill(self.buffCid)
    self.Button_handle:setVisible(isUnLock)
    self.Label_unlock_desc:setVisible(not isUnLock)

    self.Label_unlock_desc:setTextById(skillCfg.stringId)
end

function TongEquipTipView:getHandleState()
    ---装备，卸下，替换
    local equipBufferCid = TongDataMgr:getEquipedBufferCid(self.targetSlotId)
    if equipBufferCid == 0 then
        return 1
    else
        if equipBufferCid == self.buffCid then
            return 2
        else
            return 3
        end
    end
end

function TongEquipTipView:equipSkill()

    local handleState = self:getHandleState()
    if handleState == 2 then
        TongDataMgr:Send_equipSkill(self.targetSlotId,0)
    else
        TongDataMgr:Send_equipSkill(self.targetSlotId,self.buffCid)
    end
end

function TongEquipTipView:registerEvents()

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    self.Button_handle:onClick(function()
        self:equipSkill()
        AlertManager:closeLayer(self)
    end)
end

return TongEquipTipView
