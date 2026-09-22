require_relative "./wrap_stream"
require_relative "./scrollbar"
require_relative "./patches"
require_relative "./selectable"
require_relative "./text"
require_relative "./selectable_text"
require_relative "./panel"
require_relative "./input"

class Test < Hokusai::Block
  style <<-EOF
  [style]
  text {
    animate_selection: true;
    color: rgb(222,222,222);
    selection_color: rgb(236, 117, 42);
    selection_color_to: rgb(29,35,52);
    text_color: rgb(222,222,222);
    text_selection_color: rgb(79, 9, 66);
    text_selection_color_to: rgb(29,35,52);
    size: 24;
    padding: padding(0.0, 0.0, 0.0, 0.0);
  }
  input {
    size: 52;
    text_selection_color: rgb(199, 131, 187);
    text_selection_color_to: rgb(119, 141, 203);
  }
  bg {
    background: rgb(56, 50, 154);
  }
  EOF

  template <<-EOF
  [template]
    vblock { background="22,22,22"}
      panel { @keypress="on_keypress" }
        selectable { :vertical="true" }
          text { ...text :content="other" @copy="handle_copy" :copy_text="copy" }
          vblock { ...bg :height="okay_height" }
            text { ...text :content="content" @height_updated="okay" }

  EOF

  def on_keypress(event)
    if event.symbol == :c && (event.super || event.ctrl)
      self.copy = true
    end
  end
  
  def foo
    @foo ||= ""
  end

  def okay(height)
    @okay_height = height
  end

  def handle_copy(text)
    p text
    self.copy = false
  end

  def content
    @file ||= File.read("hp.md")
  end

  def other
    @other ||= begin
      f = File.read("panel.rb")
      f
    end
  end

  attr_accessor :copy, :okay_height

  def initialize(**args)
    @copy = false
    @okay_height = 0.0
    super
  end

  uses(
    hblock: Hokusai::Blocks::Hblock,
    vblock: Hokusai::Blocks::Vblock,
    selectable: Hokusai::Blocks::Selectable,
    panel: Hokusai::Blocks::Panel,
    input: Hokusai::Blocks::Input,
    text: Hokusai::Blocks::Text,
  )
end

Hokusai::Backend.run(Test) do |config|
  config.width = 700
  config.height = 500
  config.title = "input test"
  config.event_waiting = false
  config.draw_fps = true
  # config.accessibility do |accessibility_config|
  #   accessibility_config.model_path = "assets/models/ggml-tiny.bin"
  # end

  config.after_load do
    Hokusai.fonts.register "default", Hokusai::Backend::Font.from_ext("assets/OpenSans.ttf", 52)
    Hokusai.fonts.activate "default"
  end
end