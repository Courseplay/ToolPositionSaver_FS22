---@class WorkingToolPositions
WorkingToolPositions = {
	NUM_OF_POSITIONS = 4,
	MAX_ROT_SPEED = 0.6,
	MIN_ROT_SPEED = 0.1,
	MAX_TRANS_SPEED = 1,
	MIN_TRANS_SPEED = 0.4,
}
WorkingToolPositions.MOD_NAME = g_currentModName
WorkingToolPositions.DEBUG = false


function WorkingToolPositions.initSpecialization()
	local schema = Vehicle.xmlSchemaSavegame
	local toolKey = "vehicles.vehicle(?).WorkingToolPositions.workingToolPositions.subVehicles(?)"
	schema:register(XMLValueType.ANGLE, toolKey .. ".position(?).movingTool(?)#curRot", "Rotation saved.")
	schema:register(XMLValueType.FLOAT, toolKey .. ".position(?).movingTool(?)#curTrans", "Translation saved.")
end


function WorkingToolPositions.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Shovel, specializations) or SpecializationUtil.hasSpecialization(DynamicMountAttacher, specializations)
end

function WorkingToolPositions.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", WorkingToolPositions)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", WorkingToolPositions)
end

function WorkingToolPositions.registerFunctions(vehicleType)
    --SpecializationUtil.registerFunction(vehicleType, "updateWorkingToolStateActionEventState", WorkingToolPositions.updateActionEventState)
   
end

function WorkingToolPositions:onPreDetach()
	WorkingToolPositions.actionEventResetAllPositions(self)
end

function WorkingToolPositions:onLoad(savegame)
	--- Register the spec: spec_WorkingToolPositions
    local specName = WorkingToolPositions.MOD_NAME .. ".workingToolPositions"
    self.spec_workingToolPositions = self["spec_" .. specName]
    local spec = self.spec_workingToolPositions

	spec.positions = {}

	spec.hasPositions = {
		false,false,false,false
	}
	spec.hasAtLeastOnePosition = false

	spec.currentPositionSelected = 1

	spec.currentPlayPositionIx = nil

	spec.texts = {
		setPosition = g_i18n:getText("WTP_SET_POSITION"),
		playPosition = g_i18n:getText("WTP_PLAY_POSITION"),
		resetPosition = g_i18n:getText("WTP_RESET_POSITION"),
		changePosition = g_i18n:getText("WTP_CHANGE_POSITION"),
	}
	spec.isDirty = false

	if self:getPropertyState() == Vehicle.PROPERTY_STATE_SHOP_CONFIG then
		return
	end
	WorkingToolPositions.loadPositionsFromXml(self,savegame)
end

function WorkingToolPositions:loadPositionsFromXml(savegame)
	if savegame == nil or savegame.resetVehicles then return end
	local spec = self.spec_workingToolPositions
	savegame.xmlFile:iterate(string.format("%s.WorkingToolPositions.workingToolPositions.subVehicles", savegame.key), function (id, baseKey)
		spec.positions[id-1] = {}
		savegame.xmlFile:iterate(baseKey..".position", function (ix, key)
			spec.positions[id-1][ix] = {}
			savegame.xmlFile:iterate(key..".movingTool", function (i, k)
				spec.positions[id-1][ix][i] = {}
				spec.positions[id-1][ix][i].curTrans =  savegame.xmlFile:getValue(k.."#curTrans")
				spec.positions[id-1][ix][i].curRot =  savegame.xmlFile:getValue(k.."#curRot")
				spec.hasPositions[ix] = true
				spec.hasAtLeastOnePosition = true
			end)
		end)
	end)
end

function WorkingToolPositions:saveToXMLFile(xmlFile, key, usedModNames)
	local rootVehicle = self:getRootVehicle()
	if rootVehicle == nil then return end
	local spec = self.spec_workingToolPositions
	if spec.positions == nil then return end
	for id,positions in pairs(spec.positions) do
		local baseKey = string.format("%s.subVehicles(%d)",key,id)
		for i, movingTools in ipairs(positions) do
			local posKey = string.format("%s.position(%d)", baseKey, i-1)
			for ix, tool in ipairs(movingTools) do
				local toolKey = string.format("%s.movingTool(%d)", posKey, ix-1)
				if tool.curTrans ~= nil then
					xmlFile:setValue(toolKey .. "#curTrans", tool.curTrans)
				end
				if tool.curRot ~= nil then
					xmlFile:setValue(toolKey .. "#curRot", tool.curRot)
				end	
			end
		end
	end
end

function WorkingToolPositions:onReadStream(streamId)
	local spec = self.spec_workingToolPositions
	for i=1,WorkingToolPositions.NUM_OF_POSITIONS do 
		spec.hasPositions[i] = streamReadBool(streamId)
		spec.hasAtLeastOnePosition = spec.hasPositions[i] or spec.hasAtLeastOnePosition
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
				_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.WTP_SET_OR_PLAY_POSITION, self, WorkingToolPositions.actionEventSetOrPlayPosition, false, true, false, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
				
				_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.WTP_RESET_POSITION, self, WorkingToolPositions.actionEventResetPosition, false, true, false, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
				g_inputBinding:setActionEventText(actionEventId, spec.texts.resetPosition)

				_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.WTP_CHANGE_POSITION, self, WorkingToolPositions.actionEventChangeCurrentPosition, false, true, false, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
				g_inputBinding:setActionEventText(actionEventId, spec.texts.changePosition)
				WorkingToolPositions.updateActionEventState(self)
			end
		end
	end

end

function WorkingToolPositions:updateActionEventState()
	local spec = self.spec_workingToolPositions
    local actionEvent = spec.actionEvents[InputAction.WTP_SET_OR_PLAY_POSITION]
	local text = spec.hasPositions[spec.currentPositionSelected] and spec.texts.playPosition or spec.texts.setPosition
	g_inputBinding:setActionEventText(actionEvent.actionEventId, string.format(text,spec.currentPositionSelected))

	actionEvent = spec.actionEvents[InputAction.WTP_RESET_POSITION]
	g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.hasPositions[spec.currentPositionSelected])
	g_inputBinding:setActionEventText(actionEvent.actionEventId, string.format(spec.texts.resetPosition,spec.currentPositionSelected))

	actionEvent = spec.actionEvents[InputAction.WTP_CHANGE_POSITION]
	g_inputBinding:setActionEventText(actionEvent.actionEventId, string.format(spec.texts.changePosition,spec.currentPositionSelected))
end

function WorkingToolPositions.actionEventSetOrPlayPosition(self, actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_workingToolPositions
	if spec.hasPositions[spec.currentPositionSelected] then 
		WorkingToolPositions.playPosition(self,spec.currentPositionSelected)
		WorkingToolsPositionEvent.sendPlayEvent(self)
	else 
		WorkingToolPositions.setPosition(self,spec.currentPositionSelected)
		WorkingToolsPositionEvent.sendSetEvent(self)
	end
end

function WorkingToolPositions.actionEventResetPosition(self, actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_workingToolPositions
	WorkingToolPositions.resetPosition(self,spec.currentPositionSelected)
	WorkingToolsPositionEvent.sendResetEvent(self)
end

function WorkingToolPositions.actionEventChangeCurrentPosition(self, actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_workingToolPositions
	WorkingToolPositions.changePosition(self)
	WorkingToolsPositionEvent.sendChangeEvent(self)
end


function WorkingToolPositions:setPosition(positionIx)
	WorkingToolPositions.debugVehicle(self,"Set position %d.",positionIx)
	local spec = self.spec_workingToolPositions
	spec.hasPositions[positionIx] = true
	spec.hasAtLeastOnePosition = true
	if g_server == nil then return end

	local cylinderedSpec = self.spec_cylindered
	local id = self.id	
	if spec.positions[id] == nil then 
		spec.positions[id] = {}
	end
	spec.positions[id][positionIx] = {}
	for toolIndex, tool in ipairs(cylinderedSpec.movingTools) do
		spec.positions[id][positionIx][toolIndex] = {}
		spec.positions[id][positionIx][toolIndex].curRot = tool.curRot[tool.rotationAxis]
		spec.positions[id][positionIx][toolIndex].curTrans = tool.curTrans[tool.translationAxis]
	end
	local rootVehicle = self:getRootVehicle()
	cylinderedSpec = rootVehicle.spec_cylindered
	id = rootVehicle.id
	if spec.positions[id] == nil then 
		spec.positions[id] = {}
	end
	spec.positions[id][positionIx] = {}
	for toolIndex, tool in ipairs(cylinderedSpec.movingTools) do
		spec.positions[id][positionIx][toolIndex] = {}
		spec.positions[id][positionIx][toolIndex].curRot = tool.curRot[tool.rotationAxis]
		spec.positions[id][positionIx][toolIndex].curTrans = tool.curTrans[tool.translationAxis]
	end
	WorkingToolPositions.updateActionEventState(self)
end

function WorkingToolPositions:resetPosition(positionIx)
	WorkingToolPositions.debugVehicle(self,"Reset position %d.",positionIx)
	local spec = self.spec_workingToolPositions
	if spec.hasPositions[positionIx] then 
		spec.hasPositions[positionIx] = false
		spec.positions[positionIx] = nil
	end
	WorkingToolPositions.updateActionEventState(self)
end

function WorkingToolPositions:playPosition(positionIx)
	WorkingToolPositions.debugVehicle(self,"Play position %d.",positionIx)
	local spec = self.spec_workingToolPositions
	if g_server == nil then return end
	if spec.hasPositions[positionIx] then 
		spec.currentPlayPositionIx = positionIx
	end
	WorkingToolPositions.updateActionEventState(self)
end


function WorkingToolPositions:changePosition()
	local spec = self.spec_workingToolPositions
	local newIx = spec.currentPositionSelected + 1
	if newIx > WorkingToolPositions.NUM_OF_POSITIONS then 
		newIx = 1
	end
	WorkingToolPositions.debugVehicle(self,"Changed current selected position ix from %d to %d.",spec.currentPositionSelected,newIx)
	spec.currentPositionSelected = newIx
	WorkingToolPositions.updateActionEventState(self)
end

function WorkingToolPositions:onUpdate(dt)
	if self:getPropertyState() == Vehicle.PROPERTY_STATE_SHOP_CONFIG then
		return
	end
	if g_server == nil then return end
	local spec = self.spec_workingToolPositions 
	if spec.currentPlayPositionIx == nil then
		spec.isDirty = nil
		return
	end

	local isDirty =	WorkingToolPositions.updateToolPositions(self,spec,dt)
	isDirty = WorkingToolPositions.updateToolPositions( self:getRootVehicle(),spec,dt) or isDirty
	spec.isDirty = isDirty
	if not isDirty then 
		WorkingToolPositions.debugVehicle(self,"Reset playing position %d",spec.currentPlayPositionIx)
		spec.currentPlayPositionIx = nil
	end
end

function WorkingToolPositions.updateToolPositions(object,spec,dt)
	local id = object.id
	local isDirty = false
	local cylinderedSpec = object.spec_cylindered
	local positions = spec.positions[id] and spec.positions[id][spec.currentPlayPositionIx] 		
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
	CHANGE = 2,
	PLAY = 3
}

local WorkingToolsPositionEvent_mt = Class(WorkingToolsPositionEvent, Event)

InitEventClass(WorkingToolsPositionEvent, "WorkingToolsPositionEvent")

function WorkingToolsPositionEvent.emptyNew()
	return Event.new(WorkingToolsPositionEvent_mt)
end

--- Creates a new Event
function WorkingToolsPositionEvent.new(vehicle,mode)
	local self = WorkingToolsPositionEvent.emptyNew()
	self.vehicle = vehicle
	self.mode = mode
	return self
end

--- Reads the serialized data on the receiving end of the event.
function WorkingToolsPositionEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.mode = streamReadUIntN(streamId,2)

	self:run(connection);
end

--- Writes the serialized data from the sender.
function WorkingToolsPositionEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId,self.vehicle)
	streamWriteUIntN(self.mode,2)
end

--- Runs the event on the receiving end of the event.
function WorkingToolsPositionEvent:run(connection) -- wir fuehren das empfangene event aus
	if self.vehicle then 
		local spec = self.vehicle.spec_workingToolPositions
		if spec then 
			if self.mode == WorkingToolsPositionEvent.SET then 
				WorkingToolPositions.setPosition(self.vehicle,spec.currentPositionSelected)
			elseif self.mode == WorkingToolsPositionEvent.RESET then
				WorkingToolPositions.resetPosition(self.vehicle,spec.currentPositionSelected)
			elseif self.mode == WorkingToolsPositionEvent.PLAY then
				WorkingToolPositions.playPosition(self.vehicle,spec.currentPositionSelected)
			else 
				WorkingToolPositions.changePosition(self.vehicle)
			end
		end
	end
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		g_server:broadcastEvent(WorkingToolsPositionEvent:new(self.vehicle,self.positionIx), nil, connection, self.vehicle)
	end
end

function WorkingToolsPositionEvent.sendEvent(vehicle,mode)
	if g_server ~= nil then
		g_server:broadcastEvent(WorkingToolsPositionEvent:new(vehicle,mode), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(WorkingToolsPositionEvent:new(vehicle,mode))
	end
end

function WorkingToolsPositionEvent.sendPlayEvent(vehicle)
	WorkingToolsPositionEvent.sendEvent(vehicle,WorkingToolsPositionEvent.PLAY)
end


function WorkingToolsPositionEvent.sendResetEvent(vehicle)
	WorkingToolsPositionEvent.sendEvent(vehicle,WorkingToolsPositionEvent.RESET)
end



function WorkingToolsPositionEvent.sendSetEvent(vehicle)
	WorkingToolsPositionEvent.sendEvent(vehicle,WorkingToolsPositionEvent.SET)
end


function WorkingToolsPositionEvent.sendChangeEvent(vehicle)
	WorkingToolsPositionEvent.sendEvent(vehicle,WorkingToolsPositionEvent.CHANGE)
end
