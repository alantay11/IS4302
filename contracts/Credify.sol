// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Credify {
    enum InstitutionType {
        company,
        university
    }
    enum InstitutionStatus {
        reputable,
        unreputable,
        eligibleToBeAudited,
        unaudited
    }

    struct Credential {
        uint256 institutionId;
        string recipient;
        string credentialName;
        string description; // Brief description of the credential
        string url; // Link to detailed information stored off-chain
        string ipfsHash; // IPFS hash of the credential for verification with url contents
        uint256 issueDate;
    }

    struct AuditDecision {
        uint256 stakeAmount;
        bool voteReputable;
    }

    struct Institution {
        uint256 id;
        uint256 reputationPoints;
        InstitutionType institutionType;
        InstitutionStatus institutionStatus;
        uint256 lastAuditDate;
        mapping(address => uint256) endorsedStakes;
        mapping(address => uint256) receivedStakes;
        mapping(address => AuditDecision) auditingStakes;
        Credential[] credentialsIssued;
    }

    uint256 public institutionCount;
    mapping(uint256 => Institution) public institutions;

    event InstitutionCreated(
        uint256 indexed institutionId,
        InstitutionType institutionType,
        InstitutionStatus institutionStatus
    );

    event CredentialAdded(
        uint256 indexed institutionId,
        string recipient,
        string credentialName,
        string url,
        string ipfsHash
    );

    // Function to create a new institution
    function createInstitution(
        InstitutionType institutionType,
        InstitutionStatus institutionStatus
    ) public returns (uint256) {
        institutionCount++;
        uint256 institutionId = institutionCount;

        Institution storage newInstitution = institutions[institutionId];
        newInstitution.id = institutionId;
        newInstitution.institutionType = institutionType;
        newInstitution.institutionStatus = institutionStatus;
        newInstitution.reputationPoints = 0;

        emit InstitutionCreated(
            institutionId,
            institutionType,
            institutionStatus
        );
        return institutionId;
    }

    function addCredential(
        uint256 institutionId,
        string memory recipient,
        string memory credentialName,
        string memory description,
        string memory url,
        string memory ipfsHash
    ) public {
        require(
            institutions[institutionId].institutionStatus ==
                InstitutionStatus.reputable,
            "Institution must be reputable to issue credentials"
        );

        Credential memory newCredential = Credential({
            institutionId: institutionId,
            recipient: recipient,
            credentialName: credentialName,
            description: description,
            url: url,
            ipfsHash: ipfsHash,
            issueDate: block.timestamp
        });

        institutions[institutionId].credentialsIssued.push(newCredential);
        emit CredentialAdded(
            institutionId,
            recipient,
            credentialName,
            url,
            ipfsHash
        ); // Updated event emission
    }

    // Function to get the credentials of an institution
    function getCredentials(
        uint256 institutionId
    ) public view returns (Credential[] memory) {
        return institutions[institutionId].credentialsIssued;
    }

    //function to create a new dice, and add to 'dices' map. requires at least 0.01ETH to create
    function add(
        uint8 numberOfSides,
        uint8 color
    ) public payable returns (uint256) {
        require(numberOfSides > 0);
        require(
            msg.value > 0.01 ether,
            "at least 0.01 ETH is needed to spawn a new dice"
        );

        //new dice object
        // dice memory newDice = dice(
        //     numberOfSides,
        //     color,
        //     (uint8)(block.timestamp % numberOfSides) + 1,  //non-secure random number
        //     diceState.stationary,
        //     msg.value,
        //     msg.sender,  //owner
        //     address(0),
        //     0 // Ex1
        // );

        //     uint256 newDiceId = numDices++;
        //     dices[newDiceId] = newDice; //commit to state variable
        //     return newDiceId;   //return new diceId
    }

    // //modifier to ensure a function is callable only by its owner
    // modifier ownerOnly(uint256 diceId) {
    //     require(dices[diceId].owner == msg.sender);
    //     _;
    // }

    // modifier validDiceId(uint256 diceId) {
    //     require(diceId < numDices);
    //     _;
    // }

    // //owner can roll a dice
    // function roll(uint256 diceId) public ownerOnly(diceId) validDiceId(diceId) {
    //         dices[diceId].state = diceState.rolling;    //set state to rolling
    //         dices[diceId].currentNumber = 0;    //number will become 0 while rolling
    //         emit rolling(diceId);   //emit rolling event
    // }

    // function stopRoll(uint256 diceId) public ownerOnly(diceId) validDiceId(diceId) {
    //         dices[diceId].state = diceState.stationary; //set state to stationary

    //         //this is not a secure randomization
    //         uint8 newNumber = (uint8)((block.timestamp*(diceId+1)) % dices[diceId].numberOfSides) + 1;
    //         dices[diceId].currentNumber = newNumber;

    //         // LUCKY TIMES
    //         if (newNumber == dices[diceId].numberOfSides) {
    //             dices[diceId].luckyTimes = dices[diceId].luckyTimes + 1;
    //             emit luckytimesEvent(diceId);
    //         }
    //         emit rolled(diceId, newNumber); //emit rolled
    // }

    // //transfer ownership to new owner
    // function transfer(uint256 diceId, address newOwner) public ownerOnly(diceId) validDiceId(diceId) {
    //     dices[diceId].prevOwner = dices[diceId].owner;
    //     dices[diceId].owner = newOwner;
    // }

    // //get number of sides of dice
    // function getDiceSides(uint256 diceId) public view validDiceId(diceId) returns (uint8) {
    //     return dices[diceId].numberOfSides;
    // }

    // //get current dice number
    // function getDiceNumber(uint256 diceId) public view validDiceId(diceId) returns (uint8) {
    //     return dices[diceId].currentNumber;
    // }

    // //get ether put in during creation
    // function getDiceValue(uint256 diceId) public view validDiceId(diceId) returns (uint256) {
    //     return dices[diceId].creationValue;
    // }

    // //Ex1 Get luckyTimes
    // function getLuckyTimes(uint256 diceId) public view validDiceId(diceId) returns (uint256) {
    //     return dices[diceId].luckyTimes;
    // }

    // //Ex 1 Destroy Dice
    // function destroyDice(uint256 diceId) public ownerOnly(diceId) validDiceId(diceId) {
    //     uint256 value = dices[diceId].creationValue;
    //     delete dices[diceId]; // Remove from mapping
    //     payable(msg.sender).transfer(value); // Return value
    // }

    // function getPrevOwner(uint256 diceId) public view validDiceId(diceId) returns (address) {
    //     return dices[diceId].prevOwner;
    // }

    // function getOwner(uint256 diceId) public view validDiceId(diceId) returns (address) {
    //     return dices[diceId].owner;
    // }
}
