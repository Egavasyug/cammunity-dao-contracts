
---

## 🚀 Initial Mint Instructions (CAMC Token Allocation)

After deploying `CamuCoin.sol`, run the following function from the contract owner’s wallet (or via multisig if transferred):

```solidity
initialMint(treasuryAddress, vestingWrapperAddress, lpWalletAddress);
```

### 💡 Example:
```
initialMint(
  0xYourTreasuryWallet,
  0xYourVestingWrapper,
  0xYourLPWallet
);
```

### ⛏️ Minted Allocation:
- 1,200,000 CAMC → DAO Treasury
- 400,000 CAMC → Vesting Wrapper (Creator Unlock System)
- 400,000 CAMC → LP / Founders Wallet

🛡️ This function can only be called once.

---
