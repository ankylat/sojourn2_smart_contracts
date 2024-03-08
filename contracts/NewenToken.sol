// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import { ERC20 } from "solmate/src/tokens/ERC20.sol";

// welcome to the smart contract of $newen, the token of the ankyverse
// this is an ancient word, that is used by the mapuche culture to speak about life force
// you see. 
// in many ways, this whole story is just a vehicle for harnessing life force
// and focusing it inside you 
// on the quest of understanding.
// of experiencing.
// through the power of your words.
//
// anky and all of what comes with it is just an excuse.
// for you to explore who you are
//
// TOKENOMICS
// 20% of it will go to the liquidity pool
// 80% of it will be used to reward people that will write the eight books of anky
// 10% for each one of the next 8 sojourns.
// 
// the starting timestamps of each one of them are:
//
// third sojourn - primordia - 1711861200 - March 31, 2024
// fourth sojourn - emblazion - 1721970000 - July 26, 2024
// fifth sojourn - chryseos - 1732078800 - November 20, 2024
// sixth sojourn - eleasis - 1742187600 - March 17, 2025
// seventh sojourn - voxlumis - 1752296400 - July 12, 2025
// eigth sojourn - insightia - 1762405200 - November 6, 2025
// ninth sojourn - claridium - 1772514000 - March 3, 2026
// tenth sojourn - poiesis - 1782622800 - June 28, 2026

contract NewenToken is ERC20 {
    uint constant MAX_SUPPLY = 1_618_033_969 ether;
    constructor() ERC20("newen", "newen", 18) {
        _mint(msg.sender, MAX_SUPPLY);
    }
}