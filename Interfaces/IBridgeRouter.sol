// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IArbRetryableTx {
    function calculateRetryableSubmissionFee(uint256 dataLength, uint256 baseFee)
        external
        view
        returns (uint256);
}

interface PolygonBridgeInterface{
  function depositFor(address user , address rootToken , bytes calldata depositData) external payable;
}

interface OptimismBridgeInterface{
    function depositERC20To(address _l1Token,address _l2Token,address _to,uint256 _amount,uint32 _l2Gas, bytes memory _data) external payable;
}

interface ArbitrumBridgeInterface{
  function outboundTransfer( address _token,
        address _to,
        uint256 _amount,
        uint256 _maxGas,
        uint256 _gasPriceBid,
        bytes calldata _data) external payable;
}