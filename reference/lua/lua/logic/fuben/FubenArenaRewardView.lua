
local FubenArenaRewardView = class("FubenArenaRewardView", BaseLayer)

function FubenArenaRewardView:initData(levelGroupId, diff)
    self.segmentRewards = {} 
    local rewards = TabDataMgr:getData("RankReward")
    for k,v in pairs(rewards) do
        local rankData = {}
        rankData.rankName = v.rankName
        rankData.id = v.id
        local rankSize = #v.rankAward /2
        rankData.rankReward = {}
        local rankS = 1
        for i = 1 , rankSize do
            local rankE     = v.rankAward[i*2-1]
            local rankInfo  = {}
            rankInfo.rank   = rankS < rankE and  string.format("%s-%s" ,rankS ,rankE) or tostring(rankE)
            rankInfo.rankE  = rankE
            rankInfo.reward = {}
            for k,v in pairs(v.rankAward[i*2]) do
                table.insert(rankInfo.reward ,{id = k ,num = v})
            end
            table.insert(rankData.rankReward,rankInfo)
            rankS = rankE + 1
        end
        table.insert(self.segmentRewards,rankData)
    end
    table.sort(self.segmentRewards  ,function (a,b)
        return a.id  < b.id
    end)

    -- dump(self.segmentRewards)
end

function FubenArenaRewardView:ctor(...)
    self.super.ctor(self)
    self:initData(...)
    self:showPopAnim(true)
    self:init("lua.uiconfig.secondary.uiconfig_zn.fuben.fubenArenaReward")
end

function FubenArenaRewardView:initUI(ui)
	self.super.initUI(self, ui)
    self.Panel_root = TFDirector:getChildByPath(ui, "Panel_root")
    self.Panel_prefab = TFDirector:getChildByPath(ui, "Panel_prefab"):hide()
    self.Panel_reward_item = TFDirector:getChildByPath(self.Panel_prefab, "Panel_reward_item")
    self.Button_grade  = TFDirector:getChildByPath(self.Panel_prefab, "Button_grade")
    -- if self.levelGroupId_ == 9401 then --海王星联动替换星星资源 
    --     local Image_star = TFDirector:getChildByPath(self.Panel_prefab , "Image_FubenArenaRewardView_2")
    --     Image_star:setTexture("ui/fuben/linkage/checkpoint/020.png")
    -- end
    self.Image_bg = TFDirector:getChildByPath(self.Panel_root, "Image_bg")

    -- self.Label_title_tip = TFDirector:getChildByPath(self.Image_bg, "Label_title_tip")
    -- self.Label_title_tip:setTextById(63991)
    local ScrollViewReward = TFDirector:getChildByPath(self.Image_bg, "ScrollViewReward")
    self.ListView = UIListView:create(ScrollViewReward)
    self.Button_close = TFDirector:getChildByPath(self.Image_bg, "Button_close")
    self.ScrollViewGrade  = TFDirector:getChildByPath(self.Image_bg, "ScrollViewGrade")
    self.ListViewGrade = UIListView:create(self.ScrollViewGrade)
    self.buttonGrades = {}
local color_sets =  
{
    {ccc3(200,220,218) ,ccc3(80,146,138),ccc3(255,255,255)},
    {ccc3(226, 240, 253) ,ccc3(215, 218, 218),ccc3(255,255,255)},


    {ccc3(244, 228, 134) ,ccc3(255, 202, 28),ccc3(255,255,255)},
    {ccc3(248, 250, 252) ,ccc3(255,255,255),ccc3(179, 182, 186)},

    {ccc3(229, 203, 252) ,ccc3(254, 174, 250),ccc3(255,255,255)},
    {ccc3(234, 148, 155) ,ccc3(240, 54, 55),ccc3(255,255,255)},
 

}

    for i,v in ipairs(self.segmentRewards) do

        local color_set =  color_sets[v.id]  
        local item = self.Button_grade:clone():show()
        item.Lable_name = TFDirector:getChildByPath(item, "Label_name")

        local name_text = ArenaDataMgr:segmentName(v.id)
        item.Lable_name:setTextById(name_text)
        item.Lable_name:setFontColor(color_set[2])
        item.Lable_name:enableStroke(color_set[3], 1)
        if Utils:isCH() then 
            item.Lable_name:setFontSize(30)
        else
            item.Lable_name:setFontSize(20)
        end

        item.Image_select = TFDirector:getChildByPath(item, "Image_select")
        item.Image_normal = TFDirector:getChildByPath(item, "Image_normal")
        item.Image_select:setColor(color_set[1])
        item.Image_normal:setColor(color_set[1])

        local name_path   = ArenaDataMgr:segmentImageName(v.id)
        -- item.Image_normal:setTexture(name_path)
        local name_path_focus =  string.gsub(name_path ,".png","_focus.png")
        print(" name_path_focus: " ..name_path_focus)
        -- item.Image_select:setTexture(name_path_focus)
        item:onClick(function ()
            self:setSelect(i)
        end)
        self.ListViewGrade:pushBackCustomItem(item)

    end
    self:setLang()
    self:setSelect(1)
    --self:refreshView()
end

function FubenArenaRewardView:setLang()
    local Label_title_name = TFDirector:getChildByPath(self.Image_bg, "Label_title_name")
    local Label_title_tip  = TFDirector:getChildByPath(self.Image_bg, "Label_title_tip")
    local Label_title1  = TFDirector:getChildByPath(self.Image_bg, "Label_title1")
    local Label_title2  = TFDirector:getChildByPath(self.Image_bg, "Label_title2")
    Label_title_name:setTextById(3202055)
    Label_title_tip:setTextById(63995)
    Label_title1:setTextById(12101042)
    Label_title2:setTextById(14220070)

end

function FubenArenaRewardView:setSelect(selectIndex)
    if self.selectIndex == selectIndex then 
        return
    end
    self.selectIndex = selectIndex
    local items = self.ListViewGrade:getItems()
    for i,v in ipairs(items) do
        v.Image_select:setVisible(i == self.selectIndex)
    end
    --切换对应段位的奖励
    self:refreshView()
end
function FubenArenaRewardView:refreshView()

    local rankAward  = self.segmentRewards[self.selectIndex].rankReward
    local items = self.ListView:getItems()
    local gap = #rankAward - #items
    for i = 1, math.abs(gap) do
        if gap < 0 then
            self.ListView:removeItem(1)
        else
            local item = self.Panel_reward_item:clone():show()

            item.ScrollView_reward = TFDirector:getChildByPath(item, "ScrollView_reward")
            item.ListView          = UIListView:create(item.ScrollView_reward)
            item.Label_rank        = TFDirector:getChildByPath(item, "Label_rank")
            item.Image_rank1        = TFDirector:getChildByPath(item, "Image_rank1")
            item.Image_rank2        = TFDirector:getChildByPath(item, "Image_rank2")
            item.Image_rank3        = TFDirector:getChildByPath(item, "Image_rank3")
            self.ListView:pushBackCustomItem(item)
        end
    end

    for i,v in ipairs(rankAward) do

        local item  = self.ListView:getItem(i)
        item.Label_rank:setText(""..v.rank)
        item.Label_rank:setVisible(v.rankE > 3)

        item.Image_rank1:setVisible(v.rankE == 1)
        item.Image_rank2:setVisible(v.rankE == 2)
        item.Image_rank3:setVisible(v.rankE == 3)
        --刷新奖励
        local rewardCount = #v.reward
        local rewardItems = item.ListView:getItems()
        local gap = rewardCount - #rewardItems
        for i = 1, math.abs(gap) do
            if gap < 0 then
                item.ListView:removeItem(1)
            else
                local panel_goodsItem = PrefabDataMgr:getPrefab("Panel_goodsItem"):clone()
                panel_goodsItem:setScale(0.75)
                item.ListView:pushBackCustomItem(panel_goodsItem)
            end
        end

        for k, v in ipairs(v.reward) do
            local panel_goodsItem = item.ListView:getItem(k) 
           PrefabDataMgr:setInfo(panel_goodsItem, tonumber(v.id), v.num)
     
        end
    end

end


function FubenArenaRewardView:registerEvents()
    self.Button_close:onClick(function()
        AlertManager:closeLayer(self)
    end)
end

return FubenArenaRewardView
