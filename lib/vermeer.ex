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
      uptime: :os.system_time(:millisecond),
      count: 0,
      window: :wxWindow.getScreenPosition(frame),
      mouse_relative_position: {0.0, 0.0},
      particles: Enum.map(0..300, fn _ -> %Particle{position: {0,0,0}, velocity: {0,0,0}} end)
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

    new_particles = state.particles
                    |>Flow.from_enumerable(stages: 18)
                    |>Flow.map(fn particle -> VectorField.affect_particle(particle) end)
                    |>Enum.to_list

    # 直列化するとやや遅くなる
    #    new_particles = state.particles
    #    |>Enum.map(fn particle -> VectorField.affect_particle(particle) end)

    exec_time =   (:os.system_time(:millisecond) - state.uptime) / 1000
    IO.inspect state.count / exec_time

    new_state = Map.merge(state,
      %{
        count: state.count + 1,
        particles: new_particles,
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
    :gl.translatef(0, 0, -15)
#   :gl.rotatef(state.count ,0.0, 0.0, 1.0)
    particle_positions = Enum.map(state.particles,fn particle -> particle.position end )
    points(particle_positions,3)
    Enum.map(particle_positions,fn pos -> circle(0.05,32,pos,{1,1,1}) end)

    #near_points= cross_resolve( [[] | particle_positions])
    near_points= cross_resolve_parallel(particle_positions) |> Enum.reject(fn x -> is_nil(x) end)

    lines_positions = near_points |>  Enum.map(fn x -> Tuple.to_list(x) end) |> List.flatten
    lines(lines_positions,1)
    :ok
  end

  defp circle(radius,resolution,{x,y,z},{r,g,b}) do
    deg_to_rad = :math.pi() / 180
    :gl.'begin'(:gl_const.gl_polygon)
    :gl.color3f(r, g, b)
    Enum.map(0..(resolution + 1),
      fn n -> :gl.vertex3f(
                :math.cos((n * (360 / resolution ) * deg_to_rad)) * radius + x,
                :math.sin((n * (360 / resolution ) * deg_to_rad)) * radius + y,
                z)
      end)
    :gl.'end'()
  end

  defp points(positions,size) do
    :gl.pointSize(size)
    :gl.'begin'(:gl_const.gl_points)
    Enum.map(positions,
      fn {x,y,z} -> :gl.vertex3f(x,y,z)
      end)
    :gl.'end'()
  end

  defp lines(positions,size) do
    :gl.pointSize(size)
    :gl.'begin'(:gl_const.gl_lines)
    Enum.map(positions,
      fn {x,y,z} -> :gl.vertex3f(x,y,z)
      end)
    :gl.'end'()
  end

  defp circle(radius,resolution,{r,g,b}) do
    deg_to_rad = :math.pi() / 180
    :gl.'begin'(:gl_const.gl_polygon)
    :gl.color3f(r, g, b)
    Enum.map(0..(resolution + 1),
      fn x -> :gl.vertex3f(
                :math.cos((x * (360 / resolution ) * deg_to_rad)) * radius,
                :math.sin((x * (360 / resolution ) * deg_to_rad)) * radius,
                0.0)
      end)
    :gl.'end'()
  end

  defp quad(width,height,{r,g,b}) do
    :gl.'begin'(:gl_const.gl_triangles_strip)
    :gl.color3f(r, g, b)
    :gl.vertex3f(-width, -height, 0.0)
    :gl.vertex3f(width, -height, 0.0)
    :gl.vertex3f(-width, height, 0.0)
    :gl.vertex3f(width, height, 0.0)
    :gl.'end'()
  end

  defp render(%{canvas: canvas} = state) do
    draw(state)
    :wxGLCanvas.swapBuffers(canvas)
    :ok
  end

  defp random_position3d(count) do
    positions3d = Enum.map(0..count,fn x ->
      {:random.uniform(1000)/1000 - 0.5,
        :random.uniform(1000)/1000 - 0.5,
        :random.uniform(1000)/1000 - 0.5
      } end)
  end

  def cross_resolve( [result | []]), do: Enum.reject( result, fn x -> is_nil(x)end)

  def cross_resolve( [result | array] ) do
    [ a | next_array] = array

    #    near_points = next_array
    #                  |>Flow.from_enumerable(stages: 12)
    #                  |>Flow.map(fn b -> if distance3d(a,b) < 0.6 , do: {a,b}, else: nil end)
    #                  |>Enum.to_list

    #直列のほうが早い
    near_points = Enum.map( next_array, fn b -> if distance3d(a,b) < 0.6 , do: {a,b}, else: nil end)
    next_result = result ++ near_points
    cross_resolve([next_result | next_array])
  end

  def cross_resolve_parallel(array) do
    indexed_array= Enum.with_index(array)

        near_points = indexed_array
                      |>Flow.from_enumerable(stages: 18)
                      |>Flow.map( fn n -> cross_resolve_parallel2(n,indexed_array) end)
                      |>Enum.to_list
                      |> Enum.reject(fn x -> is_nil(x) end)
                      |> List.flatten
  end

  def cross_resolve_parallel2(target,array) do

    #elem(x,1) < elem(target,1) &&
    Enum.map(array , fn x ->
      if   distance3d(elem(target,0) , elem(x,0)) < 0.6,
                                 do: {elem(target,0),elem(x,0)},
                                 else: nil
    end
    )
  end


  def distance3d({x1,y1,z1},{x2,y2,z2}) do
    length3d({x1-x2,y1-y2,z1-z2})
  end

  defp length3d({x,y,z}) do
    :math.sqrt((:math.pow(x,2) + :math.pow(y,2) + :math.pow(z,2))) |> abs
  end
end