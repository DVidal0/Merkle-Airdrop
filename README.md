# 🥯 Merkle Airdrop

A gas-efficient ERC-20 airdrop contract built with [Foundry](https://book.getfoundry.sh/), using a **Merkle tree** to prove eligibility and an **EIP-712 signature** so a relayer (or anyone) can pay the gas on behalf of the claiming address.

> Project built following Patrick Collins' Advanced Foundry course on [Cyfrin Updraft](https://updraft.cyfrin.io/).

## 📋 Overview

`MerkleAirdrop.sol` distributes a fixed amount of an ERC-20 token (`BagelToken`, `BGL`) to a predefined whitelist of addresses. Instead of storing the whole list on-chain, only the Merkle **root** of the whitelist is stored; each claimant proves they're on the list by submitting a Merkle proof. To let someone else submit the claim transaction (and pay gas) on the eligible account's behalf, the contract verifies an **EIP-712 typed signature** from the account being claimed for, so the claim can only be executed with that account's consent.

### Key features

- ✅ Merkle-proof-based claim verification — no need to store the full whitelist on-chain, only a single root hash.
- ✅ EIP-712 typed-data signatures (`AirdropClaim(address account, uint256 amount)`), so a gas payer can submit the transaction while the signature still proves the claimant's consent.
- ✅ Double-claim protection via `s_hasClaimed` mapping, guarded by a custom error (`MerkleAirdrop__AlreadyClaimed`).
- ✅ Uses OpenZeppelin's `SafeERC20`, `MerkleProof`, `ECDSA`, and `EIP712` utilities for secure, standards-compliant verification.
- ✅ Off-chain tooling (via [Murky](https://github.com/dmfxyz/murky)) to generate the whitelist input, build the Merkle tree, and produce proofs for each claimant.
- ✅ zkSync-aware test setup (`ZkSyncChainChecker`) that falls back to a direct deployment instead of the Foundry deployment script when running on a zkSync chain.
- ✅ Interaction script to submit a claim against the most recently deployed contract, using `foundry-devops`.

## 🏗️ Project architecture

```
├── src/
│   ├── MerkleAirdrop.sol            # Core airdrop contract (Merkle proof + EIP-712 signature claim)
│   └── BagelToken.sol               # Simple owner-mintable ERC-20 used as the airdropped token
├── script/
│   ├── GenerateInput.s.sol          # Generates script/target/input.json (whitelist + amounts)
│   ├── MakeMerkle.s.sol             # Builds the Merkle tree from input.json and writes script/target/output.json (root, leaves, proofs)
│   ├── DeployMerkleAirdrop.s.sol    # Deploys BagelToken + MerkleAirdrop and funds the airdrop contract
│   └── interact.s.sol               # ClaimAirdrop script: submits a claim against the deployed contract
├── test/
│   └── MerkleAirdrop.t.sol          # Unit tests for claiming via a signed EIP-712 message + Merkle proof
└── README.md
```

### Contracts and scripts

| File | Role |
|---|---|
| `MerkleAirdrop.sol` | Verifies the EIP-712 signature and Merkle proof, marks the account as claimed, and transfers the tokens |
| `BagelToken.sol` | Minimal ERC-20 (`ERC20` + `Ownable`) with an `onlyOwner` `mint()`, used as the token being airdropped |
| `GenerateInput.s.sol` | Builds `script/target/input.json`: the list of whitelisted addresses, each with a fixed claim amount (25 tokens) |
| `MakeMerkle.s.sol` | Reads `input.json`, builds the Merkle tree with the Murky library, and writes `script/target/output.json` containing each leaf's inputs, proof, and the tree's root |
| `DeployMerkleAirdrop.s.sol` | Deploys `BagelToken` and `MerkleAirdrop` (with a hardcoded root), mints the total airdrop amount, and transfers it into the airdrop contract |
| `interact.s.sol` | `ClaimAirdrop` script that splits a raw signature into `(v, r, s)` and calls `claim()` on the most recently deployed `MerkleAirdrop` |
| `MerkleAirdrop.t.sol` | Tests that a user can sign a claim message, have a different address (the gas payer) submit it, and receive the correct token amount |

## ⚙️ How it works

1. **Build the whitelist** — `GenerateInput.s.sol` produces a JSON file listing each eligible address and its claim amount.
2. **Build the Merkle tree** — `MakeMerkle.s.sol` hashes each `(address, amount)` pair into a leaf, builds the tree with Murky, and outputs the root plus each leaf's proof.
3. **Deploy** — `DeployMerkleAirdrop.s.sol` deploys `BagelToken`, deploys `MerkleAirdrop` with the computed root, mints the total airdrop supply, and funds the airdrop contract.
4. **Sign** — the eligible account signs an EIP-712 typed message (`AirdropClaim{account, amount}`) via `getMessageHash()`, authorizing a claim for themselves without needing to submit a transaction.
5. **Claim** — `claim(account, amount, merkleProof, v, r, s)`: the contract checks the account hasn't already claimed, recovers the signer from `(v, r, s)` and confirms it matches `account`, verifies the Merkle proof against the stored root, marks the account as claimed, and transfers the tokens via `SafeERC20`.

## 🔧 Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`, `anvil`)
- [Git](https://git-scm.com/)

## 📦 Installation

```bash
git clone <repository-url>
cd <repository-name>
forge install
forge build
```

Expected dependencies (via `forge install`):

- `OpenZeppelin/openzeppelin-contracts` (`@openzeppelin`)
- `dmfxyz/murky` (Merkle tree generation and proofs)
- `foundry-rs/forge-std`
- `Cyfrin/foundry-devops`

## 🌳 Generating the Merkle tree

Before deploying, (re)generate the whitelist and Merkle tree whenever the list of claimants changes:

```bash
# 1. Generate the whitelist input file (script/target/input.json)
forge script script/GenerateInput.s.sol:GenerateInput

# 2. Build the Merkle tree and proofs (script/target/output.json)
forge script script/MakeMerkle.s.sol:MakeMerkle
```

Then update the `ROOT` constant in `DeployMerkleAirdrop.s.sol` (and the proofs used in `interact.s.sol`/tests) with the new values from `output.json`.

## 🧪 Tests

```bash
forge test
```

Run with more verbosity or filter by test name:

```bash
forge test -vvv
forge test --match-test testUsersCanClaim -vvvv
```

Check coverage:

```bash
forge coverage
```

## 🚀 Deployment

### Local network (Anvil)

```bash
anvil
```

In another terminal:

```bash
forge script script/DeployMerkleAirdrop.s.sol:DeployMerkleAirdrop --rpc-url http://127.0.0.1:8545 --private-key <YOUR_PRIVATE_KEY> --broadcast
```

### Testnet (Sepolia)

Set up your environment variables (e.g. in a `.env` file):

```bash
SEPOLIA_RPC_URL=<your_rpc_url>
PRIVATE_KEY=<your_private_key>
ETHERSCAN_API_KEY=<your_api_key>
```

Deploy:

```bash
forge script script/DeployMerkleAirdrop.s.sol:DeployMerkleAirdrop --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify -vvvv
```

## 🎮 Claiming an airdrop

Using `interact.s.sol` against the most recently deployed contract on the current chain (via `foundry-devops`):

```bash
forge script script/interact.s.sol:ClaimAirdrop --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
```

> ⚠️ `interact.s.sol` currently hardcodes the claiming address, amount, proof, and signature as constants. Update `CLAIMING_ADDRESS`, `AMOUNT_TO_COLLECT`, `PROOF_ONE`/`PROOF_TWO`, and `SIGNATURE` to match a real entry from `output.json` and a freshly generated signature before using it — the signature is tied to the specific deployed `MerkleAirdrop` address and will need to be regenerated on every redeploy.

## 🔍 Available view functions

| Function | Returns |
|---|---|
| `getMerkleRoot()` | The Merkle root used to validate claims |
| `getAirdropToken()` | The ERC-20 token address being airdropped |
| `getMessageHash(address account, uint256 amount)` | The EIP-712 typed-data hash that `account` must sign to authorize a claim |
| `s_hasClaimed(address)` | Whether a given address has already claimed |

## ⚠️ Custom errors

- `MerkleAirdrop__InvalidProof` — the supplied Merkle proof does not verify against the stored root.
- `MerkleAirdrop__AlreadyClaimed` — the account has already claimed its airdrop.
- `MerkleAirdrop__InvalidSignature` — the recovered signer does not match the claiming account.

## 📜 License

MIT

## 🙏 Credits

Based on the **Advanced Foundry** course by [Patrick Collins](https://github.com/PatrickAlphaC) on [Cyfrin Updraft](https://updraft.cyfrin.io/). Merkle tree tooling (`Merkle`, `ScriptHelper`) from [Murky](https://github.com/dmfxyz/murky) by kootsZhin, adapted by Ciara Nightingale / Cyfrin.
