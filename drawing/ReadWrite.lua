local Util = require 'Util'
local Common = require 'Common'
local Geometry = require 'Geometry'

return function(update_freq)
   local PLOT_SEC_BREAK = 20
   local PLOT_HEIGHT = 56
   local DEVICES = {'sda', 'nvme0n1'}

   -- the sector size of any block device in linux is 512 bytes
   -- see https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/linux/types.h?id=v4.4-rc6#n121
   local BLOCK_SIZE_BYTES = 512

   -- fields 3 and 7 (sectors read and written)
   local RW_REGEX = '%s+%d+%s+%d+%s+(%d+)%s+%d+%s+%d+%s+%d+%s+(%d+)'

   local __tonumber = tonumber
   local __string_match = string.match
   local __math_floor = math.floor

   -----------------------------------------------------------------------------
   -- header

   local header = Common.Header(
      Geometry.CENTER_LEFT_X,
      Geometry.TOP_Y,
      Geometry.SECTION_WIDTH,
      'INPUT / OUTPUT'
   )

   -----------------------------------------------------------------------------
   -- reads

   -- local io_label_format_fun_generator = function(plot_max)
   --    local new_unit, new_max = Util.convert_data_val(plot_max)
   --    local conversion_factor = plot_max / new_max
   --    local fmt = Common.y_label_format_string(new_max, new_unit..'B/s')
   --    return function(bytes)
   --       return string.format(fmt, bytes / conversion_factor)
   --    end
   -- end

   local format_value_function = function(bps)
      local unit, value = Util.convert_data_val(bps)
      return Util.precision_round_to_string(value, 3)..' '..unit..'B/s'
   end

   local build_plot = function(y, label)
      return Common.initLabeledScalePlot(
         Geometry.CENTER_LEFT_X,
         y,
         Geometry.SECTION_WIDTH,
         PLOT_HEIGHT,
         format_value_function,
         Common.converted_y_label_format_generator('B'),
         PLOT_SEC_BREAK,
         label,
         2,
         update_freq
      )
   end

   local reads = build_plot(header.bottom_y, 'Reads')

   -----------------------------------------------------------------------------
   -- writes

   local writes = build_plot(
      header.bottom_y + PLOT_HEIGHT + PLOT_SEC_BREAK * 2,
      'Writes'
   )

   -----------------------------------------------------------------------------
   -- update function

   local DEVICE_PATHS = {}
   for i = 1, #DEVICES do
      DEVICE_PATHS[i] = string.format('/sys/block/%s/stat', DEVICES[i])
   end

   local read_devices = function()
      local read_bytes = 0
      local write_bytes = 0
      for _, path in pairs(DEVICE_PATHS) do
         local r, w = __string_match(Util.read_file(path), RW_REGEX)
         read_bytes = read_bytes + __tonumber(r)
         write_bytes = write_bytes + __tonumber(w)
      end
      return read_bytes * BLOCK_SIZE_BYTES, write_bytes * BLOCK_SIZE_BYTES
   end

   local prev_read_bytes, prev_write_bytes = read_devices()

   local compute_rate = function(x0, x1)
      -- mask overflow
      if x1 > x0 then
         return (x1 - x0) * update_freq
      else
         return 0
      end
   end

   local update = function(cr)
      local read_bytes, write_bytes = read_devices()
      Common.annotated_scale_plot_set(
         reads,
         cr,
         compute_rate(prev_read_bytes, read_bytes)
      )
      Common.annotated_scale_plot_set(
         writes,
         cr,
         compute_rate(prev_write_bytes, write_bytes)
      )
      prev_read_bytes = read_bytes
      prev_write_bytes = write_bytes
   end

   -----------------------------------------------------------------------------
   -- main drawing functions

   local draw_static = function(cr)
      Common.drawHeader(cr, header)
      Common.annotated_scale_plot_draw_static(reads, cr)
      Common.annotated_scale_plot_draw_static(writes, cr)
   end

   local draw_dynamic = function(cr)
      update(cr)
      Common.annotated_scale_plot_draw_dynamic(reads, cr)
      Common.annotated_scale_plot_draw_dynamic(writes, cr)
   end

   return {static = draw_static, dynamic = draw_dynamic}
end
