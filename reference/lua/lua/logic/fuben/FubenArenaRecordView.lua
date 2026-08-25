
local FubenArenaRecordView = class("FubenArenaRecordView", BaseLayer)

function FubenArenaRecordView:initData(levelGroupId, diff)

end

function FubenArenaRecordView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaRecord")
end

function FubenArenaRecordView:initUI(ui)
	self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Image_content = TFDirector:getChildByPath(self.Panel_root , "Image_content")
    self.Button_close = TFDirector:getChildByPath(self.Image_content , "Button_close")
    self.Panel_Item =  TFDirector:getChildByPath(self.Image_content , "Panel_Item"):hide()
    self.ScrollView  = TFDirector:getChildByPath(self.Image_content , "ScrollView")
    self.Label_none = TFDirector:getChildByPath(self.Image_content , "Label_none")
    self.ListView = UIListView:create(self.ScrollView)
    self.ListView:setItemsMargin(2)
     -- self.recordDatas =  {

     --    {
     --    pid = 11808, 
     --    pName = "神奇的大象", 

     --    arenaScore = 10,
     --    attack = true,
     --    headId = 0,
     --    level = 50,

     --    heroRecord = {} --
     --    },
     --    {

     --    pid = 11808, 
     --    pName = "王婆卖瓜", 

     --    arenaScore = -10,
     --    attack = false,
     --    headId = 0,
     --    level = 48,

     --    heroRecord = {} --
     --    }
     -- }
    self:setLang()
    self:refreshView()
end


function FubenArenaRecordView:setLang()
    local Label_title_name = TFDirector:getChildByPath(self.Image_content , "Label_title_name")
    local Label_none       = TFDirector:getChildByPath(self.Image_content , "Label_none")
    Label_title_name:setTextById(2100003)
    Label_none:setTextById(290000088)

end

function FubenArenaRecordView:refreshView()

    self.recordDatas = ArenaDataMgr:getRecordData() 

    self.Label_none:setVisible(#self.recordDatas == 0)
    local items = self.ListView:getItems()
    local gap = #self.recordDatas - #items
    for i = 1, math.abs(gap) do
        if gap < 0 then
            self.ListView:removeItem(1)
        else
            local Panel_Item = self.Panel_Item:clone():show()
            self.ListView:pushBackCustomItem(Panel_Item)
        end
    end

    for i, v in ipairs(self.recordDatas) do
        local Panel_Item = self.ListView:getItem(i)
        self:updateItem(Panel_Item, v)
    end
end

local function _scoreToText(Label_score ,score)
    if score > 0 then 
        Label_score:setText("+"..score)
        Label_score:setFontColor(ccc3(0,255,0))
    
    elseif score < 0 then
        Label_score:setText("-"..math.abs(score))
        Label_score:setFontColor(ccc3(255,0,0))
    else
        Label_score:setText("+"..score)
        Label_score:setFontColor( ccc3(255,255,255))
    end
end


function FubenArenaRecordView:updateItem(item, data)
    local Image_head   = TFDirector:getChildByPath(item , "Image_head")
    local Image_icon   = TFDirector:getChildByPath(Image_head , "Image_icon")
    -- local Image_icon_frame   = TFDirector:getChildByPath(Image_head , "Image_icon_frame")
    local Label_name   = TFDirector:getChildByPath(item , "Label_name")
    local Label_level  = TFDirector:getChildByPath(item , "Label_level")
    local Label_score = TFDirector:getChildByPath(item , "Label_score")
    local Label_score_title = TFDirector:getChildByPath(item , "Label_score_title")
    local Label_type   = TFDirector:getChildByPath(item , "Label_type")
    local Button_check = TFDirector:getChildByPath(item , "Button_check")
    local Label_button_name = TFDirector:getChildByPath(Button_check , "Label_button_name")
    _scoreToText(Label_score ,data.arenaScore)
    Label_score_title:setTextById(61069)
    Label_button_name:setTextById(1325300)
    if data.attack then 
        Label_type:setTextById(2100165)
    else
        Label_type:setTextById(290000105)
    end
    Label_type:setFontColor(data.attack and ccc3(255,0,0) or ccc3(48,53,74))
    Label_name:setText(data.pName)
    Label_level:setTextById(800006, data.level or 1)
    local icon = AvatarDataMgr:getAvatarIconPath(headIcon)
    Image_icon:setTexture(icon)
    Button_check:onClick(function()
        Utils:openView("fuben.FubenArenaRecordDetailView",data.heroRecord)
    end)
end

function FubenArenaRecordView:registerEvents()
    EventMgr:addEventListener(self, EV_ARENA_RECORD_UPDATE, handler(self.onRecordUpdate, self))
    self.Button_close:onClick(function()
            AlertManager:close()
    end)
    ArenaDataMgr:send_ARENA_REQ_ARENA_RECORD()
end

function FubenArenaRecordView:onRecordUpdate()
    self:refreshView()
end

return FubenArenaRecordView
