require_relative "./text"

# Public: Input block, needs work
class Hokusai::Blocks::Input < Hokusai::Block
  template <<~EOF
  [template]
    panel
      vblock {
        @click="start_selection"
        @hover="update_selection"
        :height="content_height"
      }
        text {
          :color="text_color"
          :content="model"
          :size="size"
          :padding="padding"
          :selection_color="text_selection_color"
          :selection_color_to="text_selection_color_to"
          :animate_selection="animate_selection"
          :copy_text="copy"
          @copy="on_copy"
          @selected="handle_selection"
          @keypress="handle_keypress"
          @height_updated="update_content_height"
          @click="update_click_position"
        }
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
    panel: Hokusai::Blocks::Panel,
    cursor: Hokusai::Blocks::Cursor,
    selectable: Hokusai::Blocks::Selectable,
    text: Hokusai::Blocks::Text,
    vblock: Hokusai::Blocks::Vblock,
  )

  computed! :model

  computed :text_color, default: [33,33,33], convert: Hokusai::Color
  computed :text_selection_color, default: [233,233,233], convert: Hokusai::Color
  computed :text_selection_color_to, default: [0, 33, 233], convert: Hokusai::Color
  computed :animate_selection, default: false
  computed :cursor_color, default: [244,22,22], convert: Hokusai::Color
  computed :growable, default: false
  computed :size, default: 34, convert: proc(&:to_i)
  computed :padding, default: Hokusai::Padding.new(0.0, 0.0, 0.0, 0.0), convert: Hokusai::Padding

  attr_reader :selection
  attr_accessor :content, :buffer, :positions, :content_height, :shift, :copy

  provide :selection, :selection

  def initialize(**args)
    super

    @copy = false
    @shift = false
    @content_height = 0.0
    @buffer = ""
    @cursor = nil
    @selection = Hokusai::Util::Selection.new
  end

  def on_copy(text)
    Hokusai.copy(text)
    self.copy = false
  end

  def update_content_height(height)
    self.content_height = height
  end

  def update_click_position(event)
    selection.geom!
    if shift
      selection.geom.stop(event.pos.x, event.pos.y)
    else
      selection.geom.set_click_pos(event.pos.x, event.pos.y)
    end
  end

  def update_height(value)
    # node.meta.set_prop(:height, value)

    # emit("height_updated", value)
  end

  def handle_selection(copy)
    # puts [copy.inspect]
    # return if copy.nil?

    # @cursor = copy.cursor
  end

  def increment_cursor(selecting, times: 1)
    selection.pos!

    selection.pos.move :right, selecting, times 
  end

  def decrement_cursor(selecting, times: 1)
    selection.pos!

    selection.pos.move :left, selecting, times
  end

  def handle_keypress(event)
    range = (selection.pos.positions.first..selection.pos.positions.last)
    self.shift = event.shift

    if event.printable? && !event.super && !event.ctrl
      if selection.pos.positions.size > 0
        if model[range][-1] == "\n"
          model[range] = event.char + "\n"
        else
          model[range] = event.char
        end
        selection.pos.positions = []
        selection.geom.clear
        selection.pos.cursor_index = range.begin - 1
        increment_cursor(false)
      elsif selection.pos.cursor_index
        model.insert(selection.pos.cursor_index + 1, event.char)
        increment_cursor(false)
      end
    elsif event.symbol == :c && (event.ctrl || event.super)
      self.copy = true
    elsif event.symbol == :v && (event.ctrl || event.super)
      if text = Hokusai.paste
        if selection.pos.positions.size > 0
          model[range] = text
          selection.pos.positions = []
          selection.geom.clear
          selection.pos.cursor_index = range.begin + text.size

        elsif selection.pos.cursor_index
          model.insert(selection.pos.cursor_index + 1, text)
          increment_cursor(false, times: text.size)
        end
      end
    elsif event.symbol == :enter
      if selection.pos.positions.size > 0
        model[range] = "\n"
        selection.pos.positions = []
        selection.geom.clear
        selection.pos.cursor_index = range.begin + 1
        # increment_cursor(false)
      elsif selection.pos.cursor_index
        model.insert(selection.pos.cursor_index + 1, "\n")
        increment_cursor(false)
      end
    elsif event.symbol == :backspace
      if selection.pos.positions.size > 0

        model[range] = ""
        selection.pos.positions = []
        selection.geom.clear
        selection.pos.cursor_index = range.begin + 1

        decrement_cursor(false) if selection.pos.cursor_index >= model.size
  
      elsif selection.pos.cursor_index
        model[selection.pos.cursor_index] = ""
        decrement_cursor(false)
      end
    elsif event.symbol == :right && selection.pos.cursor_index < model.size - 1
      increment_cursor(event.shift)
    elsif event.symbol == :left && selection.pos.cursor_index > -1
      decrement_cursor(event.shift)
    end

    # puts ["model", model, selection.pos.cursor_index].inspect
  end

  def start_selection(event)
    if !shift && event.left.down #&& !selection.geom.active?
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
