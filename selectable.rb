module Hokusai
  module Util
    class PosSelection
      attr_reader :parent
      attr_accessor :cursor_index, :state, :positions, :offset

      def initialize(parent)
        @parent = parent
        @positions = nil
        @cursor_index = nil
        @state = :none
        @offset = 0
      end

      def move(to, selecting, times = 1)
        return if cursor_index.nil? || positions.nil?

        case to
        when :right
          self.cursor_index += times

          if cursor_index == positions.last
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

      def concat(arr)
        return if arr.reject(&:nil?).empty?

        if @positions.nil?
          @positions = arr.first..arr.last

          return
        end

        if parent.geom.up?
          # was going down, now up..
          # 
          # a b c | d e f 
          # d is selected when going down, but not up.
          if parent.geom.changed_direction?
            if arr.last > positions.first
              range = (arr.first..arr.last)
            else
              range = (arr.first..positions.first)
              self.offset -= 1
            end
            # p ["ooshit", arr.first..arr.last, positions]

            @positions = range
          # going up from down
          else
            # p ["normal", arr.first..@positions.last]
            @positions = (arr.first..@positions.last)
          end
        else
          # was going up now down
          # a b c | d e f
          # c is selected when going up, but not down
          if parent.geom.changed_direction? && !parent.pos?
            p parent.pos?, self.offset
            range = (positions.last)..arr.last
            # p ["updown", range]
            self.offset += 1
            @positions = range
          else
            # p ["reg down", positions.first..arr.last]
            @positions = (positions.first..arr.last)
          end
        end
      end

      def selected(index)
        # p positions
        return false if positions.nil?
        
        (positions.first..positions.last + offset).include?(index)
      end

      def clear
        self.offset = 0
        self.cursor_index = nil
        self.positions = nil
        self.state = :none
      end
    end

    class GeomSelection
      attr_reader :parent
      attr_accessor :start_x, :start_y, :stop_x, :stop_y, :click_pos, :modified
      
      def initialize(parent)
        @parent = parent
        @start_x = 0.0
        @start_y = 0.0
        @stop_x = 0.0
        @stop_y = 0.0
        @click_pos = nil
        @modified = false
      end

      def start(x, y)
        self.start_x = x
        self.start_y = y + parent.offset_y
        self.stop_x = x
        self.stop_y = y + parent.offset_y
        self.click_pos = nil
        parent.cursor = nil
      end

      def stop(x, y)
        self.stop_x = x
        self.stop_y = y + parent.offset_y

        self.modified = true

        if up? && @direction == :down || down? && @direction == :up
          @changed_direction = true
        else
          @changed_direction = false
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

      def clicked_on_line(y, h)
        return false if click_pos.nil?

        click_pos[1] > y && click_pos[1] <= y + h 
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
      attr_accessor :offset_y, :offset_x, :cursor, :action, :state

      def initialize
        @pos = PosSelection.new(self)
        @geom = GeomSelection.new(self)
        @offset_y = 0.0
        @offset_x = 0.0
        @cursor = nil
        @action = nil
        @state = :geom
      end

      def cursor=(arr)
        return if (geom? && !geom.modified)

        @cursor = arr
      ensure
        geom.modified = false
      end

      def cursor
        return nil unless @cursor

        return [@cursor[0], @cursor[1] - offset_y, @cursor[2], @cursor[3]]
      end

      def geom?
        state == :geom
      end

      def geom!
        pos.clear

        self.state = :geom
      end

      def pos?
        state == :pos
      end

      def pos!(gclear = false)
        geom.clear if gclear
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
        (geom?) || (pos? && pos.cursor_index)
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
      # if event.shift && !shift && event.input.mouse.left.down
      #   p ["shift", shift, event.shift, "mousedown"]
      #   selection.pos.state = :none
      #   selection.action = :collect
      #   selection.geom.stop(event.input.mouse.pos.x, event.input.mouse.pos.y)
      #   selection.geom!
      #   self.shift = true
      # elsif event.shift && shift && event.input.mouse.left.down
      #   selection.pos!
      #   selection.pos.freeze!
      # end
  
      return unless timer.elapsed(0.2)
      selection.action =  nav_target
      #   case nav_target
      #   when :left
      #     selection.action = :left
      #     # selection.pos.move(:left, true)
      #   when :right
      #     selection.action = :right
      #     # selection.pos.move(:right, true)
      #   when :up
      #   when :down
      #   end
      # end
      
      if page_target
        x = event.input.mouse.pos.x
        y = event.input.mouse.pos.y
        selection.geom.stop(x, y)
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
        when :down
        end
      end

      if page_target && shift
        x = event.input.mouse.pos.x
        y = event.input.mouse.pos.y
        selection.geom.stop(x, y)
      end

      self.nav_target = false
      self.page_target = false
      self.shift = false unless event.shift
    end

    def on_click(event)
      if event.right.clicked
        p selection.inspect
        return
      end

      selection.action = { 2 => :word, 3 => :line, 4 => :all }[event.left.click_count]

      # if this is a fresh click
      # clear all selections
      if !shift && event.left.clicked
        selection.clear
        selection.geom.start(event.pos.x, event.pos.y)
        selection.geom.click_pos = [event.pos.x, event.pos.y]
      elsif shift && event.left.down
        selection.action = :collect
        selection.geom.stop(event.pos.x, event.pos.y)
        selection.geom!
      elsif selection.pos?
        selection.geom.clear
      end
    end

    def on_mouseup(event)
      if event.left.released && !shift
        # selection.pos!
        # selection.geom.click_pos = nil
      end
    end

    def on_hover(event)
      return unless selection.geom?
      
      if event.left.up
        selection.action = nil
        # by the time we switch to pos, positions should already be populated.
        selection.pos!
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
  end
end