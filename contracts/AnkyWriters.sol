// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract AnkyverseNFT is ERC721Burnable, ReentrancyGuard {
    uint256 public constant NFT_PRICE = 0.1 ether;
    uint256 public constant MAX_NFTS_FIRST_CYCLE = 192;
    uint256 public saleStartTime;
    uint256 public totalMinted;
    address payable public treasury; // Address to send remaining Ether to on self-destruct

    // Track the buyers for potential refunds
    mapping(address => uint256) public buyerToAmountPaid;

    event SaleWindowOpened(uint256 saleStartTime);
    event ContractTerminated(address treasury);

    constructor(address payable _treasury) ERC721("Anky Writers", "ANKWRTRS") {
        saleStartTime = block.timestamp;
        treasury = _treasury;
        emit SaleWindowOpened(saleStartTime);
    }

    function mintNFT() external payable nonReentrant {
        require(block.timestamp <= saleStartTime + 7 days, "Sale window has closed");
        require(totalMinted < MAX_NFTS_FIRST_CYCLE, "Maximum NFTs for the cycle minted");
        require(msg.value == NFT_PRICE, "Incorrect ETH value");

        buyerToAmountPaid[msg.sender] += msg.value;
        totalMinted++;
        _safeMint(msg.sender, totalMinted);
    }

    function terminateContract() external {
        // Additional checks can be added here to ensure this function
        // is only called under the right conditions, such as unsuccessful sale
        require(block.timestamp > saleStartTime + 7 days, "Sale window still open");
        require(totalMinted < MAX_NFTS_FIRST_CYCLE, "Sale was successful, cannot terminate");

        emit ContractTerminated(treasury);
        selfdestruct(treasury);
    }

    // Other functions...
}
