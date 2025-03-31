# Kad

**A DHT simulator based on Kademlia**

Kad is a Distributed Hash Table (DHT) simulator based on [Kademlia protocol](https://en.wikipedia.org/wiki/Kademlia#:~:text=Kademlia%20is%20a%20distributed%20hash,of%20information%20through%20node%20lookups.). The main purpose is to understand Kademlia protocol and as a sandbox for further experiments around DHTs and Kademlia.

## How it works

- Nodes in a network is represented by Erlang processes, which helps us to simulate 1000s of nodes. Each process will behave like a kademlia node with its own routing table and other metadata.

- Instead of RPC calls, we use Process messaging.

## Running

### Prerequisite

Install [Erlang and Elixir](https://thinkingelixir.com/install-elixir-using-asdf/)

`git clone git@github.com:madclaws/kad.git`

There are 2 modes of simulation, 

### minikad

Minikad works in 6-bit space, ie the keys and the nodes share same 6-bit space, so keys can be 
numbers from 0-64, likewise nodes. This mode is good for learning how Kademlia works. Its easier to understand, but beware of conflict in the bit-space.

### megakad

Megakad works in 160-bit space, just like large scale kademlia network, ie the keys and the nodes share same 160-bit space. Given the large bitspace we don't have to worry about conflict btw nodes and keys

Upon starting the sim, it also opens erlang's observer for further observability into the nodes and states.

![observer](assets/observer.gif "observer")

Open a terminal and run

`iex --sname term1@localhost -S mix`

From the iex shell

```sh
iex(terminal1@localhost) Kad.minikad
```

OR 

```sh
iex(terminal1@localhost) Kad.megakad
```

In another terminal

`iex --sname term2@localhost -S mix`

```sh
# connect_term, connects 2 separate terminals using distributed Elixir

iex(terminal2@localhost) Kad.connect_term

# This example is running minikad on first terminal
iex(terminal1@localhost) Kad.put(:node_50, 55, "apple")

iex(terminal1@localhost) Kad.get(:node_2, 55) # "apple"
```

See the logs in terminal1 and do the operations in terminal2

In the above example we add the KV pair (55, "apple") in node_50
And we still get the value of 55, even if query from node_2

## Tests

`mix test`
