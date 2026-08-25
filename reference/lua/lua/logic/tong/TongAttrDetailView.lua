
local TongAttrDetailView = class("TongAttrDetailView", BaseLayer)
function TongAttrDetailView:initData(unLockSkills,isReset)

    self.unLockSkills = unLockSkills
    self.isReset = isReset
end

function TongAttrDetailView:ctor(unLockSkills,isReset)
    self.super.ctor(self)
    self:initData(unLockSkills,isReset)
    self:init("lua.uiconfig.tong.tongAttrDetailView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongAttrDetailView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")
    local ScrollView_skill       = TFDirector:getChildByPath(ui, "ScrollView_skillList")
    self.UIListView_skill        = UIListView:create(ScrollView_skill)

    self.Panel_item             = TFDirector:getChildByPath(ui, "Panel_skill")

    self.Label_title            = TFDirector:getChildByPath(ui, "Label_title")
    local strId = self.isReset and 15011481 or 15011480
    self.Label_title:setTextById(strId)
    self:initUILogic()
end

function TongAttrDetailView:initUILogic()

    for k,v in ipairs(self.unLockSkills) do

        local skillCfg = TongDataMgr:getSkillCfgById(v)
        if skillCfg then
            local item = self.Panel_item:clone()
            self.UIListView_skill:pushBackCustomItem(item)

            local Image_skill = TFDirector:getChildByPath(item, "Image_skill")
            Image_skill:setTexture(skillCfg.buffIcon)
        end
    end

    --Utils:setAliginCenterByListView(self.UIListView_skill,true)
end

function TongAttrDetailView:registerEvents()

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

end

return TongAttrDetailView
