---@class WorkingToolPositions
WorkingToolPositions = {
	NUM_OF_POSITIONS = 4,
	MAX_ROT_SPEED = 0.6,
	MIN_ROT_SPEED = 0.1,
	MAX_TRANS_SPEED = 1,
	MIN_TRANS_SPEED = 0.4,
	MODE_SET_PLAY = 0,
	MODE_RESET = 1
}
WorkingToolPositions.MOD_NAME = g_currentModName
WorkingToolPositions.DEBUG = true
WorkingToolPositions.KEY = "."..WorkingToolPositions.MOD_NAME..".workingToolPositions."

function WorkingToolPositions.initSpecialization()
	local schema = Vehicle.xmlSchemaSavegame
	local toolKey = WorkingToolPositions.KEY
	schema:register(XMLValueType.INT, "vehicles.vehicle(?)" .. toolKey .. "position(?)#index","PositionIndex")
	schema:register(XMLValueType.ANGLE, "vehicles.vehicle(?)" .. toolKey .. "position(?).movingTool(?)#curRot", "Rotation saved.")
	schema:register(XMLValueType.FLOAT, "vehicles.vehicle(?)" .. toolKey .. "position(?).movingTool(?)#curTrans", "Translation saved.")
end

function WorkingToolPositions.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Cylindered, specializations)
end

function WorkingToolPositions.registerEvents(vehicleType)
	SpecializationUtil.registerEvent(vehicleType, "onWtpSetPositions")
	SpecializationUtil.registerEvent(vehicleType, "onWtpResetPositions")
	SpecializationUtil.registerEvent(vehicleType, "onWtpPlayPositions")
end

function WorkingToolPositions.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onPostAttach", WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onWtpSetPositions",WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onWtpResetPositions",WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onWtpPlayPositions",WorkingToolPositions)
end

function WorkingToolPositions.registerFunctions(vehicleType)
    --SpecializationUtil.registerFunction(vehicleType, "updateWorkingToolStateActionEventState", WorkingToolPositions.updateActionEventState)
end

function WorkingToolPositions:onPreDetach()
	WorkingToolPositions.updateActionEventState(self)
end

function WorkingToolPositions:onPostAttach()
	WorkingToolPositions.updateActionEventState(self)
end

function WorkingToolPositions:onLoad(savegame)
	--- Register the spec: spec_WorkingToolPositions
    local specName = WorkingToolPositions.MOD_NAME .. ".workingToolPositions"
    self.spec_workingToolPositions = self["spec_" .. specName]
    local spec = self.spec_workingToolPositions

	spec.positions = {}
	spec.isDirty = false

	if self:getPropertyState() == Vehicle.PROPERTY_STATE_SHOP_CONFIG then
		return
	end

	spec.hasPositions = {
		false,false,false,false
	}

	WorkingToolPositions.loadPositionsFromXml(self,savegame)


	if not SpecializationUtil.hasSpecialization(Drivable, self.specializations) then 
		SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", WorkingToolPositions)
		return 
	end

	spec.master = true

	spec.mode = WorkingToolPositions.MODE_SET_PLAY

	spec.texts = {
		setPosition = g_i18n:getText("WTP_SET_POSITION"),
		playPosition = g_i18n:getText("WTP_PLAY_POSITION"),
		resetPosition = g_i18n:getText("WTP_RESET_POSITION"),
		modeSetPlay = g_i18n:getText("WTP_MODE_SET_PLAY"),
		modeReset = g_i18n:getText("WTP_MODE_RESET"),
		modeSetPlayWarning = g_i18n:getText("WTP_MODE_CHANGED_TO_SET_PLAY"),
		modeResetWarning = g_i18n:getText("WTP_MODE_CHANGED_TO_RESET"),
	}	
end

function WorkingToolPositions:loadPositionsFromXml(savegame)
	if savegame == nil or savegame.resetVehicles then return end
	local spec = self.spec_workingToolPositions
	savegame.xmlFile:iterate(savegame.key..WorkingToolPositions.KEY.."position", function (ix, key)
		local index =  savegame.xmlFile:getValue(key.."#index")
		spec.positions[index] = {}
		savegame.xmlFile:iterate(key..".movingTool", function (i, k)
			spec.positions[index][i] = {}
			spec.positions[index][i].curTrans =  savegame.xmlFile:getValue(k.."#curTrans")
			spec.positions[index][i].curRot =  savegame.xmlFile:getValue(k.."#curRot")
			spec.hasPositions[index] = true
		end)
	end)
end

function WorkingToolPositions:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_workingToolPositions
	if spec.positions == nil then return end
	local j = 0
	for i, movingTools in ipairs(spec.positions) do
		local posKey = string.format("%s.position(%d)", key, j)
		xmlFile:setValue(posKey .. "#index", i)
		for ix, tool in ipairs(movingTools) do
			local toolKey = string.format("%s.movingTool(%d)", posKey, ix-1)
			if tool.curTrans ~= nil then
				xmlFile:setValue(toolKey .. "#curTrans", tool.curTrans)
			end
			if tool.curRot ~= nil then
				xmlFile:setValue(toolKey .. "#curRot", tool.curRot)
			end	
		end
		j = j + 1
	end

end

function WorkingToolPositions:onReadStream(streamId)
	local spec = self.spec_workingToolPositions
	for i=1,WorkingToolPositions.NUM_OF_POSITIONS do 
		spec.hasPositions[i] = streamReadBool(streamId)
	end
end

function WorkingToolPositions:onWriteStream(streamId)
	local spec = self.spec_workingToolPositions
	for i=1,WorkingToolPositions.NUM_OF_POSITIONS do 
		streamWriteBool(streamId,spec.hasPositions[i])
	end
end

--- Register toggle mouse state and CourseplaySpec action events
---@param isActiveForInput boolean
---@param isActiveForInputIgnoreSelection boolean
function WorkingToolPositions:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_workingToolPositions
		self:clearActionEventsTable(spec.actionEvents)
		
		local _, actionEventId = nil
		local entered = true
		if self.getIsEntered ~= nil then
			entered = self:getIsEntered()
		end
		if self:getIsActiveForInput(true, true) and entered and not self:getIsAIActive() then
			if isActiveForInputIgnoreSelection then
				for i=1,WorkingToolPositions.NUM_OF_POSITIONS do 
					_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction[string.format("WTP_POSITION_%d",i)], self, WorkingToolPositions.actionEventChangePosition, false, true, false, true,i)
					g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
				end
				
				_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.WTP_CHANGE_MODE, self, WorkingToolPositions.actionEventChangeMode, false, true, false, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
				WorkingToolPositions.updateActionEventState(self)
			end
		end
	end

end

function WorkingToolPositions:updateActionEventState()
	local spec = self.spec_workingToolPositions

	if spec.master == nil then 
		return
	end
    
	local hasMoveableTools = false 
	for _,tool in ipairs(self.spec_cylindered.movingTools) do
		if tool.axisActionIndex then 
			hasMoveableTools = true 
			break
		end
	end

	if hasMoveableTools == false then
		local childVehicles = self:getChildVehicles()
		for _, childVehicle in ipairs(childVehicles) do
			for _,tool in ipairs(childVehicle.spec_cylindered.movingTools) do
				if tool.axisActionIndex then 
					hasMoveableTools = true 
					break
				end
			end
			if hasMoveableTools then 
				break
			end
		end
	end

	for i=1,WorkingToolPositions.NUM_OF_POSITIONS do 
		local actionEvent = spec.actionEvents[InputAction[string.format("WTP_POSITION_%d",i)]]
		local text,isActive = "",true
		if spec.mode == WorkingToolPositions.MODE_SET_PLAY then 
			text = spec.hasPositions[i] and spec.texts.playPosition or spec.texts.setPosition
		else
			text = spec.texts.resetPosition
			isActive = spec.hasPositions[i]
		end
		g_inputBinding:setActionEventText(actionEvent.actionEventId, string.format(text,i))
		g_inputBinding:setActionEventActive(actionEvent.actionEventId,isActive and hasMoveableTools)
	end
	local actionEvent = spec.actionEvents[InputAction.WTP_CHANGE_MODE]
	local text = spec.mode == WorkingToolPositions.MODE_SET_PLAY and spec.texts.modeSetPlay or spec.texts.modeReset
	g_inputBinding:setActionEventText(actionEvent.actionEventId, text)
	g_inputBinding:setActionEventActive(actionEvent.actionEventId,hasMoveableTools)
end

function WorkingToolPositions.actionEventChangePosition(self, actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_workingToolPositions
	if spec.mode ==  WorkingToolPositions.MODE_SET_PLAY then
	
		if spec.hasPositions[callbackState] then 
			WorkingToolPositions.playPosition(self,callbackState)
			WorkingToolsPositionEvent.sendPlayEvent(self,callbackState)
		else 
			WorkingToolPositions.setPosition(self,callbackState)
			WorkingToolsPositionEvent.sendSetEvent(self,callbackState)
		end
	else 
		WorkingToolPositions.resetPosition(self,callbackState)
		WorkingToolsPositionEvent.sendResetEvent(self,callbackState)
	end
end

function WorkingToolPositions.actionEventChangeMode(self, actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_workingToolPositions
	spec.mode = spec.mode == WorkingToolPositions.MODE_SET_PLAY and WorkingToolPositions.MODE_RESET or WorkingToolPositions.MODE_SET_PLAY
	local text = spec.mode == WorkingToolPositions.MODE_SET_PLAY and spec.texts.modeSetPlayWarning or spec.texts.modeResetWarning
	g_currentMission.hud:showBlinkingWarning(text,500)
	WorkingToolPositions.updateActionEventState(self)
end


function WorkingToolPositions:setPosition(positionIx)
	WorkingToolPositions.debugVehicle(self,"Set position %d.",positionIx)
	local spec = self.spec_workingToolPositions
	spec.hasPositions[positionIx] = true
	WorkingToolPositions.updateActionEventState(self)
	if g_server == nil then return end
	local childVehicles = self:getChildVehicles()
	for _, childVehicle in ipairs(childVehicles) do
		SpecializationUtil.raiseEvent(childVehicle, "onWtpSetPositions", positionIx)
	end
end

function WorkingToolPositions:onWtpSetPositions(positionIx)
	WorkingToolPositions.debugVehicle(self,"onWtpSetPositions")
	local spec = self.spec_workingToolPositions
	local cylinderedSpec = self.spec_cylindered
	spec.positions[positionIx] = {}
	spec.hasPositions[positionIx] = true
	for toolIndex, tool in ipairs(cylinderedSpec.movingTools) do
		spec.positions[positionIx][toolIndex] = {}
		spec.positions[positionIx][toolIndex].curRot = tool.curRot[tool.rotationAxis]
		spec.positions[positionIx][toolIndex].curTrans = tool.curTrans[tool.translationAxis]
	end
end

function WorkingToolPositions:resetPosition(positionIx)
	WorkingToolPositions.debugVehicle(self,"Reset position %d.",positionIx)
	local spec = self.spec_workingToolPositions
	spec.hasPositions[positionIx] = false
	WorkingToolPositions.updateActionEventState(self)
	local childVehicles = self:getChildVehicles()
	for _, childVehicle in ipairs(childVehicles) do
		SpecializationUtil.raiseEvent(childVehicle, "onWtpResetPositions", positionIx)
	end
end

function WorkingToolPositions:onWtpResetPositions(positionIx)
	WorkingToolPositions.debugVehicle(self,"onWtpResetPositions")
	local spec = self.spec_workingToolPositions
	spec.hasPositions[positionIx] = false
	spec.positions[positionIx] = {}
end

function WorkingToolPositions:playPosition(positionIx)
	WorkingToolPositions.debugVehicle(self,"Play position %d.",positionIx)
	WorkingToolPositions.updateActionEventState(self)
	local childVehicles = self:getChildVehicles()
	for _, childVehicle in ipairs(childVehicles) do
		SpecializationUtil.raiseEvent(childVehicle, "onWtpPlayPositions", positionIx)
	end
end

function WorkingToolPositions:onWtpPlayPositions(positionIx)
	WorkingToolPositions.debugVehicle(self,"onWtpPlayPositions")
	local spec = self.spec_workingToolPositions
	if g_server == nil then return end
	if spec.hasPositions[positionIx] then 
		spec.currentPlayPositionIx = positionIx
	end
end


function WorkingToolPositions:onUpdate(dt)
	local spec = self.spec_workingToolPositions 
	if self:getPropertyState() == Vehicle.PROPERTY_STATE_SHOP_CONFIG then
		return
	end
	if g_server == nil then return end
	if spec.currentPlayPositionIx == nil then
		spec.isDirty = nil
		return
	end

	spec.isDirty =	WorkingToolPositions.updateToolPositions(self,dt)
	if not spec.isDirty then 
		WorkingToolPositions.debugVehicle(self,"Reset playing position %d",spec.currentPlayPositionIx)
		spec.currentPlayPositionIx = nil
	end
end

function WorkingToolPositions.updateToolPositions(object,dt)
	local isDirty = false
	local cylinderedSpec = object.spec_cylindered
	local spec = object.spec_workingToolPositions 
	local positions = spec.positions and spec.positions[spec.currentPlayPositionIx] 		
	if positions then
		for toolIndex, tool in ipairs(cylinderedSpec.movingTools) do
			if object:getIsMovingToolActive(tool) and positions[toolIndex] then 
				local isRotating = WorkingToolPositions.checkToolRotation(object,tool,positions[toolIndex],dt) 
				local isMoving = WorkingToolPositions.checkToolTranslation(object,tool,positions[toolIndex],dt)
				isDirty = isDirty or isRotating or isMoving
			end
		end
	end
	return isDirty
end


function WorkingToolPositions:isDirty()
	return self.spec_workingToolPositions.isDirty	
end

--- Updates rotation for a tool along an axis.
---@param object table vehicle or implement
---@param tool table part of object.movingTools
---@param position table position index to move.
---@param dt number
function WorkingToolPositions.checkToolRotation(object,tool,position,dt)
	local spec = object.spec_cylindered
	if tool.rotSpeed == nil or position.curRot  == nil then
		return false,0
	end

	local curRot = { getRotation(tool.node) }
	local newRot = curRot[tool.rotationAxis]
	local diff = position.curRot - newRot
	local normDiff = (2*math.pi-math.abs(diff))/(2*math.pi)
	local rotSpeed = MathUtil.clamp(normDiff,WorkingToolPositions.MIN_ROT_SPEED,WorkingToolPositions.MAX_ROT_SPEED)*tool.rotSpeed
	if diff < 0 then
		rotSpeed=rotSpeed*(-1)
	end
	if math.abs(diff) < 0.03 or rotSpeed == 0 then
		tool.move = 0
		return false,0
	end
	WorkingToolPositions.debugVehicle(object,"RotDiff: %.2f,NormDiff: %.2f, RotSpeed: %.4f",diff,normDiff,rotSpeed)
	if Cylindered.setToolRotation(object, tool, rotSpeed, dt) then
		Cylindered.setDirty(object, tool)
	end
	object:raiseDirtyFlags(spec.cylinderedDirtyFlag)
    return true,math.abs(diff)*2*math.pi
end

--- Updates translation for a tool along an axis.
---@param object table vehicle or implement
---@param tool table part of object.movingTools
---@param position table position index to move.
---@param dt number
function WorkingToolPositions.checkToolTranslation(object,tool,position,dt)	
	local spec = object.spec_cylindered
	if tool.transSpeed == nil or position.curTrans == nil then
		return false,0
	end
	
	local curTrans = { getTranslation(tool.node) }
	local newTrans = curTrans[tool.translationAxis]
	local diff =  position.curTrans - newTrans
	local transSpeed = MathUtil.clamp(diff,WorkingToolPositions.MIN_TRANS_SPEED,WorkingToolPositions.MAX_TRANS_SPEED)*tool.transSpeed
	if diff < 0 then
		transSpeed=transSpeed*(-1)
	end
	if math.abs(diff) < 0.03 or transSpeed == 0 then
		tool.move = 0
		return false,0
	end
	WorkingToolPositions.debugVehicle(object,"TransDiff: %.2f, TransSpeed: %.2f",diff,transSpeed)
	if Cylindered.setToolTranslation(object, tool, transSpeed, dt) then
		Cylindered.setDirty(object, tool)
	end
	object:raiseDirtyFlags(spec.cylinderedDirtyFlag)
	return true,math.abs(diff)
end

function WorkingToolPositions.debugVehicle(vehicle,str,...)
	if WorkingToolPositions.DEBUG then
		print(string.format("%s: %s",vehicle:getName(),string.format(str,...)))
	end
end

function WorkingToolPositions.register(typeManager)
	for typeName, typeEntry in pairs(typeManager.types) do
		if  WorkingToolPositions.prerequisitesPresent(typeEntry.specializations) then
			typeManager:addSpecialization(typeName, WorkingToolPositions.MOD_NAME .. ".workingToolPositions")	
		end
    end
end
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, WorkingToolPositions.register)

---@class WorkingToolsPositionEvent
WorkingToolsPositionEvent = {
	SET = 0,
	RESET = 1,
	PLAY = 2
}

local WorkingToolsPositionEvent_mt = Class(WorkingToolsPositionEvent, Event)

InitEventClass(WorkingToolsPositionEvent, "WorkingToolsPositionEvent")

function WorkingToolsPositionEvent.emptyNew()
	return Event.new(WorkingToolsPositionEvent_mt)
end

--- Creates a new Event
function WorkingToolsPositionEvent.new(vehicle,mode,positionIx)
	local self = WorkingToolsPositionEvent.emptyNew()
	self.vehicle = vehicle
	self.mode = mode
	self.positionIx = positionIx
	return self
end

--- Reads the serialized data on the receiving end of the event.
function WorkingToolsPositionEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.mode = streamReadUIntN(streamId,2)
	self.positionIx = streamReadUIntN(streamId,3)
	self:run(connection);
end

--- Writes the serialized data from the sender.
function WorkingToolsPositionEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId,self.vehicle)
	streamWriteUIntN(self.mode,2)
	streamWriteUIntN(self.positionIx,3)
end

--- Runs the event on the receiving end of the event.
function WorkingToolsPositionEvent:run(connection) -- wir fuehren das empfangene event aus
	if self.vehicle then 
		local spec = self.vehicle.spec_workingToolPositions
		if spec then 
			if self.mode == WorkingToolsPositionEvent.SET then 
				WorkingToolPositions.setPosition(self.vehicle,self.positionIx)
			elseif self.mode == WorkingToolsPositionEvent.RESET then
				WorkingToolPositions.resetPosition(self.vehicle,self.positionIx)
			elseif self.mode == WorkingToolsPositionEvent.PLAY then
				WorkingToolPositions.playPosition(self.vehicle,self.positionIx)
			end
		end
	end
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		g_server:broadcastEvent(WorkingToolsPositionEvent.new(self.vehicle,self.mode,self.positionIx), nil, connection, self.vehicle)
	end
end

function WorkingToolsPositionEvent.sendEvent(vehicle,mode,positionIx)
	if g_server ~= nil then
		g_server:broadcastEvent(WorkingToolsPositionEvent.new(vehicle,mode,positionIx), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(WorkingToolsPositionEvent.new(vehicle,mode,positionIx))
	end
end

function WorkingToolsPositionEvent.sendPlayEvent(vehicle,positionIx)
	WorkingToolsPositionEvent.sendEvent(vehicle,WorkingToolsPositionEvent.PLAY,positionIx)
end


function WorkingToolsPositionEvent.sendResetEvent(vehicle,positionIx)
	WorkingToolsPositionEvent.sendEvent(vehicle,WorkingToolsPositionEvent.RESET,positionIx)
end



function WorkingToolsPositionEvent.sendSetEvent(vehicle,positionIx)
	WorkingToolsPositionEvent.sendEvent(vehicle,WorkingToolsPositionEvent.SET,positionIx)
end
