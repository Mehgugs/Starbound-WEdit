--[[
  WEdit library (http://silvermods.com/WEdit/)

  To load this script, it has to be required -inside- the init function of a base tech script (EG. distortionsphere.lua).
  To use this script, the chosen base tech has to be active on your character. Further usage instructions can be found on the official page linked above.

  Hit ALT + 0 in NP++ to fold all, and get an overview of the contents of this script.
]]

require "/scripts/wedit.lua"
require "/scripts/keybinds.lua"

--[[
  Controller table, variables accessed with 'weditController.' are stored here..
]]
weditController = { }

--- Noclip parameters.
weditController.useNoclip = true
-- Bind can be any Keybinds compatible bind string.
weditController.noclipBind = "g"
-- Movement speed per tick, in blocks.
weditController.noclipSpeed = 0.75
-- Default noclip status (on tech selection or character load)
weditController.noclipping = false

-- Indices for selected materials, used by the Modifier and Hydrator.
weditController.modIndex = 39
weditController.liquidIndex = 1

-- Variables used to determine if LMB and/or RMB are held down this tick.
weditController.primaryFire, weditController.altFire = false, false
weditController.fireLock = false

-- Number used by WE_Select to determine the selection stage (0: Nothing, 1: Selecting).
weditController.selectStage = 0
-- Table used to store the current raw selection coordinates.
-- [1] Start selection or nil, [2] End selection or nil.
weditController.rawSelection = {}
-- Table used to store the current selection coordinates, converted to block coordinates.
-- [1] Bottom left corner of selection, [2] Top right corner of selection.
weditController.selection = {{},{}}

weditController.lineStage = 0
weditController.line = {{},{}}

-- Number used to display the selection with particles every x ticks.
weditController.selectionTicks = 0

-- String used to determine what layer the Eraser, Color Picker, Paint Bucket and Pencil affect.
weditController.layer = "foreground"

-- String used to hold the block used by the Pencil and Paint Bucket
weditController.selectedBlock = "dirt"

-- Table used to store copies of areas prior to commands such as fill.
weditController.backup = {}

-- Table used to display information in certain colors. { title & operations, description, variables }
weditController.colors = { "^orange;", "^yellow;", "^red;"}
wedit.colors = weditController.colors

-- Table used to store the coordinates at which to display the config interface.
weditController.configLocation = {}

----------------------------------------
--          Useful functions          --
-- Primary for use within this script --
----------------------------------------

--[[
  Returns the currently selected matmod.
  @return - Selected matmod.
]]
function weditController.getSelectedMod()
  return wedit.mods[weditController.modIndex]
end

--[[
  Returns the currently selected block for displaying purposes (false = air, nil = none)
  @return - Block name, where non-strings are converted for displaying.
]]
function weditController.selectedBlockToString()
  if weditController.selectedBlock == nil then
    return "none"
  elseif weditController.selectedBlock == false then
    return "air"
  else
    return weditController.selectedBlock
  end
end

--[[
  Sets the selected block to the one under the cursor, on the given layer.
  @param [layer] - Layer to select block from. Defaults to
  weditController.layer.
  @return - Tile or false.
]]
function weditController.updateColor(layer)

  if type(layer) ~= "string" then layer = weditController.layer end

  local tile = world.material(tech.aimPosition(), layer)
  if tile then
    weditController.selectedBlock = tile
  else
    weditController.selectedBlock = false
  end

  return tile or false
end

--[[
  Returns a value indicating whether there's currently a valid selection.
  Does this by confirming both the bottom left and top right point are set.
]]
function weditController.validSelection()
  return next(weditController.selection[1]) and next(weditController.selection[2]) and true or false
end

---------------------
-- Update Callback --
---------------------

--[[
  Update function, called in the main update callback.
]]
function weditController.update(args)
  -- Check if LMB / RMB are held down this game tick.
  weditController.primaryFire = args.moves["primaryFire"]
  weditController.altFire = args.moves["altFire"]

  if weditController.noclipping then
    mcontroller.controlParameters({
      gravityEnabled = false,
      collisionEnabled = false,
      standingPoly = {},
      crouchingPoly = {},
      mass = 0,
      runSpeed = 0,
      walkSpeed = 0
    })
    wedit.setLogMap("Noclip", string.format("Press '%s' to stop flying.", weditController.noclipBind))
  else
    wedit.setLogMap("Noclip", string.format("Press '%s' to fly.", weditController.noclipBind))
  end
  -- Removes the lock on your fire keys (LMB/RMB) if both have been released.
  if weditController.fireLock and not weditController.primaryFire and not weditController.altFire then
    weditController.fireLock = false
  end

  -- As all WEdit items are two handed, we only have to check the primary item.
  local primaryItem = world.entityHandItemDescriptor(entity.id(), "primary")
  local primaryType = nil
  if primaryItem and primaryItem.parameters and primaryItem.parameters.shortdescription then primaryType = primaryItem.parameters.shortdescription end

  -- Run the function bound to the short description of the held item.
  if primaryType and type(weditController[primaryType]) == "function" then
    weditController[primaryType]()
  end

  -- Draw selections if they have been made.
  if weditController.validSelection() then
    wedit.debugRectangle(weditController.selection[1], weditController.selection[2])
    wedit.debugText(string.format("^shadow;WEdit Selection (%s,%s)", weditController.selection[2][1] - weditController.selection[1][1], weditController.selection[2][2] - weditController.selection[1][2]), {weditController.selection[1][1], weditController.selection[2][2]}, "green")

    if weditController.copyTable and weditController.copyTable.size and (primaryType == "WE_Select" or primaryType == "WE_Stamp") then
      local copy = weditController.copyTable
      local top = weditController.selection[1][2] + copy.size[2]
      wedit.debugRectangle(weditController.selection[1], {weditController.selection[1][1] + copy.size[1], top}, "cyan")

      if top == weditController.selection[2][2] then top = weditController.selection[2][2] + 1 end
      wedit.debugText("^shadow;WEdit Paste Selection", {weditController.selection[1][1], top}, "cyan")
    end
  end
end

-- Set up noclip using Keybinds.
Bind.create(weditController.noclipBind, function()
  weditController.noclipping = not weditController.noclipping
  if weditController.noclipping then
    tech.setParentState("fly")
    for i,v in ipairs(weditController.noclipBinds) do
      v:rebind()
    end
  else
    tech.setParentState()
    for i,v in ipairs(weditController.noclipBinds) do
      v:unbind()
    end
  end
end)

local adjustPosition = function(offset)
  local pos = mcontroller.position()
  mcontroller.setPosition({pos[1] + offset[1], pos[2] + offset[2]})
end
weditController.noclipBinds = {}
table.insert(weditController.noclipBinds, Bind.create("up", function() adjustPosition({0,weditController.noclipSpeed}) end, true))
table.insert(weditController.noclipBinds, Bind.create("down", function() adjustPosition({0,-weditController.noclipSpeed}) end, true))
table.insert(weditController.noclipBinds, Bind.create("left", function() adjustPosition({-weditController.noclipSpeed,0}) end, true))
table.insert(weditController.noclipBinds, Bind.create("right", function() adjustPosition({weditController.noclipSpeed,0}) end, true))
for i,v in ipairs(weditController.noclipBinds) do
  v:unbind()
end

-- Alter update callback.
local oldUpdate = update
update = function(args)
  oldUpdate(args)
  weditController.update(args)
end

-----------------
-- WEdit Tools --
-----------------

--[[
  Sets or updates the selection area.
]]
function weditController.WE_Select()
  wedit.info("^shadow;^orange;WEdit: Selection Tool")

  if weditController.validSelection() then
    wedit.info("^shadow;^yellow;Alt Fire: Remove selection.", {0,-2})
    wedit.info("^shadow;^yellow;Current Selection: ^red;(" .. (weditController.selection[2][1] - weditController.selection[1][1]) .. "," .. (weditController.selection[2][2] - weditController.selection[1][2]) .. ")^yellow;.", {0,-3})
  end

  -- RMB resets selection entirely
  if not weditController.fireLock and weditController.altFire then
    weditController.fireLock = true
    weditController.selectStage = 0
    weditController.selection = {{},{}}
    return
  end

  if weditController.selectStage == 0 then
    -- Select stage 0: Not selecting.
    wedit.info("^shadow;^yellow;Primary Fire: Select area.", {0,-1})

    if weditController.primaryFire then
      -- Start selection; set first point.
      weditController.selectStage = 1
      weditController.rawSelection[1] = tech.aimPosition()
    end

  elseif weditController.selectStage == 1 then
  wedit.info("^shadow;^yellow;Drag mouse and let go to select an area.", {0,-1})
    -- Select stage 1: Selection started.
    if weditController.primaryFire then
      -- Dragging selection; update second point.
      weditController.rawSelection[2] = tech.aimPosition()

      -- Update converted coördinates.
      -- Compare X (1 is smallest):
      weditController.selection[1][1] = math.floor((weditController.rawSelection[1][1] <  weditController.rawSelection[2][1]) and weditController.rawSelection[1][1] or weditController.rawSelection[2][1])
      weditController.selection[2][1] = math.ceil((weditController.rawSelection[1][1] <  weditController.rawSelection[2][1]) and weditController.rawSelection[2][1] or weditController.rawSelection[1][1])

      -- Compare Y (1 is smallest):
      weditController.selection[1][2] = math.floor((weditController.rawSelection[1][2] <  weditController.rawSelection[2][2]) and weditController.rawSelection[1][2] or weditController.rawSelection[2][2])
      weditController.selection[2][2] = math.ceil((weditController.rawSelection[1][2] <  weditController.rawSelection[2][2]) and weditController.rawSelection[2][2] or weditController.rawSelection[1][2])
    else
      -- Selection ended; reset stage.
      weditController.selectStage = 0

      -- We can forget about the raw coördinates now.
      weditController.rawSelection = {}
    end
  else
    -- Select stage is not valid; reset it.
    weditController.selectStage = 0
  end
end

--[[
  Function to set weditController.layer.
]]
function weditController.WE_Layer()
  wedit.info("^shadow;^orange;WEdit: Layer Tool")
  wedit.info("^shadow;^yellow;Primary Fire: foreground.", {0,-1})
  wedit.info("^shadow;^yellow;Alt Fire: background", {0,-2})
  wedit.info("^shadow;^yellow;Current Layer: ^red;" .. weditController.layer .. "^yellow;.", {0,-3})

  if not weditController.fireLock and (weditController.primaryFire or weditController.altFire) then
    -- Prioritizes LMB over RMB.
    weditController.layer = (weditController.primaryFire and "foreground") or (weditController.altFire and "background") or weditController.layer

    -- Prevents repeats until mouse buttons no longer held.
    weditController.fireLock = true
  end
end

--[[
  Function to erase all blocks in the current selection.
  Only targets weditController.layer
]]
function weditController.WE_Erase()
  wedit.info("^shadow;^orange;WEdit: Eraser")
  wedit.info("^shadow;^yellow;Erase all blocks in the current selection.", {0,-1})
  wedit.info("^shadow;^yellow;Primary Fire: foreground.", {0,-2})
  wedit.info("^shadow;^yellow;Alt Fire: background.", {0,-3})

  if not weditController.fireLock and weditController.validSelection() then
    if weditController.primaryFire then
      -- Remove Foreground
      weditController.fireLock = true
      local backup = wedit.breakBlocks(weditController.selection[1], weditController.selection[2], "foreground")

      if backup then table.insert(weditController.backup, backup) end

    elseif weditController.altFire then
      -- Remove Background
      weditController.fireLock = true
      local backup = wedit.breakBlocks(weditController.selection[1], weditController.selection[2], "background")

      if backup then table.insert(weditController.backup, backup) end
    end
  end
end

--[[
  Function to undo the previous Fill or Erase action.
  LMB Undoes the last remembered action. RMB removes the last remembered action, allowing for multiple undo steps.
]]
function weditController.WE_Undo()
  local backupSize = #weditController.backup
  wedit.info("^shadow;^orange;WEdit: Undo Tool (EXPERIMENTAL)")
  wedit.info("^shadow;^yellow;Undoes previous action (Fill, Break, Paste, Replace).", {0,-1})
  wedit.info("^shadow;^yellow;Primary Fire: Undo last action.", {0,-2})
  wedit.info("^shadow;^yellow;Alt Fire: Forget last undo (go back a step).", {0,-3})
  wedit.info("^shadow;^yellow;Undo Count: " .. backupSize .. ".", {0,-4})

  if not weditController.fireLock then
    if weditController.primaryFire then
      -- Undo
      weditController.fireLock = true
      if (backupSize > 0) then
        wedit.paste(weditController.backup[backupSize], weditController.backup[backupSize].origin)
      end
    elseif weditController.altFire then
      -- Remove Undo
      weditController.fireLock = true
      table.remove(weditController.backup, backupSize)
    end
  end

  -- Show undo area.
  if backupSize > 0 then
    local backup = weditController.backup[backupSize]
    local top = backup.origin[2] + backup.size[2]
    if weditController.validSelection() and math.ceil(weditController.selection[2][2]) == math.ceil(top) then top = top + 1 end
    wedit.debugText("^shadow;WEdit Undo Position", {backup.origin[1], top}, "#FFBF87")
    wedit.debugRectangle(backup.origin, {backup.origin[1] + backup.size[1], backup.origin[2] + backup.size[2]}, "#FFBF87")
  end
end

--[[
  Function to select a block to be used by tools such as the Pencil or the Paint Bucket.
]]
function weditController.WE_ColorPicker()
  wedit.info("^shadow;^orange;WEdit: Color Picker")
  wedit.info("^shadow;^yellow;Select a block for certain tools.", {0,-1})
  wedit.info("^shadow;^yellow;Primary Fire: foreground.", {0,-2})
  wedit.info("^shadow;^yellow;Alt Fire: background.", {0,-3})
  wedit.info("^shadow;^yellow;Current Block: ^red;" .. weditController.selectedBlockToString() .. "^yellow;.", {0,-4})

  if weditController.primaryFire then
    weditController.fireLock = true
    weditController.updateColor("foreground")
  elseif weditController.altFire then
    weditController.fireLock = true
    weditController.updateColor("background")
  end
end

--[[
  Function to fill the crurent selection with the selected block.
  Only targets weditController.layer
]]
function weditController.WE_Fill()
  wedit.info("^shadow;^orange;WEdit: Paint Bucket")
  wedit.info("^shadow;^yellow;Fills air in the current selection with the selected block.", {0,-1})
  wedit.info("^shadow;^yellow;Primary Fire: foreground.", {0,-2})
  wedit.info("^shadow;^yellow;Alt Fire: background.", {0,-3})
  wedit.info("^shadow;^yellow;Current Block: ^red;" .. weditController.selectedBlockToString() .. "^yellow;.", {0,-4})

  if not weditController.fireLock and weditController.validSelection() then
    if weditController.primaryFire then
      weditController.fireLock = true

      local backup = wedit.fillBlocks(weditController.selection[1], weditController.selection[2], "foreground", weditController.selectedBlock)

      if backup then table.insert(weditController.backup, backup) end
    elseif weditController.altFire then
      weditController.fireLock = true

      local backup = wedit.fillBlocks(weditController.selection[1], weditController.selection[2], "background", weditController.selectedBlock)

      if backup then table.insert(weditController.backup, backup) end
    end
  end
end

--[[
  Function to draw the selected block under the cursor. Existing blocks will be replaced.
  Only targets weditController.layer
]]
function weditController.WE_Pencil()
  wedit.info("^shadow;^orange;WEdit: Pencil")
  wedit.info("^shadow;^yellow;Primary Fire: Draw on foreground.", {0,-1})
  wedit.info("^shadow;^yellow;Alt Fire: Draw on background.", {0,-2})
  wedit.info("^shadow;^yellow;Current Block: ^red;" .. weditController.selectedBlockToString() .. "^yellow;.", {0,-3})

  if weditController.selectedBlock ~= nil then
    if weditController.primaryFire then
      wedit.pencil(tech.aimPosition(), "foreground", weditController.selectedBlock)
    elseif weditController.altFire then
      wedit.pencil(tech.aimPosition(), "background", weditController.selectedBlock)
    end
  end
end

--[[
  Function to copy and paste a selection elsewhere.
  The pasting is done through weditController.paste, this function just sets the pasting stage to 1 after checking values for validity.
]]
function weditController.WE_Stamp()
  wedit.info("^shadow;^orange;WEdit: Stamp Tool")
  wedit.info("^shadow;^yellow;Primary Fire: Copy selection.", {0,-1})
  wedit.info("^shadow;^yellow;Alt Fire: Paste selection.", {0,-2})
  wedit.info("^shadow;^yellow;The paste area is defined by the bottom left point of your selection.", {0,-3})

  if not weditController.fireLock and weditController.primaryFire and weditController.validSelection() then
    -- Store copy
    weditController.copyTable = wedit.copy(weditController.selection[1], weditController.selection[2])
    weditController.fireLock = true
  elseif not weditController.fireLock and weditController.altFire and weditController.validSelection() then
    -- Start paste
    local position = {weditController.selection[1][1], weditController.selection[1][2]}
    local backup = wedit.paste(weditController.copyTable, position)
    if backup then table.insert(weditController.backup, backup) end

    weditController.fireLock = true
  end
end

--[[
  Function to select certain parameters for the tech.
]]
function weditController.WE_Config()
  wedit.info("^shadow;^orange;WEdit: Config Tool")
  wedit.info("^shadow;^yellow;Primary Fire: Select item.", {0,-1})
  wedit.info("^shadow;^yellow;Alt Fire: Show or move menu.", {0,-2})

  -- Draw
  if weditController.configLocation and weditController.configLocation[1] then
    wedit.debugText("^shadow;^orange;WEdit Config:", {weditController.configLocation[1], weditController.configLocation[2] - 1})
  end

  -- Actions
  if weditController.altFire then
    weditController.configLocation = tech.aimPosition()
  elseif not weditController.fireLock and weditController.primaryFire and weditController.configLocation and weditController.configLocation[1] then

  end
end

--[[
  Function to replace blocks within the selection with another one.
  Two actions; one to replace all existing blocks and one to replace the block type aimed at.
]]
function weditController.WE_Replace()
  wedit.info("^shadow;^orange;WEdit: Replace Tool")
  wedit.info("^shadow;^yellow;Primary Fire: Replace hovered block.", {0,-1})
  wedit.info("^shadow;^yellow;Alt Fire: Replace all blocks.", {0,-2})
  wedit.info("^shadow;^yellow;Replace With: ^red;" .. weditController.selectedBlockToString() .. "^yellow;.", {0,-3})
  wedit.info("^shadow;^yellow;Current Layer: ^red;" .. weditController.layer .. "^yellow;.", {0,-4})
  local tile = world.material(tech.aimPosition(), weditController.layer)
  if tile then
    wedit.info("^shadow;^yellow;Replace Block: ^red;" .. tile, {0,-5})
  end

  if not weditController.fireLock and weditController.validSelection() then
    if weditController.primaryFire and tile then
      weditController.fireLock = true

      local backup = wedit.replace(weditController.selection[1], weditController.selection[2], weditController.layer, weditController.selectedBlock, tile)
      if backup then table.insert(weditController.backup, backup) end
    elseif weditController.altFire then
      weditController.fireLock = true

      local backup = wedit.replace(weditController.selection[1], weditController.selection[2], weditController.layer, weditController.selectedBlock)
      if backup then table.insert(weditController.backup, backup) end
    end
  end
end

--[[
  Function to add modifications to terrain (matmods).
]]
function weditController.WE_Modifier()
  wedit.info("^shadow;^orange;WEdit: Modifier")
  wedit.info("^shadow;^yellow;Primary Fire: Modify hovered block.", {0,-1})
  wedit.info("^shadow;^yellow;Alt Fire: Select next Mod.", {0,-2})
  wedit.info("^shadow;^yellow;Current Mod: ^red;" .. weditController.getSelectedMod() .. "^yellow;.", {0,-3})
  wedit.info("^shadow;^yellow;Current Layer: ^red;" .. weditController.layer .. "^yellow;.", {0,-4})

  if not weditController.fireLock then
    if weditController.primaryFire then
      wedit.placeMod(tech.aimPosition(), weditController.layer, weditController.getSelectedMod())
    elseif weditController.altFire then
      weditController.fireLock = true
      weditController.modIndex = weditController.modIndex + 1
      if weditController.modIndex > #wedit.mods then weditController.modIndex = 1 end
    end
  end
end

--[[
  Function to draw a line of blocks between two selected points
]]
function weditController.WE_Ruler()
  wedit.info("^shadow;^orange;WEdit: Ruler")
  -- Line x - 1 reserved.
  wedit.info("^shadow;^yellow;Alt Fire: Fill selection.", {0,-2})
  wedit.info("^shadow;^yellow;Current Block: ^red;" .. weditController.selectedBlockToString() .. "^yellow;.", {0,-3})
  wedit.info("^shadow;^yellow;Current Layer: ^red;" .. weditController.layer .. "^yellow;.", {0,-4})

  -- Make selection (similar to WE_Select, but doesn't convert the two points to the bottom left and top right corner).
  if weditController.lineStage == 0 then
    -- Select stage 0: Not selecting.
    wedit.info("^shadow;^yellow;Primary Fire: Create selection.", {0,-1})

    if weditController.primaryFire then
      -- Start selection; set first point.
      weditController.lineStage = 1
      weditController.line[2] = {}
      weditController.line[1] = tech.aimPosition()
    end

  elseif weditController.lineStage == 1 then
  wedit.info("^shadow;^yellow;Drag mouse and let go to finish the selection.", {0,-1})
    -- Select stage 1: Selection started.
    if weditController.primaryFire then
      -- Dragging selection; update second point.
      weditController.line[2] = tech.aimPosition()

      -- Round each value down.
      weditController.line[1][1] = math.floor(weditController.line[1][1])
      weditController.line[2][1] = math.floor(weditController.line[2][1])

      weditController.line[1][2] = math.floor(weditController.line[1][2])
      weditController.line[2][2] = math.floor(weditController.line[2][2])
    else
      -- Selection ended; reset stage to allow next selection.
      weditController.lineStage = 0
    end
  else
    -- Select stage is not valid; reset it.
    weditController.lineStage = 0
  end

  -- Drawing and allowing RMB only works with a valid selection
  if weditController.line[1] and weditController.line[1][1] and weditController.line[2] and weditController.line[2][1] then
    -- Draw boxes around every block in the current selection.
    wedit.bresenham(weditController.line[1], weditController.line[2],
    function(x, y)
      world.debugLine({x, y}, {x + 1, y}, "green")
      world.debugLine({x, y + 1}, {x + 1, y + 1}, "green")
      world.debugLine({x, y}, {x, y + 1}, "green")
      world.debugLine({x + 1, y}, {x + 1, y + 1}, "green")
    end)

    wedit.info("^shadow;^yellow;Current line is indicated with green blocks.", {0,-5})

    -- RMB : Fill selection.
    if not weditController.fireLock and weditController.altFire then
      weditController.fireLock = true
      wedit.line(weditController.line[1], weditController.line[2], weditController.layer, weditController.selectedBlockToString())
    end
  end
end

--[[
  Function to remove all liquid(s) in the selection.
]]
function weditController.WE_Dehydrator()
  wedit.info("^shadow;^orange;WEdit: Dehydrator")
  wedit.info("^shadow;^yellow;Primary Fire: Dehydrate selection.", {0,-1})

  if not weditController.fireLock and weditController.primaryFire and weditController.validSelection() then
    weditController.fireLock = true
    wedit.drain(weditController.selection[1], weditController.selection[2])
  end
end

--[[
  Function to fill the selection with a liquid.
]]
function weditController.WE_Hydrator()
  wedit.info("^shadow;^orange;WEdit: Hydrator")
  wedit.info("^shadow;^yellow;Primary Fire: Fill selection.", {0,-1})
  wedit.info("^shadow;^yellow;Alt Fire: Select next Liquid.", {0,-2})
  wedit.info("^shadow;^yellow;Current Liquid: ^red;" .. wedit.liquids[weditController.liquidIndex].name .. "^yellow;.", {0,-3})

 -- Execute
  if not weditController.fireLock and weditController.primaryFire and weditController.validSelection() then
    weditController.fireLock = true
    wedit.hydrate(weditController.selection[1], weditController.selection[2], wedit.liquids[weditController.liquidIndex].id)
  end

  if not weditController.fireLock and weditController.altFire then
    weditController.fireLock = true

    weditController.liquidIndex = weditController.liquidIndex + 1
    if weditController.liquidIndex > #wedit.liquids then weditController.liquidIndex = 1 end
  end
  -- Scroll available liquids
end

--[[
  Function to obtain all WEdit Tools.
  Uses weditController.colors to color the names and descriptions of the tools.
]]
function weditController.WE_ItemBox()
  wedit.info("^shadow;^orange;WEdit: Item Box")
  wedit.info("^shadow;^yellow;Primary Fire: Spawn Tools.", {0,-1})

  if not weditController.fireLock and weditController.primaryFire then
    weditController.fireLock = true

    local items = root.assetJson("/weditItems/items.json")

    for i=1,#items do
      items[i].category = items[i].category:gsub("%^orange;", weditController.colors[1])
      items[i].description = items[i].description:gsub("%^yellow;", weditController.colors[2])
      world.spawnItem("silverore", mcontroller.position(), 1, items[i])
    end
  end
end

sb.logInfo("WEdit: Loaded!")
