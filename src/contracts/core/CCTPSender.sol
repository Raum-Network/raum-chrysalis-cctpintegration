// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICircleCaller} from "ChrysalisCCTP/Interfaces/ICircleMessenger.sol";

contract CustomBurnContract {
    using SafeERC20 for IERC20;

    ICircleCaller public immutable circleBridge;
    
    event DepositForBurn(
        address indexed sender,
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    );

    constructor(address _circleBridge) {
        require(_circleBridge != address(0), "Invalid Circle Bridge address");
        circleBridge = ICircleCaller(_circleBridge);
    }

    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    ) external {
        require(amount > 0, "Amount must be greater than zero");

        IERC20 erc20Token = IERC20(burnToken);
        erc20Token.safeTransferFrom(msg.sender, address(this), amount);
        erc20Token.approve(address(circleBridge), amount);

        emit DepositForBurn(
            msg.sender,
            amount,
            destinationDomain,
            mintRecipient,
            burnToken,
            destinationCaller
        );

        circleBridge.depositForBurnWithCaller(
            amount,
            destinationDomain,
            mintRecipient,
            burnToken,
            destinationCaller
        );
    }
}
