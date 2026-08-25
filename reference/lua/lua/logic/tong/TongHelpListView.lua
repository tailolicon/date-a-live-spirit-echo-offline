
local TongHelpListView = class("TongHelpListView", BaseLayer)
function TongHelpListView:initData()

    self.helpData = {}
end

function TongHelpListView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:init("lua.uiconfig.tong.tongHelpListView")
    self:showPopAnim(true)
    self.opacity = 255 * 0.45
end

function TongHelpListView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close")

    local ScrollView_list       = TFDirector:getChildByPath(ui, "ScrollView_list")
    self.TableView_help         = Utils:scrollView2TableView(ScrollView_list)


    self.Label_nil_tip          = TFDirector:getChildByPath(ui, "Label_nil_tip")
    self.Label_point            = TFDirector:getChildByPath(ui, "Label_point")

    self.Panel_item             = TFDirector:getChildByPath(ui, "Panel_item")

    self.TableView_help:addMEListener(TFTABLEVIEW_SIZEFORINDEX, handler(self.cellSizeForTable, self))
    self.TableView_help:addMEListener(TFTABLEVIEW_SIZEATINDEX, handler(self.tableCellAtIndex, self))
    self.TableView_help:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, handler(self.numberOfCellsInTableView, self))

    self:timeOut(function()
        TongDataMgr:Send_getHelpInfo()
    end,0)


end

function TongHelpListView:updateHelpInfo()


    local remainCnt = TongDataMgr:getLeftHelpCnt()
    self.Label_point:setTextById(13206048,remainCnt)

    local helpList = TongDataMgr:getHelpList()
    if not helpList then
        return
    end
    self.helpData = helpList
    self.TableView_help:reloadData()

    self.Label_nil_tip:setVisible(#self.helpData <= 0)
end

function TongHelpListView:cellSizeForTable()
    local size = self.Panel_item:getSize()
    return size.height, size.width
end

function TongHelpListView:numberOfCellsInTableView()
    return #self.helpData
end

function TongHelpListView:tableCellAtIndex(tab, idx)
    local cell = tab:dequeueCell()
    idx = idx + 1
    if not cell then
        cell = TFTableViewCell:create()
        local item = self.Panel_item:clone()
        item:setAnchorPoint(ccp(0, 0))
        item:setPosition(ccp(0, 0))
        cell:addChild(item)
        cell.item = item
    end
    cell.idx = idx

    if cell.item then
        self:updateListItem(cell.item, self.helpData[idx])
    end

    return cell
end

function TongHelpListView:updateListItem(item,data)

    local Image_icon             = TFDirector:getChildByPath(item, "Image_icon")
    local Label_name             = TFDirector:getChildByPath(item, "Label_name")
    local Image_boss             = TFDirector:getChildByPath(item, "Image_boss")
    local Label_boss             = TFDirector:getChildByPath(item, "Label_boss")
    local Label_threaten         = TFDirector:getChildByPath(item, "Label_threaten")
    local Button_help            = TFDirector:getChildByPath(item, "Button_help")

    local avatarFrameIcon,avatarFrameEffect = AvatarDataMgr:getAvatarFrameIconPath(data.headFrame)
    Image_icon:setTexture(AvatarDataMgr:getAvatarIconPath(data.headId))
    Label_name:setText(data.name)
    Label_boss:setText(data.bossName)

    local cfg = TongDataMgr:getVitDungonCfg(data.id)
    if cfg then
        local dungeonInclude = cfg.dungeonInclude
        local levelCid = dungeonInclude[1]
        local vitMaxDungonInfo = TabDataMgr:getData("DungeonInfoOfVITmax")[levelCid]
        if vitMaxDungonInfo then
            Image_boss:setTexture(vitMaxDungonInfo.eliteBossIcon)
            Label_boss:setTextById(vitMaxDungonInfo.eliteBossName)
        end
        print(levelCid)
        local lv = TongDataMgr:getThreatLvByLevelCid(levelCid)
        Label_threaten:setTextById(13206049,lv)
    end

    Button_help:onClick(function()
        local remainCnt = TongDataMgr:getLeftHelpCnt()
        if remainCnt <= 0 then
            Utils:showTips(13206050)
            return
        end
        local str = TextDataMgr:getText(13206051,data.name)
        Utils:showTips(str)
        TongDataMgr:Send_helpOthers(data.playerId,data.uid)
    end)

end

function TongHelpListView:registerEvents()

    EventMgr:addEventListener(self, EV_TONG.HelpInfo, handler(self.updateHelpInfo, self))

    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)

end

return TongHelpListView
