// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IMessageTransmitter} from "ChrysalisCCTP/IMessageTransmitter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IHook {
    function executeHook(bytes calldata data) external returns (bool);
}

interface IArbRetryableTx {
    function calculateRetryableSubmissionFee(uint256 dataLength, uint256 baseFee)
        external
        view
        returns (uint256);
}

interface UniswapInterface {
     function factory() external pure returns (address);
     function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

interface LidoInterface{
  function submit(address _referral) external payable;
  function balanceOf(address _account) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
}


interface ArbitrumBridgeInterface{
  function outboundTransfer( address _token,
        address _to,
        uint256 _amount,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        bytes calldata _data) external payable;
}

contract CCTPReceiverV2 {
    address public immutable usdc;
    address public immutable cctpMessageTransmitter;
    address public hookAddress;
    UniswapInterface public dexRouter;
    LidoInterface public immutable lido;
    address public immutable weth;
    ArbitrumBridgeInterface public bridgeInterface;

    mapping(address user => uint256 amount) public stakedAmount;

    event USDCMinted(address indexed recipient, uint256 amount, bytes hookData);

    // event AttestationVerified(bytes indexed message);

    constructor(
    ) {

        cctpMessageTransmitter = 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD;
        UniswapInterface _dexRouter = UniswapInterface(
            0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
        );
        lido = LidoInterface(0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af);
        usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        ArbitrumBridgeInterface _bridgeInterface = ArbitrumBridgeInterface(0xcE18836b233C83325Cc8848CA4487e94C6288264);
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

    function getHookData(uint256 amount, address recipient)
        public
        pure
        returns (bytes memory)
    {
        require(amount > 0, "Amount must be greater than zero");
        require(recipient != address(0), "Invalid recipient address");

        return abi.encode(amount, recipient);
    }

    /// @dev Internal function to handle hook execution
    function _executeHook(bytes calldata hookData) internal {


        IERC20 usdcToken = IERC20(usdc);
        (uint256 amountIn, address recipient) = abi.decode(
            hookData,
            (uint256, address)
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

        uint256 stethAfter = lido.balanceOf(address(this));

        stakedAmount[recipient] += stethAfter - stethBefore;

    lido.approve(address(0x902b3E5f8F19571859F4AB1003B960a5dF693aFF), stethAfter - stethBefore);

    uint256 submissionFee = IArbRetryableTx(0xaAe29B0366299461418F5324a79Afc425BE5ae21)
            .calculateRetryableSubmissionFee(2000, block.basefee);

     uint256 maxSubmissionCost = submissionFee + (submissionFee / 4);

    bridgeInterface.outboundTransfer{value:1000000000000000}(0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af , recipient , stethAfter - stethBefore , 1_000_000 , 600000000 , abi.encode( maxSubmissionCost , bytes("")));

    emit USDCMinted(recipient, amountIn, hookData);

    }

    function estimateEthNeeded() external view returns (uint256) {
    uint256 baseFee = block.basefee;
    uint256 dataLength = 2000;
    uint256 submissionFee = IArbRetryableTx(0xaAe29B0366299461418F5324a79Afc425BE5ae21)
        .calculateRetryableSubmissionFee(dataLength, baseFee);
    uint256 maxSubmissionCost = submissionFee + (submissionFee / 4);
    uint256 maxGas = 1_000_000;
    uint256 gasPriceBid = tx.gasprice * 2;
    // return submissionFee;

    return maxSubmissionCost + (maxGas * gasPriceBid);
}

       
    
}
