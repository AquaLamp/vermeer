defmodule PointNetwork do

  def  curl_noise({x,y,z} = pos) do
    e = 0.0009765625
    e2 = 2.0 * e

    dx = { e   , 0.0 , 0.0 }
    dy = { 0.0 , e   , 0.0 }
    dz = { 0.0 , 0.0 , e   }

    p_x0 = simplex_noise3d( sub3d(pos, dx ));
    p_x1 = simplex_noise3d( add3d(pos, dx ));
    p_y0 = simplex_noise3d( sub3d(pos, dy) );
    p_y1 = simplex_noise3d( add3d(pos, dy ));
    p_z0 = simplex_noise3d( sub3d(pos, dz) );
    p_z1 = simplex_noise3d( add3d(pos, dz) );

    result_x = elem(p_y1,2) - elem(p_y0,2) - elem(p_z1,1) + elem(p_z0,1)
    result_y = elem(p_z1,0) - elem(p_z0,0) - elem(p_x1,2) + elem(p_x0,2)
    result_z = elem(p_x1,1) - elem(p_x0,1) - elem(p_y1,0) + elem(p_y0,0)

    multiply3d(normalize3d( {result_x/e2 , result_y/e2 , result_z/e2 } ), {0.1,0.1,0.1})
  end

  defp simplex_noise3d({x,y,z} = pos) do
    x_noise = :noise_simplex.raw(:random.uniform(10),random_add3d(pos))
    y_noise = :noise_simplex.raw(:random.uniform(10),{random_add(y),random_add(z),random_add(x)})
    z_noise = :noise_simplex.raw(:random.uniform(10),{random_add(z),random_add(x),random_add(y)})
    {x_noise,y_noise,z_noise}
  end

  defp random_add(n) do
    :random.uniform(10)/100 + n
  end

  defp random_add3d({x,y,z}) do
#    {x,y,z}
    {:random.uniform(100)/100 + x,:random.uniform(100)/100 + y,:random.uniform(100)/100 + z}
  end
  def add3d({x1,y1,z1},{x2,y2,z2}) do
    {x1+x2,y1+y2,z1+z2}
  end

  def sub3d({x1,y1,z1},{x2,y2,z2}) do
    {x1-x2,y1-y2,z1-z2}
  end

  def multiply3d({x1,y1,z1},{x2,y2,z2}) do
    {x1*x2,y1*y2,z1*z2}
  end

  defp normalize3d({x,y,z}) do
    len = length3d({x,y,z})

    if len == 0 do
     {0,0,0}
    else
    {x/len, y/len,z /len}
    end

  end

  defp length3d({x,y,z}) do
    :math.sqrt(:math.pow(x,2) + :math.pow(y,2) + :math.pow(z,2))
  end

end