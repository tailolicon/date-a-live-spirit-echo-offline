#!/usr/bin/env python3
"""Battle attributes for a hero on the wire.

`Property:init` takes a hero's stats straight from the `attr` list the server
sent - unlike a monster, nothing is derived client-side. A hero with an empty
`attr` therefore enters battle with 0 max HP and dies on the first frame, so
every stage that fights with the player's *own* formation (`heroLimitType = 0`,
which is most of the game past Volume 1's opening) needs this filled in.

The numbers come from HeroProgress, indexed the way the client's own
StrengthenResult view reads them back: `baseAttr` at the strengthen row and
`upAttr` at the quality row, combined as `base + growth * level`.
"""
from __future__ import annotations

from typing import Any

from game_static_config import GameStaticConfig, StaticConfigUnavailable, config as static_config


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def battle_attributes(hero: dict[str, Any], cfg: GameStaticConfig | None = None) -> list[dict[str, int]]:
    """The `attr` rows for one hero, honouring an explicit override in the save."""
    explicit = hero.get("attr")
    if isinstance(explicit, list) and explicit:
        # A hand-edited save wins: this is the escape hatch for experiments.
        return [row for row in explicit if isinstance(row, dict)]
    cid = _as_int(hero.get("cid"))
    if cid <= 0:
        return []
    try:
        cfg = cfg or static_config()
        return cfg.hero_attributes(
            cid,
            max(1, _as_int(hero.get("lvl"), 1)),
            quality=max(0, _as_int(hero.get("quality"))),
            advanced_level=max(0, _as_int(hero.get("advancedLvl"))),
        )
    except StaticConfigUnavailable:
        return []
    except AttributeError:
        # Handlers accept an injected config provider; one that only models the
        # cost tables has no stats to give, and that is not an error.
        return []
