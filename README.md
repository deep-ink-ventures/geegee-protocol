# GeeGee Protocol 🎫

> Made with ❤️ for Polkadot by [Deep Ink Ventures](https://deep-ink.ventures)

GeeGee is a provably fair, on-chain raffle protocol that brings transparency and trust to digital raffles through blockchain technology.

## Overview

GeeGee enables participants to enter raffles for exciting prizes like consumer electronics while ensuring complete fairness through cryptographic proofs and blockchain technology. Each participant has an equal chance of winning, and the system is designed to be transparent and tamper-proof.

## Key Features

- **Provably Fair**: Our cryptographic system ensures that winning tickets cannot be predicted or manipulated
- **On-Chain Implementation**: Each raffle exists as an NFT Collection on the blockchain
- **Guaranteed Value**: Non-winners receive voucher codes equal to their ticket value
- **Unlimited Participation**: Buy as many tickets as you want to increase your chances
- **Transparent Process**: The entire raffle mechanism is verifiable on-chain

## How It Works

### 1. Raffle Setup
- Each raffle is implemented as an NFT Collection on-chain
- A cryptographic hash of a random number (GeeGee Number - GNN) is generated and stored at collection creation
- Each ticket is minted as a non-transferable NFT with a unique identifier

### 2. Participation
- Users can purchase tickets at a fixed price
- Each ticket represents a chance to win the featured prize
- Tickets are represented as unrevealed NFTs in the collection
- No limit on the number of tickets a participant can purchase

### 3. Winner Selection Process

The winning ticket is determined through a provably fair process:

1. **Initial Randomization (GNN)**
   - GeeGee generates a random number with an additional random string sequence
   - This number is hashed and stored at raffle creation

2. **Block Hash Integration (FBN)**
   - The final block hash after ticket sales close is converted to a number
   - This provides an additional source of randomness that couldn't be known in advance

3. **Winner Calculation**
   ```
   Final Number = GNN × FBN
   Winning Ticket = Final Number % Total Number of Tickets
   ```

This process ensures:
- No one can predict the winning ticket during the sale period
- The outcome is verifiable by all participants
- Even GeeGee employees cannot manipulate the results

### 4. Prize Distribution
- The winning ticket holder receives the featured prize
- All other participants receive voucher codes equal to their ticket value
- Prizes and vouchers can be claimed through the GeeGee app

## Security

The protocol employs cryptographic hashing functions that:
- Produce fixed-size byte strings that appear random
- Are computationally irreversible
- Include additional random string sequences to prevent guessing
- Combine multiple sources of entropy for true randomness

## Getting Started

[Documentation and integration guides coming soon]

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
