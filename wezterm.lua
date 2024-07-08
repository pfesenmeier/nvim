-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- TODO put env.lua, this file into folder, symlink to destination
-- require'env.lua'
--
-- local nubin
-- if Env.islinux then
--     nubin =  '/home/linuxbrew/.linuxbrew/bin/nu'
-- end
--
-- config.default_prog = { nubin }

-- This will hold the configuration.
local config = wezterm.config_builder()

wezterm.font("CaskaydiaCove Nerd Font Mono", {weight="Regular", stretch="Normal", style="Normal"})
wezterm.font("JetBrains Mono", {weight="DemiBold", stretch="Normal", style="Normal"})
config.color_scheme = 'deep'
config.window_background_opacity = 0.8
config.font_size = 14.0


return config
