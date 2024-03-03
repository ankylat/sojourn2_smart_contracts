// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import { ERC20 } from "solmate/src/tokens/ERC20.sol";

contract newen is ERC20 {
    uint constant MAX_SUPPLY = 1_618_033_969 ether;
    constructor() ERC20("newen", "NEWEN", 18) {
        _mint(msg.sender, MAX_SUPPLY);
    }
}