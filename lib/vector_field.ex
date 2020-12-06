defmodule VectorField do
  def affect_particle(particle) do
    field_vel = curl_noise(particle.position)

    new_velocity = add3d(particle.velocity, field_vel) |> multiply3d({0.92, 0.92, 0.92})
    new_position = add3d(particle.position, multiply3d(new_velocity, {0.01, 0.01, 0.01}))

    %Particle{position: new_position, velocity: new_velocity}
  end

  def curl_noise({x, y, z} = pos) do
    multiply3d(pos, {3, 3, 3}) |> simplex_noise_delta3d |> multiply3d({0.1, 0.1, 0.1})
  end

  defp simplex_noise3d({x, y, z} = pos) do
    x_noise = :noise_simplex.raw(2, multiply3d(pos, {0.5, 0.5, 0.5} |> add3d({30, 30, 30})))
    y_noise = :noise_simplex.raw(3, multiply3d(pos, {0.5, 0.5, 0.5} |> add3d({30, 30, 30})))
    z_noise = :noise_simplex.raw(4, multiply3d(pos, {0.5, 0.5, 0.5} |> add3d({30, 30, 30})))
    {x_noise, y_noise, z_noise}
  end

  defp simplex_noise_delta3d({x, y, z} = pos) do
    dlt = 0.0001
    a = simplex_noise3d(pos)
    b = simplex_noise3d({x + dlt, y + dlt, z + dlt})

    {(elem(a, 0) - elem(b, 0)) / dlt, (elem(a, 1) - elem(b, 1)) / dlt,
     (elem(a, 2) - elem(b, 2)) / dlt}
  end

  defp random_add(n) do
    :random.uniform(10) / 100 + n
  end

  #  defp random_add3d({x,y,z}) do
  ##    {x,y,z}
  #    {:random.uniform(100)/100 + x,:random.uniform(100)/100 + y,:random.uniform(100)/100 + z}
  #  end

  def add3d({x1, y1, z1}, {x2, y2, z2}) do
    {x1 + x2, y1 + y2, z1 + z2}
  end

  def sub3d({x1, y1, z1}, {x2, y2, z2}) do
    {x1 - x2, y1 - y2, z1 - z2}
  end

  def multiply3d({x1, y1, z1}, {x2, y2, z2}) do
    {x1 * x2, y1 * y2, z1 * z2}
  end

  defp normalize3d({x, y, z}) do
    len = length3d({x, y, z})

    if len == 0 do
      {0, 0, 0}
    else
      {x / len, y / len, z / len}
    end
  end

  defp length3d({x, y, z}) do
    :math.sqrt(:math.pow(x, 2) + :math.pow(y, 2) + :math.pow(z, 2))
  end
end
