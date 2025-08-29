# Flux Complet BlockCast - Exemple de Pricing Dynamique

## Vue d'ensemble du système

BlockCast est un marché de prédiction décentralisé où :
- N'importe qui peut créer un marché
- Les utilisateurs parient sur Yes/No avec un pricing AMM (Automated Market Maker)
- Chaque pari génère un NFT tradable
- 2% des fees vont au protocole
- Les créateurs reçoivent 100 CAST tokens après résolution

## Exemple concret : "Est-ce que Bitcoin dépassera 100k$ avant fin 2025?"

### Étape 1: Création du marché
```
Créateur: Alice
Question: "Bitcoin > 100k$ avant fin 2025?"
Deadline: 31 décembre 2025
Dépôt initial: 1000 USDC
```

**État initial:**
- `reserve = 1000 USDC`
- `yesShares = 0`
- `noShares = 0`
- `totalYesValue = 0`
- `totalNoValue = 0`

---

### Étape 2: Premier achat - Bob achète 100 YES
**Calcul du prix:**
```solidity
// getPriceYes(100) quand reserve = 1000, yesShares = 0
if (reserve == 0) return sharesToBuy; // Non applicable
return (reserve * sharesToBuy) / (yesShares + sharesToBuy);
return (1000 * 100) / (0 + 100) = 100000 / 100 = 1000 USDC
```

**Prix unitaire:** 1000 / 100 = **10 USDC par share YES**

**Transaction:**
- Bob paie: 1000 USDC
- Bob reçoit: 100 shares YES + NFT #1
- Fees (2%): 20 USDC → Treasury
- Au marché: 980 USDC

**Nouvel état:**
- `reserve = 1980 USDC` (1000 initial + 980 net)
- `yesShares = 100`
- `noShares = 0`
- `totalYesValue = 980 USDC`
- Bob possède NFT #1 (100 YES shares)

---

### Étape 3: Charlie achète 50 YES
**Calcul du prix:**
```solidity
// getPriceYes(50) quand reserve = 1980, yesShares = 100
return (1980 * 50) / (100 + 50) = 99000 / 150 = 660 USDC
```

**Prix unitaire:** 660 / 50 = **13.2 USDC par share YES** (plus cher!)

**Transaction:**
- Charlie paie: 660 USDC
- Charlie reçoit: 50 shares YES + NFT #2
- Fees (2%): 13.2 USDC → Treasury
- Au marché: 646.8 USDC

**Nouvel état:**
- `reserve = 2626.8 USDC` (1980 + 646.8)
- `yesShares = 150`
- `noShares = 0`
- `totalYesValue = 1626.8 USDC`

---

### Étape 4: Dave achète 200 NO (contrepartie)
**Calcul du prix:**
```solidity
// getPriceNo(200) quand reserve = 2626.8, noShares = 0
return (2626.8 * 200) / (0 + 200) = 525360 / 200 = 2626.8 USDC
```

**Prix unitaire:** 2626.8 / 200 = **13.134 USDC par share NO**

**Transaction:**
- Dave paie: 2626.8 USDC
- Dave reçoit: 200 shares NO + NFT #3
- Fees (2%): 52.54 USDC → Treasury
- Au marché: 2574.26 USDC

**Nouvel état:**
- `reserve = 5201.06 USDC` (2626.8 + 2574.26)
- `yesShares = 150`
- `noShares = 200`
- `totalYesValue = 1626.8 USDC`
- `totalNoValue = 2574.26 USDC`

---

### Étape 5: Marché secondaire NFT
Charlie veut vendre son NFT #2 (50 YES shares) avant la deadline.

**Prix du marché actuel pour 50 YES:**
```solidity
// getPriceYes(50) avec état actuel
return (5201.06 * 50) / (150 + 50) = 260053 / 200 = 1300.27 USDC
```

**Prix unitaire actuel:** 1300.27 / 50 = **26.005 USDC par share**

Charlie peut lister son NFT à n'importe quel prix, par exemple 1250 USDC (légèrement en dessous du marché).

**Transaction NFT:**
- Eve achète le NFT #2 de Charlie pour 1250 USDC
- Les 50 shares YES sont automatiquement transférées à Eve
- Charlie récupère 1250 USDC (profit de 590 USDC!)

---

### Étape 6: Résolution du marché
**Scénario: Bitcoin atteint 105k$ → YES gagne**

**Distribution des gains:**
```
Total pool: 5201.06 USDC
Gagnants: 150 shares YES total

Gain par share YES = 5201.06 / 150 = 34.67 USDC par share
```

**Récompenses:**
- Bob (NFT #1, 100 shares): 100 × 34.67 = **3467 USDC**
- Eve (NFT #2, 50 shares): 50 × 34.67 = **1733.5 USDC**
- Dave (NFT #3, 200 NO shares): **0 USDC** (perdu)

**Bonus créateur:**
- Alice (créatrice) reçoit: **100 CAST tokens** (mintés automatiquement)

---

## Résumé des gains/pertes

| Participant      | Investissement | Récupéré          | Profit/Perte         |
| ---------------- | -------------- | ----------------- | -------------------- |
| Alice (créateur) | 1000 USDC      | 0 USDC + 100 CAST | -1000 USDC + rewards |
| Bob              | 1000 USDC      | 3467 USDC         | **+2467 USDC**       |
| Charlie          | 660 USDC       | 1250 USDC         | **+590 USDC**        |
| Eve              | 1250 USDC      | 1733.5 USDC       | **+483.5 USDC**      |
| Dave             | 2626.8 USDC    | 0 USDC            | **-2626.8 USDC**     |
| Treasury         | 0              | 85.74 USDC        | **+85.74 USDC fees** |

---

## Points clés du pricing AMM

1. **Prix initial**: 1:1 quand le marché est vide
2. **Prix croissant**: Plus il y a de shares d'un côté, plus le prix augmente
3. **Asymétrie**: YES et NO ont des prix différents selon les volumes
4. **Arbitrage**: Les écarts de prix créent des opportunités
5. **Liquidité**: Plus il y a de réserve, plus les prix sont stables

## Formule de pricing
```solidity
Prix = (reserve × shares_à_acheter) / (shares_existantes + shares_à_acheter)
```

Cette formule garantit que:
- Le prix augmente avec la demande
- Il y a toujours de la liquidité
- Le marché s'équilibre naturellement
