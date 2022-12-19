// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}


pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract tokenForStake is Initializable, ERC721Upgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using Strings for uint256;

    string private baseURI = "";
    uint private _currentIndex = 0;
    uint private _burnCounter = 0;

    struct features {
        address user_wallet;
        uint amount;
        uint start_data;
        uint finish_data;
        uint apy_value;
        uint days_value;
        string stake_id;
    }

    struct id_params {
        uint tokenId;
        features myFeatures;
    }

    mapping(uint => features) private nft_features;

    mapping(string => uint) private stake_id_nft_id;

    mapping(uint => bool) private transferable;

    mapping(address => uint[]) private ownerOfToken;
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        initialize();
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("name", "symbol");
        __ERC721Burnable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function totalSupply() public view returns (uint256) {
        unchecked {
            return _currentIndex - _burnCounter;
        }
    }

    function mint(
        address user_wallet,
        uint amount,
        uint start_data,
        uint finish_data,
        uint apy_value,
        uint days_value,
        string memory stake_id
        ) external onlyOwner returns(uint) {
        
            _safeMint(owner(), _currentIndex);

            nft_features[_currentIndex] = features(user_wallet, amount, start_data, finish_data, apy_value, days_value, stake_id);
            stake_id_nft_id[stake_id] = _currentIndex;
            transferable[_currentIndex] = true;
            ownerOfToken[user_wallet].push(_currentIndex);

            _currentIndex += 1;
            return stake_id_nft_id[stake_id];
    }

    function getNft(uint _tokenId) public view returns(features memory) {
        return nft_features[_tokenId];
    }

    function getNftParams(address _userWallet) public view returns(id_params[] memory) {
        require(ownerOfToken[_userWallet].length != 0, "you don't have nft");
        id_params[] memory myArray = new id_params[](ownerOfToken[_userWallet].length);
        for (uint i; i < ownerOfToken[_userWallet].length; i++) {
            myArray[i] = id_params(ownerOfToken[_userWallet][i], nft_features[ownerOfToken[_userWallet][i]]);
        }
        return myArray;
    }

    function getOwnerOf(address _owner) public view returns(uint[] memory) {
        return ownerOfToken[_owner];
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
    
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }

    function setTransferable(uint _tokenId, bool _transferable) external onlyOwner {
        transferable[_tokenId] = _transferable;
    }

    function transferToken(address _addressTo, uint _tokenId) external {
        if (msg.sender == owner()) {
            _safeTransfer(_ownerOf(_tokenId), _addressTo, _tokenId, "");
        } else {
            require(msg.sender == nft_features[_tokenId].user_wallet, "you are not the owner");
            require(transferable[_tokenId] == true, "you can't transfer");
            _safeTransfer(_ownerOf(_tokenId), _addressTo, _tokenId, "");
        }
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(transferable[tokenId] == true, "you can't transfer");
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        require(transferable[tokenId] == true, "you can't transfer");
        _safeTransfer(from, to, tokenId, data);
    }

    function sendTokenClient(address _userWallet, string memory _stakeId) external onlyOwner returns(features memory) {
        require(nft_features[stake_id_nft_id[_stakeId]].user_wallet == _userWallet, "nft not found");
        _safeTransfer(_ownerOf(stake_id_nft_id[_stakeId]), _userWallet, stake_id_nft_id[_stakeId], "");
        return nft_features[stake_id_nft_id[_stakeId]];
    }

    function returnToken(address _userWallet, string memory _stakeId, bool _burnBool) external onlyOwner returns(features memory) {
        require(nft_features[stake_id_nft_id[_stakeId]].user_wallet == _userWallet, "nft not found");

        if (_burnBool) {
            burn(stake_id_nft_id[_stakeId]);
        } else {
            _safeTransfer(_ownerOf(stake_id_nft_id[_stakeId]), owner(), stake_id_nft_id[_stakeId], "");
        }

        return nft_features[stake_id_nft_id[_stakeId]];
    }

    function burn(uint256 _tokenId) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), _tokenId) || msg.sender == owner(), "ERC721: caller is not token owner or approved");
        _burn(_tokenId);

        delete stake_id_nft_id[nft_features[_tokenId].stake_id];
        
        for (uint i; i < ownerOfToken[nft_features[_tokenId].user_wallet].length; i++) {
            if (ownerOfToken[nft_features[_tokenId].user_wallet][i] == _tokenId) {
                delete ownerOfToken[nft_features[_tokenId].user_wallet][i];
                break;
            }
        }

        delete nft_features[_tokenId];
        delete transferable[_tokenId];

        _burnCounter += 1;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}
