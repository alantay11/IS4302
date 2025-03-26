// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Credential.sol";

contract Credify {
    mapping(address => uint256) public credifyTokenBalances;
    address public credifyOwnerAddress;
    address[] public verifiedUniAddresses;

    // Store endorsement buckets for each institution on each day
    mapping(uint256 => mapping(uint256 => uint256[])) public dailyEndorsementBucketsCache;
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

    // CH: To facilitate difference in reward process for endorsee and auditee
    // only endorsee will receive tokens staked in them, auditee does not
    enum ProcessingStatus {
        endorsee,
        auditee 
    }

    struct AuditDecision {
        uint256 stakeAmount;
        bool voteReputable;
        uint256 institutionId;
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
        uint256 lastAuditDate; // timestamp of the last audit
        string name;
        // in endorsedStakes, institutionId is the company that is being endorsed by the address (investor)
        Stake[] endorsedStakes;
        // in receivedStakes, institutionId is the company that is endorsing the address (investee)
        Stake[] receivedStakes;
        AuditDecision[] auditorStakes;
        AuditDecision[] auditeeStakes;
        address[] credentialsIssued;
        address owner;
    }

    uint256 public institutionCount;
    mapping(uint256 => Institution) public institutions;
    mapping(address => uint256) public institutionIdByOwner;
    Institution[] public auditeePool;
    Institution[] public auditorPool;

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
        newInstitution.processingStatus = ProcessingStatus.endorsee;
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
    ) ownerOnly(institutionId) public {
        require(
            institutions[institutionId].institutionStatus ==
                InstitutionStatus.reputable,
            "Institution must be reputable to issue credentials"
        );
        //TODO: Add requirement to check token balance
        //TODO: Burn credits when credentials are created

        address newCredential = new Credential({
            owner: msg.sender,
            credifyInstitutionId: institutionId,
            recipient: recipient,
            credentialName: credentialName,
            description: description,
            url: url,
            ipfsHash: ipfsHash
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
                delete institution.auditorStakes;
                delete institution.auditeeStakes;
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
            delete institution.auditorStakes;
            delete institution.auditeeStakes;
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

    // NEW: Function to view stakes auditor placed in others
    function getAuditorStakes(
        // get auditor institution identifer
        uint256 institutionId
    ) public view ownerOnly(institutionId) returns (AuditDecision[] memory) {
        return institutions[institutionId].auditorStakes;
    }

    // NEW: Function to view stakes placed by others in auditee
    function getAuditeeStakes(
        // get auditee institution identifer
        uint256 institutionId
    ) public view ownerOnly(institutionId) returns (AuditDecision[] memory) {
        return institutions[institutionId].auditeeStakes;
    }

    // Function to get the endorsement list for a specific institution
    function getTodayEndorsementBucket(uint256 institutionId) public returns (uint256[] memory) {
        require(institutions[institutionId].institutionStatus == InstitutionStatus.unaudited, "Not eligible for endorsement.");
        uint256 today = block.timestamp / 1 days;

        // Check if the endorsement bucket for today already exists for this institution
        if (dailyEndorsementBucketsCache[institutionId][today].length == 0) {
            // No bucket exists for today, so generate it
            generateEndorsementBucket(institutionId, today);
        }
        
        // Return the endorsement bucket (cached)
        return dailyEndorsementBucketsCache[institutionId][today];
    }

    private function generateEndorsementBucket(uint256 institutionId, uint256 today) internal {      
        // Clear the previous buckets for this institution
        delete dailyEndorsementBucketsCache[institutionId];

        // Create a pool of eligible institutions to endorse
        // CH: eligibleInstitutions needs to check if the institution has the unaudited status
        uint256[] memory eligibleInstitutions = new uint256[](institutionCount);
        uint256 eligibleCount = 0;
        
        for (uint256 j = 1; j <= institutionCount; j++) {
            // Don't include self or already endorsed institutions 
            // ASK: i dont know other way to exclude self, 
            // since doin this loop anyways, might as well just exclude alr endorsed institutions
            if (institutionId != j && isEligibleForEndorsement(institutionId, j)) {
                eligibleInstitutions[eligibleCount] = j;
                eligibleCount++;
            }
        }

        // Fill the bucket with random institutions
        uint256 actualBucketSize = bucketSize < eligibleCount ? bucketSize : eligibleCount;
        

        for (uint256 k = 0; k < actualBucketSize; k++) {
            uint256 randomIndex = generateRandomNumber(institutionId * 1000 + k, eligibleCount - k);
            
            // Add the selected institution to the bucket
            dailyEndorsementBucketsCache[institutionId][today].push(eligibleInstitutions[randomIndex]);
            
            // Swap the selected institution with the last one to avoid duplicates
            eligibleInstitutions[randomIndex] = eligibleInstitutions[eligibleCount - k - 1];
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

    // New events for endorsement and audit processes
    event EndorsementSubmitted(
        uint256 indexed endorserId,
        uint256 indexed endorseeId,
        uint256 stakeAmount
    );
    event EndorsementProcessed(uint256 indexed endorseeId, bool success);
    event AuditFinalized(
        uint256 indexed auditorId,
        uint256 indexed auditeeId,
        bool auditPassed
    );

    // Function to submit endorsements
    function submitEndorsements(uint256[] memory endorseeIds, uint256[] memory stakeAmounts) public {
        require(endorseeIds.length == stakeAmounts.length, "Mismatched input lengths");

        // CH: do we need to check if the endorseeId is inside the msg.sender's (endorser) basket?
        uint256 endorserId = institutionIdByOwner[msg.sender];
        require(endorserId > 0, "Endorser not registered");

        for (uint256 i = 0; i < endorseeIds.length; i++) {
            uint256 endorseeId = endorseeIds[i];
            uint256 stakeAmount = stakeAmounts[i];

            require(
                credifyTokenBalances[msg.sender] >= stakeAmount,
                "Insufficient CredifyToken balance"
            );
            require(
                institutions[endorseeId].institutionStatus == InstitutionStatus.unaudited,
                "Endorsee must be unaudited"
            );

            // Deduct tokens from endorser and update stakes
            // CH: burnCredits is not really to burn from the system but just to deduct from the endorser
            // CH: if team doesn't like burning, we can do "credifyTokenBalances[msg.sender] -= stakeAmount" instead
            burnCredits(msg.sender, stakeAmount);
            institutions[endorserId].endorsedStakes.push(Stake(stakeAmount, endorseeId));
            institutions[endorseeId].receivedStakes.push(Stake(stakeAmount, endorserId));

            emit EndorsementSubmitted(endorserId, endorseeId, stakeAmount);
        }
    }

    // Function to process endorsements
    function processEndorsements(uint256 endorseeId) public {
        Institution storage endorsee = institutions[endorseeId];
        // Endorsements are only needed for unaudited institutions
        require(
            endorsee.institutionStatus == InstitutionStatus.unaudited,
            "Endorsee must be unaudited"
        );

        // Determine if the endorsee is eligible for auditing
        uint256 totalReceivedStakes = calculateTotalReceivedStakes(endorseeId);
        require(
            totalReceivedStakes + credifyTokenBalances[endorsee.owner] >= 100,
            "Sum of available token balance and received stakes must be at least 100"
        );

        // Move endorsee to auditee pool and process audit to determine success/failure of endorsement
        endorsee.institutionStatus = InstitutionStatus.eligibleToBeAudited;
        processAudit(endorseeId);
        emit EndorsementProcessed(endorseeId, true);
    }

    // Helper function to calculate total received stakes for an institution
    function calculateTotalReceivedStakes(uint256 institutionId) public view returns (uint256) {
        Stake[] memory receivedStakes = institutions[institutionId].receivedStakes;
        uint256 totalReceivedStakes = 0;

        for (uint256 i = 0; i < receivedStakes.length; i++) {
            totalReceivedStakes += receivedStakes[i].amount;
        }

        return totalReceivedStakes;
    }

    event AuditDecisionMade(
        uint256 indexed auditorId,
        uint256 indexed auditeeId,
        uint256 stakeAmount,
        bool voteReputable
    );

    event AuditProcessed(
        uint256 indexed auditeeId,
        bool auditPassed
    );

    function getInstitutionsForAudit() public {
        delete auditeePool;
        for (uint256 i = 1; i <= institutionCount; i++) {
            Institution memory institution = institutions[i];
            if ((institution.institutionStatus == InstitutionStatus.reputable) && (institution.lastAuditDate + 180 days > block.timestamp)) {
                institutions[i].processingStatus = ProcessingStatus.auditee;
                auditeePool.push(institution);
            }
            if (institution.institutionStatus == InstitutionStatus.eligibleToBeAudited) {
                auditeePool.push(institution);
            }
        }
        return auditeePool;
    }

    function getAuditorPool() public view returns (Institution[] memory) {
        delete auditorPool;
        for (uint256 i = 1; i <= institutionCount; i++) {
            Institution memory institution = institutions[i];
            if ((institution.institutionStatus == InstitutionStatus.reputable) && (institution.lastAuditDate + 180 days <= block.timestamp)) {
                auditorPool.push(institution);
            }
        }
        return auditorPool;
    }

    // Function for an auditor to make an audit decision
    function makeAuditDecision(
        uint256 auditorId,
        uint256 auditeeId,
        uint256 stakeAmount,
        bool voteReputable
    ) public {
        Institution storage auditor = institutions[auditorId];
        Institution storage auditee = institutions[auditeeId];
        require(
            auditee.institutionStatus == InstitutionStatus.eligibleToBeAudited || 
                auditee.institutionStatus == InstitutionStatus.reputable,
            "Auditee must be eligible to be audited or reputable"
        );
        require(
            credifyTokenBalances[auditor.owner] >= stakeAmount,
            "Insufficient CredifyTokens for staking"
        );
        require(stakeAmount >= 1 / 10 * credifyTokenBalances[auditor.owner],
            "Stake amount must be at least 10% of the auditor's balance"
        );

        // Deduct staked tokens from the auditor
        burnCredits(auditor.owner, stakeAmount);

        // Record the audit decision
        institutions[auditorId].auditorStakes.push(AuditDecision(stakeAmount, voteReputable, auditeeId));
        institutions[auditeeId].auditeeStakes.push(AuditDecision(stakeAmount, voteReputable, auditorId));

        // CH: confirm with team if this is the way to help auditee reach audit threshold faster
        // Token of appreciation given to auditors for making audit decision
        institutions[auditorId].reputationPoints += 10;

        emit AuditDecisionMade(auditorId, auditeeId, stakeAmount, voteReputable);
    }

    // Function to process audits for an auditee
    function processAudit(uint256 auditeeId) public {
        Institution storage auditee = institutions[auditeeId];

        uint256 totalVotes = 0;
        uint256 reputableVotes = 0;
        
        // Tally votes from all auditors
        for (uint256 i = 0; i < auditee.auditeeStakes.length; i++) {
            totalVotes++;
            if (auditee.auditeeStakes[i].voteReputable) {
                reputableVotes++;
            }
        }

        uint256 auditorPoolSize = getAuditorPool().length;
        // Ensure minimum number of votes is reached before processing
        // CH: criteria to process audit to be confirmed by team
        require(totalVotes >= 2 / 3 * auditorPoolSize, "Not enough audit decisions to process");

        // Determine if the audit passed based on the majority vote
        // CH: need to handle the case where reputableVotes and notReputableVotes is even
        bool auditPassed = reputableVotes > totalVotes / 2;

        if (auditPassed) {
            // Reward all auditors with a 10% bonus on their stakes and mark the auditee as reputable
            for (uint256 i = 0; i < auditee.auditeeStakes.length; i++) {
                AuditDecision memory decision = auditee.auditeeStakes[i];
                address auditor = institutions[decision.institutionId].owner;
                addCredits(auditor, (decision.stakeAmount * 11) / 10);
                for (uint256 j = 0; j < institutions[auditorId].auditorStakes.length; j++) {
                    if (institutions[auditorId].auditorStakes[j].institutionId == auditeeId) {
                        delete institutions[auditorId].auditorStakes[j];
                        break;
                    }
                }
            }
            auditee.institutionStatus = InstitutionStatus.reputable;
            emit AuditProcessed(auditeeId, true);
            // Process endorsement for auditees who are endorsees
            for (uint256 i = 0; i < auditee.receivedStakes.length; i++) {
                Stake memory stake = auditee.receivedStakes[i];
                address endorser = institutions[stake.institutionId].owner;
                addCredits(endorser, (stake.amount * 11) / 10);
                if (auditee.processingStatus == ProcessingStatus.endorsee) {
                    addCredits(auditee.owner, stake.amount);
                }
                delete institutions[stake.institutionId].receivedStakes;
                for (uint256 j = 0; j < institutions[stake.institutionId].auditorStakes.length; j++) {
                    if (institutions[stake.institutionId].auditorStakes[j].institutionId == auditeeId) {
                        delete institutions[stake.institutionId].auditorStakes[j];
                        break;
                    }
                }
            }
        } else {
            // Penalize all auditors with a 30% deduction on their stakes and mark the auditee as unreputable
            for (uint256 i = 0; i < auditee.auditeeStakes.length; i++) {
                AuditDecision memory decision = auditee.auditeeStakes[i];
                address auditor = institutions[decision.institutionId].owner;
                addCredits(auditor, (decision.stakeAmount * 7) / 10);
                for (uint256 j = 0; j < institutions[auditorId].auditorStakes.length; j++) {
                    if (institutions[auditorId].auditorStakes[j].institutionId == auditeeId) {
                        delete institutions[auditorId].auditorStakes[j];
                        break;
                    }
                }
            }
            auditee.institutionStatus = InstitutionStatus.unreputable;
            emit AuditProcessed(auditeeId, false);
            // Process endorsement for auditees who are endorsees
            for (uint256 i = 0; i < auditee.receivedStakes.length; i++) {
                Stake memory stake = auditee.receivedStakes[i];
                address endorser = institutions[stake.institutionId].owner;
                addCredits(endorser, (stake.amount * 7) / 10);
                delete institutions[stake.institutionId].receivedStakes;
                for (uint256 j = 0; j < institutions[stake.institutionId].auditorStakes.length; j++) {
                    if (institutions[stake.institutionId].auditorStakes[j].institutionId == auditeeId) {
                        delete institutions[stake.institutionId].auditorStakes[j];
                        break;
                    }
                }
            }
        }

        // CH: Update the last audit date for the auditee (so that reputable endorsee is not subjected to audit immediately after being endorsed)
        auditee.lastAuditDate = block.timestamp;

        // Clear auditing stakes after processing
        delete auditee.auditeeStakes;
    }
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