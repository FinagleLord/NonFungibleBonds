// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

interface IwsOHM {
    function unwrap( uint _amount ) external returns ( uint );
    function wrap( uint _amount ) external returns ( uint );
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function sOHMValue( uint _amount ) external view returns ( uint );
    function wOHMValue( uint _amount ) external view returns ( uint );
}