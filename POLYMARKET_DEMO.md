# 📊 Démonstration Système Polymarket Simple

## 🎯 Principe
- **Prix = Probabilité** : Si YES coûte 0.7 USDC, alors P(YES) = 70%
- **Conservation** : Prix YES + Prix NO = 1.0 toujours
- **Augmentation avec demande** : Plus on achète YES, plus ça coûte cher

## 🔍 Exemple Concret

### État Initial
- **Shares** : 100 YES, 100 NO (équilibré)
- **Prix** : YES = 0.5, NO = 0.5 (50¢ chacun)
- **Probabilité** : P(YES) = 50%, P(NO) = 50%

### Après achat de 50 YES shares
- **Shares** : 150 YES, 100 NO
- **Prix** : YES = 150/250 = 0.6, NO = 100/250 = 0.4
- **Probabilité** : P(YES) = 60%, P(NO) = 40%

### Prix pour acheter plus
- **Coût moyen** : Si on veut 10 YES de plus
  - Prix actuel : 0.6
  - Prix futur : 160/260 ≈ 0.615
  - Prix moyen : (0.6 + 0.615) / 2 ≈ 0.608
  - **Coût total** : 10 × 0.608 = 6.08 USDC

## ✅ Avantages
1. **Simple** : Prix = probabilité directe
2. **Intuitif** : Plus de demande = prix plus élevé
3. **Conservatif** : Somme des prix = 1.0 toujours
4. **Efficace** : Pas de calculs complexes CPMM

## 🔄 Différence avec l'ancien système
- **Avant** : CPMM complexe avec mint+swap
- **Maintenant** : Prix proportionnel aux shares directement
