# Public: Input block, needs work
class Hokusai::Blocks::Input < Hokusai::Block
  template <<~EOF
  [template]
    vblock {
      @click="focus"
      :background="background"
    }
      text {
        :color="color"
        :content="model"
        :size="size"
        :padding="padding"
        :selection_color="selection_color"
        :selection_color_to="selection_color_to"
        :animate_selection="animate_selection"
        :copy_text="copy"
        @copy="on_copy"
        @selected="handle_selection"
        @keypress="handle_keypress"
        @keydown="handle_keydown"
        @height_updated="update_content_height"
      }
  EOF

  uses(
    clipped: Hokusai::Blocks::Clipped,
    scissor_end: Hokusai::Blocks::ScissorEnd,
    panel: Hokusai::Blocks::Panel,
    cursor: Hokusai::Blocks::Cursor,
    selectable: Hokusai::Blocks::Selectable,
    text: Hokusai::Blocks::Text,
    vblock: Hokusai::Blocks::Vblock,
  )

  computed! :model

  computed :background, default: nil, convert: Hokusai::Color
  computed :color, default: [33,33,33], convert: Hokusai::Color
  computed :selection_color, default: [233,233,233], convert: Hokusai::Color
  computed :selection_color_to, default: [0, 33, 233], convert: Hokusai::Color
  computed :animate_selection, default: false
  computed :cursor_color, default: [244,22,22], convert: Hokusai::Color
  computed :growable, default: false
  computed :size, default: 34, convert: proc(&:to_i)
  computed :tabsize, default: 2, convert: proc(&:to_i)
  computed :padding, default: Hokusai::Padding.new(0.0, 0.0, 0.0, 0.0), convert: Hokusai::Padding

  inject :selection
  
  attr_reader :timer
  attr_accessor :content, :buffer, :positions, :content_height, :shift, :copy

  def focus(event)
   node.meta.focus
  end
  
  def after_updated
    if model == ""
      selection.pos.cursor_index = nil
    end
  end

  def initialize(**args)
    super

    @copy = false
    @shift = false
    @content_height = 0.0
    @buffer = ""
    @timer = Hokusai::Timer.new
  end

  def whatever(event)
    node.meta.focus
  end

  def on_copy(text)
    Hokusai.copy(text)
    self.copy = false
  end

  def update_content_height(height)
    self.content_height = height
    node.meta.set_prop(:height, height)
  end

  def increment_cursor(selecting, times: 1)
    # selection.pos!

    selection.pos.move :right, selecting, times 
  end

  def decrement_cursor(selecting, times: 1)
    # selection.pos!

    selection.pos.move :left, selecting, times
  end

  def handle_keydown(event)
    return unless timer.elapsed(0.2)

    keypress_logic(event, :down)
  end

  def keypress_logic(event, type = :pressed)
    return unless node.meta.focused

    idx = selection.pos.cursor_index || 0
    insertidx = model.empty? ? 0 : idx + 1

    if selection.pos.cursor_index.nil?
      deleteidx = nil
    elsif selection.pos.cursor_index <= 0 && model.size.zero?
      deleteidx = nil
    elsif selection.pos.cursor_index <= 0
      deleteidx = -1
    elsif selection.pos.cursor_index.zero?
      deleteidx = -1
    else
      deleteidx = selection.pos.cursor_index - 1
    end
    
    if selection.pos.positions
      range = selection.pos.positions(false)
    else
      range = nil
    end
  
    self.shift = event.shift

    if event.printable?(type) && !event.super && !event.ctrl
      if range
        if model[range][-1] == "\n"
          model[range] = event.char + "\n"
        else
          model[range] = event.char
        end
        selection.pos.positions = nil
        selection.geom.clear
        selection.pos.cursor_index = range.begin
        # increment_cursor(false)
      # DONE
      elsif selection.pos.cursor_index
        model.insert(insertidx, event.char)
        selection.pos.cursor_index += 1 unless idx.zero? && model.size == 1
      end


      # why were we doing this?
      # if selection.pos.positions.nil?
      #   selection.action = :collect 
      #   p ["collect from input"]
      # end
    elsif event.symbol == :c && (event.ctrl || event.super)
      self.copy = true
    elsif event.symbol == :v && (event.ctrl || event.super)
      if text = Hokusai.paste
        if range
          model[range] = text
          selection.pos.positions = nil
          selection.geom.clear
          selection.pos.cursor_index = range.begin + text.size

        elsif selection.pos.cursor_index
          model.insert(selection.pos.cursor_index + 1, text)
          increment_cursor(false, times: text.size)
        end
      end
    elsif event.symbol == :tab
      chr = " " * tabsize

      if range
        if model[range][-1] == "\n"
          model[range] = chr + "\n"
        else
          model[range] = chr
        end
        selection.pos.positions = nil
        selection.geom.clear
        selection.pos.cursor_index = range.last
        # increment_cursor(false)
      # DONE
      elsif selection.pos.cursor_index
        model.insert(insertidx, chr)
        selection.pos.cursor_index += tabsize unless idx.zero? && model.size == 1
      end
    elsif event.symbol == :a && (event.ctrl || event.super)
      selection.action = :all
    elsif event.symbol == :enter
      if range
        model[range] = "\n"
        selection.pos.positions = nil
        selection.geom.clear
        selection.pos.cursor_index = range.begin + 1
        # increment_cursor(false)
      elsif selection.pos.cursor_index
        model.insert(selection.pos.cursor_index + 1, "\n")
        increment_cursor(false)
      end
    elsif event.symbol == :backspace
      if range

        model[range] = ""
        selection.pos.positions = nil
        selection.geom.clear
        if range.begin  - 1 <= 0
          selection.pos.cursor_index = -1
        else
          selection.pos.cursor_index = range.begin - 1
        end  
      elsif selection.pos.cursor_index
        if selection.pos.cursor_index >= 0
          model[selection.pos.cursor_index] = ""
          selection.pos.cursor_index = deleteidx
        end
      end
    elsif event.symbol == :right && selection.pos.cursor_index < model.size - 1
      increment_cursor(event.shift)
    elsif event.symbol == :left && selection.pos.cursor_index > -1
      decrement_cursor(event.shift)
    end
  end

  #
  # | 0 | 1 | 2 | 3 | 
  #   a   b   c   d
  #                 x - cursor
  #               x - cursor index
  #               x - insert index
  def handle_keypress(event)
    return if selection.pos.cursor_index.nil?
    
    keypress_logic(event)
    
    timer.reset
  end
end
