module Hokusai::Blocks
  # Public: A text rendering component
  class Text < Hokusai::Block
    template <<-EOF
    [template]
      empty { 
        @mousedown="on_mousedown"
        @mouseup="on_mouseup"
      }
    EOF

    uses(empty: Hokusai::Blocks::Empty)

    computed! :content
    computed :static, default: false
    computed :font, default: nil
    computed :size, default: 20, convert: proc(&:to_i)
    computed :color, default: [22, 22, 22], convert: Hokusai::Color
    computed :padding, default: [0.0, 0.0, 0.0, 0.0], convert: Hokusai::Padding
    computed :selection_color, default: [183, 201, 229], convert: Hokusai::Color
    computed :selection_color_to, default: [183, 225, 229], convert: Hokusai::Color
    computed :animate_selection, default: true
    computed :copy_text, default: false
    
    inject :panel_offset
    inject :panel_height
    inject :panel_top
    inject :selection
  
    attr_accessor :counter, :copying, :last_width

    def initialize(**args)
      @counter = 0
      @last_width = 0.0
      @last_content = nil
      @copying = false
      @progress = 0
      
      super
    end

    def on_mousedown(event)
    
    end

    def on_mouseup(event)
      
    end

    def on_resize(canvas)
      @counter = 0
      @cache = nil
      @last_content = nil

      if selection
        selection.cursor = nil
      end
    end

    def panel?
      !panel_offset.nil?
    end

    def user_font
      font ? Hokusai.fonts.get(font) : Hokusai.fonts.active
    end

    def start_top(canvas)
      canvas.y + padding.top
    end

    def top
      offset + padding.top
    end

    def panel_height_or_canvas_height(canvas)
      panel_height || canvas.height
    end

    def cache(canvas)
      return @cache if counter >= 2 && (static || @last_content == content && @last_width == canvas.width)

      @last_width = canvas.width

      @cache = begin
        cache = Hokusai::Util::WrapCache.new
        y = start_top(canvas)

        off = selection&.offset_pos || 0
        stream = Hokusai::Util::WrapStream.new(canvas.width - padding.width, canvas.x, y, off) do |string, extra|
          if string == "\n"
            [size, size]
          end
          if w = user_font.measure_char(string, size)
            [w, size]
          else
            [user_font.measure(string, size).first, size]
          end
        end

        stream.on_text do |wrapped|
          cache << wrapped
        end
        stream.wrap(content, nil)
        stream.flush

        if (stream.y - canvas.y).zero?
          height = size
        else
          height = (stream.y - canvas.y + size).ceil
        end

        if selection
          selection.offset_pos = stream.offset_pos
        end
      
        node.meta.set_prop(:height, height + padding.height)
        emit("height_updated", height + padding.height)
        @last_content = content.dup

        cache
      end
    end

    def offset
      panel_offset || 0.0
    end

    def height(canvas)
      panel_height || canvas.height
    end

    def fshader
      <<-EOF
      #version 330
      in vec4 fragColor;
      in vec2 fragTexCoord;
      out vec4 finalColor;
      uniform sampler2D texture0;
      uniform vec4 from;
      uniform vec4 to;
      uniform float progress;

      void main() {
        vec4 texelColor = texture(texture0, fragTexCoord) * fragColor;

        finalColor.a = texelColor.a;
        finalColor.rgb = mix(from, to, progress).rgb;
      }
      EOF
    end

    def render(canvas)
      if content.nil? || content.empty?
        if selection && selection.selecting?
          selection.pos.cursor_index = -1
          selection.pos.positions = []
          selection.geom.cursor = [canvas.x + padding.left, top + padding.top, 0.5, size]
        end

        return yield canvas
      end

      token_cache = cache(canvas)
      tokens = token_cache.tokens_for(Hokusai::Canvas.new(canvas.width, height(canvas), canvas.x, top))

      # token selection
      if selection && (node.meta.focused)
        # set up for offset tracking
        selection.offset_y = offset
        if animate_selection && selection.geom?
          shader_begin do |command|
            command.fragment_shader = fshader
            command.uniforms = {
              "from" => [selection_color.to_shader_value, HP_SHADER_UNIFORM_VEC4], 
              "to" => [selection_color_to.to_shader_value, HP_SHADER_UNIFORM_VEC4],
              "progress" => [@progress, HP_SHADER_UNIFORM_FLOAT]
            }
          end
        end

        token_cache.selected_area_for_tokens(tokens, selection, padding: padding) do |rect|
          # y = rect.y + selection.diff
          rect(rect.x, rect.y, rect.width, rect.height) do |command|
            command.color = selection_color
          end
        end

        # emit("selected", copied) unless copied.nil?

        if copy_text
          copystuff = token_cache.selected_text(content, selection)

          Hokusai.copy(copystuff)
          emit("copy", copystuff)
        end

        if animate_selection && selection.geom?
          shader_end
        end
      end

      tokens.each do |wrapped|
        # draw text
        text(wrapped.text, wrapped.x + padding.left, wrapped.y + padding.top - offset || 0.0) do |command|
          command.color = color
          command.size = size
          if font
            command.font = user_font
          end
        end
      end

      self.counter += 1 if counter < 2

      if @back
        @progress -= 0.02
      else
        @progress += 0.02
      end

      if @progress >= 1 && !@back
        @back = true
      elsif @progress <= 0 && @back
        @progress = 0
        @back = false
      end

      # p [content[0..50], node.meta.focused]
      yield canvas
    end
  end
end
