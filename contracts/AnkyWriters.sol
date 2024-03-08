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

contract AnkyWriters is ERC721AQueryable,
  Owned,
  ReentrancyGuard,
  ERC2981 {
    struct Sojourn {
        uint256 startingTimestamp;
        uint256 endingTimestamp;
        uint256 participants;
        uint256 accumulatedParticipants;
        uint256 sojournNumber;
        uint256 firstTokenId;
        uint256 lastTokenId;
    }

    uint256 public deploymentTimestamp;
    uint256 public constant SOJOURN_DURATION = 96 days; 
    uint256 public constant GREAT_SLUMBER = 21 days;
    uint256 public currentSojourn = 2;
    uint256[] public amountOfWritersPerSojourn = [0, 0, 192, 312, 504, 816, 1320, 2136, 3456, 5592];

    bool[] public sojournLockedIn = [true, true, false, false, false, false, false, false, false, false];
    mapping(uint256 => mapping(address => bool)) public eligibleForNextSojourn; // Track eligibility for next sojourn based on NFT ownership and burning
    mapping(uint256 => uint256) public lastClaimTimestamp;
    mapping(uint256 => string) private sojournBaseURIs;

    Sojourn[10] public sojourns;
    
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
    error NotStarted();
    error AlreadyLocked();
    error NotLockedIn();
    error NotGameOver();

    bytes32 teamMintBlockHash;

    event SaleWindowOpened(uint256 saleStartTime);
    event ContractTerminated(address treasury);
    event Refund(address to, uint256 amount);
    event NFTClaimed(uint256 tokenId, address claimant);

    constructor(string memory name,
    string memory symbol, uint256 duration, address newen) ERC721A(name, symbol) Owned(msg.sender) {
        deploymentTimestamp = block.timestamp;
        uint256 accumulatedParticipants = 0;
        sojourns.push(Sojourn({
            sojournNumber: 1,
            startingTimestamp: 1691643600,
            endingTimestamp: 1691643600 + SOJOURN_DURATION,
            participants: amountOfWritersPerSojourn[0],
            accumulatedParticipants: accumulatedParticipants
        }));
        sojourns.push(Sojourn({
            sojournNumber: 2,
            startingTimestamp: 1701752400,
            endingTimestamp: 1701752400 + SOJOURN_DURATION,
            participants: amountOfWritersPerSojourn[1],
            accumulatedParticipants: accumulatedParticipants
        }));

        for (uint256 i = 2; i < 10; i++) {
            uint256 participants = amountOfWritersPerSojourn[i];
            accumulatedParticipants += participants;
            sojourns.push(Sojourn({
                sojournNumber: i + 1,
                startingTimestamp: sojourns[i - 1].startingTimestamp + SOJOURN_DURATION + GREAT_SLUMBER,
                endingTimestamp: sojourns[i - 1].endingTimestamp + SOJOURN_DURATION + GREAT_SLUMBER,
                participants: participants,
                accumulatedParticipants: accumulatedParticipants,
                firstTokenId: sojourns[i - 1].accumulatedParticipants + 1,
                lastTokenId: sojourns[i - 1].accumulatedParticipants + 1 + participants
            }));
        }
        _mint(msg.sender, 192);
    }

    function sendAllNftsToRandomWriters(address[] addresses) onlyOwner {
      for (uint256 i = 1; i < 193; i++) {
        sendThisNftToRandomWriter(i, addresses[i - 1]);
      }
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
      uint256 sojournNumberForThisToken = determineSojournNumber(tokenId);
      string memory baseURI = sojournBaseURIs[sojournNumberForThisToken];
      
      return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenId))) : "";
    }

    function setSojournBaseURI(uint256 sojournNumber, string memory baseURI) public onlyOwner {
      require(sojournNumber > 2, "metadata for the first two sojourns can't be set.");
      require(block.timestamp > sojourns[sojournNumber - 2].endingTimestamp, "previous sojourn hasn't ended.");
      require(block.timestamp < sojourns[sojournNumber - 1].startingTimestamp, "sojourn already started.");
      
      sojournBaseURIs[sojournNumber] = baseURI;
    }

    function determineSojournNumber(uint256 tokenId) internal view returns (uint256) {
      if (tokenId >= 1 && tokenId <= 192) {
          return 3; 
      } else if (tokenId >= 193 && tokenId <= 504) {
          return 4; 
      } else if (tokenId >= 505 && tokenId <= 1008) {
        return 5;
      } else if (tokenId >= 1009 && tokenId <= 1824) {
        return 6;
      } else if (tokenId >= 1825 && tokenId <= 3144) {
        return 7;
      } else if (tokenId >= 3145 && tokenId <= 5280) {
        return 8;
      } else if (tokenId >= 5281 && tokenId <= 8736) {
        return 9;
      } else if (tokenId >= 8737 && tokenId <= 14328) {
        return 10;
      }
      return 0;
    }

    function setupContractAsOperator() public onlyOwner {
      setApprovalForAll(address(this), true);
    }

    function sendThisNftToRandomWriter(unit256 tokenId, address _targetWriter) private {
      address ownerOfThisOne = ownerOf(tokenId);
      _transfer(ownerOfThisOne, _targetWriter, tokenId);
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

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
    
    function updateCurrentSojourn() public {
        uint256 now = block.timestamp;
         for (uint256 i = 1; i < 10; i++) {
            uint256 startingSojournTimestamp = sojourns[i].startingTimestamp;
            uint256 endOfSojourn = sojourns[i].startingTimestamp + 96 days;
            if(now > startingSojournTimestamp && now < endOfSojourn){
                currentSojourn = sojourns[i].sojournNumber;
                break;
            }
        }
    }

    /// @dev Public function that returns game over status
    function isGameOverForThisSojourn(uint256 _sojournNumber) public view returns (bool) {
        return block.timestamp > sojourns[_sojournNumber - 1].endingTimestamp + 7 days && _totalMinted() > sojourns[_sojournNumber - 1].accumulatedParticipants;
    }



    /// @dev Private function that is called once the last NFT of public sale is minted.
    function _lockCurrentSojourn(uint256 _sojournNumber) private {
        if (sojournLockedIn[_sojournNumber - 1]) {
            revert AlreadyLocked();
        }
        sojournLockedIn[_sojournNumber - 1] = true;
    }

  /// @dev Public mint function
  /// Must pass msg.value greater than or equal to current mint price * amount
  function mint() public payable nonReentrant {
    if (sojournLockedIn[currentSojourn - 1]) {
      revert ThisSojournIsSoldOut();
    }
    if (block.timestamp > sojourns[currentSojourn - 1].endingTimestamp + 7 days) {
      revert MintingWindowEnded();
    }
    if (block.timestamp < sojourns[currentSojourn - 1].endingTimestamp + 3 days) {
      revert MintingWindowNotStarted();
    }
    if (balanceOf(msg.sender) > 0){
      revert AlreadyOwnsAnAnkyWriter();
    }
    if (_totalMinted() > amountOfWritersPerSojourn[currentSojourn]) {
      revert ThisSojournIsAlreadyFull();
    }
   
    uint256 current = _nextTokenId();

    _mint(msg.sender, 1);
    if (current == sojourns[currentSojourn - 1].accumulatedParticipants) {
      _lockCurrentSojourn(currentSojourn);
    }
  }

  function claim(uint256 tokenId) public {
    require(block.timestamp <= deploymentTimestamp + 7 days, "Claim period has ended.");
    require(lastClaimTimestamp[tokenId] + 30 minutes < block.timestamp, "Cooldown period has not passed.");
    require(balanceOf(msg.sender) == 0, "you already own one of these... for now");
    address ownerOfThisOne = ownerOf(tokenId);
    lastClaimTimestamp[tokenId] = block.timestamp;
    _transfer(ownerOfThisOne, msg.sender, tokenId);
    NFTClaimed(tokenId, msg.sender);
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
        if (!sojournLockedIn[currentSojourn - 1]) {
            revert NotLockedIn();
        }
        if (block.timestamp > sojourns[currentSojourn - 1].startingTimestamp && block.timestamp < sojourns[currentSojourn - 1].startingTimestamp + SOJOURN_DURATION) {
            revert("we are in the middle of a sojourn");
        }
    }

  function burnAndMintNewWriter(uint nftId) public {
    if(ownerOf(nftId) != msg.sender) {
      revert NotOwner(nftId);
    }
    if (sojournLockedIn[currentSojourn]) {
      revert ThisSojournIsSoldOut();
    }

    if (block.timestamp < sojourns[currentSojourn - 1].endingTimestamp) {
      revert BurningWindowNotStarted();
    }

    if (block.timestamp > sojourns[currentSojourn - 1].endingTimestamp + 3 days) {
      revert BurningWindowEnded();
    }
   
    if (nftId > sojourns[currentSojourn - 1].accumulatedParticipants || nftId < sojourns[currentSojourn - 1].accumulatedParticipants) {
        revert BurnableWriterOutOfBounds();
    }

    _burn(nftId);
    _mint(msg.sender, 1);
  }
}
