// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import { ud } from "@prb/math/src/UD60x18.sol";
import { ERC20 } from "solmate/src/tokens/ERC20.sol";
import { Owned } from "solmate/src/auth/Owned.sol";
import { ReentrancyGuard } from "solmate/src/utils/ReentrancyGuard.sol";
import { ERC721A, ERC721AQueryable } from "erc721a/contracts/extensions/ERC721AQueryable.sol";
import { ERC2981 } from "@openzeppelin/contracts/token/common/ERC2981.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IERC721A } from "erc721a/contracts/interfaces/IERC721A.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// IDEA: implement erc6551 and have each day for the whole process be an nft that can't be transferred and that can  only be burned if the user writes that day on anky

contract AnkyWriters is ERC721AQueryable,
  Owned,
  ReentrancyGuard,
  ERC2981 {
    uint256 public thirdSojournStartTimestamp;
    uint256 public thirdSojournEndTimestamp;
    uint256 public constant SOJOURN_DURATION = 96 days;
    uint256 public constant GREAT_SLUMBER = 21 days;
    uint256[9] public sojournStartTimestamps;
    uint256[9] public sojournEndTimestamps;
    uint256 public currentSojourn = 1;
    uint256[] public amountOfWritersPerSojourn = [0, 192, 312, 504, 816, 1320, 2136, 3456, 5592]; 
    uint256[] public writersIndexForEachSojourn = [0, 192, 504, 1008, 1824, 3144, 5280, 8736, 14328];
    uint256[9] public finalCost;
    bool[] public sojournLockedIn = [true, false, false, false, false, false, false, false, false];
    mapping(uint256 => mapping(address => bool)) public eligibleForNextSojourn; // Track eligibility for next sojourn based on NFT ownership and burning

    uint256 public MAX_SUPPLY;
    uint256 public MAX_PUB_SALE = 120;
    uint256 public MAX_TEAM = 72;
    uint256 public DURATION;
    uint256 public MIN_PRICE = 0.001 ether;
    uint256 public MAX_PRICE = 0.1 ether;
    uint256 public DISCOUNT_RATE;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalEthClaimed;
    address public erc20Address;
    mapping(uint256 => uint256) public _rewardDebt;
    mapping(uint256 => TokenMintInfo) public tokenMintInfo;
    struct TokenMintInfo {
        bytes32 seed;
        uint256 cost;
    }
    
    address payable public treasury; // Address to send remaining Ether to on self-destruct

    error IncorrectPayment();
    error InvalidTokenId(uint256 tokenId);
    error NotOwner(uint256 tokenId);
    error MintingWindowEnded();
    error MintingWindowNotStarted();
    error ThisSojournIsSoldOut();
    error AlreadyOwnsAnAnkyWriter();
    error ThisSojournIsAlreadyFull();
    error BurningWindowEnded();
    error BurningWindowNotStarted();
    error BurnableWriterOutOfBounds();
    error AmountRequired();
    error NotStarted();
    error AlreadyLocked();
    error NotLockedIn();
    error NotGameOver();

    address teamMintWallet;
    bytes32 teamMintBlockHash;

    // Track the buyers for potential refunds
    mapping(address => uint256) public buyerToAmountPaid;

    event SaleWindowOpened(uint256 saleStartTime);
    event ContractTerminated(address treasury);
    event Refund(address to, uint256 amount);

    uint256 private _totalFees;

    /// @dev Function to get the total fees accumulated over time
    function getFeeBalance() public view returns (uint256) {
        return _totalFees;
    }

    constructor(string memory name,
    string memory symbol, uint256 duration, address newen) ERC721A(name, symbol) Owned(msg.sender) {
        thirdSojournStartTimestamp = 1711861200;  
        thirdSojournEndTimestamp = 1711861200 + 96 days;
        erc20Address = newen;
        startTime = block.timestamp;
        endTime = startTime + duration;
        MAX_SUPPLY = MAX_TEAM + MAX_PUB_SALE;
        DURATION = duration;
        DISCOUNT_RATE = ud(MAX_PRICE - MIN_PRICE)
            .div(ud((duration) * 10**18))
            .intoUint256();
        teamMintWallet = msg.sender;
        _mintERC2309(teamMintWallet, MAX_TEAM); // this comes from ERC721A
        teamMintBlockHash = blockhash(block.number - 1);
        sojournStartTimestamps[0] = 1711861200 - 21 days - 96 days; // when the third sojourn starts
        sojournEndTimestamps[0] = 1711861200 - 21 days; // when the third sojourn ends
        sojournStartTimestamps[1] = 1711861200; // when the third sojourn starts
        sojournEndTimestamps[1] = 1711861200 + 96 days; // when the third sojourn ends
        uint256 sojournStartVar;
        for (uint256 i = 2; i < 9; i++) {
            sojournStartVar = sojournStartTimestamps[i - 1] + SOJOURN_DURATION + GREAT_SLUMBER;
            sojournStartTimestamps[i] = sojournStartVar;
            sojournEndTimestamps[i] = sojournStartVar + 96 days;
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC721A, ERC721A, ERC2981)
        returns (bool)
    {
        return
        super.supportsInterface(interfaceId) ||
        ERC2981.supportsInterface(interfaceId);
    }

    function withdrawErc20(address token, address to) public onlyOwner {
        ERC20(token).transfer(to, ERC20(token).balanceOf(address(this)));
    }

    /// @dev Function to manually migrate ETH from contract
    /// Can be disabled by changing owner to address(0)
    function migrate(uint256 amount) public onlyOwner {
        Address.sendValue(payable(owner), amount);
    }

    /// @dev Public function that can be used to calculate the pending ETH payment for a given NFT ID
    function calculatePendingPayment(uint256 nftId)
        public
        view
        returns (uint256)
    {
        uint256 a = getFeeBalance() + totalEthClaimed - _rewardDebt[nftId];
        if (a == 0) return 0;
        return ud(a).div(ud(MAX_SUPPLY * 10**18)).intoUint256();
    }



    /// @dev Get on-chain token URI
    /// Accounts for NFTs that were minted using ERC-2309
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A, IERC721A)
        returns (string memory)
    {
        return "";
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /// @dev Public function that returns game over status
    function isGameOver() public view returns (bool) {
        return block.timestamp > endTime && _totalMinted() < MAX_SUPPLY;
    }

    /// @dev Private function to redeem mint costs for a given NFT ID
    function _redeem(uint256 tokenId) private {
        if (tokenMintInfo[tokenId].cost == 0) {
        revert InvalidTokenId(tokenId);
        }
        if (ownerOf(tokenId) != msg.sender) {
        revert NotOwner(tokenId);
        }
        uint256 amount = tokenMintInfo[tokenId].cost;
        Address.sendValue(payable(msg.sender), amount);
        tokenMintInfo[tokenId].cost = 0;
        emit Refund(msg.sender, amount);
    }

    /// @dev Public function to redeem mint costs for multiple NFT IDs
    /// This function can only be called if game over is true.
    function redeem(uint256[] memory tokenIds) public nonReentrant {
        if (!isGameOver()) {
            revert NotGameOver();
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _redeem(tokenIds[i]);
        }
    }

    function _claimRefund(uint256 tokenId) private {
        if (tokenMintInfo[tokenId].cost == 0) {
            revert InvalidTokenId(tokenId);
        }
        if (ownerOf(tokenId) != msg.sender) {
            revert NotOwner(tokenId);
        }
        if (tokenMintInfo[tokenId].cost > finalCost[currentSojourn]) {
            uint256 amount = tokenMintInfo[tokenId].cost - finalCost[currentSojourn];
            Address.sendValue(payable(msg.sender), amount);
            emit Refund(msg.sender, amount);
        }
        tokenMintInfo[tokenId].cost = 0;
    }

    /// @dev This function disables transfers until mint is complete.
    /// TODO: Disable transfers in between sojourns
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        if (from == address(0)) return;
        if (!sojournLockedIn[currentSojourn]) {
            revert NotLockedIn();
        }
        if (block.timestamp < sojournStartTimestamps[currentSojourn] && block.timestamp > sojournEndTimestamps[currentSojourn]) {
            revert("we are in the middle of the third sojourn");
        }
    }

    /// @dev Private function that is called once the last NFT of public sale is minted.
    function _lockCurrentSojourn(uint256 _sojournNumber) private {
        if (sojournLockedIn[_sojournNumber]) {
            revert AlreadyLocked();
        }
        sojournLockedIn[_sojournNumber] = true;
    }

    /// @dev Gets the current mint price for dutch auction
    function getCurrentMintPrice() public view returns (uint256) {
        if (block.timestamp < startTime) {
            revert NotStarted();
        }
        uint256 timeElapsed = block.timestamp - startTime;
        uint256 discount = DISCOUNT_RATE * timeElapsed;
        if (discount > MAX_PRICE) return MIN_PRICE;
        return MAX_PRICE - discount;
    }

  /// @dev Public mint function
  /// Must pass msg.value greater than or equal to current mint price * amount
  function mint() public payable nonReentrant {
    if (sojournLockedIn[currentSojourn]) {
      revert ThisSojournIsSoldOut();
    }
    if (block.timestamp > sojournEndTimestamps[currentSojourn - 1] + 7 days) {
      revert MintingWindowEnded();
    }
    if (block.timestamp < sojournEndTimestamps[currentSojourn - 1] + 3 days) {
      revert MintingWindowNotStarted();
    }
    if (balanceOf(msg.sender) > 0){
      revert AlreadyOwnsAnAnkyWriter();
    }
    if (_totalMinted() > amountOfWritersPerSojourn[currentSojourn]) {
      revert ThisSojournIsAlreadyFull();
    }
   
    uint256 mintPrice = getCurrentMintPrice();

    if (msg.value < mintPrice) {
      revert IncorrectPayment();
    }
    uint256 current = _nextTokenId();

    tokenMintInfo[current] = TokenMintInfo({
        seed: keccak256(abi.encodePacked(blockhash(block.number - 1), current)),
        cost: mintPrice
    });

    uint256 refund = msg.value - mintPrice;
    if (refund > 0) {
      Address.sendValue(payable(msg.sender), refund);
    }
    _mint(msg.sender, 1);
    if (current == amountOfWritersPerSojourn[currentSojourn]) {
      _lockCurrentSojourn(currentSojourn);
    }
  }

  function burnAndMintNewWriter(uint nftId) public {
    if(ownerOf(nftId) != msg.sender) {
      revert NotOwner(nftId);
    }
    if (sojournLockedIn[currentSojourn]) {
      revert ThisSojournIsSoldOut();
    }
    if (block.timestamp > sojournEndTimestamps[currentSojourn - 1] + 3 days) {
      revert BurningWindowEnded();
    }

    if (block.timestamp < sojournEndTimestamps[currentSojourn - 1]) {
      revert BurningWindowNotStarted();
    }
    if(nftId > writersIndexForEachSojourn[currentSojourn] || nftId < writersIndexForEachSojourn[currentSojourn - 1]) {
        revert BurnableWriterOutOfBounds();
    }

    _burn(nftId);
    _mint(msg.sender, 1);
  }
}
