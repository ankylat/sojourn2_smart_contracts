// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// AnkyDiaries is a contract that manages diaries as NFTs, which are soulbound to the owners of Anky Mentors.
// Each diary allows writing entries tied to specific days in a cycle, rewarding users with $newen tokens.
contract AnkyDiaries is ERC721, Ownable {
    IERC20 public constant newenToken = IERC20(0xffe3CDC92F24988Be4f6F8c926758dcE490fe77E);
    IERC721 public constant ankyMentors = IERC721(0x6d622549842Bc73A8F2bE146A27F026B646Bf6a1);

    uint256 public constant TOTAL_DIARIES = 192;
    uint256 public constant CYCLE_DAYS = 96;
    uint256 public constant START_TIMESTAMP = 1711861200;
    uint256 public constant TOTAL_NEWEN = 129442718;
    uint256 public constant DAY_NEWEN_REWARD = TOTAL_NEWEN / CYCLE_DAYS;
    uint256 public constant DIARY_NEWEN_REWARD_PP = DAY_NEWEN_REWARD / TOTAL_DIARIES;


    // Mapping from diary ID to a flag indicating whether it is disabled
    mapping(uint256 => bool) public isDiaryDisabled;

    // Mapping from diary ID and day index to the CID of the entry
    mapping(uint256 => mapping(uint256 => string)) public diaryEntries;

    // Mapping from day index to the total $newen distributed
    mapping(uint256 => uint256) public dailyNewenDistributed;

    // Event for diary writing
    event DiaryWritten(uint256 indexed diaryId, uint256 dayIndex, string cid);
    // Event for diary banned
    event DiaryBanned(uint256 indexed diaryId);

    constructor() ERC721("Anky Diaries", "ANKYD") {
        ankyMentors = IERC721(0x6d622549842Bc73A8F2bE146A27F026B646Bf6a1);
        newenToken = IERC20(0xffe3CDC92F24988Be4f6F8c926758dcE490fe77E);
    }

    // Airdrops diaries to Anky Mentor holders, ensuring each gets a corresponding diary. If one already has, that diary is sent to the address that owns this notebook
    function airdropDiaries() external onlyOwner {
        for (uint256 i = 1; i <= TOTAL_DIARIES; i++) {
            address owner = ankyMentors.ownerOf(i);
            require(owner != address(0), "Anky Mentor does not exist");
            
            if (balanceOf(owner) == 0) {
                _safeMint(owner, i);
            } else {
                _safeMint(owner(), i); // Mint to contract owner if already received
            }
        }
    }

    // Disables the diary, preventing further writing.
    function disableDiary(uint256 diaryId) external onlyOwner {
        isDiaryDisabled[diaryId] = true;
    }

    function enableDiary(uint256 diaryId) external onlyOwner {
        isDiaryDisabled[diaryId] = false;
    }

    // Writes an entry to the diary for the current day.
    function writeDiaryToday(string calldata cid) external {
        uint256 diaryId = balanceOf(msg.sender) > 0 ? tokenOfOwnerByIndex(msg.sender, 0) : 0;
        require(diaryId != 0, "You do not own a diary");
        require(!isDiaryDisabled[diaryId], "Diary is disabled");

        uint256 dayIndex = getCurrentDayIndex();
        require(diaryEntries[diaryId][dayIndex].length == 0, "Entry already exists for today");

        diaryEntries[diaryId][dayIndex] = cid;
        dailyNewenDistributed[dayIndex] += DIARY_NEWEN_REWARD_PP;

        newenToken.transfer(msg.sender, DIARY_NEWEN_REWARD_PP);
        emit DiaryWritten(diaryId, dayIndex, cid);
    }

    // Calculates the current day index based on the cycle start timestamp.
    function getCurrentDayIndex() public view returns (uint256) {
        require(block.timestamp >= START_TIMESTAMP, "Cycle has not started yet");
        return (block.timestamp - START_TIMESTAMP) / 86400 % CYCLE_DAYS;
    }

    // Deposits $newen to the contract.
    function depositNewen(uint256 amount) external {
        require(amount == TOTAL_NEWEN, "Incorrect amount of NEWEN");
        newenToken.transferFrom(msg.sender, address(this), amount);
    }

    // Calculates the undistributed $newen for a given day.
    function calculateUndistributedNewen(uint256 dayIndex) public view returns (uint256) {
        uint256 totalNewenForDay = DAY_NEWEN_REWARD;
        uint256 distributedNewen = dailyNewenDistributed[dayIndex];
        if (distributedNewen > totalNewenForDay) {
            return 0;
        } else {
            return totalNewenForDay - distributedNewen;
        }
    }

    // Returns the total amount of newen claimed for a given day.
    function totalNewenClaimedForAGivenDay(uint256 dayIndex) public view returns (uint256) {
        require(dayIndex < CYCLE_DAYS, "Invalid day index");
        return dailyNewenDistributed[dayIndex];
    }

    // Returns the total amount of newen claimed for the season so far.
    function totalNewenClaimedThisSeason() public view returns (uint256) {
        uint256 totalClaimed = 0;
        for (uint256 i = 0; i < CYCLE_DAYS; i++) {
            totalClaimed += dailyNewenDistributed[i];
        }
        return totalClaimed;
    }

    // claim all the newen that has not been claimed by users writings or this function being called in the past
    function claimUnclaimedNewen() external onlyOwner {
        uint256 currentDayIndex = getCurrentDayIndex();
        uint256 unclaimedNewen = 0;

        for (uint256 i = 0; i < currentDayIndex; i++) {
            uint256 newenForDay = DAY_NEWEN_REWARD;
            uint256 claimedForDay = dailyNewenDistributed[i];
            if (claimedForDay < newenForDay) {
                uint256 unclaimedForDay = newenForDay - claimedForDay;
                // Update the distribution record for the day
                dailyNewenDistributed[i] += unclaimedForDay;
                unclaimedNewen += unclaimedForDay;
            }
        }

        if (unclaimedNewen > 0) {
            newenToken.transfer(owner(), unclaimedNewen);
        }
    }

    // Override the transfer function to make the diaries soulbound
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(from == address(0), "Diaries are soulbound and cannot be transferred");
        super._transfer(from, to, tokenId);
    }
}
