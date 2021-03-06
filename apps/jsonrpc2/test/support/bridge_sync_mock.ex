defmodule JSONRPC2.BridgeSyncMock do
  alias Blockchain.Account
  alias Blockchain.Block
  alias JSONRPC2.Response.Block, as: ResponseBlock
  alias JSONRPC2.Response.Receipt, as: ResponseReceipt
  alias JSONRPC2.Response.Transaction, as: ResponseTransaction
  alias JSONRPC2.Struct.EthSyncing
  alias MerklePatriciaTree.TrieStorage

  import JSONRPC2.Response.Helpers

  @behaviour JSONRPC2.Client

  use GenServer

  @impl true
  def connected_peer_count() do
    GenServer.call(__MODULE__, :connected_peer_count)
  end

  @impl true
  def last_sync_block_stats() do
    GenServer.call(__MODULE__, :get_last_sync_block_stats)
  end

  @impl true
  def block(hash_or_number, include_full_transactions) do
    GenServer.call(__MODULE__, {:get_block, hash_or_number, include_full_transactions})
  end

  @impl true
  def transaction_by_block_and_index(block_hash_or_number, index) do
    GenServer.call(
      __MODULE__,
      {:get_transaction_by_block_and_index, block_hash_or_number, index}
    )
  end

  @impl true
  def transaction_by_hash(transaction_hash) do
    GenServer.call(__MODULE__, {:get_transaction_by_hash, transaction_hash})
  end

  @impl true
  def block_transaction_count(block_hash_or_number) do
    GenServer.call(__MODULE__, {:get_block_transaction_count, block_hash_or_number})
  end

  @impl true
  def uncle_count(block_number_or_hash) do
    GenServer.call(__MODULE__, {:get_uncle_count, block_number_or_hash})
  end

  @impl true
  def starting_block_number do
    GenServer.call(__MODULE__, :get_starting_block_number)
  end

  @impl true
  def highest_block_number do
    GenServer.call(__MODULE__, :get_highest_block_number)
  end

  @impl true
  def code(address, block_number) do
    GenServer.call(__MODULE__, {:get_code, address, block_number})
  end

  @impl true
  def balance(address, block_number) do
    GenServer.call(__MODULE__, {:get_balance, address, block_number})
  end

  @impl true
  def transaction_receipt(transaction_hash) do
    GenServer.call(__MODULE__, {:get_transaction_receipt, transaction_hash})
  end

  @impl true
  def uncle(block_number_or_hash, index) do
    GenServer.call(__MODULE__, {:get_uncle, {block_number_or_hash, index}})
  end

  @impl true
  def storage(address, storage_key, block_number) do
    GenServer.call(__MODULE__, {:get_storage, address, storage_key, block_number})
  end

  @impl true
  def transaction_count(address, block_number) do
    GenServer.call(__MODULE__, {:get_transaction_count, address, block_number})
  end

  @impl true
  def last_sync_state() do
    GenServer.call(__MODULE__, :last_sync_state)
  end

  def set_trie(trie) do
    GenServer.call(__MODULE__, {:set_trie, trie})
  end

  def get_trie do
    GenServer.call(__MODULE__, :get_trie)
  end

  def set_connected_peer_count(connected_peer_count) do
    GenServer.call(__MODULE__, {:set_connected_peer_count, connected_peer_count})
  end

  def set_starting_block_number(block_number) do
    GenServer.call(__MODULE__, {:set_starting_block_number, block_number})
  end

  def set_highest_block_number(block_number) do
    GenServer.call(__MODULE__, {:set_highest_block_number, block_number})
  end

  def set_last_sync_block_stats(block_stats) do
    GenServer.call(__MODULE__, {:set_last_sync_block_stats, block_stats})
  end

  def put_block(block) do
    GenServer.call(__MODULE__, {:put_block, block})
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:connected_peer_count, _, state) do
    {:reply, state.connected_peer_count, state}
  end

  def handle_call(:get_highest_block_number, _, state) do
    {:reply, Map.get(state, :highest_block_number, 0), state}
  end

  def handle_call(:get_starting_block_number, _, state) do
    {:reply, Map.get(state, :starting_block_number, 0), state}
  end

  def handle_call({:set_trie, trie}, _, state) do
    {:reply, :ok, Map.put(state, :trie, trie)}
  end

  def handle_call(:get_trie, _, state) do
    {:reply, state.trie, state}
  end

  def handle_call({:set_connected_peer_count, connected_peer_count}, _, state) do
    {:reply, :ok, Map.put(state, :connected_peer_count, connected_peer_count)}
  end

  def handle_call({:set_highest_block_number, block_number}, _, state) do
    {:reply, :ok, Map.put(state, :highest_block_number, block_number)}
  end

  def handle_call({:set_starting_block_number, block_number}, _, state) do
    {:reply, :ok, Map.put(state, :set_starting_block_number, block_number)}
  end

  def handle_call({:put_block, block}, _, state = %{trie: trie}) do
    {:ok, {_, updated_trie}} = Block.put_block(block, trie, block.block_hash)
    updated_state = %{state | trie: updated_trie}

    {:reply, :ok, updated_state}
  end

  def handle_call(
        {:get_block, hash_or_number, include_full_transactions},
        _,
        state = %{trie: trie}
      ) do
    block =
      case Block.get_block(hash_or_number, trie) do
        {:ok, block} -> ResponseBlock.new(block, include_full_transactions)
        _ -> nil
      end

    {:reply, block, state}
  end

  def handle_call(
        {:get_transaction_by_block_and_index, block_hash_or_number, trx_index},
        _,
        state = %{trie: trie}
      ) do
    result =
      with {:ok, block} <- Block.get_block(block_hash_or_number, trie) do
        case Enum.at(block.transactions, trx_index) do
          nil -> nil
          transaction -> ResponseTransaction.new(transaction, block)
        end
      else
        _ -> nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_block_transaction_count, block_hash_or_number},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_hash_or_number, trie) do
        {:ok, block} ->
          block.transactions
          |> Enum.count()
          |> encode_quantity()

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_uncle_count, block_number_or_hash},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_number_or_hash, trie) do
        {:ok, block} ->
          block.ommers
          |> Enum.count()
          |> encode_quantity()

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_uncle, {block_hash_or_number, index}},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_hash_or_number, trie) do
        {:ok, block} ->
          case Enum.at(block.ommers, index) do
            nil ->
              nil

            ommer_header ->
              uncle_block = %Block{header: ommer_header, transactions: [], ommers: []}

              uncle_block
              |> Block.add_metadata(trie)
              |> ResponseBlock.new()
          end

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_code, address, block_number}, _, state = %{trie: trie}) do
    result =
      case Block.get_block(block_number, trie) do
        {:ok, block} ->
          block_state = TrieStorage.set_root_hash(trie, block.header.state_root)

          case Account.machine_code(block_state, address) do
            {:ok, code} -> encode_unformatted_data(code)
            _ -> nil
          end

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_balance, address, block_number}, _, state = %{trie: trie}) do
    result =
      case Block.get_block(block_number, trie) do
        {:ok, block} ->
          block_state = TrieStorage.set_root_hash(trie, block.header.state_root)

          case Account.get_account(block_state, address) do
            nil ->
              nil

            account ->
              encode_quantity(account.balance)
          end

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_transaction_by_hash, transaction_hash}, _, state = %{trie: trie}) do
    result =
      case Block.get_transaction_by_hash(transaction_hash, trie, true) do
        {transaction, block} -> ResponseTransaction.new(transaction, block)
        nil -> nil
      end

    {:reply, result, state}
  end

  def handle_call({:get_transaction_receipt, transaction_hash}, _, state = %{trie: trie}) do
    result =
      case Block.get_receipt_by_transaction_hash(transaction_hash, trie) do
        {receipt, transaction, block} -> ResponseReceipt.new(receipt, transaction, block)
        _ -> nil
      end

    {:reply, result, state}
  end

  def handle_call(
        {:get_storage, storage_address, storage_key, block_number},
        _,
        state = %{trie: trie}
      ) do
    result =
      case Block.get_block(block_number, trie) do
        {:ok, block} ->
          block_state = TrieStorage.set_root_hash(trie, block.header.state_root)

          case Account.get_storage(block_state, storage_address, storage_key) do
            {:ok, value} ->
              value
              |> :binary.encode_unsigned()
              |> encode_unformatted_data

            _ ->
              nil
          end
      end

    {:reply, result, state}
  end

  def handle_call({:get_transaction_count, address, block_number}, _, state = %{trie: trie}) do
    result =
      case Block.get_block(block_number, trie) do
        {:ok, block} ->
          block_state = TrieStorage.set_root_hash(trie, block.header.state_root)

          case Account.get_account(block_state, address) do
            nil ->
              nil

            account ->
              encode_quantity(account.nonce)
          end

        _ ->
          nil
      end

    {:reply, result, state}
  end

  def handle_call(:last_sync_state, _, state) do
    {:reply, state, state}
  end

  @spec handle_call(:get_last_sync_block_stats, {pid, any}, map()) ::
          {:reply, EthSyncing.output(), map()}
  def handle_call(:get_last_sync_block_stats, _, state) do
    {:reply, state.block_stats, state}
  end

  @spec handle_call(
          {:set_last_sync_block_stats, EthSyncing.input()},
          {pid, any},
          map()
        ) :: {:reply, :ok, map()}
  def handle_call({:set_last_sync_block_stats, block_stats}, _, state) do
    new_state = Map.put(state, :block_stats, block_stats)
    {:reply, :ok, new_state}
  end
end
