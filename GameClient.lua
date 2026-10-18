
-- ONE OF THESE IS WRONG
-- First playable prototype

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("OneOfTheseIsWrong")
if oldGui then
	oldGui:Destroy()
end

math.randomseed(os.clock() * 100000)

-- Colors
local backgroundColor = Color3.fromRGB(242, 240, 255)
local panelColor = Color3.fromRGB(255, 255, 255)
local textColor = Color3.fromRGB(54, 49, 78)
local accentColor = Color3.fromRGB(133, 111, 245)

-- Screen GUI
local gui = Instance.new("ScreenGui")
gui.Name = "OneOfTheseIsWrong"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Main panel
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0.9, 0, 0.86, 0)
main.Position = UDim2.new(0.5, 0, 0.5, 0)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = backgroundColor
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 22)
mainCorner.Parent = main

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(500, 650)
sizeLimit.MinSize = Vector2.new(300, 420)
sizeLimit.Parent = main

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 42)
title.Position = UDim2.new(0, 10, 0, 12)
title.BackgroundTransparency = 1
title.Text = "ONE OF THESE IS WRONG"
title.TextColor3 = textColor
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = main

-- Subtitle
local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -20, 0, 28)
subtitle.Position = UDim2.new(0, 10, 0, 55)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Find the one different square!"
subtitle.TextColor3 = Color3.fromRGB(120, 113, 145)
subtitle.TextScaled = true
subtitle.Font = Enum.Font.Gotham
subtitle.Parent = main

-- Score
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Size = UDim2.new(0.48, 0, 0, 32)
scoreLabel.Position = UDim2.new(0.02, 0, 0, 92)
scoreLabel.BackgroundTransparency = 1
scoreLabel.Text = "Score: 0"
scoreLabel.TextColor3 = textColor
scoreLabel.TextScaled = true
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.Parent = main

-- Timer
local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(0.48, 0, 0, 32)
timerLabel.Position = UDim2.new(0.5, 0, 0, 92)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "Time: 60"
timerLabel.TextColor3 = textColor
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.GothamBold
timerLabel.Parent = main

-- Game grid
local grid = Instance.new("Frame")
grid.Name = "GameGrid"
grid.Size = UDim2.new(1, -36, 0, 300)
grid.Position = UDim2.new(0.5, 0, 0, 140)
grid.AnchorPoint = Vector2.new(0.5, 0)
grid.BackgroundColor3 = panelColor
grid.Parent = main

local gridCorner = Instance.new("UICorner")
gridCorner.CornerRadius = UDim.new(0, 16)
gridCorner.Parent = grid

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.22, 0, 0.22, 0)
gridLayout.CellPadding = UDim2.new(0.02, 0, 0.02, 0)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

-- Message
local message = Instance.new("TextLabel")
message.Size = UDim2.new(1, -30, 0, 30)
message.Position = UDim2.new(0.5, 0, 1, -42)
message.AnchorPoint = Vector2.new(0.5, 0)
message.BackgroundTransparency = 1
message.Text = "Find the odd square!"
message.TextColor3 = textColor
message.TextScaled = true
message.Font = Enum.Font.GothamBold
message.Parent = main

-- Restart button
local restartButton = Instance.new("TextButton")
restartButton.Size = UDim2.new(0.55, 0, 0, 48)
restartButton.Position = UDim2.new(0.5, 0, 0.77, 0)
restartButton.AnchorPoint = Vector2.new(0.5, 0)
restartButton.BackgroundColor3 = accentColor
restartButton.TextColor3 = Color3.new(1, 1, 1)
restartButton.Text = "PLAY AGAIN"
restartButton.TextScaled = true
restartButton.Font = Enum.Font.GothamBold
restartButton.Visible = false
restartButton.Parent = main

local restartCorner = Instance.new("UICorner")
restartCorner.CornerRadius = UDim.new(0, 14)
restartCorner.Parent = restartButton

-- Game state
local score = 0
local timeLeft = 60
local roundNumber = 1
local gameRunning = false
local roundLocked = false
local differentIndex = 1
local buttons = {}

local function clearGrid()
	for _, button in ipairs(buttons) do
		button:Destroy()
	end
	table.clear(buttons)
end

local function endGame()
	gameRunning = false
	roundLocked = true
	clearGrid()
	grid.Visible = false

	title.Text = "GAME OVER!"
	subtitle.Text = "Great job! Keep practicing."
	message.Text = "Final score: " .. score
	restartButton.Visible = true
end

local function newRound()
	if not gameRunning then
		return
	end

	roundLocked = false
	clearGrid()

	grid.Visible = true
	restartButton.Visible = false

	-- The difference becomes smaller each round
	local hue = math.random()
	local difference = math.max(0.045, 0.14 - (roundNumber * 0.003))

	local normalColor = Color3.fromHSV(hue, 0.55, 0.95)
	local oddColor = Color3.fromHSV((hue + difference) % 1, 0.55, 0.95)

	differentIndex = math.random(1, 16)

	for i = 1, 16 do
		local button = Instance.new("TextButton")
		button.Name = "Square" .. i
		button.LayoutOrder = i
		button.Text = ""
		button.AutoButtonColor = true
		button.BorderSizePixel = 0
		button.BackgroundColor3 = normalColor
		button.Parent = grid

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button

		if i == differentIndex then
			button.BackgroundColor3 = oddColor
		end

		button.Activated:Connect(function()
			if not gameRunning or roundLocked then
				return
			end

			if i == differentIndex then
				roundLocked = true
				score = score + 10
				roundNumber = roundNumber + 1
				scoreLabel.Text = "Score: " .. score
				message.Text = "Correct! +10 points"
				task.delay(0.25, function()
					if gameRunning then
						newRound()
					end
				end)
			else
				score = math.max(0, score - 2)
				scoreLabel.Text = "Score: " .. score
				message.Text = "Wrong! -2 points"
				button.BackgroundColor3 = Color3.fromRGB(255, 135, 150)
			end
		end)

		table.insert(buttons, button)
	end

	subtitle.Text = "Round " .. roundNumber .. " - Find the odd square!"
end

local function startGame()
	score = 0
	timeLeft = 60
	roundNumber = 1
	gameRunning = true
	roundLocked = false

	scoreLabel.Text = "Score: 0"
	timerLabel.Text = "Time: 60"
	title.Text = "ONE OF THESE IS WRONG"
	message.Text = "Find the odd square!"
	restartButton.Visible = false

	newRound()

	task.spawn(function()
		while gameRunning and timeLeft > 0 do
			task.wait(1)

			if not gameRunning then
				break
			end

			timeLeft = timeLeft - 1
			timerLabel.Text = "Time: " .. timeLeft
		end

		if gameRunning then
			endGame()
		end
	end)
end

restartButton.Activated:Connect(startGame)

-- Start automatically
startGame()
