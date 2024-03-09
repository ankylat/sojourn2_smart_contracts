// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { Owned } from "solmate/src/auth/Owned.sol";

// welcome to the smart contract of $newen, the token of the ankyverse
//
// this whole story is just a vehicle for harnessing life force.
// and focusing it inside you. through you. from there to the outside.
// on the quest of experiencing your being.
// through the power of your words.
//
// anky and all of what comes with it is just an excuse.
// for you to explore who you are.
//
// thank you for being.
//
// TOKENOMICS
// 15% of the token will go to the liquidity pool
// 15% of the token will be distributed as rewards for liquidity providers
// 6% of the token will be for the team and vested as a stream until the 1st of october of 2026
// 64% of it will be used to reward people that will write the eight books of anky - 8% for each one
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

// on the 1st of october of 2026, the whole supply of $newen will be free.

contract Newen is ERC20, Owned {
    uint constant SUPPLY = 1_618_033_969 ether;
    constructor() ERC20("Newen", "NEWEN", 18) Owned(msg.sender) {
        _mint(msg.sender, SUPPLY);
    }

    function renounceOwnership() external onlyOwner {
        transferOwnership(address(0));
    }
}

