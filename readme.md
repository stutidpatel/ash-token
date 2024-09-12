# Explanation of Changes

## Overflow Protection for Minting:
    
    
        Requirement: No overflow of minting 1% of the total supply over a 2-day period.

This means:

    Mint Cap: You can only mint up to 1% of the total token supply within any 2-day period.
    Period Reset: After 2 days, the minting cap resets, allowing another 1% of the total supply to be minted.

### Steps:
 
Tracking Period and Minted Amount:

    lastMintTime records the last time minting occurred.
    mintedAmountInPeriod tracks the total amount minted in the current period.

Checking Time Elapsed:

    If 2 days have passed since the last mint, reset lastMintTime and mintedAmountInPeriod.

Calculating and Enforcing Cap:

    Calculate the remaining mint cap for the period.
    Ensure the new mint request does not exceed the remaining cap

## Functions added

### setTimeLock

__Description:__

Sets up the __parameters for the time lock mechanism, __determining when and how tokens will be gradually released.

__Parameters:__

- _futureDate (uint256): The timestamp of the future date when token release can start.
- _DCATimeFrame (uint256): The total duration (in seconds) over which tokens will be released.
- _snapshotDate (uint256): The timestamp when the token distribution was recorded (not directly used in this function but may be relevant for tracking).
- _releasePercentage (uint256): The percentage of the total token supply that will be subject to the time lock.

__Usage:__

This function can only be called by the contract owner.

Ensures:
- The future date is in the future.
- The time frame is a positive value.
- The release percentage is between 0 and 100.

### lockTokens

__Description:__

Locks a specified amount of tokens for a given account, preventing them from being transferred until released.

__Parameters:__

    account (address): The address of the account where tokens will be locked.
    amount (uint256): The number of tokens to lock.

__Usage:__

    This function can only be called by the contract owner.
    Ensures:
        The amount is greater than zero.
        The owner has sufficient tokens to lock.
    Transfers the tokens from the owner's balance to the contract’s address and updates the locked balance for the specified account.

### releaseLockedTokens

__Description:__

Allows users to release and claim tokens that have been locked and are now available for release.

__Usage:__

Can be called by any user with locked tokens.
Tokens can only be released if the current time is equal to or later than the futureDate.

Calculates:

- The amount of tokens that can be released based on the elapsed time since futureDate, the release time frame, and the release percentage.
- The actual amount to be released and updates the user's locked balance.
- Transfers the released tokens from the contract to the user’s address.

### mint 
__Description:__

Allows the contract owner to mint new tokens and allocate them to a specified address, with controlled minting limits.

__Parameters:__

- to (address): The recipient address for the minted tokens.
- amount (uint256): The number of tokens to mint.

__Functionality:__

- Access Control:
    Only the contract owner can call this function.

- Validation Checks:
    Ensures the amount to be minted is greater than zero.
    Ensures the to address is not the zero address (0x0).

- Minting Limits:
    - Calculates 1% of the total token supply (-onePercentOfTotalSupply).

    Checks if the current time is past the 2-day period since the last minting operation.
    - If so, resets the minting period (lastMintTime) and the minted amount in the period (mintedAmountInPeriod).
    - Determines the remaining minting cap for the current period (remainingMintCap).
    - Ensures the requested amount does not exceed this remaining cap.

__Minting Process:__

- Updates the balances of the to address (rOwned and tOwned).
- Increases the mintedAmountInPeriod by the minted amount.
- Calls the internal _mint function to create and allocate the tokens.
- Emits a Transfer event to log the minting operation.