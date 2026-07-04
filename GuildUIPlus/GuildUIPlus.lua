-- GuildUI+ Bootstrap (3.3.5a-compatible)
-- Creates shared namespace table as a global since 3.3.5a addon loader
-- does not pass a shared table via ... (that was added in 4.0+)
-- This file MUST be loaded first.

local ADDON = ...

-- Create the namespace as a global so other files can share it
_G.GuildUIPlus = _G.GuildUIPlus or {}
_G.GuildUIPlus.Loader = nil -- will be set by Loader.lua
_G.GuildUIPlus.Util = nil  -- will be set by Util.lua
_G.GuildUIPlus.Comm = nil  -- will be set by Comm.lua
_G.GuildUIPlus.Settings = nil
_G.GuildUIPlus.UI = nil
_G.GuildUIPlus.Modules = {} -- module registry mirror

-- Version constants
_G.GuildUIPlus.ADDON_NAME = ADDON
_G.GuildUIPlus.VERSION = "1.0.0"
_G.GuildUIPlus.PROTOCOL_VERSION = 1
_G.GuildUIPlus.COMM_PREFIX = "GG1"
