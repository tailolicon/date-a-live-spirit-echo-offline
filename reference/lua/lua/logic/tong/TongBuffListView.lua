
local TongBuffListView = class("TongBuffListView", BaseLayer)
function TongBuffListView:initData(isOtherPlayer,otherActive)

    self.muiltFlag = false
    self.otherActive = otherActive or {}
    self.isOtherPlayer = otherActive

    self.fearlessUnlock = false

    if not self.isOtherPlayer then
        local eliteInfo = TongDataMgr:getEliteInfo()
        if not eliteInfo then
            return
        end
        self.fearlessUnlock = eliteInfo.fearlessUnlock
    end
end

function TongBuffListView:ctor(isOtherPlayer,otherActive)
    self.super.ctor(self)
    self:initData(isOtherPlayer,otherActive)
    self:init("lua.uiconfig.tong.tongBuffListView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongBuffListView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    local ScrollView_buff_list  = TFDirector:getChildByPath(ui, "ScrollView_buff_list")
    self.UIGridView_list        = UIGridView:create(ScrollView_buff_list)
    self.Label_desc             = TFDirector:getChildByPath(ui, "Label_desc")

    self.Panel_info             = TFDirector:getChildByPath(ui, "Panel_info")
    self.Image_buffIcon         = TFDirector:getChildByPath(ui, "Image_buffIcon")
    self.Label_buffName         = TFDirector:getChildByPath(ui, "Label_buffName")
    self.Label_descClone        = TFDirector:getChildByPath(ui, "Label_descClone")

    local ScrollView_desc       = TFDirector:getChildByPath(ui, "ScrollView_desc")
    self.UIListView_desc        = UIListView:create(ScrollView_desc)

    self.Panel_special          = TFDirector:getChildByPath(ui, "Panel_special")

    self.Label_desc             = TFDirector:getChildByPath(ui, "Label_desc")
    self.Label_score            = TFDirector:getChildByPath(ui, "Label_score")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")
    self.Button_active          = TFDirector:getChildByPath(ui, "Button_active")
    self.Label_active_btn       = TFDirector:getChildByPath(ui, "Label_active_btn")
    self.switchBg               = TFDirector:getChildByPath(ui, "Image_auto_bg")
    self.Image_on               = TFDirector:getChildByPath(ui, "Image_on")

    self.Panel_item             = TFDirector:getChildByPath(ui, "Panel_item")

    self.UIGridView_list:setItemModel(self.Panel_item)
    self.UIGridView_list:setColumn(4)
    --self.UIGridView_list:setColumnMargin(10)
    self.UIGridView_list:setRowMargin(10)

    self:initUILogic()
end

function TongBuffListView:initUILogic()
    self:switchMode(self.muiltFlag)
    self:initBuffList()
end

function TongBuffListView:isShowBuffHandle()

    if self.isOtherPlayer then
        return false
    else
        return self.fearlessUnlock
    end

    return false
end

function TongBuffListView:isActiveAffix(id)

    local isActive,isSelfActive = false,false
    if self.isOtherPlayer then
        return table.indexOf(self.otherActive,id) ~= -1
    else
        isActive = TongDataMgr:isActiveAffix(id)
        isSelfActive = TongDataMgr:isSelfActiveAffix(id)
    end

    return isActive,isSelfActive
end


function TongBuffListView:initBuffList()


    self.buffItem_ = {}
    local data = {}
    local affixCfg = TongDataMgr:getAffixCfg()
    for k,v in pairs(affixCfg) do
        if v.isIntrepidMode  then
            local isOpen = self:isShowBuffHandle()
            if isOpen then
                table.insert(data,v)
            end
        else
            table.insert(data,v)
        end
    end

    for k,v in ipairs(data) do
        self:addBuffItem(k,v.id)
    end

    self:updateBuffList()

    local index = self.selectIndex or 1
    self:selectBuffItem(index)
end

function TongBuffListView:addBuffItem(index,id)
    local item = self.Panel_item:clone()
    self.UIGridView_list:pushBackCustomItem(item)
    local isActive,isSelfActive = self:isActiveAffix(id)
    if (isSelfActive or isActive) and not self.selectIndex  then
        self.selectIndex = index
    end

    local icon              = TFDirector:getChildByPath(item, "Image_icon")
    local Label_name        = TFDirector:getChildByPath(item, "Label_name")
    local Label_active      = TFDirector:getChildByPath(item, "Label_active")
    local select            = TFDirector:getChildByPath(item, "Image_select")
    local Label_self_active = TFDirector:getChildByPath(item, "Label_self_active")
    table.insert(self.buffItem_,{root = item,icon = icon,name = Label_name,selfActive = Label_self_active,
                                 active = Label_active,select = select,id = id})
end

function TongBuffListView:updateBuffList()

    local score = 0
    for k,v in ipairs(self.buffItem_) do
        local isActive,isSelfActive = self:isActiveAffix(v.id)

        local str = self.fearlessUnlock and 13206041 or 13206042
        v.active:setTextById(str)
        v.active:setVisible(isActive)

        v.selfActive:setVisible(isSelfActive)

        local affixCfg = TongDataMgr:getAffixCfg(v.id)
        if affixCfg then
            if isActive then
                score = score + affixCfg.scoreAdd
            end
            v.icon:setTexture(affixCfg.icon)
            v.name:setTextById(affixCfg.name)
        end
    end

    self.Label_score:setText(score)
end

function TongBuffListView:selectBuffItem(index)

    for k,v in ipairs(self.buffItem_) do
        v.select:setVisible(index == k)
    end

    self.selectIndex = index

    self:updateDetailInfo()

    if self.muiltFlag then
        self:activeOrCancle(index)
    end
end

function TongBuffListView:updateDetailInfo()

    local itemInfo = self.buffItem_[self.selectIndex]
    if not itemInfo then
        return
    end

    local affixCfg = TongDataMgr:getAffixCfg(itemInfo.id)
    if not affixCfg then
        return
    end
    dump(affixCfg)
    self.Image_buffIcon:setTexture(affixCfg.icon)
    self.Label_buffName:setTextById(affixCfg.name)

    self.UIListView_desc:removeAllItems()
    local size = self.UIListView_desc:getContentSize()
    local Label_content = self.Label_descClone:clone():Show()
    Label_content:setTextById(affixCfg.desc)
    Label_content:setDimensions(size.width, 0)
    self.UIListView_desc:pushBackCustomItem(Label_content)

    local isActive,isSelfActive = self:isActiveAffix(affixCfg.id)
    local str = isSelfActive and 1329129 or 1326525
    self.Label_active_btn:setTextById(str)

    if isActive then
        self.Panel_special:setVisible(false)
    else
        local isShow = self:isShowBuffHandle()
        self.Panel_special:setVisible(isShow)
    end

end

function TongBuffListView:switchMode(flag)

    self.muiltFlag = flag
    local posX = self.muiltFlag and -30 or 30
    self.Image_on:setPositionX(posX)
end

function TongBuffListView:activeOrCancle(index)

    local isShow = self:isShowBuffHandle()
    if not isShow then
        return
    end

    local itemInfo = self.buffItem_[index]
    if not itemInfo then
        return
    end

    local isActive,isSelfActive = self:isActiveAffix(itemInfo.id)
    if isActive then
        return
    end
    local handle = isSelfActive and 2 or 1
    TongDataMgr:Send_activeOrCancle(itemInfo.id,handle)
end

function TongBuffListView:afterHandleAffix()
    self:updateBuffList()
    self:updateDetailInfo()
end

function TongBuffListView:registerEvents()

    EventMgr:addEventListener(self, EV_TONG.ActiveAffix, handler(self.afterHandleAffix, self))

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

    self.switchBg:onClick(function()
        self:switchMode(not self.muiltFlag)
    end)

    self.Button_active:onClick(function()
        self:activeOrCancle(self.selectIndex)
    end)

    for k,v in ipairs(self.buffItem_) do
        v.root:onClick(function()
            if  self.selectIndex == k and (not self.muiltFlag) then
                return
            end
            self:selectBuffItem(k)
        end)
    end
end

return TongBuffListView
