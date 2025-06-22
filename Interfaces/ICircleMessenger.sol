// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IMessageTransmitter} from "./IMessageTransmitter.sol";
import {ITokenMinter} from "./ITokenMinter.sol";

interface ICircleCaller {
    function depositForBurnWithCaller(uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller)
        external;

    function owner() external view returns (address);

    function handleReceiveMessage(uint32 _remoteDomain, bytes32 _sender, bytes memory messageBody)
        external
        view
        returns (bool);

    function localMessageTransmitter() external view returns (IMessageTransmitter);

    function localMinter() external view returns (ITokenMinter);

    function remoteCircleBridges(uint32 domain) external view returns (bytes32);

    // owner only methods
    function transferOwnership(address newOwner) external;
}