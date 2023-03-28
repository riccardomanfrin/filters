defmodule Filters do
  @moduledoc """
  Models a list of filters to apply to a collection (list) of data items
  """

  defmodule Filter do
    @moduledoc """
    Struct used to recevive responses from HTTP servers
    """

    @typedoc """
    Matches any sub token at any point in the string value,
    E.g. "The white rabbit" data matches "te rab" text filter value
    """
    @type text() :: :text
    @typedoc """
    Use this for exact matching across a list of well known
    (and limited amount of) items.
    """
    @type enum() :: :enum
    @typedoc """
    Use this to filter out data past the date expressed in the filter value.
    """
    @type date_from() :: :date_from
    @typedoc """
    Use this to filter out data exceeding the date expressed in the filter value.
    """
    @type date_to() :: :date_to
    @typedoc """
    Expresses a date formatted as "yyyy-mm-dd"
    """
    @type date_value :: String.t()
    @type filter_type :: text() | enum() | date_from() | date_to()
    @type value_type :: String.t() | date_value()
    @type key :: atom() | String.t()

    use TypedStruct

    typedstruct enforce: true do
      field(:filter_type, filter_type(), default: :text)
      field(:key, key())
      field(:value, value_type())
    end

    def new(t, k, v \\ nil),
      do:
        %Filter{filter_type: t, key: k, value: v}
        |> validate()

    def validate(%Filter{filter_type: t} = f)
        when t in [:text, :enum],
        do: f

    def validate(%Filter{filter_type: t, value: v} = f)
        when t in [:date_from, :date_to] do
      epoch = normalize(v)
      %Filter{f | value: epoch}
    end

    def equals(%Filter{filter_type: t1, key: k1}, %Filter{filter_type: t2, key: k2}),
      do: t1 == t2 and k1 == k2

    def match(data_item, %Filter{key: k} = filter) do
      case data_item[k] do
        nil -> false
        _ -> tmatch(data_item, filter)
      end
    end

    def tmatch(data_item, %Filter{filter_type: :text} = f), do: data_item[f.key] =~ f.value
    def tmatch(data_item, %Filter{filter_type: :enum} = f), do: data_item[f.key] == f.value

    def tmatch(data_item, %Filter{filter_type: :date_to} = f),
      do: normalize(data_item[f.key]) <= f.value

    def tmatch(data_item, %Filter{filter_type: :date_from} = f),
      do: normalize(data_item[f.key]) >= f.value

    def normalize(nil), do: nil

    def normalize(date) do
      with {:integer_check, false} <- {:integer_check, is_integer(date)},
           {:iso8601, {:ok, iso8601val}} <- {:iso8601, Date.from_iso8601(date)},
           {:diff, val} <- {:diff, Date.diff(iso8601val, ~D[1970-01-01])} do
        val * 3600 * 24
      else
        {:integer_check, true} ->
          date

        {:iso8601, _} ->
          date
          |> String.to_integer()
          |> normalize()

        _ ->
          raise("Invalid date format #{inspect(date)}")
      end
    end
  end

  @type filters_data :: list(%{Filter.key() => String.t()})
  @type logic :: :or | :and

  use TypedStruct

  typedstruct enforce: true do
    field(:logic, logic(), default: :and)
    field(:filters, list(%Filter{}), default: [])
  end

  @doc """
  Create a new set of filters
  """
  @spec new(logic()) :: Filters.t()
  def new(logic \\ :and, filters \\ []), do: %Filters{logic: logic, filters: filters}

  @doc """
  Add or update an existing filter in the list.
  Two filters cannot have the same `:filter_type` and `:key`.
  """
  def add_update(%Filters{} = fs, %Filter{} = f) do
    other_filters =
      case pop(fs, f) do
        {[_found], others} ->
          others

        {[], _} ->
          fs.filters

        somethingelse ->
          raise "Detected filter duplicates (by filter_type and key): #{inspect(somethingelse)}"
      end

    %Filters{fs | filters: [f | other_filters]}
  end

  @doc """
  Return a tuple with the found filter and the remaining ones

  Useful to drop a filter or to update it
  """
  @spec pop(Filters.t(), Filter.t()) :: {[Filter.t()] | [], list(Filter.t())}
  def pop(%Filters{} = fs, %Filter{filter_type: t, key: k}) do
    Enum.reduce(fs.filters, {[], []}, fn filter, {matched, unmatched} ->
      case filter.filter_type == t and filter.key == k do
        true -> {[filter | matched], unmatched}
        false -> {matched, [filter | unmatched]}
      end
    end)
  end

  @doc """
  Return a filter matching by `:filter_type` and `:key`
  """
  def get(%Filters{} = fs, %Filter{} = f) do
    Enum.find(fs.filters, nil, fn x -> Filter.equals(x, f) end)
  end

  @doc ~S"""
  Filter the provided data with a list of filters

  ## Examples

  ### Text filters

      iex> filters = Filters.new()
      ...> |> Filters.add_update(Filters.Filter.new(:text, :is, "liv"))
      iex> Filters.filter([
      ...>  %{type: "human",   is: "Philip J. Fry"},
      ...>  %{type: "robot",   is: "Bender Rodriguez"},
      ...>  %{type: "human",   is: "Turanga Leila"},
      ...>  %{type: "robot",   is: "R. Daneel Oliva"},
      ...>  %{type: "drink",   is: "Martini with an olive"},
      ...>  %{type: "actions", are: "eat, live, think"}
      ...>  ], filters)
      [
        %{type: "drink", is: "Martini with an olive"},
        %{type: "robot", is: "R. Daneel Oliva"}
      ]

  ### Enum filters

      iex> filters = Filters.new()
      ...> |> Filters.add_update(Filters.Filter.new(:enum, :type, "human"))
      iex> Filters.filter([
      ...>  %{type: "human", is: "Philip J. Fry"},
      ...>  %{type: "robot", is: "Bender Rodriguez"},
      ...>  %{type: "human", is: "Turanga Leila"},
      ...>  %{type: "humanoid", is: "R. Daneel Oliva"}
      ...>  ], filters)
      [
        %{type: "human", is: "Turanga Leila"},
        %{type: "human", is: "Philip J. Fry"}
      ]

  ### Date filters

      iex> filters = Filters.new()
      ...> |> Filters.add_update(Filters.Filter.new(:date_from, :birthday, "2042-11-12"))
      ...> |> Filters.add_update(Filters.Filter.new(:date_to,   :birthday, "2042-12-12"))
      iex> Filters.filter([
      ...>  %{birthday: "2042-12-11", of: "Bender Rodriguez"},
      ...>  %{birthday: "2042-11-11", of: "Philip J. Fry"},
      ...>  %{birthday: "2042-11-12", of: "Turanga Leila"},
      ...>  %{birthday: "2042-11-13", of: "Hubert Farnsworth"},
      ...>  %{birthday: "2042-12-12", of: "Amy Wong"},
      ...>  %{birthday: "2042-12-13", of: "Doctor Zoidberg"},
      ...>  %{birthday: "2042-12-12", of: "Hermes Conrad"}
      ...>  ], filters)
      [
        %{birthday: "2042-12-12", of: "Hermes Conrad"},
        %{birthday: "2042-12-12", of: "Amy Wong"},
        %{birthday: "2042-11-13", of: "Hubert Farnsworth"},
        %{birthday: "2042-11-12", of: "Turanga Leila"},
        %{birthday: "2042-12-11", of: "Bender Rodriguez"}
      ]

  ### Multiple filters (and logic)

      iex> filters = Filters.new()
      ...> |> Filters.add_update(Filters.Filter.new(:enum, :type, "human"))
      ...> |> Filters.add_update(Filters.Filter.new(:text, :is, "Leila"))
      iex> Filters.filter([
      ...>  %{hello: "world", type: "human", is: "Philip J. Fry"},
      ...>  %{hello: "world", type: "robot", is: "Bender Rodriguez"},
      ...>  %{hell: "world",  type: "human", is: "Turanga Leila"},
      ...>  %{hello: "word",  type: "humanoid", is: "R. Daneel Oliva"}
      ...>  ], filters)
      [
        %{hell: "world",  type: "human", is: "Turanga Leila"}
      ]

  ### Multiple filters (or logic)

      iex> filters = Filters.new(:or)
      ...> |> Filters.add_update(Filters.Filter.new(:enum, :type, "human"))
      ...> |> Filters.add_update(Filters.Filter.new(:text, :is, "Bender"))
      iex> Filters.filter([
      ...>  %{hello: "world", type: "human", is: "Philip J. Fry"},
      ...>  %{hello: "world", type: "robot", is: "Bender Rodriguez"},
      ...>  %{hell: "world",  type: "human", is: "Turanga Leila"},
      ...>  %{hello: "word",  type: "humanoid", is: "R. Daneel Oliva"}
      ...>  ], filters)
      [
        %{hell: "world",  type: "human", is: "Turanga Leila"},
        %{hello: "world", type: "robot", is: "Bender Rodriguez"},
        %{hello: "world", type: "human", is: "Philip J. Fry"}
      ]

  """
  @spec filter(filters_data(), Filters.t()) :: filters_data()
  def filter(data, %Filters{logic: logic, filters: filters}) do
    Enum.reduce(data, [], fn item, acc ->
      {inneracc, match, nomatch} =
        case logic do
          :and -> {[item], {:cont, [item]}, {:halt, []}}
          :or -> {[], {:halt, [item]}, {:cont, []}}
        end

      [
        Enum.reduce_while(filters, inneracc, fn filter, _ ->
          case Filter.match(item, filter) do
            true -> match
            false -> nomatch
          end
        end)
        | acc
      ]
    end)
    |> List.flatten()
  end

  @doc """
  Serialize a list of filters into URL query parameters

  ## Example

      iex> %Filters{
      ...>  filters: [
      ...>    %Filters.Filter{filter_type: :text, key: :genre, value: "industrial metal"},
      ...>    %Filters.Filter{filter_type: :text, key: :artist, value: "Dance With"}
      ...>  ],
      ...>  logic: :and
      ...> } |> Filters.filters_to_query() |> URI.decode()
      "logic=and&genre=text|industrial metal&artist=text|Dance With"

  """
  def filters_to_query(filters, opts \\ []) do
    {logic_key, separator, _} = getopts(opts)

    [
      "#{logic_key}=#{filters.logic}"
      | for %Filters.Filter{filter_type: t, key: k, value: v} <- filters.filters do
          "#{k}=#{t}#{separator}#{v}"
        end
    ]
    |> Enum.join("&")
    |> URI.encode()
  end

  @doc """
  Deserialize URL query parameters into a list of filters

  ## Example

      iex> "logic=and&genre=text%7Cindustrial%20metal&artist=text%7CDance%20With"
      ...> |> Filters.query_to_filters(keys: :atoms)
      %Filters{
        filters: [
          %Filters.Filter{filter_type: :text, key: :genre, value: "industrial metal"},
          %Filters.Filter{filter_type: :text, key: :artist, value: "Dance With"}
        ],
        logic: :and
      }
  """
  def query_to_filters(qp, opts \\ []) do
    {logic_key, separator, keys} = getopts(opts)

    filters =
      qp
      |> URI.decode()
      |> String.split("&")
      |> Enum.map(&String.split(&1, "="))

    [[_, logic]] = logicfilter = Enum.filter(filters, fn [k, _tv] -> logic_key == k end)
    filters = filters -- logicfilter

    logic =
      case logic do
        "and" -> :and
        "or" -> :or
      end

    filters =
      for [k, tv] <- filters do
        [t, v] = String.split(tv, separator)

        k =
          case keys do
            :atoms -> String.to_existing_atom(k)
            _ -> k
          end

        Filter.new(String.to_existing_atom(t), k, v)
      end

    Filters.new(logic, filters)
  end

  defp getopts(opts) do
    {
      Keyword.get(opts, :logic_key, "logic"),
      Keyword.get(opts, :separator, "|"),
      Keyword.get(opts, :keys, :strings)
    }
  end
end
