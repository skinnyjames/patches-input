require_relative "./wrap_stream"
require_relative "./scrollbar"
require_relative "./patches"
require_relative "./selectable"
require_relative "./text"
require_relative "./selectable_text"
require_relative "./panel"
require_relative "./input"

class Slot < Hokusai::Block
  template <<-EOF
  [template]
    slot
  EOF
end

class TodoList < Hokusai::Block
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
    size: 23;
    padding: padding(0.0, 0.0, 0.0, 0.0);
  }
  input {
    text_selection_color: rgb(199, 131, 187);
    text_selection_color_to: rgb(119, 141, 203);
  }
  bg {
    background: rgb(56, 50, 154);
  }

  cursor {
    cursor_color: rgb(222,222,222);
  }

  formInput {
    height: 30.0;
    padding: padding(0.0, 0.0, 0.0, 0.0);
    outline: outline(0.0, 0.0, 1.0, 0.0);
    outline_color: rgb(222,222,222);
    cursor: "pointer";
  }

  header {
    background: rgb(39, 28, 60);
    height: 34.0;
  }

  button {
    content: "Add Todo";
    size: 20;
    color: rgb(222,222,222);
  }
  EOF

  # template <<-EOF
  # [template]
  #   vblock { background="22,22,22"}
  #     hblock { ...formInput :height="32.0"}
  #       selectable { ...cursor :height="30.0" }
  #         input {...formInput :height="30.0"  :model="todo_form"  }
  #       vblock { @click="todo_add" :width="100.0" }
  #         text { content="Add" :size="18" color="222,222,222" }
  #     panel
  #       selectable
  #         [for="todo in todos"]
  #           text { ...text :key="todo" :content="todo" }
  # EOF

  template do
    child(Hokusai::Blocks::Vblock) do 
      child(Hokusai::Blocks::Hblock) do
        merge_styles "header"

        child(Hokusai::Blocks::Selectable) do
          child(Hokusai::Blocks::Input) do
            merge_styles "formInput", "input"
            prop :model do
              todo_form
            end
          end
        end

        child(Hokusai::Blocks::Vblock) do
          static "width", "170.0"

          on :click do |event|
            p "click"
            todo_add(event)
          end
    
          child(Hokusai::Blocks::Text) do
            merge_styles "button"
          end
        end
      end

      child(Hokusai::Blocks::Panel) do
        prop :background do
          Hokusai::Color.new(22,22,22)
        end
        
        child(Hokusai::Blocks::Selectable) do
          each_child(Hokusai::Blocks::Text, :todos) do |todo|
            merge_styles "text"

            prop :key do
              todo.value
            end

            prop :content do
              todo.value
            end
          end
        end
      end
    end
  end

  attr_accessor :todos, :copy, :todo_form

  def initialize(**args)
    @copy = false
    @todos = %w[]
    super
  end

  def vertical
    true
  end

  def todo_form
    @todo_form ||= ""
  end

  def todo_add(event)
    return if todo_form.empty?

    @todos << @todo_form.dup
    @todo_form = ""
  end

  # uses(
  #   hblock: Hokusai::Blocks::Hblock,
  #   vblock: Hokusai::Blocks::Vblock,
  #   selectable: Hokusai::Blocks::Selectable,
  #   panel: Hokusai::Blocks::Panel,
  #   input: Hokusai::Blocks::Input,
  #   text: Hokusai::Blocks::Text,
  #   dynamic: Hokusai::Blocks::Dynamic,
  # )
end

Hokusai::Backend.run(TodoList) do |config|
  config.width = 500
  config.height = 700
  config.title = "input test"
  config.event_waiting = false
  # config.draw_fps = true
  # config.accessibility do |accessibility_config|
  #   accessibility_config.model_path = "assets/models/ggml-tiny.bin"
  # end

  config.after_load do
    Hokusai.fonts.register "default", Hokusai::Backend::Font.from_ext("assets/NotoSans.ttf", 36)
    Hokusai.fonts.activate "default"
  end
end