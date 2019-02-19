## Build Multi-Host Network (BMHN)

This Fork is based on the original [wahabjawed/Build-Multi-Host-Network-Hyperledger](https://github.com/wahabjawed/Build-Multi-Host-Network-Hyperledger) repository.

It's been updated to work with 2 Organisations instead of one.

The directions for using the original 1 Org are documented at wahabjawed's article at Medium.
["Hyperledger Fabric on Multiple Hosts"](https://medium.com/@wahabjawed/hyperledger-fabric-on-multiple-hosts-a33b08ef24f)

### Changes in this repo.

#### Network Topology

So the network that we are going to build will have the following below components. For this example we are using two Virtualbox guest hosts with 2 network interfaces lets say (vm0 and vm1):

**vm0**

* A Certificate Authority (CA) 
* An Orderer
* 1 PEER (peer0) Org1 on 
* 1 PEER (peer1) Org1 on 

**vm1**

* 1 PEER (peer0) Org2
* CLI (can connect to Org1 or Org2)

##### Network graph descriptor


```
      NAT                  NAT
       +                    +
       |                    |
  +----+-----+        +-----+----+
  |          |        |          |
+-+   vm0    |        |   vm1    +---+
| |          |        |          |   |
| +--------+-+        +---+------+   |
|          |              |          |
|          |              |          |
|          |              |          |
|          +-------+------+          |
|                  +                 |
|       VBox hostonly vboxnet0       |
|                                    |
|                                    |
+---+ peer0.org1.example.com         +--+ peer0.org2.example.com
      couchdb0                            couchdb2
      peer1.org1.example.com
      couchdb1
      orderer.example.com
      ca.example.com
```

As the original document, we'll use `docker swarm` between the 2 nodes through the `hostonly` network (192.168.99.100/28)


### Changed Files

*  bmhn.sh 
*  .gitignore
*  configtx.yaml
*  crypto-config.yaml
*  scripts/script.sh

Removed data from `crypto-config/*` and `channel-artifacts/*` as it'll be regenerated.

## Install

##### Create docker network to attach all Hyperledger services on `vm0`.

```
vm0$ docker network create --attachable --driver overlay testnet
```

##### Clone this repo and checkout `2Orgs` branch on all nodes.

```
vm{0|1}$ git clone https://github.com/netmanito/BMHNH
vm{0|1}$ cd BMHNH/
vm{0|1}(BMHNH)$ git checkout 2Orgs

```

Now, everything will be done on `vm0`

### VM0

##### Generate Network Artifacts

```
vm0(BMHNH)$ ./bmhn.sh
```

This will generate network artifacts for you in `crypto-config` and `channel-artifacts` folder. You must copy these folders on `vm1` so that both the projects will have same crypto material. It is important that both the nodes must have same crypto material otherwise the network will not communicate.

##### CA server

On firts node `vm0` you will execute `ca-node.sh` command included in this repo; before you do so, replace `{put the name of secret key}` with the name of the secret key. 
You can find it under `/crypto-config/peerOrganizations/org1.example.com/ca/`.

##### Orderer node

Run `orderer.sh` command included in this repo.

##### CouchDB — for Peer0 and Peer1 - Org1

Run `couchdb0.sh` command included in this repo to start `couchdb` for `peer0` and run `couchdb1.sh` for `peer1` .

##### Peers from Org1 

Run `peer0 .sh` and `peer1.sh` to start **Org1** peers.

If everything goes fine, you should have succesfully deployed the `CA-node`, `Orderer` hyperledger base system and `peers 0|1` for the `Org1`.

Lets change to second node `vm1` and start `Org2` peer.

### VM1 

##### Network Artifacts

Copy `crypto-config` and `channel-artifacts` folder from `vm0` to `vm1`.

```
vm1(BMHNH)$ rsync -avz vm0:~/BMHNH/crypto-config .

vm1(BMHNH)$ rsync -avz vm0:~/BMHNH/channel-artifacts .
```

##### CouchDB and Peers from Org2

Run `couchdb-Org2.sh` and `peer0-Org2.sh` to start `Org2` peers.
It should connect to `testnet` docker. 
If not, connect the containers using `docker network connect testnet $container`.

##### CLI

Run `cli.sh` which will run the `./scripts/script.sh`.

The script will:

* Create channel; `testnet` in our case
* Make `peer0` and `peer1` form `Org1` and `peer0` from `Org2`, join the channel.
* Upon successful joining of the channel, the script will update the anchor peer (peer0 in our case).
* Install the chaincode on all peers.

Now our network is up and running, let’s test it out. Now we will invoke and query chaincode on both peers from `vm1`.

That's it, you now have an Hyperledger environment where first **node** has `CA`, `Orderer` and the MSP manager `Org1` with 2 `peers`. 
And a second node related to `Org2` with it's own `peer` attached to same `network`and `channel`.

## Testing the network.

Run `cli-bash.sh` script to access `cli` shell hyperledger node.

You must see this after executing the command.

`root@b1ee4d403319:/opt/gopath/src/github.com/hyperledger/fabric/peer#`

#### Instantiate Chaincode on Peer0

To instantiate the chaincode on peer0 we will need to set few environment variables first. Paste the below line in the cli terminal.

##### Environment variables for PEER0

```
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp

CORE_PEER_LOCALMSPID="Org1MSP"

CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

CORE_PEER_ADDRESS=peer0.org1.example.com:7051
```

After that we will initialize chaincode. Execute the below command to instantiate the chaincode that was installed as a part of step 1.

```
$ peer chaincode instantiate -o orderer.example.com:7050 -C testnet -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR ('Org1MSP.member','Org2MSP.member')"
```

#### Query the Chaincode on Peer1 Org1

To query the chaincode on peer1 we will need to set few environment variables first. Paste the below line in the cli terminal on `vm1`

##### Environment variables for PEER1

```
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp

CORE_PEER_LOCALMSPID="Org1MSP"

CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

CORE_PEER_ADDRESS=peer1.org1.example.com:7051
```

Let’s query for the value of a to make sure the chaincode was properly instantiated and the couch DB was populated. The syntax for query is as follows: (execute in cli terminal) and wait for a while

```
$ peer chaincode query -C testnet -n mycc -c '{"Args":["query","a"]}'
```

it will bring

```
Query Result: 100
```

#### Invoke the Chaincode on Peer0 Org2

To invoke the chaincode on `peer0` we will need to set few environment variables first. Paste the below line in the cli terminal on `vm1`.

##### Environment variables for PEER0

```
CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp

CORE_PEER_LOCALMSPID="Org1MSP"

CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt

CORE_PEER_ADDRESS=peer0.org1.example.com:7051
```

Now let’s move 10 from `a` to `b`. 

This transaction will cut a new block and update the couch DB. The syntax for invoke is as follows: (execute in cli terminal on `vm1`)

```
$ peer chaincode invoke -o orderer.example.com:7050 -C testnet -n mycc -c '{"Args":["invoke","a","b","10"]}'
```

##### Query the Chaincode

Let’s confirm that our previous invocation executed properly. We initialized the key a with a value of 100 and just removed 10 with our previous invocation. Therefore, a query against a should reveal 90. The syntax for query is as follows. (we are querying on peer0 so no need to change the environment variables)

be sure to set the -C and -n flags appropriately

```
peer chaincode query -C testnet -n mycc -c '{"Args":["query","a"]}'
```
We should see the following:

```
Query Result: 90
```
