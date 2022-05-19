# learn-kudosv3
Learning the contracts of KudosV3

#### Surya

<img src="/SuryaKudosV3.png" alt="SuryaKudosV3" style="width: 65%;">

#### SolGraph

<img src="/SolgraphKudosV3.png" alt="SolgraphKudosV3" style="width: 100%;">

## Getting Started

#### Compile

```sh
git clone https://github.com/fatfingererr/learn-kudosv3.git
cd learn-kudosv3
npm install
npm run compile
```

#### Deploy

```
npm run deploy
```

#### Verify

```
npx hardhat verify <kudosv3 address> --network matic
```

## Analysis

### solgraph

Generates a DOT graph that visualizes function control flow of a Solidity contract and highlights potential security vulnerabilities.
- https://github.com/raineorshine/solgraph

#### Install

```
npm install -g solgraph
sudo npm install -g solgraph --unsafe-perm=true --allow-root
sudo apt install graphviz
```

#### usage

```
solgraph contracts/KudosV3.sol > SolgraphKudosV3.dot
dot -Tpng SolgraphKudosV3.dot -o SolgraphKudosV3.png
xdg-open SolgraphKudosV3.png # for ubuntu
```

### Surya

Surya is an utility tool for smart contract systems. It provides a number of visual outputs and information about the contracts' structure. Also supports querying the function call graph in multiple ways to aid in the manual inspection of contracts.
- https://github.com/ConsenSys/surya

#### Install

```
npm install -g surya
sudo apt install graphviz
```

#### usage

```
surya graph contracts/KudosV3.sol | dot -Tpng > SuryaKudosV3.png
```