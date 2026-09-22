module Hokusai
  module Util
    class PosSelection
      attr_reader :parent
      attr_accessor :cursor_index, :state, :positions, :offset, :direction

      def initialize(parent)
        @parent = parent
        @positions = nil
        @cursor_index = nil
        @state = :none
        @offset = 0
        @direction = nil
      end

      def move(to, selecting, times = 1)
        return if cursor_index.nil? || (selecting && positions.nil?)

        case to
        when :right
          self.cursor_index += times

          if positions && cursor_index == positions.last
            self.positions = cursor_index..cursor_index
          elsif selecting && !positions.nil? && cursor_index <= positions.last
            self.positions = (positions.first + 1)...positions.last
          elsif selecting
            self.positions = positions.first..cursor_index 
          end

        when :left
          if selecting && !positions.nil? && cursor_index >= positions.last
            if positions.last - 1 < positions.first
              self.positions = positions.last - 1...positions.first
              @moved_left = true
            else
              self.positions = positions.first...positions.last - 1
            end
          elsif selecting
            self.positions = cursor_index...positions.last
          end
          self.cursor_index -= times unless cursor_index == -1

        end
      end

      def left?
        direction == :left
      end

      def right?
        direction == :right
      end

      def frozen?
        state == :frozen
      end

      def freeze!
        self.state = :frozen
      end

      # Public: merges the geometry selection into the existing positions
      #
      # arr - the tokens that are currently selected on the screen.
      #       Note: if the selection is out of the viewport, this will be missing tokens.
      #
      # Returns nothing
      def concat(arr)
        return if arr.nil?

        if @positions.nil?
          @positions = arr.first..arr.last

          return
        end
        # p [@positions, arr.first..arr.last, parent.geom.changed_direction?]

        if parent.geom.down? && parent.geom.changed_direction?
          max = [positions.first, arr.first].max
          if max == arr.last
            # p ["niling pos"]
            @positions = nil
            return
          end

          # p ["setting pos 1", max..arr.last]
          @positions = max..arr.last
          parent.geom.changed_direction = false # TEST: WIP
        elsif parent.geom.down?

          max = arr.last
          min = positions.first#[positions.first, arr.first].min

          if min == max
            # p ["niling pos"]

            @positions = nil
            return
          end

          # p ["pos 2", min..max]
          @positions = min..max
        elsif parent.geom.up? && parent.geom.changed_direction?
          min = [positions.first, arr.first].min
          max = [positions.first, arr.last].max

          if min == max
            # p ["niling pos"]

            @positions = nil
            return
          end

          if positions.first > arr.last
            max -= 1
          end

          # p ["pos 3", min...max]

          @positions = min...max
          parent.geom.changed_direction = false #test WIP
        elsif parent.geom.up?
          if arr.first == positions.last || arr.first > positions.last
            # p ["niling pos", arr.first..arr.last, positions]

            @positions = nil
            return
          end

          min = []

          # p ["pos 4", arr.first..positions.last]
          @positions = arr.first...positions.last
        else
          # p ["default", arr.first..arr.last]
          @positions = arr.first..arr.last
        end
      end

      def selected(index)
        # p positions
        return false if positions.nil?

        # if parent.geom.original_direction == :up && parent.geom.direction == :down
        #   p ["switch up down"]
        #   self.offset = 1
        # elsif parent.geom.original_direction == :down && parent.geom.direction == :up
        #   p ["downup"]
        #   self.offset = -1
        # else
        #   self.offset = 0
        # end
        
        # p ["result", positions.first..positions.last +  offset]
        (positions.first..positions.last).include?(index)
      end

      def clear
        self.offset = 0
        self.cursor_index = nil
        self.positions = nil
        self.state = :none
      end
    end

    class GeomSelection
      attr_reader :parent, :direction
      attr_accessor :start_x, :start_y, :stop_x, :stop_y, :click_pos, :modified, 
                    :changed_direction, :original_direction, :resized
      
      def initialize(parent)
        @parent = parent
        @start_x = 0.0
        @start_y = 0.0
        @stop_x = 0.0
        @stop_y = 0.0
        @click_pos = nil
        @modified = false
        @original_direction = nil
        @resized = false
      end

      def start(x, y)
        self.start_x = x
        self.start_y = y + parent.offset_y
        self.stop_x = x
        self.stop_y = y + parent.offset_y
        self.click_pos = nil
        parent.cursor = nil
      end

      def move_up(height)
        self.stop_y -= height

        if (up? && @direction == :down) || (down? && @direction == :up)
          @changed_direction = true
        end

        @direction = up? ? :up : :down
      end

      def move_down(height)
        self.stop_y += height

        if (up? && @direction == :down) || (down? && @direction == :up)
          @changed_direction = true
        end

        @direction = up? ? :up : :down
      end

      def stop(x, y)
        self.stop_x = x
        self.stop_y = y + parent.offset_y
        self.modified = true
        self.original_direction ||= up? ? :up : :down

        if (up? && @direction == :down) || (down? && @direction == :up)
          @changed_direction = true
        end

        @direction = up? ? :up : :down
      end

      def commit!
        parent.pos!
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

      def changed_direction?
        @changed_direction
      end

      def clear
        self.start_x = 0.0
        self.start_y = 0.0
        self.stop_x = 0.0
        self.stop_y = 0.0
        parent.cursor = nil
      end
      
      def rect_selected(rect)
        selected(rect[0], rect[1], rect[2], rect[3])
      end

      def clicked_on_line(x, y, w, h)
        return false if click_pos.nil?

        click_pos[1] > y - parent.offset_y && click_pos[1] <= y - parent.offset_y + h  && click_pos[0] > w
      end

      def clicked(x,y,w,h)
        return false if click_pos.nil?

        pos = Hokusai::Rect.new(x, y - parent.offset_y, w, h)
        pos.includes_x?(click_pos[0]) && pos.includes_y?(click_pos[1])
      end

      def selected(x, ty, width, height)
        return false if parent.pos?

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

    class Selection
      attr_reader :pos, :geom
      attr_accessor :offset_y, :offset_x, :offset_pos, :cursor, 
                    :action, :state, :use_focus, :focus_id, :top, :column,
                    :insert

      def initialize
        @pos = PosSelection.new(self)
        @geom = GeomSelection.new(self)
        @offset_y = 0.0
        @offset_x = 0.0
        @offset_pos = 0
        @cursor = nil
        @action = nil
        @state = :geom
        @use_focus = false
        @focus_id = nil
        @top = 0.0
        @column = nil
        @insert = false
      end
      
      # def cursor_index
      #   return pos.cursor_index unless insert
    
      #   case pos.cursor_index
      #   when nil
      #     0
      #   when 0
      #     0
      #   else

      #   end
      # end

      def cursor=(arr)
        return if (geom? && !geom.modified)

        @cursor = arr
      ensure
        geom.modified = false
      end

      def offset_y
        @top + @offset_y
      end

      def cursor
        return nil unless @cursor

        return [@cursor[0], @cursor[1] - offset_y, @cursor[2], @cursor[3]]
      end

      def geom?
        state == :geom
      end

      def geom!(pclear = true)
        pos.clear if pclear

        self.state = :geom
      end

      def pos?
        state == :pos
      end

      def pos!(gclear = false)
        geom.clear if gclear
        # p ["changed direction = false", gclear]
        geom.changed_direction = false
        geom.click_pos = nil

        self.state = :pos
      end

      def clear
        geom.clear
        pos.clear
        self.cursor = nil

        geom!
      end

      def selecting?
        (geom?) || (pos? && !pos.cursor_index.nil?)
        #(geom? && !geom.click_pos.nil?) || (pos? && pos.cursor_index)
      end
    end
  end
end

module Hokusai::Blocks
  class Selectable < Hokusai::Block
    template <<~EOF
      [template]
        dynamic {
          :vertical="vertical"
          @keypress="on_keypress"
          @keyup="on_keyup"
          @keydown="on_keydown"
          @hover="on_hover"
          @mouseup="on_mouseup"
          @click="on_click"
          @size_updated="update_height"
        }
          slot
          cursor {
            width="0"
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
    computed :vertical, default: true
    computed :focus_mode, default: true

    provide :selection, :selection
    inject :panel_control

    attr_reader :selection, :timer
    attr_accessor :shift, :nav_target, :page_target

    def update_height(w, h)
      node.meta.set_prop(:height, h)
    end

    def initialize(**args)
      # our selection object
      @selection = Hokusai::Util::Selection.new
      # debounce timer for keydown
      @timer = Hokusai::Timer.new
      @shift = false
      @nav_target = nil
      @page_target = nil
      @top = nil

      super
    end

    def on_keypress(event)
      self.shift = true if event.shift
      timer.reset

      if [:left, :right, :up, :down].include?(event.symbol)
        self.nav_target = event.symbol
      elsif [:home, :end, :page_up, :page_down].include?(event.symbol)
        self.page_target = true
      end
    end
    
    def on_keydown(event)  
      return unless timer.elapsed(0.2)
      selection.action = nav_target if nav_target 
      case nav_target
      when :left
        selection.pos.move(:left, true)
      when :right
        selection.pos.move(:right, true)
      when :up
        # p [panel_control.offset, selection.geom.stop_y]
        if selection.geom.stop_y - panel_control.offset < 70
          navheight = panel_control.scroll_y - 5
          panel_control.scroll_y = navheight
          panel_control.scroll_goto_y = navheight
          panel_control.scroll_percent = panel_control.local_percent_scrolled
        end
        selection.action = :up
      when :down
        if (panel_control.offset + panel_control.panel_height) - selection.geom.stop_y < 70
          navheight = panel_control.scroll_y + 5
          panel_control.scroll_y = navheight
          panel_control.scroll_goto_y = navheight
          panel_control.scroll_percent = panel_control.local_percent_scrolled
        end
        selection.action = :down
      end
    end

    def on_keyup(event)
      if nav_target && shift
        case nav_target
        when :left
          selection.pos.move(:left, true)
        when :right
          selection.pos.move(:right, true)
        when :up
          # p [panel_control.offset, selection.geom.stop_y]
          if selection.geom.stop_y - panel_control.offset < 70
            navheight = panel_control.scroll_y - 5
            panel_control.scroll_y = navheight
            panel_control.scroll_goto_y = navheight
            panel_control.scroll_percent = panel_control.local_percent_scrolled
          end
          selection.action = :up
        when :down
          if (panel_control.offset + panel_control.panel_height) - selection.geom.stop_y < 70
            navheight = panel_control.scroll_y + 5
            panel_control.scroll_y = navheight
            panel_control.scroll_goto_y = navheight
            panel_control.scroll_percent = panel_control.local_percent_scrolled
          end
          selection.action = :down
        end
      end

      if page_target && shift
        x = event.input.mouse.pos.x
        y = event.input.mouse.pos.y
        selection.geom.stop(x, y)
        selection.geom!
        selection.action = :collect
      end

      self.nav_target = nil
      self.page_target = nil
      self.shift = false unless event.shift
    end

    def on_resize(canvas)
      # resizing triggers a click event. >:(
      @resizing = true

      # ok, preserving the selection on resize is fine, but
      # the geometry is corrupted, so we have to clear it.
      # 
      # this makes shift + click fail intermittently after a resize.
      # work has been done, but the most stable thing to do is clear the selection.
      selection.clear
    end

    def on_click(event)
      if event.right.clicked
        p selection.inspect
        return
      end

      selection.action = { 2 => :word, 3 => :line, 4 => :all }[event.left.click_count]

      # if this is a fresh click
      # clear all selections
      if !shift && event.left.clicked && !@resizing
        selection.clear
        selection.geom.start(event.pos.x, event.pos.y)
        selection.geom.click_pos = [event.pos.x, event.pos.y]
      elsif shift && event.left.down && !@resizing
        # Bug: when shift click after a resize, the geometry is messed up from the resize, and this will not work.
        # We would absolutely need to get the geometry from the pos selection.
        selection.geom.stop(event.pos.x, event.pos.y)
        selection.geom!
        selection.action = :collect
      end
    end

    def on_mouseup(event)
      if event.left.released && !shift
        selection.column = nil
        # selection.pos!
        # selection.geom.click_pos = nil
      end
    end

    def on_hover(event)
      return unless selection.geom?

      if event.left.up
        # p ['niling action']
        selection.action = nil
        # by the time we switch to pos, positions should already be populated.
        selection.pos!(false)
        selection.pos.freeze!
      elsif event.left.down && !event.input.keyboard.shift
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

    def render(canvas)
      selection.use_focus = focus_mode
      selection.offset_pos = 0
      @top = canvas.y
      @resizing = false

      yield canvas
    end
  end
end