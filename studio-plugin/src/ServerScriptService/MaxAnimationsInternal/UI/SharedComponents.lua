--!native
--!strict
--!optimize 2

local State = require(script.Parent.Parent.state)
local Fusion = require(script.Parent.Parent.Packages.Fusion)

local New = Fusion.New
local Children = Fusion.Children
local OnChange = Fusion.OnChange
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value
local Computed = Fusion.Computed
local Observer = Fusion.Observer
local Spring = Fusion.Spring

local StudioComponents = script.Parent.Parent.Components:FindFirstChild("StudioComponents")
local Label = require(StudioComponents.Label)
local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local themeProvider = require(StudioComponentsUtil.themeProvider)
local PlaybackControls = require(script.Parent.Components.PlaybackControls)

local SharedComponents = {}

function SharedComponents.AnimatedHintLabel(props: {
	Text: any,
	Size: UDim2,
	TextWrapped: boolean,
	LayoutOrder: number,
	ClipsDescendants: boolean,
	Visible: boolean,
	TextTransparency: any,
	RichText: boolean?,
})
	local activeHint = props.Text
	local displayedText = Value(activeHint:get())

	Observer(activeHint):onChange(function()
		if activeHint:get() ~= "" then
			displayedText:set(activeHint:get())
		end
	end)

	local isVisible = Computed(function()
		return activeHint:get() ~= ""
	end)

	local height = Spring(Computed(function()
		return isVisible:get() and 50 or 0
	end), 20)

	local transparency = Spring(Computed(function()
		return isVisible:get() and 0 or 1
	end), 20)

	return Label({
		Text = displayedText,
		TextWrapped = true,
		RichText = props.RichText,
		Size = Computed(function()
			return UDim2.new(1, 0, 0, height:get())
		end),
		LayoutOrder = props.LayoutOrder,
		TextTransparency = transparency,
		ClipsDescendants = true,
	})
end

function SharedComponents.createHeaderUI(services: any?)
	local lockScale = Value(1)
	local lockPressScale = Spring(lockScale, 35, 0.75)
	local function toggleLockSelection()
		State.isSelectionLocked:set(not State.isSelectionLocked:get())
		if not State.reducedMotion:get() then
			lockScale:set(1.35)
			task.delay(0.08, function()
				lockScale:set(1)
			end)
		end
	end

	local headerChildren = {
		_Layout = New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 1),
		}),
		_Padding = New("UIPadding")({
			PaddingLeft = UDim.new(0, 7),
			PaddingRight = UDim.new(0, 7),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 3),
		}),
		_RigName = Label({
			LayoutOrder = 1,
			Text = Computed(function()
				return "Rig: " .. State.rigModelName:get()
			end),
			Font = Enum.Font.SourceSansBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		_LockSelection = New("Frame")({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			[Children] = {
				New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 5),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				New("TextButton")({
					Text = "",
					Size = Computed(function()
						local scale = lockPressScale:get()
						return UDim2.new(0, 12 * scale, 0, 12 * scale)
					end),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(6, 9),
					LayoutOrder = 1,
					BackgroundColor3 = themeProvider:GetColor(Computed(function()
						return if State.isSelectionLocked:get()
							then Enum.StudioStyleGuideColor.CheckedFieldBackground
							else Enum.StudioStyleGuideColor.InputFieldBackground
					end)),
					BorderSizePixel = 0,
					[Children] = {
						New("UIStroke")({
							Color = themeProvider:GetColor(Enum.StudioStyleGuideColor.CheckedFieldBorder),
							Thickness = 1,
						}),
						New("Frame")({
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.new(0, 6, 0, 6),
							BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.CheckedFieldIndicator),
							BorderSizePixel = 0,
							Visible = Computed(function()
								return State.isSelectionLocked:get()
							end),
						}),
					},
					[OnEvent("Activated")] = toggleLockSelection,
				}),
				New("TextButton")({
					Text = "Lock Rig Selection",
					Size = UDim2.new(1, -18, 0, 18),
					LayoutOrder = 2,
					BackgroundTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText),
					Font = Enum.Font.SourceSans,
					TextSize = 14,
					[OnEvent("Activated")] = toggleLockSelection,
				}),
			},
		}),
		_Warnings = Label({
			LayoutOrder = 4,
			Text = Computed(function()
				local warnings = State.activeWarnings:get()
				return table.concat(warnings, "\n")
			end),
			Visible = Computed(function()
				return #State.activeWarnings:get() > 0
			end),
			TextColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.WarningText),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}),
	}

	if services then
		headerChildren._Playback = PlaybackControls.createHeaderPlayback(services, 3)
	end

	return New("Frame")({
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = headerChildren,
	})
end

return SharedComponents
