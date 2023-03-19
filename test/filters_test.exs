defmodule FiltersTest do
  use ExUnit.Case

  describe "Filters" do
    test "Create Example" do
      filters = %Filters{}
      assert filters == %Filters{filters: [], logic: :and}
      f1 = Filters.Filter.new(:text, :hello, "world")
      f2 = Filters.Filter.new(:enum, :on, "time")
      f3 = Filters.Filter.new(:enum, :off, "guard")

      filters =
        filters
        |> Filters.add_update(f1)
        |> Filters.add_update(f2)
        |> Filters.add_update(f3)

      assert filters = %Filters{
               filters: [
                 %Filters.Filter{filter_type: :enum, key: :off, value: "guard"},
                 %Filters.Filter{filter_type: :enum, key: :on, value: "time"},
                 %Filters.Filter{filter_type: :text, key: :hello, value: "world"}
               ],
               logic: :and
             }
    end
  end
end
