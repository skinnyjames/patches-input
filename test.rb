require_relative "./wrap_stream"
require_relative "./scrollbar"
require_relative "./patches"
require_relative "./selectable"
require_relative "./text"
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
  bg {
    background: rgb(22,22,22);
  }
  EOF

  template <<-EOF
  [template]
    hblock { ...bg }
      panel { @keypress="on_keypress" }
        selectable
          text { ...text :content="other" @copy="handle_copy" :copy_text="copy" }
  EOF

  def on_keypress(event)
    if event.symbol == :c && (event.super || event.ctrl)
      self.copy = true
    end
  end

  def handle_copy(text)
    p text
    self.copy = false
  end

  def content
    @file ||= File.read("hp.md")
  end

  def other
    @other ||= File.read("panel.rb")
  end

  attr_accessor :copy

  def initialize(**args)
    @copy = false
    super
  end

  # register_voice :test do |voice|
  #   voice.build_action ".*" do |builder|
  #     builder.on_match do |str|
  #       @file << str
  #       Hokusai.speak(str)
  #       "yeah buddy"
  #     end
  #   end
  # end

  uses(
    hblock: Hokusai::Blocks::Hblock,
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
  # config.accessibility do |accessibility_config|
  #   accessibility_config.model_path = "assets/models/ggml-tiny.bin"
  # end

  config.after_load do
    Hokusai.fonts.register "default", Hokusai::Backend::Font.from_ext("assets/OpenSans.ttf", 24)
    Hokusai.fonts.activate "default"
  end
end