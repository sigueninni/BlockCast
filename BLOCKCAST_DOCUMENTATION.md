# 📊 BlockCast - Documentation Complète

## 🎯 Vue d'ensemble

BlockCast est une plateforme de marchés de prédiction décentralisée avec un système de pricing simple type Polymarket, des NFTs pour tokeniser les positions, et un système de résolution en deux étapes avec période de dispute.

---

## 🏗️ Architecture du Système

### 📋 Contrats Principaux

1. **PredictionMarket** - Contrat principal du marché
2. **PredictionMarketFactory** - Création et gestion des marchés
3. **AdminManager** - Gestion des permissions administratives
4. **Treasury** - Gestion des frais de protocole
5. **BetNFT** - NFTs représentant les positions
6. **CastToken** - Token de gouvernance/récompense

---

## 👥 Système d'Administration

### 🔑 Rôles et Permissions

#### **Super Admin**
- **Qui :** Déployeur initial du système
- **Pouvoirs :**
  - Ajouter/retirer des admins
  - Modifier les taux de frais de protocole (max 10%)
  - Contrôle total du système

#### **Admins**
- **Qui :** Utilisateurs approuvés par le Super Admin
- **Pouvoirs :**
  - Résoudre les marchés (preliminary + final)
  - Configurer les contrats BetNFT
  - Modérer le contenu

#### **Utilisateurs**
- **Qui :** Tout détenteur de tokens de collateral
- **Pouvoirs :**
  - Créer des marchés (via Factory)
  - Acheter des positions YES/NO
  - Trader des NFTs sur le marché secondaire
  - Récupérer les gains après résolution

---

## 🏭 Création de Marchés

### 📝 Processus de Création

```solidity
// Via PredictionMarketFactory
function createMarket(
    string memory question,      // "Bitcoin atteindra-t-il $100k en 2024?"
    uint256 endTime,            // Timestamp de fin (ex: 31 Dec 2024)
    address collateral,         // Token de collateral (DAI, USDC, etc.)
    uint256 protocolFeeRate     // Frais en points de base (200 = 2%)
) external returns (address marketAddress)
```

### 🎯 Paramètres Requis

- **Question** : Binaire (Oui/Non), claire et vérifiable
- **EndTime** : Date limite pour les paris
- **Collateral** : Token ERC20 (recommandé: 18 décimales)
- **Protocol Fee** : 0-10% (200 basis points = 2%)

### 🏆 Récompenses Créateur

- **Quand :** Après résolution finale du marché
- **Quoi :** Tokens CAST (gouvernance)
- **Montant :** Déterminé par la Factory

---

## 💰 Système de Pricing (Type Polymarket)

### 🧮 Mécanisme Simple

Notre système utilise un **AMM proportionnel simple** :

```solidity
Prix YES = yesShares / (yesShares + noShares)
Prix NO = 1.0 - Prix YES
```

### 📊 État Initial
- **YES Shares :** 100 (virtuels)
- **NO Shares :** 100 (virtuels)
- **Prix YES :** 50% (0.5)
- **Prix NO :** 50% (0.5)

### 📈 Évolution des Prix

#### Exemple Pratique :

| Action | YES Shares | NO Shares | Prix YES | Prix NO | Prob YES |
|--------|------------|-----------|-----------|---------|----------|
| **Initial** | 100 | 100 | 50% | 50% | 50% |
| User1 achète 200 YES | 300 | 100 | 75% | 25% | 75% |
| User2 achète 100 NO | 300 | 200 | 60% | 40% | 60% |
| User3 achète 500 YES | 800 | 200 | 80% | 20% | 80% |

### 💸 Calcul du Coût

Pour acheter N shares, le système calcule le **prix moyen** :

```solidity
Prix Actuel = shares actuelles / total
Prix Futur = (shares actuelles + N) / (total + N)
Coût Total = N × (Prix Actuel + Prix Futur) / 2
```

**Exemple :** Acheter 100 YES quand prix actuel = 50%
- Prix actuel : 50%
- Prix futur : ~58.3%
- Coût moyen : ~54.2%
- **Coût total : 100 × 0.542 = 54.2 tokens**

---

## 🎯 Probabilités et Pricing

### 📊 Relation Prix = Probabilité

Dans BlockCast : **Prix YES = Probabilité YES**

- **Si prix YES = 0.75** → **75% de chance que YES gagne**
- **Si prix NO = 0.25** → **25% de chance que NO gagne**
- **Conservation :** Prix YES + Prix NO = 1.0 (toujours)

### 📈 Évolution des Probabilités

Les probabilités évoluent naturellement avec les achats :
- ✅ **Plus d'achats YES** → Prix YES augmente → Probabilité YES augmente
- ❌ **Plus d'achats NO** → Prix NO augmente → Probabilité NO augmente

---

## 🔄 Système de Résolution (Deux Étapes)

### 📅 Timeline de Résolution

```
[Marché Ouvert] → [EndTime] → [Résolution Préliminaire] → [Période Dispute] → [Résolution Finale]
```

### 🏁 Étape 1 : Résolution Préliminaire

```solidity
function preliminaryResolve(Outcome outcome) external onlyAdmin
```

**Effets :**
- ❌ **Trading bloqué** (plus d'achats possibles)
- ⏳ **Statut :** `PendingResolution`
- 📝 **Stocke :** Résultat préliminaire
- 🔥 **Émet :** Event `PreliminaryResolution`

### 🏆 Étape 2 : Résolution Finale

```solidity
function finalResolve(Outcome outcome, uint256 confidenceScore) external onlyAdmin
```

**Paramètres :**
- **Outcome :** `Yes`, `No` (peut différer du préliminaire)
- **Confidence Score :** 0-100% (qualité de la résolution)

**Effets :**
- ✅ **Statut :** `Resolved`
- 💰 **Frais protocole** envoyés au Treasury
- 🏆 **Créateur récompensé** en tokens CAST
- 💸 **Remboursements** activés pour les gagnants

### 🤔 Gestion des Disputes

- **Période :** Déterminée hors-chaîne
- **Processus :** Investigation externe → Résolution finale
- **Flexibilité :** Admin peut changer l'outcome final
- **Score de confiance :** Reflète la qualité/certitude

---

## 💵 Système de Frais

### 📊 Frais de Protocole

- **Taux :** Configurable 0-10% (défaut: 2%)
- **Calcul :** `frais = reserve × protocolFeeRate / 10000`
- **Prélèvement :** À la résolution finale uniquement
- **Destination :** Treasury contract

### 💰 Exemple de Calcul

```
Réserve totale du marché : 10,000 USDC
Taux de frais : 2% (200 basis points)
Frais prélevés : 10,000 × 200 / 10,000 = 200 USDC
Reste pour remboursements : 9,800 USDC
```

### 🎯 Distribution des Gains

Après prélèvement des frais :

```solidity
// Pour un gagnant individuel
payout = (userShares × reserveRestante) / totalWinningShares
```

**Exemple :**
- User détient 100 shares YES
- Total YES shares : 500
- Réserve après frais : 9,800 USDC
- **Payout = 100 × 9,800 / 500 = 1,960 USDC**

---

## 🎨 NFTs et Marché Secondaire

### 🖼️ BetNFT - Tokenisation des Positions

Chaque position d'achat génère un **NFT unique** :

```solidity
struct BetMetadata {
    address market;      // Adresse du marché
    uint256 shares;      // Nombre de shares
    bool isYes;         // true = YES, false = NO
    uint256 timestamp;   // Moment de l'achat
}
```

### 🏪 Marché Secondaire

#### **Listing de NFTs**
```solidity
function listNFT(uint256 tokenId, uint256 price) external
```
- **Conditions :** Marché encore ouvert, propriétaire du NFT
- **Prix :** En ETH/token natif de la chaîne

#### **Achat de NFTs**
```solidity
function buyNFT(uint256 tokenId) external payable
```
- **Transferts automatiques :**
  - 💰 Paiement → Vendeur
  - 🎨 NFT → Acheteur  
  - 📊 Shares dans le marché → Acheteur

#### **Métadonnées On-Chain**
```json
{
  "name": "BlockCast Bet #123",
  "description": "Prediction market position NFT",
  "attributes": [
    {"trait_type": "Market", "value": "0x..."},
    {"trait_type": "Shares", "value": 100},
    {"trait_type": "Position", "value": "YES"},
    {"trait_type": "Timestamp", "value": 1703721600}
  ]
}
```

---

## 🎮 Scénarios d'Usage Complets

### 📈 Scénario 1 : Marché Bitcoin $100k

#### **1. Création**
```
Question: "Bitcoin atteindra-t-il $100,000 avant le 31 décembre 2024?"
EndTime: 31 décembre 2024, 23:59 UTC
Collateral: USDC
Fee Rate: 2%
```

#### **2. Évolution du Trading**

| Jour | Action | Montant | Prix YES | Prix NO | Prob YES |
|------|--------|---------|-----------|---------|----------|
| **J+1** | Alice achète YES | 1,000 USDC | 52% | 48% | 52% |
| **J+7** | Bob achète YES | 2,000 USDC | 58% | 42% | 58% |
| **J+14** | Carol achète NO | 1,500 USDC | 54% | 46% | 54% |
| **J+30** | Dave achète YES | 5,000 USDC | 68% | 32% | 68% |
| **J+60** | Pump Bitcoin! | - | 68% | 32% | 68% |
| **J+90** | Ève achète YES | 10,000 USDC | 78% | 22% | 78% |

#### **3. Résolution**
```
31 décembre 2024: Bitcoin = $95,000 (échec)

J+365: Admin fait preliminaryResolve(No)
       → Trading bloqué, statut = PendingResolution

J+372: Période de dispute (7 jours)
       → Vérifications externes, pas de contestation

J+372: Admin fait finalResolve(No, 95)
       → Résolution finale, 95% de confiance
       → Frais prélevés, détenteurs de NO remboursés
```

#### **4. Remboursements**
```
Réserve totale: 20,000 USDC
Frais (2%): 400 USDC
Reste: 19,600 USDC

Carol (NO): récupère sa part proportionnelle
Autres détenteurs NO: récupèrent leurs parts
Détenteurs YES: perdent leurs mises
```

### 🎨 Scénario 2 : Trading NFT

#### **1. Alice achète et liste son NFT**
```
1. Alice achète 500 YES shares pour 250 USDC
2. Reçoit NFT #123 (500 shares YES)
3. Bitcoin monte, prix YES passe à 75%
4. Alice liste NFT #123 pour 0.5 ETH
```

#### **2. Bob achète le NFT**
```
1. Bob paie 0.5 ETH
2. Reçoit NFT #123
3. Hérite de 500 YES shares dans le marché
4. Alice reçoit 0.5 ETH
```

#### **3. Résolution**
```
Si YES gagne: Bob récupère ~375 USDC (500 shares × 75% du pool)
Si NO gagne: Bob perd sa position
```

---

## 🔧 Aspects Techniques

### 💾 Variables d'État Principales

```solidity
// Shares virtuels + réels
uint256 public yesShares;     // Total YES (initial 100e18)
uint256 public noShares;      // Total NO (initial 100e18)
uint256 public reserve;       // Collateral total déposé

// Balances utilisateurs
mapping(address => uint256) public yesBalance;
mapping(address => uint256) public noBalance;

// Résolution
Outcome public preliminaryOutcome;  // Résultat préliminaire
Outcome public resolvedOutcome;     // Résultat final
uint256 public confidenceScore;     // Score 0-100
```

### 🎯 Fonctions Clés

#### **Trading**
- `buyYes(uint256 shares)` - Acheter des shares YES
- `buyNo(uint256 shares)` - Acheter des shares NO
- `getPriceYes(uint256 shares)` - Calculer le coût d'achat YES
- `getCurrentPrice()` - Prix instantané YES/NO

#### **Pricing & Probabilités**
- `getProbabilities()` - Probabilités actuelles (0-100)
- `getCurrentPrice()` - Prix instantané (0-1e18)

#### **Résolution**
- `preliminaryResolve(Outcome)` - Première résolution
- `finalResolve(Outcome, score)` - Résolution finale
- `redeem()` - Récupérer les gains

#### **NFT & Marché Secondaire**
- `listNFT(tokenId, price)` - Lister un NFT
- `buyNFT(tokenId)` - Acheter un NFT listé
- `transferShares(from, to, shares, isYes)` - Transfer interne

### ⚡ Optimisations et Contraintes

#### **Décimales**
- **Système interne :** 18 décimales (1e18)
- **Collateral recommandé :** 18 décimales (DAI, WETH)
- **USDC support :** Possible mais nécessite adaptation

#### **Gas Optimizations**
- Prix calculé off-chain puis validé on-chain
- Batch operations pour le trading de volume
- Events optimisés pour indexation

#### **Sécurité**
- Reentrancy guards sur toutes les fonctions de transfer
- Validation des paramètres utilisateur
- Overflow protection (Solidity 0.8+)

---

## 🚀 Déploiement et Configuration

### 🏗️ Ordre de Déploiement

1. **AdminManager** (Super Admin initial)
2. **Treasury** 
3. **CastToken** (gouvernance)
4. **BetNFT**
5. **PredictionMarketFactory**
6. **PredictionMarket** (via Factory)

### ⚙️ Configuration Initiale

```solidity
// 1. Configurer les admins
adminManager.addAdmin(0x...);

// 2. Autoriser la Factory à mint des CastTokens
castToken.grantRole(MINTER_ROLE, factoryAddress);

// 3. Autoriser la Factory à créer des NFTs
betNFT.authorizeMarket(factoryAddress);

// 4. Configurer les frais par défaut
factory.setDefaultProtocolFeeRate(200); // 2%
```

### 🌍 Réseaux Supportés

- **Ethereum Mainnet** (production)
- **Polygon** (faibles frais)
- **Arbitrum** (L2 optimisé)
- **Base** (Coinbase L2)
- **Testnets** (développement)

---

## 📊 Métriques et Analytics

### 📈 KPIs du Système

- **Volume total tradé** par marché
- **Nombre d'utilisateurs uniques**
- **Précision des prédictions** (% de marchés résolus correctement)
- **Liquidité moyenne** par marché
- **Frais générés** pour le protocole

### 🎯 Events pour Analytics

```solidity
event MarketCreated(address indexed market, address indexed creator, string question);
event SharesPurchased(address indexed market, address indexed user, bool isYes, uint256 shares, uint256 cost);
event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
event MarketResolved(address indexed market, Outcome outcome, uint256 confidenceScore);
```

---

## 🔮 Roadmap et Évolutions

### 🆕 V2 Prévisions

- **Multi-outcome markets** (plus que Oui/Non)
- **Conditional markets** (marchés liés)
- **Automated Market Makers** plus sophistiqués
- **Cross-chain bridges** pour liquidité
- **DAO governance** via CastToken
- **Oracle integration** pour résolution automatique

### 🎯 Améliorations Techniques

- **Layer 2 natif** pour réduire les frais
- **Batch trading** pour économiser le gas
- **Advanced pricing curves** (courbes s, logistiques)
- **MEV protection** pour traders
- **Mobile app** native

---

## 📚 Ressources et Support

### 🔗 Liens Utiles

- **GitHub :** `https://github.com/blockcast/contracts`
- **Documentation :** `https://docs.blockcast.market`
- **Discord :** `https://discord.gg/blockcast`
- **Twitter :** `@BlockCastMarket`

### 🆘 Support Technique

- **Smart Contract Audits :** En cours
- **Bug Bounty :** Programme actif
- **Community :** Discord pour support

---

*Documentation générée le 21 septembre 2025 - Version 1.0*

**⚠️ Disclaimer :** Les marchés de prédiction comportent des risques. Ne tradez que ce que vous pouvez vous permettre de perdre. Cette documentation est fournie à titre informatif uniquement.
