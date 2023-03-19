ExUnit.start(capture_log: false)

defmodule Doctester do
  use ExUnit.Case
  doctest Filters
end
