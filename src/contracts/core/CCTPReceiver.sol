// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IMessageTransmitter} from "ChrysalisCCTP/Interfaces/IMessageTransmitter.sol";
import {IArbRetryableTx, ArbitrumBridgeInterface, PolygonBridgeInterface, OptimismBridgeInterface} from "ChrysalisCCTP/Interfaces/IBridgeRouter.sol";
import {UniswapInterface} from "ChrysalisCCTP/Interfaces/IUniswapV2.sol";
import {LidoInterface} from "ChrysalisCCTP/Interfaces/ILidoRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract CCTPReceiverV2 {
    address public immutable usdc;
    address public immutable cctpMessageTransmitter;
    address public hookAddress;
    UniswapInterface public dexRouter;
    LidoInterface public immutable lido;
    address public immutable weth;
    ArbitrumBridgeInterface public bridgeInterface;
    PolygonBridgeInterface public polygonBridgeInterface;
    OptimismBridgeInterface public optimismBridgeInterface;

    mapping(address => uint256) public stakedAmount;
    uint256 public totalUSDCStaked;
    uint256 public uniqueRecipientCount;
    mapping(address => bool) public recipientSeen;


    event USDCMinted(address indexed recipient, uint256 amount, bytes hookData);

    constructor() {
        cctpMessageTransmitter = 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD;
        UniswapInterface _dexRouter = UniswapInterface(
            0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
        );
        lido = LidoInterface(0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af);
        usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        ArbitrumBridgeInterface _bridgeInterface = ArbitrumBridgeInterface(
            0xcE18836b233C83325Cc8848CA4487e94C6288264
        );
        PolygonBridgeInterface _polygonBridgeInterface = PolygonBridgeInterface(
            0x34F5A25B627f50Bb3f5cAb72807c4D4F405a9232
        );
        OptimismBridgeInterface _optimismBridgeInterface = OptimismBridgeInterface(
                0x4Abf633d9c0F4aEebB4C2E3213c7aa1b8505D332
            );
        polygonBridgeInterface = _polygonBridgeInterface;
        optimismBridgeInterface = _optimismBridgeInterface;
        bridgeInterface = _bridgeInterface;
        dexRouter = _dexRouter;
    }

    receive() external payable {}

    function receiveUSDC(
        bytes calldata hookData,
        bytes calldata cctpMessage,
        bytes calldata signature
    ) external {
        IMessageTransmitter(cctpMessageTransmitter).receiveMessage(
            cctpMessage,
            signature
        );

        if (hookData.length > 0) {
            _executeHook(hookData);
        }
    }

    function getHookData(
        uint256 amount,
        address recipient,
        uint32 sourceDomain
    ) public pure returns (bytes memory) {
        require(amount > 0, "Amount must be greater than zero");
        require(recipient != address(0), "Invalid recipient address");

        return abi.encode(amount, recipient, sourceDomain);
    }

    /// @dev Internal function to handle hook execution
    function _executeHook(bytes calldata hookData) internal {
        IERC20 usdcToken = IERC20(usdc);
        (uint256 amountIn, address recipient, uint32 sourceDomain) = abi.decode(
            hookData,
            (uint256, address, uint32)
        );

        require(amountIn > 0, "Invalid amount");
        require(recipient != address(0), "Invalid recipient");

        require(
            usdcToken.balanceOf(msg.sender) >= amountIn,
            "Insufficient USDC balance"
        );
        require(
            usdcToken.allowance(msg.sender, address(this)) >= amountIn,
            "Insufficient allowance"
        );

        // Approve USDC for Uniswap
        require(
            usdcToken.approve(address(dexRouter), amountIn),
            "Approval failed"
        );



        // Swap USDC for ETH
        address[] memory path = new address[](2);
        path[0] = address(usdcToken);
        path[1] = weth;

        uint256 ethBefore = address(this).balance;
        uint256 stethBefore = lido.balanceOf(address(this));

        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 ethAfter = address(this).balance;
        require(ethAfter > 0, "Swap failed: insufficient ETH received");

        // Stake ETH in Lido
        lido.submit{value: ethAfter - ethBefore}(address(this));

        totalUSDCStaked += amountIn;

        if (!recipientSeen[recipient]) {
            recipientSeen[recipient] = true;
            uniqueRecipientCount += 1;
        }

        uint256 stethAfter = lido.balanceOf(address(this));

        stakedAmount[recipient] += stethAfter - stethBefore;

        if (sourceDomain == 3) {
            lido.approve(
                address(0x902b3E5f8F19571859F4AB1003B960a5dF693aFF),
                stethAfter - stethBefore
            );

            uint256 submissionFee = IArbRetryableTx(
                0xaAe29B0366299461418F5324a79Afc425BE5ae21
            ).calculateRetryableSubmissionFee(2000, block.basefee);

            uint256 maxSubmissionCost = submissionFee + (submissionFee / 4);

            bridgeInterface.outboundTransfer{value: 1000000000000000}(
                0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af,
                recipient,
                stethAfter - stethBefore,
                1_000_000,
                600000000,
                abi.encode(maxSubmissionCost, bytes(""))
            );
        } else if (sourceDomain == 7) {
            lido.approve(
                address(0x4258C75b752c812B7Fa586bdeb259f2d4bd17f4F),
                stethAfter - stethBefore
            );

            polygonBridgeInterface.depositFor(
                address(recipient),
                address(0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af),
                abi.encode(stethAfter - stethBefore)
            );
        } else if (sourceDomain == 2) {
            lido.approve(
                address(0x4Abf633d9c0F4aEebB4C2E3213c7aa1b8505D332),
                stethAfter - stethBefore
            );
            optimismBridgeInterface.depositERC20To(
                0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af,
                0xf49D208B5C7b10415C7BeAFe9e656F2DF9eDfe3B,
                recipient,
                stethAfter - stethBefore,
                300000,
                "0x7375706572627269646765"
            );
        }

        emit USDCMinted(recipient, amountIn, hookData);
    }

}
