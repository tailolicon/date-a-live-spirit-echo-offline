
local BaseDataMgr = import(".BaseDataMgr")

local UserDefalt = CCUserDefault:sharedUserDefault()
local ServerDataMgr = class("ServerDataMgr", BaseDataMgr)

function ServerDataMgr:init()
    self.serverTime_ = 0
    self.onlineTime_ = 0
    self.localTime_ = 0


    self.debugLoginServers = {
        -- [1] = {
        --     sort  = 2,
        --     group = "bt_area_develop",
        --     name  = "bt_develop",
        --     url   = "http://192.168.40.91:8081/account",
        -- },
        -- [2] = {
        --     sort  = 3,
        --     group = "bt_area_test",
        --     name  = "bt_test",
        --     url   = "http://43.138.118.87:7070/account"
        -- }

        [1] = {
            sort = 1,
            group = "us_develop",
            name = "us_develop",
            url =  "http://192.168.38.150:8081/account"
        },
        [2] = {
            sort = 1,
            group = "us_develop_hy",
            name = "us_develop_hy",
            url =  "http://192.168.38.150:8081/account"
        },

        [3] = {
            sort = 2,
            group = "us",
            name = "us",
            url =  "https://dal-login-us.heitaoglobal.com:8082/account"
        },
        [4] = {
            sort = 3,
            group = "us_test",
            name = "us_test",
            url =  "http://43.130.144.246:7070/account"
        },
    }

    TFDirector:addProto(s2c.LOGIN_RESP_SERVER_TIME, self, self.onRecvServerTime)
    --游戏服列表
    self.gameServers = {}
    --游戏服分区信息
    self.areas       = {}
    --当前选中的服务器基础信息
    self.serverInfo  = nil
    --当前游戏服数据
    self.serverData = nil

    --测试服分组
    self.serverGroup_ = nil

    self:loadLocalData()
end



function ServerDataMgr:setServerData(serverData)
    self.serverData = serverData
    dump(self.serverData)

                 -- "gameServerIp"   = "192.168.38.88"
                 -- "gameServerPort" = 10086
                 -- "groupName"      = "约战BT1"
                 -- "group_id"       = 101
                 -- "hasRole"        = false
                 -- "serverId"       = 101001
                 -- "tip"            = 0
                 -- "token"          = "101_dbe78ed76fa2aa664b405345809a6d26"
end

function ServerDataMgr:getServerData()
    return self.serverData
end


function ServerDataMgr:getServerGroupID()
    if self.serverData then
        return self.serverData.group_id or 1
    end
    return 1
end

function ServerDataMgr:getServerID_()
    if self.serverData then
        return self.serverData.serverId or 1
    end
    return 1
end


function ServerDataMgr:getServerName_()
    local serverName = ""
    if self.serverData then
        if not string.isNullOrEmpty(self.serverData.showServerName) then 
            serverName = self.serverData.showServerName
        else
            local cfg = self:getServerCfg(self.serverData.serverId)
            if cfg then 
               serverName =  self:getText(cfg.serverName)
            end
        end
        serverName = string.gsub(serverName,"\\n","")
        serverName = string.gsub(serverName,"\n","")
    end
    print("serverName_:" ..tostring(serverName))
    
    return serverName

end







-- [[登录服开始]]--
function ServerDataMgr:reset()

end

function ServerDataMgr:onLoginOut()

end

function ServerDataMgr:onLogin()
    self:timerOnlineFunc()
end

function ServerDataMgr:initServerTime(time)
    self.serverTime_ = time
    self.localTime_ = os.time()
end

--使用登录前的时间作为服务器时间
function ServerDataMgr:__initBeforeLoginServerTime()
    --登录前的服务器时间
    if MainPlayer and MainPlayer.serverTime then 
        self.serverTime_ = MainPlayer.serverTime
        self.localTime_  = MainPlayer.localtime
    end
    print("使用登录前的时间作为服务器时间")
end


function ServerDataMgr:getServerTime()
    if self.serverTime_ == 0 then 
        self:__initBeforeLoginServerTime()
    end
    local serverTime = self.serverTime_ + (os.time() - self.localTime_)
    return serverTime
end

function ServerDataMgr:getOnlineTime()
    return self.onlineTime_
end
    
function ServerDataMgr:timerOnlineFunc()
    if not self.timer_ then
        self.timer_ = TFDirector:addTimer(1000, -1, nil, function()
            self.onlineTime_ = self.onlineTime_ + 1
        end)
    end
end

function ServerDataMgr:onRecvServerTime(event)
    local data = event.data
    self:initServerTime(data.serverTime)
end



function ServerDataMgr:getServerGroup()
    return self.serverGroup_
end

function ServerDataMgr:setServerGroup(serverGrop)
    self.serverGroup_ = serverGrop
end

function ServerDataMgr:getDebugServer()
    for i,v in ipairs(self.debugLoginServers) do
        if v.group == self.serverGroup_ then 
            return v
        end
    end
end

function ServerDataMgr:getDebugServers()
    return self.debugLoginServers
end


-- [[登录服结束]]--

-- [[游戏服开始]]--

function ServerDataMgr:setGameServerList(serverData)
    self.gameServers = serverData or {}

    --TODO 测试复制数据
    -- for i=2,10 do
    --     self.gameServers[i] = clone(self.gameServers[1])
    --     self.gameServers[i].serverName = "天宫测试服"..i
    --     --self.gameServers[i].serverId   = self.gameServers[i].serverId + i
    -- end

    self:readyServers()
end


--服务器分组数据
function ServerDataMgr:getAreas()
    return self.areas
end


    -- [7043] = {
    --     id = 7043,
    --     showAreaId = "天宫五区",
    --     showServerId = 43,
    --     AreaId = 5,
    -- },
    -- [888] = {
    --     id = 888,
    --     showAreaId = "天宫十区",
    --     showServerId = 888,
    --     AreaId = 10,
    -- },

--       "serverInfos" = {
-- [LUA-print] [04/10/24 11:36:50]  -             1 = {
-- [LUA-print] [04/10/24 11:36:50]  -                 "areaId"        = 2
-- [LUA-print] [04/10/24 11:36:50]  -                 "lastLoginTime" = 0
-- [LUA-print] [04/10/24 11:36:50]  -                 "serverId"      = 7002
-- [LUA-print] [04/10/24 11:36:50]  -                 "serverName"    = "bt_area_game2"
-- [LUA-print] [04/10/24 11:36:50]  -                 "show"          = 1
-- [LUA-print] [04/10/24 11:36:50]  -                 "showAreaId"    = 123
-- [LUA-print] [04/10/24 11:36:50]  -                 "state"         = 0
-- [LUA-print] [04/10/24 11:36:50]  -             }



--根据serverID 进行分区
function ServerDataMgr:getServerCfg(serverId)

    local cfgs = TabDataMgr:getData("GroupName")
    local cfg  = cfgs[serverId]

    if not cfg then 
        local defaultCfg =  cfgs[888]
        cfg = {}
        cfg.serverName     = tostring(serverId)                      --"怀\n旧\n"..tostring(serverId).."\n服"    --defaultCfg.serverName
        cfg.areaName       = defaultCfg.areaName
        cfg.areaId         = defaultCfg.areaId
    end
    return cfg
end

function ServerDataMgr:getText(id,...)
    return TextDataMgr:getText(id, ...) 
end
--分组 ，组织服务器数据
function ServerDataMgr:readyServers()
    --组织分区信息
    local areas = {}
    for i,v in ipairs(self.gameServers) do
         v.lastLoginTime = v.lastLoginTime or 0
        local cfg        = self:getServerCfg(v.serverId)
        if not string.isNullOrEmpty(v.showServerName) then  --后台未配置的情况下使用配置表名称
            v.serverName = string.gsub(v.showServerName,"\\n","\n")
        else 
            v.serverName = self:getText(cfg.serverName)
        end
        v.areaName       =  self:getText(cfg.areaName)
        local areaId     = cfg.areaId
        local areaName   = v.areaName
        v.new = nil
        if v.show == 1 then --显示
            local area        = areas[areaId] 
            if not area then 
                area          = {}
                area.id       = areaId
                area.name     = areaName
                area.servers  = {}
                areas[areaId] = area
            end
            table.insert(area.servers ,v)
        end
    end

    --按serverId 排序越大表是约新
    table.sort(self.gameServers,function (a , b)
        return a.serverId > b.serverId
    end)
    for i,v in ipairs(self.gameServers) do
        v.new = true
        if i >= 2 then --最大的2个ID 为新服
            break
        end
    end

    --最近登录（虚拟分区）
    local historyArea = 
    {
        id      = 999999,
        name    = self:getText(18000371) , -- "最近登录"
        servers = {}
    }
    --按登录时间排序找到最近登录的服务器
    table.sort(self.gameServers,function (a , b)
        return a.lastLoginTime > b.lastLoginTime
    end)
    for i,v in ipairs(self.gameServers) do
        if v.lastLoginTime <= 0 then 
            break
        end
        if v.show == 1 then 
            table.insert(historyArea.servers,v)
        end
        if i >= 5 then --最近登录只显示最近5登录过的5个 
            break
        end
    end

    --分区
    self.areas   = {}
    if #historyArea.servers > 0 then -- 有最近登录的才显示最近登录分组
        table.insert(self.areas ,historyArea)
    end
    --dump(self.areas)
    for k,v in pairs(areas) do
        table.sort(v.servers,function (a , b)
            return a.serverId < b.serverId
        end)
        table.insert(self.areas ,v)
    end

    --分区排序处理
    table.sort(self.areas,function (a , b)
        return a.id > b.id
    end)
    --dump(self.areas[2])

    --默认选中最后登录的服务器
    if #historyArea.servers > 0 then
        self:setServerInfo(historyArea.servers[1])
    elseif #self.areas > 0 then  --找最新的
        local find = false
        --dump(self.areas)
        for i, _area in ipairs(self.areas) do
            for k = #_area.servers, 1, -1 do
                local _server = _area.servers[k]          
                if _server.state == 0 then 
                    self:setServerInfo(_server)
                    dump(_server)
                    find = true
                    break
                end 
            end
            if find then 
                break
            end
        end
        --没有找的
        if not find then
            print("未找到可用服务器使用默认")
            local __servers = self.areas[1].servers
            self:setServerInfo(__servers[1])
        end
    end
    --dump(self.gameServers)
end


function ServerDataMgr:getGameServerList()
    return self.gameServers
end


--设置当前选中服务器
function ServerDataMgr:setServerInfo(serverInfo)
    self.serverInfo = serverInfo
    EventMgr:dispatchEvent(EV_GAMESERVER_REFRESH)
end

--当前选中服务器的信息
function ServerDataMgr:getServerInfo()
    return self.serverInfo
end

function ServerDataMgr:getCurrentServerID()    
    if self.serverInfo then
        return self.serverInfo.serverId
    end
    return -1
end


--登录成功保存数据到本地方便下次直接登录
function ServerDataMgr:saveToLocal(account ,password)
    self.account_   = account
    self.password_  = password
    UserDefalt:setStringForKey("account",self.account_ )
    UserDefalt:setStringForKey("password",self.password_)
    UserDefalt:setStringForKey("serverGroup",self.serverGroup_)
    UserDefalt:flush()
end

function ServerDataMgr:loadLocalData()
    self.account_      = UserDefalt:getStringForKey("account")
    self.password_     = UserDefalt:getStringForKey("password")
    local serverGroup_ = UserDefalt:getStringForKey("serverGroup")
    self.serverGroup_  = self.debugLoginServers[1].group
    --验证self.serverGroup_ 的合法性
    for i,v in ipairs(self.debugLoginServers) do
        if v.group == serverGroup_ then 
            self.serverGroup_ = serverGroup_
            break
        end
    end
end

function ServerDataMgr:getUserInfo()
    return self.account_ ,self.password_ 
end

function ServerDataMgr:saveIsActivat(isActivat)
    CCUserDefault:sharedUserDefault():setBoolForKey("isActivat",isActivat)
    CCUserDefault:sharedUserDefault():flush()
end

function ServerDataMgr:getIsActivat()
    return CCUserDefault:sharedUserDefault():getBoolForKey("isActivat");
end


function ServerDataMgr:getCurrentServerHasRole(serverId)
    -- if serverId then 
    --     for i, serverInfo in ipairs(self.gameServers) do
    --         if serverInfo.serverId == serverId then 
    --             return serverInfo.hasRole
    --         end
    --     end
    --     return false
    -- 选择服务器
    -- if self.serverInfo then
    --     return self.serverInfo.hasRole
    -- end
    return false
end
-- [[游戏服结束]]--

function ServerDataMgr:getCurServerName()
    if self.serverInfo then 
        local serverName  = string.gsub(self.serverInfo.serverName,"\n","")
        return serverName
       --return string.format("%s  %02d服",self.serverInfo.areaName ,self.serverInfo.serverName)
    end
    return  self:getText(18000372) --"选择服务器"  
end

local DAY_SECONDS = 24*60*60
function ServerDataMgr:lastLoginTip(lastloginTime)
    if lastloginTime and lastloginTime > 0 then 
        local passTime = self:getServerTime() - lastloginTime 
        local value    = math.floor(passTime / DAY_SECONDS)
        if value < 1 then 
            return self:getText(18000373)  --1天内登录
        else
            return self:getText(18000374,value)   -- string.format("%s天前登录",value)
        end
    end
    return ""
end



--转换自定义UTC时区 UTC+8 传入8 UTC-8传入-8 
function ServerDataMgr:customUtcTimeForServer()
    local timeInterval = self:customUtcTimeForServerTimestap(GV_UTC_TIME_ZONE)
    local timeTable = os.date("*t", timeInterval)
    return timeTable.hour , timeTable.min , timeTable.sec
end
function ServerDataMgr:customUtcTimeForServerTimestap( timeZone )
    timeZone = timeZone or GV_UTC_TIME_ZONE
    local serverTime = self.serverTime_ + (os.time() - self.localTime_)
    local timeInterval = os.time(os.date("!*t", serverTime)) + timeZone * 3600 + (os.date("*t", time).isdst and -1 or 0) * 3600  --isdst是否夏令时决定加一或者不加1小时
    return timeInterval
end
function ServerDataMgr:customUtcTimeForServerDate( )
    local timeInterval = self:customUtcTimeForServerTimestap(GV_UTC_TIME_ZONE)
    local timeTable = os.date("*t", timeInterval)
    return timeTable
end

--TODO CLOSE 英文版时间戳换算UTC-7 服务器下发UTC-7时间戳 则本地转换需要同步使用UTC-7计算
function ServerDataMgr:customUtcTimestap(timestamp, timeZone )
    timeZone = timeZone or GV_UTC_TIME_ZONE
    local serverTime = timestamp + (os.time() - self.localTime_)
    local timeInterval = os.time(os.date("!*t", serverTime)) + timeZone * 3600 + (os.date("*t", time).isdst and -1 or 0) * 3600  --isdst是否夏令时决定加一或者不加1小时
    return timeInterval
end



--[[

local zhChar = {'一','二','三','四','五','六','七','八','九'}
local places = {'','十','百','千','万','十','百','千','亿','十','百','千','万'}

function formatNumber( num )
    if  type(num) ~=  'number' then
        return num .. 'is not a num'
    end
    local numStr = tostring(num)
    local len = string.len(numStr)
    local str = ''
    local has0 = false
    for i = 1, len do
        local n = tonumber(string.sub(numStr,i,i))
        local p = len - i + 1
        if n > 0 and has0 == true then --连续多个零只显示一个
            str = str .. '零'
            has0 = false
        end
        if p % 4 == 2 and n == 1 then --十位数如果是首位则不显示一十这样的
            if len > p then
                str = str .. zhChar[n]
            end
            str = str .. places[p]
        elseif n > 0 then 
            str = str .. zhChar[n]
            str = str .. places[p]
        elseif n == 0 then
            if p % 4 == 1 then --各位是零则补单位
                str = str .. places[p]
            else
                has0 = true
            end
        end
    end
    return str
end
--]]
return ServerDataMgr:new()


--TODO  多语言适配