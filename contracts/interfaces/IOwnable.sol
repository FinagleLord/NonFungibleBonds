// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

interface IOwnable {
  function policy() external view returns (address);
  function renounceManagement() external;
  function pushManagement( address newOwner_ ) external;
  function pullManagement() external;
}