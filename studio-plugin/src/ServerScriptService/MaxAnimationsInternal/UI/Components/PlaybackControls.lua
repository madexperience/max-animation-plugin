--!native
--!strict
--!optimize 2

local State = require(script.Parent.Parent.Parent.state)
local Fusion = require(script.Parent.Parent.Parent.Packages.Fusion)

local New = Fusion.New
local Children = Fusion.Children
local OnChange = Fusion.OnChange
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value
local Computed = Fusion.Computed
local Observer = Fusion.Observer
local Spring = Fusion.Spring

local StudioComponents = script.Parent.Parent.Parent.Components:FindFirstChild("StudioComponents")
local Checkbox = require(StudioComponents.Checkbox)
local Label = require(StudioComponents.Label)
local Slider = require(StudioComponents.Slider)
local VerticalCollapsibleSection = require(StudioComponents.VerticalCollapsibleSection)
local PlaybackSlider = require(script.Parent.PlaybackSlider)

local StudioComponentsUtil = StudioComponents:FindFirstChild("Util")
local themeProvider = require(StudioComponentsUtil.themeProvider)

local PlaybackControls = {}

local function createPlaybackButton(props: { [any]: any })
	local isHovering = Value(false)
	local isPressed = Value(false)
	return New("ImageButton")({
		Image = props.Image,
		Size = props.Size or UDim2.new(0, 40, 0, 40),
		BackgroundTransparency = 1,
		ImageColor3 = props.ImageColor3,
		LayoutOrder = props.LayoutOrder,
		[Children] = {
			New("UIScale")({
				Scale = Spring(Computed(function()
					if State.reducedMotion:get() then
						return 1
					end
					if isPressed:get() then
						return 0.97
					end
					if isHovering:get() then
						return 1.02
					end
					return 1
				end), 25, 0.9),
			}),
		},
		[OnEvent("MouseEnter")] = function()
			isHovering:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			isHovering:set(false)
			isPressed:set(false)
		end,
		[OnEvent("InputBegan")] = function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isPressed:set(true)
			end
		end,
		[OnEvent("InputEnded")] = function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isPressed:set(false)
			end
		end,
		[OnEvent("Activated")] = props.Activated,
	})
end

local function seekToStart(services: any)
	if services and services.playbackService then
		services.playbackService:seekAnimationToTime(0)
		State.isPlaying:set(false)
		if services.playbackService.State.currentAnimTrack then
			(services.playbackService.State.currentAnimTrack :: AnimationTrack):AdjustSpeed(0)
		end
		services.playbackService:updateUI()
	end
end

local function seekToEnd(services: any)
	if services and services.playbackService then
		local animLength = 0
		if services.playbackService.State.currentAnimTrack then
			animLength = (services.playbackService.State.currentAnimTrack :: AnimationTrack).Length
		else
			animLength = State.animationLength:get()
		end
		services.playbackService:seekAnimationToTime(animLength - 0.001)
		State.isPlaying:set(false)
		if services.playbackService.State.currentAnimTrack then
			(services.playbackService.State.currentAnimTrack :: AnimationTrack):AdjustSpeed(0)
		end
		services.playbackService:updateUI()
	end
end

function PlaybackControls.createPlaybackScrubber(services: any)
	local sliderValue = Value(0)

	-- sync slider value with playhead when not being dragged
	local cleanupPlayheadObserver = Observer(State.playhead):onChange(function()
		if not State.userChangingSlider:get() then
			sliderValue:set(State.playhead:get())
		end
	end)

	return New("Frame")({
		Size = UDim2.new(1, 0, 0, 25),
		BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
		BackgroundTransparency = 0.9,
		LayoutOrder = 8,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Slider({
				Step = 0.01,
				Min = 0,
				Max = State.animationLength,
				Value = sliderValue,
				OnChange = function(value)
					State.playhead:set(value)
					if services and services.playbackService then
						services.playbackService:onSliderChange(value)
					end
					return nil
				end,
				[OnEvent("InputBegan")] = function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						State.userChangingSlider:set(true)
					end
				end,
				[OnEvent("InputEnded")] = function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						State.userChangingSlider:set(false)
					end
				end,
				[Children] = Computed(function()
					local keyframes = State.keyframeNames:get()
					local animLength = State.animationLength:get()

					local indicators = {}
					for _, keyframe in ipairs(keyframes) do
						table.insert(
							indicators,
							New("Frame")({
								Size = UDim2.new(0, 2, 1, 0),
								Position = UDim2.new(
									(keyframe :: any).time / (animLength or 1),
									0,
									0,
									0
								),
								ZIndex = 2,
								BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.ErrorText) :: any,
								BorderSizePixel = 0,
							})
						)
					end
					return indicators
				end, Fusion.cleanup),
			}),
		},
	})
end

function PlaybackControls.createPlaybackSection(services: any, layoutOrder: number?)
	return VerticalCollapsibleSection({
		Text = "Playback",
		Collapsed = false,
		LayoutOrder = layoutOrder or 2,
		[Children] = {
			PlaybackControls.createPlaybackScrubber(services),
			New("Frame")({
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
				LayoutOrder = 9,
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 5),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					createPlaybackButton({
						Image = "rbxasset://textures/AnimationEditor/button_control_previous.png",
						ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
						LayoutOrder = 1,
						Activated = function()
							if services and services.playbackService then
								services.playbackService:seekAnimationToTime(0)
								State.isPlaying:set(false)
								-- Stop the animation track to prevent it from continuing
								if services.playbackService.State.currentAnimTrack then
									(services.playbackService.State.currentAnimTrack :: AnimationTrack):AdjustSpeed(0)
								end
								services.playbackService:updateUI()
							end
						end,
					}),
					createPlaybackButton({
						Image = State.reversePlayPauseButtonImage,
						ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
						LayoutOrder = 2,
						Activated = function()
							if services and services.playbackService then
								services.playbackService:onReverseButtonActivated()
							end
						end,
					}),
					createPlaybackButton({
						Image = State.playPauseButtonImage,
						ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
						LayoutOrder = 3,
						Activated = function()
							if services and services.playbackService then
								services.playbackService:onPlayPauseButtonActivated()
							end
						end,
					}),
					createPlaybackButton({
						Image = "rbxasset://textures/AnimationEditor/button_control_next.png",
						ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
						LayoutOrder = 4,
						Activated = function()
							if services and services.playbackService then
								-- Use the actual animation track length for accurate seeking
								local animLength = 0
								if services.playbackService.State.currentAnimTrack then
									animLength = (services.playbackService.State.currentAnimTrack :: AnimationTrack).Length
								else
									animLength = State.animationLength:get()
								end
								services.playbackService:seekAnimationToTime(animLength - 0.001)
								State.isPlaying:set(false)
								-- Stop the animation track to prevent it from continuing
								if services.playbackService.State.currentAnimTrack then
									(services.playbackService.State.currentAnimTrack :: AnimationTrack):AdjustSpeed(0)
								end
								services.playbackService:updateUI()
							end
						end,
					}),
				},
			}),
			Checkbox({
				Value = State.loopAnimation,
				Text = "Loop Animation",
				LayoutOrder = 10,
				OnChange = function(newValue: boolean): nil
					State.loopAnimation:set(newValue)
					return nil
				end,
			}),
			Label({
				LayoutOrder = 11,
				Text = Computed(function()
					local playhead = State.playhead:get()
					local currentFrame = math.floor(playhead * 60 + 0.5)
					return string.format("Frame: %d", currentFrame)
				end),
			}),
		},
	})
end

function PlaybackControls.createHeaderPlayback(services: any, layoutOrder: number?)
	local loopScale = Value(1)
	local loopPressScale = Spring(loopScale, 35, 0.75)
	local function toggleLoop()
		State.loopAnimation:set(not State.loopAnimation:get())
		if not State.reducedMotion:get() then
			loopScale:set(1.35)
			task.delay(0.08, function()
				loopScale:set(1)
			end)
		end
	end

	return New("Frame")({
		Name = "HeaderPlayback",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder or 3,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 1),
			}),
			New("Frame")({
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				[Children] = {
					PlaybackSlider.create({
						Step = 0.01,
						Min = 0,
						Max = State.animationLength,
						Value = State.playhead,
						Children = Computed(function()
							local keyframes = State.keyframeNames:get()
							local animLength = State.animationLength:get()

							local indicators = {}
							for _, keyframe in ipairs(keyframes) do
								table.insert(
									indicators,
									New("Frame")({
										Size = UDim2.new(0, 2, 1, 0),
										Position = UDim2.new(
											(keyframe :: any).time / (animLength or 1),
											0,
											0,
											0
										),
										ZIndex = 2,
										BackgroundColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.ErrorText) :: any,
										BorderSizePixel = 0,
									})
								)
							end
							return indicators
						end, Fusion.cleanup),
						OnChange = function(value)
							State.playhead:set(value)
							if services and services.playbackService then
								services.playbackService:onSliderChange(value)
							end
							return nil
						end,
					}),
				},
			}),
			New("Frame")({
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				[Children] = {
					New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 5),
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					createPlaybackButton({
						Image = "rbxasset://textures/AnimationEditor/button_control_previous.png",
						ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
						Size = UDim2.new(0, 28, 0, 28),
						LayoutOrder = 1,
						Activated = function()
							seekToStart(services)
						end,
					}),
					createPlaybackButton({
						Image = State.reversePlayPauseButtonImage,
						ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
						Size = UDim2.new(0, 28, 0, 28),
						LayoutOrder = 2,
						Activated = function()
							if services and services.playbackService then
								services.playbackService:onReverseButtonActivated()
							end
						end,
					}),
					createPlaybackButton({
						Image = State.playPauseButtonImage,
						ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
						Size = UDim2.new(0, 28, 0, 28),
						LayoutOrder = 3,
						Activated = function()
							if services and services.playbackService then
								services.playbackService:onPlayPauseButtonActivated()
							end
						end,
					}),
					createPlaybackButton({
						Image = "rbxasset://textures/AnimationEditor/button_control_next.png",
						ImageColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText) :: any,
						Size = UDim2.new(0, 28, 0, 28),
						LayoutOrder = 4,
						Activated = function()
							seekToEnd(services)
						end,
					}),
					New("Frame")({
						Size = UDim2.new(0, 50, 0, 22),
						BackgroundTransparency = 1,
						LayoutOrder = 5,
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 4),
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							New("TextButton")({
								Text = "",
								Size = Computed(function()
									local scale = loopPressScale:get()
									return UDim2.new(0, 12 * scale, 0, 12 * scale)
								end),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromOffset(6, 11),
								LayoutOrder = 1,
								BackgroundColor3 = themeProvider:GetColor(Computed(function()
									return if State.loopAnimation:get()
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
											return State.loopAnimation:get()
										end),
									}),
								},
								[OnEvent("Activated")] = function()
									toggleLoop()
								end,
							}),
							New("TextButton")({
								Text = "Loop",
								Size = UDim2.new(0, 34, 0, 22),
								LayoutOrder = 2,
								BackgroundTransparency = 1,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Center,
								TextColor3 = themeProvider:GetColor(Enum.StudioStyleGuideColor.MainText),
								Font = Enum.Font.SourceSans,
								TextSize = 14,
								[OnEvent("Activated")] = function()
									toggleLoop()
								end,
							}),
						},
					}),
				},
			}),
			Label({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 9),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextSize = 11,
				Text = Computed(function()
					local playhead = State.playhead:get()
					local currentFrame = math.floor(playhead * 60 + 0.5)
					return string.format("%.2fs / frame %d", playhead, currentFrame)
				end),
			}),
		},
	})
end

return PlaybackControls
