import { ethers } from "hardhat";
import { expect } from "chai";
import { PickAWinner as PickAWinnerContract, PickAWinnerFactory as PickAWinnerFactoryContract, PickAWinner__factory, PickAWinnerFactory__factory } from "../typechain";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { assert } from "console";

const createProvenanceHash = (indices: number[], salt: string): string => {
  const packed = ethers.solidityPacked(["bytes", "uint256[]"], [salt, indices]);
  return ethers.keccak256(packed);
};

describe("PickAWinnerFactory", function () {
  let pawFactory: PickAWinnerFactoryContract;

  const slotPrice = ethers.parseEther("0.1");

  // A mock array of indices and salt to be used as an example.
  // Usually, you'd generate these in a more structured manner.
  const indices = [2, 1, 8, 5, 3, 7, 0, 4, 6, 9];
  const salt = "0xdeadbeef";

  // The provenance hash is computed as keccak256(salt, indices)
  const provenanceHash = createProvenanceHash(indices, salt);


  beforeEach(async function () {
    const PickAWinnerFactory = (await ethers.getContractFactory("PickAWinnerFactory")) as unknown as PickAWinnerFactory__factory;
    pawFactory = await PickAWinnerFactory.deploy();
  });

  describe('Deployment', function () {
    it('should have 0 paws deployed initially', async function () {
      const numPaws = await pawFactory.numPaws();
      expect(numPaws).to.equal(0);
    });
    it('should be able to deploy a new paw', async function () {
      await pawFactory.createPaw(indices.length, slotPrice, provenanceHash);
      const numPaws = await pawFactory.numPaws();
      expect(numPaws).to.equal(1);
    });
    it('should revert if non-owner tries to deploy a new paw', async function () {
      const signers = await ethers.getSigners();
      await expect(
        pawFactory.connect(signers[1]).createPaw(indices.length, slotPrice, provenanceHash)
      ).to.be.revertedWithCustomError(pawFactory, "OwnableUnauthorizedAccount");
    });
  });
});

describe("PickAWinner", function () {
  let paw: PickAWinnerContract;
  let owner: HardhatEthersSigner;
  let someone: HardhatEthersSigner;
  let another: HardhatEthersSigner;

  const slotPrice = ethers.parseEther("0.1");

  // A mock array of indices and salt to be used as an example.
  // Usually, you'd generate these in a more structured manner.
  const indices = [2, 1, 8, 5, 3, 7, 0, 4, 6, 9];
  const salt = "0xdeadbeef";

  // The provenance hash is computed as keccak256(salt, indices)
  const provenanceHash = createProvenanceHash(indices, salt);

  before(async function () {
    [owner, someone, another] = await ethers.getSigners();
  });

  beforeEach(async function () {
    const PickAWinner = (await ethers.getContractFactory("PickAWinner")) as unknown as PickAWinner__factory;
    paw = await PickAWinner.deploy(indices.length, slotPrice, provenanceHash);
  });

  describe("Deployment", function () {
    it("initializes with the correct number of slots", async function () {
      expect(await paw.numSlots()).to.equal(indices.length);
    });

    it("initializes with the correct provenance hash", async function () {
      expect(await paw.provenanceHash()).to.equal(provenanceHash);
    });

    it("initializes with the correct slot price", async function () {
      expect(await paw.slotPriceInNative()).to.equal(slotPrice);
    });

    it("has no slots purchased at deployment", async function () {
      // Since no slots have been bought yet
      await expect(paw.slots(0)).to.be.reverted; // no slot at index 0
    });

    it("generates the expected provenance hash", async function () {
      const salt = "0xa7571219"
      const indices = [3, 2, 1, 0];
      const expectedProvenanceHash = "0x74431f12a115a6bdf6762a0a2a382f2fafe67665e085a49dd4d32af49c76853b";
      expect(createProvenanceHash(indices, salt)).to.equal(expectedProvenanceHash);
    });
  });

  describe("Buying Slots", function () {
    it("should allow buying a slot if sufficient payment is made", async function () {
      await paw.connect(someone).buyIn({ value: slotPrice });
      expect(await paw.slots(0)).to.equal(someone.address);
    });

    it("should revert if insufficient payment is made", async function () {
      await expect(
        paw.connect(someone).buyIn({ value: ethers.parseEther("0.05") })
      ).to.be.revertedWithCustomError(paw, "InsufficientPayment");
    });

    it("should allow the owner to buy a slot privileged without payment", async function () {
      await paw.connect(owner).buyInPrivileged();
      expect(await paw.slots(0)).to.equal(owner.address);
    });

    it("should revert if a non-owner tries to buyInPrivileged", async function () {
      await expect(
        paw.connect(someone).buyInPrivileged()
      ).to.be.revertedWithCustomError(paw, 'OwnableUnauthorizedAccount');
    });

    it("should let multiple participants buy until all slots are filled", async function () {
      for (let i = 0; i < indices.length; i++) {
        await paw.connect(someone).buyIn({ value: slotPrice });
        expect(await paw.slots(i)).to.equal(someone.address);
      }
      expect(await paw.hasAvailableSlots()).to.equal(false);
    });

    it("should revert if owner tries to pick a winner before all slots are filled", async function () {
      await expect(
        paw.connect(owner).pickWinner(indices, salt)
      ).to.be.revertedWithCustomError(paw, "SaleIsOngoing");
    });

    it("should revert when trying to buy a slot after all are sold", async function () {
      // Fill all slots first
      for (let i = 0; i < indices.length; i++) {
        await paw.connect(someone).buyIn({ value: slotPrice });
      }

      // Now no more slots are available
      await expect(
        paw.connect(someone).buyIn({ value: slotPrice })
      ).to.be.revertedWithCustomError(paw, "NoMoreSlotsAvailable");
    });
  });

  describe("Picking a Winner", function () {
    beforeEach(async function () {
      // Fill all slots to transition to a state where winner can be picked
      for (let i = 0; i < indices.length; i++) {
        await paw.connect(someone).buyIn({ value: slotPrice });
      }
    });

    it("should revert if pickWinner is called by non-owner", async function () {
      await expect(
        paw.connect(someone).pickWinner(indices, salt)
      ).to.be.revertedWithCustomError(paw, "OwnableUnauthorizedAccount");
    });

    it("should revert if indices length != numSlots", async function () {
      const wrongLengthIndices = indices.slice(0, 5); // only 5 instead of 10
      await expect(
        paw.connect(owner).pickWinner(wrongLengthIndices, salt)
      ).to.be.revertedWithCustomError(paw, "ArrayLengthMismatch");
    });

    it("should revert if computed hash != provenanceHash", async function () {
      // Mess with indices so hash won't match
      const badIndices = [...indices];
      badIndices[0] = 99; // something out of original sequence

      await expect(
        paw.connect(owner).pickWinner(badIndices, salt)
      ).to.be.revertedWithCustomError(paw, "InvalidProvenanceHash");
    });

    it("should pick a winner and emit Winner event if everything matches", async function () {
      await expect(
        paw.connect(owner).pickWinner(indices, salt)
      )
        .to.emit(paw, "Winner")
        .withArgs(await paw.slots(indices[(await ethers.provider.getBlockNumber()) % indices.length]), indices[(await ethers.provider.getBlockNumber()) % indices.length]);

      const winningSlot = await paw.winningSlot();
      const winner = await paw.winner();
      expect(winner).to.equal(await paw.slots(winningSlot));
    });

    it("should revert if pickWinner is called more than once", async function () {
      await paw.connect(owner).pickWinner(indices, salt);
      await expect(
        paw.connect(owner).pickWinner(indices, salt)
      ).to.be.revertedWithCustomError(paw, "WinnerAlreadyPicked");
    });

    it("should revert if winning slot index is out of bounds", async function () {
      const badIndices = [100, 101, 102, 103, 104, 105, 106, 107, 108, 109];
      const badSalt = "0xdeadbeef";
      const badProvenanceHash = createProvenanceHash(badIndices, badSalt);

      const PickAWinner = (await ethers.getContractFactory("PickAWinner")) as unknown as PickAWinner__factory;
      const badPaw = await PickAWinner.deploy(badIndices.length, slotPrice, badProvenanceHash);
      for (let i = 0; i < badIndices.length; i++) {
        await badPaw.connect(someone).buyIn({ value: slotPrice });
      }

      await expect(
        badPaw.connect(owner).pickWinner(badIndices, badSalt)
      ).to.be.revertedWithCustomError(badPaw, "WinningSlotOutOfBounds");
    });
  });

  describe("Withdrawing Funds", function () {
    beforeEach(async function () {
      // Buy a few slots to get some balance in the contract
      await paw.connect(someone).buyIn({ value: slotPrice });
      await paw.connect(another).buyIn({ value: slotPrice });
    });

    it("should allow owner to withdraw contract balance", async function () {
      const initialOwnerBalance = await ethers.provider.getBalance(owner.address);
      const contractBalance = await ethers.provider.getBalance(paw.getAddress());

      await paw.connect(owner).withdraw();

      const finalOwnerBalance = await ethers.provider.getBalance(owner.address);
      expect(finalOwnerBalance).to.be.gt(initialOwnerBalance);

      const contractBalanceAfter = await ethers.provider.getBalance(paw.getAddress());
      expect(contractBalanceAfter).to.equal(0n);

      expect(contractBalance).to.be.gt(0n);
    });

    it("should revert if non-owner tries to withdraw", async function () {
      await expect(paw.connect(someone).withdraw()).to.be.revertedWithCustomError(paw, "OwnableUnauthorizedAccount");
    });
  
    it("should revert if owner tries to buy in unprivileged", async function () {
      await expect(paw.connect(owner).buyIn({ value: slotPrice })).to.be.revertedWithCustomError(paw, "InvalidOwnerBuyIn");
    });
  });

  describe("Constructor Validations", function () {
    it("should revert if provenanceHash is zero", async function () {
      const PickAWinner = (await ethers.getContractFactory("PickAWinner")) as unknown as PickAWinner__factory;
      await expect(
        PickAWinner.deploy(indices.length, slotPrice, "0x0000000000000000000000000000000000000000000000000000000000000000")
      ).to.be.revertedWithCustomError(paw, "InvalidProvenanceHash");
    });

    it("should revert if numSlots < 2", async function () {
      const PickAWinner = (await ethers.getContractFactory("PickAWinner")) as unknown as PickAWinner__factory;
      await expect(
        PickAWinner.deploy(1, slotPrice, provenanceHash)
      ).to.be.revertedWithCustomError(paw, "TooFewSlots");
    });
  });

  describe("Behavior When slotPriceInNative = 0", function () {
    it("should revert when user tries to buyIn if slotPriceInNative = 0", async function () {
      const PickAWinner = (await ethers.getContractFactory("PickAWinner")) as unknown as PickAWinner__factory;

      // Deploy with zero slot price
      const pawZeroPrice = await PickAWinner.deploy(indices.length, 0n, provenanceHash);

      await expect(
        pawZeroPrice.connect(someone).buyIn({ value: 0n })
      ).to.be.revertedWithCustomError(pawZeroPrice, "UnprivilegedBuyInIsNotPossible");
    });
  });
});
