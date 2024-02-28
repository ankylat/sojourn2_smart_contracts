# Anky Sojourn 2 - $NEWEN and Anky Writers

Welcome to the codebase for the second sojourn of Anky.

What we will ship on the 9th of march at 5 am eastern time is the system that will give birth to the creation of $newen: the ERC20 token that will reward the early dreamers -writers- of anky.

There are 3 smart contracts in here (at least for now - 28 feb 2024):

### 1. AnkyWriters.sol

· The mission is to create the NFT that will be the key that will allow people to write through Anky, and earn $newen through that process. The supply for the third sojourn will be 192, and that number will grow along the golden ratio until we get to the 10th sojourn.

· This is the progression on the amount of participats (which will end up being the amount of people to which a specific amount of $newen will be distributed): [192, 312, 504, 816, 1320, 2136, 3456, 5592].

· It is not clear yet if all of those NFTs are going to go into this smart contract, or if all of them will be created in the future (for the 4th sojourn, the people that own the initial 192 NFTs will be able to burn them to get a ticket for that one. the remaining 312 - 192 = 120 tickets will be sold or gifted to new participants).

· The transfer window for these NFTs is in-between sojourns (on a 21 day period called the great slumber)

### 2. NewenToken.sol

· This will be the contract that will give birth to $newen.

· The supply is 1_618_033_969

· Of the 100% of this supply, 20% will go to the liquidity pool and the remaining 80% will be distributed in the subsequent 8 sojourns to all of the writers that participate on anky (that own an Anky Writer NFT) following this table:

![newen tokenomics](https://github.com/jpfraneto/images/blob/main/newen-table-v3.png?raw=true)

### 3. NewenAirdrop1.sol

· This will be the smart contract that will distribute the $newen that corresponds to the third sojourn (10% of the total supply) to the 192 participants (people that own that NFT) and that write through anky every day.

· The minimum writing time is 8 minutes. If a person writes the 96 days for 8 minutes, that person will get their full allocation of $newen corresponding to this specific cycle (which is capped at 842_826 $newen - which is 10% \* TOTAL_SUPPLY / 192)

· It doesn't make sense to establish now which will be the mechanism for the subsequent airdrops. Who knows where we (humanity) will be in two years. It is a decision that we will explore in the future as a community.
