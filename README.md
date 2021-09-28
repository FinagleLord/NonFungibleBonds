# NonFungibleBonds

### Temporary Description:

### Major Changes:

#### UniqueBondDepo - Bonds are now unique such that buying new bonds doesn't reset the users vesting timer. Rather than bond info being mapped to an address (the bonds owner) its now mapped to its own unqiue identification number. I've also introduced a new function `transferBond` that allows users to transfer ownership of their bonds, and the right to redeem them.

#### NonFungibleBondManager - A Uniswap v3 inspired wrapper contract that wraps and delegates the ownship of bonds to a unique NFT, which can allow for secondary markets as well as other utility.
