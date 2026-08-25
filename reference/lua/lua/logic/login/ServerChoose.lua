
local ServerChoose = class("ServerChoose", BaseLayer)

function ServerChoose:initData()
    self.areas = ServerDataMgr:getAreas()
    dump(self.areas)
end



    --TODO serverInfo
    -- "areaId"     = 0
    -- "serverId"   = 101001
    -- "serverName" = "bt_game1"
    -- "state"      = 0

function ServerChoose:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.loginScene.serverChoose")
end

function ServerChoose:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_Content = TFDirector:getChildByPath(ui, "Panel_Content")
    self.Panel_root = TFDirector:getChildByPath(self.Panel_Content, "Panel_root")

    self.Label_title  = TFDirector:getChildByPath(self.Panel_root, "Label_title")

    self.Button_close = TFDirector:getChildByPath(self.Panel_root, "Button_close")

    self.Panel_prefab = TFDirector:getChildByPath(ui, "Panel_prefab"):hide()
    local ScrollView_aredList = TFDirector:getChildByPath(self.Panel_root, "ScrollView_areaList")
    local ScrollView_serverList = TFDirector:getChildByPath(self.Panel_root, "ScrollView_serverList")

    self.Area_Item = TFDirector:getChildByPath(self.Panel_prefab, "Area_Item")
    self.Server_Item = TFDirector:getChildByPath(self.Panel_prefab, "Server_Item")

    local ScrollView_serverList = TFDirector:getChildByPath(self.Panel_root,"ScrollView_serverList")
    self.ListView_serverList = UIGridView:create(ScrollView_serverList)
    self.ListView_serverList:setItemModel(self.Server_Item)
    self.ListView_serverList:setColumn(2)
    self.ListView_serverList:setRowMargin(5)
    self.ListView_serverList:setColumnMargin(5)

    self.tableView = Utils:scrollView2TableView(ScrollView_aredList)

    self.tableView:setDirection(TFTableView.TFSCROLLVERTICAL)
    self.tableView:setVerticalFillOrder(TFTableView.TFTabViewFILLTOPDOWN)
    self.tableView:addMEListener(TFTABLEVIEW_SIZEFORINDEX, handler(self.tableCellSize,self))
    self.tableView:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, handler(self.numberOfCells,self))
    self.tableView:addMEListener(TFTABLEVIEW_SIZEATINDEX, handler(self.tableCellAtIndex,self))
    self.Button_close:onClick(function()
        self:removeSelf()
    end)

    local stateTexts = 
    {
        [0] = 18000376, --爆满
        [2] = 18000377, --顺畅
        [1] = 18000378, --维护
    }

    local Image_states = TFDirector:getChildByPath(self.Panel_root, "Image_states")

    for k,v in pairs(stateTexts) do
        local Image_state = TFDirector:getChildByPath(Image_states, "Image_state"..k)
        local Label_tip = TFDirector:getChildByPath(Image_state, "Label_tip")
        if Label_tip then 
            Label_tip:setTextById(v)
        end
    end
    self.Label_title:setTextById(18000372)
    self.selectArea = self.areas[1]
    self:onSelectedGroup()
    self.tableView:reloadData()

    --self.ListView_serverList:setInertiaScrollEnabled(false)
    -- self.ListView_serverList:setBounceEnabled(false)




end

function ServerChoose:numberOfCells(tableView)
    return #self.areas
end

function ServerChoose:tableCellSize(tableView)
    local size = self.Area_Item:getContentSize()
    return size.height, size.width
end

function ServerChoose:tableCellAtIndex(tableView, idx)
    local cell = tableView:dequeueCell()
    local item = nil
    if nil == cell then
        cell = TFTableViewCell:create()
        item = self.Area_Item:clone()
        item.idx = idx
        cell:addChild(item)
        item:setPosition(ccp(0,0))
        item:show()
        cell.item = item
        item.Label_name = TFDirector:getChildByPath(item, "Label_name")   
        item.Image_select = TFDirector:getChildByPath(item, "Image_select")  
    else
        item = cell.item
    end
    self:updateCell(item, idx +1)
    return cell
end


function ServerChoose:updateCell(item, idx)
    local area = self.areas[idx]
    item.Label_name:setText(area.name)
    local selected = self.selectArea  == area
    item.Image_select:setVisible(selected)
    --item:setTextureNormal(selected and "ui/login/77.png" or "ui/login/7.png")
    item:removeMEListener(TFWIDGET_CLICK)
    item:onClick(function()
        if self.selectArea  ~= area then 
            self.selectArea  = area
            self.tableView:reloadData()
            self:onSelectedGroup()
        end
    end)
end

function ServerChoose:onSelectedGroup()
    print("刷新区服")
    if self.selectArea then 
        while #self.ListView_serverList:getItems() > #self.selectArea.servers do 
            self.ListView_serverList:removeLastItem()
        end

        while #self.ListView_serverList:getItems() < #self.selectArea.servers do 
            self.ListView_serverList:pushBackDefaultItem()
        end

        for _serverIndex, serverInfo in ipairs(self.selectArea.servers) do

            --local item  = self.Server_Item:clone()
            local item  = self.ListView_serverList:getItem(_serverIndex)
            local Image_bg   = TFDirector:getChildByPath(item, "Image_bg")
            local Label_area   = TFDirector:getChildByPath(item, "Label_area")
            local Label_name   = TFDirector:getChildByPath(item, "Label_name")
            local Image_new    = TFDirector:getChildByPath(item, "Image_new")
            local Image_state  = TFDirector:getChildByPath(item, "Image_state")
            local Label_time   = TFDirector:getChildByPath(item, "Label_time")
      
            if serverInfo.lastLoginTime > 0 then 
                Label_time:show()
                Label_time:setText(ServerDataMgr:lastLoginTip(serverInfo.lastLoginTime))
            else
                Label_time:hide()
            end 
            
            Label_area:setText(serverInfo.serverName)  
            Label_name:hide()
            -- Label_area:setText(serverInfo.areaName)  
            -- Label_name:setText(string.format("%02d\n服",serverInfo.serverName))
            Image_new:setVisible(serverInfo.new)

            Image_state:setTexture(self:getStateTexture(serverInfo.state))
            --Image_state:setVisible(serverInfo.state == 0)
            Image_bg:onClick(function()
                if serverInfo.state == 0 then 
                    ServerDataMgr:setServerInfo(serverInfo)
                    self:removeSelf()
                else
                    Utils:showTips(100036)
                end
            end)
        end
    else
        self.ListView_serverList:removeAllItems()
    end
end

-- status
-- 0 正常
-- 1 维护
-- 2 注册已达上限
function ServerChoose:getStateTexture(state)
    if state == 1 then --维护
        return "ui/login/dl_fwq_dd_wh.png"
    elseif state == 2 then --爆满
        return "ui/login/dl_fwq_dd_hb.png"
    else --正常
        return "ui/login/dl_fwq_dd_sc.png"
    end 

end


function ServerChoose:refreshView()

end




function ServerChoose:removeSelf()
    self:getParent():removeLayer(self,true)
end

function ServerChoose:registerEvents()
    self.Panel_root:onClick(function()
            self:getParent():removeLayer(self,true)
    end)
end

return ServerChoose
