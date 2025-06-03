// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILido {
    function submit(address _referral) external payable returns (uint256);
}

interface UniswapInterface {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;
}

contract SwapAndStakeHook {
    UniswapInterface public dexRouter;
    ILido public immutable lido;
    address public immutable usdc;
    address public immutable weth;

    constructor() {
        UniswapInterface _dexRouter = UniswapInterface(
            0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3
        );
        lido = ILido(0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af);
        usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        dexRouter = _dexRouter;
    }

    function getHookData(uint256 amount, address recipient)
        public
        view
        returns (bytes memory)
    {
        require(amount > 0, "Amount must be greater than zero");
        require(recipient != address(0), "Invalid recipient address");

        address hookContract = address(this);
        return abi.encode(hookContract, abi.encode(amount, recipient));
    }

    function executeHook(bytes calldata data) external returns (bool) {
        (uint256 amountIn, address recipient) = abi.decode(
            data,
            (uint256, address)
        );

        require(amountIn > 0, "Invalid amount");
        require(recipient != address(0), "Invalid recipient");

        IERC20 usdcToken = IERC20(usdc);

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

        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn,
            0,
            path,
            address(msg.sender),
            block.timestamp
        );

        uint256 ethAfter = address(this).balance;
        require(ethAfter > 0, "Swap failed: insufficient ETH received");

        // Stake ETH in Lido
        try lido.submit{value: ethAfter - ethBefore}(msg.sender) returns (
            uint256 stETHReceived
        ) {
            require(stETHReceived > 0, "Lido staking failed");
        } catch {
            revert("Lido staking transaction failed");
        }

        return true;
    }

    receive() external payable {}
}
