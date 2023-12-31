// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Base64} from "base64-sol/base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "reference/src/lib/ERC6551AccountLib.sol";
import "reference/src/interfaces/IERC6551Registry.sol";
import "juice-token-resolver/src/Libraries/StringSlicer.sol";
import "./interfaces/ISBTofRole.sol";

/// @title DAO6551
/// @notice An DAO that members consist of abstract accounts.
/// @dev An ERC-721 NFT implementation which can mint SBT as the role of DAO.
/// @author web3roy
contract DAO6551 is ERC721 {
    ISBTofRole public immutable sbta;
    ISBTofRole public immutable sbtb;
    ISBTofRole public immutable sbtc;
    using Strings for uint256; // Turns uints into strings
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public totalSupply; // The total number of tokens minted on this contract
    address public immutable implementation; // The Piggybank6551Implementation address
    IERC6551Registry public immutable registry; // The 6551 registry address
    uint public immutable chainId = block.chainid; // The chainId of the network this contract is deployed on
    address public immutable tokenContract = address(this); // The address of this contract
    uint salt = 0; // The salt used to generate the account address
    uint public immutable maxSupply; // The maximum number of tokens that can be minted on this contract
    uint public immutable price;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _implementation,
        address _registry,
        uint _maxSupply,
        uint _price,
        address _sbta,
        address _sbtb,
        address _sbtc
    ) ERC721("DAO6551", "DAO6551") {
        implementation = _implementation;
        registry = IERC6551Registry(_registry);
        maxSupply = _maxSupply;
        price = _price;
        sbta = ISBTofRole(_sbta);
        sbtb = ISBTofRole(_sbtb);
        sbtc = ISBTofRole(_sbtc);
    }

    /**************************/
    /**** Abstract Account ****/
    /**************************/

    function getAccount(uint tokenId) public view returns (address) {
        return
            registry.account(
                implementation,
                chainId,
                tokenContract,
                tokenId,
                salt
            );
    }

    function createAccount(uint tokenId) public returns (address) {
        return
            registry.createAccount(
                implementation,
                chainId,
                tokenContract,
                tokenId,
                salt,
                ""
            );
    }

    function mint() external payable returns (uint256) {
        require(totalSupply < maxSupply, "Max supply reached");
        require(msg.value >= price, "Insufficient funds");
        _safeMint(msg.sender, ++totalSupply);
        return totalSupply;
    }

    function getRoleA(uint tokenId) external payable {
        require(msg.value >= price, "Insufficient funds");
        sbta.mint(getAccount(tokenId));
    }

    function getRoleB(uint tokenId) external payable {
        require(msg.value >= price, "Insufficient funds");
        sbtb.mint(getAccount(tokenId));
    }

    function getRoleC(uint tokenId) external payable {
        require(msg.value >= price, "Insufficient funds");
        sbtc.mint(getAccount(tokenId));
    }

    function addEth(uint tokenId) external payable {
        address account = getAccount(tokenId);
        (bool success, ) = account.call{value: msg.value}("");
        require(success, "Failed to send ETH");
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        address account = getAccount(tokenId);
        string[] memory uriParts = new string[](4);
        string memory balance = "0";
        string memory ethBalanceTwoDecimals = "0";
        string memory roleship = "none";
        if (sbta.balanceOf(account) > 0) {
            roleship = "Admin";
        }
        if (sbtb.balanceOf(account) > 0) {
            roleship = "Developer";
        }
        if (sbtc.balanceOf(account) > 0) {
            roleship = "Contributor";
        }
        if (sbtb.balanceOf(account) > 0 && sbtc.balanceOf(account) > 0) {
            roleship = "Developer, Contributor";
        }
        if (ownerOf(tokenId) == account) {
            uriParts[0] = string("data:application/json;base64,");
            uriParts[1] = string(
                abi.encodePacked(
                    '{"name":"DAO6551 #',
                    tokenId.toString(),
                    ' (Burned)",',
                    '"description":"DAO6551 ",',
                    '"attributes":[{"trait_type":"Balance","value":"0"},{"trait_type":"Status","value":"Burned"}],',
                    '"image":"data:image/svg+xml;base64,'
                )
            );
            uriParts[2] = Base64.encode(
                abi.encodePacked(
                    '<svg width="1000" height="1000" viewBox="0 0 1000 1000" xmlns="http://www.w3.org/2000/svg">',
                    '<rect width="1000" height="1000" fill="black"/>',
                    '<text x="80" y="276" fill="white" font-family="Helvetica" font-size="130" font-weight="bold">',
                    "DAO6551 #",
                    tokenId.toString(),
                    "</text>",
                    '<text x="80" y="425" fill="white" font-family="Helvetica" font-size="130" font-weight="bold">',
                    " activity </text>",
                    "</svg>"
                )
            );
            uriParts[3] = string('"}');
        } else {
            uriParts[0] = string("data:application/json;base64,");
            uriParts[1] = string(
                abi.encodePacked(
                    '{"name":"DAO6551 #',
                    tokenId.toString(),
                    '",',
                    '"description":"DAO6551 ",',
                    '"attributes":[{"trait_type":"Balance","value":"',
                    ethBalanceTwoDecimals,
                    ' ETH"},{"trait_type":"Status","value":"Exists"}],',
                    '"image":"data:image/svg+xml;base64,'
                )
            );
            uriParts[2] = Base64.encode(
                abi.encodePacked(
                    '<svg width="1000" height="1000" viewBox="0 0 1000 1000" xmlns="http://www.w3.org/2000/svg">',
                    '<rect width="1000" height="1000" fill="hsl(',
                    (address(account).balance / 10 ** 17).toString(),
                    ', 78%, 56%)"/>',
                    '<text x="80" y="276" fill="white" font-family="Helvetica" font-size="70" font-weight="bold">',
                    "DAO6551 #",
                    tokenId.toString(),
                    "</text>",
                    '<text x="80" y="425" fill="white" font-family="Helvetica" font-size="70" font-weight="bold">',
                    " contains role: </text>",
                    '<text x="80" y="574" fill="white" font-family="Helvetica" font-size="70" font-weight="bold">',
                    roleship,
                    "</text>",
                    "</svg>"
                )
            );
            uriParts[3] = string('"}');
        }

        string memory uri = string.concat(
            uriParts[0],
            Base64.encode(
                abi.encodePacked(uriParts[1], uriParts[2], uriParts[3])
            )
        );

        return uri;
    }
}
