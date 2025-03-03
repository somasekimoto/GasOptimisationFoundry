// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0; 

error Invalid();

contract GasContract {
    // Event signatures
    event AddedToWhitelist(address userAddress, uint256 tier);
    event WhiteListTransfer(address indexed);
    
    // Storage variables
    address private immutable contractOwner;
    
    // Constructor
    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        
        assembly {
            // Get length of _admins array, limited by administrators length (5)
            let adminLength := mload(_admins)
            if gt(adminLength, 5) { adminLength := 5 }

            // Loop through admins array and store valid addresses
            for { let i := 0 } lt(i, adminLength) { i := add(i, 1) } {
                // Get admin address from array
                let admin := mload(add(add(_admins, 0x20), mul(i, 0x20)))

                // Skip zero addresses
                if iszero(iszero(admin)) {
                    // Store admin in administrators array
                    sstore(add(1, i), admin) // administrators.slot = 1

                    // If admin is msg.sender, set their balance to _totalSupply
                    if eq(admin, caller()) {
                        // Calculate storage slot for balances[admin]
                        mstore(0x00, admin)
                        mstore(0x20, 2) // balances.slot = 2
                        sstore(keccak256(0x00, 0x40), _totalSupply)
                    }
                }
            }
        }
    }

    function checkForAdmin(address _user) public view returns (bool) {
        assembly {
            // 固定サイズの配列をループで処理
            for { let i := 0 } lt(i, 5) { i := add(i, 1) } {
                // administrators[i]のスロットを計算
                let admin := sload(add(1, i)) // administrators.slot = 1

                // 一致するか確認
                if eq(admin, _user) {
                    mstore(0x00, 1) // true
                    return(0x00, 0x20)
                }
            }
            mstore(0x00, 0) // false
            return(0x00, 0x20)
        }
    }

    function balanceOf(address _user) public view returns (uint256) {
        assembly {
            // Calculate storage slot for balances[_user]
            mstore(0x00, _user)
            mstore(0x20, 2) // balances.slot = 2
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
            if gt(calldataload(sub(_name.offset, 0x20)), 8) {
                // Revert with Invalid() error
                mstore(0x00, 0x9db9ee81) // Function signature for Invalid()
                revert(0x1c, 0x04)
            }
            
            // Get sender balance
            mstore(0x00, caller())
            mstore(0x20, 2) // balances.slot = 2
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
            mstore(0x20, 2) // balances.slot = 2
            let recipientBalanceSlot := keccak256(0x00, 0x40)
            let recipientBalance := sload(recipientBalanceSlot)
            sstore(recipientBalanceSlot, add(recipientBalance, _amount))

            // Emit Transfer event
            mstore(0x00, _amount)
            log2(0x00, 0x20, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, _recipient)
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public {
        assembly {
            // Check if caller is admin or owner
            let isAdmin := 0
            let isOwner := eq(caller(), sload(0)) // contractOwner is at slot 0
            
            // Check if caller is admin
            for { let i := 0 } lt(i, 5) { i := add(i, 1) } {
                let adminSlot := add(1, i) // administrators.slot = 1
                let admin := sload(adminSlot)
                if eq(admin, caller()) {
                    isAdmin := 1
                    break
                }
            }
            
            // Check conditions: caller must be admin or owner, and tier must be < 255
            if or(iszero(or(isAdmin, isOwner)), gt(_tier, 254)) {
                mstore(0x00, 0x9db9ee81) // Invalid()
                revert(0x1c, 0x04)
            }
            
            // Set whitelist tier (max 3)
            let finalTier := _tier
            if gt(finalTier, 3) { finalTier := 3 }
            
            // Store in whitelist mapping
            mstore(0x00, _userAddrs)
            mstore(0x20, 3) // whitelist.slot = 3
            sstore(keccak256(0x00, 0x40), finalTier)
        }
        
        // Emit AddedToWhitelist event using Solidity
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(address _recipient, uint256 _amount) external {
        assembly {
            // Get sender tier from whitelist
            mstore(0x00, caller())
            mstore(0x20, 3) // whitelist.slot = 3
            let usersTier := sload(keccak256(0x00, 0x40))
            
            // Get sender balance
            mstore(0x00, caller())
            mstore(0x20, 2) // balances.slot = 2
            let senderBalanceSlot := keccak256(0x00, 0x40)
            let senderBalance := sload(senderBalanceSlot)
            
            // Check conditions
            if or(or(lt(_amount, 3), lt(senderBalance, _amount)), or(eq(usersTier, 0), gt(usersTier, 3))) {
                mstore(0x00, 0x9db9ee81) // Invalid()
                revert(0x1c, 0x04)
            }
            
            // Update whiteListStruct
            mstore(0x00, caller())
            mstore(0x20, 4) // whiteListStruct.slot = 4
            let structSlot := keccak256(0x00, 0x40)
            sstore(structSlot, _amount)      // amount
            sstore(add(structSlot, 1), 1)    // paymentStatus = true
            
            // Update sender balance: senderBalance + usersTier - _amount
            sstore(senderBalanceSlot, add(sub(senderBalance, _amount), usersTier))
            
            // Update recipient balance: recipientBalance + _amount - usersTier
            mstore(0x00, _recipient)
            mstore(0x20, 2) // balances.slot = 2
            let recipientBalanceSlot := keccak256(0x00, 0x40)
            let recipientBalance := sload(recipientBalanceSlot)
            sstore(recipientBalanceSlot, add(sub(recipientBalance, usersTier), _amount))
        }
        
        // Emit WhiteListTransfer event using Solidity
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) public view returns (bool, uint256) {
        assembly {
            // Calculate storage slot for whiteListStruct[sender]
            mstore(0x00, sender)
            mstore(0x20, 4) // whiteListStruct.slot = 4
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
    
    // Public view functions required by tests
    function administrators(uint256 index) public view returns (address) {
        require(index < 5, "Index out of bounds");
        assembly {
            let value := sload(add(1, index)) // administrators.slot = 1
            mstore(0x00, value)
            return(0x00, 0x20)
        }
    }
    
    function balances(address user) public view returns (uint256) {
        assembly {
            mstore(0x00, user)
            mstore(0x20, 2) // balances.slot = 2
            let value := sload(keccak256(0x00, 0x40))
            mstore(0x00, value)
            return(0x00, 0x20)
        }
    }
    
    function whitelist(address user) public view returns (uint256) {
        assembly {
            mstore(0x00, user)
            mstore(0x20, 3) // whitelist.slot = 3
            let value := sload(keccak256(0x00, 0x40))
            mstore(0x00, value)
            return(0x00, 0x20)
        }
    }
}
