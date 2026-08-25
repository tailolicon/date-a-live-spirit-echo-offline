
local TongStudyMainView = class("TongStudyMainView", BaseLayer)
function TongStudyMainView:initData(guideClick)
    self.vitSkillCfg = {}
    local VITmaxSkill = TabDataMgr:getData("VITmaxSkill")
    for k,v in pairs(VITmaxSkill) do
       table.insert(self.vitSkillCfg,v)
    end
    self.vitAttrCfg = {}
    local VITmaxAttribute = TabDataMgr:getData("VITmaxAttribute")
    for k,v in pairs(VITmaxAttribute) do
        table.insert(self.vitAttrCfg,v)
    end

    local kvpCfg = Utils:getKVP(90045)
    self.resetCost = kvpCfg.resetCost or {}
    self.attrItemId = kvpCfg.itemId


    self.ownPoint = GoodsDataMgr:getItemCount(self.attrItemId)
    self.totalCost = 0

    self.guideClick = guideClick

    dump(kvpCfg,"kvpCfg")
    self.dialogScriptId = 25071
end

function TongStudyMainView:ctor(guideClick)
    self.super.ctor(self)
    self:initData(guideClick)
    self:init("lua.uiconfig.tong.tongStudyMainView")
    self.block = AlertManager.BLOCK_CLOSE
end

function TongStudyMainView:initUI(ui)
    self.super.initUI(self, ui)
    self.Panel_root             = TFDirector:getChildByPath(ui, "Panel_root")

    self.Button_close           = TFDirector:getChildByPath(ui, "Button_close"):hide()
    local ScrollView_attr       = TFDirector:getChildByPath(ui, "ScrollView_attr")
    self.UIListView_attr        = UIListView:create(ScrollView_attr)

    self.Label_cost             = TFDirector:getChildByPath(ui, "Label_cost")
    self.Image_cost_icon        = TFDirector:getChildByPath(ui, "Image_cost_icon")
    self.Button_reset           = TFDirector:getChildByPath(ui, "Button_reset")
    self.Button_confirmAttr     = TFDirector:getChildByPath(ui, "Button_confirmAttr")
    self.Panel_skill_item       = TFDirector:getChildByPath(ui, "Panel_skill_item")
    local ScrollView_skill      = TFDirector:getChildByPath(ui, "ScrollView_skill")
    self.UIGridView_skill       = UIGridView:create(ScrollView_skill)

    self.Image_reset_icon       = TFDirector:getChildByPath(ui, "Image_reset_icon")
    self.Label_reset_cost       = TFDirector:getChildByPath(ui, "Label_reset_cost")

    self.UIGridView_skill:setItemModel(self.Panel_skill_item)
    self.UIGridView_skill:setColumn(5)
    self.UIGridView_skill:setColumnMargin(6)


    self.Label_num              = TFDirector:getChildByPath(ui, "Label_num")
    self.Button_down            = TFDirector:getChildByPath(ui, "Button_down")
    self.Button_up              = TFDirector:getChildByPath(ui, "Button_up")

    self.equipSkill_ = {}
    for i=1,3 do
        local item              = TFDirector:getChildByPath(ui, "Panel_skill_"..i)
        local icon              = TFDirector:getChildByPath(item, "Image_icon")
        local select            = TFDirector:getChildByPath(item, "Image_select")
        table.insert(self.equipSkill_,{root = item, icon = icon, select = select})
    end
    self.Button_exit            = TFDirector:getChildByPath(ui, "Button_exit")

    self.Panel_attr_item        = TFDirector:getChildByPath(ui, "Panel_attr_item")

    self:timeOut(function()
        self:playGuide()
    end,0)

    self:initUILogic()
end

function TongStudyMainView:playGuide()
    print("guideClick",self.guideClick)

    local flag = tonumber(Utils:getLocalSettingValue("TongStudyMainView"..self.dialogScriptId)) or 0
    if flag == 1 then
        return
    end

    Utils:setLocalSettingValue("TongStudyMainView"..self.dialogScriptId,1)

    local function callback()
        KabalaTreeDataMgr:playStory(1,self.dialogScriptId,function ()
            self.guideClick = false
            EventMgr:dispatchEvent(EV_CG_END)
        end)
    end
    KabalaTreeDataMgr:openCgView("kabalaTree.KabalaTreeCg",callback)
end

function TongStudyMainView:initUILogic()

    self:updateResetCost()
    self:initAttrInfo()
    self:initSkillInfo()
end

function TongStudyMainView:initSkillInfo()
    self.skillItem_ = {}
    for k,v in ipairs(self.vitSkillCfg) do

        local skillItem = self.Panel_skill_item:clone()

        self.UIGridView_skill:pushBackCustomItem(skillItem)

        local icon          = TFDirector:getChildByPath(skillItem, "Image_skill_icon")
        local use_flag      = TFDirector:getChildByPath(skillItem, "Label_use_flag")
        local Image_lock    = TFDirector:getChildByPath(skillItem, "Image_lock")
        local select        = TFDirector:getChildByPath(skillItem, "Image_select")

        table.insert(self.skillItem_,{root = skillItem,icon = icon,use_flag = use_flag,Image_lock = Image_lock,select = select})

    end

    self:updateAllSkillInfo()
    self:selectEquipSlot(1)
end

function TongStudyMainView:updateSkillInfo()

    table.sort(self.vitSkillCfg,function(a,b)

        local isUnLockA = TongDataMgr:isUnLockSkill(a.id)
        isUnLockA = isUnLockA and 1 or 0
        local isUnLockB = TongDataMgr:isUnLockSkill(b.id)
        isUnLockB = isUnLockB and 1 or 0

        if isUnLockA == isUnLockB then
            return a.id < b.id
        else
            return isUnLockA > isUnLockB
        end


    end)

    for k,v in ipairs(self.skillItem_) do
        local data = self.vitSkillCfg[k]
        self:updateSkillItem(v,data,k)
    end

end

function TongStudyMainView:updateEquipSkill()

    for k,v in ipairs(self.equipSkill_) do
        v.select:setVisible(self.selectSlot == k)
        local buffid = TongDataMgr:getEquipedBufferCid(k)
        if buffid == 0 then
            v.icon:hide()
        else
            local skillCfg = TongDataMgr:getSkillCfgById(buffid)
            if skillCfg then
                v.icon:show()
                v.icon:setTexture(skillCfg.buffIcon)
            end
        end
    end

end

function TongStudyMainView:updateSkillItem(foo,cfg,index)

    foo.icon:setTexture(cfg.buffIcon)

    local isUsing = TongDataMgr:isEquip(cfg.id)
    foo.use_flag:setVisible(isUsing)

    local isUnLock = TongDataMgr:isUnLockSkill(cfg.id)
    foo.Image_lock:setVisible(not isUnLock)

    foo.select:setVisible(self.selectSkillIndex == index)
end

function TongStudyMainView:selectSkill(index,jump)

    local skillCfg = self.vitSkillCfg[index]
    if not skillCfg then
        return
    end

    for k,v in ipairs(self.skillItem_) do
        v.select:setVisible(index == k)
    end

    self.selectSkillIndex = index

    if not jump then
        return
    end
    Utils:openView("tong.TongEquipTipView",skillCfg.id,self.selectSlot)
end

function TongStudyMainView:selectEquipSlot(index)
    for k,v in ipairs(self.equipSkill_) do
        v.select:setVisible(index == k)
    end
    self.selectSlot = index

    local buffid = TongDataMgr:getEquipedBufferCid(index)
    if buffid == 0 then
        return
    end

    local skillIndex
    for k,v in ipairs(self.vitSkillCfg) do
        if v.id == buffid then
            skillIndex = k
            break
        end
    end

    if not skillIndex then
        return
    end
    self:selectSkill(skillIndex)

end

function TongStudyMainView:initAttrInfo()

    self.selectIndex = nil
    self.attrInfo_ = {}

    self.DelBtn = {}
    self.AddBtn = {}

    for k,v in ipairs(self.vitAttrCfg) do
        local item = self.Panel_attr_item:clone()
        self.UIListView_attr:pushBackCustomItem(item)

        local Label_name = TFDirector:getChildByPath(item, "Label_name")
        local Label_attr = TFDirector:getChildByPath(item, "Label_attr")
        Label_name:setTextById(v.stringId)
        local num = TongDataMgr:getAttrNum(v.id)
        Label_attr:setText(num)
        table.insert(self.attrInfo_,{root = item, name = Label_name, numTx = Label_attr, addNum = 0, cost = v.cost, id = v.id, num = num})

        local Button_del = TFDirector:getChildByPath(item, "Button_del")
        local Button_add = TFDirector:getChildByPath(item, "Button_add")
        self.DelBtn[k] = Button_del
        self.AddBtn[k] = Button_add

        self.totalCost = self.totalCost + num
    end

    self.Label_cost:setText(self.totalCost.."/"..self.ownPoint)

end

function TongStudyMainView:updateAttrInfo(isRest)
    self.totalCost = 0
    local isPlaySound = false
    for k,v in ipairs(self.attrInfo_) do
        local num = TongDataMgr:getAttrNum(v.id)
        if v.num ~= num then
            isPlaySound = true
        end
        v.numTx:setText(num)
        self.totalCost = self.totalCost + num
        v.num = num
        v.addNum = 0
    end
    self.Label_cost:setText(self.totalCost.."/"..self.ownPoint)

    if isPlaySound and not isRest then
        Utils:playSound(1004)
    end
end


function TongStudyMainView:onTouchButtonDown(index)
    self:updateAttrNum(index,-1)
end

function TongStudyMainView:onTouchButtonUp(index)
    self:updateAttrNum(index,1)
end

function TongStudyMainView:updateAttrNum(index,deltaNum)

    local attrInfo = self.attrInfo_[index]
    if not attrInfo then
        return
    end

    local totalAddNum = self:getTotalAddNum()
    local newTotalCost = totalAddNum + self.totalCost
    local isOverMax = newTotalCost >= self.ownPoint

    if isOverMax and deltaNum > 0 then
        return
    end

    attrInfo.addNum = math.max(attrInfo.addNum + deltaNum,0)

    if attrInfo.addNum > 0 then
        attrInfo.numTx:setText(attrInfo.num.." +"..attrInfo.addNum)
    else
        attrInfo.numTx:setText(attrInfo.num)
    end

    local totalAddNum = self:getTotalAddNum()
    local newTotalCost = totalAddNum + self.totalCost
    self.Label_cost:setText(newTotalCost.."/"..self.ownPoint)
end

function TongStudyMainView:getTotalAddNum()

    local addNum = 0
    for k,v in ipairs(self.attrInfo_) do
        addNum = addNum + v.addNum * v.cost
    end
    return addNum
end


function TongStudyMainView:holdDownAction(isAddOp,index)
    local speedTiming = 0
    local timing = 0
    local needTime = 0
    local entryFalg = false

    local function action(dt)
        if not self.timer or not self.onTouchButtonUp then
            return
        end
        timing = timing + dt
        speedTiming = speedTiming + dt
        if speedTiming >= 3.0 then
            entryFalg = true
            needTime = 0.01
        elseif speedTiming > 0.5 then
            entryFalg = true
            needTime = 0.05
        end
        if entryFalg and timing >= needTime then
            if isAddOp then
                self:onTouchButtonUp(index)
            else
                self:onTouchButtonDown(index)
            end
            timing = 0
        end
    end
    self:stopTimer()
    self.timer = TFDirector:addTimer(0, -1, nil, action)
end

function TongStudyMainView:stopTimer()
    if self.timer then
        TFDirector:removeTimer(self.timer)
        self.timer = nil;
    end
end

function TongStudyMainView:onHide()
    self:stopTimer()
    self.super.onHide(self)
end

function TongStudyMainView:removeUI()
    self.super.removeUI(self)
end

function TongStudyMainView:onShow()

end

function TongStudyMainView:onClose()
    self:stopTimer()
    self.super.onClose(self)
end

function TongStudyMainView:updateAllSkillInfo()
    self:updateSkillInfo()
    self:updateEquipSkill()
end

function TongStudyMainView:isSaveAttr()

    local isSave = true
    for k,v in ipairs(self.attrInfo_) do
        if v.addNum ~= 0 then
            isSave = false
            break
        end
    end

    return isSave
end

function TongStudyMainView:unLockSkillTip(unLockSkills)
    dump(unLockSkills)
    if #unLockSkills <= 0 then
        return
    end

    Utils:openView("tong.TongAttrDetailView",unLockSkills)

    self:updateAllSkillInfo()
end

function TongStudyMainView:updateResetCost()
    if self.resetCost then
        local id,num = self.resetCost[1],self.resetCost[2]
        if id and num then
            local cfg = GoodsDataMgr:getItemCfg(id)
            if cfg then
                self.Image_reset_icon:setTexture(cfg.icon)
                local ownCnt = GoodsDataMgr:getItemCount(id)
                self.Label_reset_cost:setText(ownCnt .. "/"..num)
            end
        end
    end

    self.ownPoint = GoodsDataMgr:getItemCount(self.attrItemId)
    local cfg = GoodsDataMgr:getItemCfg(self.attrItemId)
    if cfg then
        self.Image_cost_icon:setTexture(cfg.icon)
    end
end

function TongStudyMainView:resetStudy(unLockSkills)

    if next(unLockSkills) then
        Utils:openView("tong.TongAttrDetailView",unLockSkills,true)
    end

    self:updateAllSkillInfo()
    self:updateAttrInfo(true)
end

function TongStudyMainView:registerEvents()

    EventMgr:addEventListener(self, EV_BAG_ITEM_UPDATE, handler(self.updateResetCost, self))
    EventMgr:addEventListener(self, EV_TONG.UnLockSkill, handler(self.unLockSkillTip, self))
    EventMgr:addEventListener(self, EV_TONG.AfterEquip, handler(self.updateAllSkillInfo, self))
    EventMgr:addEventListener(self, EV_TONG.SaveAttr, handler(self.updateAttrInfo, self))
    EventMgr:addEventListener(self, EV_TONG.ResetStudy, handler(self.resetStudy, self))


    self.Button_close:onClick(function ()
        AlertManager:closeLayer(self)
    end)


    for k,v in ipairs(self.AddBtn) do
        v:onTouch(function(event)
            if event.name == "began" then
                TFAudio.playSound(Utils:getKVP(1001,"ui_clickSound"))
                self:holdDownAction(true,k)
                self:onTouchButtonUp(k)
            elseif event.name == "ended" then
                self:stopTimer()
            end
        end)
    end

    for k,v in ipairs(self.DelBtn) do
        v:onTouch(function(event)
            if event.name == "began" then
                TFAudio.playSound(Utils:getKVP(1001,"ui_clickSound"))
                self:holdDownAction(false,k)
                self:onTouchButtonDown(k)
            elseif event.name == "ended" then
                self:stopTimer()
            end
        end)
    end

    self.Button_reset:onClick(function()

        if not self.resetCost then
            return
        end

        local id,num = self.resetCost[1],self.resetCost[2]
        local ownCnt = GoodsDataMgr:getItemCount(id)

        if ownCnt < num then
            Utils:showTips(13210018)
            return
        end


        local content = TextDataMgr:getText(13206076)

        local args = {
            tittle = 2107025,
            content = content,
            reType = EC_OneLoginStatusType.ReConfirm_ResetPoint,
            opacity = 255 * 0.45,
            confirmCall = function()
                TongDataMgr:Send_resetAttr()
            end,
        }
        Utils:openView("tong.TongAddNumConfirmView",args)
    end)

    for k,v in ipairs(self.skillItem_) do
        v.root:onClick(function()
            self:selectSkill(k,true)
        end)
    end

    for k,v in ipairs(self.equipSkill_) do
        v.root:onClick(function()
            self:selectEquipSlot(k)
        end)
    end

    self:setBackBtnCallback(function()
        local isSave = self:isSaveAttr()
        if not isSave then
            local args = {
                tittle = 2107025,
                content = TextDataMgr:getText(13206077),
                reType = false,
                opacity = 255 * 0.45,
                confirmCall = function()
                    AlertManager:closeLayer(self)
                end,
            }
            Utils:openView("tong.TongAddNumConfirmView",args)
        else
            AlertManager:closeLayer(self)
        end
    end)


    self.Button_confirmAttr:onClick(function()

        local info = {}
        for k,v in ipairs(self.attrInfo_) do
            local num = v.addNum
            table.insert(info,{v.id,num})
        end
        dump(info)
        TongDataMgr:Send_saveAttr(info)
    end)

    self.Image_reset_icon:onClick(function()
        if not self.resetCost then
            return
        end
        local id = self.resetCost[1]
        if not id then
            return
        end
        Utils:showInfo(id)
    end)

    self.Image_cost_icon:onClick(function()
        Utils:showInfo(self.attrItemId)
    end)
end

return TongStudyMainView
