// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0; 

error Invalid();

contract GasContract {
    address private immutable contractOwner;
    address[5] public administrators;
    struct ImportantStruct {
        uint256 amount;
        bool paymentStatus;
    }

    mapping(address => uint256) public balances;
    mapping(address => uint256) public whitelist;
    mapping(address => ImportantStruct) private whiteListStruct;
    event AddedToWhitelist(address userAddress, uint256 tier);
    event Transfer(address recipient, uint256 amount);
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        assembly {
            // Get length of _admins array, limited by administrators length (5)
            let adminLength := mload(_admins)

            // Loop through admins array and store valid addresses
            let i := 0
            for {} lt(i, adminLength) { i := add(i, 1) } {
                // Get admin address from array
                let adminOffset := add(add(_admins, 0x20), mul(i, 0x20))
                let admin := mload(adminOffset)

                // Skip zero addresses
                if iszero(iszero(admin)) {
                    // Store admin in administrators array
                    // administrators.slot + i
                    mstore(0x00, i)
                    mstore(0x20, administrators.slot)
                    sstore(mload(0x00), admin)

                    // If admin is msg.sender, set their balance to _totalSupply
                    if eq(admin, caller()) {
                        // Calculate storage slot for balances[admin]
                        mstore(0x00, admin)
                        mstore(0x20, balances.slot)
                        sstore(keccak256(0x00, 0x40), _totalSupply)
                    }
                }
            }
        }
    }

    function checkForAdmin(address _user) public view returns (bool) {
        for (uint256 i = 0; i < administrators.length; i++) {
            if (administrators[i] == _user) {
                return true;
            }
        }
        return false;
    }

    function balanceOf(address _user) public view returns (uint256) {
        return balances[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public {
        if (bytes(_name).length > 8 || balances[msg.sender] < _amount) revert Invalid();
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public
    {
        if (!checkForAdmin(msg.sender) || msg.sender != contractOwner || _tier >= 255) revert Invalid();
        whitelist[_userAddrs] = _tier > 3 ? 3 : _tier;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount
    ) external {
        uint256 usersTier = whitelist[msg.sender];
        uint256 senderBalance = balances[msg.sender];
        if (_amount < 3 || senderBalance < _amount || usersTier <= 0 || usersTier >= 4) revert Invalid(); 
        whiteListStruct[msg.sender] = ImportantStruct(_amount, true);
        balances[msg.sender] = senderBalance + usersTier -  _amount;
        balances[_recipient] = balances[_recipient] + _amount - usersTier;
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        ImportantStruct memory userStruct = whiteListStruct[sender];
        return (userStruct.paymentStatus, userStruct.amount);
    }
}