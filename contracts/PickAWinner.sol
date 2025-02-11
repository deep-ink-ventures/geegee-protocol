// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PickAWinner is Ownable {

    /**
     * @notice The number of slots available for purchase.
     */
    uint256 public numSlots;

    /**
     * @notice The price of a slot in native currency.
     */
    uint256 public slotPriceInNative;

    /**
     * @notice The slots that have been purchased.
     */
    address[] public slots;

    /**
     * @notice Hash of the index sequence and salt for proving the provenance of the winner.
     */
    bytes32 public provenanceHash;

    /**
     * @notice The indices of the winning slots.
     */
    uint256[] public winningIndices;

    /**
     * @notice The salt used to generate the provenance hash.
     */
    bytes public winningSalt;

    /**
     * @notice The index of the winning slot.
     */
    uint256 public winningSlot;

    /**
     * @notice The address of the winner.
     */
    address public winner;

    /**
     * @notice Emitted when a slot is purchased.
     */
    event SlotPurchased(address indexed buyer, uint256 indexed slot);

    /**
     * @notice Emitted when the winning indices are revealed and a winner is chosen.
     */
    event Winner(address indexed winner, uint256 winningSlot);

    /**
     * @notice This error is raised when there are no more slots available for purchase.
     */
    error NoMoreSlotsAvailable();

    /**
     * @notice This error is raised when you attempt to choose a winner before all slots are taken.
     */
    error SaleIsOngoing();

    /**
     * @notice This error is raised when the owner attempts to buy a slot.
     */
    error InvalidOwnerBuyIn();

    /**
     * @notice This error is raised when number of slots is less than 2.
     */
    error TooFewSlots();

    /**
     * @notice This error is raised when the payment is insufficient.
     */
    error InsufficientPayment();

    /**
     * @notice This error is raised when unprivileged buy-in is not possible.
     */
    error UnprivilegedBuyInIsNotPossible();

    /**
     * @notice This error is raised when the length of the array does not match the number of slots.
     */
    error ArrayLengthMismatch();

    /**
     * @notice This error is raised when the winning indices do not match the provenance hash.
     */
    error InvalidProvenanceHash();

    /**
     * @notice This error is raised when the winner has already been chosen.
     */
    error WinnerAlreadyPicked();

    /**
     * @notice This error is raised when the winning index is out of bounds.
     */
    error WinningSlotOutOfBounds();

    /**
     * @notice This modifier checks if there are any slots available for purchase.
     */
    modifier whenSlotsAvailable() {
        if (!hasAvailableSlots()) {
            revert NoMoreSlotsAvailable();
        }
        _;
    }

    /**
     * @notice This modifier checks if all slots have been taken.
     */
    modifier whenAllSlotsTaken() {
        if (hasAvailableSlots()) {
            revert SaleIsOngoing();
        }
        _;
    }

    /**
     * @notice This modifier checks if unprivileged buy-in is possible.
     */
    modifier whenUnprivilegedBuyInIsPossible() {
        if (slotPriceInNative == 0) {
            revert UnprivilegedBuyInIsNotPossible();
        }
        _;
    }

    constructor(
        uint256 _numSlots,
        uint256 _slotPriceInNative,
        bytes32 _provenanceHash
    ) Ownable(msg.sender) {
        if (_provenanceHash == 0) {
            revert InvalidProvenanceHash();
        }
        if (_numSlots < 2) {
            revert TooFewSlots();
        }
        provenanceHash = _provenanceHash;
        numSlots = _numSlots;
        slotPriceInNative = _slotPriceInNative;
    }

    /**
     * @notice Checks if there are any slots available for purchase.
     * @return bool True if there are available slots, false otherwise.
     */
    function hasAvailableSlots() public view returns (bool) {
        return slots.length < numSlots;
    }

    /**
     * @notice Buys a slot.
     * @return uint256 The index of the slot purchased.
     */
    function _buyIn() internal whenSlotsAvailable returns (uint256) {
        uint256 slot = slots.length;
        slots.push(msg.sender);
        emit SlotPurchased(msg.sender, slot);
        return slot;
    }

    /**
     * @notice Buys a slot using native currency.
     * @dev This function is only available when unprivileged buy-in is possible.
     * @return uint256 The index of the slot purchased.
     */
    function buyIn() external payable whenUnprivilegedBuyInIsPossible returns (uint256) {
        if (msg.sender == owner()) {
            revert InvalidOwnerBuyIn();
        }
        if (msg.value < slotPriceInNative) {
            revert InsufficientPayment();
        }
        return _buyIn();
    }

    /**
     * @notice Buys a slot using privileged access.
     * @dev This function is only available to the owner.
     * @return uint256 The index of the slot purchased.
     */
    function buyInPrivileged() external payable onlyOwner returns (uint256) {
        return _buyIn();
    }

    /**
     * @notice Reveals the winning indices and chooses a winner.
     * @dev This function is only available to the owner. It is only available once all slots are taken.
     * @param indices The indices of the winning slots.
     * @param salt The salt used to generate the provenance hash.
     */
    function pickWinner(uint256[] calldata indices, bytes calldata salt) external onlyOwner whenAllSlotsTaken {
        if (winner != address(0)) {
            revert WinnerAlreadyPicked();
        }

        if (indices.length != numSlots) {
            revert ArrayLengthMismatch();
        }

        bytes32 computedHash = keccak256(abi.encodePacked(salt, indices));
        if (computedHash != provenanceHash) {
            revert InvalidProvenanceHash();
        }

        uint256 slot = indices[block.number % indices.length];
        if (slot >= numSlots) {
            revert WinningSlotOutOfBounds();
        }

        winningIndices = indices;
        winningSalt = salt;
        winningSlot = slot;
        winner = slots[slot];

        emit Winner(winner, slot);
    }

    /**
     * @notice Withdraws the balance of the contract.
     * @dev This function is only available to the owner.
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
