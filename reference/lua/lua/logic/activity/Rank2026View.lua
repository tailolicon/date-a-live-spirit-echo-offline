--region *.lua
--Date
--此文件由[BabeLua]插件自动生成
local ResLoader = require("lua.logic.battle.ResLoader")
local COLUME = 3

local Rank2026View = class("Rank2026View", BaseLayer)
function Rank2026View:ctor(...)
	self.super.ctor(self)

	self:initData(...)
	self:init("lua.uiconfig.secondary.uiconfig_zn.activity.rank2026View")
end

function Rank2026View:initData()

   
	--打榜送礼的礼物ID
    self.flowerItemId = Utils:getKVP(90216, "giftId", 570031)
    print("flowerItemId: "..tostring(self.flowerItemId))
	local heroTables = TabDataMgr:getData("Hero")
    self.roleIds = {}
	for k,v in pairs(heroTables) do
		if v.testType == 0 and v.isOpen == 1 then 
			table.insert(self.roleIds,v.id)
		end
	end


	self.roleItem = {}

    self.batchNumDefault = 1
	if GoodsDataMgr:getItemCount(self.flowerItemId) == 0 then
		self.batchNumDefault = 0
	end

	self.changeScale = 1
	self.selectRole = nil



	--当前排行数据
	self.rankData = {}

	self.rankType = -1


	self.sendTime = 0

end

function Rank2026View:initUI(ui)
	self.super.initUI(self, ui)

	self.Image_content					= TFDirector:getChildByPath(ui,"Image_content")
	-- self.Image_content					= TFDirector:getChildByPath(ui,"Image_content")


	self.Panel_keyBoard1			    = TFDirector:getChildByPath(self.Image_content,"Panel_keyBoard1")
	self.Panel_keyBoard2			    = TFDirector:getChildByPath(self.Image_content,"Panel_keyBoard2")


	--切换到个人榜
	self.Button_changeSingle            = TFDirector:getChildByPath(self.Panel_keyBoard1,"Button_changeSingle")
	self.Panel_flowers					= TFDirector:getChildByPath(self.Panel_keyBoard1,"Panel_flowers")
	self.Panel_batch					= TFDirector:getChildByPath(self.Panel_keyBoard1,"Panel_batch")
	self.Panel_batch.Button_down		= TFDirector:getChildByPath(self.Panel_batch,"Button_down")
	self.Panel_batch.Button_up			= TFDirector:getChildByPath(self.Panel_batch,"Button_up")
	self.Panel_batch.Button_max			= TFDirector:getChildByPath(self.Panel_batch,"Button_max")
	self.Panel_batch.Label_num			= TFDirector:getChildByPath(self.Panel_batch,"Label_num")

self.Button_send = TFDirector:getChildByPath(self.Panel_batch,"Button_send")



    self.Button_back            = TFDirector:getChildByPath(self.Panel_keyBoard2,"Button_back")
    self.Button_single1         = TFDirector:getChildByPath(self.Panel_keyBoard2,"Button_single1")
	self.Button_single2         = TFDirector:getChildByPath(self.Panel_keyBoard2,"Button_single2")

    self.Image_focus1           = TFDirector:getChildByPath(self.Button_single1,"Image_focus1")
    self.Image_focus2           = TFDirector:getChildByPath(self.Button_single2,"Image_focus2")





	--预制体

	self.Panel_rank_item				= TFDirector:getChildByPath(ui,"Panel_rank_item")
	self.Panel_role_head				= TFDirector:getChildByPath(ui,"Panel_role_head")
	self.Panel_role_head.size 			= self.Panel_role_head:getContentSize()

	self.Label_title				= TFDirector:getChildByPath(self.Image_content,"Label_title")
    self.Label_title:setTextById(1100048)
    self.Label_title:setSkewX(10)

	self.ScrollView_Sprite				= TFDirector:getChildByPath(self.Image_content,"ScrollView_Sprite")
	self.ScrollView_Sprite:setInertiaScrollEnabled(true)
	self.ScrollView_Sprite.size			= self.ScrollView_Sprite:getContentSize()

	self.Panel_rank = TFDirector:getChildByPath(self.Image_content,"Panel_rank")
	-- self.Image_name_1 = TFDirector:getChildByPath(self.Panel_rank,"Image_name_1")
	-- self.Image_name_2 = TFDirector:getChildByPath(self.Panel_rank,"Image_name_2")
	-- self.Image_name_3 = TFDirector:getChildByPath(self.Panel_rank,"Image_name_3")
	self.Label_rank_title = TFDirector:getChildByPath(self.Panel_rank,"Label_rank_title")
	self.Label_rank_title:setSkewX(10)

	self:initLanguage()
	self.tableView						= Utils:scrollView2TableView( TFDirector:getChildByPath(self.Panel_rank,"tableview"))
	self:initRoleList()
	self:initTableView()
	self:initFlowers()

	self:changeRankType(1)
end

function Rank2026View:initLanguage()

	self.Label_castle = TFDirector:getChildByPath(self.Button_send,"Label_castle")
	self.Label_castle:setTextById(700014) --赠送

	self.Label_changeSingle = TFDirector:getChildByPath(self.Button_changeSingle,"Label_changeSingle")
	self.Label_changeSingle:setTextById(13317080) 


	self.Label_single2 = TFDirector:getChildByPath(self.Button_single2,"Label_single2")
	self.Label_single2:setTextById(13317084)

	self.Label_single1 = TFDirector:getChildByPath(self.Button_single1,"Label_single1")
	self.Label_single1:setTextById(13317083 )

	self.Label_back = TFDirector:getChildByPath(self.Button_back,"Label_back")
	self.Label_back:setTextById(13317082 ) 

end


function Rank2026View:initRoleList()
	local row = math.ceil( #self.roleIds / COLUME)
	self.ScrollView_Sprite:setInnerContainerSize(ccs(self.ScrollView_Sprite.size.width, row * (self.Panel_role_head.size.height + 5)))
	self.roleItems = {}
	for i=1,#self.roleIds do
			local role  = self.Panel_role_head:clone()
		    role.heroId = self.roleIds[i]
			local nameTextId ,heroIcon  = self:getHeroCfg(role.heroId)
			self.ScrollView_Sprite:addChild(role)
			role:setPosition(self:getItemPos(i))
			--头像
			role.head = role:getChildByName("head_frame")
			role.head:setTexture(heroIcon)

			role.Image_bg_unselect = TFDirector:getChildByPath(role,"Image_bg_unselect"):show()
			role.Image_bg_select = TFDirector:getChildByPath(role,"Image_bg_select"):hide()
			role.Label_name = TFDirector:getChildByPath(role,"Label_name")
			role.Label_name:setTextById(nameTextId)
			role.Label_name:setSkewX(10)
			local touch = TFDirector:getChildByPath(role,"touch"):show()
			touch:setTouchEnabled(true)
			touch:addMEListener(TFWIDGET_CLICK, function()
				self:selectRoleItem(role)
			end)
			role.touch = touch


			role.Image_vote = TFDirector:getChildByPath(role,"Image_vote"):hide()
			role.Image_vote_focus = TFDirector:getChildByPath(role.Image_vote,"Image_vote_focus")
			role.Label_vote_name = TFDirector:getChildByPath(role.Image_vote,"Label_vote_name")
			role.Label_vote = TFDirector:getChildByPath(role.Image_vote,"Label_vote")
			role.Label_vote_name:setSkewX(10)
			role.Label_vote:setSkewX(10)
			role.Label_vote_name:setTextById(13317081)
		    self.roleItems[i]= role

	end

end

function Rank2026View:selectRoleItem(role ,reqData)
	if self.selectRole ~= role then
		if self.selectRole then
			self.selectRole.Image_bg_unselect:show()
			self.selectRole.Image_bg_select:hide()
		end	
		role.Image_bg_unselect:hide()
		role.Image_bg_select:show()
		self.selectRole = role

        --选择角色出现不一同时，重置送礼数量
		self.batchNumDefault = 1
	    if GoodsDataMgr:getItemCount(self.flowerItemId) == 0 then
			self.batchNumDefault = 0
		end
		self:updateFlowersCount()
    end

	if reqData or self.rankType == 2 or self.rankType == 3  then 
		ActivityDataMgr:reqGigtRankInfo(self.rankType ,self.selectRole.heroId)
	end



end

function Rank2026View:getItemPos(index)
	local container = self.ScrollView_Sprite:getInnerContainer()
	local prefabSize = self.Panel_role_head:getSize()
	local row = math.ceil( index / COLUME)
	local col = (index - 1) % COLUME
	return ccp((prefabSize.width + 4) * (col) + 5, container:getSize().height - (prefabSize.height + 5) * (row - 0.0))
end

function Rank2026View:initTableView()
	self.tableView:setDirection(TFTableView.TFSCROLLVERTICAL)
	self.tableView:setVerticalFillOrder(TFTableView.TFTabViewFILLTOPDOWN)
	self.tableView:addMEListener(TFTABLEVIEW_SIZEFORINDEX, handler(self.tableCellSize,self))
    self.tableView:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, handler(self.numberOfCells,self))
    self.tableView:addMEListener(TFTABLEVIEW_SIZEATINDEX, handler(self.tableCellAtIndex,self))

end

function Rank2026View:numberOfCells(tableView)
	-- print("#self.rankData : " ..#self.rankData )
	return #self.rankData + 1
end

function Rank2026View:tableCellSize(tableView)
	local size = self.Panel_rank_item:getContentSize()
	return size.height, size.width
end

function Rank2026View:tableCellAtIndex(tableView, idx)
	local cell = tableView:dequeueCell()
    local item = nil
	if nil == cell then

        cell = TFTableViewCell:create()
        item = self.Panel_rank_item:clone()
		item.idx = idx
        item:show()
        item:setPosition(ccp(150,0))
        cell:addChild(item)
        cell.item = item

		self:initCell(item)	
	else
		item = cell.item
    end
	self:updateCell(item, self.rankData[idx + 1], idx + 1)
	return cell
end

function Rank2026View:initCell(item)
	item.Layout1 = TFDirector:getChildByPath(item, "Layout1")
	item.Layout2 = TFDirector:getChildByPath(item, "Layout2")
	item.Image_icon = TFDirector:getChildByPath(item, "Image_icon")
	item.Image_box1 = TFDirector:getChildByPath(item, "Image_box1")
	item.Image_box2 = TFDirector:getChildByPath(item, "Image_box2")
	item.Image_box3 = TFDirector:getChildByPath(item, "Image_box3")
	item.Image_box4 = TFDirector:getChildByPath(item, "Image_box4")
	
	item.Layout1.Label_name = TFDirector:getChildByPath(item.Layout1, "Label_name")
	item.Layout1.Label_votes = TFDirector:getChildByPath(item.Layout1, "Label_votes")
	item.Layout1.Label_level = TFDirector:getChildByPath(item.Layout1, "Label_level")
	item.Layout1.Label_level:setSkewX(10)
	item.Layout1.Label_name:setSkewX(10)
	item.Layout1.Label_votes:setSkewX(10)

	item.Layout2.Label_name = TFDirector:getChildByPath(item.Layout2, "Label_name")
	item.Layout2.Label_votes = TFDirector:getChildByPath(item.Layout2, "Label_votes")
	item.Layout2.Label_level = TFDirector:getChildByPath(item.Layout2, "Label_level")
    item.Layout2.Label_rank = TFDirector:getChildByPath(item.Layout2, "Label_rank")
	item.Layout2.Label_level:setSkewX(10)
	item.Layout2.Label_name:setSkewX(10)
	item.Layout2.Label_votes:setSkewX(10)

end

-- //个人榜
-- message PersonalRakInfo{
-- 	required int32 rank = 1;	//排名
-- 	required int64 score = 2;		//分数
-- 	required int32 heroId = 3;//精灵id，rankType为2或者3时候需要

-- 	required int32 playerId = 4;//玩家id
-- 	required string name = 5; //玩家名字
-- 	required int32 lv = 6; //等级
-- 	required int32 portraitCid = 7;				//头像id
-- 	required int32 portraitFrameCid = 8;		//头像框id
-- }


function Rank2026View:updateCell(item, data, idx)
	if idx > #self.rankData then
		item:hide()
		return
	else
		item:show()
	end
	item.Layout1:setVisible(self.rankType == 1)
	item.Layout2:setVisible(self.rankType ~= 1)
	local player_rank  = data.rank 
	local player_vote  = data.score
	local player_level = data.lv or 1



	local player_head      = ""


	if self.rankType == 1 then --总榜 精灵

 	    local heroCfg = TabDataMgr:getData("Hero",data.heroId)
	    local skinCfg = TabDataMgr:getData("HeroSkin",heroCfg.defaultSkin)
		player_head = skinCfg.heroIcon

		item.Image_icon:setPositionX(-25)
		item.Layout1.Label_name:setTextById(heroCfg.nameTextId)
		item.Layout1.Label_votes:setTextById(13317079,player_vote)
		item.Layout1.Label_level:setText("Lv."..player_level)

    else --个人榜
    	
        player_head = AvatarDataMgr:getAvatarIconPath(data.portraitCid)

		item.Image_icon:setPositionX(0)
		item.Layout2.Label_name:setText(data.name)
		if self.rankType == 2 then
			item.Layout2.Label_votes:setTextById(13317085,player_vote)
		else
			item.Layout2.Label_votes:setTextById(110000104,player_vote)
		end
		item.Layout2.Label_level:setText("Lv."..player_level)
		item.Layout2.Label_rank:setText(player_rank)

	end	
	item.Image_icon:setTexture(player_head)
	item.Image_box1:setVisible(player_rank == 1)
	item.Image_box2:setVisible(player_rank == 2)
	item.Image_box3:setVisible(player_rank == 3)
	item.Image_box4:setVisible(player_rank > 3)



	-- print("show----")
end


function Rank2026View:onShow()
	self.super.onShow(self)
end



function Rank2026View:addTimer()
	if self.timer__ == nil then
		self.timer__ = TFDirector:addTimer(100,nil,nil,function ( ... )

			if self.continueTouchSubStract then
				self:substractFlower(self.changeScale)
			end

			if self.continueTouchAdd then
				self:addFlower(self.changeScale)
			end
			self.changeScale = self.changeScale + 0.2
		end)
	end
end

function Rank2026View:addFlower(scale)
	self.batchNumDefault = self.batchNumDefault + math.floor(scale)
	local max = GoodsDataMgr:getItemCount(self.flowerItemId)
	if self.batchNumDefault > max then
		self.batchNumDefault = max
	end

	self:updateFlowersCount()
end

function Rank2026View:substractFlower(scale)
	self.batchNumDefault = self.batchNumDefault - math.floor(scale)
	if self.batchNumDefault < 1 then
		self.batchNumDefault = 1
	end

	self:updateFlowersCount()
end

function Rank2026View:initFlowers()
	local flowerItemId = self.flowerItemId
	local flowerItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
	flowerItem:setPosition(0,0)
	flowerItem:setScale(0.6)
	PrefabDataMgr:setInfo(flowerItem, flowerItemId, GoodsDataMgr:getItemCount(flowerItemId))
	self.Panel_flowers:addChild(flowerItem)
	self.Panel_flowers.flowerItem = flowerItem

	self:updateFlowersCount()
end

function Rank2026View:updateFlowersCount()
	local num = GoodsDataMgr:getItemCount(self.flowerItemId)
	if num > 0 then
		self.Panel_batch.Label_num:setText(self.batchNumDefault)
	else
		self.Panel_batch.Label_num:setText(0)
	end
end

function Rank2026View:refreshRank(rankType)
	if self.rankType ~= rankType then 
		return
	end
    if self.rankType == 1 then --总榜
		self.rankData = ActivityDataMgr:getTopRank()
	elseif self.rankType == 2 then --个人人气榜
    	self.rankData = ActivityDataMgr:getPersonalContributionRank()
    elseif self.rankType == 3 then --个人战力榜
    	self.rankData = ActivityDataMgr:getPersonalPowerRank()
	end
    self.tableView:reloadData()
end

function Rank2026View:registerEvents()
	self.super.registerEvents(self)
	--排行榜数据更新
    EventMgr:addEventListener(self, EV_HERO_RANK_UPDATE, handler(self.refreshRank, self))
	EventMgr:addEventListener(self, EV_BAG_ITEM_UPDATE, handler(self.updateFlowerNum, self))

	self.Panel_batch.Button_down:onClick(function()		
		self:substractFlower(1)
	end)
	self.Panel_batch.Button_down:onTouch(function(event)
		if event.name == "began" then
			self.changeScale = 0
			self.continueTouchSubStract = true
		elseif event.name == "ended" then
			self.continueTouchSubStract = false
			self.changeScale = 0
		end
	end)

	self.Panel_batch.Button_up:onClick(function()
		self:addFlower(1)
	end)
	self.Panel_batch.Button_up:onTouch(function(event)
		if event.name == "began" then
			self.changeScale = 0
			self.continueTouchAdd = true
		elseif event.name == "ended" then
			self.continueTouchAdd = false
			self.changeScale = 0
		end
	end)

	self.Panel_batch.Button_max:onClick(function()
		self.batchNumDefault = GoodsDataMgr:getItemCount(self.flowerItemId)
		self:updateFlowersCount()
	end)


	--榜单切换
	self.Button_back:onClick(function()
		--返回总榜
		self:changeRankType(1)
	end)

	self.Button_single1:onClick(function()
		self:changeRankType(2)
	end)

	self.Button_single2:onClick(function()
		self:changeRankType(3)
	end)

	self.Button_changeSingle:onClick(function()
		self:changeRankType(2)
	end)


	self.Button_send:onClick(function()
		--todo send
		if self.selectRole == nil then
			Utils:showTips(16500003)
			return
		end
		if GoodsDataMgr:getItemCount(self.flowerItemId) == 0 then
			Utils:showTips(16500004)
			return
		end
		local time  = os.time()
		if time -  self.sendTime < 3 then 
			Utils:showTips(200007)
			return
		end
		self.sendTime = time
		local heroId  = self.selectRole.heroId
		local itemNum = self.batchNumDefault
        ActivityDataMgr:reqSendGift(heroId,itemNum)


	end)

	self:addTimer()
end


function Rank2026View:removeEvents()
	self.super.removeEvents(self)

	if self.timer__ then
		TFDirector:stopTimer(self.timer__)
		TFDirector:removeTimer(self.timer__)
		self.timer__ = nil
	end
end



function Rank2026View:updateFlowerNum()
	local hasNum = GoodsDataMgr:getItemCount(self.flowerItemId)
	if self.Panel_flowers and self.Panel_flowers.flowerItem then
		PrefabDataMgr:setInfo(self.Panel_flowers.flowerItem, self.flowerItemId, hasNum)
	end

	if self.batchNumDefault > hasNum then
		self.batchNumDefault = hasNum
		self:updateFlowersCount()
	end
end

--切换磅榜单
function Rank2026View:changeRankType(rankType_)

	if self.rankType ~= rankType_ then  
		self.rankType = rankType_

		self:onRankChange()
	end
end


function Rank2026View:refreshRoleItem(role ,idx ,topRankTable)
    role:setPosition(self:getItemPos(idx))
	role.Image_vote:setVisible(self.rankType == 3 or self.rankType == 2)	
    role.Image_bg_select:setVisible(self.selectRole == role)
    role.Image_bg_unselect:setVisible(self.selectRole ~= role)
    role.Image_vote_focus:setVisible(self.selectRole == role )
    local vote = topRankTable[role.heroId] and topRankTable[role.heroId].score or 0
    role.Label_vote:setText(vote)
 

end

function Rank2026View:refreshRoleList()
--排序
    local tables  = self:getTopRankTable()  
    if self.rankType == 2 or self.rankType == 3 then 
     	table.sort(self.roleItems ,function (a , b)
     	    local a = tables[a.heroId] and tables[a.heroId].rank or 999 
     	    local b = tables[b.heroId] and tables[b.heroId].rank or 999 
     	    return a < b
     	end)
    end
	for i,v in ipairs(self.roleItems) do
		self:refreshRoleItem(v ,i ,tables)
	end
	self.ScrollView_Sprite:setInnerContainerSize(self.ScrollView_Sprite:getInnerContainerSize())
end

--总榜转MAP 方便查找
function Rank2026View:getTopRankTable()
   local data   = ActivityDataMgr:getTopRank()
   local tables = {}
   for i,v in ipairs(data) do
   	   tables[v.heroId] = v
   end
   return tables
end

--排行榜切换
function Rank2026View:onRankChange()
	-- print("self.rankType : " ..self.rankType )

	self:refreshRoleList()
	if self.rankType == 1 then
		self.Label_rank_title:setTextById(13317086)
	elseif self.rankType == 2 then
		self.Label_rank_title:setTextById(13317087)
	elseif self.rankType == 3 then
		self.Label_rank_title:setTextById(13317087)
	end
	-- self.Image_name_1:setVisible(self.rankType == 1)
 --    self.Image_name_2:setVisible(self.rankType == 2)
	-- self.Image_name_3:setVisible(self.rankType == 3)
	
	self.Panel_keyBoard1:setVisible(self.rankType == 1)
	self.Panel_keyBoard2:setVisible(self.rankType == 3 or self.rankType == 2)
	self.Image_focus1:setVisible(self.rankType == 2)
	self.Image_focus2:setVisible(self.rankType == 3)


	self:refreshRank(self.rankType)


	self:selectRoleItem(self.selectRole and self.selectRole or self.roleItems[1] ,true )
		


end

--
function Rank2026View:getHeroCfg(id)
	local roleCfg = TabDataMgr:getData("Hero",id)
	local skinCfg = TabDataMgr:getData("HeroSkin",roleCfg.defaultSkin)
	return roleCfg.nameTextId , skinCfg.heroIcon
end


return Rank2026View

--endregion
