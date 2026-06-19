--!native
--!strict
--!optimize 2

local State = require(script.Parent.Parent.Parent.state)
local Fusion = require(script.Parent.Parent.Parent.Packages.Fusion)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local StudioComponents = script.Parent.Parent.Parent.Components:FindFirstChild("StudioComponents")
local Checkbox = require(StudioComponents.Checkbox)
local Label = require(StudioComponents.Label)
local VerticalCollapsibleSection = require(StudioComponents.VerticalCollapsibleSection)

local SharedComponents = require(script.Parent.Parent.SharedComponents)

local MoreTab = {}

function MoreTab.create(services: any)
	local activeHint = Value("")

	return {
		VerticalCollapsibleSection({
			Text = "Export Options",
			Collapsed = false,
			LayoutOrder = 1,
			[Children] = {
				Checkbox({
					Value = State.enableFileExport,
					Text = "Enable File Export",
					LayoutOrder = 1,
					OnChange = function(enabled: boolean): nil
						State.enableFileExport:set(enabled)
						services.plugin:SetSetting("EnableFileExport", enabled)
						return nil
					end,
					[OnEvent("MouseEnter")] = function()
						activeHint:set("Allows importing animations from files.")
					end,
					[OnEvent("MouseLeave")] = function()
						activeHint:set("")
					end,
				}),
				Checkbox({
					Value = State.enableClipboardExport,
					Text = "Enable Clipboard Export",
					LayoutOrder = 2,
					OnChange = function(enabled: boolean): nil
						State.enableClipboardExport:set(enabled)
						services.plugin:SetSetting("EnableClipboardExport", enabled)
						return nil
					end,
					[OnEvent("MouseEnter")] = function()
						activeHint:set("Allows importing animations from the clipboard.")
					end,
					[OnEvent("MouseLeave")] = function()
						activeHint:set("")
					end,
				}),
			},
		}) :: any,
		VerticalCollapsibleSection({
			Text = "Live Sync Options",
			Collapsed = false,
			LayoutOrder = 2,
			[Children] = {
				Checkbox({
					Value = State.enableLiveSync,
					Text = "Enable Live Sync",
					LayoutOrder = 1,
					OnChange = function(enabled: boolean): nil
						State.enableLiveSync:set(enabled)
						services.plugin:SetSetting("EnableLiveSync", enabled)
						if not enabled then
							services.maxSyncManager:stopLiveSyncing()
						end
						return nil
					end,
					[OnEvent("MouseEnter")] = function()
						activeHint:set("Automatically syncs animations from Max to Roblox.")
					end,
					[OnEvent("MouseLeave")] = function()
						activeHint:set("")
					end,
				}),
				Checkbox({
					Value = State.autoConnectToMax,
					Text = "Auto-connect to Max",
					LayoutOrder = 2,
					OnChange = function(enabled: boolean): nil
						State.autoConnectToMax:set(enabled)
						services.plugin:SetSetting("AutoConnectToMax", enabled)
						return nil
					end,
					[OnEvent("MouseEnter")] = function()
						activeHint:set("Connects to Max automatically when the plugin opens.")
					end,
					[OnEvent("MouseLeave")] = function()
						activeHint:set("")
					end,
				}),
				Checkbox({
					Value = State.reducedMotion,
					Text = "Reduced Motion",
					LayoutOrder = 3,
					OnChange = function(enabled: boolean): nil
						State.reducedMotion:set(enabled)
						services.plugin:SetSetting("ReducedMotion", enabled)
						return nil
					end,
					[OnEvent("MouseEnter")] = function()
						activeHint:set("Disables most UI motion animations.")
					end,
					[OnEvent("MouseLeave")] = function()
						activeHint:set("")
					end,
				}),
			},
		}) :: any,
		SharedComponents.AnimatedHintLabel({
			Text = activeHint,
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 0),
			TextWrapped = true,
			ClipsDescendants = true,
			Visible = true,
			TextTransparency = 0,
			RichText = true,
		}),
		VerticalCollapsibleSection({
			Text = "About",
			Collapsed = true,
			LayoutOrder = 5,
			[Children] = {
				Label({
					LayoutOrder = 1,
					Text = "Run the 3ds Max companion plugin first, then connect from Max Sync.",
					TextWrapped = true,
				}),
			},
		}) :: any,
	}
end

return MoreTab
