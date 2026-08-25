
local ServerListView = class("ServerListView", BaseLayer)

function ServerListView:initData()
    self.server_ = ServerDataMgr:getDebugServers()
end

function ServerListView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.test.serverListView")
end

function ServerListView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_prefab = TFDirector:getChildByPath(ui, "Panel_prefab"):hide()

    local ScrollView_serverList = TFDirector:getChildByPath(self.Panel_root, "ScrollView_serverList"):hide()
    self.ListView_serverList = UIListView:create(ScrollView_serverList)
    self.ListView_serverList:setItemsMargin(6)
    local ScrollView_groupList = TFDirector:getChildByPath(self.Panel_root, "ScrollView_groupList")
    self.ListView_groupList = UIListView:create(ScrollView_groupList)
    self.ListView_groupList:setItemsMargin(6)

    self.Button_serverListItem = TFDirector:getChildByPath(self.Panel_prefab, "Button_serverListItem")

    self:refreshView()
end

function ServerListView:refreshView()
    self:showServerGroup()
end

function ServerListView:showServerGroup()
    local sortServer = self.server_
    table.sort(sortServer, function(a,b)
        return a.sort < b.sort
    end)

    for i, v in ipairs(sortServer) do
        local item = self.Button_serverListItem:clone()
        self.ListView_groupList:pushBackCustomItem(item)
        local Label_name = TFDirector:getChildByPath(item, "Label_name")
        Label_name:setText(v.name)
        item:onClick(function()
                -- if serverList and #serverList > 0 then
                --     self.ListView_serverList:s():show()
                --     self:showServerList(groupName)
                -- else
                --     LogonHelper:switchLogin(groupName)
                --     self:getParent():removeLayer(self,true)
                --     EventMgr:dispatchEvent(EV_LOGIN_UPDATESERVERNAME)
                -- end

            LogonHelper:switchLogin(v.group)
            self:getParent():removeLayer(self,true)
            EventMgr:dispatchEvent(EV_LOGIN_UPDATESERVERNAME)
        end)
    end
end

-- function ServerListView:showServerList(groupName)
--     local serverList = self.server_[groupName].list
--     self.ListView_serverList:removeAllItems()
--     for _, serverName in ipairs(serverList) do
--         local item = self.Button_serverListItem:clone()
--         self.ListView_serverList:pushBackCustomItem(item)
--         local Label_name = TFDirector:getChildByPath(item, "Label_name")
--         Label_name:setText(serverName)

--         item:onClick(function()
--                 LogonHelper:switchLogin(groupName, serverName)
--                 --AlertManager:close()
--                 self:getParent():removeLayer(self,true)
--                 EventMgr:dispatchEvent(EV_LOGIN_UPDATESERVERNAME, groupName, serverName)
--         end)
--     end
-- end

function ServerListView:registerEvents()
    self.Panel_root:onClick(function()
        self:getParent():removeLayer(self,true)
    end)
end

return ServerListView
