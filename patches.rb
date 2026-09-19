# Public: Represents a blinking cursor
class Hokusai::Blocks::Cursor < Hokusai::Block
  template <<~EOF
    [template]
      virtual
  EOF

  DEFAULT_COLOR = [255,0,0,244]

  computed :x, default: 0.0
  computed :y, default: 0.0
  computed :show, default: false
  computed :speed, default: 0.5
  computed :cursor_width, default: 2.0
  computed :cursor_height, default: 0.0
  computed :color, default: DEFAULT_COLOR, convert: Hokusai::Color

  def initialize(**args)
    @active = false
    @iteration = 0

    super
  end

  def before_updated
    frames = speed * 30

    @active = @iteration < frames

    if @iteration >= 30
      @iteration = 0
    else
      @iteration += 1
    end
  end

  def render(canvas)    
    if show
      draw do
        if @active
          rect(x, y, cursor_width, cursor_height) do |command|
            command.color = color
          end
        end
      end
    end

    yield canvas
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

module Hokusai
  class Keyboard
    attr_accessor :shift, :control, :super, :alt
    attr_reader :keys, :pressed, :released, :down

    # Public: Is the pressed key printable?
    # 
    # Returns boolean
    def printable?
      [
        :space, :tab, :apostrophe, :comma, :minus, :period,
        :slash, :right_bracket, :left_bracket, :grave,
        :zero, :one, :two, :three, :four, :five, :six, 
        :seven, :eight, :nine, :semicolon, 
        :a, :b, :c, :d, :e, :f, :g, :h,
        :i, :j, :k, :l, :m, :n, :o, :p, :q, :r, 
        :s, :t, :u, :v, :w, :x, :y, :z,
      ].include?(symbol)
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

# Public: Measures it's children and emits the width and height
class Hokusai::Blocks::Dynamic < Hokusai::Block
  template <<~EOF
    [template]
      slot
  EOF

  computed :reverse, default: false
  computed :vertical, default: true

  def before_updated
    width, height = compute_size

    emit("size_updated", width, height)
  end

  def on_resize(_)
    compute_size
  end

  def on_mounted
    compute_size
  end

  def compute_size
    h = 0.0
    w = 0.0

    if vertical
      children.each do |block|
        h += block.node.meta.get_prop?(:height)&.to_f || 0.0
        w += block.node.meta.get_prop?(:width)&.to_f || 0.0
      end
    else
      h = children.map {|block| block.node.meta.get_prop?(:height)&.to_f || 0.0 }.max
    end

    node.meta.set_prop(:height, h)

    [w, h]
  end

  def render(canvas)
    canvas.vertical = vertical
    canvas.reverse = (reverse == true || reverse == "true")

    yield canvas
  end
end