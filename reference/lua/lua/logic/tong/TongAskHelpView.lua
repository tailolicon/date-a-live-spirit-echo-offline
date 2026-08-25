
local TongAskHelpView = class("TongAskHelpView", BaseLayer)
function TongAskHelpView:initData()
    self.helpType = {}
    self.newSelect = {}
end

function TongAskHelpView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.tong.tongAskHelpView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongAskHelpView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")
    self.Button_askHelp         = TFDirector:getChildByPath(ui, "Button_askHelp")
    self.Label_btn              = TFDirector:getChildByPath(self.Button_askHelp, "Label_btn")

    self.askBtn_ = {}
    for i=1,2 do
        local btn               = TFDirector:getChildByPath(ui, "Button_ask_"..i)
        local Image_select      = TFDirector:getChildByPath(btn, "Image_select")
        self.askBtn_[i] = {btn = btn , select = Image_select}
    end

    self:initUILogic()
end

function TongAskHelpView:initUILogic()

    local eliteInfo = TongDataMgr:getEliteInfo()
    if not eliteInfo then
        return
    end

    self.helpType = eliteInfo.helpType or {}
    for i=1,2 do
        local index = table.indexOf(self.helpType,i)
        local isSelect = index ~= -1
        self.askBtn_[i].select:setVisible(isSelect)
        self.askBtn_[i].btn:setTouchEnabled(not isSelect)
    end
end

function TongAskHelpView:selectHelp(type_)

    local index = table.indexOf(self.helpType,type_)
    local isSelect = index ~= -1
    if isSelect then
        return
    end

    --社团
    if type_ == 2 then
        local inUnion = LeagueDataMgr:checkSelfInUnion()
        if not inUnion then
            Utils:showTips(63824)
            return
        end
    end

    if self.newSelect[type_] == 1 then
        self.newSelect[type_] = nil
    else
        self.newSelect[type_] = 1
    end

    self.askBtn_[type_].select:setVisible( self.newSelect[type_] == 1)
end

function TongAskHelpView:AskHelp()

    if #self.helpType >= 2 then
        Utils:showTips(13206035)
        AlertManager:closeLayer(self)
        return
    end

    local newSelect = {}
    for k,v in pairs(self.newSelect) do
        table.insert(newSelect,k)
    end

    if #newSelect == 0 then
        local str = 13206036
        if #self.helpType == 1 then
            str = 13206035
        end
        Utils:showTips(str)
        AlertManager:closeLayer(self)
        return
    end



    TongDataMgr:Send_askHelp(newSelect)
    Utils:showTips(13206037)
    AlertManager:closeLayer(self)

end

function TongAskHelpView:registerEvents()

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    for k,v in ipairs(self.askBtn_) do
        v.btn:onClick(function()
            self:selectHelp(k)
        end)
    end

    self.Button_askHelp:onClick(function()
        self:AskHelp()
    end)
end

return TongAskHelpView
