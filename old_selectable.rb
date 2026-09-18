module Hokusai::Util
  class PositionSelection
    attr_accessor :positions, :cursor_index, :direction, :type

    def initialize
      @cursor_index = nil
      @positions = []
      @direction = :right
      @type = :none
    end

    def move(to, selecting, times = 1)
      if selecting
        @type = :active
      end
  
      return if cursor_index.nil?
      
      case to
      when :right
        self.cursor_index += times
        if selecting && !positions.empty? && cursor_index <= positions.last
          positions.shift
        elsif selecting
          positions << cursor_index 
        end

      when :left
        if selecting && !positions.empty? && cursor_index >= positions.last
          positions.pop
        elsif selecting
          positions.unshift cursor_index
        end
  
        self.cursor_index -= times unless cursor_index == -1
      end
    end

    def activate!
      @type = :active
    end

    def active?
      @type == :active
    end

    def frozen?
      @type == :frozen
    end

    def freeze!
      @type = :frozen
    end

    def left?
      direction == :left
    end

    def right?
      direction == :right
    end

    def clear
      self.cursor_index = nil
      positions.clear
    end

    def selected(index)
      (positions.first..positions.last).include?(index)
    end

    def select(range)
      self.positions.concat(range).uniq!
    end
  end
end

module Hokusai::Util
  class GeometrySelection
    attr_accessor :start_x, :start_y, :stop_x, :stop_y, :direction,
                  :type, :cursor, :diff, :click_pos, :parent, :modified

    def initialize(parent)
      @parent = parent
      @type = :none         # state for the geometry selection (active/frozen/etc)
      @start_x = 0.0        # the x coordinate for the geometry
      @start_y = 0.0        # the y coordinate for the geometry 
      @stop_x = 0.0
      @stop_y = 0.0
      @diff = 0.0
      @cursor = nil
      @click_pos = nil
    end

    def set_click_pos(x, y)
      @click_pos = [x, y]
    end

    def none?
      type == :none
    end

    def ready?
      type == :none || type == :frozen
    end

    def clear
      self.start_x = 0.0
      self.start_y = 0.0
      self.stop_x = 0.0
      self.stop_y = 0.0
      self.cursor = nil
    end

    def changed_direction?
      @changed_direction
    end

    def activate!
      @type = :active
    end

    def active?
      type == :active
    end

    def frozen?
      type == :frozen
    end

    def freeze!
      self.type = :frozen
      parent.pos!
    end

    def coords
      [start_x, stop_x, start_y, stop_y]
    end

    def start(x, y)
      self.start_x = x
      self.start_y = y + parent.offset_y
      self.stop_x = x
      self.stop_y = y + parent.offset_y
      self.cursor = nil
      @click_pos = nil

      activate!
    end

    def stop(x, y)
      self.stop_x = x
      self.stop_y = y + parent.offset_y

      @modified = true

      if up? && @direction == :down || down? && @direction == :up
        @changed_direction = true
      else
        @changed_direction = false
      end

      @direction = up? ? :up : :down
    end

    def up?(height = 0)
      stop_y < start_y - height
    end

    def down?(height = 0)
      start_y <= stop_y - height
    end

    def left?
      stop_x < start_x
    end

    def right?
      start_x <= stop_x
    end

    def cursor=(arr)
      return if frozen? && !@modified && parent.geom?

      @cursor = arr
      @modified = false
    end

    def cursor
      return nil unless @cursor

      return [@cursor[0], @cursor[1] - parent.offset_y, @cursor[2], @cursor[3]]
    end

    def rect_selected(rect)
      selected(rect[0], rect[1], rect[2], rect[3])
    end

    def on_line(y, h)
      return false if click_pos.nil?

      click_pos[1] > y && click_pos[1] <= y + h 
    end

    def clicked(x,y,w,h)
      return false if click_pos.nil?

      pos = Hokusai::Rect.new(x, y - parent.offset_y, w, h)
      # pos.move_x_left
      pos.includes_x?(click_pos[0]) && pos.includes_y?(click_pos[1])
    end

    def selected(x, ty, width, height)
      return false if none?

      y = ty - parent.offset_y
      sy = @start_y - parent.offset_y
      ey = @stop_y - parent.offset_y

      sx = @start_x
      ex = @stop_x

      down = sy <= ey
      up = ey < sy
      left = ex < sx
      right = sx <= ex

      rect = Hokusai::Rect.new(x, y, width, height)
      x_shifted_right = rect.move_x_right(1)
      y_shifted_up = rect.move_y_up(2)
      y_shifted_down = rect.move_y_down(2)
      end_y = y + height

      a = ((down &&
        # first line of multiline selection
        ((x_shifted_right > sx && end_y < ey && rect.includes_y?(sy)) ||
          # last line of multiline selection
          (x_shifted_right <= ex && y_shifted_up + height < ey && y > sy) ||
          # middle line (all selected)
          (y > sy && end_y < ey))) ||
        (up &&
          # first line of multiline selection
          ((x_shifted_right <= sx && y > ey && rect.includes_y?(sy)) ||
          # last line of multiline selection
            (x_shifted_right >= ex && y_shifted_down > ey && end_y < sy) ||
            # middle line (all selected)
            (y > ey && y + height < sy))) ||
        # single line selection
        ((rect.includes_y?(sy) && rect.includes_y?(ey)) &&
          ((left && x_shifted_right < sx && x_shifted_right > ex) || (right && x_shifted_right > sx && x_shifted_right < ex)))
      )

      a
    end
  end
end


module Hokusai::Util
  class Selection
    attr_reader :geom, :pos
    attr_accessor :type, :offset_y, :diff, :cursor, :action

    def initialize
      @geom = GeometrySelection.new(self)
      @pos = PositionSelection.new
      @type = :geom
      @offset_y = 0.0
      @diff = 0.0
      @cursor = nil
      @action = nil
    end

    def clear
      pos.clear
      geom.clear
    end

    def cursor
      geom.cursor
    end

    def geom!(lclear = true)
      pos.clear if lclear
      pos.cursor_index = nil if lclear
      pos.active = false
      self.type = :geom
    end

    def pos!(lclear = true)
      geom.clear if lclear

      self.type = :pos
    end

    def geom?
      type == :geom
    end

    def pos?
      type == :pos
    end

    def left?
      geom? ? geom.left? : pos.left?
    end

    def right?
      geom? ? geom.right? : pos.right?
    end

    def up?
      geom? && geom.up?
    end

    def down?
      geom? && geom.down?
    end

    def selecting?
      !(geom.type == :none && geom.click_pos.nil?)
    end

    # should we show the cursor?
    def active?
      !cursor.nil?
    end
  end
end

module Hokusai
  class Timer
    attr_accessor :start

    def initialize
      @start = Hokusai.monotonic
    end

    def elapsed(seconds)
      Hokusai.monotonic - @start > seconds
    end

    def reset
      @start = Hokusai.monotonic
    end
  end
end

# Public: slotted block which provides text selection information
#         to descendants
module Hokusai::Blocks
  class Selectable < Hokusai::Block
    template <<~EOF
      [template]
        dynamic {
          @keypress="on_keypress"
          @keyup="on_keyup"
          @keydown="on_keydown"
          @hover="update_selection"
          @click="start_selection"
          @size_updated="update_height"
        }
          slot
          cursor {
            height="0"
            :color="cursor_color"
            :x="cursor_x"
            :y="cursor_y"
            :cursor_height="cursor_height"
            :show="cursor_show"
          }
    EOF

    uses(
      dynamic: Hokusai::Blocks::Dynamic,
      cursor: Hokusai::Blocks::Cursor
    )

    computed :cursor_color, default: [255,22,22], convert: Hokusai::Color

    provide :selection, :selection
    inject :panel

    attr_reader :selection, :shift, :timer

    def update_height(w, h)
      node.meta.set_prop(:height, h)
    end

    def initialize(**args)
      @selection = Hokusai::Util::Selection.new
      @timer = Hokusai::Timer.new

      super
    end

    def on_keypress(event)
      @shift = true if event.shift
      timer.reset
      if [:left, :right, :up, :down].include?(event.symbol)
        @target_nav = event.symbol
      elsif [:home, :end, :page_up, :page_down].include?(event.symbol)

        @target_paging = true
      end

      # if selection.geom.none?
      #   x = event.input.mouse.pos.x
      #   y = event.input.mouse.pos.y
      #   selection.geom.start(x, y)
      # end
    end
    
    def on_keydown(event)
      return unless timer.elapsed(0.2)
      if @target_nav
        selection.pos!(false)
        case @target_nav
        when :left
          selection.pos.move(:left, true)
        when :right
          selection.pos.move(:right, true)
        when :up
        when :down
        end
      end
      
      if @target_paging
        x = event.input.mouse.pos.x
        y = event.input.mouse.pos.y
        selection.geom.stop(x, y)
      end
    end

    def on_keyup(event)
      if @target_nav && @shift
        selection.pos!(false)
        case @target_nav
        when :left
          selection.pos.move(:left, true)
        when :right
          selection.pos.move(:right, true)
        when :up
        when :down
        end
      end

      if @target_paging && @shift
        x = event.input.mouse.pos.x
        y = event.input.mouse.pos.y
        selection.geom.stop(x, y)
      end

      @target_nav = false
      @target_paging = false
      @shift = false
    end

    def start_selection(event)
      case event.left.click_count
      when 2
        selection.pos.activate!
        selection.action = :word
      when 3
        selection.pos.activate!
        selection.action = :line
      when 4
        selection.pos.activate!

        selection.action = :all
      else
        selection.action = nil
      end

      if !shift && event.left.down
        selection.pos.positions.clear
        selection.pos.cursor_index = nil
        selection.geom!

        selection.geom.clear
        selection.geom.start(event.pos.x, event.pos.y)
        selection.geom.set_click_pos(event.pos.x, event.pos.y)
      elsif shift && event.left.down
        selection.geom.stop(event.pos.x, event.pos.y)
        selection.geom.set_click_pos(event.pos.x, event.pos.y)
      elsif selection.geom.frozen?
        selection.geom.click_pos = nil
        selection.geom.clear
      end
    end

    def update_selection(event)
      return unless selection.geom.active?
      
      if event.left.up
        selection.geom.freeze!
      elsif event.left.down
        selection.geom.stop(event.pos.x, event.pos.y)
      end
    end

    def cursor_x
      cursor(0)
    end

    def cursor_y
      cursor(1)
    end

    def cursor_height
      cursor(3)
    end

    def cursor_show
      !selection.cursor.nil?
    end

    def cursor(index)
      return if selection.cursor.nil?

      selection.cursor[index]
    end
  end
end

module Hokusai
  class MouseButton
    attr_accessor :up, :down, :clicked, :released
    attr_reader :click_count

    def initialize
      @up = false
      @down = false
      @clicked = false
      @released = false
      @click_count = 0
      @time = nil
    end

    def clicked=(val)
      @clicked = val
      if val
        @time ||= Hokusai.monotonic
        if Hokusai.monotonic - @time < 0.5
          @click_count += 1
          @time = Hokusai.monotonic
        else
          @click_count = 1
          @time = Hokusai.monotonic
        end
      end
    end
  end
end