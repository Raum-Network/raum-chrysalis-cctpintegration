const { expect } = require("chai");
const { ethers, waffle } = require("hardhat");
const { deployMockContract } = waffle;

const IERC20 = require("../src/contracts/interfaces/IERC20.sol");
const IMessageTransmitter = require("../src/contracts/interfaces/IMessageTransmitter.json");
const UniswapInterface = require("../src/contracts/interfaces/IUniswapV2.json");
const LidoInterface = require("../src/contracts/interfaces/ILidoRouter.json");
const IBridgeRouter = require("../src/contracts/interfaces/IBridgeRouter.json");

describe("CCTPReceiverV2", function () {
  let deployer, user, usdc, lido, uniswap, messageTransmitter;
  let arbBridge, polygonBridge, optimismBridge;
  let receiver;

  beforeEach(async () => {
    [deployer, user] = await ethers.getSigners();

    usdc = await deployMockContract(deployer, IERC20.abi);
    lido = await deployMockContract(deployer, LidoInterface.abi);
    uniswap = await deployMockContract(deployer, UniswapInterface.abi);
    messageTransmitter = await deployMockContract(deployer, IMessageTransmitter.abi);
    arbBridge = await deployMockContract(deployer, IBridgeRouter.abi);
    polygonBridge = await deployMockContract(deployer, IBridgeRouter.abi);
    optimismBridge = await deployMockContract(deployer, IBridgeRouter.abi);

    // Deploy real contract
    const Receiver = await ethers.getContractFactory("CCTPReceiverV2");
    receiver = await Receiver.deploy();
    await receiver.deployed();

    // Override state manually for mocks
    await ethers.provider.send("hardhat_setStorageAt", [
      receiver.address,
      "0x0", // storage slot for USDC (simplified for test)
      ethers.utils.hexZeroPad(usdc.address, 32),
    ]);
  });

  it("should encode hook data correctly", async () => {
    const amount = ethers.utils.parseUnits("1000", 6);
    const recipient = user.address;
    const sourceDomain = 3;

    const hookData = await receiver.getHookData(amount, recipient, sourceDomain);
    const decoded = ethers.utils.defaultAbiCoder.decode(
      ["uint256", "address", "uint32"],
      hookData
    );

    expect(decoded[0]).to.equal(amount);
    expect(decoded[1]).to.equal(recipient);
    expect(decoded[2]).to.equal(sourceDomain);
  });

  it("should call receiveMessage on CCTP transmitter", async () => {
    const hookData = "0x";
    const fakeMessage = ethers.utils.hexlify(ethers.utils.randomBytes(32));
    const fakeSig = ethers.utils.hexlify(ethers.utils.randomBytes(65));

    await messageTransmitter.mock.receiveMessage.withArgs(fakeMessage, fakeSig).returns(true);

    // Call receiveUSDC (skip hook for simplicity)
    await expect(receiver.receiveUSDC(hookData, fakeMessage, fakeSig)).to.not.be.reverted;
  });

  it("should revert if hookData amount = 0", async () => {
    const amount = 0;
    const recipient = user.address;
    const sourceDomain = 2;

    await expect(
      receiver.getHookData(amount, recipient, sourceDomain)
    ).to.be.revertedWith("Amount must be greater than zero");
  });

  it("should revert if hookData recipient = 0", async () => {
    const amount = ethers.utils.parseUnits("10", 6);
    const recipient = ethers.constants.AddressZero;
    const sourceDomain = 2;

    await expect(
      receiver.getHookData(amount, recipient, sourceDomain)
    ).to.be.revertedWith("Invalid recipient address");
  });

  // 🔹 NOTE: full _executeHook test requires mocking Uniswap swap + Lido staking
  // This is an example of structure:
  it("should emit USDCMinted after hook execution", async () => {
    const amount = ethers.utils.parseUnits("50", 6);
    const hookData = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "address", "uint32"],
      [amount, user.address, 2]
    );

    // Mock ERC20 behavior
    await usdc.mock.balanceOf.withArgs(receiver.address).returns(amount);
    await usdc.mock.allowance.returns(amount);
    await usdc.mock.approve.returns(true);

    // Mock Uniswap swap
    await uniswap.mock.swapExactTokensForETHSupportingFeeOnTransferTokens.returns();

    // Mock Lido submit
    await lido.mock.balanceOf.returns(0).returns(100); // before and after stake
    await lido.mock.submit.returns();

    // Execute
    await expect(receiver.receiveUSDC(hookData, "0x", "0x"))
      .to.emit(receiver, "USDCMinted")
      .withArgs(user.address, amount, hookData);
  });
});
