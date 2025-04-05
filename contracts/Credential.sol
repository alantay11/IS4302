// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Credential {
    address private owner;
    uint256 private credifyInstitutionId;
    string private recipient;
    string private credentialName;
    string private description; // Brief description of the credential
    string private url; // Link to detailed information stored off-chain
    string private ipfsHash; // IPFS hash of the credential for verification with URL contents
    uint256 private issueDate;

    constructor(
        address _owner,
        uint256 _credifyInstitutionId,
        string memory _recipient,
        string memory _credentialName,
        string memory _description,
        string memory _url,
        string memory _ipfsHash
    ) {
        owner = _owner;
        credifyInstitutionId = _credifyInstitutionId;
        recipient = _recipient;
        credentialName = _credentialName;
        description = _description;
        url = _url;
        ipfsHash = _ipfsHash;
        issueDate = block.timestamp;
    }

    function getCredentialDetails() public view returns (
        address _owner,
        uint256 _credifyInstitutionId, 
        string memory _recipient, 
        string memory _credentialName, 
        string memory _description, 
        string memory _url, 
        string memory _ipfsHash, 
        uint256 _issueDate
    ) {
        return (owner, credifyInstitutionId, recipient, credentialName, description, url, ipfsHash, issueDate);
    }
    
    function getCredentialOwner() public view returns (
        address
    ) {
        return owner;
    }
}
