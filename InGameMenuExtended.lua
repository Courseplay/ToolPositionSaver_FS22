InGameMenuGameExtendedWtp = {}

function InGameMenuGameExtendedWtp.onFrameOpen(self)
	if self.wtpSubTitleElement == nil or self.wtpSetting ==nil then
		local subTitleElement = InGameMenuGameExtendedWtp.getSubTitleElement(self)
		self.wtpSubTitleElement = subTitleElement:clone(subTitleElement.parent)
		self.wtpSubTitleElement:setText("WTP")
		self.wtpSetting = self.economicDifficulty:clone(self.economicDifficulty.parent)
		local toolTipElement = InGameMenuGameExtendedWtp.getElementToolTip(self,self.wtpSetting)
		toolTipElement:setText("wtp toolTip")
	end
	self.wtpSetting:setVisible(true)
	self.wtpSetting:setTexts({"1","2","3","4"})
	self.wtpSetting:setLabel("wtp")
	print("Added Setting")
	self:updateAvailableProperties()
end
InGameMenuGameSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGameSettingsFrame.onFrameOpen,InGameMenuGameExtendedWtp.onFrameOpen)


function InGameMenuGameExtendedWtp.getSubTitleElement(self)
	for i,element in ipairs(self.boxLayout.elements) do 
		if element.profile == "settingsMenuSubtitle" then 
			return element
		end
	end
end

function InGameMenuGameExtendedWtp.getElementToolTip(self,element)
	for i,element in ipairs(element.elements) do 
		if element.profile == "multiTextOptionSettingsTooltip" then 
			return element
		end
	end
end