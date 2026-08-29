#!/usr/bin/env python3
"""Story ("dating") stages: handing the client the script to play (s2c 1542).

Half of Volume 1 is not a battle. `DungeonLevel.dungeonType = DATING` stages -
1-2 and 1-3, for two - run a visual-novel script instead, and
`FubenDataMgr:onRecvFightStart` routes them to
`DatingDataMgr:sendGetSciptMsg(FUBEN_SCRIPT, ..., levelCfg.datingID[1])`
rather than into BattleController.

That request is c2s 1537, whose *reply* carries nothing: the script arrives on
a separate push, s2c 1542 DATING_DATING_SCRIPT, and `datingScriptMsgHandle`
is what opens the dating layer. Answering only 1537 therefore looks like a
correct, empty reply and leaves the stage dead on the map - the client asked,
got an ack, and nothing ever opened.

`DatingRule[cid].start_node_id` is where the script begins; the client walks it
from there through its own shipped dialogue tables, so the server only has to
name the rule and say whether this is a first run.
"""
from __future__ import annotations

from typing import Any

from game_static_config import GameStaticConfig, StaticConfigUnavailable, config as static_config
from player_save import save as persist
from protocol_schema import decode_request, encode_response

DATING_GET_SCRIPT = 1537
DATING_DIALOGUE = 1538
DATING_DATING_SETTLEMENT = 1540
DATING_DATING_SCRIPT = 1542

DATING_PROTOCOLS = frozenset({DATING_GET_SCRIPT, DATING_DIALOGUE})

# EC_DatingScriptType.FUBEN_SCRIPT - a story stage opened from the instance map.
FUBEN_SCRIPT = 7


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _active_rule(state: dict[str, Any]) -> int:
    raw = state.get("activeDatingRule")
    return _as_int(raw) if raw is not None else 0


def _seen_scripts(state: dict[str, Any]) -> list[int]:
    raw = state.setdefault("datingScriptsSeen", [])
    if not isinstance(raw, list):
        state["datingScriptsSeen"] = raw = []
    return raw


def dating_script(state: dict[str, Any], rule_cid: int,
                  cfg: GameStaticConfig | None = None) -> tuple[dict[str, Any] | None, bool]:
    """s2c 1542 for one DatingRule, plus whether the save changed."""
    if rule_cid <= 0:
        return None, False
    cfg = cfg or static_config()
    try:
        rule = cfg.dating_rule(rule_cid)
    except StaticConfigUnavailable:
        rule = None
    if rule is None or _as_int(rule.get("startNodeId")) <= 0:
        # Not a script we can name a start node for: stay silent rather than
        # opening a dating layer on a nil rule row.
        return None, False

    seen = _seen_scripts(state)
    is_first = rule_cid not in [_as_int(value) for value in seen]
    if is_first:
        seen.append(rule_cid)
    # c2s 1538 carries the node, not the script it belongs to, so the run has
    # to be remembered here for the settlement to be able to name it.
    state["activeDatingRule"] = rule_cid
    return {
        "datingRuleCid": rule_cid,
        # Branch choices are pushed as the script reaches them; a run that has
        # just started has none outstanding.
        "branchNodes": [],
        "isFirst": is_first,
        "datingId": "",
    }, is_first


def dating_settlement(state: dict[str, Any], request: dict[str, Any]) -> dict[str, Any] | None:
    """s2c 1540, pushed when the script reports its last node.

    `DatingScriptView:showComplete` waits on this to build the result view, and
    for a story stage (`finallyType = 1`) that view is `dating.SettlementLayer`
    - whose close button is what finally sends DUNGEON_FIGHT_OVER. Skip the
    push and the stage plays through and then simply stops on its last line,
    never clearing.
    """
    if not request.get("isLastNode"):
        return None
    rule_cid = _active_rule(state)
    if rule_cid <= 0:
        return None
    state.pop("activeDatingRule", None)
    return {
        "score": 0,
        "favor": 0,
        # A story stage pays out through its own DUNGEON_FIGHT_OVER drop, not
        # here; `datingSettlementMsgHandle` only needs the run identified.
        "rewards": [],
        "scriptId": rule_cid,
        "starList": [],
        "obsolete": False,
        "endId": _as_int(request.get("selectedNodeId")),
    }


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto not in DATING_PROTOCOLS:
        return None
    if proto == DATING_DIALOGUE:
        return encode_response(proto, {"score": 0}), False
    return encode_response(proto), False


def extra_packets(state: dict[str, Any], proto: int, body: bytes) -> tuple[tuple[int, bytes], ...]:
    request = decode_request(proto, body)
    if proto == DATING_GET_SCRIPT:
        values, _ = dating_script(state, _as_int(request.get("scriptId")))
        if values is None:
            return ()
        return ((DATING_DATING_SCRIPT, encode_response(DATING_DATING_SCRIPT, values)),)
    if proto == DATING_DIALOGUE:
        values = dating_settlement(state, request)
        if values is None:
            return ()
        return ((DATING_DATING_SETTLEMENT,
                 encode_response(DATING_DATING_SETTLEMENT, values)),)
    return ()


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    if proto not in DATING_PROTOCOLS:
        return False
    request = decode_request(proto, body)
    if proto == DATING_GET_SCRIPT:
        values, mutated = dating_script(client.save, _as_int(request.get("scriptId")))
        follow = ((DATING_DATING_SCRIPT, encode_response(DATING_DATING_SCRIPT, values)),)             if values is not None else ()
        reply = encode_response(proto)
    else:
        values = dating_settlement(client.save, request)
        mutated = values is not None
        follow = ((DATING_DATING_SETTLEMENT,
                   encode_response(DATING_DATING_SETTLEMENT, values)),) if values else ()
        reply = encode_response(proto, {"score": 0})
    if mutated:
        persist(client.save)
    client.send_pkt(proto, reply)
    for pid, payload in follow:
        client.send_pkt(pid, payload)
    return True
