---------------------------------------------------------------
-- Basic scratchpad manager for the awesome window manager
---------------------------------------------------------------
-- Coded by:  * Adrian C. (anrxc) <anrxc@sysphere.org>
--            * Konstantin Koslowski (konni) <konstantin.koslowski@gmail.com>
-- Licensed under the WTFPL version 2
--   * http://sam.zoy.org/wtfpl/COPYING
---------------------------------------------------------------
-- To use this module add:
--     local scratch = require("scratch")
-- to the top of your rc.lua, and call:
--     scratch.pad.set(c, args)
-- from a clientkeys binding, and:
--     scratch.pad.toggle({instance, screen})
-- from a globalkeys binding.
--
-- Parameters:
-- c        - Client to scratch or un-scratch
-- args     - table containing properties
--  args.vert     - vertical position
--                possible values: "left", "right", "top", "bottom", "center"
--                defaults to "center"
--  args.horiz    - horizontal position
--                possible values: "left", "right", "top", "bottom", "center"
--                defaults to "center"
--  args.width    - Width in absolute pixels, or width percentage
--                when <= 1
--                (0.50 (50% of the screen) by default)
--  args.height   - Height in absolute pixels, or height percentage
--                when <= 1
--                (0.50 (50% of the screen) by default)
--  args.sticky   - client visible on all workspaces
--                defaults to false
--  args.instance - used to have multiple scratched clients
--                defaults to 0
--  args.screen   - screen the client appears on, 0 for any
--                mouse.screen by default
---------------------------------------------------------------

-- Grab environment
local pairs = pairs
local awful = require("awful")
local capi = {
    mouse = mouse,
    client = client,
    screen = screen
}

-- Scratchpad: basic scratchpad manager for the awesome window manager
local pad = {} -- module scratch.pad


local scratchpad = {}

-- Toggle a set of properties on a client.
local function toggleprop(c, prop)
    c.ontop  = prop.ontop  or false
    c.above  = prop.above  or false
    c.hidden = prop.hidden or false
    c.sticky = prop.stick  or false
    c.skip_taskbar = prop.task or false
end

-- Scratch the focused client, or un-scratch and tile it.
-- If another client is already scratched, replace it with the focused client.
function pad.set(c, args)
  vert      = args.vert      or "center"
  horiz     = args.horiz     or "center"
  width     = args.width     or 0.50
  height    = args.height    or 0.50
  sticky    = args.sticky    or false
  instance  = args.instance  or 0
  screen    = args.screen    or capi.mouse.screen

  -- Determine signal usage in this version of awesome
  local attach_signal = capi.client.connect_signal    or capi.client.add_signal
  local detach_signal = capi.client.disconnect_signal or capi.client.remove_signal

  local function setscratch(c)
    -- Scratchdrop clients are floaters
    awful.client.floating.set(c, true)

    -- Client geometry and placement
    local screengeom = capi.screen[capi.mouse.screen].workarea

    if width  <= 1 then width  = screengeom.width  * width  end
    if height <= 1 then height = screengeom.height * height end

    if     horiz == "left"  then x = screengeom.x
    elseif horiz == "right" then x = screengeom.width - width
    else   x =  screengeom.x+(screengeom.width-width)/2 end

    if     vert == "bottom" then y = screengeom.height + screengeom.y - height - 4
    elseif vert == "center" then y = screengeom.y+(screengeom.height-height)/2
    else   y =  screengeom.y - screengeom.y end

    -- Client properties
    c:geometry({ x = x, y = y, width = width, height = height })
    c.ontop = true
    c.above = true
    c.skip_taskbar = true
    if sticky then c.sticky = true end
    awful.titlebar.hide(c)

    c:raise()
    capi.client.focus = c
  end

  -- Prepare a table for storing clients,
  if not scratchpad.pad then scratchpad.pad = {} end
  if not scratchpad.pad[instance] then scratchpad.pad[instance] = {} end
  attach_signal("unmanage", function (c)
    -- add unmanage signal for scratchpad clients
    for scr, cl in pairs(scratchpad.pad[instance]) do
      if cl == c then scratchpad.pad[instance][scr] = nil end
    end
  end)

  -- If the scratcphad is emtpy, store the client,
  if not scratchpad.pad[instance][screen] then
    scratchpad.pad[instance][screen] = c
    -- then apply geometry and properties
    setscratch(c)
  else -- If a client is already scratched,
    local oc = scratchpad.pad[instance][screen]
    -- unscratch, and compare it with the focused client
    awful.client.floating.toggle(oc); toggleprop(oc, {})
    -- If it matches clear the table, if not replace it
    if  oc == c then scratchpad.pad[instance][screen] =     nil
    else scratchpad.pad[instance][screen] = c; setscratch(c) end
  end
end

-- Move the scratchpad[instance] to the current workspace, focus and raise it
-- when it's hidden, or hide it when it's visible.
function pad.toggle(args)
  if not args then args = {} end
  instance  = args.instance  or 0
  screen    = args.screen    or capi.mouse.screen

  -- Check if we have a client on storage,
  if scratchpad.pad and scratchpad.pad[instance] then
    if scratchpad.pad[instance][0] ~= nil then
      screen = 0
    end
    -- and get it out, to play
    if scratchpad.pad[instance][screen] ~= nil then
      local c = scratchpad.pad[instance][screen]

      -- If it's visible on another tag hide it,
      if c:isvisible() == false then c.hidden = true
          -- and move it to the current worskpace
          awful.client.movetotag(awful.tag.selected(capi.mouse.screen), c)
      end
      -- Focus and raise if it's hidden,
      if c.hidden then
        -- awful.placement.centered(c)
        c.hidden = false
        c:raise(); capi.client.focus = c
      else -- hide it if it's not
        c.hidden = true
      end
    end
  end
end

return pad
