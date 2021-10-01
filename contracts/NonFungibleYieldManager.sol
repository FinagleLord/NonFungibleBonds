// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.0;

import "./libraries/Ownable.sol";
import "./libraries/ERC165.sol";
import "./libraries/Address.sol";
import "./libraries/Strings.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/NonFungibleToken.sol";

import "./interfaces/IERC721.sol";
import "./interfaces/IERC721Metadata.sol";
import "./interfaces/IERC721Receiver.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniqueBondDepository.sol";
import "./interfaces/IwsOHM.sol";

/// @author Dionysus
/// Allows a user to lockup their wsOHM, and wrap/sell the prospect of future staking yeild as an NFT.
contract NonFungibleYeildManager is Ownable, NonFungibleToken("Olympus Yield Token", "YI3LD") {

    ///////// dependencies /////////

    using SafeERC20 for IERC20;


    /////////// structs ///////////

    struct TokenInfo {
        address depositor; // beneficiary of the sOHMValue of the intial wsOHM deposit.
        uint amount;       // inital amount of wsOHM that depositor has provided.
        uint vestingTerm;  // unix style timestamp when initial funds minus interest is paid out to depositor.
        uint sOHMValue;    // the value of the initial wsOHM deposit denominated in sOHM that gets paid back to depositor.
    }


    /////////// storage ///////////

    // Wrapped sOHM
    IwsOHM public wsOHM;

    // Next mintable token index
    uint public tokenCount;

    // Mapping containig a reciept for each token
    mapping( uint => TokenInfo ) tokenToTokenInfo;


    ///////////  user  ///////////
    
    /// Allows a user to lockup their wsOHM, and wrap/sell the prospect of future staking yeild as an NFT.
    /// @param depositor - beneificiary of the inital locked wsOHM minus interest paid out.
    /// @param amount - inital amount of wsOHM that depositor/caller has provided.
    /// @param vestingTerm - unix style timestamp when initial funds minus interest is paid out to depositor.
    /// @return tokenId - the ERC721 tokenId unique to the newly minted.
    /// @return sOHMValue - the value of the initial wsOHM deposit denominated in sOHM that gets paid back to depositor.
    function deposit(
        address depositor,
        uint amount,
        uint vestingTerm
    ) external returns ( uint tokenId, uint sOHMValue ) {
        // interface the new available token index
        TokenInfo storage tokenInfo = tokenToTokenInfo [ tokenCount ];
        // transfer users wsOHM to contract
        IERC20( address( wsOHM ) ).safeTransferFrom( msg.sender, address(this), amount );
        // set token id for return before its updated
        tokenId = tokenCount;
        // get sOHM value of depositors wsOHM for return
        sOHMValue = wsOHM.sOHMValue( amount );
        // store tokenInfo
        tokenInfo.depositor = depositor;
        tokenInfo.amount = amount;
        tokenInfo.vestingTerm = vestingTerm;
        tokenInfo.sOHMValue = sOHMValue;        
    }

    /// Allows the token holder for a given position to redeem it's accrued interest
    /// @dev token must exist, caller must be the owner or depositor, and depositor's amount  
    /// MUST be greater or equal than the their inital deposit value denominated in sOHM.
    /// @param tokenId - ERC721 tokenId
    /// @return payout - amount of wsOHM paid to token owner
    /// @return fullyVested - if sOHMValue was returned to depositor, and if the NFT was burned.
    function redeem( 
        uint tokenId
    ) external returns ( uint payout, bool fullyVested ) {
        // make sure token exists
        require( _exists( tokenId ) );
        // interface the tokens TokenInfo
        TokenInfo storage tokenInfo = tokenToTokenInfo [ tokenId ];
        // if vesting is compete 
        if ( tokenInfo.vestingTerm >= block.timestamp ) {
            // burn the token
            _burn( tokenId );
            // return fully vested
            fullyVested = true;
            // return a payout of 0 since vesting is over
            payout = 0;
            // transfer depositor their wsOHM back
            IERC20( address( wsOHM ) ).safeTransfer( tokenInfo.depositor, tokenInfo.amount);
        } else {
            // make sure caller owns the token or is the orginal depositor
            require( ownerOf[ tokenId ] == msg.sender || msg.sender == tokenInfo.depositor, "You're not the owner");
            // get the current value of the minters deposited wsOHM denominated in sOHM
            uint currentValueInSOHM = wsOHM.sOHMValue( tokenInfo.amount );
            // make sure there's sOHM to be claimed
            require( tokenInfo.sOHMValue < currentValueInSOHM,  "nothing to claim");
            // calculate payout in sOHM
            uint payoutInSOHM = currentValueInSOHM - tokenInfo.sOHMValue;
            // calculate payout in wsOHM
            payout = wsOHM.wOHMValue( payoutInSOHM );
            // subtract the wsOHM that was paid out from the minters deposit amount 
            tokenInfo.amount -= payout;
            // make sure depositor still has at least their original deposit denominated in staked ohm
            require( tokenInfo.amount >= tokenInfo.sOHMValue, "low level math error" );
            // transfer token holder their payout
            IERC20( address( wsOHM ) ).safeTransfer( ownerOf[ tokenId ], payout);
        }
    }
}
