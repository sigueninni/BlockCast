# BlockCast - Prediction Markets Platform Documentation

## Overview

BlockCast is a decentralized prediction market platform where users can create markets, trade on future events, and earn rewards. Think of it as a marketplace where people bet on real-world outcomes like "Will Bitcoin reach $100,000?" or "Will it rain tomorrow in New York?"

---

## Core Concepts

### What is a Prediction Market?
A prediction market allows people to trade shares that represent the probability of future events. If you think Bitcoin will reach $100k, you buy "YES" shares. If you think it won't, you buy "NO" shares. The price reflects what the crowd believes is the probability of that event happening.

### How Does Pricing Work?
- **Simple Rule**: Price = Probability
- If YES shares cost $0.75, the market believes there's a 75% chance the event will happen
- If NO shares cost $0.25, there's a 25% chance it won't happen
- Prices always add up to $1.00

---

## Smart Contracts Explained

### 1. **PredictionMarketFactory** - The Market Creator

**What it does**: This is the central hub that creates all prediction markets.

**Key Features**:
- **Market Creation**: Anyone can propose a new prediction market
- **Quality Control**: Admins can pause market creation if needed
- **Reward System**: Automatically rewards market creators with CAST tokens when their market resolves successfully
- **Authorization**: Manages which markets are legitimate

**User Experience**:
- Submit a question like "Will Team A win the championship?"
- Set an end date (when betting stops)
- The factory creates your market and authorizes it
- You get rewarded with governance tokens when it resolves

### 2. **PredictionMarket** - Individual Betting Markets

**What it does**: Each market represents one specific question where people can trade YES/NO positions.

**How Trading Works**:
1. **Market Opens**: People can buy YES or NO shares
2. **Dynamic Pricing**: Prices change based on demand (more YES buyers = higher YES price)
3. **Market Closes**: No more trading after the deadline
4. **Resolution**: Admins determine the outcome
5. **Payouts**: Winners get their share of the pot

**Smart Features**:
- **Two-Stage Resolution**: First a preliminary result, then final confirmation after dispute period
- **Confidence Scoring**: Admins can express how certain they are (0-100%)
- **Protocol Fees**: Small percentage goes to platform treasury
- **Proportional Payouts**: Winners split the pot based on their stake

**Example Flow**:
- Market: "Will Bitcoin hit $100k by Dec 31?"
- You buy 100 YES shares at $0.60 each = $60 spent
- Market resolves to YES
- You get back: (your shares / total winning shares) × remaining pot

### 3. **BetNFT** - Digital Collectibles for Your Bets

**What it does**: Every time you buy shares, you get a unique NFT that represents your position.

**Why NFTs?**:
- **Proof of Ownership**: Your NFT proves you own specific shares
- **Secondary Market**: You can sell your position to others before market closes
- **Collectible Value**: Each NFT has unique metadata about your bet
- **Transferable**: Trade your betting positions like trading cards

**NFT Features**:
- **Automatic Creation**: Get an NFT every time you place a bet
- **Rich Metadata**: Shows market, shares, position (YES/NO), timestamp
- **Marketplace**: List your NFT for sale at any price you want
- **Trading Restrictions**: Can only trade while market is still open

**Secondary Market Example**:
- You buy 500 YES shares when price is $0.50
- Price goes up to $0.80 (looking good for YES!)
- Instead of waiting for resolution, you list your NFT for $450
- Someone buys it, you get $450 cash now, they get the 500 shares

### 4. **Treasury** - Platform Revenue Management

**What it does**: Collects and manages all platform fees from trading activity.

**Revenue Sources**:
- **Protocol Fees**: Small percentage (default 2%) from each market's total volume
- **Collected at Resolution**: Fees are only taken when markets resolve

**Fund Management**:
- **Admin Controlled**: Only authorized admins can withdraw funds
- **Multi-Token Support**: Can hold any type of token (USDC, DAI, etc.)
- **Transparent Tracking**: All deposits and withdrawals are recorded
- **Balance Monitoring**: Anyone can check how much the treasury holds

**Use Cases**:
- Platform development funding
- Admin compensation
- Security audits
- Community rewards

### 5. **AdminManager** - Governance & Permissions

**What it does**: Manages who can do what on the platform.

**Role Hierarchy**:

#### Super Admin (Platform Owner)
- **Ultimate Control**: Can add/remove regular admins
- **Fee Control**: Can change protocol fee rates (max 10%)
- **System Settings**: Can pause/unpause various features
- **Emergency Powers**: Can intervene in extreme situations

#### Regular Admins (Trusted Moderators)
- **Market Resolution**: Decide outcomes of prediction markets
- **Content Moderation**: Can pause problematic markets
- **Technical Management**: Update contract configurations
- **Dispute Handling**: Manage the two-stage resolution process

#### Regular Users (Everyone Else)
- **Market Creation**: Propose new prediction markets
- **Trading**: Buy and sell prediction shares
- **NFT Trading**: List and buy position NFTs
- **Claiming Rewards**: Redeem winnings and creator rewards

### 6. **CastToken** - Governance Token

**What it does**: The platform's governance token that rewards participation.

**How You Earn CAST**:
- **Create Markets**: Get 100 CAST tokens when your market resolves successfully
- **Active Participation**: Future rewards for high-quality market creation
- **Community Contributions**: Potential airdrops for platform engagement

**Utility (Future)**:
- **Governance Voting**: Vote on platform changes
- **Fee Discounts**: Reduced trading fees for token holders
- **Premium Features**: Access to advanced market creation tools
- **Staking Rewards**: Earn yield by locking up tokens

---

## Complete User Journeys

### Journey 1: Market Creator

1. **Create Market**
   - Think of an interesting question: "Will the next iPhone have a folding screen?"
   - Set end date: "January 15th, 2025"
   - Submit through Factory
   - Pay small gas fee

2. **Market Goes Live**
   - People start trading YES/NO shares
   - You watch the probability evolve
   - Market generates trading volume

3. **Resolution Time**
   - Market closes on end date
   - Admins research the outcome
   - Preliminary resolution announced
   - 7-day dispute period
   - Final resolution confirmed

4. **Get Rewarded**
   - Receive 100 CAST tokens automatically
   - Build reputation as quality market creator
   - Potential for future governance rights

### Journey 2: Trader

1. **Find Interesting Market**
   - Browse active markets
   - Research the topic: "Will SpaceX land on Mars in 2025?"
   - Check current probability: YES trading at $0.30

2. **Place Your Bet**
   - Buy 1000 YES shares for $300
   - Receive NFT representing your position
   - Watch your shares in real-time

3. **Monitor & Decide**
   - Price moves to $0.60 (good news for you!)
   - Option A: Hold until resolution
   - Option B: Sell NFT on secondary market for profit

4. **Resolution & Payout**
   - If YES wins: Get ~$600 (doubled your money!)
   - If NO wins: Lose your $300
   - Automatic payout to your wallet

### Journey 3: NFT Trader

1. **Buy Position NFT**
   - Someone lists their bet NFT for sale
   - Buy it to inherit their market position
   - Now you own their shares + NFT

2. **Active Trading**
   - List your own positions for sale
   - Set your desired price
   - Profit from short-term price movements

3. **Collection & Strategy**
   - Build portfolio of active positions
   - Diversify across multiple markets
   - Trade based on news and analysis

---

## Economics & Incentives

### Fee Structure
- **Protocol Fee**: 2% of total market volume (adjustable by Super Admin)
- **Collected at Resolution**: Only when markets close successfully
- **Goes to Treasury**: Funds platform development and operations

### Reward System
- **Market Creators**: 100 CAST tokens per successful market
- **Quality Incentive**: Only get rewarded if market resolves properly
- **Future Enhancements**: Potential trading rewards, referral bonuses

### Risk Management
- **Two-Stage Resolution**: Prevents hasty decisions
- **Admin Oversight**: Trusted parties handle complex resolutions
- **Confidence Scoring**: Transparency about resolution quality
- **Dispute Period**: Time for community to challenge results

---

## Safety & Security

### Smart Contract Security
- **Audited Code**: All contracts reviewed for vulnerabilities
- **Tested Extensively**: Comprehensive test suite covers all scenarios
- **Upgradeable**: Admin can fix issues without losing user funds
- **Open Source**: Code is publicly verifiable

### Financial Protections
- **No Platform Risk**: Your money is in smart contracts, not controlled by company
- **Proportional Payouts**: Algorithm ensures fair distribution
- **Fee Transparency**: All costs are clearly displayed
- **Withdrawal Guarantees**: Winners can always claim their money

### Governance Safeguards
- **Admin Limits**: Super Admin power is constrained by code
- **Multi-Signature**: Important decisions require multiple approvals
- **Time Delays**: Major changes have waiting periods
- **Community Oversight**: All actions are publicly visible

---

## Getting Started

### For Market Creators
1. **Connect Wallet**: Use MetaMask or similar
2. **Prepare Question**: Make it clear, verifiable, and interesting
3. **Set Timeline**: Choose realistic end date
4. **Submit & Wait**: Factory creates your market
5. **Promote**: Share with community to drive trading

### For Traders
1. **Fund Wallet**: Get USDC, DAI, or supported tokens
2. **Browse Markets**: Find topics you understand
3. **Research**: Make informed predictions
4. **Start Small**: Begin with small amounts to learn
5. **Track Performance**: Monitor your positions

### For NFT Collectors
1. **Understand Positions**: Learn what each NFT represents
2. **Watch Markets**: Find profitable trading opportunities
3. **List Strategically**: Price your NFTs competitively
4. **Build Reputation**: Become known as reliable trader

---

## Market Examples

### Simple Binary Markets
- "Will Bitcoin exceed $100,000 in 2024?" (YES/NO)
- "Will it rain in London on Christmas Day?" (YES/NO)
- "Will Team A beat Team B in the finals?" (YES/NO)

### Economic Predictions
- "Will inflation exceed 5% next year?" (YES/NO)
- "Will unemployment rate drop below 3%?" (YES/NO)
- "Will the stock market gain 20%?" (YES/NO)

### Technology & Innovation
- "Will ChatGPT-5 be released by June?" (YES/NO)
- "Will Tesla deliver 2M cars this year?" (YES/NO)
- "Will Apple announce AR glasses?" (YES/NO)

### Entertainment & Culture
- "Will Movie X win Best Picture Oscar?" (YES/NO)
- "Will Celebrity Y announce retirement?" (YES/NO)
- "Will TV Show Z get renewed?" (YES/NO)

---

## Platform Benefits

### For Users
- **Profit from Knowledge**: Turn your insights into money
- **Learn & Research**: Incentive to stay informed about world events
- **Community Building**: Connect with like-minded predictors
- **Portfolio Diversification**: New asset class beyond stocks/crypto

### For Society
- **Information Aggregation**: Harness collective intelligence
- **Better Predictions**: More accurate than polls or expert opinions
- **Research Tool**: Valuable data for businesses and researchers
- **Democratic Forecasting**: Everyone can contribute their view

### For Developers
- **Composable**: Other apps can build on top of BlockCast
- **Open Data**: All prediction data is publicly available
- **Fair Launch**: Community-owned, not controlled by VCs
- **Innovation Platform**: Foundation for new prediction products

---

## Future Roadmap

### Phase 2: Enhanced Features
- **Multi-Outcome Markets**: More than just YES/NO
- **Conditional Markets**: "If X happens, then Y will happen"
- **Time Series Markets**: Predict specific numbers, not just binary outcomes
- **Mobile App**: Native iOS/Android applications

### Phase 3: Advanced Functionality
- **Automated Resolution**: Oracle integration for objective outcomes
- **Cross-Chain Support**: Trade on multiple blockchains
- **Advanced Analytics**: Professional trading tools
- **Institution Support**: API access for businesses

### Phase 4: Ecosystem Expansion
- **DAO Governance**: Full community control
- **Prediction Indexes**: Basket products tracking multiple markets
- **Insurance Products**: Hedge real-world risks with predictions
- **Global Expansion**: Localized versions for different regions

---

## Support & Community

### Getting Help
- **Documentation**: Comprehensive guides and tutorials
- **Discord Community**: Real-time chat with other users
- **Support Tickets**: Direct help for technical issues
- **Video Tutorials**: Step-by-step walkthroughs

### Stay Connected
- **Twitter**: @BlockCastMarket for updates
- **Newsletter**: Weekly market highlights
- **Blog**: Deep dives into prediction science
- **Governance Forum**: Participate in platform decisions

---

*This platform puts the power of prediction in everyone's hands. Whether you're a casual user making your first bet or a sophisticated trader building a portfolio, BlockCast provides the tools and transparency you need to profit from your knowledge of the future.*

**Important**: Prediction markets involve financial risk. Only trade what you can afford to lose. Past performance doesn't guarantee future results. Always do your own research.
