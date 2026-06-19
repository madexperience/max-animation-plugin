--!native
--!strict
--!optimize 2

local State = require(script.Parent.Parent.Parent.state)
local Fusion = require(script.Parent.Parent.Parent.Packages.Fusion)

local New = Fusion.New
local OnChange = Fusion.OnChange
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value
local Computed = Fusion.Computed
local Children = Fusion.Children

local StudioComponents = script.Parent.Parent.Parent.Components:FindFirstChild("StudioComponents")
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local themeProvider = require(StudioComponentsUtil.themeProvider)
local Label = require(StudioComponents.Label)
local LimitedTextInput = require(StudioComponents.LimitedTextInput)
local VerticalCollapsibleSection = require(StudioComponents.VerticalCollapsibleSection)
local Checkbox = require(StudioComponents.Checkbox)
local Slider = require(StudioComponents.Slider)

local SharedComponents = require(script.Parent.Parent.SharedComponents)
local CameraControls = require(script.Parent.Parent.Components.CameraControls)
local KeyframeNaming = require(script.Parent.Parent.Components.KeyframeNaming)
local BoneToggles = require(script.Parent.Parent.Components.BoneToggles)

local function getAnimSizeString(animData: any?): string
	if not animData then
		return "Size: N/A"
	end
	local success, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(animData)
	end)
	if not success or not encoded then
		return "Size: N/A"
	end
	local bytes = #encoded
	if bytes >= 1048576 then
		return string.format("Size: %.1f MB", bytes / 1048576)
	elseif bytes >= 1024 then
		return string.format("Size: %.1f KB", bytes / 1024)
	else
		return string.format("Size: %d B", bytes)
	end
end

local SIMPLIFIER_MAX_DROP_RATIO = 0.75
local SIMPLIFIER_STRENGTH_CURVE = 0.9

local function getSimplifierKeepRatio(strength: number): number
	local t = math.clamp(strength / 100, 0, 1)
	if t <= 0 then
		return 1
	end

	return math.clamp(1 - SIMPLIFIER_MAX_DROP_RATIO * (t ^ SIMPLIFIER_STRENGTH_CURVE), 0.25, 1)
end

local ToolsTab = {}

local function createToolDivider(layoutOrder: number)
	return New("Frame")({
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.Border),
		BorderSizePixel = 0,
	})
end

function ToolsTab.create(services: any)
	local activeHint = Value("")
	local debounceThread: thread? = nil

	local function triggerResimplify()
		if debounceThread then
			pcall(function()
				task.cancel(debounceThread)
			end)
		end
		debounceThread = task.delay(0.15, function()
			debounceThread = nil
			if services and services.animationManager then
				services.animationManager:resimplifyAndPlay()
			end
		end)
	end

	local components = {}


	local cameraControls = CameraControls.createCameraControlsUI(services)
	if cameraControls then
		table.insert(components, cameraControls)
	end

	local keyframeNaming = KeyframeNaming.createKeyframeNamingUI(services, 4)
	if keyframeNaming then
		table.insert(components, keyframeNaming)
		table.insert(components, createToolDivider(5))
	end

	-- Add the Animation Modifiers section
	table.insert(
		components,
		VerticalCollapsibleSection({
			Text = "Animation Modifiers",
			Collapsed = false,
			LayoutOrder = 6,
			[Children] = {
				Label({
					Text = "Animation Resizer (Default: 1)",
					LayoutOrder = 1,
				}),
				LimitedTextInput({
					PlaceholderText = "1",
					Text = Computed(function()
						return tostring(State.scaleFactor:get())
					end),
					LayoutOrder = 2,
					GraphemeLimit = 8,
					[OnChange("Text")] = function(newScaleFactorText)
						local newScaleFactor = tonumber(newScaleFactorText)
						if newScaleFactor then
							if newScaleFactor and newScaleFactor > 0 then
								State.scaleFactor:set(newScaleFactor)
								if State.activeAnimator and services and services.playbackService then
									services.playbackService:playCurrentAnimation(State.activeAnimator)
								end
							end
						end
					end,
					[OnEvent("MouseEnter")] = function()
						activeHint:set(
							"Resizes the animation by a given factor. Useful for scaling animations up or down."
						)
					end,
					[OnEvent("MouseLeave")] = function()
						activeHint:set("")
					end,
				} :: any),
				Label({
					Text = Computed(function()
						local scaleFactor = State.scaleFactor:get()
						local rigScale = State.rigScale:get()
						return string.format("Scale Factor: %.2f | Model Scale: %.2f", scaleFactor, rigScale)
					end),
					LayoutOrder = 3,
				}),
				Label({
					Text = "Simplifier Strength",
					LayoutOrder = 4,
				}),
				Slider({
					LayoutOrder = 5,
					Size = UDim2.new(1, 0, 0, 20),
					Min = 0,
					Max = 100,
					Step = 1,
					Value = State.simplifierStrength,
					OnChange = function(value)
						State.simplifierStrength:set(value)
						triggerResimplify()
					end,
					Enabled = Computed(function()
						return State.simplifierEnabled:get()
					end),
				}) :: any,
				Label({
					Text = Computed(function()
						local strength = State.simplifierStrength:get()
						local enabled = State.simplifierEnabled:get()
						if not enabled then
							return "Simplifier: Off"
						end
						if strength == 0 then
							return "Simplifier: None (0%)"
						elseif strength <= 33 then
							return string.format(
								"Simplifier: Low (%d%%) - keeps ~%.0f%%",
								strength,
								getSimplifierKeepRatio(strength) * 100
							)
						elseif strength <= 66 then
							return string.format(
								"Simplifier: Medium (%d%%) - keeps ~%.0f%%",
								strength,
								getSimplifierKeepRatio(strength) * 100
							)
						else
							return string.format(
								"Simplifier: High (%d%%) - keeps ~%.0f%%",
								strength,
								getSimplifierKeepRatio(strength) * 100
							)
						end
					end),
					LayoutOrder = 6,
				}),
				Label({
					Text = Computed(function()
						local rawData = State.lastRawAnimData:get()
						local simplifiedData = State.currentAnimationData:get()
						if not rawData then
							return "Size: N/A"
						end
						local rawSize = getAnimSizeString(rawData)
						if simplifiedData and simplifiedData ~= rawData then
							local simpSize = getAnimSizeString(simplifiedData)
							return rawSize .. " -> " .. simpSize
						end
						return rawSize
					end),
					LayoutOrder = 7,
				}),
				Checkbox({
					Text = "Enable Simplifier",
					Value = State.simplifierEnabled,
					LayoutOrder = 8,
					OnChange = function(enabled: boolean)
						State.simplifierEnabled:set(enabled)
						triggerResimplify()
					end,
					[OnEvent("MouseEnter")] = function()
						activeHint:set(
							"Thins keyframes to reduce animation size for lower in-game bandwidth."
						)
					end,
					[OnEvent("MouseLeave")] = function()
						activeHint:set("")
					end,
				}) :: any,
				SharedComponents.AnimatedHintLabel({
					Text = activeHint,
					LayoutOrder = 9,
					Size = UDim2.new(1, 0, 0, 0),
					TextWrapped = true,
					ClipsDescendants = true,
					Visible = true,
					TextTransparency = 0,
				}),
			},
		}) :: any
	)

	-- divider between animation modifiers and bone toggles
	table.insert(components, createToolDivider(7))

	-- Add the Bone Toggles section
	table.insert(
		components,
		BoneToggles.create(services, 8) :: any
	)

	return components
end

return ToolsTab
