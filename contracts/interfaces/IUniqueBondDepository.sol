// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

interface IUniqueBondDepository {
    function deposit( uint _amount, uint _maxPrice, address _depositor) external returns ( uint payout, uint bondID );
    function redeem( uint _bondId, address _to ) external returns ( uint payout, bool fullyVested );
}