# BlockCast - System Overview

## What is BlockCast?

BlockCast is a prediction market platform where users can bet on future events. You can buy YES or NO positions on questions like "Will Bitcoin reach $100k by end of 2024?" The platform uses simple pricing that reflects the crowd's opinion about the probability of events.

## The Contracts

### PredictionMarket
This is where the actual betting happens. Each market has one question with YES/NO answers. Users deposit tokens to buy shares, and winners get paid out when the market resolves.

### PredictionMarketFactory  
This creates new markets. When someone wants to start a prediction market, they use the Factory. It ensures all markets follow the same rules and connects them to the reward system.

### AdminManager
This manages who can resolve markets. Admins are trusted people who decide the final outcome of questions. There's a Super Admin who controls everything and regular Admins who resolve markets.

### Treasury
This collects fees from each market. When markets resolve, a small percentage goes to the Treasury to fund the platform operations.

### BetNFT
When you buy shares, you get an NFT that represents your position. You can sell this NFT to other people, creating a secondary market for betting positions.

### CastToken
This is the reward token. Market creators get CAST tokens when their markets are resolved. It's used for platform governance and rewards.

## How the Pricing Works (AMM)

The system uses a simple automatic market maker:

**Basic Logic:**
- Start with 100 virtual YES shares and 100 virtual NO shares
- YES price = YES shares ÷ (YES shares + NO shares)
- NO price = 1 - YES price

**Example:**
- Initially: 100 YES, 100 NO → YES price = 50%, NO price = 50%
- Someone buys 200 YES shares: Now 300 YES, 100 NO → YES price = 75%, NO price = 25%
- The more people buy YES, the higher the YES price goes

This means the price always reflects what the crowd thinks will happen.

## The Betting Flow

### 1. Creating a Market
- Someone submits a clear YES/NO question
- Sets an end date for betting
- Chooses what token people bet with (like USDC)
- Market goes live for trading

### 2. Buying Shares
- Users deposit tokens to buy YES or NO shares
- Each purchase moves the price based on supply and demand
- Users get an NFT representing their position
- Can buy more shares anytime before the deadline

### 3. Secondary Market Trading
- Users can sell their NFT positions to others
- Price is set by the seller in ETH
- Buyer gets the NFT and the underlying shares
- This allows early exit before market resolution

### 4. Market Resolution
- **Step 1:** Admin makes preliminary decision after deadline
- **Step 2:** Dispute period (usually a few days)
- **Step 3:** Final resolution with confidence score
- Winners can withdraw their tokens

## Rewards System

### For Market Creators
- Get CAST tokens when their market resolves
- Amount depends on market activity and success
- Encourages people to create interesting markets

### For Platform
- Small fee (usually 2%) taken from each market
- Goes to Treasury for platform development
- Keeps the system sustainable

### For Winners
- Get back their original tokens plus winnings
- Payout based on how many shares they own vs total winning shares
- Automatic calculation ensures fair distribution

## Secondary Market for NFTs

### How it Works
- Every betting position becomes an NFT
- NFT contains: market address, number of shares, YES/NO position, timestamp
- Owners can list NFTs for sale at any price
- Buyers pay in ETH and get the NFT plus underlying shares

### Why Use It
- Exit positions early without waiting for resolution
- Speculate on NFT values as prices change
- More liquidity for betting positions
- Creates additional trading opportunities

## Key Features

### Two-Stage Resolution
Prevents hasty decisions by having preliminary then final resolution with dispute period.

### Fee Management
Configurable fees (0-10%) ensure platform sustainability while keeping costs reasonable.

### NFT Integration
Every position becomes tradeable, creating additional value and liquidity.

### Simple Pricing
Easy to understand probability-based pricing that reflects market sentiment.

### Permission System
Controlled by trusted admins to ensure fair and accurate resolutions.
