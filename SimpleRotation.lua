--This is still in the works. Code is and will be Quick and Dirty for the time being. 
--[[
Name: Simple Rotation
Author: Durbin (durbindesign@gmail.com)
Description: SimpleRotation allows you to build "macros" that can be bound
to just one button and spammed or a few spread out to accommodate
your particular needs.

This addon came out of the demise of the 0-castsequence macros that made
it easier for people with disabilities to play. Using inspiration from GnomeSequencer
I decided to build an easy to use and configurable rotation helper. One key difference
is that castsequence macros inserted into the helper will remember their sequence!

While this addon handles my own disabilities, I am completely open to any suggestions
or features that will help out people who are further inhibited. It may take me a while
to get it implemented, but I'll do what I can to help as many people as possible.
]]

--Features left to implement:
--  Localization
--  Profile Sharing
--  Configuration menu to hide/show minimap button

local SimpleRotation = LibStub("AceAddon-3.0"):NewAddon("SimpleRotation","AceConsole-3.0")
SimpleRotation:RegisterChatCommand("simplerotation", "SlashCMDs")
local config = LibStub("AceConfig-3.0")
local gui = LibStub("AceGUI-3.0")
local dialog = LibStub("AceConfigDialog-3.0")
local db = LibStub("AceDBOptions-3.0")
local AIS = LibStub("LibAdvancedIconSelector-1.0")
local mmIcon = LibStub("LibDBIcon-1.0")
local simplerotationLDB = LibStub("LibDataBroker-1.1"):NewDataObject("SimpleRotation", {
	type = "launcher",
	text = "Simple Rotation",
	label ="Simple Rotation",
	icon = "Interface\\ICONS\\INV_Gizmo_01",
	OnClick = function() ToggleRotations() end,
})

local qmark = "Interface\\ICONS\\INV_Misc_QuestionMark"
local options = {
	name = "SimpleRotation",
	type = "group", 
	args = {}
}

options.general = {
	type = "group",
	order = 1,
	name = GENERAL,
	args = {
		general_box = {
			type = "toggle",
			order = 1,
			name = "General Checkbox?",
			width = "full"
		},
		iconSize = {
			type = "input",
			name = "Icon Size",
			width = "quarter",
			value = 48
		},

	}
}

config:RegisterOptionsTable("SimpleRotation",options);
dialog:AddToBlizOptions("SimpleRotation","Simple Rotation",nil);

config:RegisterOptionsTable("SimpleRotation_General",options.general);
dialog:AddToBlizOptions("SimpleRotation_General",options.general.name,"Simple Rotation");

-----------------------------------------

local iconSize, SRot = options.general.args.iconSize.value, ...
item,currentlySelectedPanel = nil,{}

local defaults = {
	profile = {
		minimap = {
			hide = false,
		},
		rotations = {
			['*'] = {
				options ={
					name = "No Name Assigned",
					includetrinkets = true,
					icon = "Interface\\ICONS\\INV_Gizmo_01",
					macroID = nil
				},
				compiled = {},
				spells = {}
			}
		},
		
	}	
}

--UI Frames
local RotationEditor = nil
local REInner, dd, specIconList, RotationList, SRUI_Buttons
local RBP,sb = {},{}

local OnClick = [=[
	local step = self:GetAttribute('step')
	self:SetAttribute('macrotext',  macros[step])
	%s
	if not step or not macros[step] then step = 1 end
	self:SetAttribute('step', step)
]=]

function SimpleRotation:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("AceDBSimpleRotDB",defaults)
	mmIcon:Register("Simple Rotation", simplerotationLDB, self.db.profile.minimap)
	SimpleRotation:RBP_INIT()
end

function SimpleRotation:OnEnable()
	-- SimpleRotation:OpenRotations()
	self:UpdateMacroFrames()
end

function SimpleRotation:RBP_INIT(n)
	if n ~= nil then 
		RBP = self.db.profile.rotations[n]
	else
		RBP = {
		options = {
			name = "",
			includeTrinkets = false,
			suppress = false,
			icon = "Interface\\ICONS\\INV_Gizmo_01",
			macroID = nil
		},
		compiled = {},
		spells = {}
		}
	end
end

function OpenRotationBuilder(n)
	SimpleRotation:RBP_INIT(n)
	SimpleRotation:BuildEditor(n)
	if n ~= nil then
		--create panels for each ability in spells
		for i = 1, #RBP.spells do
			if RBP.spells[i] ~= nil then
				AddAbilityPanel(i)
			end
		end
	end
end

function PopulateSpells()
	spellListFrame = gui:Create("Window")
	spellListFrame:SetStatusText("Select a spell ... ")
	spellListFrame:SetTitle("Pick a Spell!")
	spellListFrame:SetLayout("Fill")
	spellListFrame:SetHeight(400)
	spellListFrame:SetWidth(500)

	specIconList = gui:Create("ScrollFrame")
	specIconList:SetLayout("Flow")
	spellListFrame:AddChild(specIconList)
	
	local _,specName = GetSpecializationInfo(GetSpecialization())
    local numTabs = GetNumSpellTabs()

	for i=1,numTabs do
	  local name,texture,offset,numSpells = GetSpellTabInfo(i)
	  if (name == specName) then 
	  	for n = offset+1, offset + numSpells do
	  		if not IsPassiveSpell(n, "spell") then
		  		local spellName, _, icon = GetSpellInfo(n,"spell")
		  		if spellName ~= nil then
		  			local addIcon = gui:Create("Icon")
		  			addIcon:SetImage(icon)
		  			addIcon:SetImageSize(36,36)
		  			addIcon:SetLabel(spellName)
		  			addIcon:SetCallback("OnClick", function(self) AddSpellToRotation(n)  end)
		  			specIconList:AddChild(addIcon)
		  		end
			end
	  	end
	  end
	end
	spellListFrame:Hide()
end

function SimpleRotation:OpenRotations()	
	
	if RotationList ~= nil then 
		gui:Release(RotationList)
	end
	
	RotationList = gui:Create("Window")
	RotationList:SetCallback("OnClose",function(widget)
		gui:Release(widget)
		SRUI_Buttons:ReleaseChildren()
		RotationList = nil
	end)
	RotationList:SetTitle("Rotations")
	RotationList:SetWidth(300)
	RotationList:SetHeight(300)
	RotationList:SetLayout("Flow")
	SRUI_Buttons = gui:Create("ScrollFrame")
	if RotationEditor ~= nil then RotationList:SetPoint("Center", -375,0) end

	local createNew = gui:Create("Button")
	createNew:SetText("Add New Rotation")
	createNew:SetFullWidth(true)
	createNew:SetCallback("OnClick",function() 
		OpenRotationBuilder()
		RotationEditor.update = nil -- For some reason destroying the object isnt getting rid of it
	end )

	local scrollcontainer = gui:Create("SimpleGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetFullHeight(true) 
	scrollcontainer:SetLayout("Fill") 

	for i = 1, #self.db.profile.rotations do
		self:AddRotationToList(i)
	end

	RotationList:AddChildren(createNew, scrollcontainer)
	scrollcontainer:AddChild(SRUI_Buttons)
end

function SimpleRotation:BuildEditor(n)
	if RotationEditor ~= nil then
		gui:Release(RotationEditor)
	end

	RotationList:SetPoint("Center", -375,0)
	-- EDITOR GUI
	RotationEditor = gui:Create("Window")
	RotationEditor:SetCallback("OnClose",function(widget) gui:Release(widget) end)
	RotationEditor:SetTitle("Simple Rotation: New Rotation")
	RotationEditor:SetWidth(450)
	RotationEditor:SetLayout("Flow")
	RotationEditor.name = "RotationEditor"
	RotationEditor.frame:SetFrameStrata("HIGH")
		--------------------------------------------------
	local mSimple = gui:Create("InlineGroup")
	mSimple:SetTitle("Name and Icon")
	mSimple:SetLayout("Flow")
	mSimple:SetFullWidth(true)

	local mName = gui:Create("EditBox")
	mName:SetLabel("Name:")
	mName:SetRelativeWidth(0.4)
	mName:SetText(RBP.options.name or "")
	mName:SetCallback("OnTextChanged",function(self) RBP.options.name = self:GetText() end)
	RotationEditor.Name = mName

	local mIcon = gui:Create("Icon")
	mIcon:SetImage(RBP.options.icon or qmark)
	mIcon:SetImageSize(36,36)
	mIcon:SetRelativeWidth(0.2)
	mIcon:SetLabel("Select Icon")
	mIcon:SetCallback("OnClick", function(self) CreateMacroIconFrame("icon") end)
	RotationEditor.Icon = mIcon

	local svbtn = gui:Create("Button")
	svbtn:SetText("SAVE ROTATION")
	svbtn:SetRelativeWidth(0.3)
	svbtn:SetCallback("OnClick", function() SimpleRotation:SaveRotation(n) end)
	---------------------------------------------------

	local ddopts = {Spell = "Spell", Macro = "Macro", Item="Item"}
	dd = gui:Create("Dropdown")
	dd:SetRelativeWidth(0.5)
	dd:SetText("Select an Action")
	dd:SetList(ddopts)

	local btn = gui:Create("Button")
	btn:SetRelativeWidth(0.4)
	btn:SetText("Add")
	btn:SetCallback("OnClick", function() AddAbilityPanel() end) --Dont want it passing in self

	includeTrinkets = gui:Create("CheckBox")
	includeTrinkets:SetLabel("Include Trinkets?")
	includeTrinkets:SetRelativeWidth(0.5)
	includeTrinkets:SetValue(RBP.options.includeTrinkets or false)
	includeTrinkets:SetCallback("OnValueChanged", function(self) RBP.options.includeTrinkets = self:GetValue() end)

	suppressErrors = gui:Create("CheckBox")
	suppressErrors:SetLabel("Suppress Errors?")
	suppressErrors:SetRelativeWidth(0.5)
	suppressErrors:SetValue(RBP.options.suppress or false)
	suppressErrors:SetCallback("OnValueChanged", function(self) RBP.options.suppress = self:GetValue() end)

	local scrollcontainer = gui:Create("SimpleGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetFullHeight(true)
	scrollcontainer:SetLayout("Fill")
	scrollcontainer.name ="scrollcontainer"

	REInner = gui:Create("ScrollFrame")
	REInner:SetLayout("List")
	REInner.name = "REInner"
	scrollcontainer:AddChild(REInner)
	
	PopulateSpells()

	mSimple:AddChildren(mIcon,mName,svbtn, includeTrinkets, suppressErrors)
	RotationEditor:AddChildren(mSimple, dd, btn, scrollcontainer)
	RotationEditor:Show()
end

function SimpleRotation:SortList(direction,index)
	local e=tremove(RBP.spells, index)
	if(direction == "up") then
		tinsert(RBP.spells, index-1, e)
	end

	if(direction == "down") then
		tinsert(RBP.spells, index+1, e)
	end
	REInner:ReleaseChildren()
	for i = 1, #RBP.spells do
		AddAbilityPanel(i)
	end
end

function SimpleRotation:SaveRotation(update)
	if RBP == nil then 
		return nil
	end

	if #RBP.spells > 0 then
		local a, c = GetNumMacros()
		local cm = 1
		if c >= 18 then 
			cm = 0
			PM("Character macros are full, saving into account wide")
		end
		if RotationEditor.update ~= nil then update = RotationEditor.update end
		if not update then			
			RBP.options.macroID = CreateMacro(RBP.options.name.."-simplerotation", string.sub(RBP.options.icon,17) or "INV_Misc_QuestionMark", "/click "..RBP.options.name.."-simplerotation", cm)
			table.insert(self.db.profile.rotations,RBP)
			RotationEditor.update = #self.db.profile.rotations
			PM("Created "..RBP.options.name)
			self:OpenRotations()
		else
			if GetMacroInfo(RBP.options.macroID) == RBP.options.name.."-simplerotation" then
				RBP.options.macroID = EditMacro(RBP.options.macroID, RBP.options.name.."-simplerotation", string.sub(RBP.options.icon,17) or "INV_Misc_QuestionMark", "/click "..RBP.options.name.."-simplerotation" )
			else
				RBP.options.macroID = CreateMacro(RBP.options.name.."-simplerotation", string.sub(RBP.options.icon,17) or "INV_Misc_QuestionMark", "/click "..RBP.options.name.."-simplerotation",cm)
			end
			self.db.profile.rotations[update] = RBP
		end
	end
	self:UpdateMacroFrames()
end

function SimpleRotation:AddRotationToList(id)
	local rotation = self.db.profile.rotations[id]
	if rotation ~= nil then 
		local sg = gui:Create("SimpleGroup")
		sg:SetLayout("Flow")
		sg:SetFullWidth(true)
		
		local PaneBackdrop  = {
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 4,
			insets = { left = 1, right = 1, top = 10, bottom = 1 }
		}

		local button = gui:Create("Icon")
		button:SetRelativeWidth(0.3)
		button:SetImage(rotation.options.icon or qmark)
		button:SetImageSize(36,36)
		button:SetCallback("OnClick", function() 
			OpenRotationBuilder(id)
			RotationEditor.update = id
		end)
		button.frame:RegisterForDrag("LeftButton", "RightButton")
		button.frame:SetScript("OnDragStart", function()
			PickupMacro(rotation.options.name.."-simplerotation")
		end)

		local label = gui:Create("InteractiveLabel")
		label:SetText(rotation.options.name or "")
		label:SetRelativeWidth(0.6)

		-- local border = CreateFrame("frame", nil, sg.frame)
		-- border:SetPoint("TOPLEFT", -10, 0)
		-- border:SetPoint("BOTTOMRIGHT", 10, -5)
		-- border:SetBackdrop(PaneBackdrop)
		-- border:SetBackdropColor(0.1, 0.1, 0.1, 0.2)
		-- border:SetBackdropBorderColor(0.4, 0.4, 0.4)

		local delete = gui:Create("Icon")
		delete:SetImage("Interface\\GLUES\\LOGIN\\Glues-CheckBox-Check")
		delete:SetImageSize(20,20)
		delete:SetRelativeWidth(0.1)
		delete:SetCallback("OnClick", function(self)
			SimpleRotation:DeleteRotation(id)
		end)
		sg:AddChildren(button,label,delete)
		sg.rotation = rotation
		SRUI_Buttons:AddChild(sg)
	end
end

function SimpleRotation:DeleteRotation(p)
	PM("Deleted "..self.db.profile.rotations[p].options.name)
	DeleteMacro(self.db.profile.rotations[p].options.name.."-simplerotation") -- safer than by ID just in case
	table.remove(self.db.profile.rotations,p)
	self:OpenRotations()
end

function AddAbilityPanel(index,p)
	if index == nil then 
		index = #RBP.spells+1
		RBP.spells[index] = {}
	end

	if RBP.spells[index].type == nil then
		opt = dd:GetValue()
		RBP.spells[index].type = opt
	else
		opt = RBP.spells[index].type
	end

	if opt == nil then 
		return
	end

	-- NEW ABILITY PANEL
	local ig = gui:Create("InlineGroup")
	ig:SetLayout("Flow")
	ig:SetFullWidth(true)
	ig:SetCallback("OnClose",function(widget) gui:Release(widget) end)

	REInner:AddChild(ig,p)
	ig.name = index
	
	local delete = gui:Create("Icon")
	delete:SetImage("Interface\\GLUES\\LOGIN\\Glues-CheckBox-Check")
	delete:SetImageSize(20,20)
	delete:SetRelativeWidth(0.1)
	delete:SetCallback("OnClick", function(self) DeleteAbilityPanel(self.parent) end)
	delete.frame:SetPoint("TOPRIGHT",-10,0)

	local sortFrame = gui:Create("SimpleGroup")
	sortFrame:SetRelativeWidth(0.1)
	ig:AddChild(sortFrame)

	local moveUp = gui:Create("Icon")
	moveUp:SetImage("Interface\\BUTTONS\\UI-MicroStream-Green")
	moveUp.image:SetRotation(math.rad(180))
	moveUp:SetImageSize(25,25)
	moveUp:SetWidth(30)
	moveUp:SetCallback("OnClick",function(self)
		if index-1 > 0 then
			SimpleRotation:SortList("up",index)
		end
	end)

	local moveDown = gui:Create("Icon")
	moveDown:SetImage("Interface\\BUTTONS\\UI-MicroStream-Green")
	moveDown:SetImageSize(36,36)
	moveDown:SetWidth(30)
	moveDown:SetCallback("OnClick",function(self)
		if index+1 <= #RBP.spells then
			SimpleRotation:SortList("down",index)
		end

	end)

	sortFrame:AddChild(moveUp)
	sortFrame:AddChild(moveDown)

	local ico = gui:Create("InteractiveLabel")
	ico:SetImage(RBP.spells[index].icon or qmark)
	ico:SetImageSize(36,36)

	if opt == "Spell" or opt == "Item" then

		ico:SetRelativeWidth(0.7)
		ico.frame:SetScript("OnReceiveDrag", function(self)
			local t, d, s, p = GetCursorInfo()			
			if t == "item" then
				item = {GetItemInfo(d)}
				ico:SetText(item[1])
				ico:SetImage(item[10])
			elseif t=="spell" then
				item = {GetSpellInfo(d,s)}
				ico:SetText(item[1])
				ico:SetImage(item[3])
			elseif t=="petaction" then
				PM("Pet actions do not work at this time. Insert them into a macro")
			else
				PM("That is not valid, it is a "..t)
			end	
			ClearCursor()
		end)
		--Spell needs to show popup
		if opt == "Spell" then 
			ico:SetText(RBP.spells[index].name or "Click Area or Drag")
			ico:SetCallback("OnClick", function(self)
				currentlySelectedPanel = self
				spellListFrame:Show()
			end)		
		end
		--Item needs to fill length
		if opt == "Item" then
			ico:SetText(RBP.spells[index].name or "Drag item onto Icon")
		end

		ig:AddChild(ico)
	end
	
	if opt == "Macro" then

		local eb = gui:Create("MultiLineEditBox")
		eb:SetLabel("Type or paste your macro text...")
		eb:SetMaxLetters(255)
		eb:SetRelativeWidth(0.7)
		eb:SetText(RBP.spells[index].macrotext or "")
		eb:SetCallback("OnTextChanged",function(self) RBP.spells[index].macrotext = self:GetText() end)
		ig:AddChild(eb)
	end
	ig:AddChild(delete)
end

function DeleteAbilityPanel(p)
	local childArray = p.parent.children
	for k,v in ipairs(childArray) do 
		if(v == p) then
			RBP.spells[p.name] = nil
			table.remove(childArray, k)
			p:Release()
			break
		end
	end	
	REInner:DoLayout()
end

function AddSpellToRotation(p)
	if not p then return end
	if currentlySelectedPanel ~= nil then
		local pid = currentlySelectedPanel.parent.name
		if pid ~= nil then
			local name, _, icon = GetSpellInfo(p, "spell")
			currentlySelectedPanel:SetImage(icon)
			currentlySelectedPanel:SetText(name)
			--GET SPELL GLOBAL ID FOR MACRO PROCESSING
			local _,spellID = GetSpellBookItemInfo(p, "spell")
			RBP.spells[pid].icon, RBP.spells[pid].spellID, RBP.spells[pid].name = icon,spellID,name
			currentlySelectedPanel = nil
		end
	end
	spellListFrame:Hide()
end

function SimpleRotation:UpdateMacroFrames()
	if not InCombatLockdown() then
		for i = 1, #self.db.profile.rotations do
			--Make a primary frame
			local rot = self.db.profile.rotations[i]
			local fr = CreateFrame("Button", rot.options.name.."-simplerotation", UIParent,"ActionButtonTemplate,SecureActionButtonTemplate,SecureHandlerBaseTemplate")
			local macros, fn = {}, 1

			for x=1,#rot.spells do
				local text = ""
				local s = rot.spells[x]
				if s ~= nil then 					
					if s.type == "Macro" then
						local f = rot.options.name.."-simplerotation"..fn
						if(rot.options.name.."-simplerotation"..fn ~= nil) then 
							f = CreateFrame("Button",rot.options.name.."-simplerotation"..fn , UIParent,  "SecureActionButtonTemplate")
						end
						f:SetAttribute("type", "macro")
						f:SetAttribute("macrotext", s.macrotext)
						text = "/click "..f:GetName()
						fn = fn+1
					elseif s.type == "Spell" then
						text = "/cast [nochanneling] !"..s.name
					else
						text = "/use "..s.name
					end
					if rot.options.includetrinkets then
						text = text.."\n/use 13\n/use14"
					end
					
					if rot.options.suppress then
						-- text = "/console Sound_EnableSFX 0\n"..text.."\n/console Sound_EnableSFX 1\n/run UIErrorsFrame:Clear()"
						text = text.."\n/run UIErrorsFrame:Clear()"

					end
					table.insert(macros, text)
				end
			end
			
			fr:Execute('name, macros = self:GetName(), newtable([=======[' .. strjoin(']=======],[=======[', unpack(macros)) .. ']=======])')
			fr:SetAttribute("step", 1)
			fr:SetAttribute("rotation", i)
			fr:SetAttribute("type", "macro")
			fr:WrapScript(fr, "OnClick", format(OnClick, macros.StepFunction or 'step = step % #macros + 1'))
			
		end
	end
end

function PM(s)
	SimpleRotation:Print(s);	
end

function CreateMacroIconFrame(reference)
	if not AIS.iconBrowser then
		local options = {
			okayCancel = true,
			anchorFrame = RotationEditor.frame
		}

		AIS.iconBrowser = AIS:CreateIconSelectorWindow("AIS_IconBrowser", RotationEditor.frame, options)
		AIS.iconBrowser:SetPoint("CENTER")
		AIS.iconBrowser:SetFrameStrata("DIALOG")
		AIS.iconBrowser:SetScript("OnOkayClicked", function(self) 
			AIS.selectedIcon = AIS.iconBrowser.iconsFrame:GetSelectedIcon()

			local _,_,iconTexture = AIS.iconBrowser.iconsFrame:GetIconInfo(AIS.selectedIcon)

			if iconTexture ~= nil then
				if reference == "macro" then 

				elseif reference == "icon" then
					RBP.options.icon = "Interface\\ICONS\\"..iconTexture
					RotationEditor.Icon:SetImage("Interface\\ICONS\\"..iconTexture)
				end
				
				
			end
		AIS.iconBrowser:Hide()
		end)
	end
	AIS.iconBrowser:Show()
end

function ToggleRotations()
	if RotationList ~= nil then
		if RotationList:IsVisible() then
			RotationList:Fire("OnClose")
			return
		end
	end
	SimpleRotation:OpenRotations()
end

function SimpleRotation:SlashCMDs(args)
	if(args == "DeleteRotations") then
		for i=1, #self.db.profile.rotations do
			DeleteMacro(self.db.profile.rotations[i].macroID)
		end
		self.db.profile.rotations = {}
		PM("All rotations have been erased")

	end

	if args == "minimap" then 
		if mmIcon:IsVisible() then
			mmIcon:Hide("SimpleRotation")
		else
			mmIcon:Show("SimpleRotation")
		end
	end

	if args == "" then 
		self:OpenRotations()
	end

end