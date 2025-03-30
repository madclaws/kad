# Kad

**A DHT simulator based on Kademlia**

## Running


`iex --sname term1@localhost -S mix`

Inside the iex

```
iex(terminal1@localhost) Kad.minikad
```

In another terminal

`iex --sname term2@localhost -S mix`

```
iex(terminal2@localhost) Kad.connect_term

iex(terminal1@localhost) Kad.get()

iex(terminal1@localhost) Kad.put()
```

See the logs in terminal1 and do the operations in terminal2