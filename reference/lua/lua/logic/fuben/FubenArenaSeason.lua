local FubenArenaSeason = class("FubenArenaSeason", BaseLayer)

function FubenArenaSeason:ctor(data)
    self.super.ctor(self)
    self.data = data
    -- dump(data)
    --self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaSeason")
end


function FubenArenaSeason:initUI(ui)
    self.super.initUI(self, ui)
    self.ui = ui

    self.Panel_root = TFDirector:getChildByPath(self.ui, "Panel_root")


    self.Panel_touch = TFDirector:getChildByPath(self.ui, "Panel_touch")
    self.Panel_touch:setContentSize(GameConfig.WS)

    self.Panel_grade = TFDirector:getChildByPath(self.ui, "Panel_grade")
    self.Image_grade_bg = TFDirector:getChildByPath(self.Panel_grade, "Image_grade_bg")
    self.Image_grade_bg:setScaleY(0)
    self.Image_grade_bg:setOpacity(0)
    -- self.LabelBMFont_num = TFDirector:getChildByPath(self.Panel_grade, "LabelBMFont_num")
    self.Panel_grade_info = TFDirector:getChildByPath(self.Panel_grade, "Panel_grade_info")
    self.Panel_grade_info:setOpacity(0)
    self.Label_stage_name = TFDirector:getChildByPath(self.Panel_grade, "Label_stage_name")
    self.Image_medal_grade = TFDirector:getChildByPath(self.Panel_grade, "Image_medal_grade")
    self.Label_my_rank = TFDirector:getChildByPath(self.Panel_grade, "Label_my_rank")
    self.Label_clicktip = TFDirector:getChildByPath(self.ui, "Label_clicktip")
    self:setLang()
    ViewAnimationHelper.doflashAction(self.Label_clicktip, 0.5, 0)

    self:initUIData()

end

function FubenArenaSeason:setLang()
    self.Label_clicktip:setTextById(800018)
    local Label_stage = TFDirector:getChildByPath(self.Panel_grade_info, "Label_stage")
    local Label_tip = TFDirector:getChildByPath(self.Panel_grade_info, "Label_tip")
    Label_stage:setTextById(300980)
    Label_tip:setTextById(310009)
end

function FubenArenaSeason:initUIData()
    local arenaData =  ArenaDataMgr:getArenaData()
    self.Label_my_rank:setTextById(15010043 ,self.data.rank)
    self.Image_medal_grade:setTexture(ArenaDataMgr:segmentIcon(self.data.segment))
    self.Label_stage_name:setText(TextDataMgr:getText(ArenaDataMgr:segmentName(self.data.segment)))

    self:playFirstAction()
end

function FubenArenaSeason:playFirstAction()

    local action = CCSequence:create({
        CCSpawn:create({ CCFadeIn:create(0.2), CCScaleTo:create(0.2,1,0.7)}),
        CCCallFunc:create(function()
            self.Panel_grade_info:runAction(CCFadeIn:create(0.5))
        end)
    })

    self.Image_grade_bg:runAction(action)

end


function FubenArenaSeason:registerEvents()

    self.Panel_touch:onClick(function()
        AlertManager:closeLayer(self)
    end)

end

return FubenArenaSeason