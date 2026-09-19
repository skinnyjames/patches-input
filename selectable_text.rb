class SelectableText < Hokusai::Block
  template <<-EOF
  [template]
    selectable
      text {
        @height_updated="update_height"
        :content="content"
        :size="size"
        :animate_selection="animate_selection"
        :color="color"
        :selection_color="selection_color"
        :selection_color_to="selection_color_to"
      }
  EOF

  uses(
    selectable: Hokusai::Blocks::Selectable,
    text: Hokusai::Blocks::Text,
  )
  
  def update_height(height)
    node.meta.set_prop(:height, height)
  end

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

  def render(canvas)
    @top = canvas.y

    yield canvas
  end
end