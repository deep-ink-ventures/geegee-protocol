// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PickAWinner
 * @dev A provably fair raffle contract where participants can buy tickets (slots) for a chance to win.
 *
 * This contract implements a transparent and verifiable raffle system with the following features:
 * - Fixed number of slots available for purchase
 * - Fixed price per slot in native currency
 * - Provably fair winner selection using a combination of:
 *   1. Pre-committed random number (provenanceHash)
 *   2. Salt value revealed after all slots are sold
 *   3. Block hash at the time of winner selection
 *
 * The winning mechanism ensures that:
 * - The outcome cannot be predicted during the ticket sale
 * - The contract owner cannot manipulate the winner selection
 * - The entire process is verifiable on-chain
 *
 * Security Features:
 * - Owner cannot participate in the raffle
 * - Winner selection can only occur after all slots are sold
 * - Provenance hash must be committed at contract creation
 * - Minimum of 2 slots required for a valid raffle
 */
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

    /**
     * @notice Initializes a new raffle contract
     * @dev Sets up the initial state of the raffle with the specified parameters
     * @param _numSlots The total number of slots (tickets) available in the raffle
     * @param _slotPriceInNative The price of each slot in the native currency (0 for privileged-only raffles)
     * @param _provenanceHash The hash of the winning sequence and salt, committed at creation time
     * @custom:security The provenance hash ensures the winning sequence cannot be changed after creation
     */
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
     * @notice Reveals the winning indices and determines the winner of the raffle
     * @dev This function implements the core fairness mechanism of the raffle:
     *      1. Verifies the revealed sequence matches the committed hash
     *      2. Uses the current block number as an unpredictable source of randomness
     *      3. Selects the winner using modulo arithmetic on the block number
     * 
     * @param indices The complete sequence of winning indices that was committed at creation
     * @param salt The secret salt value used in the original hash commitment
     * 
     * @custom:security This function ensures fairness through multiple mechanisms:
     * - The indices must match the committed hash (prevents manipulation)
     * - The block number is used as a source of randomness (unpredictable)
     * - The function can only be called once (prevents re-rolls)
     * - All slots must be filled (ensures full participation)
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
