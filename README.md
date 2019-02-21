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

As the original document, we'll use `docker swarm` between the 2 nodes through the `hostonly` virtualbox network service (192.168.99.100/28)


## Install Process

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

### VM0 Org1

##### Generate Network Artifacts

```
vm0(BMHNH)$ ./bmhn.sh
```

This will generate network artifacts for you in `crypto-config` and `channel-artifacts` folder. You must copy these folders on `vm1` so that both the projects will have same crypto material. It is important that both the nodes must have same crypto material otherwise the network will not communicate.

##### CA server
On first node `vm0` you will execute `ca-node.sh` command included in this repo; before you do so, replace `KEY` variable in the file with the name of the secret key. 
You can find it under `/crypto-config/peerOrganizations/org1.example.com/ca/`.

You'll see there's only **Org1** in `crypto-config/` dir at this moment.

```
hyper@hyperledger:~/BMHNH$ ls -l crypto-config/peerOrganizations/
total 4
drwxr-xr-x 7 hyper hyper 4096 Feb 21 11:52 org1.example.com
``` 

##### Orderer node
Run `orderer.sh` command included in this repo.

##### CouchDB — for Peer0 and Peer1 - Org1
Run `couchdb0.sh` command included in this repo to start `couchdb` for `peer0` and run `couchdb1.sh` for `peer1` .

##### Peers from Org1 
Run `peer0 .sh` and `peer1.sh` to start **Org1** peers.

If everything goes fine, you should have succesfully deployed the `CA-node`, `Orderer` hyperledger base system and `peers 0|1` for the `Org1`.

##### CLI
Run `cli.sh` which will run the `./scripts/script.sh`.

The script will:

* Create channel; `testnet` in our case
* Make `peer0` and `peer1` form `Org1`, join the channel.
* Upon successful joining of the channel, the script will update the anchor peer (peer0 in our case).
* Install the chaincode on all peers.

Now our network is up and running, let’s test it out. 

You now have an Hyperledger environment where first **node** has `CA`, `Orderer` and the MSP manager `Org1` with 2 `peers`. 

### Configuring the network.
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

After that we will initialize chaincode. Execute the below command to instantiate the chaincode that was installed as a part of step 1. This should be done for every **Org** in the network.

```
$ peer chaincode instantiate -o orderer.example.com:7050 -C testnet -n mycc -v 1.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR ('Org1MSP.member','Org2MSP.member')"
```

#### Query the Chaincode on Peer1 Org1
To query the chaincode on peer1 we will need to set few environment variables first. Paste the below line in the cli terminal.

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

That's it, we've the first Org with 2 peer nodes on the network. 

Lets now add a new Org to the network.

================================================================

### VM1 Org2
We'll follow the `channel-update` tutorial from hyperledger documentation [https://hyperledger-fabric.readthedocs.io/en/latest/channel_update_tutorial.html](https://hyperledger-fabric.readthedocs.io/en/latest/channel_update_tutorial.html)

#### Copy material from master node
```
rsync -avz hyperledger:~/BMHNH/crypto-config/ crypto-config/
rsync -avz hyperledger:~/BMHNH/channel-artifacts/ channel-artifacts/
```

#### Generate the Org2 Crypto Material
```
export FABRIC_CFG_PATH=$PWD && configtxgen -printOrg Org2MSP > ../channel-artifacts/org2.json
```

```
cd ../ && cp -r crypto-config/ordererOrganizations org2-artifacts/crypto-config/
```

### Prepare the CLI Environment
Run `cli-bash.sh` from `vm1` and set the environment variables.

```
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem  && export CHANNEL_NAME=testnet
```
Check you've connectivity with `orderer.example.com`.

```
root@2f6fd4e299f6:/opt/gopath/src/github.com/hyperledger/fabric/peer# nc -v orderer.example.com 7050
Connection to orderer.example.com 7050 port [tcp/*] succeeded!
```
Fetch configuration from current network.

```
peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --cafile $ORDERER_CA
```
We now have a file config from the current network.

```
root@2f6fd4e299f6:/opt/gopath/src/github.com/hyperledger/fabric/peer# peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --cafile $ORDERER_CA
2019-02-21 11:46:06.782 UTC [main] InitCmd -> WARN 001 CORE_LOGGING_LEVEL is no longer supported, please use the FABRIC_LOGGING_SPEC environment variable
2019-02-21 11:46:06.798 UTC [main] SetOrdererEnv -> WARN 002 CORE_LOGGING_LEVEL is no longer supported, please use the FABRIC_LOGGING_SPEC environment variable
2019-02-21 11:46:06.801 UTC [channelCmd] InitCmdFactory -> INFO 003 Endorser and orderer connections initialized
2019-02-21 11:46:06.812 UTC [cli.common] readBlock -> INFO 004 Received block: 2
2019-02-21 11:46:06.823 UTC [cli.common] readBlock -> INFO 005 Received block: 1

root@2f6fd4e299f6:/opt/gopath/src/github.com/hyperledger/fabric/peer# ls
channel-artifacts  config_block.pb  crypto  scripts
```
As a result, we have the following configuration sequence:

* block 0: genesis block
* block 1: Org1 anchor peer update
* block 2: Org2 anchor peer update

### Convert the Configuration to JSON and Trim It Down
```
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json
```

### Add the Org3 Crypto Material
```
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"Org2MSP":.[1]}}}}}' config.json ./channel-artifacts/org2.json > modified_config.json
```

```
configtxlator proto_encode --input config.json --type common.Config --output config.pb
```

```
configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
```

```
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output org2_update.pb
```

```
configtxlator proto_decode --input org2_update.pb --type common.ConfigUpdate | jq . > org2_update.json
```

```
echo '{"payload":{"header":{"channel_header":{"channel_id":"testnet", "type":2}},"data":{"config_update":'$(cat org2_update.json)'}}}' | jq . > org2_update_in_envelope.json
```

```
configtxlator proto_encode --input org2_update_in_envelope.json --type common.Envelope --output org2_update_in_envelope.pb
```

```
peer channel signconfigtx -f org2_update_in_envelope.pb
```
This should result in the below message

```
root@2f6fd4e299f6:/opt/gopath/src/github.com/hyperledger/fabric/peer# peer channel signconfigtx -f org2_update_in_envelope.pb

2019-02-21 11:53:14.659 UTC [main] InitCmd -> WARN 001 CORE_LOGGING_LEVEL is no longer supported, please use the FABRIC_LOGGING_SPEC environment variable
2019-02-21 11:53:14.682 UTC [main] SetOrdererEnv -> WARN 002 CORE_LOGGING_LEVEL is no longer supported, please use the FABRIC_LOGGING_SPEC environment variable
2019-02-21 11:53:14.682 UTC [channelCmd] InitCmdFactory -> INFO 003 Endorser and orderer connections initialized
```

```
peer channel update -f org2_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --cafile $ORDERER_CA
```

```
root@2f6fd4e299f6:/opt/gopath/src/github.com/hyperledger/fabric/peer# peer channel update -f org2_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --cafile $ORDERER_CA

2019-02-21 11:58:16.223 UTC [main] InitCmd -> WARN 001 CORE_LOGGING_LEVEL is no longer supported, please use the FABRIC_LOGGING_SPEC environment variable
2019-02-21 11:58:16.243 UTC [main] SetOrdererEnv -> WARN 002 CORE_LOGGING_LEVEL is no longer supported, please use the FABRIC_LOGGING_SPEC environment variable
2019-02-21 11:58:16.246 UTC [channelCmd] InitCmdFactory -> INFO 003 Endorser and orderer connections initialized
2019-02-21 11:58:16.273 UTC [channelCmd] update -> INFO 004 Successfully submitted channel update
```








































##### CouchDB and Peers from Org2

Run `couchdb-Org2.sh` and `peer0-Org2.sh` to start `Org2` peers.
It should connect to `testnet` docker. 
If not, connect the containers using `docker network connect testnet $container`.

And a second node related to `Org2` with it's own `peer` attached to same `network`and `channel`.



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
