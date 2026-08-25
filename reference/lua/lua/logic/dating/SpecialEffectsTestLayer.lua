local SpecialEffectsTestLayer = class("SpecialEffectsTestLayer",BaseLayer)
require("lua.logic.dating.DatingPublic")

local specialCgFileConfig = {
    cg001 = "scene/cg/main_cg_1.png",
    date_cg_2 = "scene/cg/date_cg_3.png",
    date_cg_3 = "scene/cg/date_cg_2.png",
    date_cg_4 = "scene/cg/date_cg_4.png",
    date_cg_69 = "scene/cg/main_cg_3.png",
    date_cg_76 = "scene/cg/main_cg_4.png",
    date_cg_91 = "scene/cg/main_cg_6.png",
    date_cg_92 = "scene/cg/main_cg_6.png",
    date_cg_93 = "scene/cg/main_cg_5.png",
    bg_chaoshi = "scene/bg/bg_chaoshi.png",
    bg_gongyuan = "scene/bg/bg_gongyuan.png",
    bg_parkyewan = "scene/bg/bg_parkyewan.png",
    bg_huadian1 = "scene/bg/bg_huadian1.png",
    bg_huadianyewan = "scene/bg/bg_huadianyewan.png",
    bg_meishijie = "scene/bg/bg_meishijie.png",
    bg_mianbaodian = "scene/bg/bg_mianbaodian.png",
    bg_mianbaodian = "scene/bg/bg_mianbaodian.png",
    bg_shatan_day2 = "scene/bg/bg_shatan_day2.png",
    bg_shensheyewan = "scene/bg/bg_shensheyewan.png",
    bg_shipindian = "scene/bg/bg_shipindian.png",
    bg_tushuguanyewan = "scene/bg/bg_tushuguanyewan.png",
    bg_wanoudian1 = "scene/bg/bg_wanoudian1.png",
    bg_wanoudian2 = "scene/bg/bg_wanoudian2.png",
    bg_youleyuan2 = "scene/bg/bg_youleyuan2.png",

}

function SpecialEffectsTestLayer:ctor(isLast)
    self.super.ctor(self,isLast)

    self.chooseImages = {}
    self.chooseStates = {}
    self.cgFilePathList = {}
    self.cgList = {}
    self.cgFindList = {}
    self.cgFileNameList = {}
    self.cgFindFileNamelList = {}
    self.bgList = {}
    self.bgFileNameList = {}
    self.bgFindFileNamelList = {}
    self.npcs = {}
    self.lastTest = isLast
    self.saveData = {}

    self.curFromData = {}
    self.curAfterId = 1
    self:init("lua.uiconfig.dating.specialEffectsTestLayer")
end

function SpecialEffectsTestLayer:initUI(ui)
    self.super.initUI(self,ui)

    self.ui = ui

    self.Panel_base = TFDirector:getChildByPath(ui, "Panel_base")

    self.closeBtn = TFDirector:getChildByPath(ui, 'Button_back');
    self.closeBtn:onClick(audioClickfun(self.closeBtnClickHandle,nil,self),false)
    self.closeBtn:setZOrder(1000)

    self.Label_count = TFDirector:getChildByPath(ui, "Label_count")
    self.Label_count:setText("当前列表总数：0")

    TFDirector:getChildByPath(ui, "Label_sTitle"):setVisible(not self.lastTest)
    self.Label_tager = TFDirector:getChildByPath(ui, "Label_tager")
    self.Label_tager:setVisible(not self.lastTest)
    self.Label_tager:setText("点击任意图片可切换设置对象")

    self:testTool()
    self:initBg()
    self:initElvesNpc()
    self:findAllImageList()
    self:findAllBgList()
    self:findCgFilePathList()
    self:initTableView()
    self:bindTableViewEvent()
    self:onTouchBg()
    self:initCgItemList()
end


function SpecialEffectsTestLayer:initCgItemList()
    self.Panel_cgItem = TFDirector:getChildByPath(self.ui, "Panel_cgItem")
    self.Panel_cgList = TFDirector:getChildByPath(self.ui, "Panel_cgList"):hide()
    local ScrollView_cg = TFDirector:getChildByPath(self.Panel_cgList, "ScrollView_cg")
    local ScrollView_cgFind = TFDirector:getChildByPath(self.Panel_cgList, "ScrollView_cgFind")
    self.cGgridView = UIGridView:create(ScrollView_cg)
    self.cGgridView:setItemModel(self.Panel_cgItem)
    self.cGgridView:setColumn(2)
    self.cGgridView:setColumnMargin(15)
    self.cGgridView:setRowMargin(10)

    self.findCGgridView = UIGridView:create(ScrollView_cgFind)
    self.findCGgridView:setItemModel(self.Panel_cgItem)
    self.findCGgridView:setColumn(2)
    self.findCGgridView:setColumnMargin(15)
    self.findCGgridView:setRowMargin(10)

    self.findCGgridView:setVisible(false)
end

function SpecialEffectsTestLayer:showCgListHandle()
    self:showCgItemList()
end

function SpecialEffectsTestLayer:hideCgListHandle()
    self:hideCgItemList()
end

function SpecialEffectsTestLayer:hideCgItemList()
    self.Panel_cgList:hide()
    self.cGgridView:setVisible(true)
    self.findCGgridView:setVisible(false)
    self.cGgridView:removeAllItems()
    self.findCGgridView:removeAllItems()
    self.cgList = {}
    self.bgList = {}
    self.cgFindList = {}
    self.bgFindList = {}
    local TextButton_cgFind = TFDirector:getChildByPath(self.ui, "TextButton_cgFind"):show()
    local TextField_cgFileName = TFDirector:getChildByPath(self.ui, "TextField_cgFileName"):show()
    local Button_backCgList = TFDirector:getChildByPath(self.ui, "Button_backCgList"):hide()
    TextField_cgFileName:setText("")
end

function SpecialEffectsTestLayer:showFindCgItemList()
    if self.isFindCg then
        self.findCGgridView:removeAllItems()
        self.cgFindList = {}
        for i, v in ipairs(self.cgFindFileNamelList) do
            local cgItem = self.Panel_cgItem:clone()
            cgItem.id = v.id
            self:initItem(cgItem,v.id)
            self:updateItem(cgItem)
            self.findCGgridView:pushBackCustomItem(cgItem)
            table.insert(self.cgFindList,cgItem)
        end

        for i, v in ipairs(self.cgFindList) do
            local cgItem = v
            cgItem:Touchable(true)
            cgItem:onClick(function()
                local cgName = specialCgFileConfig[self.cgFileNameList[cgItem.id]]
                local cgView = require("lua.logic.common.CgView"):new(self.cgFileNameList[cgItem.id], cgName, true, function()

                end,true)
                self:addLayerToNode(cgView,self.Panel_base);
                cgView:setZOrder(99999)
                local ws = GameConfig.WS
                cgView:PosX((1136-ws.width)/2)
            end)
        end
        self.Label_count:setText("当前列表总数：" .. #self.cgFindList)
    end

end

function SpecialEffectsTestLayer:showFindBgItemList()
    if self.isFindBg then
        self.findCGgridView:removeAllItems()
        self.bgFindList = {}
        for i, v in ipairs(self.bgFindFileNamelList) do
            local bgItem = self.Panel_cgItem:clone()
            bgItem.name = v.name

            self:initItem(bgItem,v.id)
            self:updateItem(bgItem)
            self.findCGgridView:pushBackCustomItem(bgItem)
            table.insert(self.bgFindList,bgItem)
        end

        for i, v in ipairs(self.bgFindList) do
            local bgItem = v
            bgItem:Touchable(true)
            bgItem:onClick(function()
                Utils:showTips("更换背景成功")
                local textureName = string.format("scene/cg/%s",bgItem.name)
                if not file_exists(textureName) then
                    textureName = string.format("scene/bg/%s",bgItem.name)
                end
                self.imageBg.textureName = textureName
                self.imageBg.name = bgItem.name
                self.imageBg:setTexture(textureName)
                if not self.lastTest then
                    self.currentNode = self.imageBg
                    self.Label_tager:setText(self.imageBg.name)
                end
                self:hideCgItemList()
            end)
        end
        self.Label_count:setText("当前列表总数：" .. #self.bgFindList)
    end

end

function SpecialEffectsTestLayer:showCgItemList()
    self.Panel_cgList:show()
    self.cGgridView:removeAllItems()
    self.cgList = {}

    for i,v in ipairs(self.cgFileNameList) do
        local cgItem = self.Panel_cgItem:clone()

        self:initItem(cgItem,i)
        self:updateItem(cgItem)
        self.cGgridView:pushBackCustomItem(cgItem)
        table.insert(self.cgList,cgItem)
    end

    local Panel_cgView = TFDirector:getChildByPath(self.ui, "Panel_cgView")

    for i, v in ipairs(self.cgList) do
        local cgItem = v
        cgItem:Touchable(true)
        cgItem:onClick(function()
            local cgName = specialCgFileConfig[self.cgFileNameList[i]]
            print("specialCgFileConfig ",specialCgFileConfig)
            print("self.cgFileNameList[i] ",self.cgFileNameList[i])
            local cgView = require("lua.logic.common.CgView"):new(self.cgFileNameList[i], cgName, true, function()

            end,true)
            self:addLayerToNode(cgView,self.Panel_base);
            cgView:setZOrder(99999)
            local ws = GameConfig.WS
            cgView:PosX((1136-ws.width)/2)
        end)
    end

    self.Label_count:setText("当前列表总数：" .. #self.cgList)
end

function SpecialEffectsTestLayer:showBgItemList()
    self.Panel_cgList:show()
    self.cGgridView:removeAllItems()
    self.bgList = {}

    for i,v in ipairs(self.bgFileNameList) do
        local bgItem = self.Panel_cgItem:clone()
        local tablePath = string.split(v, "\\")
        bgItem.name = tablePath[table.count(tablePath)]
        bgItem.path = v

        self:initItem(bgItem,i)
        self:updateItem(bgItem)
        self.cGgridView:pushBackCustomItem(bgItem)
        table.insert(self.bgList,bgItem)
    end
    for i, v in ipairs(self.bgList) do
        local bgItem = v
        bgItem:Touchable(true)
        bgItem:onClick(function()
            Utils:showTips("更换背景成功")
            local textureName = string.format("scene/cg/%s",bgItem.name)
            if not file_exists(textureName) then
                textureName = string.format("scene/bg/%s",bgItem.name)
            end
            self.imageBg.textureName = textureName
            self.imageBg.name = bgItem.name
            self.imageBg:setTexture(textureName)
            if not self.lastTest then
                self.currentNode = self.imageBg
                self.Label_tager:setText(self.imageBg.name)
            end
            self:hideCgItemList()
        end)
    end

    self.Label_count:setText("当前列表总数：" .. #self.bgList)
end

function SpecialEffectsTestLayer:initItem(item,idx)
    local Label_name = TFDirector:getChildByPath(item, "Label_name")
    if item.name then
        Label_name:setText(item.name)
    else
        Label_name:setText(self.cgFileNameList[idx])
    end
    local Label_des = TFDirector:getChildByPath(item, "Label_des")
    Label_des:setText(tostring(idx))
end

function SpecialEffectsTestLayer:updateItem(item)

end

--cg bg
function SpecialEffectsTestLayer:initBg()
    self.imageBg = TFDirector:getChildByPath(self.ui,"Image_bg")
    self.imageBg.lock = true
    local textureName = "scene/cg/date_cg_2.png"
    self.imageBg.textureName = textureName
    self.imageBg.name = "date_cg_2.png"
    self.imageBg:setTexture(textureName)
end

--cg npc
function SpecialEffectsTestLayer:initElvesNpc()
    self.imageNpc = TFDirector:getChildByPath(self.ui,"Image_npc")
    self.imageNpc:hide()
end

function SpecialEffectsTestLayer:saveOriginal(image)
    image.savePos = image:getPosition()
    image.saveScale = image:getScale()
    image.saveOpacity = image:getOpacity()
end

function SpecialEffectsTestLayer:restate(image)
    if image.savePos == nil then
        return
    end
    image:setPosition(image.savePos)
    image:setScale(image.saveScale)
    image:setOpacity(image.saveOpacity)
end

function SpecialEffectsTestLayer:closeBtnClickHandle(btn)

    local fileName = self.TextField_file:getString()
    local str = ""

    if fileName == "" then
        str = "fileName is nil"
    elseif not self.saveData.time then
        str = "time is nil 你需要播放一次cg保存time"
    end

    if str == "" then
        local str = "是否保存" .. fileName .. "文件！"
        showMessageBox(str , EC_MessageBoxType.okAndCancel,function()

            self:saveDatas()
            AlertManager:close()
            AlertManager:closeLayer(self)
        end,
                function()
                    AlertManager:close()
                    AlertManager:closeLayer(self)
        end)
    else
        str = str .. " 确定退出！"
        showMessageBox(str , EC_MessageBoxType.okAndCancel,function()
            AlertManager:close()
            AlertManager:closeLayer(self)
        end,
        function()
            AlertManager:close()
        end)
    end
end

-- 每次c++调用onEnter之后调用
function SpecialEffectsTestLayer:onEnter()
    self.super.onEnter(self)
end

-- 每次c++调用onExit之后调用
function SpecialEffectsTestLayer:onClose()
    self.super.onClose(self)
    TFDirector:removeTimer(self.timerID_)
end

-- 每次AlertManager:show()之后调用；子弹窗关闭时调用；断线重连时调用
function SpecialEffectsTestLayer:onShow()
    self.super.onShow(self)
    self:refreshTable()
end

function SpecialEffectsTestLayer:saveDatas()
    local fileName = self.TextField_file:getString()
    local filePath = me.FileUtils:fullPathForFilename("cgAnimation")
    local str = string.format("%s/%s.lua", filePath,fileName)
    if fileName == "" then
        return false
    elseif not self.saveData.time then
        return false
    end
    local data = clone(self.saveData)
    table.save(data,str)
    Utils:showTips("成功保存%s文件",fileName)
    return true
end

function SpecialEffectsTestLayer:getDatas(fileName)
    --print "-----------测试读取"
    local filePath = "res.basic.cgAnimation"
    local str = string.format("%s.%s", filePath,fileName)
    --print("str " .. str)
    self.saveData = table.load(str)
    dump(self.saveData)
end


function SpecialEffectsTestLayer:testTool()

    self.Panel_controls = TFDirector:getChildByPath(self.ui, 'Panel_controls')
    self.Panel_controls:setZOrder(200)
    self.Panel_playControls = TFDirector:getChildByPath(self.ui, 'Panel_playControls')
    self.Panel_playControls:setZOrder(2000)

    self.Panel_timeItem = TFDirector:getChildByPath(self.ui, "Panel_timeItem")
    self.TextButton_time = TFDirector:getChildByPath(self.ui, "TextButton_time")
    self.TextButton_time:hide()
    self.TextButton_time:onClick(handler(self.timeBtnClickHandle,self))

    self.TextButton_scale = TFDirector:getChildByPath(self.ui, 'TextButton_scale')
    self.TextButton_scale:onClick(audioClickfun(self.scaleBtnClickHandle,nil,self),false)
    self.TextButton_start = TFDirector:getChildByPath(self.ui, 'TextButton_start')
    self.TextButton_start:onClick(audioClickfun(self.startBtnClickHandle,nil,self),false)
    self.TextButton_end = TFDirector:getChildByPath(self.ui, 'TextButton_end')
    self.TextButton_end:onClick(audioClickfun(self.endBtnClickHandle,nil,self),false)
    self.TextButton_end:hide()
    self.TextButton_play = TFDirector:getChildByPath(self.ui, 'TextButton_play')
    self.TextButton_play:onClick(audioClickfun(self.playBtnClickHandle,nil,self),false)
    self.TextButton_play:hide()
    self.TextButton_save = TFDirector:getChildByPath(self.ui, 'TextButton_save')
    self.TextButton_save:onClick(audioClickfun(self.saveBtnClickHandle,nil,self),false)
    self.TextButton_save:hide()
    self.TextButton_record = TFDirector:getChildByPath(self.ui, "TextButton_record")
    self.TextButton_record:onClick(handler(self.recordBtnClickHandle,self))
    self.TextButton_record.num = 1
    --self.TextButton_record:setTextById(100000034,self.TextButton_record.num)
    self.TextButton_record:setText("记录"..self.TextButton_record.num)
    self.TextButton_record:hide()
    self.TextButton_pos = TFDirector:getChildByPath(self.ui, 'TextButton_pos')
    self.TextButton_pos:onClick(audioClickfun(self.posBtnClickHandle,nil,self),false)
    self.TextButton_suoDing = TFDirector:getChildByPath(self.ui, "TextButton_suoDing")
    self.TextButton_suoDing:onClick(audioClickfun(self.suoDingBtnClickHandle,nil,self),false)
    self.TextButton_suoDing:hide()
    self.TextButton_jieSuo = TFDirector:getChildByPath(self.ui, "TextButton_jieSuo")
    self.TextButton_jieSuo:setVisible(self.lastTest)
    self.TextButton_jieSuo:onClick(audioClickfun(self.jieSuoBtnClickHandle,nil,self),false)
    self.TextButton_bg = TFDirector:getChildByPath(self.ui, "TextButton_bg")
    self.TextButton_bg:onClick(audioClickfun(self.bgBtnClickHandle,nil,self),false)
    self.TextButton_screenShake = TFDirector:getChildByPath(self.ui, "TextButton_screenShake")
    self.TextButton_screenShake:hide()
    self.TextButton_screenShake:onClick(handler(self.screenShakeBtnClickHandle,self))

    self.Button_cgList = TFDirector:getChildByPath(self.ui, "Button_cgList")
    self.Button_cgList:onClick(handler(self.showCgListHandle,self))
    self.Button_cgClose = TFDirector:getChildByPath(self.ui, "Button_cgClose")
    self.Button_cgClose:onClick(handler(self.hideCgListHandle,self))

    self.TextField_scale = TFDirector:getChildByPath(self.ui, 'TextField_scale')
    self.TextField_file = TFDirector:getChildByPath(self.ui, 'TextField_file')
    self.TextField_file:hide()
    self.TextField_posX = TFDirector:getChildByPath(self.ui, 'TextField_posX')
    self.TextField_posY = TFDirector:getChildByPath(self.ui, 'TextField_posY')
    self.TextField_time = TFDirector:getChildByPath(self.ui, 'TextField_time')
    self.TextField_time:hide()
    self.TextField_cgFileName = TFDirector:getChildByPath(self.ui, 'TextField_cgFileName')

    self.TextButton_selectBg = TFDirector:getChildByPath(self.ui, "TextButton_selectBg")
    self.TextButton_selectBg:onClick(function() self:showBgItemList() end)
end

function SpecialEffectsTestLayer:timeBtnClickHandle(btn)

    local disTime = 0.03
    if btn.isClick == true then
        for i,v in ipairs(self.timeList) do
            v:timeOut(function() v:fadeOut(disTime) end,disTime*(#self.timeList - i))
        end
        btn.isClick = nil
        return
    else
        btn.isClick = true
    end

    if self.timeList == nil then
        self.timeList = {}
        local size = self.Panel_timeItem:Size()
        local disY = btn:Size().height + 10
        for i,v in ipairs(self.saveData.toData) do
            local panelTime = self.Panel_timeItem:clone()
            local Label_timeId = TFDirector:getChildByPath(panelTime,"Label_timeId")
            Label_timeId:setString(tostring(i))
            local TextField_time = TFDirector:getChildByPath(panelTime,"TextField_time")
            TextField_time:setString(tostring(1))
            panelTime:AddTo(btn:getParent(),10)
            panelTime:Pos(btn:Pos().x,btn:Pos().y + disY)
            disY = disY + size.height + 10
            table.insert(self.timeList,panelTime)
            panelTime:Alpha(0)
        end
    end

    for i,v in ipairs(self.timeList) do
        v:timeOut(function() v:fadeIn(disTime) end,disTime*i)
    end
end

function SpecialEffectsTestLayer:screenShakeBtnClickHandle(btn)
    -- btn:setTouchEnabled(false)
    -- btn:setGrayEnabled(false)
    btn:hide()
    self.saveData.screenShake = true
end

function SpecialEffectsTestLayer:bgBtnClickHandle(btn)
    local textureName = self.TextField_cgFileName:getString()
    if textureName == "" then
        toastMessage("textureName is nil")
        return
    end
    textureName = string.format("scene/cg/%s.png",textureName)
    self.imageBg.textureName = textureName
    self.imageBg:setTexture(textureName)

    self.TextField_cgFileName:setString("")
end

function SpecialEffectsTestLayer:saveBtnClickHandle(btn)
    if self.TextField_file:getString() == "" then
        toastMessage("TextField_file is nil")
        return
    end
    if true then
        self.TextButton_save:hide()
        self.TextButton_play:show()
        self.Panel_controls:hide()
        for i,v in ipairs(self.npcs) do
            local npc = v
            npc:hide()
        end
        self.panel_down:hide()
        self.panel_left:hide()
        -- self.TextField_time:show()
        self.TextField_file:hide()
        self.TextButton_time:show()
    end
end

function SpecialEffectsTestLayer:suoDingBtnClickHandle(btn)
    self.TextButton_suoDing:hide()
    self.TextButton_jieSuo:show()
    self.imageBg:setTouchEnabled(false)
    self.imageBg.lock = true
end

function SpecialEffectsTestLayer:jieSuoBtnClickHandle(btn)
    self.TextButton_suoDing:show()
    self.TextButton_jieSuo:hide()
    self.imageBg.lock = false
    self.imageBg:setTouchEnabled(true)
    if self.currentNode then
        self.currentNode.color = nil
        self.tableViewDown:reloadData()
        self.currentNode = nil
    end
end

function SpecialEffectsTestLayer:posBtnClickHandle(btn)
    --print("TextField_posX value: " .. self.TextField_posX:getString())
    --print("TextField_posY value: " .. self.TextField_posY:getString())
    local textX = self.TextField_posX:getString()
    local textY = self.TextField_posY:getString()
    if string.isNullOrEmpty(textX) or string.isNullOrEmpty(textY) then 
        toastMessage("position can not be null")
        return 
    end
    local x = tonumber(textX)
    local y = tonumber(textY)
    if self.currentNode then
        self.currentNode:setPosition(ccp(x,y))
    elseif self.imageBg.lock == false then
        self.imageBg:setPosition(ccp(x,y))
    else
        toastMessage("currentNode and imageBg is nil")
        return
    end
    -- self.TextField_posX:setString("")
    -- self.TextField_posY:setString("")
end

function SpecialEffectsTestLayer:scaleBtnClickHandle(btn)
    --print("TextField_scale value: " .. self.TextField_scale:getString())
    local textScale = self.TextField_scale:getString()
    if string.isNullOrEmpty(textScale)  then 
        toastMessage("scale can not be null")
        return 
    end
    local scale = tonumber(textScale)
    if self.currentNode then
        self.currentNode:setScale(scale)
    elseif self.imageBg.lock == false then
        self.imageBg:setScale(scale)
    end

    --self.TextField_scale:setString("")
end

function SpecialEffectsTestLayer:startBtnClickHandle(btn)
    self.saveData.fromData = {}
    self.saveData.fromData.imageBgInfo = {["pos"] = self.imageBg:getPosition(), ["scale"] = self.imageBg:getScale(), ["opacity"] = 255}
    self.saveData.fromData.imageNpcsInfo = {}
    for i,v in ipairs(self.npcs) do
        local imageNpcInfo = {}
        local npc = v
        imageNpcInfo.filePath = self.chooseImages[npc.npcNameIndex]
        imageNpcInfo.status = {["pos"] = npc:getPosition(), ["scale"] = npc:getScale(), ["opacity"] = 255}
        table.insert(self.saveData.fromData.imageNpcsInfo,imageNpcInfo)
    end
    dump(self.saveData)
    self:saveOriginal(self.imageBg)
    self:saveOriginal(self.imageNpc)

    self.TextButton_start:hide()
    self.TextButton_end:show()
    self.TextButton_record:show()
end

function SpecialEffectsTestLayer:recordBtnClickHandle(btn)
    -- toastMessage(string.format("成功记录结束点%d",self.TextButton_record.num))
    Utils:showTips(100000035, self.TextButton_record.num)

    self.TextButton_record.num = self.TextButton_record.num + 1
    --self.TextButton_record:setTextById(100000034,self.TextButton_record.num)
    self.TextButton_record:setText("记录"..self.TextButton_record.num)

    if self.saveData.toData == nil then
        self.saveData.toData = {}
    end
    local afterData = {}
    afterData.imageBgInfo = {["pos"] = self.imageBg:getPosition(), ["scale"] = self.imageBg:getScale(), ["opacity"] = 255}
    afterData.imageNpcsInfo = {}
    for i,v in ipairs(self.npcs) do
        local imageNpcInfo = {}
        local npc = v
        imageNpcInfo.filePath = self.chooseImages[npc.npcNameIndex]
        imageNpcInfo.status = {["pos"] = npc:getPosition(), ["scale"] = npc:getScale(), ["opacity"] = 255}
        table.insert(afterData.imageNpcsInfo,imageNpcInfo)
    end

    table.insert(self.saveData.toData,afterData)
end

function SpecialEffectsTestLayer:endBtnClickHandle(btn)

    if self.saveData.toData == nil then
        -- toastMessage("没有记录任何结束点")
        Utils:showTips(100000036)
        return
    end

    self.TextButton_end:hide()
    self.TextButton_record:hide()
    self.TextButton_save:show()
    self.TextField_file:show()

    --print("self.saveData.toData")
    dump(self.saveData.toData)
end

function SpecialEffectsTestLayer:playBtnClickHandle(btn)
    local str = self.TextField_file:getString()

    self.saveData.time = {}

    if self.timeList and #self.timeList then
        for i,v in ipairs(self.timeList) do
            local textFiledTime = TFDirector:getChildByPath(v,"TextField_time")
            table.insert(self.saveData.time,tonumber(textFiledTime:getString()) or 1)
        end
    else
        for i,v in ipairs(self.saveData.toData) do
            table.insert(self.saveData.time,1)
        end
    end

    self.TextField_time:setString("")
    if #self.saveData.time == 0 then
        toastMessage("time is nil")
        return
    end

    self:playCg()
end

function SpecialEffectsTestLayer:playCg()
    self.curAfterId = 1
    self:free()
    self:startTimer()
end

function SpecialEffectsTestLayer:startTimer()
    if self.saveData.toData == nil or self.saveData.fromData == nil then
        return
    end

    self:bindImageAnimationInfos()
    print("startTimer")
end

function SpecialEffectsTestLayer:bindImageAnimationInfos()

    if self.curAfterId > table.count(self.saveData.time) then
        return
    end

    local time = self.saveData.time[self.curAfterId]
    --print("********bindImageAnimationInfos********")

    if self.curAfterId ~= 1 then
        self.curFromBgData = self.saveData.toData[self.curAfterId-1].imageBgInfo
        self.curFromNpcsData = self.saveData.toData[self.curAfterId-1].imageNpcsInfo
    else
        self.curFromBgData = self.saveData.fromData.imageBgInfo
        self.curFromNpcsData = self.saveData.fromData.imageNpcsInfo
    end
    self.imageBg.imageFromData = self.curFromBgData
    self.imageBg.imageToData = self.saveData.toData[self.curAfterId].imageBgInfo
    self.curToNpcsData = self.saveData.toData[self.curAfterId].imageNpcsInfo

    if self.playImageNpcs then
        for i,v in ipairs(self.curFromNpcsData) do
            local imageNpcInfo = v
            local data = imageNpcInfo.status
            self.playImageNpcs[i].imageFromData = data
        end
    else
        self.playImageNpcs = {}
        for i,v in ipairs(self.curFromNpcsData) do
            local imageNpcInfo = v
            local filePath = imageNpcInfo.filePath
            local data = imageNpcInfo.status
            local imageNpc = TFImage:create(filePath)
            imageNpc.filePath = filePath
            imageNpc.imageFromData = data
            -- local info = {}
            -- info.pos = data.pos
            -- info.scale = data.scale
            -- info.opacity = data.opacity
            -- self:defaultStatus(imageNpc,info)

            self.Panel_base:addChild(imageNpc,500)
            table.insert(self.playImageNpcs,imageNpc)
        end
    end

    for i,v in ipairs(self.curToNpcsData) do
        local imageNpcInfo = v
        local imageNpc = nil
        local filePath = imageNpcInfo.filePath
        for i,v in ipairs(self.playImageNpcs) do
            if filePath == v.filePath then
                imageNpc = v
            end
        end
        local data = imageNpcInfo.status
        imageNpc.imageToData = data
    end

    self:bindImageAnimationInfo(self.imageBg,time)
    for i,v in ipairs(self.playImageNpcs) do
        local imageNpc = v
        self:bindImageAnimationInfo(imageNpc,time)
    end

    local aniArr = {}
    table.insert(aniArr,DelayTime:create(time))
    local function acFun()
        self.curAfterId = self.curAfterId + 1
        self:bindImageAnimationInfos()
    end
    table.insert(aniArr,CallFunc:create(acFun))

    self:runAction(CCSequence:createWithTable(aniArr))
end
function SpecialEffectsTestLayer:bindImageAnimationInfo(image,time)
    local imageFromData = image.imageFromData
    local imageToData = image.imageToData

    local fromPos = imageFromData.pos
    local toPos = imageToData.pos
    local fromScale = imageFromData.scale
    local toScale = imageToData.scale
    local fromOpacity = imageFromData.opacity
    local toOpacity= imageToData.opacity

    local disx =  toPos.x - fromPos.x
    local disy = toPos.y - fromPos.y
    image.uDisx = disx / time
    image.uDisy = disy / time
    image.uScale = (toScale - fromScale)/time
    image.uOpacity = (toOpacity- fromOpacity)/time

    local info = {}
    info.pos = fromPos
    info.scale = fromScale
    info.opacity = fromOpacity
    self:defaultStatus(image,info)

    local spawnAc = {
        MoveTo:create(time,toPos),
        ScaleTo:create(time,toScale),
        FadeTo:create(time, toOpacity)
    }
    local aniArr = {}
    table.insert(aniArr,CCSpawn:create(spawnAc))
    if self.saveData.screenShake then
        local screenShakeAc = self:screenShakeSeq(5,20,10)
        table.insert(aniArr,screenShakeAc)
    end

    image:runAction(CCSequence:createWithTable(aniArr))

end

function SpecialEffectsTestLayer:screenShakeSeq(offsetMin, offsetMax, count)
    local aniArr = {}
    for i = 1, count do
        local x = math.random(offsetMin, offsetMax)
        local y = math.random(offsetMin, offsetMax)
        table.insert(aniArr, CCMoveBy:create(0.05, ccp(x, y)))
        table.insert(aniArr, CCMoveBy:create(0.05, ccp(-x, -y)))
    end
    local seq = CCSequence:createWithTable(aniArr)
    return seq
end

function SpecialEffectsTestLayer:removeTimer()
    if self.timerID_ then
        TFDirector:removeTimer(self.timerID_)
        self.timerID_ = nil
    end
end

function SpecialEffectsTestLayer:update(delta)
    self.imageBg:setPosition(self.imageBg:getPosition()+ccp(self.imageBg.uDisx,self.imageBg.uDisy))
    self.imageBg:setScale(self.imageBg:getScale() + self.imageBg.uScale)
    self.imageBg:setOpacity(self.imageBg:getOpacity() + self.imageBg.uOpacity)
    for i,v in ipairs(self.playImageNpcs) do
        local imageNpc = v
        imageNpc:setPosition(imageNpc:getPosition()+ccp(imageNpc.uDisx,imageNpc.uDisy))
        imageNpc:setScale(imageNpc:getScale() + imageNpc.uScale)
        imageNpc:setOpacity(imageNpc:getOpacity() + imageNpc.uOpacity)
    end
end

function SpecialEffectsTestLayer:free()
    self:removeTimer()
    self.imageBg:stopAllActions()
    if self.playImageNpcs == nil then
        return
    end
    for i,v in ipairs(self.playImageNpcs) do
        local imageNpc = v
        imageNpc:stopAllActions()
        imageNpc:removeFromParent()
        imageNpc = nil
    end
    self.playImageNpcs = nil
end

function SpecialEffectsTestLayer:defaultStatus(image,info)
    image:setPosition(info.pos)
    image:setScale(info.scale)
    image:setOpacity(info.opacity)
end

function SpecialEffectsTestLayer:onTouchNpc(imageNpc)
    imageNpc:setSwallowTouch(true)
    imageNpc:OnBegan(function(sender, pos)
        if sender ~= self.currentNode and self.lastTest then
            return
        end
        if not self.lastTest then
            self.currentNode = imageNpc
            self.Label_tager:setText(imageNpc.name)
        end
        sender.logic = pos
        sender.savePos = sender:getPosition()
        self.TextField_posX:setString(string.format("%0.2f", sender:getPosition().x))
        self.TextField_posY:setString(string.format("%0.2f", sender:getPosition().y))
    end)
    imageNpc:OnMoved(function(sender, pos)
        if sender ~= self.currentNode and self.lastTest then
            return
        end
        local disX = pos.x - sender.logic.x
        local disY = pos.y - sender.logic.y

        sender:setPosition(sender.savePos + ccp(disX,disY))
        self.TextField_posX:setString(string.format("%0.2f", sender:getPosition().x))
        self.TextField_posY:setString(string.format("%0.2f", sender:getPosition().y))
    end)
    imageNpc:OnEnded(function(sender, pos)
    end)

    imageNpc:setTouchEnabled(true)

end

function SpecialEffectsTestLayer:onTouchBg(image)
    self.imageBg:OnBegan(function(sender, pos)
        if not self.lastTest then
            self.currentNode = self.imageBg
            self.Label_tager:setText(self.imageBg.name)
        end
        sender.logic = pos
        sender.savePos = sender:getPosition()
        self.TextField_posX:setString(string.format("%0.2f", sender:getPosition().x))
        self.TextField_posY:setString(string.format("%0.2f", sender:getPosition().y))
    end)
    self.imageBg:OnMoved(function(sender, pos)
        local disX = pos.x - sender.logic.x
        local disY = pos.y - sender.logic.y

        sender:setPosition(sender.savePos + ccp(disX,disY))
        self.TextField_posX:setString(string.format("%0.2f", sender:getPosition().x))
        self.TextField_posY:setString(string.format("%0.2f", sender:getPosition().y))
    end)
    self.imageBg:OnEnded(function(sender, pos)
    end)

    if self.lastTest then
        self.imageBg:setTouchEnabled(false)
    end
end

function SpecialEffectsTestLayer:findAllImageList()
    local filePath = me.FileUtils:fullPathForFilename("modle/cg")
    print("findAllImageList")
    function findindir (path, wefind, r_table, intofolder)
        for file in lfs.dir(path) do
            if file ~= "." and file ~= ".." then
                local f = path..'\\'..file
                ----print ("/t "..f)
                if string.find(f, wefind) ~= nil then
                    ----print("/t "..f)
                    table.insert(r_table, f)
                end
                local attr = lfs.attributes (f)
                assert (type(attr) == "table")
                if attr.mode == "directory" and intofolder then
                    findindir (f, wefind, r_table, intofolder)
                else
                end
            end
        end
    end
    -------------------------------------
    findindir(filePath, "%.png", self.chooseImages, false)

    --dump(self.chooseImages)
end

function SpecialEffectsTestLayer:findAllBgList()
    self.bgFileNameList = {}
    local filePath1 = me.FileUtils:fullPathForFilename("scene/cg")
    local filePath2 = me.FileUtils:fullPathForFilename("scene/bg")
    print("findAllBgList")
    function findindir (path, wefind, r_table, intofolder)
        for file in lfs.dir(path) do
            if file ~= "." and file ~= ".." then
                local f = path..'\\'..file
                ----print ("/t "..f)
                if string.find(f, wefind) ~= nil then
                    ----print("/t "..f)
                    table.insert(r_table, f)
                end
                local attr = lfs.attributes (f)
                assert (type(attr) == "table")
                if attr.mode == "directory" and intofolder then
                    findindir (f, wefind, r_table, intofolder)
                else
                end
            end
        end
    end
    -------------------------------------
    findindir(filePath1, "%.png", self.bgFileNameList, false)
    findindir(filePath2, "%.png", self.bgFileNameList, false)
end

function SpecialEffectsTestLayer:findCgFilePathList()
    local filePath = me.FileUtils:fullPathForFilename("cgAnimation")
    print("findCgFilePathList")
    function findindir (path, wefind, r_table, intofolder)
        for file in lfs.dir(path) do
            if file ~= "." and file ~= ".." then
                local f = path..'/'..file
                if string.find(f, wefind) ~= nil then
                    table.insert(r_table, f)
                end
                local attr = lfs.attributes (f)
                assert (type(attr) == "table")
                if attr.mode == "directory" and intofolder then
                    findindir (f, wefind, r_table, intofolder)
                else
                end
            end
        end
    end
    -------------------------------------
    findindir(filePath, "%.lua", self.cgFilePathList, false)

    self:loadCgFileList()
end

function SpecialEffectsTestLayer:loadCgFileList()
    if self.cgFilePathList then
        for i, v in ipairs(self.cgFilePathList) do
            local filePath = v
            local str = string.split(filePath, "cgAnimation/")[2]
            local cgFileName = string.split(str,".lua")[1]
            table.insert(self.cgFileNameList, cgFileName)
        end
    end
end

function SpecialEffectsTestLayer:initTableView()

    local panel_left = TFDirector:getChildByPath(self.ui,"Panel_left")
    panel_left:setZOrder(100)
    self.tableViewLeft = TFTableView:create()
    self.tableViewLeft:setTableViewSize(panel_left:getContentSize())
    self.tableViewLeft:setDirection(TFTableView.TFSCROLLVERTICAL)
    --列表设置为从小到大显示，及idx从0开始
    self.tableViewLeft:setVerticalFillOrder(TFTableView.TFTabViewFILLTOPDOWN)
    panel_left:addChild(self.tableViewLeft,200)
    Public:bindScrollFun(self.tableViewLeft)
    self.tableViewLeft.logic = self
    self.panel_left = panel_left


    local panel_down = TFDirector:getChildByPath(self.ui,"Panel_down")
    panel_down:setVisible(self.lastTest)
    panel_down:setZOrder(100)
    self.tableViewDown = TFTableView:create()
    self.tableViewDown:setTableViewSize(panel_down:getContentSize())
    self.tableViewDown:setDirection(TFTableView.TFSCROLLHORIZONTAL)
    --列表设置为从小到大显示，及idx从0开始
    self.tableViewDown:setVerticalFillOrder(TFTableView.TFTabViewFILLTOPDOWN)
    panel_down:addChild(self.tableViewDown,200)
    Public:bindScrollFun(self.tableViewDown)
    self.tableViewDown.logic = self
    self.panel_down = panel_down

end

function SpecialEffectsTestLayer:refreshTable()
    self.tableViewLeft:reloadData()
    self.tableViewLeft:scrollToYTop()
    self.tableViewDown:reloadData()
    self.tableViewDown:scrollToYTop()
end

function SpecialEffectsTestLayer.tableCellAtIndexLeft(tab, idx)
    local self = tab.logic
    local cell = tab:dequeueCell()
    local index = idx + 1

    local item = nil

    if nil == cell then
        cell = TFTableViewCell:create()
        item = TFImage:create()
        local laName = TFLabel:create()
        laName:setWidth(145)
        laName:setFontSize(16)
        laName:enableOutline(ccc4(100,100,100,255), 2)
        item.laName = laName
        cell:addChild(laName,100)
        cell:addChild(item)
        cell.item = item
    else
        item = cell.item
    end

    self:refreshItem(item,index)
    return cell
end

function SpecialEffectsTestLayer:refreshItem(item,index)
    if item.laName then
        local tablePath = string.split(self.chooseImages[index], "cg\\")
        item.laName:setText(tablePath[table.count(tablePath)])
    end
    item:setTexture(self.chooseImages[index])
    --local size = item:getSize()
    --local scale = 150/size.height
    --item:setScaleX(scale)
    --item:setScaleY(scale)
    item:Size(150,98)
    item:setPosition(ccp(150/2,100/2))
    item.npcNameIndex = index
    if self.chooseStates[item.npcNameIndex] then
        item:setColor(ccc3(255,125,125))
    else
        item:setColor(ccc3(255,255,255))
    end
end

function SpecialEffectsTestLayer.numberOfCellsInTableViewLeft(table)

    local self = table.logic

    return #self.chooseImages
end

function SpecialEffectsTestLayer.tableCellTouchedLeft(tab,cell)
    local self = tab.logic
    local item = clone(cell.item)
    local npcName = self.chooseImages[item.npcNameIndex]
    self.chooseStates[item.npcNameIndex] = true
    item:setColor(ccc3(255,125,125))
    if item.npc then
        self.chooseStates[item.npcNameIndex] = false
        item.npc:removeFromParent()
        table.removeItem(self.npcs,item.npc)
        self.tableViewDown:reloadData()
        if self.lastTest then
            self.currentNode = nil
        end
        if item.npc == self.currentNode then
            self.Label_tager:setText("点击任意图片可切换设置对象")
        end
        item.npc = nil
        item:setColor(ccc3(255,255,255))
        return
    end

    local npc = self.imageNpc:clone()
    npc.name = item.laName:getText()
    npc:show()
    npc:setTexture(npcName)
    npc.npcNameIndex = item.npcNameIndex
    local centerPos = ccp(self.imageNpc:getParent():Size().width/2,self.imageNpc:getParent():Size().height/2)
    npc:setPosition(centerPos)
    if not self.lastTest then
        self.currentNode = npc
        self.Label_tager:setText(npc.name)
    end
    self.imageNpc:getParent():addChild(npc,self.imageNpc:getZOrder())
    self:onTouchNpc(npc)
    table.insert(self.npcs,npc)
    self.tableViewDown:reloadData()
    item.npc = npc
end

function SpecialEffectsTestLayer.cellSizeForTableLeft(table,index)
    local self = table.logic;

    return 100,150

end


function SpecialEffectsTestLayer.tableCellAtIndexDown(tab, idx)
    local self = tab.logic
    local cell = tab:dequeueCell()
    local index = idx + 1

    local item = nil

    if nil == cell then
        cell = TFTableViewCell:create()
        item = TFImage:create()
        cell:addChild(item)
        cell.item = item
    else
        item = cell.item
    end

    local npc = self.npcs[index]
    item.name = self.chooseImages[npc.npcNameIndex]
    item:setTexture(item.name)
    local size = item:getSize()
    item:Size(158,100)
    -- local scale = 150/size.height
    -- item:setScaleX(150/size.width)
    -- item:setScaleY(100/size.height)
    item:setPosition(ccp(160/2,100/2))
    if npc.color then
        item:setColor(ccc3(125,125,255))
        npc.color = nil
    else
        item:setColor(ccc3(255,255,255))
    end
    return cell
end

function SpecialEffectsTestLayer.numberOfCellsInTableViewDown(table)

    local self = table.logic

    return #self.npcs
end

function SpecialEffectsTestLayer.tableCellTouchedDown(tab,cell)

    --print("click  tableCellTouchedDown")

    local self = tab.logic
    local item = cell.item
    local itemName = item.name
    for i,v in ipairs(self.npcs) do
        local npc = v
        local npcName = self.chooseImages[npc.npcNameIndex]
        if itemName == npcName then
            if npc.isSelect == nil then
                self.currentNode = npc
                self.Label_tager:setText(npc.name)
                self:suoDingBtnClickHandle()
                npc.color = true
                npc.isSelect = true
            else
                npc.color = nil
                npc.isSelect = nil
            end
            self.tableViewDown:reloadData()
            return
        end
    end
end

function SpecialEffectsTestLayer.cellSizeForTableDown(table,index)
    local self = table.logic;

    return 100,160

end

--注册事件
function SpecialEffectsTestLayer:registerEvents()
    self.super.registerEvents(self)

    local TextButton_cgFind = TFDirector:getChildByPath(self.ui, "TextButton_cgFind")
    local TextField_cgFileName = TFDirector:getChildByPath(self.ui, "TextField_cgFileName")
    local Button_backCgList = TFDirector:getChildByPath(self.ui, "Button_backCgList"):hide()

    TextButton_cgFind:onClick(function()
        self.cgFindFileNamelList = {}
        self.bgFindFileNamelList = {}
        local isFind = false
        local list = nil
        local findList = nil
        if self.bgList and #self.bgList > 0 then
            list = self.bgList
            findList = self.bgFindFileNamelList
        elseif self.cgList and # self.cgList > 0 then
            list = self.cgList
            findList = self.cgFindFileNamelList
        end
        if not list then
            Utils:showTips("没有任何文件列表数据！")
            return
        end
        for i, v in ipairs(list) do
            local Label_name = TFDirector:getChildByPath(v, "Label_name")
            if string.find(Label_name:getText(),TextField_cgFileName:getText()) then
                local fileNameData = {}
                fileNameData.id = i
                fileNameData.name = Label_name:getText()
                table.insert(findList,fileNameData)
                isFind = true
            end
        end
        if isFind then
            if self.bgList and #self.bgList > 0 then
                self.isFindBg = true
                self:showFindBgItemList()
            elseif self.cgList and # self.cgList > 0 then
                self.isFindCg = true
                self:showFindCgItemList()
            end
            self.findCGgridView:setVisible(true)
            self.cGgridView:setVisible(false)
            Button_backCgList:show()
            TextButton_cgFind:hide()
            TextField_cgFileName:hide()
        else
            if self.bgList and #self.bgList > 0 then
                self.isFindBg = false
            elseif self.cgList and # self.cgList > 0 then
                self.isFindCg = false
            end
            TextField_cgFileName:setText("")
            Utils:showTips("没有找到任何cg文件，请输入正确的cg文件名！")
        end
    end)

    Button_backCgList:onClick(function()
        if self.isFindCg then
            self.isFindCg = false
            self.Label_count:setText("当前列表总数：" .. #self.cgList)
        elseif self.isFindBg then
            self.isFindBg = false
            self.Label_count:setText("当前列表总数：" .. #self.bgList)
        end
        TextButton_cgFind:show()
        TextField_cgFileName:show()
        TextField_cgFileName:setText("")
        Button_backCgList:hide()
        self.findCGgridView:setVisible(false)
        self.cGgridView:setVisible(true)
    end)
end

function SpecialEffectsTestLayer:bindTableViewEvent()
    -- table view 事件

    --print("bindTableViewEvent")

    self.tableViewLeft:addMEListener(TFTABLEVIEW_TOUCHED, self.tableCellTouchedLeft)
    self.tableViewLeft:addMEListener(TFTABLEVIEW_SIZEFORINDEX, self.cellSizeForTableLeft)
    self.tableViewLeft:addMEListener(TFTABLEVIEW_SIZEATINDEX, self.tableCellAtIndexLeft)
    self.tableViewLeft:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, self.numberOfCellsInTableViewLeft)

    self.tableViewDown:addMEListener(TFTABLEVIEW_TOUCHED, self.tableCellTouchedDown)
    self.tableViewDown:addMEListener(TFTABLEVIEW_SIZEFORINDEX, self.cellSizeForTableDown)
    self.tableViewDown:addMEListener(TFTABLEVIEW_SIZEATINDEX, self.tableCellAtIndexDown)
    self.tableViewDown:addMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW, self.numberOfCellsInTableViewDown)

end

--移除事件
function SpecialEffectsTestLayer:removeEvents()
    self.super.removeEvents(self)


    self.tableViewLeft:removeMEListener(TFTABLEVIEW_TOUCHED)
    self.tableViewLeft:removeMEListener(TFTABLEVIEW_SIZEFORINDEX)
    self.tableViewLeft:removeMEListener(TFTABLEVIEW_SIZEATINDEX)
    self.tableViewLeft:removeMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW)

    self.tableViewDown:removeMEListener(TFTABLEVIEW_TOUCHED)
    self.tableViewDown:removeMEListener(TFTABLEVIEW_SIZEFORINDEX)
    self.tableViewDown:removeMEListener(TFTABLEVIEW_SIZEATINDEX)
    self.tableViewDown:removeMEListener(TFTABLEVIEW_NUMOFCELLSINTABLEVIEW)

end

return SpecialEffectsTestLayer
