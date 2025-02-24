// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PickAWinner} from "./PickAWinner.sol";

/**
 * @title PickAWinnerFactory
 * @dev A factory contract for creating and managing PickAWinner raffle contracts.
 *
 * This contract serves as the central hub for deploying new raffle instances with the following features:
 * - Only the factory owner can create new raffles
 * - Maintains a registry of all created raffle contracts
 * - Automatically transfers ownership of new raffles to the factory owner
 * - Provides functionality to query the total number of raffles created
 *
 * The factory pattern enables:
 * - Centralized management of multiple raffles
 * - Easy tracking of all raffle instances
 * - Standardized raffle creation process
 * - Future upgradability through new factory versions
 */
contract PickAWinnerFactory is Ownable {

    /**
     * @notice The PickAWinner contracts that have been created.
     */
    address[] public paws;

    /**
     * @notice Emitted when a new PickAWinner contract is created.
     */
    event NewPickAWinner(address paw);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Returns the number of PickAWinner contracts that have been created.
     */
    function numPaws() external view returns (uint256) {
        return paws.length;
    }

    /**
     * @notice Creates a new PickAWinner contract.
     * @dev This function is only callable by the owner. Ownership of the new PickAWinner contract is transferred to the owner.
     * @param numSlots The number of slots available for purchase.
     * @param slotPriceInNative The price of a slot in native currency.
     * @param provenanceHash Hash of the index sequence and salt for proving the provenance of the winner.
     */
    function createPaw(uint256 numSlots, uint256 slotPriceInNative, bytes32 provenanceHash) external onlyOwner {
        PickAWinner paw = new PickAWinner(numSlots, slotPriceInNative, provenanceHash);
        paw.transferOwnership(owner());
        paws.push(address(paw));
        emit NewPickAWinner(address(paw));
    }
}
