defmodule Anoma.Node.Examples.ENode do
  use TypedStruct

  import ExUnit.Assertions

  alias __MODULE__
  alias Anoma.Node.Examples.ERegistry
  alias Anoma.Crypto.Id

  require Logger

  ############################################################
  #                    Context                               #
  ############################################################

  typedstruct do
    @typedoc """
    I am the state of a TCP listener.

    My fields contain information to listen for TCP connection with a remote node.

    ### Fields
    - `:node_id`    - The key of this router. This value is used to announce myself to other
    - `:pid`        - the pid of the supervision tree.
    - `:tcp_ports`  - The ports on which the node is listening for connections.
    """
    field(:node_id, Id.t())
    field(:pid, pid())
    field(:tcp_ports, [integer()], default: [])
  end

  ############################################################
  #                  Public API                              #
  ############################################################

  @table_name :enode_table

  @doc """
  I initialize the ETS table to keep track of creates nodes.

  My only reason for existence is to keep track of the nodes that are created in the system and their
  GRPC ports.
  """
  def initialize_ets() do
    unless @table_name in :ets.all() do
      :ok
      :ets.new(@table_name, [:set, :protected, :named_table])
    end

    @table_name
  end

  @doc """
  I start a new node given a node id and returns its process id.

  When a node is started, I put its ENode struct in an ETS table for later retrieval.

  When a node is already spawned, I lookup the ENode struct in the ETS table.
  Some meta data (in particular, the GRPC port) is only available when the node is started
  so I fetch that data from the ETS table.
  """
  @spec start_node(Id.t()) :: ENode.t() | {:error, :failed_to_start_node}
  def start_node(opts \\ []) do
    initialize_ets()

    opts =
      Keyword.validate!(opts, node_id: Examples.ECrypto.londo())

    enode =
      case Anoma.Supervisor.start_node(opts) do
        {:ok, pid} ->
          enode = %ENode{node_id: opts[:node_id], pid: pid, tcp_ports: []}
          :ets.insert(@table_name, {pid, enode})

          enode

        {:error, {:already_started, pid}} ->
          case :ets.lookup(@table_name, pid) do
            [{_, enode}] ->
              enode

            _ ->
              enode = %ENode{node_id: opts[:node_id], pid: pid, tcp_ports: []}
              :ets.insert(@table_name, {pid, enode})
              enode
          end

        {:error, _} ->
          {:error, :failed_to_start_node}
      end

    case enode do
      {:error, _} ->
        enode

      enode ->
        assert ERegistry.process_registered?(enode.node_id, :tcp_supervisor)
        assert ERegistry.process_registered?(enode.node_id, :proxy_supervisor)
        enode
    end
  end

  @doc """
  I stop a node and assert that's is gone.
  """
  @spec stop_node(ENode.t()) :: :ok
  def stop_node(node) do
    Supervisor.stop(node.pid)

    refute ERegistry.process_registered?(node.node_id, :tcp_supervisor)
    refute ERegistry.process_registered?(node.node_id, :proxy_supervisor)
    :ok
  end

  @doc """
  I kill all the nodes in the vm.
  """
  @spec kill_all_nodes() :: :ok
  def kill_all_nodes() do
    Anoma.Node.NodeSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_, pid, _, _} -> Supervisor.stop(pid) end)
  end
end