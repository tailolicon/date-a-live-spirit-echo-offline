#!/usr/bin/env python3
"""Compatibility launcher for the MainScene regression path."""
from stateful_handlers import FIRST_PLOT_LEVEL, encode_dungeon_level_info
import tcp_server as base

__all__ = ["FIRST_PLOT_LEVEL", "encode_dungeon_level_info"]

if __name__ == "__main__":
    base.main()
