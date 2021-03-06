require 'cairo'
local __cairo_xlib_surface_create 	= cairo_xlib_surface_create
local __cairo_create 				= cairo_create
local __cairo_surface_destroy 		= cairo_surface_destroy
local __cairo_destroy 				= cairo_destroy

local ABS_PATH = debug.getinfo(1).source:match("@?(.*/)")
package.path = ABS_PATH..'?.lua;'..
   ABS_PATH..'drawing/?.lua;'..
   ABS_PATH..'schema/?.lua;'..
   ABS_PATH..'core/func/?.lua;'..
   ABS_PATH..'core/widget/?.lua;'..
   ABS_PATH..'core/widget/arc/?.lua;'..
   ABS_PATH..'core/widget/text/?.lua;'..
   ABS_PATH..'core/widget/plot/?.lua;'..
   ABS_PATH..'core/widget/rect/?.lua;'..
   ABS_PATH..'core/widget/poly/?.lua;'

local Util 			= require 'Util'
local System 		= require 'System'
local Network 		= require 'Network'
local Processor 	= require 'Processor'
local FileSystem 	= require 'FileSystem'
local Pacman 		= require 'Pacman'
local Power 		= require 'Power'
local ReadWrite		= require 'ReadWrite'
local Graphics		= require 'Graphics'
local Memory		= require 'Memory'
local Static		= require 'Static'

local using_ac = function()
   -- for some reason it is much more efficient to test if the battery
   -- is off than if the ac is on
   return Util.read_file('/sys/class/power_supply/BAT0/status', nil, '*l') ~= 'Discharging'
end

local draw_dynamic

function conky_start(update_interval)
   conky_set_update_interval(update_interval)

   local update_freq = 1 / update_interval

   local mem = Memory(update_freq)
   local rw = ReadWrite(update_freq)
   local net = Network(update_freq)
   local pwr = Power(update_freq)
   local fs = FileSystem()
   local sys = System()
   local gfx = Graphics(update_freq)
   local proc = Processor(update_freq)
   local pcm = Pacman()

   local draw_static = Static(
      {sys.static, gfx.static, proc.static},
      {rw.static, net.static},
      {pcm.static, fs.static, pwr.static, mem.static}
   )

   local STATS_FILE = '/tmp/.conky_pacman'

   draw_dynamic = function(cr, _updates)
      -- timings of each line when cpu set to performance
      -- 0.7ms
      draw_static(cr)

      local t1 = _updates % (update_freq * 10)
      local pacman_stats = Util.read_file(STATS_FILE)
      -- 0.1ms
      local is_using_ac = using_ac()

      -- <0.1ms
      sys.dynamic(cr, pacman_stats)
      -- 0.3ms
      gfx.dynamic(cr)
      -- 0.8-1.1ms
      proc.dynamic(cr, t1)

      -- 0.1-0.3ms
      rw.dynamic(cr)
      -- 0.2ms
      net.dynamic(cr)

      -- <0.1ms
      pcm.dynamic(cr, pacman_stats)
      -- <0.1ms
      fs.dynamic(cr, t1)
      -- 0.3ms
      pwr.dynamic(cr, is_using_ac)
      -- 0.5ms
      mem.dynamic(cr)
   end
end

local updates = -2 -- this accounts for the first few spazzy iterations

function conky_main()
   local _cw = conky_window
   if not _cw then return end

   local cs = __cairo_xlib_surface_create(_cw.display, _cw.drawable,
                                          _cw.visual, 1920, 1080)
   local cr = __cairo_create(cs)
   updates = updates + 1

   draw_dynamic(cr, updates)

   __cairo_surface_destroy(cs)
   __cairo_destroy(cr)
end
