------------------------------------------------
--Spyro: A Hero's Tail - In-Game Object Viewer--
--------------------By Ebbe---------------------
------------------------------------------------

-------------CONTROLS---------------
local KEY_PRINT_LIST = "E"
--local KEY_TELEPORT = "T"
local KEY_INCREASE_RANGE = "Up"
local KEY_DECREASE_RANGE = "Down"
local KEY_TOGGLE_RENDER = "R"
------------------------------------

console.clear()
memory.usememorydomain("RAM")

local specificItem = ""

--INPUT VARS
local currInput = {}
local lastInput = {}

local currKeyInput = {}
local lastKeyInput = {}

local currWheel = 0
local lastWheel = 0

local mouseClientPos = {X = 0, Y = 0}

local mouseCurrInput = {}
local mouseLastInput = {}

--ITEMS
local itemListLength = 0
local pnt_itemListBase = 0x46F670
local pnt_itemListStart = 0x0

local itemList = {}

local itemUpdateEnabled = true

--TRIGGERS
local trigTableLength = 0x0
local trigListLength = 0
local gpSE_TriggerList = 0x4CB63C
local pnt_trigListBase = 0x0
local pnt_trigListStart = 0x0

local trigList = {}

--SCREEN STUFF
local internalScreenDim = {X = 640, Y = 492}

local screenDim = {X = 1280, Y = 984} --These values change as the user resizes the window

local screenScale = 0

local screenAspect = 1.3

local emuScreenYOffset = 0

local gameFrameDelay = 3
local gameFOV = 58.5
local screenYStretch = 0.978
local posRenderDistance = 100 --Render distance for all points, regardless of object type
local trigRenderDistance = 30
local screenClippingDist = 0.3

--CAMERA
local cameraPosBuffer = {}
for i = 1, gameFrameDelay do
	cameraPosBuffer[i] = {["X"] = 0, ["Y"] = 0, ["Z"] = 0}
end

local cameraPos = {X = 0, Y = 0, Z = 0}

local cameraMatBuffer = {}
for i = 1, gameFrameDelay do
	cameraMatBuffer[i] = {}
	cameraMatBuffer[i]["X"] = {["X"] = 1, ["Y"] = 0, ["Z"] = 0}
	cameraMatBuffer[i]["Y"] = {["X"] = 0, ["Y"] = 1, ["Z"] = 0}
	cameraMatBuffer[i]["Z"] = {["X"] = 0, ["Y"] = 0, ["Z"] = 1}
end

local cameraMatrix = {}
cameraMatrix["X"] = {["X"] = 1, ["Y"] = 0, ["Z"] = 0}
cameraMatrix["Y"] = {["X"] = 0, ["Y"] = 1, ["Z"] = 0}
cameraMatrix["Z"] = {["X"] = 0, ["Y"] = 0, ["Z"] = 1}

local FOVmultBuffer = {}
for i = 1, gameFrameDelay do
	FOVmultBuffer[i] = 1
end

local FOVmult = 1;

--MORE ITEM STUFF
local pnt_currItem = 0x0
local renderLimit = 8

local startIndex = 1
local endIndex = 1000 --Just a high temp value

--MODES
local drawMode = 1
local showCloseRange = 10
local renderEnabled = true
local renderOnlySpecific = false

local modes = {
	{
		["Name"] = "Items (Full List)",
		["Type"] = "ITEM"
	},
	{
		["Name"] = "Items (Close to Player)",
		["Type"] = "ITEM"
	},
	{
		["Name"] = "Unknown Items",
		["Type"] = "ITEM"
	},
	{
		["Name"] = "Items (Only On-Screen)",
		["Type"] = "ITEM"
	},
	{
		["Name"] = "Triggers",
		["Type"] = "TRIG"
	},
}

local sortMode = 1

local sortModes = {
	"Sort by Index",
	"Sort by Address",
	"Sort by Class Name"
}

local heroNames = {
	"Spyro",
	"BallGadget",
	"Blinky",
	"Player_Sparx",
	"Hunter",
	"SgtByrd"
}

local teleportCloseNextFrame = false
local teleportSpecificNextFrame = false
local updateTrigListNextFrame = false

--Table of item ID's
local itemClassID = require("SpyroAHT_objlist_itemDef");
--Table of .edb hashcodes
local geoHashes = require("SpyroAHT_objlist_geoDef");

--UI Setup
local textOffset = 0
local highlightColor = "White"
local titleTextSize = 16
local itemRenderAreaStart = 0
local itemRenderAreaEnd = 100 --Just a high temp value
local scrollBarWidth = 10
local itemDisplaySize = 96
local topTextHeight = 100 --Just a high temp value

local textAreaWidth = 400
local textAreaHeight = 1000 --Just a high temp value
client.setwindowsize(2)
client.SetClientExtraPadding(textAreaWidth, 0, 0, 0)
gui.use_surface("client")


--SETTINGS WINDOW
forms.destroyall();
local settingsWindow = forms.newform(300, 300, "Settings");
forms.setlocation(settingsWindow, client.xpos()+textAreaWidth, client.ypos()+100);

local leftSideOffset = 2;
local elementOffset = 10
local dropDownItems = {
	modes[1].Name,
	modes[2].Name,
	--modes[3].Name,
	modes[4].Name,
	modes[5].Name
	};

local checkRenderToggle = forms.checkbox(settingsWindow, string.format("Render (%s)", KEY_TOGGLE_RENDER), leftSideOffset, elementOffset);
forms.setproperty(checkRenderToggle, "Checked", true);
local checkItemUpdate = forms.checkbox(settingsWindow, "Update Items", leftSideOffset+150, elementOffset);
forms.setproperty(checkItemUpdate, "Checked", true);
elementOffset = elementOffset+20
local checkRenderSpecific = forms.checkbox(settingsWindow, string.format("Only Specific", KEY_TOGGLE_RENDER), leftSideOffset, elementOffset);
elementOffset = elementOffset+30

local labelModeSettings = forms.label(settingsWindow, "Mode Settings", leftSideOffset, elementOffset, 150, 14);
elementOffset = elementOffset+15

local dropDownModes = forms.dropdown(settingsWindow, dropDownItems, leftSideOffset, elementOffset, 200, 24);
forms.setdropdownitems(dropDownModes, dropDownItems, false)
elementOffset = elementOffset+22

local dropDownSort = forms.dropdown(settingsWindow, sortModes, leftSideOffset, elementOffset, 200, 24);
forms.setdropdownitems(dropDownSort, sortModes, false)
elementOffset = elementOffset+30

local labelTriggers = forms.label(settingsWindow, "Triggers", leftSideOffset, elementOffset, 150, 14);
elementOffset = elementOffset+15

local buttonTriggerUpdate = forms.button( settingsWindow, "Update Trigger List", function()
	updateTrigListNextFrame = true
end, leftSideOffset, elementOffset, 150, 25 );
elementOffset = elementOffset+30

local labelTeleport = forms.label(settingsWindow, "Teleport Items", leftSideOffset, elementOffset, 150, 14);
elementOffset = elementOffset+15

local buttonTeleportClose = forms.button( settingsWindow, "Teleport Close Items to Player", function()
	teleportCloseNextFrame = true
end, leftSideOffset, elementOffset, 180, 25 );
--local checkTeleportCloseConstant = forms.checkbox(settingsWindow, "Constant", leftSideOffset+182, elementOffset);
elementOffset = elementOffset+25

local buttonTeleportSelected = forms.button( settingsWindow, "Teleport Specific Class to Player:", function()
	teleportSpecificNextFrame = true
end, leftSideOffset, elementOffset, 180, 25 );
local checkTeleportSpecificConstant = forms.checkbox(settingsWindow, "Constant", leftSideOffset+182, elementOffset);
elementOffset = elementOffset+30

local labelSpecify = forms.label(settingsWindow, "Specify Item Class:", leftSideOffset, elementOffset, 150, 14);
elementOffset = elementOffset+15

local textboxSpecifyItem = forms.textbox(settingsWindow, "Type Class Name Here...", 250, 26, "STRING", leftSideOffset, elementOffset, true, true);
elementOffset = elementOffset+30

local function hex2float (c)
	--From François Perrad's lua-MessagePack.
    if c == 0 then return 0.0 end
    local c = string.gsub(string.format("%X", c),"(..)",function (x) return string.char(tonumber(x, 16)) end)
    local b1,b2,b3,b4 = string.byte(c, 1, 4)
    local sign = b1 > 0x7F
    local expo = (b1 % 0x80) * 0x2 + math.floor(b2 / 0x80)
    local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4

    if sign then
        sign = -1
    else
        sign = 1
    end

    local n

    if mant == 0 and expo == 0 then
        n = sign * 0.0
    elseif expo == 0xFF then
        if mant == 0 then
            n = sign * math.huge
        else
            n = 0.0/0.0
        end
    else
        n = sign * math.ldexp(1.0 + mant / 0x800000, expo - 0x7F)
    end

    return n
end

local function convertByteArrayToIntArray(inputArray, arraySize) --NOTE: Output array will be 4 times smaller than input array
	local intArraySize = arraySize/4
	local outputArray = {}
	
	for i = 0, intArraySize-1 do
		local index = i*4
		outputArray[i+1] = inputArray[index+1]*0x1000000 + inputArray[index+2]*0x10000 + inputArray[index+3]*0x100 + inputArray[index+4]
	end
	
	return outputArray
end

local function convertByteArrayToFloatArray(inputArray, arraySize) --NOTE: Output array will be 4 times smaller than input array
	local fltArraySize = arraySize/4
	local outputArray = {}
	
	for i = 0, fltArraySize-1 do
		local index = i*4
		outputArray[i+1] = hex2float(inputArray[index+1]*0x1000000 + inputArray[index+2]*0x10000 + inputArray[index+3]*0x100 + inputArray[index+4]);
	end
	
	return outputArray
end

local function dist3D(Vect3a, Vect3b)
	return math.sqrt( (Vect3a.X-Vect3b.X)^2 + (Vect3a.Y-Vect3b.Y)^2 + (Vect3a.Z-Vect3b.Z)^2 )
end

local function isInRange(Vect3a, Vect3b, range)
	return dist3D(Vect3a, Vect3b) < range
end

local function length3D(inputVect)
	return math.sqrt(inputVect.X^2 + inputVect.Y^2 + inputVect.Z^2)
end

local function cameraInit()
	cameraPos.X = memory.readfloat(0x750878, true)
	cameraPos.Y = memory.readfloat(0x75087C, true)
	cameraPos.Z = memory.readfloat(0x750880, true)
	
	for i = 1, gameFrameDelay do
		cameraPosBuffer[i] = cameraPos
	end
	
	cameraMatrix.X.X = memory.readfloat(0x48A1A0, true)
	cameraMatrix.Y.X = memory.readfloat(0x48A1A4, true)
	cameraMatrix.Z.X = memory.readfloat(0x48A1A8, true)
	
	cameraMatrix.X.Y = memory.readfloat(0x48A1B0, true)
	cameraMatrix.Y.Y = memory.readfloat(0x48A1B4, true)
	cameraMatrix.Z.Y = memory.readfloat(0x48A1B8, true)
	
	cameraMatrix.X.Z = memory.readfloat(0x48A1C0, true)
	cameraMatrix.Y.Z = memory.readfloat(0x48A1C4, true)
	cameraMatrix.Z.Z = memory.readfloat(0x48A1C8, true)
	
	for i = 1, gameFrameDelay do
		cameraMatBuffer[i] = cameraMatrix
	end
end

local function itemIsHero(itemID)
	for i, v in pairs(heroNames) do
		if v == itemID then
			return true
		end
	end
	
	return false
end

local function findHeroPos()
	for i, item in pairs(itemList) do
		if itemIsHero(item.ID) == true then
			return {
				X = item.Position.X,
				Y = item.Position.Y,
				Z = item.Position.Z,
				Pitch = item.Rotation.Pitch,
				Yaw = item.Rotation.Yaw,
				Roll = item.Rotation.Roll
			}
		end
	end
	
	return {
		X = 0,
		Y = 0,
		Z = 0,
		Pitch = 0,
		Yaw = 0,
		Roll = 0
	}
end

local function vectToEuler(vectStart, vectEnd)
	local vectDir = {
		X = vectEnd.X - vectStart.X,
		Y = vectEnd.Y - vectStart.Y,
		Z = vectEnd.Z - vectStart.Z
	}
	
	return {
		Pitch = math.asin(vectDir.Y / length3D(vectDir)),
		Yaw =   math.atan2(vectDir.X, vectDir.Z),
		Roll =  0 --Assume roll is always zero
	}
end

local function getItemID(itemPointer)
	local pnt_itemHeader = bit.band(memory.read_u32_be(itemPointer + 0x14C), 0xFFFFFF)
	local pnt_1 = bit.band(memory.read_u32_be(pnt_itemHeader + 0x4), 0xFFFFFF)
	local pnt_ClassFunction = memory.read_u32_be(pnt_1 + 0x8)
	local IDresult = {}
	IDresult.Name = "ERR"
	IDresult.isCamera = false
	
	if itemClassID[pnt_ClassFunction] ~= nil then
		IDresult.Name = itemClassID[pnt_ClassFunction]
	else
		IDresult.Name = string.format("UNK: 0x%x", pnt_ClassFunction)
	end
	
	if pnt_ClassFunction > 0x8012b914 and pnt_ClassFunction < 0x8012ba8c then
		IDresult.isCamera = true
	end
	
	--IDresult.Name = IDresult.Name .. string.format(" (%x)", pnt_ClassFunction)
	
	return IDresult;
end

local function teleportItemAnimator(item)
	local pnt_itemAnimator = bit.band(memory.read_u32_be(item.Address+0x144), 0xFFFFFF)
	local hasAnimator = true
	
	if bit.band(pnt_itemAnimator, 0x80000000) == 0x80000000 then
		if (memory.readfloat(pnt_itemAnimator + 0xc0, true) ~= 0 and
		memory.readfloat(pnt_itemAnimator + 0xc0, true) ~= 0 and
		memory.readfloat(pnt_itemAnimator + 0xc0, true) ~= 0) then
			
			memory.writefloat(pnt_itemAnimator + 0xc0, item.Position.X, true)
			memory.writefloat(pnt_itemAnimator + 0xc4, item.Position.Y, true)
			memory.writefloat(pnt_itemAnimator + 0xc8, item.Position.Z, true)
		else
			hasAnimator = false
		end
	else
		hasAnimator = false
	end
	
	--if hasAnimator == false then
	--	console.log(string.format("Item '%s' at 0x%x had no animator pointer at offset 0x144.", itemList[inputIndex]["ID"], itemList[inputIndex]["Address"]))
	--end
end

local function teleportToHero(item)
	local HeroPos = findHeroPos()
	
	if (item.Position.X ~= 0 and
	item.Position.Y ~= 0 and
	item.Position.Z ~= 0 and
	item.Camera == false) then
		memory.writefloat(item.Address + 0xD0, HeroPos.X, true);
		memory.writefloat(item.Address + 0xD4, HeroPos.Y, true);
		memory.writefloat(item.Address + 0xD8, HeroPos.Z, true);
		memory.writefloat(item.Address + 0xE0, HeroPos.Pitch, true);
		memory.writefloat(item.Address + 0xE4, HeroPos.Yaw, true);
		memory.writefloat(item.Address + 0xE8, HeroPos.Roll, true);
		
		--Needed, as static items don't update their animators every frame
		teleportItemAnimator(item);
	end
end

local function doScroll()
	if currWheel < lastWheel then
		startIndex = startIndex + 1;
	elseif currWheel > lastWheel then
		startIndex = startIndex - 1;
	end
end

local function doTeleportClose()
	for i, item in pairs(itemList) do
		if isInRange(item.Position, findHeroPos(), showCloseRange) then
			teleportToHero(item);
		end
	end
end

local function doTeleportSpecific()
	for i, item in pairs(itemList) do
		if item.ID == specificItem then
			teleportToHero(item);
		end
	end
end

local function doChangeCloseRange()
	if currKeyInput[KEY_INCREASE_RANGE] and lastKeyInput[KEY_INCREASE_RANGE] ~= true then
		showCloseRange = showCloseRange + 1
		if showCloseRange > 100 then
			showCloseRange = 100;
		end
	elseif currKeyInput[KEY_DECREASE_RANGE] and lastKeyInput[KEY_DECREASE_RANGE] ~= true then
		showCloseRange = showCloseRange - 1
		if showCloseRange < 1 then
			showCloseRange = 1;
		end
	end
end

local function doToggleRender()
	if currKeyInput[KEY_TOGGLE_RENDER] and lastKeyInput[KEY_TOGGLE_RENDER] ~= true then
		if renderEnabled then
			renderEnabled = false;
			forms.setproperty(checkRenderToggle, "Checked", false);
		else
			renderEnabled = true;
			forms.setproperty(checkRenderToggle, "Checked", true);
		end
	end
end

local function initItem(inputIndex)
	itemList[inputIndex] = {}
	
	itemList[inputIndex].Index = inputIndex;
	
	itemList[inputIndex].Address = 0x0
	itemList[inputIndex].ID = ""
	itemList[inputIndex].Camera = false
	
	itemList[inputIndex].Position = {}
	itemList[inputIndex].Position.X = 0
	itemList[inputIndex].Position.Y = 0
	itemList[inputIndex].Position.Z = 0
	
	itemList[inputIndex].Rotation = {}
	itemList[inputIndex].RotationPitch = 0
	itemList[inputIndex].RotationYaw = 0
	itemList[inputIndex].RotationRoll = 0
	
	itemList[inputIndex].currVectorHash = 0
	itemList[inputIndex].lastVectorHash = 0
	
	itemList[inputIndex].DistFromCam = 0
end

local function updateTrigListLength()
	local currPnt = pnt_trigListBase
	trigListLength = 0
	
	while bit.band(memory.read_u32_be(currPnt), 0x80000000) == 0x80000000 do
		trigListLength = trigListLength + 1
		currPnt = currPnt + 0x4
	end
end

local function sanitizeItemList()
	for i = itemListLength+1, table.getn(itemList) do
		table.remove(itemList, i);
	end
end

local function sanitizeTrigList()
	for i = trigListLength+1, table.getn(trigList) do
		table.remove(trigList, i);
	end
end

local function initTrig(inputIndex)
	trigList[inputIndex] = {}
	trigList[inputIndex].Index = 0
	
	trigList[inputIndex].Address = 0
	trigList[inputIndex].GeoHash = ""
	trigList[inputIndex].TrigHash = 0x0
	
	trigList[inputIndex].Position = {}
	trigList[inputIndex].Position.X = 0
	trigList[inputIndex].Position.Y = 0
	trigList[inputIndex].Position.Z = 0
end

local function updateItemList()
	local currIndex = 1
	
	--Initialize item info
	while currIndex <= itemListLength and currIndex > 0 do
		if itemList[currIndex] == nil then
			--console.log(string.format("Updating item %d in table", currIndex))
			initItem(currIndex);
		end
	
		itemList[currIndex].Index = currIndex;
	
		--Set the object base address
		itemList[currIndex].Address = pnt_currItem;
		
		--Set the object ID
		itemList[currIndex].ID = getItemID(pnt_currItem).Name;
		itemList[currIndex].Camera = getItemID(pnt_currItem).isCamera;
		
		--Set the object position vector
		if itemList[currIndex].Camera == true then
			itemList[currIndex].currVectorHash = memory.hash_region(pnt_currItem + 0x1E0, 0x34);
			--only update if changed
			if itemList[currIndex].currVectorHash ~= itemList[currIndex]["lastVectorHash"] then
				itemList[currIndex].Rotation.Pitch = memory.readfloat(pnt_currItem + 0x1E0, true);
				itemList[currIndex].Rotation.Yaw = memory.readfloat(pnt_currItem + 0x1E4, true);
				itemList[currIndex].Rotation.Roll = memory.readfloat(pnt_currItem + 0x1E8, true);
				
				itemList[currIndex].Position.X = memory.readfloat(pnt_currItem + 0x208, true);
				itemList[currIndex].Position.Y = memory.readfloat(pnt_currItem + 0x20c, true);
				itemList[currIndex].Position.Z = memory.readfloat(pnt_currItem + 0x210, true);
				
				itemList[currIndex].DistFromCam = dist3D(itemList[currIndex].Position, cameraPos);
			end
			itemList[currIndex].lastVectorHash = itemList[currIndex].currVectorHash;
		else
			itemList[currIndex].currVectorHash = memory.hash_region(pnt_currItem + 0xD0, 0x20);
			--only update if changed
			if itemList[currIndex].currVectorHash ~= itemList[currIndex].lastVectorHash then
				itemList[currIndex].Position.X = memory.readfloat(pnt_currItem + 0xD0, true);
				itemList[currIndex].Position.Y = memory.readfloat(pnt_currItem + 0xD4, true);
				itemList[currIndex].Position.Z = memory.readfloat(pnt_currItem + 0xD8, true);
				
				itemList[currIndex].DistFromCam = dist3D(itemList[currIndex].Position, cameraPos);
				
				itemList[currIndex].Rotation.Pitch = memory.readfloat(pnt_currItem + 0xE0, true);
				itemList[currIndex].Rotation.Yaw = memory.readfloat(pnt_currItem + 0xE4, true);
				itemList[currIndex].Rotation.Roll = memory.readfloat(pnt_currItem + 0xE8, true);
			end
			itemList[currIndex].lastVectorHash = itemList[currIndex].currVectorHash;
		end
		
		currIndex = currIndex + 1;
		--Read pointer of the next item
		pnt_currItem = bit.band(memory.read_u32_be(pnt_currItem + 0x4), 0xFFFFFF)
	end
	
	sanitizeItemList()
end

local function updateTrigList()
	local currIndex = 1
	local currOffset = 0x0;
	local pnt_currTrig = pnt_trigListStart;
	local tempGeoHash = 0x0;
	
	while currIndex <= trigListLength and currIndex > 0 do
		if trigList[currIndex] == nil then
			initTrig(currIndex);
		end
		trigList[currIndex].Index = currIndex;
		trigList[currIndex].Address = pnt_currTrig;
		
		trigList[currIndex].Position.X = memory.readfloat(pnt_currTrig, true);
		trigList[currIndex].Position.Y = memory.readfloat(pnt_currTrig + 0x4, true);
		trigList[currIndex].Position.Z = memory.readfloat(pnt_currTrig + 0x8, true);
		
		local tempGeoHash = memory.read_u32_be(pnt_currTrig + 0x34);
		if geoHashes[tempGeoHash] ~= nil then
			trigList[currIndex].GeoHash = geoHashes[tempGeoHash];
		else
			trigList[currIndex].GeoHash = "";
		end
		
		trigList[currIndex].TrigHash = memory.read_u32_be(pnt_currTrig - 0x14);
		
		currIndex = currIndex + 1
		--Read pointer of the next trigger
		currOffset = currOffset + 0x4
		
		pnt_currTrig = bit.band(memory.read_u32_be(pnt_trigListBase + currOffset), 0xFFFFFF)
	end
	
	sanitizeTrigList()
end

local function worldSpcToScreenSpc(inputVect)
	local localVect = {
		X = inputVect.X - cameraPos.X,
		Y = inputVect.Y - cameraPos.Y,
		Z = inputVect.Z - cameraPos.Z
	}
	
	return {
		X = cameraMatrix.X.X * localVect.X + cameraMatrix.Y.X * localVect.Y + cameraMatrix.Z.X * localVect.Z,
		Y = cameraMatrix.X.Y * localVect.X + cameraMatrix.Y.Y * localVect.Y + cameraMatrix.Z.Y * localVect.Z,
		Z = cameraMatrix.X.Z * localVect.X + cameraMatrix.Y.Z * localVect.Y + cameraMatrix.Z.Z * localVect.Z
	}
end

local function screenSpcToScreenPos(inputVect)
	return {
		X = (screenDim.X/2)+textAreaWidth+((inputVect.X*(screenDim.Y/2))/inputVect.Z)/math.tan(math.rad(gameFOV*FOVmult)/2),
		Y = (screenDim.Y/2)+((inputVect.Y*-(screenDim.Y/2))/inputVect.Z)/math.tan(math.rad(gameFOV*FOVmult*screenYStretch)/2)+emuScreenYOffset
	}
end

local function drawPosToScreen(obj, pointColor, drawIndex, labelsToDraw)
	local screenObjPos = worldSpcToScreenSpc(obj.Position)
	local pointPos = screenSpcToScreenPos(screenObjPos)
	local pointSizeMin = 4
	
	--scale dot to mimmick perspective
	pointSize = 200/(screenObjPos.Z/(1/math.tan(math.rad(gameFOV*FOVmult))))
	if pointSize < pointSizeMin then
		pointSize = pointSizeMin
	end
	
	if (screenObjPos.Z > 0 and 
	isInRange(cameraPos, obj.Position, posRenderDistance) and
	isInRange(cameraPos, obj.Position, screenClippingDist) == false and
	pointPos.X > textAreaWidth and
	pointPos.X < textAreaWidth+screenDim.X and
	obj.Camera ~= true) then
		gui.drawEllipse(math.floor(pointPos.X-(pointSize/2)), math.floor(pointPos.Y-(pointSize/2)), pointSize, pointSize, 0x00000000, pointColor)
		
		if drawIndex then
			gui.text(math.floor(pointPos.X)+10, math.floor(pointPos.Y)-10, tostring(obj.Index))
		end
		for i, v in pairs(labelsToDraw) do
			gui.text(math.floor(pointPos.X)-20, math.floor(pointPos.Y)+((i-1)*14)+5, v)
		end
	end
end

local function getMatrixFromEuler(inputRot, inputMat)
	local outputMat = inputMat
	--NOTE: Roll and Pitch have swapped definitions
	local cr = math.cos(-inputRot.Pitch)
	local sr = math.sin(-inputRot.Pitch)
	local cy = math.cos(inputRot.Yaw)
	local sy = math.sin(inputRot.Yaw)
	local cp = math.cos(inputRot.Roll)
	local sp = math.sin(inputRot.Roll)
	
	outputMat.X.X = cy * cp
	outputMat.X.Y = sy * sr - cy * sp * cr
	outputMat.X.Z = cy * sp * sr + sy * cr
	outputMat.Y.X = sp
	outputMat.Y.Y = cp * cr
	outputMat.Y.Z = -cp * sr
	outputMat.Z.X = -sy * cp
	outputMat.Z.Y = sy * sp * cr + cy * sr
	outputMat.Z.Z = -sy * sp * sr + cy * cr
	
	return outputMat;
end

local function rotateVectorBuffer(inputBuffer)
	local outputBuffer = {}
	
	for i = 1, gameFrameDelay do
		outputBuffer[i] = {}
		
		outputBuffer[i].X = 0
		outputBuffer[i].Y = 0
		outputBuffer[i].Z = 0
	end
	
	for i = gameFrameDelay, 2, -1 do
		outputBuffer[i].X = inputBuffer[i-1].X
		outputBuffer[i].Y = inputBuffer[i-1].Y
		outputBuffer[i].Z = inputBuffer[i-1].Z
	end
	
	return outputBuffer
end

local function rotateMatBuffer(inputBuffer)
	local outputBuffer = {}
	
	for i = 1, gameFrameDelay do
		outputBuffer[i] = {}
		
		outputBuffer[i].X = {["X"] = 1, ["Y"] = 0, ["Z"] = 0}
		outputBuffer[i].Y = {["X"] = 0, ["Y"] = 1, ["Z"] = 0}
		outputBuffer[i].Z = {["X"] = 0, ["Y"] = 0, ["Z"] = 1}
	end
	
	for i = gameFrameDelay, 2, -1 do
		outputBuffer[i].X = inputBuffer[i-1].X
		outputBuffer[i].Y = inputBuffer[i-1].Y
		outputBuffer[i].Z = inputBuffer[i-1].Z
	end
	
	return outputBuffer;
end

local function rotateBuffer(inputBuffer)
	local outputBuffer = {}
	
	for i = 1, gameFrameDelay do
		outputBuffer[i] = 0
	end
	
	for i = gameFrameDelay, 2, -1 do
		outputBuffer[i] = inputBuffer[i-1]
	end
	
	return outputBuffer;
end

local function updateCamera()
	--The camera position is buffered to make the on-screen points line up with the game's own rendering.
	cameraPosBuffer = rotateVectorBuffer(cameraPosBuffer)
	
	cameraPosBuffer[1].X = memory.readfloat(0x750878, true)
	cameraPosBuffer[1].Y = memory.readfloat(0x75087C, true)
	cameraPosBuffer[1].Z = memory.readfloat(0x750880, true)
	
	cameraPos.X = cameraPosBuffer[gameFrameDelay].X
	cameraPos.Y = cameraPosBuffer[gameFrameDelay].Y
	cameraPos.Z = cameraPosBuffer[gameFrameDelay].Z
	
	--The camera FOV multiplier, too.
	FOVmultBuffer = rotateBuffer(FOVmultBuffer)
	
	FOVmultBuffer[1] = memory.readfloat(0x750874, true)
	
	FOVmult = FOVmultBuffer[gameFrameDelay]
end

local function updateCameraMat()
	--The camera matrix is buffered to make the on-screen points line up with the game's own rendering.
	cameraMatBuffer = rotateMatBuffer(cameraMatBuffer);
	
	cameraMatBuffer[1].X.X = memory.readfloat(0x48A1A0, true)
	cameraMatBuffer[1].Y.X = memory.readfloat(0x48A1A4, true)
	cameraMatBuffer[1].Z.X = memory.readfloat(0x48A1A8, true)
	
	cameraMatBuffer[1].X.Y = memory.readfloat(0x48A1B0, true)
	cameraMatBuffer[1].Y.Y = memory.readfloat(0x48A1B4, true)
	cameraMatBuffer[1].Z.Y = memory.readfloat(0x48A1B8, true)
	
	cameraMatBuffer[1].X.Z = memory.readfloat(0x48A1C0, true)
	cameraMatBuffer[1].Y.Z = memory.readfloat(0x48A1C4, true)
	cameraMatBuffer[1].Z.Z = memory.readfloat(0x48A1C8, true)
	
	cameraMatrix.X.X = cameraMatBuffer[gameFrameDelay].X.X
	cameraMatrix.Y.X = cameraMatBuffer[gameFrameDelay].Y.X
	cameraMatrix.Z.X = cameraMatBuffer[gameFrameDelay].Z.X
	
	cameraMatrix.X.Y = cameraMatBuffer[gameFrameDelay].X.Y
	cameraMatrix.Y.Y = cameraMatBuffer[gameFrameDelay].Y.Y
	cameraMatrix.Z.Y = cameraMatBuffer[gameFrameDelay].Z.Y
	
	cameraMatrix.X.Z = cameraMatBuffer[gameFrameDelay].X.Z
	cameraMatrix.Y.Z = cameraMatBuffer[gameFrameDelay].Y.Z
	cameraMatrix.Z.Z = cameraMatBuffer[gameFrameDelay].Z.Z
end

local function drawItemGeneric(item)
	textAreaHeight = textAreaHeight + itemDisplaySize
	
	local itemScreenYPos = textOffset
	local mouseHover = false
	local fillColour = 0xff202020
	
	if mouseClientPos.X > 0 and mouseClientPos.X < (textAreaWidth-scrollBarWidth)
	and mouseClientPos.Y > itemScreenYPos and mouseClientPos.Y < (itemScreenYPos + itemDisplaySize)
	then
		mouseHover = true
		fillColour = 0xff202040
	end
	
	if mouseHover and mouseCurrInput.Left and mouseLastInput.Left ~= true then
		specificItem = item.ID
		forms.setproperty(textboxSpecifyItem, "Text", specificItem)
		gui.addmessage("Set specified item class to " .. specificItem .. " (0x" .. bizstring.hex(item.Address) .. ")")
	end
	
	gui.drawRectangle(0, itemScreenYPos, textAreaWidth-scrollBarWidth, itemDisplaySize, 0xffa0a0a0, fillColour)
	
	if item.ID == specificItem then
		gui.drawEllipse(textAreaWidth-scrollBarWidth-20, textOffset+10, 12, 12, 0xffff0000, 0xffff0000)
	end

	if string.find(item.ID, "UNK: ") then
		highlightColor = "Orange"
	elseif itemIsHero(item.ID) then
		highlightColor = "Cyan"
	elseif item.Camera then
		highlightColor = 0xffffff7f
	else
		highlightColor = "White"
	end

	gui.drawText(0, textOffset, "Item " .. tostring(item.Index) .. ":", highlightColor, nil, titleTextSize)
	textOffset = textOffset + 15
	
	gui.drawText(0, textOffset, " Base Address: 0x" .. bizstring.hex(item.Address), highlightColor, nil, titleTextSize)
	textOffset = textOffset + 15
	
	gui.drawText(0, textOffset, " Class: " .. item.ID, highlightColor, nil, titleTextSize)
	textOffset = textOffset + 18
	
	if (item.Position.X ~= 0 and item.Position.Y ~= 0 and item.Position.Z) ~= 0 then
		gui.text(0, textOffset, string.format(" X: %.5f", item.Position.X))
		textOffset = textOffset + 15
		gui.text(0, textOffset, string.format(" Y: %.5f", item.Position.Y))
		textOffset = textOffset + 15
		gui.text(0, textOffset, string.format(" Z: %.5f", item.Position.Z))
		textOffset = textOffset - 30
		
		gui.text(math.floor(textAreaWidth/2), textOffset, string.format("Pitch: %.5f", item.Rotation.Pitch))
		textOffset = textOffset + 15
		gui.text(math.floor(textAreaWidth/2), textOffset, string.format("Yaw  : %.5f", item.Rotation.Yaw))
		textOffset = textOffset + 15
		gui.text(math.floor(textAreaWidth/2), textOffset, string.format("Roll : %.5f", item.Rotation.Roll))
		
		textOffset = textOffset + 18
	else
		textOffset = textOffset + 48
	end
end

local function drawTrigGeneric(trig)
	gui.drawText(0, textOffset, tostring(trig.Index), nil, nil, 16);
	textOffset = textOffset + 15;
	gui.drawText(0, textOffset, string.format("  0x%x", trig.Address));
	textOffset = textOffset + 15;
	--gui.drawText(0, textOffset, string.format("  %.5f", memory.readfloat(trigList_Addr[currIndex]+0x10, true)));
	
	if trig.GeoHash ~= "" then
		gui.drawText(0, textOffset, "  Geo Reference: " .. trig.GeoHash);
		textOffset = textOffset + 20;
	end
	
	gui.drawText(0, textOffset, "  Hash: " .. string.format("  0x%x", trig.TrigHash));
	textOffset = textOffset + 20;
end

local function drawItemListToScreen()
	--Sort the table by distance to the camera, so items don't overlap incorrectly
	table.sort(itemList, function(a, b) return a.DistFromCam > b.DistFromCam end)
	
	for i, item in pairs(itemList) do
		local pointColor = 0xd0ff0000
		if itemIsHero(item.ID) then
			pointColor = 0xd0E08030 --0xd04040FF
		end
		
		if forms.ischecked(checkRenderSpecific) then
			if item.ID == specificItem then
				drawPosToScreen(item, pointColor, true, {item.ID})
			end
		else
			drawPosToScreen(item, pointColor, true, {item.ID})
		end
	end
end

local function drawTrigListToScreen()
	for i, trig in pairs(trigList) do
		if i > trigListLength then
			break
		end
		if isInRange(cameraPos, trig.Position, trigRenderDistance) then
			drawPosToScreen(trig, 0xd00000ff, true, {tostring(trig.GeoHash)})
		end
	end
end

local function sortItemList()
	if sortMode == 1 then
		table.sort(itemList, function(a, b) return a.Index < b.Index end);
	elseif sortMode == 2 then
		table.sort(itemList, function(a, b) return a.Address < b.Address end);
	elseif sortMode == 3 then
		table.sort(itemList, function(a, b) return a.ID < b.ID end);
	end
end

local function drawItemListFull()
	itemRenderAreaStart = textOffset;
	
	sortItemList()
	
	-- Display all items and their properties
	for i, item in ipairs(itemList) do
		if i > endIndex then
			break
		elseif i >= startIndex then
			drawItemGeneric(item);
		end
	end
	
	renderLimit = math.floor((client.screenheight()-topTextHeight-30)/itemDisplaySize);
	
	itemRenderAreaEnd = textOffset;
end

local function drawItemListClose()
	sortItemList()
	
	for i, item in pairs(itemList) do
		if isInRange(item.Position, findHeroPos(), showCloseRange) then
			if textOffset < (screenDim.Y-itemDisplaySize) then
				drawItemGeneric(item)
			end
			
			if renderEnabled == true then
				if forms.ischecked(checkRenderSpecific) then
					if item.ID == specificItem then
						drawPosToScreen(item, 0xd0ff0000, true, {item.ID})
					end
				else
					drawPosToScreen(item, 0xd0ff0000, true, {item.ID})
				end
			end
		end
	end
end

local function drawItemListUnk()
	for i, item in pairs(itemList) do
		if string.find(item.ID, "UNK: ") then
			drawItemGeneric(item)
			if renderEnabled == true then
				drawPosToScreen(item, pointColor, true, {item.ID})
			end
		end
	end
end

local function drawCamera()
	textOffset = textOffset + 20
	if renderEnabled == true then
		gui.drawText(0, textOffset, "Only rendering to screen.", 0xffa0ffa0, nil, titleTextSize)
	else
		gui.drawText(0, textOffset, "On-screen rendering is off.\nPress " .. KEY_TOGGLE_RENDER .. " to turn it on.", 0xffc0a0a0, nil, titleTextSize)
	end
	textOffset = textOffset + 70
	
	gui.text(0, textOffset, "CAMERA")
	textOffset = textOffset + 30

	gui.text(0, textOffset, "Position")
	textOffset = textOffset + 15
	gui.text(0, textOffset, string.format("X: %.5f", cameraPos.X))
	textOffset = textOffset + 15
	gui.text(0, textOffset, string.format("Y: %.5f", cameraPos.Y))
	textOffset = textOffset + 15
	gui.text(0, textOffset, string.format("Z: %.5f", cameraPos.Z))
	textOffset = textOffset + 30
	
	gui.text(0, textOffset, "Matrix")
	textOffset = textOffset + 15
	gui.text(0, textOffset, string.format("(%.2f) (%.2f) (%.2f)", cameraMatrix.X.X, cameraMatrix.X.Y, cameraMatrix.X.Z))
	textOffset = textOffset + 15
	gui.text(0, textOffset, string.format("(%.2f) (%.2f) (%.2f)", cameraMatrix.Y.X, cameraMatrix.Y.Y, cameraMatrix.Y.Z))
	textOffset = textOffset + 15
	gui.text(0, textOffset, string.format("(%.2f) (%.2f) (%.2f)", cameraMatrix.Z.X, cameraMatrix.Z.Y, cameraMatrix.Z.Z))
	textOffset = textOffset + 30
end

local function drawTriggers()
	textOffset = textOffset + 20
	
	gui.drawText(0, textOffset, string.format("gpSE_TriggerList: 0x%x", bit.band(memory.read_u32_be(gpSE_TriggerList), 0xFFFFFF)))
	textOffset = textOffset + 15
	gui.drawText(0, textOffset, string.format("pnt_trigListBase: 0x%x", pnt_trigListBase))
	textOffset = textOffset + 30
	
	for i, trig in ipairs(trigList) do
		if isInRange(trig.Position, cameraPos, trigRenderDistance) and textOffset < (screenDim.Y-itemDisplaySize) then
			drawTrigGeneric(trig)
		end
		if textOffset > client.screenheight() then break end
	end
end

local function doControl()
	doToggleRender()
	
	if drawMode == 1 then
		doScroll()
	elseif drawMode == 2 then
		--doTeleport()
		doChangeCloseRange()
	end
	
	--doCycleModes()
end

local function drawTopTextFullList()
	local localTextOffset = 0
	
	gui.drawText(0, textOffset+localTextOffset, "Showing up to " .. tostring(renderLimit) .. " items.")
	localTextOffset = localTextOffset + 15
	
	gui.drawText(0, textOffset+localTextOffset, "Mousewheel to scroll.")
	localTextOffset = localTextOffset + 20
end

local function drawTopTextClose()
	local localTextOffset = 0
	
	gui.drawText(0, textOffset+localTextOffset, "Showing items within " .. tostring(showCloseRange) .. "\nunits of the Player.")
	localTextOffset = localTextOffset + 30
	
	--gui.drawText(0, textOffset+localTextOffset, "Press " .. KEY_TELEPORT .. " to teleport listed items to\nthe player.")
	--localTextOffset = localTextOffset + 30
	gui.drawText(0, textOffset+localTextOffset, "Press " .. KEY_INCREASE_RANGE .. " to increase distance,\n" .. KEY_DECREASE_RANGE .. " to decrease.")
	localTextOffset = localTextOffset + 30
end

local function drawTopText()
	if modes[drawMode].Type == "ITEM" then
		gui.drawText(0, textOffset, "           Item List Length: " .. tostring(itemListLength))
		textOffset = textOffset + 20
	elseif modes[drawMode].Type == "TRIG" then
		gui.drawText(0, textOffset, "Trigger List Length: " .. tostring(trigListLength))
		textOffset = textOffset + 20
	end
	
	gui.drawText(0, textOffset, "Mode: " .. modes[drawMode].Name, nil, nil, titleTextSize)
	textOffset = textOffset + 15
	--gui.drawText(0, textOffset, "Press " .. keyCycleMode .. " to cycle modes.")
	--textOffset = textOffset + 15
	gui.drawText(0, textOffset, "Press " .. KEY_TOGGLE_RENDER .. " to toggle on-screen rendering.")
	textOffset = textOffset + 20
	
	gui.drawText(0, textOffset, "LIST", nil, nil, 20)
	textOffset = textOffset + 20
	
	textAreaHeight = textOffset
	
	if drawMode == 1 then
		drawTopTextFullList()
		textOffset = textOffset + 35
		textAreaHeight = textAreaHeight + 35
		topTextHeight = textAreaHeight
	elseif drawMode == 2 then
		drawTopTextClose()
		textOffset = textOffset + 90
		textAreaHeight = textAreaHeight + 90
		topTextHeight = textAreaHeight
	elseif drawMode == 3 then
		gui.drawText(0, textOffset, "Showing items that are currently\nundefined.")
		textOffset = textOffset + 30
		textAreaHeight = textAreaHeight + 30
		topTextHeight = textAreaHeight
	end
	
	if itemListLength < 1 then
		gui.drawText(0, textOffset, "No items loaded.", "Red")
	end
end

local function drawScrollBar()
	local itemRenderAreaLength = itemRenderAreaEnd-itemRenderAreaStart
	local scrollBarStart = 0
	local scrollBarLength = 0
	
	scrollBarLength = math.floor((renderLimit/itemListLength)*itemRenderAreaLength)
	scrollBarStart = math.floor(((startIndex-1)/itemListLength)*itemRenderAreaLength)+1
	
	gui.drawRectangle(textAreaWidth-scrollBarWidth, itemRenderAreaStart, scrollBarWidth, itemRenderAreaLength, "Gray")
	gui.drawRectangle(textAreaWidth-scrollBarWidth, scrollBarStart+itemRenderAreaStart, scrollBarWidth, scrollBarLength, "White", "Gray")
end

local function updateIndexLimits()
	if startIndex > itemListLength-renderLimit+1 then
		startIndex = itemListLength-renderLimit+1
	end
	if startIndex < 1 then
		startIndex = 1
	end
	
	endIndex = startIndex + renderLimit-1
end

local function printItemList()
	local str = "ITEM LIST (" .. tostring(itemListLength) .. " in total)\n"
	
	for i, item in pairs(itemList) do
		str = str .. "--------------------------\n"
		str = str .. "Item #" .. tostring(i)
		if itemIsHero(i) then
			str = str .. " (PLAYER)"
		end
		str = str .. "\n"
		
		str = str .. string.format("  Base Address: 0x%x\n", item.Address)
		str = str .. "  Class: " .. itemList[i].ID .. "\n"
		str = str .. "  Position:\n"
		str = str .. string.format("    X    : %.5f\n", item.Position.X)
		str = str .. string.format("    Y    : %.5f\n", item.Position.Y)
		str = str .. string.format("    Z    : %.5f\n", item.Position.Z)
		str = str .. "  Rotation:\n"
		str = str .. string.format("    Pitch: %.5f\n", item.Rotation.Pitch)
		str = str .. string.format("    Yaw  : %.5f\n", item.Rotation.Yaw)
		str = str .. string.format("    Roll : %.5f\n", item.Rotation.Roll)
	end
	
	console.clear()
	console.log(str)
end

local function getMouseClientPos()
	return {
		X = math.floor(input.getmouse().X * screenScale) + textAreaWidth,
		Y = math.floor(input.getmouse().Y * screenScale) + emuScreenYOffset
	}
end

local function updateForms()
	if forms.ischecked(checkRenderToggle) then
		renderEnabled = true
	else
		renderEnabled = false
	end
	
	if forms.ischecked(checkItemUpdate) then
		itemUpdateEnabled = true
	else
		itemUpdateEnabled = false
	end
	
	local currentSelectedMode = forms.getproperty(dropDownModes, "SelectedItem")
	if currentSelectedMode == modes[1].Name then
		drawMode = 1
	elseif currentSelectedMode == modes[2].Name then
		drawMode = 2
	--elseif currentSelectedMode == modes[3].Name then
	--	drawMode = 3
	elseif currentSelectedMode == modes[4].Name then
		drawMode = 4
	elseif currentSelectedMode == modes[5].Name then
		drawMode = 5
	end
	
	local currentSelectedSort = forms.getproperty(dropDownSort, "SelectedItem")
	if currentSelectedSort == sortModes[1] then
		sortMode = 1
	elseif currentSelectedSort == sortModes[2] then
		sortMode = 2
	elseif currentSelectedSort == sortModes[3] then
		sortMode = 3
	end
	
	specificItem = forms.gettext(textboxSpecifyItem)
	
	if forms.ischecked(checkTeleportSpecificConstant) then
		teleportSpecificNextFrame = true
	end
end

cameraInit();

while true do
	--SCREEN UPDATE
	screenDim.Y = client.screenheight()
	screenDim.X = client.screenwidth()-textAreaWidth
	
	if (screenDim.X/screenDim.Y) < screenAspect then
		screenDim.Y = screenDim.X/screenAspect
		emuScreenYOffset = math.floor((client.screenheight()-screenDim.Y)/2)
	else
		emuScreenYOffset = 0
	end
	
	screenScale = screenDim.X/internalScreenDim.X
	
	--INPUT UPDATE
	mouseCurrInput = input.getmouse()
	mouseClientPos = getMouseClientPos()
	currInput = joypad.getimmediate()
	currKeyInput = input.get()
	currWheel = input.getmouse().Wheel

	--FORMS CHECK
	updateForms()
	
	--READ
	--Items
	pnt_itemListStart = bit.band(memory.read_u32_be(pnt_itemListBase), 0xFFFFFF)
	pnt_currItem = bit.band(memory.read_u32_be(pnt_itemListStart), 0xFFFFFF)
	if itemUpdateEnabled then
		itemListLength = memory.read_u32_be(0x46F6AC)
	end
	
	--Triggers
	pnt_trigListBase = bit.band(memory.read_u32_be(bit.band(memory.read_u32_be(gpSE_TriggerList), 0xFFFFFF)+0x1c), 0xFFFFFF)
	pnt_trigListStart = bit.band(memory.read_u32_be(pnt_trigListBase), 0xFFFFFF)
	
	--trigTableLength = memory.read_u32_be(pnt_trigListBase-0x8)
	--trigListLength = trigTableLength/4
	
	updateIndexLimits()
	if modes[drawMode].Type == "ITEM" and itemUpdateEnabled then
		updateItemList()
		if currKeyInput[KEY_PRINT_LIST] and lastKeyInput[KEY_PRINT_LIST] ~= true then
			printItemList()
		end
		
	elseif modes[drawMode].Type == "TRIG" and updateTrigListNextFrame then
		updateTrigListNextFrame = false
		updateTrigListLength()
		updateTrigList()
	end
	
	if renderEnabled then
		updateCamera()
		updateCameraMat()
	end
	
	--DISPLAY
	textOffset = 0
	
	drawTopText()
	
	if drawMode == 1 then
		drawItemListFull()
		if itemListLength > renderLimit then
			drawScrollBar()
		end
		if renderEnabled then
			drawItemListToScreen()
		end
	elseif drawMode == 2 then
		drawItemListClose()
	elseif drawMode == 3 then
		drawItemListUnk()
	elseif drawMode == 4 then
		drawCamera()
		if renderEnabled then
			drawItemListToScreen()
		end
	elseif drawMode == 5 then
		drawTriggers()
		if renderEnabled then
			drawTrigListToScreen()
		end
	end
	textOffset = textOffset + 10
	
	--Display how many more items are beyond the listed ones
	if itemListLength > renderLimit and startIndex <= (itemListLength - renderLimit) and drawMode == 1 then
		gui.drawText(0, textOffset, tostring(itemListLength-endIndex) .. " item(s) more...")
	end
	
	--CONTROL
	doControl()
	
	if teleportCloseNextFrame then
		teleportCloseNextFrame = false
		doTeleportClose()
	end
	if teleportSpecificNextFrame then
		teleportSpecificNextFrame = false
		doTeleportSpecific()
	end
	
	--gui.drawText(500, 500, string.format("X: %d\nY: %d", input.getmouse()["X"], input.getmouse()["Y"]))
	--gui.drawText(500, 550, string.format("X: %d\nY: %d", mouseClientPos["X"], mouseClientPos["Y"]))
	
	--AFTER FRAME INPUT UPDATE
	mouseLastInput = input.getmouse()
	lastInput = currInput
	lastKeyInput = currKeyInput
	lastWheel = currWheel
	
	emu.frameadvance()
end
