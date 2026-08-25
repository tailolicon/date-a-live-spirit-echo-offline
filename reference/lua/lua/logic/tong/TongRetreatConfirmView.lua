
local TongRetreatConfirmView = class("TongRetreatConfirmView", BaseLayer)
function TongRetreatConfirmView:initData(dungonMgrId)
    self.dungonMgrId = dungonMgrId
    self.vitmaxThreatCfg        = TabDataMgr:getData("VITmaxEIPointThreat")
end

function TongRetreatConfirmView:ctor(dungonMgrId)
    self.super.ctor(self)
    self:initData(dungonMgrId)
    self:init("lua.uiconfig.tong.tongRetreatConfirmView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongRetreatConfirmView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Label_tip              = TFDirector:getChildByPath(ui, "Label_tip")
    self.Label_tip1             = TFDirector:getChildByPath(ui, "Label_tip1")
    self.Button_ok              = TFDirector:getChildByPath(ui, "Button_ok")
    self.Button_cancle          = TFDirector:getChildByPath(ui, "Button_cancle")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")

    self:initUILogic()
end

function TongRetreatConfirmView:initUILogic()

    local curThreatLv = TongDataMgr:getCurThreatLv()
    local threatCfg = TongDataMgr:getThreatCfgByLv(curThreatLv)
    if not threatCfg then
        return
    end

    self.Label_tip:setTextById(13206074,threatCfg.threatValueLose)

    local exp = TongDataMgr:getCurThreatExp()
    if not exp then
        return
    end

    local newExp = exp - threatCfg.threatValueLose
    local newLv = 0
    for k,v in ipairs(self.vitmaxThreatCfg) do
        if newExp <= v.threatValueLmt then
            newLv = v.threatLevel
            break
        end
    end

    if newLv < curThreatLv then
        self.Label_tip1:setTextById(13206075,newLv)
    else
        self.Label_tip1:setText("")
    end


end

function TongRetreatConfirmView:registerEvents()

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    self.Button_cancle:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    self.Button_ok:onClick(function()
        TongDataMgr:Send_retreatMonsterFight(self.dungonMgrId)
    end)
end

return TongRetreatConfirmView
