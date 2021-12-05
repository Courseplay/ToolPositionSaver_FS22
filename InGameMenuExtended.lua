InGameMenuGameExtendedtps = {}

function InGameMenuGameExtendedTps.onFrameOpen(self)
	if self.tpsSubTitleElement == nil or self.tpsSetting ==nil then
		local subTitleElement = InGameMenuGameExtendedTps.getSubTitleElement(self)
		self.tpsSubTitleElement = subTitleElement:clone(subTitleElement.parent)
		self.tpsSubTitleElement:setText("TPS")
		self.tpsSetting = self.economicDifficulty:clone(self.economicDifficulty.parent)
		local toolTipElement = InGameMenuGameExtendedTps.getElementToolTip(self,self.tpsSetting)
		toolTipElement:setText("tps toolTip")
	end
	self.tpsSetting:setVisible(true)
	self.tpsSetting:setTexts({"1","2","3","4"})
	self.tpsSetting:setLabel("tps")
	print("Added Setting")
	self:updateAvailableProperties()
end
InGameMenuGameSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGameSettingsFrame.onFrameOpen,InGameMenuGameExtendedTps.onFrameOpen)


function InGameMenuGameExtendedTps.getSubTitleElement(self)
	for i,element in ipairs(self.boxLayout.elements) do 
		if element.profile == "settingsMenuSubtitle" then 
			return element
		end
	end
end

function InGameMenuGameExtendedTps.getElementToolTip(self,element)
	for i,element in ipairs(element.elements) do 
		if element.profile == "multiTextOptionSettingsTooltip" then 
			return element
		end
	end
end