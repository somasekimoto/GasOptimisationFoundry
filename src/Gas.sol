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
    bytes32 constant TRANSFER_EVENT_SIG = 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;
    // bytes32 constant WHITELIST_EVENT_SIG = 0x171e2edcf015e89d429627e6dbca33dcc63d9ec6a32de7eafdbe207c8347b408;
    // bytes32 constant WHITE_TRANSFER_EVENT_SIG = 0x79ce33fd0f1a97e929683f5953762b918c0d417874a494a6dc624f3d230a5825;
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
        bool result;

        assembly {
            // 固定サイズの配列をループで処理
            for { let i := 0 } lt(i, 5) { i := add(i, 1) } {
                // administrators[i]のスロットを計算
                let adminSlot := add(administrators.slot, i)
                let admin := sload(adminSlot)

                // 一致するか確認
                if eq(admin, _user) {
                    result := 1
                    break
                }
            }
        }

        return result;
    }

    function balanceOf(address _user) public view returns (uint256) {
        assembly {
            // Calculate storage slot for balances[_user]
            mstore(0x00, _user)
            mstore(0x20, balances.slot)
            let _balance := sload(keccak256(0x00, 0x40))

            // Return balance
            mstore(0x00, _balance)
            return(0x00, 0x20)
        }
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public {
        assembly {
            // Check if name length > 8
            let nameLength := calldataload(sub(_name.offset, 0x20))
            if gt(nameLength, 8) {
                // Revert with Invalid() error
                mstore(0x00, 0x9db9ee81) // Function signature for Invalid()
                revert(0x1c, 0x04)
            }
            // Get sender balance
            mstore(0x00, caller())
            mstore(0x20, balances.slot)
            let senderBalanceSlot := keccak256(0x00, 0x40)
            let senderBalance := sload(senderBalanceSlot)

            // Check if sender balance < amount
            if lt(senderBalance, _amount) {
                // Revert with Invalid() error
                mstore(0x00, 0x9db9ee81) // Function signature for Invalid()
                revert(0x1c, 0x04)
            }

            // Update sender balance
            sstore(senderBalanceSlot, sub(senderBalance, _amount))

            // Update recipient balance
            mstore(0x00, _recipient)
            mstore(0x20, balances.slot)
            let recipientBalanceSlot := keccak256(0x00, 0x40)
            let recipientBalance := sload(recipientBalanceSlot)
            sstore(recipientBalanceSlot, add(recipientBalance, _amount))

            // Emit Transfer event
            mstore(0x00, _amount)
            log2(0x00, 0x20, TRANSFER_EVENT_SIG, _recipient)
        }
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
        assembly {
            // Calculate storage slot for whiteListStruct[sender]
            mstore(0x00, sender)
            mstore(0x20, whiteListStruct.slot)
            let structSlot := keccak256(0x00, 0x40)

            // Load amount and paymentStatus
            let amount := sload(structSlot)
            let paymentStatus := sload(add(structSlot, 1))

            // Return the values
            mstore(0x00, paymentStatus)
            mstore(0x20, amount)
            return(0x00, 0x40)
        }
    }
}