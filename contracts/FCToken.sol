// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FCToken is ERC20 
{
  constructor() ERC20('Follow-Crypto', 'FC')
  {
    _mint(msg.sender, 300000000000000000000000);
  }

  function faucet() external
  {
    _mint(msg.sender, 100);
  }
}
