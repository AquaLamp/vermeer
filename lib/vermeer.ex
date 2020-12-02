defmodule Vermeer do
  @behaviour :wx_object
  use Bitwise

  @title 'Elixir OpenGL'
  @size {600, 600}

  @count 1

  #######
  # API #
  #######
  def start_link() do
    :wx_object.start_link(__MODULE__, [], [])
  end

  #################################
  # :wx_object behavior callbacks #
  #################################
  def init(config) do
    wx = :wx.new(config)
    frame = :wxFrame.new(wx, :wx_const.wx_id_any, @title, [{:size, @size}])
    :wxWindow.connect(frame, :close_window)
    :wxFrame.show(frame)

    opts = [{:size, @size}]
    gl_attrib = [{:attribList, [:wx_const.wx_gl_rgba,
      :wx_const.wx_gl_doublebuffer,
      :wx_const.wx_gl_min_red, 8,
      :wx_const.wx_gl_min_green, 8,
      :wx_const.wx_gl_min_blue, 8,
      :wx_const.wx_gl_depth_size, 24, 0]}]
    canvas = :wxGLCanvas.new(frame, opts ++ gl_attrib)

    :wxGLCanvas.connect(canvas, :size)
    :wxWindow.reparent(canvas, frame)
    :wxGLCanvas.setCurrent(canvas)
    setup_gl(canvas)

    # Periodically send a message to trigger a redraw of the scene
    timer = :timer.send_interval(1, self(), :update)



    {frame,
      %{canvas: canvas,
      timer: timer,
      count: 0,
      window: :wxWindow.getScreenPosition(frame),
      mouse_relative_position: {0.0, 0.0}
      }
    }
  end

  def code_change(_, _, state) do
    {:stop, :not_implemented, state}
  end

  def handle_cast(msg, state) do
    IO.puts "Cast:"
    IO.inspect msg
    {:noreply, state}
  end

  def handle_call(msg, _from, state) do
    IO.puts "Call:"
    IO.inspect msg
    {:reply, :ok, state}
  end

  def handle_info(:stop, state) do
    :timer.cancel(state.timer)
    :wxGLCanvas.destroy(state.canvas)
    {:stop, :normal, state}
  end

  def handle_info(:update, state) do
    :wx.batch(fn -> render(state) end)

    {window_width, window_height} = :wxWindow.getClientSize(state.canvas)
    {window_pos_x,window_pos_y} = :wxWindow.getScreenPosition(state.canvas)
    {mouse_pos_x,mouse_pos_y} = :wx_misc.getMousePosition
    mouse_relpos_x =  (mouse_pos_x - window_pos_x) / window_width - 0.5
    mouse_relpos_y =  (mouse_pos_y - window_pos_y) / window_height - 0.5

    new_state = Map.merge(state,
      %{
        count: state.count + 1,
         window: {window_pos_x,window_pos_y},
         mouse_position: :wxWindow.clientToScreen(state.canvas,:wx_misc.getMousePosition),
         mouse_relative_position: {mouse_relpos_x, mouse_relpos_y}
      })


    {:noreply, new_state}
  end

  # Example input:
  # {:wx, -2006, {:wx_ref, 35, :wxFrame, []}, [], {:wxClose, :close_window}}
  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
    {:stop, :normal, state}
  end

  def handle_event({:wx, _, _, _, {:wxSize, :size, {width, height}, _}}, state) do
    if width != 0 and height != 0 do
      resize_gl_scene(width, height)
    end
    {:noreply, state}
  end

  def terminate(_reason, state) do
    :wxGLCanvas.destroy(state.canvas)
    :timer.cancel(state.timer)
    :timer.sleep(300)
  end

  #####################
  # Private Functions #
  #####################
  defp setup_gl(win) do
    {w, h} = :wxWindow.getClientSize(win)
    resize_gl_scene(w, h)
    :gl.shadeModel(:gl_const.gl_smooth)
    :gl.clearColor(0.0, 0.0, 0.0, 0.0)
    :gl.clearDepth(1.0)
    :gl.enable(:gl_const.gl_depth_test)
    :gl.depthFunc(:gl_const.gl_lequal)
    :gl.hint(:gl_const.gl_perspective_correction_hint, :gl_const.gl_nicest)
    :ok
  end

  defp resize_gl_scene(width, height) do
    :gl.viewport(0, 0, width, height)
    :gl.matrixMode(:gl_const.gl_projection)
    :gl.loadIdentity()
    :glu.perspective(45.0, width / height, 0.1, 100.0)
    :gl.matrixMode(:gl_const.gl_modelview)
    :gl.loadIdentity()
    :ok
  end

  defp draw(state) do
    {x,y} = state.mouse_relative_position
    :gl.clear(Bitwise.bor(:gl_const.gl_color_buffer_bit, :gl_const.gl_depth_buffer_bit))
    :gl.loadIdentity()
    :gl.translatef(x*8, y*-8, -10.0)
    :gl.rotatef(state.count ,0.0, 0.0, 1.0)
    :gl.'begin'(:gl_const.gl_triangles)
    :gl.vertex3f(0.0, 1.0, 0.0)
    :gl.vertex3f(0.86602540378,-0.5, 0.0)
    :gl.vertex3f(-0.86602540378,-0.5, 0.0)
    :gl.'end'()
    :ok
  end

  defp render(%{canvas: canvas} = state) do
    IO.inspect state
    draw(state)
    :wxGLCanvas.swapBuffers(canvas)
    :ok
  end

  def resolve( [result | []]), do: result

  def resolve( [result | array] ) do
    IO.inspect result

    [target | next_array] = array
    next_result = result ++ Enum.map( next_array, fn x -> target <> x end)
    resolve([next_result | next_array])
  end
end