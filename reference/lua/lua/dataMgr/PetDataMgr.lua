
local BaseDataMgr = import(".BaseDataMgr")
local PetDataMgr = class("PetDataMgr", BaseDataMgr)




--临时测试数据
local TestPet =
{
    id     = 400001,
    cid    = 400001,
    level  = 10,
    star   = 1,
    heroId = ""
}

function PetDataMgr:addTestData()
    self.petDatas = {}
    --TODO 测试数据
    for k,v in pairs(self.Pets) do
        local data  = clone(TestPet)
        data.id     = tostring(v.id)
        data.cid    = v.id
        self.petDatas[data.id] = data
    end
end


function PetDataMgr:init()
    self.petDatas = {}
    TFDirector:addProto(s2c.PET_RES_EQUIP_PET, self, self.onResEquipPet)
    TFDirector:addProto(s2c.PET_RES_UPGRADE_PET, self, self.onResUpgradePet)
    self:onReloadConfig()
end



function PetDataMgr:onReloadConfig()
    self.PetsAdvance    = TabDataMgr:getData("PetsAdvance")
    self.Pets           = TabDataMgr:getData("Pets")
    self.PetsStrengthen = TabDataMgr:getData("PetsStrengthen") 
    self.PetsSkill      = TabDataMgr:getData("PetsSkill") 
end


function PetDataMgr:onLogin()
    return {}
end

function PetDataMgr:reset()
    self.petDatas = {}
end

function PetDataMgr:onEnterMain()
    -- self:addTestData()
end

function PetDataMgr:syncServer(data)
    if data.ct == EC_SChangeType.ADD or data.ct == EC_SChangeType.DEFAULT then
        self.petDatas[data.id] = data;
    elseif data.ct == EC_SChangeType.UPDATE then
        self.petDatas[data.id] = self.petDatas[data.id] or {}
        table.merge(self.petDatas[data.id],data)
    elseif data.ct == EC_SChangeType.DELETE then
        self.petDatas[data.id] = nil
    end
end


function PetDataMgr:changeDataToFriend(friend)
    if not self.myPetDatas then
        self.myPetDatas = clone(self.petDatas)
    end
    self.petDatas = {}
    for k,v in pairs(friend.heros) do
        if v.pets then
            for k2,v2 in pairs(v.pets) do
                v2.pet.ct = EC_SChangeType.DEFAULT;
                self:syncServer(v2.pet);
            end
        end
    end
end

function PetDataMgr:changeDataToSelf()
    if self.myPetDatas then
        self.petDatas = {}
        GoodsDataMgr:resetPet()
        self.myPetDatas = nil
    end
end

--获取宠物最大等级
function PetDataMgr:getMaxLv(id)
    local petData    = self:getPetData(id)
    local petcfg     = self:getPetCfg(petData.cid)
    local star       = petData.star
    local advanceCfg = self.getAdvanceCfg(petData.cid, star)
    return advanceCfg.limitLevel
end




function PetDataMgr:getPetDatas()
    return self.petDatas
end 

--返回宠物列表
function PetDataMgr:getPetDatas_()
    local datas = {}
    for k,v in pairs(self.petDatas) do
        table.insert(datas,v)
    end 
    --sort 
    return datas 
end 


function PetDataMgr:getPetData(id)  
    return self.petDatas[tostring(id)]
end

function PetDataMgr:getPetDataByCid(cid)  
    for k,v in pairs(self.petDatas) do
        if v.cid == cid then 
            return v
        end
    end
end


--判断是升级还是升阶 0 满级   1升级  2升阶
function PetDataMgr:getUpgradeType(id)
    local data       = self:getPetData(id)
    local cid        = data.cid
    local petCfg     = self:getPetCfg(cid)
    local star       = data.star
    if data.star >= petCfg.endStar then 
        return 0
    end
    local maxLevel   = self:getStarMaxLevel(cid, star) 
    if data.level <  maxLevel then 
        return 1 --升级
    end
    if data.star < petCfg.endStar then 
        return 2
    end
    return 0
end


--当前阶段的最大等级
function PetDataMgr:getStarMaxLevel(cid, star)
    local advCfg    = self:getAdvanceCfg(cid, star)
    return advCfg.limitLevel
end



--最大多少阶段
--当前阶段的最大等级
--当前阶段是否达到最大等级 ，没有达到最大等级 进行升级 ，如果到大最大等级   判断是否可以升阶 


function PetDataMgr:getAttributes(cid, star, level)
    local petCfg     = self:getPetCfg(cid)
    local advanceCfg = self:getAdvanceCfg(cid , star)
    local attrValues = {}
    for k, baseValue in pairs(advanceCfg.Attr) do
        local upValue   = advanceCfg.upAttr[k] or 0
        local value     = baseValue +  (upValue * math.max((level - 1), 0))
        value = string.format("%.1f", (value / 100))
        -- attrValues[k] = tonumber(value)
        table.insert(attrValues ,{id = k ,value =tonumber(value)})
    end
    table.sort(attrValues,function (a ,b)
        return a.id < b.id
    end)
    -- print("getAttributes")
    -- dump(attrValues)

    return attrValues
end

function PetDataMgr:getAttributeKV(cid, star, level)
    local attrValues = self:getAttributes(cid, star, level)
    local kv = {}
    for i,v in ipairs(attrValues) do
        kv[v.id] = v.value
    end
    return kv  
end

function PetDataMgr:getAdvanceCfg(cid, star)
    local petCfg    = self:getPetCfg(cid)
    local advanceId = petCfg.attribute * 100 + (star+1)   --计算advanceId
    -- print("advanceId:" ..tostring(advanceId) .." cid: " ..tostring(cid) .." star: "..tostring(star))
    return self.PetsAdvance[advanceId]
end

--获取宠物配置信息
function PetDataMgr:getPetCfg(id)   
    id = tonumber(id)
    return self.Pets[id]
end

function PetDataMgr:getPetCfgs()   
    return self.Pets
end



--获取宠物配置信息
function PetDataMgr:getPetSkillCfg(id)   
    id = tonumber(id)
    return self.PetsSkill[id]
end

function PetDataMgr:getPetSkillDes2(id,star)   
    local skillCfg = self:getPetSkillCfg(id)
    return skillCfg.des2[star + 1]
end

function PetDataMgr:getPetSkillDes(id,star)   
    local skillCfg = self:getPetSkillCfg(id)
    return skillCfg.des[star + 1]
end

--宠物技能
function PetDataMgr:getPetSkill(id,star) 
    local skillCfg = self:getPetSkillCfg(id)
    return skillCfg.specialSkill[star + 1]
end

--宠物技能
-- function PetDataMgr:getPetSkillByHeroId(heroId) 
--     for i,v in pairs(self.petDatas) do
--         if v.heroId == heroId then 
--             return self:getPetSkill(v.cid ,v.star)
--         end
--     end
-- end





-- function PetDataMgr:getPetStar(id)   
--     local data = self:getPetData(id)
--     return data.star
-- end

function PetDataMgr:getStrengthenCfg(cid)   
    return self.PetsStrengthen[cid]
end





-- --是否有可装备的宠物
-- function PetDataMgr:hasPet()
-- 	return table.count(self.petDatas) > 0
-- end




--装备/卸下宠物
function PetDataMgr:sendEquipPet(opType,heroId,petId)
    TFDirector:send(c2s.PET_REQ_EQUIP_PET ,{opType ,tostring(heroId),tostring(petId)})
end

--升级宠物
function PetDataMgr:sendUpgradePet(petId)   
    TFDirector:send(c2s.PET_REQ_UPGRADE_PET,{tostring(petId)})
end

--响应装备卸下宠物
function PetDataMgr:onResEquipPet(event)
    local data = event.data
    print("装备宠物:"..tostring(data.heroId))
    EventMgr:dispatchEvent(EV_PET_CHANGE)
end

--宠物升级响应
function PetDataMgr:onResUpgradePet(event)
    local data  = event.data
    print("pet level up restult :" ..tostring(data.type))
    if data.type then  --1 升级 2 进阶
        EventMgr:dispatchEvent(EV_PET_LEVEUP,data.type)
        EventMgr:dispatchEvent(EV_PET_CHANGE)
    end
end


return PetDataMgr:new()
