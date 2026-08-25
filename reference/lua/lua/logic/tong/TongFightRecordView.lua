
local TongFightRecordView = class("TongFightRecordView", BaseLayer)
function TongFightRecordView:initData(bossName)
    self.bossName = TextDataMgr:getText(bossName)
end

function TongFightRecordView:ctor(bossName)
    self.super.ctor(self)
    self:initData(bossName)
    self:init("lua.uiconfig.tong.tongFightRecordView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongFightRecordView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")

    local ScrollView_record     = TFDirector:getChildByPath(ui, "ScrollView_record")
    self.UIListView_record      = UIListView:create(ScrollView_record)
    self.Label_nilTip           = TFDirector:getChildByPath(ui, "Label_nilTip")
    self.Panel_item           = TFDirector:getChildByPath(ui, "Panel_item")

    self:initUILogic()

end

function TongFightRecordView:initUILogic()

    self.UIListView_record:removeAllItems()
    local eliteRecord = TongDataMgr:getRecordList()

    self.Label_nilTip:setVisible(#eliteRecord <= 0)

    for k,v in ipairs(eliteRecord) do
        local Panel_item = self.Panel_item:clone()

        local Label_record = TFDirector:getChildByPath(Panel_item, "Label_record")
        Label_record:setDimensions(440, 0)
        local desc = self:groupRecord(v)
        Label_record:setText(desc)

        local Image_bg = TFDirector:getChildByPath(Panel_item, "Image_bg")
        local h = Label_record:getContentSize().height
        Image_bg:setContentSize(CCSizeMake(470,h + 10))
        Panel_item:setContentSize(CCSizeMake(470,h + 14))
        self.UIListView_record:pushBackCustomItem(Panel_item)
    end
end

function TongFightRecordView:groupRecord(data)

    local desc = ""
    if data.type == 1 then
        desc = TextDataMgr:getText(13206045,self.bossName,(data.hurt or -1))
    elseif data.type == 2 then
        desc = TextDataMgr:getText(13206046,self.bossName,(data.hurt or -1))
    elseif data.type == 3 then
        desc = TextDataMgr:getText(13206047, (data.helpPlayerName or ""))
    end
    return desc
end

function TongFightRecordView:registerEvents()


    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

end

return TongFightRecordView
