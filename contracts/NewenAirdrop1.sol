// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @notice Newen Airdrop 1, distributes tokens to all of the first owners of the Anky Writers NFT, based on their writings through the platform.
 * @dev Slightly modified version of: https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributorWithDeadline.sol
 * Changes include:
 * - remove "./interfaces/IMerkleDistributor.sol" inheritance
 * @custom:security-contact jp@anky.lat
 */

contract NewenAirdropOne is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     *  @dev The token to be distributed
     */
    address public immutable NEWEN_TOKEN;

    /**
     *  @dev The merkle root of the distribution
     */
    bytes32 public immutable MERKLE_ROOT;

    /**
     *  @dev The time after which the airdrop can no longer be claimed
     */
    uint256 public immutable END_TIME;

    /**
     *  @dev This event is triggered whenever a call to #claim succeeds
     */
    event Claimed(
        uint256 indexed usersWriterIndex,
        address indexed account,
        uint256 indexed amount
    );

    /**
     *  @dev The airdrop has already been claimed
     */
    error AlreadyClaimed();

    /**
     *  @dev The merkle proof is invalid
     */
    error InvalidProof();

    /**
     *  @dev The end time is in the past
     */
    error EndTimeInPast();

    /**
     *  @dev The claim window has finished
     */
    error ClaimWindowFinished();

    /**
     *  @dev Cannot withdraw during the claim window
     */
    error NoWithdrawDuringClaim();

    IERC20 public newenToken;
    IERC721 public ankyWriters;
    
    uint256 public constant RESONANCE_WAVE_DURATION = 8 days;
    uint256 public startingTimestamp;
    uint256 public resonanceWavesCount = 12;
    bytes32[12] private merkleRootsForResonanceWave; // this will store the merkle root for each resonance wave

    mapping(uint256 => mapping(address => bool)) public hasUserClaimedInResonanceWave; // resonance wave -> address -> claimedStatus
    
    constructor(address _newenToken, address _ankyWriters, uint256 _startTimestamp, uint256 _endTime) Ownable(msg.sender) {
        if (endTime_ <= block.timestamp) revert EndTimeInPast();
        require(_newenToken != address(0) && _ankyWriters != address(0), "Invalid addresses");
        END_TIME = _endTime;
        NEWEN_TOKEN = _newenToken;
        ankyWriters = IERC721(_ankyWriters);
        startTimestamp = block.timestamp; // The moment on which this contract is deployed (at the beginning of the third sojourn)
    }

    /**
     *  @dev Returns true if the index has been marked claimed
     *  @param index The index of the claimer in the merkle tree - index of the anky writers nft
     */
    function isClaimed(uint256 _ankyWritersIndex, uint256 _cycle) public view returns (bool) {
        address ownerOfThisAnkyWriterAddress = ankyWriters.ownerOf(_ankyWritersIndex);
        return hasUserClaimedInCycle[_cycle][ownerOfThisAnkyWriterAddress];
    }

    /**
     *  @dev Marks the index as claimed
     *  @param index The index of the claimer in the merkle tree
     */
    function _setClaimed(uint256 _ankyWritersIndex, uint256 _cycle) private {
        address ownerOfThisAnkyWriterAddress = ankyWriters.ownerOf(_ankyWritersIndex);
        hasUserClaimedInCycle[_cycle] = true;
    }
    
    function getCurrentResonanceWave() public view returns (uint256) {
        if(block.timestamp < startTimestamp) {
            return 0;
        }
        return ((block.timestamp - startTimestamp) / RESONANCE_WAVE_DURATION) + 1;
    }

    /**
     *  @dev Claim the given amount of the token to the given address
     *  @param index The index of the claimer in the merkle tree
     *  @param account The account to receive the tokens
     *  @param amount The amount of tokens to claim
     *  @param merkleProof The merkle proof of this airdrop. this will be updated every 8 days.
     */
    function claim(
        uint256 _ankyWritersIndex,
        uint246 _resonanceWave,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external virtual {
        if (block.timestamp > END_TIME) revert ClaimWindowFinished();
        if (isClaimed(_ankyWritersIndex, _resonanceWave)) revert AlreadyClaimed();
        uint256 currentResonanceWave = getCurrentResonanceWave();
        require(currentResonanceWave <= resonanceWaveCount, "newen airdrop 1 is over -> the third sojourn ended");
        require(ankyWriters.ownerOf(_userAnkyWriterId) == msg.sender, "you are not the owner of this anky writer");
        require(!hasClaimed[currentResonanceWave][msg.sender], "you already claimed your newen for this cycle");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(_ankyWritersIndex, account, amount));

        // Q: WHERE DOES THE merkleProof come from?

        if (!MerkleProof.verify(merkleProof, merkleRootsForResonanceWave[currentResonanceWave], node))
            revert InvalidProof();

        // Mark it claimed and send the token.
        _setClaimed(_ankyWritersIndex, currentResonanceWave);
    
        IERC20(TOKEN).safeTransfer(account, amount);

        emit Claimed(_ankyWritersIndex, account, amount);
    }

    /**
     *  @dev Withdraw the remaining tokens after the claim window has finished
     */
    function withdraw() external onlyOwner {
        if (block.timestamp < END_TIME) revert NoWithdrawDuringClaim();

        IERC20(TOKEN).safeTransfer(
            msg.sender,
            IERC20(TOKEN).balanceOf(address(this))
        );
    }
}
