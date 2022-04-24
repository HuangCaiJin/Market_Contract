// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

abstract contract InitOwner {
    address public owner;
    bool private _initialized = false;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    // 检查是否为所有者
    modifier onlyOwner()
    {
        require(msg.sender == owner, "Not Owner");
        _;
    }
    // 初始化一个所有者
    function initOwner(address _owner) internal {
        require(!_initialized,'Already initialized');
        owner = _owner;
        _initialized = true;
    }
    function transferOwnership(
        address _newOwner
    ) public onlyOwner
    {
        require(_newOwner != address(0), "Owner cannot be 0x0");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}