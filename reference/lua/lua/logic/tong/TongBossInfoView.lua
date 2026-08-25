
local TongBossInfoView = class("TongBossInfoView", BaseLayer)
function TongBossInfoView:initData(levelCid)

    self.vitMaxDungonInfo = TabDataMgr:getData("DungeonInfoOfVITmax")[levelCid]

end

function TongBossInfoView:ctor(levelCid)
    self.super.ctor(self)
    self:initData(levelCid)
    self:init("lua.uiconfig.tong.tongBossInfoView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongBossInfoView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")
    local ScrollView_skill      = TFDirector:getChildByPath(ui, "ScrollView_skill")
    self.UIListView_skill       = UIListView:create(ScrollView_skill)

    self.Image_head             = TFDirector:getChildByPath(ui, "Image_head")
    self.Label_skill            = TFDirector:getChildByPath(ui, "Label_skill")
    self.Label_desc             = TFDirector:getChildByPath(ui, "Label_desc")

    self:updateBaseInfo()

end

function TongBossInfoView:updateBaseInfo()

    self.Image_head:setTexture(self.vitMaxDungonInfo.eliteBossIcon)
    self.Label_desc:setTextById(self.vitMaxDungonInfo.eliteBossDes)

    self.UIListView_skill:removeAllItems()
    local descItem = self.Label_skill:clone()
    descItem:setDimensions(440, 0)
    descItem:setTextById(self.vitMaxDungonInfo.eliteBossSkillDes)
    self.UIListView_skill:pushBackCustomItem(descItem)
end

function TongBossInfoView:registerEvents()
    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

end

return TongBossInfoView
