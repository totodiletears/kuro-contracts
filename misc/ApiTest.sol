// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract ApiTest {
    uint256 counter = 0;

    function sampleQuery() public view returns (string memory) {
        return "Query Success";
    }

    function sampleMutation() public returns (string memory) {
        counter++;
        return "Mutation Success";
    }
}
