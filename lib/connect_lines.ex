defmodule ConnectLines do

def get_edges( [result | []]), do: Enum.reject( result, fn x -> is_nil(x)end)

def get_edges( [result | array] ) do
  [ a | next_array] = array

  near_points = Enum.map( next_array, fn b -> if distance3d(a,b) < 1 , do: {a,b}, else: nil end)
  next_result = result ++ near_points
  get_edges([next_result | next_array])
end

def get_edges_parallel(array) do
  indexed_array = Enum.with_index(array)

  near_points = indexed_array
                |>Flow.from_enumerable(stages: 18)
                |>Flow.map( fn n -> sort_positions(n,indexed_array) end)
                |>Enum.to_list
                |>List.flatten
                |>Enum.reject(fn x -> is_nil(x) end)
end

def sort_positions(target,array) do
  Enum.map(array , fn x ->
    if elem(x,1) < elem(target,1) && distance3d(elem(target,0) , elem(x,0)) < 10,
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