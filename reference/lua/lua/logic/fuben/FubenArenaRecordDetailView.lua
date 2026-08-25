
local FubenArenaRecordDetailView = class("FubenArenaRecordDetailView", BaseLayer)

    -- required int32 selfHero = 1; //己方英雄id
    -- required int32 selfLevel = 2;//己方英雄等级
    -- required int32 enemyHero = 3; //对方英雄id
    -- required int32 enemyLevel = 4;//对方英雄等级
    -- required bool win = 5; //是否胜利

function FubenArenaRecordDetailView:initData(data)
    self.heroRecords = data or {}
    -- self.heroRecords[1] = {
    --     selfHero  = 110211,
    --     selfLevel =55,
    --     enemyHero  = 110215,
    --     enemyLevel = 88,    
    --     win = false   
    -- }
    -- self.heroRecords[2] = self.heroRecords[1]
    -- self.heroRecords[3] = self.heroRecords[1]
end

function FubenArenaRecordDetailView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaRecordDetail")
end

function FubenArenaRecordDetailView:initUI(ui)
	self.super.initUI(self, ui)
    self.Panel_root    = TFDirector:getChildByPath(ui, "Panel_root")
    self.Image_content = TFDirector:getChildByPath(self.Panel_root , "Image_content")
    self.Button_close  = TFDirector:getChildByPath(self.Image_content , "Button_close")
    local Label_title_name = TFDirector:getChildByPath(self.Image_content , "Label_title_name")
    Label_title_name:setTextById(290000106)
    for index = 1,3 do
       local item = TFDirector:getChildByPath(self.Image_content , "Panel_Item"..index)
       self:updateItem(item,index)
    end

end


local function _refreshRole(roleItem, heroData )
    local Label_level = TFDirector:getChildByPath(roleItem, "Label_level") 
    local Image_playerIcon = TFDirector:getChildByPath(roleItem, "Image_playerIcon") 
    local Image_quality = TFDirector:getChildByPath(roleItem, "Image_quality") 
    local Image_pinzhi = TFDirector:getChildByPath(roleItem, "Image_pinzhi") 
    Label_level:setTextById(700034,heroData.lv)
    Image_playerIcon:setTexture(HeroDataMgr:getIconPathById(heroData.cid, heroData.skin))
    Image_pinzhi:setTexture(HeroDataMgr:getQualityPicNotHave(heroData.cid))
end





function FubenArenaRecordDetailView:updateItem(item, index)
    local data         = self.heroRecords[index]
    if not data  then
        item:hide()
        return 
    end
    item:show()
    local Label_result = TFDirector:getChildByPath(item, "Label_result")
    local Image_bg_win = TFDirector:getChildByPath(item, "Image_bg_win")
    local Image_bg_lose = TFDirector:getChildByPath(item, "Image_bg_lose")
    local Image_result = TFDirector:getChildByPath(item, "Image_result")
    Image_result:hide()
    
    local Panel_role1    = TFDirector:getChildByPath(item, "Panel_role1")
    local Panel_role2    = TFDirector:getChildByPath(item, "Panel_role2")
    -- Label_result:hide()
    if data.win then 
        Label_result:setTextById(190200137)
    else
        Label_result:setTextById(800063)
    end
    Label_result:setFontColor(data.win and ccc3(0,0,255) or  ccc3(255,0,0))
    Image_bg_lose:setVisible(not data.win)
    Image_bg_win:setVisible(data.win)
    _refreshRole(Panel_role1,data.selfHero ,data.selfLevel)
    _refreshRole(Panel_role2,data.enemyHero ,data.enemyLevel)
end

function FubenArenaRecordDetailView:registerEvents()
    -- EventMgr:addEventListener(self, EV_FUBEN_LEVELGROUPREWARD, handler(self.onRefreshEvent, self))

    self.Button_close:onClick(function()
        AlertManager:close()
    end)
end

function FubenArenaRecordDetailView:onRefreshEvent()

end

return FubenArenaRecordDetailView
