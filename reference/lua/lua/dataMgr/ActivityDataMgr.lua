local BaseDataMgr = import(".BaseDataMgr")
local ActivityDataMgr = class("ActivityDataMgr", BaseDataMgr)
require("lua.logic.activity.json");

function ActivityDataMgr:ctor()
	self:initData()
	self:init();
end

function ActivityDataMgr:initData()
	self:initCfgData()
	self.actList = {}
	self.activity3List = {}
end

function ActivityDataMgr:initCfgData()
	self.signkvpCfg = Utils:getKVP(90017)
end

function ActivityDataMgr:init()
	TFDirector:addProto(s2c.SIGN_RESP_SIGN_INFOS, self, self.recvActivityList)
	TFDirector:addProto(s2c.SIGN_RESULT_SUBMIT_SIGN, self, self.revcReceiveReward)
	TFDirector:addProto(s2c.SIGN_RESP_SEVEN_CARNIVAL, self, self.revcSevenExList)
	TFDirector:addProto(s2c.SIGN_RESP_PURCH_STORE, self, self.revcBuySevenExGift)
	TFDirector:addProto(s2c.ACTIVITY_RESP_NEW_YEAR_WELFARE_URL, self, self.revcNewYear)
	TFDirector:addProto(s2c.RANK_RSP_RANK_LIST, self, self.recvRankList)  --接收排行信息

	TFDirector:addProto(s2c.SIGN_RESULT_SUPPLY_SIGN, self, self.revcReceiveReward)
	TFDirector:addProto(s2c.WORLD_HELP_RES_RANK_INFO, self, self.onRecvAllServerAssistanceRank)
	TFDirector:addProto(s2c.WORLD_HELP_RES_REWARD_RECORD, self, self.onRecvAllServerAssistanceProgerss)
	TFDirector:addProto(s2c.WORLD_HELP_RES_TAKE_REWARD, self, self.onRecvAllServerAssistanceAwards)

	--排行榜数据返回
    TFDirector:addProto(s2c.RANK_RES_GIFT_RANK_INFO, self, self.onResGiftRankInfo)
    --送礼信息返回
    TFDirector:addProto(s2c.RANK_RES_SEND_GIFT_RANK, self, self.onResSendGiftRank)


    --7日充值界面信息
    TFDirector:addProto(s2c.ACTIVITY_RES_VOUCHER_SEVEN_DAY_INFO , self, self.onRecVoucherSevenDayData)
    --7日充值领奖
    TFDirector:addProto(s2c.ACTIVITY_RES_VOUCHER_SEVEN_DAY_GET_REWARD, self, self.onRecVoucherSevenDayGetReward)

    --非后台配置活动数据
    TFDirector:addProto(s2c.ACTIVITY3_RES_GET_ALL_ACTIVITY3, self, self.onResGetAllActivityData)
    TFDirector:addProto(s2c.ACTIVITY3_RES_ELEMENT_TRAIN_RANK ,self, self.onResElementTrailRank)
    TFDirector:addProto(s2c.ACTIVITY3_RES_ELEMENT_TRAIN_INFO ,self, self.onResElementTrailInfo)

end

--[[
	[1] = {--ResElementTrainRank
		[1] = 'int32':id	[排行榜类型,ElementTrainDungeon.csv#id]
		[2] = {--repeated ElementTrainRank
			[1] = 'int32':rank	[排名]
			[2] = 'int64':score	[分数(dungeonID,用于显示通关层数信息)    //分数(dungeonID,用于显示通关层数信息)]
			[3] = 'int32':playerId	[玩家id]
			[4] = 'string':name	[玩家名字]
			[5] = 'int32':lv	[等级]
			[6] = 'int32':portraitCid	[头像id]
			[7] = 'int32':portraitFrameCid	[头像框id]
		},
	}
--]]

  -- repeated ElementTrainHero heroFatigueList = 1; //英雄疲劳值信息
  -- repeated ElementTrainDungeon dungeonInfoList = 2; //已经通关的副本信息


--元素试炼信息返回，精灵感染度 和通关关卡
function ActivityDataMgr:onResElementTrailInfo(event)
	local data = event.data
	self.elementTrainInfo  = data
   
	dump(self.elementTrainInfo)
    -- self.elementTrainInfo.heroFatigueList = self.elementTrainInfo.heroFatigueList or {}
    -- self.elementTrainInfo.dungeonInfoList = self.elementTrainInfo.dungeonInfoList or {}

    -- self.elementTrainRankDatas[data.id] = data.rankList or {}
    -- EventMgr:dispatchEvent(EV_ACTIVITY_ELEMENT_TRAIL_RANK_UPDATE ,data.id)

    EventMgr:dispatchEvent(EV_ACTIVITY_ELEMENT_TRAIL_INFO_UPDATE)

end



function ActivityDataMgr:onResElementTrailRank(event)
	local data = event.data
	self.elementTrainRankDatas          = self.elementTrainRankDatas or {} 
    self.elementTrainRankDatas[data.id] = data.rankList or {}
    EventMgr:dispatchEvent(EV_ACTIVITY_ELEMENT_TRAIL_RANK_UPDATE ,data.id)
end

--获取元素试炼英雄感染度
function ActivityDataMgr:getElementTrailHeroFatigue(heroId)

	if self.elementTrainInfo and self.elementTrainInfo.heroFatigueList then 
		for i,v in ipairs(self.elementTrainInfo.heroFatigueList) do
			if v.heroId == heroId then 
				return v.fatigue
			end
		end
	end
	return 0
  -- required int32 heroId = 1;	//英雄cid
  -- required int64 fatigue = 2;	  //英雄当前累计的疲劳值
end

-- function ActivityDataMgr:getElementTrailRankData(elementTrailDungeonId)
-- 	if self.elementTrainRankDatas then 
-- 		return self.elementTrainRankDatas[elementTrailDungeonId] or {}
-- 	end
-- 	return {}
-- end

function ActivityDataMgr:getElementTrailRankDatas()
	return self.elementTrainRankDatas or {}
end

--请求元素试炼排行榜单
function ActivityDataMgr:reqElementTrailRank(rankType)
	TFDirector:send(c2s.ACTIVITY3_REQ_ELEMENT_TRAIN_RANK, {rankType})
end

--请求元素试炼信息
function ActivityDataMgr:reqElementTrailInfo()
	TFDirector:send(c2s.ACTIVITY3_REQ_ELEMENT_TRAIN_INFO, {})
end


--V3非后台配置活动数据
function ActivityDataMgr:onResGetAllActivityData(event)
	local data = event.data
	self.activity3List = {}  
	for i,activityData in ipairs(data.activity3List or {}) do
		self.activity3List[activityData.id] = activityData
	end
	EventMgr:dispatchEvent(EV_ACTIVITY3_DATA_UPDATE)
end
--V3非后台配置活动数据请求
function ActivityDataMgr:reqGetAllActivityData()
	TFDirector:send(c2s.ACTIVITY3_REQ_GET_ALL_ACTIVITY3 , {})
end

function ActivityDataMgr:getActivity3Data(activityId)
	return self.activity3List[activityId]
end
			-- [1] = {--ChangeType(enum)
			-- 	'v4':ChangeType
			-- },
			-- [2] = 'int32':id	[活动ID]
			-- [3] = 'int32':activityType	[活动类型]
			-- [4] = 'string':activityTitle	[活动标题]
			-- [5] = 'int32':startTime	[开始时间]
			-- [6] = 'int32':endTime	[结束时间]
			-- [7] = 'int32':showStartTime	[显示开始时间]
			-- [8] = 'int32':showEndTime	[显示结束时间]
			-- [9] = 'string':remark	[备注信息Json]
			-- [10] = 'string':extendData	[扩展数据]
			-- [11] = 'int32':rank	[排序]
			-- [12] = 'string':showIcon	[广告图]
			-- [13] = 'repeated int32':items	[活动条目]
			-- [14] = 'string':titleIcon	[活动标题Icon]
function ActivityDataMgr:isActivity3Open(activityId)
	local activityData = self.activity3List[activityId]
	if activityData then 
		local serverTime = ServerDataMgr:getServerTime()
		if serverTime >= activityData.startTime and serverTime <=activityData.endTime then 
			return true
		end 
	end
	return false
end

--获取元素试炼数据
function ActivityDataMgr:getElementTrailData()
	return self:getActivity3Data(EC_ActivityFubenType.ELEMENT_TRIAL)
end

---排行版数据返回
function ActivityDataMgr:onResGiftRankInfo(event)
	local data = event.data
	-- Box("打榜数据返回")
	local rankType = data.rankType 
	if rankType == 1 then 
		self.topRanks                 = data.totalRank
	elseif rankType == 2 then 
		self.personalContributionRank = data.personalContributionRank
	elseif rankType == 3 then 
		self.personalPowerRank        = data.personalPowerRank
	end
	EventMgr:dispatchEvent(EV_HERO_RANK_UPDATE ,rankType)
end
--总榜
function ActivityDataMgr:getTopRank()
	return self.topRanks  or {}
end
--个人贡献榜
function ActivityDataMgr:getPersonalContributionRank()
	return self.personalContributionRank  or {}
end
--个人战力榜
function ActivityDataMgr:getPersonalPowerRank()
	return self.personalPowerRank  or {}
end

function ActivityDataMgr:onResSendGiftRank(event)
    local data = event.data
end


-- //人气总榜
-- message TotalRakInfo{
-- 	required int32 rank = 1;	//排名
-- 	required int64 score = 2;		//分数

-- 	required int32 heroId = 3;	//精灵id
-- }

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


-- //礼物打榜：界面请求
-- //code = 9601
-- message ResGiftRankInfo{
--   repeated TotalRakInfo totalRank = 1;		//人气总榜
-- 	repeated PersonalRakInfo personalContributionRank = 2;		//个人贡献榜
-- 	repeated PersonalRakInfo personalPowerRank = 3;		//个人战力榜
-- 	enum MsgID{eMsgID = 9601;}; //注意：消息id放最后,以免客户端解析异常
-- }


-- //礼物打榜：送礼
-- //code = 9602
-- message ResSendGiftRank{
-- 	enum MsgID{eMsgID = 9602;}; //注意：消息id放最后,以免客户端解析异常
-- }




-- //礼物打榜：界面请求
-- //code = 9601
-- message ReqGiftRankInfo{
-- 	required int32 rankType = 1; //1：人气总榜；2：个人贡献榜；3：个人战力榜
-- 	required int32 heroId = 2;//精灵id，rankType为2或者3时候需要
-- 	enum MsgID{eMsgID = 9601;}; //注意：消息id放最后,以免客户端解析异常
-- }

-- //礼物打榜：送礼
-- //code = 9602
-- message ReqSendGiftRank{
-- 	required int32 heroId = 1; //精灵id
-- 	required int32 itemNum = 2;//赠送礼物数量
-- 	enum MsgID{eMsgID = 9602;}; //注意：消息id放最后,以免客户端解析异常
-- }


function ActivityDataMgr:reqGigtRankInfo(rankType,heroId)
	heroId = heroId or 0
	print("reqGigtRankInfo rankType："..rankType .. " heroId: " ..heroId)
	TFDirector:send(c2s.RANK_REQ_GIFT_RANK_INFO , {rankType ,heroId})
end

--打榜送礼
function ActivityDataMgr:reqSendGift(heroId,itemNum)
	print("reqSendGift heroId："..heroId .. " itemNum: " ..itemNum)
	TFDirector:send(c2s.RANK_REQ_SEND_GIFT_RANK , {heroId,itemNum})
end



---------7日充值

 --代金卷连充界面信息
function ActivityDataMgr:onRecVoucherSevenDayData(event)
    local data = event.data
    self.voucherSevenDayData = data
    self.voucherSevenDayData.alreadyClaimedId = self.voucherSevenDayData.alreadyClaimedId or {}
    self.voucherSevenDayData.payAmountByDay = self.voucherSevenDayData.payAmountByDay or {}
    -- print("ActivityDataMgr:onRecVoucherSevenDayData")
    -- print(data)
    EventMgr:dispatchEvent(EV_VOUCHER_SEVEN_DAY_DATA_UPDATE,data)
    EventMgr:dispatchEvent(EV_ACTIVITY_UPDATE_PROGRESS)
    -- Box("onRecVoucherSevenDayData")
end




--[[
	[1] = {--ResVoucherSevenDayGetReward 
		[1] = 'repeated int32':alreadyClaimedId	[已领取的奖励id]
		[2] = {--repeated RewardsMsg
			[1] = 'int32':id
			[2] = 'int32':num
		},
	}
--]]

function ActivityDataMgr:onRecVoucherSevenDayGetReward(event)
    local data = event.data
    self.voucherSevenDayData.alreadyClaimedId = data.alreadyClaimedId
    EventMgr:dispatchEvent(EV_VOUCHER_SEVEN_DAY_GET_REWARD,data)
    EventMgr:dispatchEvent(EV_ACTIVITY_UPDATE_PROGRESS)
    
end

--获取每日的充值金额
function ActivityDataMgr:getVoucherRechargeValue(day)
	if self.voucherSevenDayData then 
		if not day then 
			day = self.voucherSevenDayData.curDay
		end
    	return self.voucherSevenDayData.payAmountByDay[day] or 0
	end
	return 0
end



--代金券连充:界面信息
function ActivityDataMgr:reqVoucherSevenDayInfo()
    TFDirector:send(c2s.ACTIVITY_REQ_VOUCHER_SEVEN_DAY_INFO, {})
end

--代金券连充:领取奖励
function ActivityDataMgr:reqVoucherSevenDayGetReward(id)
    TFDirector:send(c2s.ACTIVITY_REQ_VOUCHER_SEVEN_DAY_GET_REWARD, {id})
end

 --代金卷连充界面信息
function ActivityDataMgr:getVoucherSevenDayData()
    return self.voucherSevenDayData
end



















--发送根据类型获取排行榜信息请求
function ActivityDataMgr:sendGetRankByTypeReq(idx )
	local typeIdx = {1 , 4 , 3, 2 ,5 ,6 , 7 , 8} --1等级 2战斗力 3无尽 4充值
	TFDirector:send(c2s.RANK_REQ_RANK_LIST , {typeIdx[idx]})
end

--接收排行数据
function ActivityDataMgr:recvRankList(event)
	local data = event.data
	EventMgr:dispatchEvent(EV_RANK_NOTICE_UPDATE , data)
end

function ActivityDataMgr:getSignKvpCfg()
	return self.signkvpCfg
end

function ActivityDataMgr:getIsHaveActs( )
	return table.count(self.actList) > 0;
end

function ActivityDataMgr:getActivitys()
	return self.actList;
end

function ActivityDataMgr:getActivityCnt()
	return table.count(self.actList);
end

function ActivityDataMgr:getActIdx(actID)
	local idx = -1;
	for i,v in ipairs(self.actList) do
		if v.id == actID then
			idx = i;
			break;
		end
	end

	return idx
end

function ActivityDataMgr:getActIdxByID(actID)
	local idx = -1;
	for i,v in ipairs(self.actList) do
		if v.id == actID then
			idx = i;
			break;
		end
	end

	return idx
end

function ActivityDataMgr:getActData(actIdx)
	return self.actList[actIdx];
end

function ActivityDataMgr:getActList(actIdx)
	return self.actList[actIdx]
end

--UI
function ActivityDataMgr:getActTitle(actId)
	local cfg = self:getActivityFirstCfgById(actId, 1)
	if cfg then
		return cfg.name
	end
	return ""
end

function ActivityDataMgr:getActBg(actIdx)
	local act = self.actList[actIdx]
	local actCfg = self:getActivityFirstCfgById(act.id, 1)
	if act.id == EC_ActivityType.SIGN then
		return actCfg.icon
	elseif act.id == EC_ActivityType.SEVENDAY then
		return actCfg.adIcon
	elseif act.id == EC_ActivityType.NEXTDAY then
		return actCfg.adIcon
	elseif act.id == EC_ActivityType.POWER then
		return actCfg.icon
	end
	return ""
end
--UI end

function ActivityDataMgr:getActId(actIdx)
	return self.actList[actIdx].id
end

function ActivityDataMgr:getActEntryCnt(actIdx)
	local act = self.actList[actIdx]
	local count = 0
	if act.id == EC_ActivityType.SIGN then
		local cfgMap = TabDataMgr:getData("Sign")
		for i,v in ipairs(cfgMap) do
			if tostring(v.month) == tostring(act.extendData) then
				count = count + 1
			end
		end
	elseif act.id == EC_ActivityType.SEVENDAY then
		local cfgMap = TabDataMgr:getData("SevenSign")
		for i,v in ipairs(cfgMap) do
			count = count + 1
		end
	end
	return count
end

function ActivityDataMgr:getActOneEntry(actIdx,idx)
	local act = self.actList[actIdx]
	if not act then
		return 0,{}
	end
	local status = act.awardType[1] or 0
	local rewards = {}
	if act.id == EC_ActivityType.SIGN then
		if act.index < idx then
			status = 2
		elseif act.index > idx then
			status = 0
		end
		local cfgMap = TabDataMgr:getData("Sign")
		for i,v in ipairs(cfgMap) do
			if tostring(v.month) == tostring(act.extendData) and v.signTimes == idx then
				rewards = v.gifts or {}
			end
		end
	elseif act.id == EC_ActivityType.SEVENDAY then
		status = act.awardType[idx]
		local cfgMap = TabDataMgr:getData("SevenSign")
		for i,v in ipairs(cfgMap) do
			if v.signTimes == idx then
				rewards = v.gifts or {}
			end
		end
	end
	return status, rewards
end

function ActivityDataMgr:onLogin()
	TFDirector:send(c2s.SIGN_REQ_SIGN_INFOS, {})
	TFDirector:send(c2s.SIGN_REQ_SEVEN_CARNIVAL, {})
	self:reqGetAllActivityData()
	self:reqElementTrailInfo()
	return {s2c.SIGN_RESP_SIGN_INFOS,s2c.SIGN_RESP_SEVEN_CARNIVAL}
end

function ActivityDataMgr:onLoginOut()
	self.actList = {}
end

function ActivityDataMgr:recvActivityList(event)
	if not event.data.signInfos then
		return
	end

	local isSort = false;
	local ischange = false;
	if table.count(self.actList) < table.count(event.data.signInfos) then
		isSort = true
		ischange = true
	end
	for k,v in pairs(event.data.signInfos) do
		local idx = self:getActIdxByID(v.id)
		if idx == -1 then
			table.insert(self.actList,v);
		else
			self.actList[idx] = v;
		end

		--领取大于等于第3天的7日奖励，弹出5星好评
		if v.id == 2 and ischange == false then
			if v.awardType[3] == 0 then
				CommonManager:setStarEvaluateFlage(true)
			end
		end
	end
	local data = TabDataMgr:getData("DiscreteData",23001).data
	local function sortfunc(a,b)
		local aorder = 1
		local border = 1
		for k, cfg in pairs(data) do
			if cfg.id == a.id then
				aorder = cfg.order
			end
			if cfg.id == b.id then
				border = cfg.order
			end
		end
		return aorder < border
	end

	if table.count(self.actList) > 1 and isSort then
		table.sort(self.actList,sortfunc);
	end

	if ischange then
		EventMgr:dispatchEvent(EV_ACTIVITY_LIST_CHANGE);
	else
		EventMgr:dispatchEvent(EV_ACTIVITY_UPDATE_UI);
	end
end

function ActivityDataMgr:getReceivedIndex(actIdx)
	local act = self:getActList(actIdx)
	if act.id == EC_ActivityType.SIGN then
		return act.index
	elseif act.id == EC_ActivityType.SEVENDAY then

	elseif act.id == EC_ActivityType.NEXTDAY then

	elseif act.id == EC_ActivityType.POWER then

	end
	return act.index
end

function ActivityDataMgr:getIsCanReceive(actIdx)
	local flag = false
	local act = self:getActList(actIdx)
	if act then
		if act.id == EC_ActivityType.SIGN then
			for i,state in ipairs(act.awardType) do
				if state == 1 then
					flag = true
				end
			end
		elseif act.id == EC_ActivityType.SEVENDAY then
			for i,state in ipairs(act.awardType) do
				if state == 1 then
					flag = true
				end
			end
		elseif act.id == EC_ActivityType.NEXTDAY then
			for i,state in ipairs(act.awardType) do
				if state == 1 then
					flag = true
				end
			end
		elseif act.id == EC_ActivityType.POWER then
			for i,state in ipairs(act.awardType) do
				if state == 1 then
					flag = true
				end
			end
		end
	else
		local sevenExTask_ = TaskDataMgr:getTask(EC_TaskType.SEVENEX)
		for k,v in pairs(sevenExTask_) do
			local taskCid = sevenExTask_[k]
	    	local taskInfo = TaskDataMgr:getTaskInfo(taskCid)
	    	if taskInfo.status == EC_TaskStatus.GET then
	    		flag = true
	    	end
		end
	end

	return flag
end

-- 签到是否可以补签
function ActivityDataMgr:isCanSignAgainByIdx(actIdx)
	local flag = false
	local day  = 0
	local hadSupplyDays = 0
	local act  = self:getActList(actIdx)
	if act and act.supplyLimit then
		if act.id == EC_ActivityType.SIGN then
			flag = act.supplyLimit > 0
			day  = act.supplyLimit
			hadSupplyDays = table.count(act.supplyDays  or {})
		end
	end
	return flag, day, hadSupplyDays
end

function ActivityDataMgr:getOneDayShowRedPoint(dayIndex)
	local flag = false
	local sevenExTask_ = TaskDataMgr:getTask(EC_TaskType.SEVENEX)
	for k,v in pairs(sevenExTask_) do
		local taskCid = sevenExTask_[k]
    	local taskInfo = TaskDataMgr:getTaskInfo(taskCid)
    	local taskCfg = TaskDataMgr:getTaskCfg(taskCid)
    	if taskInfo.status == EC_TaskStatus.GET and taskCfg.acceptParams.day == dayIndex then
    		flag = true
    	end
	end
	return flag
end

function ActivityDataMgr:getActivityFirstCfgById(actId, idx)
	if actId == EC_ActivityType.SIGN then
		return TabDataMgr:getData("Sign", idx)
	elseif actId == EC_ActivityType.SEVENDAY then
		return TabDataMgr:getData("SevenSign", idx)
	elseif actId == EC_ActivityType.NEXTDAY then
		return TabDataMgr:getData("TomorrowSign", idx)
	elseif actId == EC_ActivityType.POWER then
		return TabDataMgr:getData("EnergySupplement", idx)
	end
end

function ActivityDataMgr:receiveReward(actIdx)
	local isCan = self:getIsCanReceive(actIdx);
	local act   = self:getActList(actIdx)
	local isCanSignAgain = false
	local lastDay   = 0
	local hadSupplyDays    = nil
	local goodsCost = nil
	if act then
		if act.id == EC_ActivityType.SIGN then
			isCanSignAgain, lastDay, hadSupplyDays = self:isCanSignAgainByIdx(actIdx)
			-- maxDay      = self.signkvpCfg["supplyMax"]
			if isCanSignAgain then
				local _id , _num = next(self.signkvpCfg["supplyCost"][hadSupplyDays + 1])
				goodsCost   = {id = _id, num = _num}
		    end
		end
	end

	if not isCan and not isCanSignAgain then
		Utils:showTips(800057);
		return;
	end

	local actid = self:getActId(actIdx);
	local msg = {
		actid,
	}
	if isCan then
		TFDirector:send(c2s.SIGN_SUBMIT_SIGN, msg);
	elseif not isCan and isCanSignAgain then -- 可以补签
		if GoodsDataMgr:currencyIsEnough(goodsCost.id, goodsCost.num) then
			TFDirector:send(c2s.SIGN_SUPPLY_SIGN, msg)
		else
			local commodityId = self.signkvpCfg["item"]
			Utils:openView("summon.SummonBuyResourceView", commodityId, goodsCost.num - GoodsDataMgr:getItemCount(goodsCost.id), 14300312)
		end
	end
end

function ActivityDataMgr:revcReceiveReward(event)
	local reward = event.data.rewards;
	if reward and #reward > 0 then
		local id = reward[1].id;
		local itemCfg = GoodsDataMgr:getItemCfg(id);

		if itemCfg.superType ~= EC_ResourceType.HERO then
			Utils:showReward(reward);
		end
	end
end

function ActivityDataMgr:onRecvAllServerAssistanceRank(event)
	local data = event.data
	EventMgr:dispatchEvent(EV_ALLSERVER_ASSISTANCE_RANK, data)
end

function ActivityDataMgr:onRecvAllServerAssistanceProgerss(event)
	local data = event.data
	self.allServerAssistanceScoreData = data
end

function ActivityDataMgr:onRecvAllServerAssistanceAwards(event)
	local data = event.data
	EventMgr:dispatchEvent(EV_ALLSERVER_ASSISTANCE_AWARD, data.type)
	Utils:showReward(data.rewards)
end

function ActivityDataMgr:getAllServerAsScoreData()
	return self.allServerAssistanceScoreData
end

function ActivityDataMgr:checkRedPoint()
    local ret = false;
    for k,v in pairs(self.actList) do
        if self:getIsCanReceive(k) then
            ret = true;
            break;
        end
    end

    if self.sevenExData and self.sevenExData.day > 0 then
	    local sevenExTask_ = TaskDataMgr:getTask(EC_TaskType.SEVENEX)
	    for k,v in pairs(sevenExTask_) do
	        local taskCid = sevenExTask_[k]
	        local taskInfo = TaskDataMgr:getTaskInfo(taskCid)
	        if taskInfo.status == EC_TaskStatus.GET then
	            ret = true
	        end
	    end
	end

    -- 圣诞签到
    local activity = ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.CHRISTMAS_SIGN)
    if #activity > 0 then
        if ActivityDataMgr2:isShowRedPoint(activity[1]) then
            ret = true
        end
    end

	--萌新召唤
	local noobInfo = SummonDataMgr:getNoobInfo()
	if noobInfo and noobInfo.awardState == 1 then
		ret = true
	end
	
	if TaskDataMgr:isCanReceiveTask(TabDataMgr:getData("Investor",1).taskType) then
		ret = true
	end
	-- if RechargeDataMgr:isMonthCardCanSign() then
	-- 	ret = true
	-- end

	local activityId =  ActivityDataMgr2:getActivityInfoByType(EC_ActivityType2.NEWGIFT_PACK_EN)[1]
    if activityId and ActivityDataMgr2:isCanGet(activityId) then
        ret = true
     end

    local giftData = RechargeDataMgr:getGiftSingleData(101)
    if giftData  then 
    	local cnt =  RechargeDataMgr:getBuyCount(101)
		if cnt < giftData.buyCount then 
			if not GlobalVarDataMgr:getValue(GV_LUXURY_RECHARGE) then 
				ret = true
			end
		end
    end

    return ret;
end

function ActivityDataMgr:getSevenExData()
	local sevenExTask_ = TaskDataMgr:getTaskCfgByType(EC_TaskType.SEVENEX);
	local ret = {};
  local serverTime = ServerDataMgr:getServerTime()
	for k,v in pairs(sevenExTask_) do
    	ret[v.acceptParams.day] = ret[v.acceptParams.day] or {}

      if self.sevenExData.state == 1 then    -- 新玩家
          if v.acceptParams.acceptType then
          else
              table.insert(ret[v.acceptParams.day],v.id)
          end
      else
          table.insert(ret[v.acceptParams.day],v.id)
      end
	end
	return ret;
end

function ActivityDataMgr:revcSevenExList(event)
	self.sevenExData = event.data;
end

function ActivityDataMgr:checkSevenExEnable()
	return self.sevenExData and self.sevenExData.day > 0 or false
end

function ActivityDataMgr:getSevenExCurDayTag()
	return self.sevenExData.day;
end

function ActivityDataMgr:isSevenExGiftCanBuy(dayTag)
	local day = dayTag;
	local his = self.sevenExData.storeList;
	if not his  then
		return true;
	end

	local isFind = false
	if his then
		for k,v in pairs(his) do
			if v.storeId == day then
				local dayCfg = TabDataMgr:getData("SevenGift",day);
				if v.num < dayCfg.paytimes then
					return true;
				end

				isFind = true
			end
		end
	end

	return not isFind;
end

function ActivityDataMgr:addSevenExBuyTimes(dayTag)
	local day = dayTag;
	if not self.sevenExData then
		local t = {}
		t.num = 1;
		t.storeId = dayTag
		self.sevenExData = {}
		self.sevenExData.storeList = {};
		table.insert(self.sevenExData.storeList,t);
		return
	end

	local his = self.sevenExData.storeList;
	local isFind = false
	if his then
		for k,v in pairs(his) do
			if v.storeId == day then
				v.num = v.num + 1;
				isFind = true
			end
		end
	end

	if not isFind then
		if self.sevenExData.storeList then
			local t = {}
			t.num = 1;
			t.storeId = dayTag
			table.insert(self.sevenExData.storeList,t);
		end
	end

	if not self.sevenExData.storeList then
		local t = {}
		t.num = 1;
		t.storeId = dayTag
		self.sevenExData.storeList = {};
		table.insert(self.sevenExData.storeList,t);
		return
	end
end

function ActivityDataMgr:getChristmasSignInFlag()
    return self.christmsSignInFlag_
end

function ActivityDataMgr:setChristmasSignInFlag(flag)
    self.christmsSignInFlag_ = flag
end

function ActivityDataMgr:buySevenExGift(dayTag)
	local msg = {
		dayTag
	}
	self.dayTag = dayTag
	TFDirector:send(c2s.SIGN_REQ_PURCH_STORE, msg);
end

function ActivityDataMgr:revcBuySevenExGift(event)
	local curDayTag = self.dayTag--self:getSevenExCurDayTag();
    local curDayCfg = TabDataMgr:getData("SevenGift",curDayTag);
    local item = curDayCfg.item;
    local rewards = {}
    local itemId
    for k,v in pairs(item) do
    	local reward = {};
    	reward.id = k;
    	itemId = k
    	reward.num = v;
    	table.insert(rewards,reward);
    end

    local itemCfg = TabDataMgr:getData("Item",itemId);
    local rewardsItem = {}
    local item = itemCfg.useProfit.fix.items
    for k,v in pairs(item) do
    	local rewardItem = {};
    	rewardItem.id = v.id;
    	rewardItem.num = v.num;
    	table.insert(rewardsItem,rewardItem);
    end

    Utils:showReward(rewardsItem);
    self:addSevenExBuyTimes(self.dayTag)
    EventMgr:dispatchEvent(EV_TASK_UPDATE)
    self.dayTag = nil
end

-- 是否激活萌新手册
function ActivityDataMgr:isActivateNewPlayerBook()
	local cfg = TabDataMgr:getData("NoviceTask")
	local isActivate = true
	for i, v in pairs(cfg) do
		local statusInfo = TaskDataMgr:getTaskInfo(v.id)
		if not statusInfo then
			isActivate = false
			break
		end
	end
	return false --isActivate
end

-- 是否完成萌新手册
function ActivityDataMgr:isCompleteAllNewPlayerBook()
	local cfg = TabDataMgr:getData("NoviceTask") 
	local isCompleteAll = true
	for i, v in pairs(cfg) do
		local statusInfo = TaskDataMgr:getTaskInfo(v.id)
		if not statusInfo then
			isCompleteAll = false
			break
		end
		if statusInfo.status ~= EC_TaskStatus.GETED then
			isCompleteAll = false
			break
		end
	end
	return isCompleteAll
end

function ActivityDataMgr:isNewPlayerBookRedShow()
	local groupNovice = {}
	local isRedShow = false
	local taskCfg = TabDataMgr:getData("NoviceTask")
	for i, cfg in pairs(taskCfg) do
		if not groupNovice[cfg.taskGroup] then
			groupNovice[cfg.taskGroup] = {}
		end
		table.insert(groupNovice[cfg.taskGroup], cfg)
	end
	table.sort(groupNovice, function(a, b)
		return a[1].taskGroup < b[1].taskGroup 
	end)

	local curUnLockGroup = 1
	for group, v in pairs(groupNovice) do
        local _bool = false
        for i, cfg in ipairs(v) do
			local _status = EC_TaskStatus.ING
			local statusInfo = TaskDataMgr:getTaskInfo(cfg.id)
            if statusInfo then
                _status = statusInfo.status
            end
            if _status == EC_TaskStatus.ING or group == table.count(groupNovice) then
                curUnLockGroup = group
                _bool = true
				break
            end
        end
        if _bool then
            break
        end
	end 

	for i, cfg in pairs(taskCfg) do
		local _status = EC_TaskStatus.ING
		local statusInfo = TaskDataMgr:getTaskInfo(cfg.id)
		if statusInfo then
			_status = statusInfo.status
		end
		if _status == EC_TaskStatus.GET and cfg.taskGroup <= curUnLockGroup then
			isRedShow = true
			break
		end
	end 

	return isRedShow, curUnLockGroup
end

function ActivityDataMgr:revcNewYear(event)
	dump(event.data.url)
	--Utils:showWebView(event.data.url,nil,true);
	TFDeviceInfo:openUrl(event.data.url);
end

function ActivityDataMgr:sendNewYear()
	TFDirector:send(c2s.ACTIVITY_REQ_NEW_YEAR_WELFARE_URL, {});
end 

function ActivityDataMgr:sendWORLD_HELP_REQ_RANK_INFO(_type)
	TFDirector:send(c2s.WORLD_HELP_REQ_RANK_INFO, {_type})
end

function ActivityDataMgr:sendWORLD_HELP_REQ_REWARD_RECORD()
	TFDirector:send(c2s.WORLD_HELP_REQ_REWARD_RECORD, {});
end

function ActivityDataMgr:sendWORLD_HELP_REQ_TAKE_REWARD(index, type)
	TFDirector:send(c2s.WORLD_HELP_REQ_TAKE_REWARD, {index - 1, type});
end
return ActivityDataMgr:new()
