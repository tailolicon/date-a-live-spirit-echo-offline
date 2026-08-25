local TongAddNumConfirmView = class("TongAddNumConfirmView", BaseLayer)

function TongAddNumConfirmView:ctor(...)
    self.super.ctor(self, ...)
    self:initData(...)
    self:init("lua.uiconfig.tong.tongAddNumConfirmView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongAddNumConfirmView:initData(...)
    self.showData = ... or {}
end

function TongAddNumConfirmView:initUI(ui)
    self.super.initUI(self, ui)

    self.ui = ui

    self.Label_title = TFDirector:getChildByPath(self.ui, "Label_title")
    self.Panel_content = TFDirector:getChildByPath(self.ui, "Panel_content")

    self.Label_change = TFDirector:getChildByPath(self.ui, "Label_change")

    self.Button_close = TFDirector:getChildByPath(self.ui, "Button_close")
    self.Button_cancel = TFDirector:getChildByPath(self.ui, "Button_cancle")
    self.Button_ok = TFDirector:getChildByPath(self.ui, "Button_ok")

    local rich = TFRichText:create(ccs(500, 160))
    local str = string.format([[<font face="fangzheng_zhunyuan26" color="#1f8993">%s</font>]], self.showData.content)
    rich:Text(str)
    self.Panel_content:Add(rich)

    self.Label_title:setTextById(self.showData.tittle)

    if self.showData.showClose ~= nil then
        self.Button_close:setVisible(tobool(self.showData.showClose))
    end

    if self.showData.showCancel ~= nil then
        self.Button_cancel:setVisible(tobool(self.showData.showCancel))
    end
end

function TongAddNumConfirmView:registerEvents()

    self.Button_close:onClick(function()
        AlertManager:closeLayer(self)
    end, EC_BTN.CLOSE)

    self.Button_cancel:onClick(function()
        if self.showData.cancleCall then
            self.showData.cancleCall()
        end
        AlertManager:closeLayer(self)
    end, EC_BTN.CLOSE)

    self.Button_ok:onClick(function()
        self.Button_ok:setTouchEnabled(false)
        if self.showData.confirmCall then
            self.showData.confirmCall()
        end
        AlertManager:closeLayer(self)
    end)
end

return TongAddNumConfirmView
