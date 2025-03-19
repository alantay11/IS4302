// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Credify {
    mapping(address => uint256) public credifyTokenBalances;
    address public credifyOwnerAddress;
    address[] public verifiedUniAddresses;

    mapping(uint256 => uint256[]) public dailyEndorsementBuckets;
    uint256 public lastUpdatedDay;
    uint256 public bucketSize = 5;

    function addVerifiedUniAddress(address uniAddress) public {
        require(
            msg.sender == credifyOwnerAddress,
            "Only the owner can add verified university addresses"
        );
        verifiedUniAddresses.push(uniAddress);
    }

    function isVerifiedUniAddress(
        address uniAddress
    ) internal view returns (bool) {
        for (uint256 i = 0; i < verifiedUniAddresses.length; i++) {
            if (verifiedUniAddresses[i] == uniAddress) {
                return true;
            }
        }
        return false;
    }

    // Constructor to set the owner address
    constructor() {
        credifyOwnerAddress = msg.sender;
    }
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

    struct Stake {
        uint256 amount;
        uint256 institutionId;
    }

    struct Institution {
        uint256 id;
        uint256 reputationPoints;
        InstitutionType institutionType;
        InstitutionStatus institutionStatus;
        uint256 lastAuditDate;
        string name;
        // in endorsedStakes, institutionId is the company that is being endorsed by the address (investor)
        Stake[] endorsedStakes;
        // in receivedStakes, institutionId is the company that is endorsing the address (investee)
        Stake[] receivedStakes;
        // there are frozen stakes, do we need to keep track of available balance??
        AuditDecision[] auditingStakes;
        Credential[] credentialsIssued;
        address owner;
    }

    uint256 public institutionCount;
    mapping(uint256 => Institution) public institutions;
    mapping(address => uint256) public institutionIdByOwner;

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

    event CredifyTokensAdded(address indexed to, uint256 amount);

    event CredifyTokensBurned(address indexed from, uint256 amount);

    function addCredits(address to, uint256 amount) internal {
        credifyTokenBalances[to] += amount;
        emit CredifyTokensAdded(to, amount);
    }

    function burnCredits(address from, uint256 amount) internal {
        require(from == msg.sender, "Not authorized to burn");
        require(credifyTokenBalances[from] >= amount, "Insufficient credits");
        credifyTokenBalances[from] -= amount;
        emit CredifyTokensBurned(from, amount);
    }

    function createCompany(
        InstitutionStatus institutionStatus
    ) public returns (uint256) {
        institutionCount++;
        uint256 institutionId = institutionCount;

        Institution storage newInstitution = institutions[institutionId];
        newInstitution.id = institutionId;
        newInstitution.institutionType = InstitutionType.company;
        newInstitution.institutionStatus = institutionStatus;
        newInstitution.reputationPoints = 0;
        newInstitution.owner = msg.sender;
        institutionIdByOwner[msg.sender] = institutionId;

        // Set the initial amount of tokens for the institution
        addCredits(msg.sender, 50);

        emit InstitutionCreated(
            institutionId,
            InstitutionType.company,
            institutionStatus
        );
        return institutionId;
    }

    function createUniversity(
        InstitutionStatus institutionStatus
    ) public returns (uint256) {
        require(
            isVerifiedUniAddress(msg.sender),
            "Address not approved to create a university"
        );

        institutionCount++;
        uint256 institutionId = institutionCount;

        Institution storage newInstitution = institutions[institutionId];
        newInstitution.id = institutionId;
        newInstitution.institutionType = InstitutionType.university;
        newInstitution.institutionStatus = institutionStatus;
        newInstitution.reputationPoints = 0;
        newInstitution.owner = msg.sender;
        institutionIdByOwner[msg.sender] = institutionId;

        // Set the initial amount of tokens for the institution
        addCredits(msg.sender, 50);

        emit InstitutionCreated(
            institutionId,
            InstitutionType.university,
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

    // Helper function to check if the caller is the owner of the institution
    function isOwner(uint256 institutionId) internal view returns (bool) {
        return institutions[institutionId].owner == msg.sender;
    }

    modifier ownerOnly(uint256 institutionId) {
        require(isOwner(institutionId), "Caller is not the owner");
        _;
    }

    // Function to get all institutions
    function getAllInstitutions() public view returns (Institution[] memory) {
        Institution[] memory allInstitutions = new Institution[](
            institutionCount
        );
        for (uint256 i = 1; i <= institutionCount; i++) {
            Institution memory institution = institutions[i];
            if (!isOwner(i)) {
                delete institution.endorsedStakes;
                delete institution.receivedStakes;
                delete institution.auditingStakes;
            }
            allInstitutions[i - 1] = institution;
        }
        return allInstitutions;
    }

    // Function to get an institution
    function getInstitution(
        uint256 institutionId
    ) public view returns (Institution memory) {
        Institution memory institution = institutions[institutionId];
        if (!isOwner(institutionId)) {
            delete institution.endorsedStakes;
            delete institution.receivedStakes;
            delete institution.auditingStakes;
        }
        return institution;
    } // if owner, get all, if not, only all details except stakes and auditing stakes

    // this is to get the whole list,
    // but consider whether to check the stake some company put on certain company company,
    // this will need a seperate method, requiring both the company and the checked company id

    function getStakesEndorsed(
        // get who the company has endorsed
        uint256 investorId
    ) public view ownerOnly(investorId) returns (Stake[] memory) {
        return institutions[investorId].endorsedStakes;
    }

    function getStakesReceived(
        // get who has endorsed the company
        uint256 investeeId
    ) public view ownerOnly(investeeId) returns (Stake[] memory) {
        return institutions[investeeId].receivedStakes;
    }

    // Function to view stakes put in the company for auditing
    function getAuditingStakes(
        // get who the company is auditing
        uint256 institutionId
    ) public view ownerOnly(institutionId) returns (AuditDecision[] memory) {
        return institutions[institutionId].auditingStakes;
    }


    // Function to update the daily endorsement buckets
    function updateDailyEndorsementBuckets() public {
        // Check if it's a new day
        uint256 today = block.timestamp / 1 days; 
        
        if (today > lastUpdatedDay) {
            lastUpdatedDay = today;
            
            // For each institution, create a new bucket
            for (uint256 i = 1; i <= institutionCount; i++) {
                // Only create buckets for eligible institutions
                if (institutions[i].institutionStatus == InstitutionStatus.unaudited) {
                    // Clear the previous bucket
                    delete dailyEndorsementBuckets[i];
                    
                    // Create a pool of eligible institutions to endorse
                    uint256[] memory eligibleInstitutions = new uint256[](institutionCount);
                    uint256 eligibleCount = 0;
                    
                    for (uint256 j = 1; j <= institutionCount; j++) {
                        // Don't include self or already endorsed institutions 
                        // ASK: i dont know other way to exclude self, 
                        // since doin this loop anyways, might as well just exclude alr endorsed institutions
                        if (i != j && isEligibleForEndorsement(i, j)) {
                            eligibleInstitutions[eligibleCount] = j;
                            eligibleCount++;
                        }
                    }
                    
                    // Fill the bucket with random institutions
                    uint256 actualBucketSize = bucketSize < eligibleCount ? bucketSize : eligibleCount;
                    
                    for (uint256 k = 0; k < actualBucketSize; k++) {
                        uint256 randomIndex = generateRandomNumber(i * 1000 + k, eligibleCount - k);
                        
                        // Add the selected institution to the bucket
                        dailyEndorsementBuckets[i].push(eligibleInstitutions[randomIndex]);
                        
                        // Swap the selected institution with the last one to avoid duplicates
                        eligibleInstitutions[randomIndex] = eligibleInstitutions[eligibleCount - k - 1];
                    }
                }
            }
        }
    }

    // This function generates a random number using block variables and a nonce
    private function generateRandomNumber(uint256 seed, uint256 max) internal view returns (uint256) {
        // Combine multiple sources of entropy
        // Not Truly Random due to the nature of Solidity, and Chainlink VRF need to pay 
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            block.difficulty,
            seed
        )));
        
        return randomNumber % max;
    }


    private function isEligibleForEndorsement(uint256 endorserId, uint256 endorseeId) internal view returns (bool) {
        // Check if the endorser has already endorsed this institution
        Stake[] memory endorsedStakes = institutions[endorserId].endorsedStakes;
        
        for (uint256 i = 0; i < endorsedStakes.length; i++) {
            if (endorsedStakes[i].institutionId == endorseeId) {
                return false;
            }
        }
        return true;
    }


    // Function to get today's endorsement bucket for an institution
    function getTodayEndorsementBucket(uint256 institutionId) public view returns (uint256[] memory) {
        return dailyEndorsementBuckets[institutionId];
    }

    // //function to create a new dice, and add to 'dices' map. requires at least 0.01ETH to create
    // function add(
    //     uint8 numberOfSides,
    //     uint8 color
    // ) public payable returns (uint256) {
    //     require(numberOfSides > 0);
    //     require(
    //         msg.value > 0.01 ether,
    //         "at least 0.01 ETH is needed to spawn a new dice"
    //     );

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
