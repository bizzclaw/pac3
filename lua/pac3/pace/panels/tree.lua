local L = pace.LanguageString

local PANEL = {}

PANEL.ClassName = "tree"
PANEL.Base = "DTree"

function PANEL:Init()
	DTree.Init(self)

	self:SetLineHeight(18)
	self:SetIndentSize(2)

	self.outfits = {}
	self.parts = {}
	
	self:Populate()
	
	pace.tree = self
end

do
	local pnl = NULL
	local _BETA
	
	if not _BETA then
		pac_ChangeTooltip = pac_ChangeTooltip or ChangeTooltip
		function ChangeTooltip(pnl_, ...)
			pnl = pnl_ or NULL
			return pac_ChangeTooltip(pnl_, ...)
		end
	end

	function PANEL:Think(...)	
		if _BETA then
			pnl = vgui.GetHoveredPanel() or NULL
		end
				
		if pnl:IsValid() then
			local pnl = pnl:GetParent()
			
			if pnl and pnl.part and pnl.part:IsValid() then
				pace.Call("HoverPart", pnl.part)
			end
		end	
		
				
		if DTree.Think then
			return DTree.Think(self, ...)
		end
	end
end

function PANEL:OnMousePressed(mc)
	if mc == MOUSE_RIGHT then
		pace.Call("NewPartMenu")
	end
end

function PANEL:SetModel(path)
	local pnl = vgui.Create("DModelPanel", self)
		pnl:SetModel(path or "")
		pnl:SetSize(16, 16)

		local mins, maxs = pnl.Entity:GetRenderBounds()
		pnl:SetCamPos(mins:Distance(maxs) * Vector(0.75, 0.75, 0.5) * 15)
		pnl:SetLookAt((maxs + mins) / 2)
		pnl:SetFOV(3)

		pnl.SetImage = function() end
		pnl.GetImage = function() end

	self.Icon:Remove()
	self.Icon = pnl
end

local function install_drag(node)
	node:SetDraggableName("pac3")
	
	function node:OnDrop(child)
		-- we're hovering on the label, not the actual node
		-- so get the parent node instead
		child = child:GetParent().part
		
		if child and child:IsValid() then
			if self.part and self.part:IsValid() then
				self.part:SetParent(child)
			end
		end
		
		return self
	end
end

local function install_expand(node)
	local old = node.SetExpanded
	node.SetExpanded = function(self, b, ...)
		if self.part and self.part:IsValid() then
			self.part:SetEditorExpand(b)
		end
		
		return old(self, b, ...)
	end
end

local fix_folder_funcs = function(tbl) 
	tbl.MakeFolder = function() end
	tbl.FilePopulateCallback = function() end
	tbl.FilePopulate = function() end
	tbl.PopulateChildren = function() end
	tbl.PopulateChildrenAndSelf = function() end
	return tbl
end
-- a hack, because creating a new node button will mess up the layout
function PANEL:AddNode(...)

	local node = fix_folder_funcs(DTree.AddNode(self, ...))
	install_expand(node)
	if _BETA then install_drag(node) end
	--node.SetModel = self.SetModel

	node.AddNode = function(...)
		local node_ = fix_folder_funcs(DTree_Node.AddNode(...))
		node_.AddNode = node.AddNode
		if _BETA then install_drag(node_) end
		install_expand(node_)
		--node_.SetModel = self.SetModel
						
		return node_
	end
	
	return node
end

function PANEL:PopulateParts(node, parts, children)
	parts = table.ClearKeys(parts)

	local tbl = {}
	
	table.sort(parts, function(a,b) 
		return a and b and a:GetName() < b:GetName() 
	end)
	
	for key, val in pairs(parts) do
		if not val:HasChildren() then
			table.insert(tbl, val)
		end
	end
	
	for key, val in pairs(parts) do
		if val:HasChildren() then
			table.insert(tbl, val)
		end
	end
	
	for key, part in ipairs(tbl) do
		key = tostring(part)
				
		if not part:HasParent() or children then
			local part_node
			
			if IsValid(part.editor_node) then
				part_node = part.editor_node
			elseif IsValid(self.parts[key]) then
				part_node = self.parts[key]
			else
				part_node = node:AddNode(part:GetName())
			end
			
			part_node:SetTooltip(part:GetDescription())
			
			part.editor_node = part_node
			part_node.part = part
			
			self.parts[key] = part_node

			part_node.DoClick = function()
				if part:IsValid() then
					pace.Call("PartSelected", part)
					return true
				end
			end
			
			part_node.DoRightClick = function()
				if part:IsValid() then
					pace.Call("PartMenu", part)
					return true
				end
			end
			
			--[[if false and part.ClassName == "model" and part.GetModel then
				--part_node:SetModel(part:GetModel())
			else]]
				part_node.Icon:SetImage(pace.PartIcons[part.ClassName] or (net and "icon16/plugin") or "gui/silkicons/plugin")
			--end
			
			self:PopulateParts(part_node, part:GetChildren(), true)			
		
			part_node:SetExpanded(part:GetEditorExpand())

		end
	end
end

function PANEL:Populate()

	for key, node in pairs(self.parts) do
		if not node.part or not node.part:IsValid() then
			node:Remove()
			self.parts[key] = nil
		end
	end
	
	--[[self.m_pSelectedItem = nil
	
	for key, node in pairs(self:GetItems()) do
		node:Remove()
	end]]
	
	self:PopulateParts(self, pac.GetParts(true))
	
	self:StretchToParent()
	self:InvalidateLayout()
end

pace.RegisterPanel(PANEL)

local function remove_node(obj)
	if (obj.editor_node or NULL):IsValid() then
		obj.editor_node:SetForceShowExpander()
		obj.editor_node:GetRoot().m_pSelectedItem = nil
		obj.editor_node:Remove()
		pace.RefreshTree()
	end
end

hook.Add("pac_OnPartRemove", "pace_remove_tree_nodes", remove_node)
hook.Add("pac_OnPartRemove", "pace_remove_tree_nodes", remove_node)

function pace.RefreshTree()
	if pace.tree:IsValid() then
		timer.Create("pace_refresh_tree",  0.2, 1, function()
			if pace.tree:IsValid() then
				pace.tree:Populate()
			end
		end)
	end
end
