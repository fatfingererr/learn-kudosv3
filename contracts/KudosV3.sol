// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma experimental ABIEncoderV2;

import "./oz/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./oz/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./oz/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./ERC1155NonTransferableUpgradeable.sol";

interface ICommunityRegistry {
    function doesCommunityExist(string memory uniqId) external view returns (bool);
}

contract KudosV3 is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC1155NonTransferableUpgradeable
{
    ////////////////////////////////// CONSTANTS //////////////////////////////////
    /// @notice The name of this contract
    string public constant CONTRACT_NAME = "Kudos";

    /// @notice The version of this contract
    string public constant CONTRACT_VERSION = "3";

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 private constant DOMAIN_TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    /// @notice The EIP-712 typehash for the Kudos input struct used by the contract
    bytes32 public constant KUDOS_TYPE_HASH =
        keccak256(
            "Kudos(string headline,string description,uint256 startDateTimestamp,uint256 endDateTimestamp,string[] links,string communityUniqId)"
        );

    /// @notice The EIP-712 typehash for the claiming flow by the contract
    bytes32 public constant CLAIM_TYPE_HASH =
        keccak256("Claim(uint256 tokenId)");
    
    /// @notice The EIP-712 typehash for adding new allowlisted addresses to an existing Kudos token
    bytes32 public constant ADD_ALLOWLISTED_ADDRESSES_TYPE_HASH = keccak256("AllowlistedAddress(uint256 tokenId)");

    ////////////////////////////////// STRUCTS //////////////////////////////////
    /// @dev Struct used to contain the Kudos metadata input
    ///      Also, note that using structs in mappings should be safe:
    ///      https://forum.openzeppelin.com/t/how-to-use-a-struct-in-an-upgradable-contract/832/4
    struct KudosInputContainer {
        string headline;
        string description;
        uint256 startDateTimestamp;
        uint256 endDateTimestamp;
        string[] links;
        string communityUniqId;
        address[] contributors;
    }

    /// @dev Struct used to contain the full Kudos metadata at the time of mint
    struct KudosContainer {
        string headline;
        string description;
        uint256 startDateTimestamp;
        uint256 endDateTimestamp;
        string[] links;
        string DEPRECATED_communityDiscordId;    // don't use this value anymore
        string DEPRECATED_communityName;         // don't use this value anymore
        address creator;
        uint256 registeredTimestamp;
        string communityUniqId;
    }

    /// @dev This event is solely so that we can easily track which creator registered
    ///      which Kudos tokens without having to store the mapping on-chain.
    event RegisteredKudos(address creator, uint256 tokenId);

    ////////////////////////////////// VARIABLES //////////////////////////////////
    /// @dev We can use this to also figure out how many tokens there _should_ be per ID.
    ///      This may be different from the number of tokens that were actually claimed and minted.
    mapping(uint256 => address[]) public tokenIdToContributors;

    mapping(uint256 => KudosContainer) public tokenIdToKudosContainer;

    /// @notice This value signifies the largest tokenId value that has not been used yet.
    /// Whenever we register a new token, we increment this value by one, so essentially the tokenID
    /// signifies the total number of types of tokens registered through this contract.
    uint256 public latestUnusedTokenId;

    /// @notice the address pointing to the community registry
    address public communityRegistryAddress;

    ////////////////////////////////// CODE //////////////////////////////////
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(uint256 _latestUnusedTokenId) public initializer {
        __ERC1155_init("https://api.mintkudos.xyz/metadata/{id}");
        __Ownable_init();
        __Pausable_init();
        __ERC1155Supply_init();

        // We start with some passed-in latest unused token ID
        if (_latestUnusedTokenId > 0) {
            latestUnusedTokenId = _latestUnusedTokenId;
        } else {
            latestUnusedTokenId = 1;
        }

        // Start off the contract as paused
        _pause();
    }

    /// @notice Allows owner to set new URI that contains token metadata
    /// @param newuri               The Kudos creator's address
    function setURI(string memory newuri) public onlyOwner whenNotPaused {
        _setURI(newuri);
    }

    /// @notice Setting the latest unused token ID value so we can start the next token mint from a different ID.
    /// @param _latestUnusedTokenId  The latest unused token ID that should be set in the contract
    function setLatestUnusedTokenId(uint256 _latestUnusedTokenId) public onlyOwner whenPaused {
        latestUnusedTokenId = _latestUnusedTokenId;
    }

    /// @notice Setting the contract address of the community registry
    /// @param _communityRegistryAddress The community registry address
    function setCommunityRegistryAddress(address _communityRegistryAddress) public onlyOwner {
        communityRegistryAddress = _communityRegistryAddress;
    }

    /// @notice Register new Kudos token type for contributors to claim.
    /// @dev This just allowlists the tokens that are able to claim this particular token type, but it does not necessarily mint the token until later.
    ///      Note that because we are using signed messages, if the Kudos input data is not the same as what it was at the time of user signing, the
    ///      function call with fail. This ensures that whatever the user signs is what will get minted, and that we as the admins cannot tamper with
    ///      the content of a Kudos.
    /// @param creator              The Kudos creator's address
    /// @param metadata             Metadata of the Kudos token
    /// @param mintForCreator       If the flag is on then we will actually mint a token for _just_ the creator
    /// @param v                    Part of the creator's signature (v)
    /// @param r                    Part of the creator's signature (r)
    /// @param s                    Part of the creator's signature (s)
    function registerBySig(
        address creator,
        KudosInputContainer memory metadata,
        bool mintForCreator,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyOwner whenNotPaused {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPE_HASH,
                keccak256(bytes(CONTRACT_NAME)),
                keccak256(bytes(CONTRACT_VERSION)),
                block.chainid,
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(
                KUDOS_TYPE_HASH,
                keccak256(bytes(metadata.headline)),
                keccak256(bytes(metadata.description)),
                metadata.startDateTimestamp,
                metadata.endDateTimestamp,
                convertStringArraytoByte32(metadata.links),
                keccak256(bytes(metadata.communityUniqId))
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(signatory == creator, "invalid signature");

        _register(signatory, metadata, mintForCreator);
    }

    function _register(
        address creator,
        KudosInputContainer memory metadata,
        bool mintForCreator
    ) internal {
        // Note that we currently don't have an easy way to de-duplicate Kudos tokens.
        // Because we are the only ones that can mint Kudos for now (since we're covering the cost),
        // we will gate duplicated tokens in the caller side.
        // However, once we open this up to the public (if the public wants to pay for their own Kudos at some point),
        // we may need to come up with some validation routine here to prevent the "same" Kudos from being minted.

        // Translate the Kudos input container to the actual container
        require(ICommunityRegistry(communityRegistryAddress).doesCommunityExist(metadata.communityUniqId), "Community uniqId does not exist in community registry");

        KudosContainer memory kc;
        kc.creator = creator;
        kc.headline = metadata.headline;
        kc.description = metadata.description;
        kc.startDateTimestamp = metadata.startDateTimestamp;
        kc.endDateTimestamp = metadata.endDateTimestamp;
        kc.links = metadata.links;
        kc.communityUniqId = metadata.communityUniqId;
        kc.registeredTimestamp = block.timestamp;

        // Store the metadata into a mapping for viewing later
        tokenIdToKudosContainer[latestUnusedTokenId] = kc;

        // Register the contributors into the allowlist
        // This is used later in the claim flow to see if an address
        // can actually claim the token or not.
        tokenIdToContributors[latestUnusedTokenId] = metadata.contributors;

        if (mintForCreator) {
            _mint(creator, latestUnusedTokenId, 1, "");
        }

        emit RegisteredKudos(creator, latestUnusedTokenId);

        // increment the latest unused TokenId because we now have an additionally registered
        // token.
        latestUnusedTokenId++;
    }

    /// @notice Mints a token for the specified address if allowlisted
    /// @param id        ID of the Token
    /// @param claimee   Address of the claimee
    /// @param v         Part of the claimee's signature (v)
    /// @param r         Part of the claimee's signature (r)
    /// @param s         Part of the claimee's signature (s)
    function claimBySig(
        uint256 id,
        address claimee,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyOwner whenNotPaused {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPE_HASH,
                keccak256(bytes(CONTRACT_NAME)),
                keccak256(bytes(CONTRACT_VERSION)),
                block.chainid,
                address(this)
            )
        );
        bytes32 claimHash = keccak256(abi.encode(CLAIM_TYPE_HASH, id));
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, claimHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(signatory == claimee, "invalid signature");

        _claim(id, signatory);
    }

    function _claim(uint256 id, address dst) internal {
        // Make sure address dst is allowlisted to claim this
        address[] memory allowlistedAddresses = tokenIdToContributors[id];

        bool addressIsAllowlisted = false;
        for (uint256 i = 0; i < allowlistedAddresses.length; i++) {
            if (dst == allowlistedAddresses[i]) {
                addressIsAllowlisted = true;
            }
        }
        require(
            addressIsAllowlisted,
            "address attempting to claim isn't allowlisted"
        );

        // Address dst should not already have the token
        require(
            balanceOf(dst, id) == 0,
            "address attempting to claim should not already own token"
        );

        // If everything is allowed, then mint the token for dst
        _mint(dst, id, 1, "");
    }

    /// @notice Adds allowlisted addresses to an existing Kudos token
    /// @param id                     ID of the Token
    /// @param allowlistedAddresses   Allowlisted addresses
    /// @param v                      Part of the creator's signature (v)
    /// @param r                      Part of the creator's signature (r)
    /// @param s                      Part of the creator's signature (s)
    function addAllowlistedAddressesBySig(
        uint256 id,
        address[] memory allowlistedAddresses,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public onlyOwner whenNotPaused {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPE_HASH,
                keccak256(bytes(CONTRACT_NAME)),
                keccak256(bytes(CONTRACT_VERSION)),
                block.chainid,
                address(this)
            )
        );
        // Note: not verifying the content of allowlisted addresses for now
        bytes32 addAllowlistedAddressesHash = keccak256(
            abi.encode(
                ADD_ALLOWLISTED_ADDRESSES_TYPE_HASH,
                id
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, addAllowlistedAddressesHash)
        );
        address signatory = ecrecover(digest, v, r, s);

        // Check if token created by this creator
        KudosContainer memory kudos = tokenIdToKudosContainer[id];
        require(kudos.creator == signatory, "Only creator of the Kudos can add allowlisted addresses");

        _addAllowlistedAddresses(id, allowlistedAddresses);
    }

    function _addAllowlistedAddresses(uint256 id, address[] memory newAllowlistedAddresses) internal {
        for (uint256 i = 0; i < newAllowlistedAddresses.length; i++) {
            tokenIdToContributors[id].push(newAllowlistedAddresses[i]);
        }
    }

    /// @notice Returns the allowlisted contributors as an array.
    /// @dev The solidity compiler automatically returns the getter for mappings with arrays
    ///      as map(key, idx), which prevents us from getting the entire array back for a given key.
    /// @param tokenId     ID of the token
    function getAllowlistedContributors(uint256 tokenId)
        public
        view
        returns (address[] memory)
    {
        return tokenIdToContributors[tokenId];
    }

    /// @notice Returns the Kudos metadata for a given token ID
    /// @dev Getters generated by the compiler for a public storage variable
    ///      silently skips mappings and arrays inside structs.
    //       This is why we need our own getter function to return the entirety of the struct.
    ///      https://ethereum.stackexchange.com/questions/107027/how-to-return-an-array-of-structs-that-has-mappings-nested-within-them/107124
    /// @param tokenId     ID of the token
    function getKudosMetadata(uint256 tokenId)
        public
        view
        returns (KudosContainer memory)
    {
        return tokenIdToKudosContainer[tokenId];
    }

    /// @notice Owner can pause the contract
    function pause() public onlyOwner {
        _pause();
    }

    /// @notice Owner can unpause the contract
    function unpause() public onlyOwner {
        _unpause();
    }

    /// @dev A way to convert an array of strings into a hashed byte32 value.
    ///      We append using encodePacked, which is the equivalent of hexlifying each
    ///      hashed string and concatenating them.
    function convertStringArraytoByte32(string[] memory inputArray)
        internal
        pure
        returns (bytes32)
    {
        bytes memory packedBytes;
        for (uint256 i = 0; i < inputArray.length; i++) {
            packedBytes = abi.encodePacked(
                packedBytes,
                keccak256(bytes(inputArray[i]))
            );
        }
        return keccak256(packedBytes);
    }

    function compareStringsbyBytes(string memory s1, string memory s2) private pure returns(bool){
        return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
    }
}