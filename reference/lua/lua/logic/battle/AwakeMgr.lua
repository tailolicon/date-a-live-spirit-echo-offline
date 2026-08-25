local BattleUtils = import(".BattleUtils")
local BattleConfig = import(".BattleConfig")
local ResLoader   = import(".ResLoader")
local Actor       = import(".Actor")
local enum        = import(".enum")
local eEvent      = enum.eEvent
local eDir         = enum.eDir
local eCameraFlag = enum.eCameraFlag
local eBuffStateType = enum.eBuffStateType

local FRAME_EVENT =
{
    EVENT_MUSIC = "music", --音效
    EVENT_STAND = "events_stand",
    EVENT_HURT  = "events_hurt",
    EVENT_FLOAT = "events_float",
    EVENT_FLOOR = "events_floor",
    EVENT_DIE2  = "events_die2",
    EVENT_WHITE = "events_white",
    EVENT_TARGET_BLACK     = "events_target_black",     --角色变黑
    EVENT_TARGET_BLACK_END = "events_target_black_end"  --角色变黑结束
}

--觉醒动画管理
local AwakeMgr = {}
local this = AwakeMgr
function AwakeMgr.init()
    if this.isInit then return end
    --主节点
    this.size     = me.size(me.EGLView:getDesignResolutionSize())
    this.rootNode = CCNode:create()
    this.rootNode:setSize(this.size)
    this.rootNode:retain()
    this.bPlay   = false
    this.isInit  = true
end

function AwakeMgr.createEffect(data,callFunc)
    local skeletonNodeList = {}
    local node = CCNode:create()
    node:setPosition(me.p(this.size.width/2,this.size.height/2))
    --下层
    for key , effect in ipairs(data.effectsDown) do
        local animation = effect.animation
        animation = string.format("effect/%s/%s",animation,animation)
        local skeletonNode = ResLoader.createSkeletonAnimation(animation,1)
        skeletonNode:play(effect.action, false)
        node:addChild(skeletonNode)
        table.insert(skeletonNodeList,skeletonNode)
    end
    --创建人物
    if data.showAction then
        local animation= data.showAction.animation
        animation = string.format("effect/%s/%s",animation,animation)
        local skeletonNode = ResLoader.createSkeletonAnimation(animation,1)
        skeletonNode:play(data.showAction.action, false)
        node:addChild(skeletonNode)
        table.insert(skeletonNodeList,skeletonNode)
    end
    --上层
    for key , effect in ipairs(data.effectsUp) do
        local animation= effect.animation
        animation = string.format("effect/%s/%s",animation,animation)
        local skeletonNode = ResLoader.createSkeletonAnimation(animation,1)
        skeletonNode:play(effect.action, false)
        node:addChild(skeletonNode)
        table.insert(skeletonNodeList,skeletonNode)
    end
    local  count = #skeletonNodeList

    local function _callFunc(skeletonNode)
        skeletonNode:removeMEListener(TFARMATURE_COMPLETE)
        count = count - 1
        if count == 0 then
            callFunc()
        end
    end
    for i, skeletonNode in ipairs(skeletonNodeList) do
        skeletonNode:addMEListener(TFARMATURE_COMPLETE,_callFunc)
    end
    return node
end

function AwakeMgr.createVideo(data,callFunc)
    local videoPlayer_ = VlcPlayer:create({
        filePath = data.showVideo,
        forceVLC = true,
        viewSize = this.size,
        onVideoPlayComplete = callFunc
        })

    videoPlayer_:setPosition(ccp(0 ,0))
    videoPlayer_:play()
    return videoPlayer_
end


function AwakeMgr.play(showData,flipX,host)
    -- if this.bPlay then return end
    this.host = host
    this.data = showData
    battleController.pause()
    this.init()
    --觉醒技能展示类型：0或者不配置播放特效 ,1播放视频
    --this.data.showType  = 1
    --this.data.showVideo = "video/summon_juya2.mp4"
    local node
    if this.data.showType == 1 then 
        node = this.createVideo(this.data,this.onPlayEnd)
    else
        node = this.createEffect(this.data,this.onPlayEnd)
        if this.data.detection then
            if flipX then
                node:setScaleX(-1)
            end
        end
        --播音效
        if ResLoader.isValid(this.data.showSound) then
            BattleUtils.playEffect(this.data.showSound)
        end
    end

    this.rootNode:addChild(node)
    EventMgr:dispatchEvent(eEvent.EVENT_SHOW_AWAKE,this.rootNode)
end


function AwakeMgr.onPlayEnd()
    this.clean()
    EventMgr:dispatchEvent(eEvent.EVENT_HIDE_AWAKE,this.rootNode)
    local skipGame = TONUMBER(this.data.skipGame) 
    if not this.host:isAssist() and skipGame > 0  then --非助战角色才能进入小游戏
        --连接小游戏
        local MusicGame = require("lua.logic.battle.MusicGame")
        local musicGame = MusicGame:new(skipGame,this.host)
        AlertManager:addLayer(musicGame,AlertManager.BLOCK)
        AlertManager:show()
    else
        battleController.resume()
    end
end


function AwakeMgr.isPlay()
    return this.bPlay
end
function AwakeMgr.clean()
    -- this.stopTimer()
    if this.rootNode then
        this.rootNode:removeAllChildren()
        this.rootNode:removeFromParent()
        this.rootNode:release()
        this.rootNode = nil
    end
    this.bPlay   = false
    this.isInit = false
end

return AwakeMgr


---[[

--地图
--动画层


--]]
