local CollectPetView = class("CollectPetView",BaseLayer)

function CollectPetView:initData()
	self.pageUICfg = {}
	local tmPageUIcfg = CollectDataMgr:getPageUICfg(EC_CollectPage.PET)
	for k,v in pairs(tmPageUIcfg) do
		table.insert(self.pageUICfg,v)
	end
	table.sort( self.pageUICfg, function(a,b)
		return a.order < b.order
	end)
end

function CollectPetView:ctor()
	self.super.ctor(self)
	self:initData()
	self:init("lua.uiconfig.secondary.uiconfig_zn.collect.collectPetView")
end

function CollectPetView:initUI(ui)
	self.super.initUI(self,ui)
	self.root_panel = ui:getChildByName("Panel_root")
	local base_panel = self.root_panel:getChildByName("Panel_base")
	self.collectBaseView = require("lua.logic.collect.CollectBaseView"):new()
    base_panel:addChild(self.collectBaseView)
    self.childArr:push(self.collectBaseView)


    self.token_model = self.root_panel:getChildByName("Panel_token_model")
    self.cellModel = {}
    self.cellModel[1] = self.root_panel:getChildByName("Panel_single_cell")
    self.cellModel[2] = self.root_panel:getChildByName("Panel_suit_cell")
    local scroll_list = self.root_panel:getChildByName("ScrollView_list")
    self.list_view = UIListView:create(scroll_list)
	self.list_view:setScrollBar(self.collectBaseView.scrollBar)
    self:initBaseUI()
end

function CollectPetView:initBaseUI()
	local callbackCfg = {tabSelCallback = handler(self.onSelTab,self),filtSelCallback = handler(self.onSelFiltTab,self)}
	self.collectBaseView:registCallback(callbackCfg)
	self.collectBaseView:makeLeftBar(self.pageUICfg)
end

function CollectPetView:onSelTab(tabInfo)
	self.tabTypeId = tabInfo.id
	print("self.tabTypeId:" ..tostring(self.tabTypeId))
end

function CollectPetView:onSelFiltTab(filtInfo,filtKey)
	self:updateInfoPage(filtInfo,filtKey)
end

function CollectPetView:updatePage()
	self.collectBaseView:updateTrophy(EC_CollectPage.PET)
	CollectDataMgr:clearRedShow(EC_CollectPage.PET)
end

function CollectPetView:updateInfoPage(filtInfo)
	self.list_view:removeAllItems()
	-- if self.tabTypeId == 120001 then  --4星
	-- 	self:updatePage(filtInfo)
	-- elseif self.tabTypeId == 120002 then  --5星
	-- 	self:updatePage(filtInfo)
	-- elseif self.tabTypeId == 120003 then  --6星  
	-- 	self:updatePage(filtInfo)
	-- end
   self:updatePage_(filtInfo)
end

function CollectPetView:updatePage_(filtInfo)
	-- dump(filtInfo)

	local collectCount = filtInfo and table.count(filtInfo) or 0
	if collectCount >= 2 then
		table.sort( filtInfo, function(a,b)
			return a.order < b.order
		end )
	end
	if collectCount <= 0 then
		return
	end
	local cellCount = math.ceil(collectCount/7)
	for i=1,cellCount do
		local itemCell = self.cellModel[1]:clone()
		self.list_view:pushBackCustomItem(itemCell)
		itemCell:setVisible(true)
		for j = 1,7 do
			local petInfo = filtInfo[7*(i-1)+j]
			if petInfo == nil then
				return
			end
			local itemCard = self.token_model:clone()
			itemCard:setPosition(me.p(0,0))
			itemCell:getChildByName("Panel_equip_"..j):getChildByName("Panel_equip_card"):addChild(itemCard)
			itemCell:getChildByName("Panel_equip_"..j):setVisible(true)
			itemCard:setVisible(true)
			itemCard.cid = petInfo.id
			local isunclock = CollectDataMgr:isCollectItemExist(petInfo.collecttype,petInfo.id)
			local petCfg = CollectDataMgr:getPetCfg(petInfo.id)
			if not petCfg then
				dump(petInfo)
				Box("not found petCfg")
			end
			itemCell:getChildByName("Panel_equip_"..j):getChildByName("Image_lock"):setVisible(not isunclock)
			itemCell:getChildByName("Panel_equip_"..j):getChildByName("Label_title"):setTextById(petCfg.nameTextId)
			self:updateItemPet(itemCard,petInfo,isunclock,petCfg)
			
		end
	end
		

end


function CollectPetView:updateItemPet(itemCard,tokenInfo,isunclock,petCfg)
	itemCard:getChildByName("Image_frame"):setTexture(EC_ItemIcon[petCfg.quality])
    local scroll_star = itemCard:getChildByName("ScrollView_star")
    local star_cell = scroll_star:getChildByName("Panel_star")
    local starsize = star_cell:getContentSize()
    local star_listView = UIListView:create(scroll_star)
    star_listView:setItemModel(star_cell)
    star_listView:setContentSize(me.size(starsize.width*petCfg.endStar,starsize.height))
    for st =1,petCfg.endStar do
    	star_listView:pushBackDefaultItem()
    end

	TFDirector:getChildByPath(itemCard,"Label_level_title"):setTextById(800006, "")
	TFDirector:getChildByPath(itemCard,"Label_level"):setText(petCfg.level)

	itemCard:getChildByName("Image_icon"):setTexture(petCfg.icon)
    CollectDataMgr:addItemTrophy(itemCard, tokenInfo.id)
	-- itemCard:onClick(function()
	-- 	if CollectDataMgr:getItemClickEnable() == false then
	-- 		return
	-- 	end
	-- 	Utils:showInfo(itemCard.cid)
	-- end)
end


function CollectPetView:onShow()
	self:updatePage()
end

function CollectPetView:registerEvents()
	
end

return CollectPetView