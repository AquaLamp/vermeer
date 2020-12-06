defmodule Particle do
    defstruct position: {0,0,0},velocity: {0,0,0}

    def init_particles(count) do
        Enum.map(0..count,
        fn _ ->  %Particle{position: {:random.uniform(100)/100,:random.uniform(100)/100,:random.uniform(100)/100}, velocity: {0,0,0}} end
        )
    end

end
