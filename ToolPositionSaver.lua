---@class ToolPositionSaver
ToolPositionSaver = {
	NUM_OF_POSITIONS = 4,
	MAX_ROT_SPEED = 0.6,
	MIN_ROT_SPEED = 0.1,
	MAX_TRANS_SPEED = 1,
	MIN_TRANS_SPEED = 0.4,
	MODE_SET_PLAY = 0,
	MODE_RESET = 1
}
ToolPositionSaver.MOD_NAME = g_currentModName
ToolPositionSaver.DEBUG = true
ToolPositionSaver.KEY = "."..ToolPositionSaver.MOD_NAME..".toolPositionSaver."

function ToolPositionSaver.initSpecialization()
	local schema = Vehicle.xmlSchemaSavegame
	local toolKey = ToolPositionSaver.KEY
	schema:register(XMLValueType.INT, "vehicles.vehicle(?)" .. toolKey .. "position(?)#index","PositionIndex")
	schema:register(XMLValueType.ANGLE, "vehicles.vehicle(?)" .. toolKey .. "position(?).movingTool(?)#curRot", "Rotation saved.")
	schema:register(XMLValueType.FLOAT, "vehicles.vehicle(?)" .. toolKey .. "position(?).movingTool(?)#curTrans", "Translation saved.")
end

function ToolPositionSaver.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Cylindered, specializations)
end

function ToolPositionSaver.registerEvents(vehicleType)
	SpecializationUtil.registerEvent(vehicleType, "onTpsSetPositions")
	SpecializationUtil.registerEvent(vehicleType, "onTpsResetPositions")
	SpecializationUtil.registerEvent(vehicleType, "onTpsPlayPositions")
end

function ToolPositionSaver.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ToolPositionSaver)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ToolPositionSaver)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", ToolPositionSaver)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", ToolPositionSaver)
	SpecializationUtil.registerEventListener(vehicleType, "onPostAttach", ToolPositionSaver)
	SpecializationUtil.registerEventListener(vehicleType, "onTpsSetPositions",ToolPositionSaver)
	SpecializationUtil.registerEventListener(vehicleType, "onTpsResetPositions",ToolPositionSaver)
	SpecializationUtil.registerEventListener(vehicleType, "onTpsPlayPositions",ToolPositionSaver)
end

function ToolPositionSaver.registerFunctions(vehicleType)
    --SpecializationUtil.registerFunction(vehicleType, "updateToolPositionStateActionEventState", ToolPositionSaver.updateActionEventState)
end

function ToolPositionSaver:onPreDetach()
	ToolPositionSaver.updateActionEventState(self)
end

function ToolPositionSaver:onPostAttach()
	ToolPositionSaver.updateActionEventState(self)
end

function ToolPositionSaver:onLoad(savegame)
	--- Register the spec: spec_ToolPositionSaver
    local specName = ToolPositionSaver.MOD_NAME .. ".toolPositionSaver"
    self.spec_toolPositionSaver = self["spec_" .. specName]
    local spec = self.spec_toolPositionSaver

	spec.positions = {}
	spec.isDirty = false

	if self:getPropertyState() == Vehicle.PROPERTY_STATE_SHOP_CONFIG then
		return
	end

	spec.hasPositions = {
		false,false,false,false
	}

	ToolPositionSaver.loadPositionsFromXml(self,savegame)


	if not SpecializationUtil.hasSpecialization(Drivable, self.specializations) then 
		SpecializationUtil.removeEventListener(self, "onRegisterActionEvents", ToolPositionSaver)
		return 
	end

	spec.master = true

	spec.mode = ToolPositionSaver.MODE_SET_PLAY

	spec.texts = {
		setPosition = g_i18n:getText("TPS_SET_POSITION"),
		playPosition = g_i18n:getText("TPS_PLAY_POSITION"),
		resetPosition = g_i18n:getText("TPS_RESET_POSITION"),
		modeSetPlay = g_i18n:getText("TPS_MODE_SET_PLAY"),
		modeReset = g_i18n:getText("TPS_MODE_RESET"),
		modeSetPlayWarning = g_i18n:getText("TPS_MODE_CHANGED_TO_SET_PLAY"),
		modeResetWarning = g_i18n:getText("TPS_MODE_CHANGED_TO_RESET"),
	}	
end

function ToolPositionSaver:loadPositionsFromXml(savegame)
	if savegame == nil or savegame.resetVehicles then return end
	local spec = self.spec_toolPositionSaver
	savegame.xmlFile:iterate(savegame.key..ToolPositionSaver.KEY.."position", function (ix, key)
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

function ToolPositionSaver:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self.spec_toolPositionSaver
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

function ToolPositionSaver:onReadStream(streamId)
	local spec = self.spec_toolPositionSaver
	for i=1,ToolPositionSaver.NUM_OF_POSITIONS do 
		spec.hasPositions[i] = streamReadBool(streamId)
	end
end

function ToolPositionSaver:onWriteStream(streamId)
	local spec = self.spec_toolPositionSaver
	for i=1,ToolPositionSaver.NUM_OF_POSITIONS do 
		streamWriteBool(streamId,spec.hasPositions[i])
	end
end

--- Register toggle mouse state and CourseplaySpec action events
---@param isActiveForInput boolean
---@param isActiveForInputIgnoreSelection boolean
function ToolPositionSaver:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self.spec_toolPositionSaver
		self:clearActionEventsTable(spec.actionEvents)
		
		local _, actionEventId = nil
		local entered = true
		if self.getIsEntered ~= nil then
			entered = self:getIsEntered()
		end
		if self:getIsActiveForInput(true, true) and entered and not self:getIsAIActive() then
			if isActiveForInputIgnoreSelection then
				for i=1,ToolPositionSaver.NUM_OF_POSITIONS do 
					_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction[string.format("TPS_POSITION_%d",i)], self, ToolPositionSaver.actionEventChangePosition, false, true, false, true,i)
					g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
				end
				
				_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TPS_CHANGE_MODE, self, ToolPositionSaver.actionEventChangeMode, false, true, false, true)
				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
				ToolPositionSaver.updateActionEventState(self)
			end
		end
	end

end

function ToolPositionSaver:updateActionEventState()
	local spec = self.spec_toolPositionSaver

	if spec.master == nil then 
		return
	end
    
	if spec.actionEvents == nil or next(spec.actionEvents) == nil then
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

	for i=1,ToolPositionSaver.NUM_OF_POSITIONS do 
		local actionEvent = spec.actionEvents[InputAction[string.format("TPS_POSITION_%d",i)]]
		local text,isActive = "",true
		if spec.mode == ToolPositionSaver.MODE_SET_PLAY then 
			text = spec.hasPositions[i] and spec.texts.playPosition or spec.texts.setPosition
		else
			text = spec.texts.resetPosition
			isActive = spec.hasPositions[i]
		end
		g_inputBinding:setActionEventText(actionEvent.actionEventId, string.format(text,i))
		g_inputBinding:setActionEventActive(actionEvent.actionEventId,isActive and hasMoveableTools)
	end
	local actionEvent = spec.actionEvents[InputAction.TPS_CHANGE_MODE]
	local text = spec.mode == ToolPositionSaver.MODE_SET_PLAY and spec.texts.modeSetPlay or spec.texts.modeReset
	g_inputBinding:setActionEventText(actionEvent.actionEventId, text)
	g_inputBinding:setActionEventActive(actionEvent.actionEventId,hasMoveableTools)
end

function ToolPositionSaver.actionEventChangePosition(self, actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_toolPositionSaver
	if spec.mode ==  ToolPositionSaver.MODE_SET_PLAY then
	
		if spec.hasPositions[callbackState] then 
			ToolPositionSaver.playPosition(self,callbackState)
			ToolPositionSaverEvent.sendPlayEvent(self,callbackState)
		else 
			ToolPositionSaver.setPosition(self,callbackState)
			ToolPositionSaverEvent.sendSetEvent(self,callbackState)
		end
	else 
		ToolPositionSaver.resetPosition(self,callbackState)
		ToolPositionSaverEvent.sendResetEvent(self,callbackState)
	end
end

function ToolPositionSaver.actionEventChangeMode(self, actionName, inputValue, callbackState, isAnalog)
	local spec = self.spec_toolPositionSaver
	spec.mode = spec.mode == ToolPositionSaver.MODE_SET_PLAY and ToolPositionSaver.MODE_RESET or ToolPositionSaver.MODE_SET_PLAY
	local text = spec.mode == ToolPositionSaver.MODE_SET_PLAY and spec.texts.modeSetPlayWarning or spec.texts.modeResetWarning
	g_currentMission.hud:showBlinkingWarning(text,500)
	ToolPositionSaver.updateActionEventState(self)
end


function ToolPositionSaver:setPosition(positionIx)
	ToolPositionSaver.debugVehicle(self,"Set position %d.",positionIx)
	local spec = self.spec_toolPositionSaver
	spec.hasPositions[positionIx] = true
	ToolPositionSaver.updateActionEventState(self)
	if g_server == nil then return end
	local childVehicles = self:getChildVehicles()
	for _, childVehicle in ipairs(childVehicles) do
		SpecializationUtil.raiseEvent(childVehicle, "onTpsSetPositions", positionIx)
	end
end

function ToolPositionSaver:onTpsSetPositions(positionIx)
	ToolPositionSaver.debugVehicle(self,"onTpsSetPositions")
	local spec = self.spec_toolPositionSaver
	local cylinderedSpec = self.spec_cylindered
	spec.positions[positionIx] = {}
	spec.hasPositions[positionIx] = true
	for toolIndex, tool in ipairs(cylinderedSpec.movingTools) do
		spec.positions[positionIx][toolIndex] = {}
		spec.positions[positionIx][toolIndex].curRot = tool.curRot[tool.rotationAxis]
		spec.positions[positionIx][toolIndex].curTrans = tool.curTrans[tool.translationAxis]
	end
end

function ToolPositionSaver:resetPosition(positionIx)
	ToolPositionSaver.debugVehicle(self,"Reset position %d.",positionIx)
	local spec = self.spec_toolPositionSaver
	spec.hasPositions[positionIx] = false
	ToolPositionSaver.updateActionEventState(self)
	local childVehicles = self:getChildVehicles()
	for _, childVehicle in ipairs(childVehicles) do
		SpecializationUtil.raiseEvent(childVehicle, "onTpsResetPositions", positionIx)
	end
end

function ToolPositionSaver:onTpsResetPositions(positionIx)
	ToolPositionSaver.debugVehicle(self,"onTpsResetPositions")
	local spec = self.spec_toolPositionSaver
	spec.hasPositions[positionIx] = false
	spec.positions[positionIx] = {}
end

function ToolPositionSaver:playPosition(positionIx)
	ToolPositionSaver.debugVehicle(self,"Play position %d.",positionIx)
	ToolPositionSaver.updateActionEventState(self)
	local childVehicles = self:getChildVehicles()
	for _, childVehicle in ipairs(childVehicles) do
		SpecializationUtil.raiseEvent(childVehicle, "onTpsPlayPositions", positionIx)
	end
end

function ToolPositionSaver:onTpsPlayPositions(positionIx)
	ToolPositionSaver.debugVehicle(self,"onTpsPlayPositions")
	local spec = self.spec_toolPositionSaver
	if g_server == nil then return end
	if spec.hasPositions[positionIx] then 
		spec.currentPlayPositionIx = positionIx
	end
end


function ToolPositionSaver:onUpdate(dt)
	local spec = self.spec_toolPositionSaver
	if self:getPropertyState() == Vehicle.PROPERTY_STATE_SHOP_CONFIG then
		return
	end
	if g_server == nil then return end
	if spec.currentPlayPositionIx == nil then
		spec.isDirty = nil
		return
	end

	spec.isDirty =	ToolPositionSaver.updateToolPositions(self,dt)
	if not spec.isDirty then 
		ToolPositionSaver.debugVehicle(self,"Reset playing position %d",spec.currentPlayPositionIx)
		spec.currentPlayPositionIx = nil
	end
end

function ToolPositionSaver.updateToolPositions(object,dt)
	local isDirty = false
	local cylinderedSpec = object.spec_cylindered
	local spec = object.spec_toolPositionSaver
	local positions = spec.positions and spec.positions[spec.currentPlayPositionIx] 		
	if positions then
		for toolIndex, tool in ipairs(cylinderedSpec.movingTools) do
			if object:getIsMovingToolActive(tool) and positions[toolIndex] then 
				local isRotating = ToolPositionSaver.checkToolRotation(object,tool,positions[toolIndex],dt) 
				local isMoving = ToolPositionSaver.checkToolTranslation(object,tool,positions[toolIndex],dt)
				isDirty = isDirty or isRotating or isMoving
			end
		end
	end
	return isDirty
end


function ToolPositionSaver:isDirty()
	return self.spec_toolPositionSaver.isDirty	
end

--- Updates rotation for a tool along an axis.
---@param object table vehicle or implement
---@param tool table part of object.movingTools
---@param position table position index to move.
---@param dt number
function ToolPositionSaver.checkToolRotation(object,tool,position,dt)
	local spec = object.spec_cylindered
	if tool.rotSpeed == nil or position.curRot  == nil then
		return false,0
	end

	local curRot = { getRotation(tool.node) }
	local newRot = curRot[tool.rotationAxis]
	local diff = position.curRot - newRot
	local normDiff = (2*math.pi-math.abs(diff))/(2*math.pi)
	local rotSpeed = MathUtil.clamp(normDiff,ToolPositionSaver.MIN_ROT_SPEED,ToolPositionSaver.MAX_ROT_SPEED)*tool.rotSpeed
	if diff < 0 then
		rotSpeed=rotSpeed*(-1)
	end
	if math.abs(diff) < 0.03 or rotSpeed == 0 then
		tool.move = 0
		return false,0
	end
	ToolPositionSaver.debugVehicle(object,"RotDiff: %.2f,NormDiff: %.2f, RotSpeed: %.4f",diff,normDiff,rotSpeed)
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
function ToolPositionSaver.checkToolTranslation(object,tool,position,dt)	
	local spec = object.spec_cylindered
	if tool.transSpeed == nil or position.curTrans == nil then
		return false,0
	end
	
	local curTrans = { getTranslation(tool.node) }
	local newTrans = curTrans[tool.translationAxis]
	local diff =  position.curTrans - newTrans
	local transSpeed = MathUtil.clamp(diff,ToolPositionSaver.MIN_TRANS_SPEED,ToolPositionSaver.MAX_TRANS_SPEED)*tool.transSpeed
	if diff < 0 then
		transSpeed=transSpeed*(-1)
	end
	if math.abs(diff) < 0.03 or transSpeed == 0 then
		tool.move = 0
		return false,0
	end
	ToolPositionSaver.debugVehicle(object,"TransDiff: %.2f, TransSpeed: %.2f",diff,transSpeed)
	if Cylindered.setToolTranslation(object, tool, transSpeed, dt) then
		Cylindered.setDirty(object, tool)
	end
	object:raiseDirtyFlags(spec.cylinderedDirtyFlag)
	return true,math.abs(diff)
end

function ToolPositionSaver.debugVehicle(vehicle,str,...)
	if ToolPositionSaver.DEBUG then
		print(string.format("%s: %s",vehicle:getName(),string.format(str,...)))
	end
end

function ToolPositionSaver.register(typeManager)
	for typeName, typeEntry in pairs(typeManager.types) do
		if  ToolPositionSaver.prerequisitesPresent(typeEntry.specializations) then
			typeManager:addSpecialization(typeName, ToolPositionSaver.MOD_NAME .. ".toolPositionSaver")	
		end
    end
end
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, ToolPositionSaver.register)

---@class ToolPositionSaverEvent
ToolPositionSaverEvent = {
	SET = 0,
	RESET = 1,
	PLAY = 2
}

local ToolPositionSaverEvent_mt = Class(ToolPositionSaverEvent, Event)

InitEventClass(ToolPositionSaverEvent, "ToolPositionSaverEvent")

function ToolPositionSaverEvent.emptyNew()
	return Event.new(ToolPositionSaverEvent_mt)
end

--- Creates a new Event
function ToolPositionSaverEvent.new(vehicle,mode,positionIx)
	local self = ToolPositionSaverEvent.emptyNew()
	self.vehicle = vehicle
	self.mode = mode
	self.positionIx = positionIx
	return self
end

--- Reads the serialized data on the receiving end of the event.
function ToolPositionSaverEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.mode = streamReadUIntN(streamId,2)
	self.positionIx = streamReadUIntN(streamId,3)
	self:run(connection);
end

--- Writes the serialized data from the sender.
function ToolPositionSaverEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId,self.vehicle)
	streamWriteUIntN(streamId,self.mode,2)
	streamWriteUIntN(streamId,self.positionIx,3)
end

--- Runs the event on the receiving end of the event.
function ToolPositionSaverEvent:run(connection) -- wir fuehren das empfangene event aus
	if self.vehicle then 
		local spec = self.vehicle.spec_toolPositionSaver
		if spec then 
			if self.mode == ToolPositionSaverEvent.SET then 
				ToolPositionSaver.setPosition(self.vehicle,self.positionIx)
			elseif self.mode == ToolPositionSaverEvent.RESET then
				ToolPositionSaver.resetPosition(self.vehicle,self.positionIx)
			elseif self.mode == ToolPositionSaverEvent.PLAY then
				ToolPositionSaver.playPosition(self.vehicle,self.positionIx)
			end
		end
	end
	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		g_server:broadcastEvent(ToolPositionSaverEvent.new(self.vehicle,self.mode,self.positionIx), nil, connection, self.vehicle)
	end
end

function ToolPositionSaverEvent.sendEvent(vehicle,mode,positionIx)
	if g_server ~= nil then
		g_server:broadcastEvent(ToolPositionSaverEvent.new(vehicle,mode,positionIx), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(ToolPositionSaverEvent.new(vehicle,mode,positionIx))
	end
end

function ToolPositionSaverEvent.sendPlayEvent(vehicle,positionIx)
	ToolPositionSaverEvent.sendEvent(vehicle,ToolPositionSaverEvent.PLAY,positionIx)
end


function ToolPositionSaverEvent.sendResetEvent(vehicle,positionIx)
	ToolPositionSaverEvent.sendEvent(vehicle,ToolPositionSaverEvent.RESET,positionIx)
end



function ToolPositionSaverEvent.sendSetEvent(vehicle,positionIx)
	ToolPositionSaverEvent.sendEvent(vehicle,ToolPositionSaverEvent.SET,positionIx)
end
