
local FubenArenaFameHallView = class("FubenArenaFameHallView", BaseLayer)

function FubenArenaFameHallView:initData(levelGroupId, diff)
   
    self.playerDatas = ArenaDataMgr:getRankData().topRankHistory or {}

    -- dump(ArenaDataMgr:getRankData())
    -- dump(self.playerDatas)
end

function FubenArenaFameHallView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaFameHall")
end

function FubenArenaFameHallView:initUI(ui)
	self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Image_content = TFDirector:getChildByPath(self.Panel_root , "Image_content")
    self.Button_close = TFDirector:getChildByPath(self.Image_content , "Button_close")

    self.Panel_main = TFDirector:getChildByPath(self.Image_content , "Panel_main")
    self.Label_none = TFDirector:getChildByPath(self.Image_content , "Label_none")

    self.Button_step  = TFDirector:getChildByPath(self.Panel_main , "Button_step")
    self.Label_step   = TFDirector:getChildByPath(self.Button_step , "Label_step")
    self.Image_arrow  = TFDirector:getChildByPath(self.Button_step , "Image_arrow")
    self.players = {}
    for i=1,3 do
        local player  = TFDirector:getChildByPath(self.Panel_main , "Panel_player"..i)
        player.Label_rank  = TFDirector:getChildByPath(player , "Label_rank")
        player.Label_name = TFDirector:getChildByPath(player , "Label_name")
        player.Label_club_name = TFDirector:getChildByPath(player , "Label_club_name")
        player.Label_title = TFDirector:getChildByPath(player , "Label_title")
        player.Panel_role  = TFDirector:getChildByPath(player , "Panel_role")


        self.players[i] = player 
    end


    self.Button_step_prfab = TFDirector:getChildByPath(self.Image_content , "Button_step_prfab")
    self.ScrollView_steps = TFDirector:getChildByPath(self.Panel_main , "ScrollView_steps")
    self:setLang()
    self.ListView = UIListView:create(self.ScrollView_steps)
    self.ListView:setItemsMargin(2)
    self.ScrollView_steps:show()
    self.selectIndex = 1
    if #self.playerDatas > 0 then
        self.Panel_main:show()
        self.Label_none:hide()
        self:setSelectStep(1 ,true)
    else
        self.Label_none:show()
        self.Panel_main:hide()
    end 

   
end

function FubenArenaFameHallView:setLang()
    local Label_title_name = TFDirector:getChildByPath(self.Image_content , "Label_title_name")
    local Label_none       = TFDirector:getChildByPath(self.Image_content , "Label_none")
    Label_title_name:setTextById(290000086)
    Label_none:setTextById(290000088)
end

function FubenArenaFameHallView:setSelectStep(index,force)
    if ( self.selectIndex == index and not force ) or index > #self.playerDatas  then
        return  
    end
    self.selectIndex = index
    self.rankData  = self.playerDatas[self.selectIndex]
    self.Label_step:setTextById(290000102,self.rankData.index)

    for i,player in ipairs(self.players) do
        local playerData  = self.rankData.historyInfo[i]
        if playerData then 
            player:show()
            player.Label_rank:setText(playerData.topRank.rank)
            player.Label_name:setText(playerData.topRank.pName)
            if playerData.unionName then
                player.Label_club_name:setText(playerData.unionName)
            else
                player.Label_club_name:setTextById(63804)
            end
            player.Label_title:setText("")
            if playerData.title > 0 then 
                player.Label_title:removeAllChildren()
                local skeletonTitleNode = TitleDataMgr:getTitleEffectSkeletonModle(playerData.title, 1)
                player.Label_title:addChild(skeletonTitleNode,10)
            end


            -- if player.Panel_role.model then 
            --     player.Panel_role.model:removeFromParent() 
            -- end
                player.Panel_role.model  = Utils:createHeroModel_( player.Panel_role, playerData.firstHero.skin,"battleSize")
                -- player.Panel_role.model = Utils:createHeroModelByModelId(paint, 0.3)
                -- player.Panel_role:addChild(player.Panel_role.model)
                -- player.Panel_role.model:setScale(0.3)
                player.Panel_role.model:setPosition(ccp(0,0))
                player.Panel_role:setScale(0.7)
            -- end
        else
            player:hide()
        end
    end


end
--       3 = {
                 -- "arenaScore" = 1000
                 -- "headId"     = 401
                 -- "level"      = 80
                 -- "pName"      = "sdasa"
                 -- "pid"        = 530006285
                 -- "rank"       = 3
                 -- "segment"    = 1
             -- }



function FubenArenaFameHallView:showDropList()
    self.ScrollView_steps:show()
    self.stepCount = #self.playerDatas
    local items = self.ListView:getItems()
    local gap = self.stepCount - #items
    for i = 1, math.abs(gap) do
        if gap < 0 then
            self.ListView:removeItem(1)
        else
            local Panel_Item = self.Button_step_prfab:clone():show()
            Panel_Item.Label_name = TFDirector:getChildByPath(Panel_Item , "Label_name")
            self.ListView:pushBackCustomItem(Panel_Item)
        end
    end
    for i=1,self.stepCount do
        local index  = self.playerDatas[i].index or  i
        local item = self.ListView:getItem(i)
        item.Label_name:setTextById(290000102,index)
        if i == self.selectIndex then 
            item.Label_name:setFontColor(me.GREEN)
        else
            item.Label_name:setFontColor(me.WHITE)
        end
        item:onClick(function()
            self:setSelectStep(i)
            self:hideDropList()
        end)
    end

    self.Image_arrow:setRotation(0)
    self.ScrollView_steps:runAction(CCSpawn:create({CCFadeIn:create(0.15), CCScaleTo:create(0.15, 1, 1)}))
    self.isOpen = true
end

function FubenArenaFameHallView:hideDropList()
    self.Image_arrow:setRotation(180)
    self.ScrollView_steps:runAction(CCSpawn:create({CCFadeOut:create(0.15), CCScaleTo:create(0.15, 1, 0.01)}))
    self.isOpen = false
end


function FubenArenaFameHallView:registerEvents()
    self.Button_step:onClick(function()
        if not self.isOpen then
            self:showDropList()
        else
            self:hideDropList()
        end
    end)
    self.Button_close:onClick(function()
        AlertManager:close()
    end)
end


return FubenArenaFameHallView
