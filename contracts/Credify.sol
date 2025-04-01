// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Credential.sol";

contract Credify {
    mapping(address => uint256) public credifyTokenBalances;
    address public credifyOwnerAddress;
    address[] public verifiedUniAddresses;
    uint256 private constant CREDENTIAL_GENERATION_COST = 10;
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

    // To facilitate difference in reward process for endorsee and auditee
    // only endorsee will receive tokens staked in them, auditee does not
    enum ProcessingStatus {
        endorsee,
        auditee,
        others
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
        ProcessingStatus processingStatus;
        uint256[] todayEndorsementBucket; // New field to store today’s bucket
        uint256 lastUpdatedDate; // New field to track last update
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

    function addCredits(address to, uint256 amount) private {
        credifyTokenBalances[to] += amount;
        emit CredifyTokensAdded(to, amount);
    }

    function burnCredits(address from, uint256 amount) private {
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
        newInstitution.processingStatus = ProcessingStatus.others;
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
    ) public ownerOnly(institutionId) {
        require(
            institutions[institutionId].institutionStatus ==
                InstitutionStatus.reputable,
            "Institution must be reputable to issue credentials"
        );
        //Burn credits when credentials are created.
        burnCredits(msg.sender, CREDENTIAL_GENERATION_COST);

        Credential newCredential = new Credential(
            msg.sender,
            institutionId,
            recipient,
            credentialName,
            description,
            url,
            ipfsHash
        );

        address newCredentialAddress = address(newCredential);
        institutions[institutionId].credentialsIssued.push(
            newCredentialAddress
        );
        emit CredentialAdded(
            institutionId,
            recipient,
            credentialName,
            url,
            ipfsHash
        );
    }

    // Function to get the credentials of an institution
    function getCredentials(
        uint256 institutionId
    ) public view returns (address[] memory) {
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

    // Function to view stakes auditor placed in others
    function getAuditorStakes(
        // get auditor institution identifer
        uint256 institutionId
    ) public view ownerOnly(institutionId) returns (AuditDecision[] memory) {
        return institutions[institutionId].auditorStakes;
    }

    // Function to view stakes placed by others in auditee
    function getAuditeeStakes(
        // get auditee institution identifer
        uint256 institutionId
    ) public view ownerOnly(institutionId) returns (AuditDecision[] memory) {
        return institutions[institutionId].auditeeStakes;
    }

    // Function to get the endorsement list for a specific institution
    function getTodayEndorsementBucket() public returns (uint256[] memory) {
        uint256 institutionId = institutionIdByOwner[msg.sender];
        require(
            institutionId > 0,
            "Caller is not registered as an institution"
        );
        require(
            institutions[institutionId].institutionStatus ==
                InstitutionStatus.unaudited,
            "Not eligible for endorsement."
        );
        uint256 today = block.timestamp / 1 days;

        // If today's endorsement bucket is outdated, regenerate it
        if (institutions[institutionId].lastUpdatedDate != today) {
            generateEndorsementBucket(institutionId, today);
        }

        return institutions[institutionId].todayEndorsementBucket;
    }

    function generateEndorsementBucket(
        uint256 institutionId,
        uint256 today
    ) internal {
        Institution storage institution = institutions[institutionId];
        delete institution.todayEndorsementBucket;

        // Create a pool of eligible institutions to endorse
        uint256[] memory eligibleInstitutions = new uint256[](institutionCount);
        uint256 eligibleCount = 0;

        for (uint256 j = 1; j <= institutionCount; j++) {
            if (institutionId != j && statusIsUnaudited(j) && notAlreadyEndorsed(institutionId, j)) {
                eligibleInstitutions[eligibleCount] = j;
                eligibleCount++;
            }
        }

        // Fill the bucket with random institutions
        uint256 actualBucketSize = bucketSize < eligibleCount
            ? bucketSize
            : eligibleCount;

        for (uint256 k = 0; k < actualBucketSize; k++) {
            uint256 randomIndex = generateRandomNumber(
                institutionId * 1000 + k,
                eligibleCount - k
            );
            // Add the selected institution to the bucket
            institution.todayEndorsementBucket.push(
                eligibleInstitutions[randomIndex]
            );
            // Swap the selected institution with the last one to avoid duplicates
            eligibleInstitutions[randomIndex] = eligibleInstitutions[
                eligibleCount - k - 1
            ];
        }

        institution.lastUpdatedDate = today;
    }

    // This function generates a random number using block variables and a nonce
    function generateRandomNumber(
        uint256 seed,
        uint256 max
    ) internal view returns (uint256) {
        // Combine multiple sources of entropy
        // Not Truly Random due to the nature of Solidity, and Chainlink VRF need to pay
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    block.timestamp,
                    block.prevrandao,
                    seed
                )
            )
        );

        return randomNumber % max;
    }

    function statusIsUnaudited(
        uint256 institutionId
    ) internal view returns (bool) {
        return
            institutions[institutionId].institutionStatus ==
            InstitutionStatus.unaudited;
    }

    function notAlreadyEndorsed(
        uint256 endorserId,
        uint256 endorseeId
    ) internal view returns (bool) {
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

    // Function to submit endorsements
    function submitEndorsements(
        uint256[] memory endorseeIds,
        uint256[] memory stakeAmounts
    ) public {
        // [DONE] TO-DO: check whether the endorseeId is in the bucket
        uint256[] memory endorserBucket = getTodayEndorsementBucket();
        //  Ensure all endorseeIds are in the bucket
        for (uint256 i = 0; i < endorseeIds.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < endorserBucket.length; j++) {
                if (endorseeIds[i] == endorserBucket[j]) {
                    found = true;
                    break;
                }
            }
            require(found, "Endorsee not in today's endorsement bucket");
        }
        require(
            endorseeIds.length == stakeAmounts.length,
            "Mismatched input lengths"
        );

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
                institutions[endorseeId].institutionStatus ==
                    InstitutionStatus.unaudited,
                "Endorsee must be unaudited"
            );

            // Deduct tokens from endorser and update stakes
            burnCredits(msg.sender, stakeAmount);
            institutions[endorserId].endorsedStakes.push(
                Stake(stakeAmount, endorseeId)
            );
            institutions[endorseeId].receivedStakes.push(
                Stake(stakeAmount, endorserId)
            );

            emit EndorsementSubmitted(endorserId, endorseeId, stakeAmount);
            uint256 totalReceivedStakes = calculateTotalReceivedStakes(
                endorseeId
            );
            // [DONE] TO-DO: automatic endorsement eligibility check (previously is processEndorsement but really is just to check if met threshold only)
            if (
                totalReceivedStakes +
                    credifyTokenBalances[institutions[endorseeId].owner] >=
                100
            ) {
                processEndorsementEligibility(endorseeId);
            }
        }
    }

    // Function to process endorsements
    function processEndorsementEligibility(uint256 endorseeId) public {
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
        // [DONE] TO-DO: remove the processAudit
        emit EndorsementProcessed(endorseeId, true);
    }

    // Helper function to calculate total received stakes for an institution
    function calculateTotalReceivedStakes(
        uint256 institutionId
    ) public view returns (uint256) {
        Stake[] memory receivedStakes = institutions[institutionId]
            .receivedStakes;
        uint256 totalReceivedStakes = 0;

        for (uint256 i = 0; i < receivedStakes.length; i++) {
            totalReceivedStakes += receivedStakes[i].amount;
        }

        return totalReceivedStakes;
    }

    event AuditDecisionMade(
        uint256 indexed auditorId,
        uint256 indexed auditeeId,
        uint256 stakeAmount
    );

    event AuditProcessed(uint256 indexed auditeeId, bool auditPassed);

    function getInstitutionsForAudit() public returns (uint256[] memory) {
        delete auditeePool;
        for (uint256 i = 1; i <= institutionCount; i++) {
            Institution memory institution = institutions[i];
            if (
                (institution.institutionStatus ==
                    InstitutionStatus.reputable) &&
                (institution.lastAuditDate + 180 days > block.timestamp)
            ) {
                institutions[i].processingStatus = ProcessingStatus.auditee;
                auditeePool.push(institution.id);
            }
            if (
                institution.institutionStatus ==
                InstitutionStatus.eligibleToBeAudited
            ) {
                auditeePool.push(institution.id);
            }
        }
        // [DONE] TO-DO: return the pool of institution ids instead of the whole institution
        return auditeePool;
    }

    function getAuditorPool() public returns (uint256[] memory) {
        delete auditorPool;
        for (uint256 i = 1; i <= institutionCount; i++) {
            Institution memory institution = institutions[i];
            if (
                (institution.institutionStatus ==
                    InstitutionStatus.reputable) &&
                (institution.lastAuditDate + 180 days <= block.timestamp)
            ) {
                auditorPool.push(institution.id);
            }
        }
        // [DONE] TO-DO: return the pool of institution ids instead of the whole institution
        return auditorPool;
    }

    // Function for an auditor to make an audit decision
    function makeAuditDecision(
        uint256 auditeeId,
        uint256 stakeAmount,
        bool voteReputable
    ) public {
        // [DONE] TO-DO: auditorId is directly retrieved based on msg sender
        uint256 auditorId = institutionIdByOwner[msg.sender];
        require(auditorId > 0, "Caller is not registered as an institution");

        Institution storage auditor = institutions[auditorId];
        Institution storage auditee = institutions[auditeeId];

        // NEW: Ensure auditor is indeed in the auditorPool
        bool auditorFound = false;
        for (uint256 i = 0; i < auditorPool.length; i++) {
            if (auditorPool[i] == auditorId) {
                auditorFound = true;
                break;
            }
        }
        require(auditorFound, "Caller is not an auditor");

        // NEW: Ensure the auditee is indeed in the auditeePool
        bool found = false;
        for (uint256 i = 0; i < auditeePool.length; i++) {
            if (auditeePool[i] == auditeeId) {
                found = true;
                break;
            }
        }
        require(
            found,
            "The institution that the caller intends to make an audit decision on is not an auditee"
        );
        require(
            credifyTokenBalances[auditor.owner] >= stakeAmount,
            "Insufficient CredifyTokens for staking"
        );
        require(
            stakeAmount >= (credifyTokenBalances[auditor.owner] * 10) / 100,
            "Stake amount must be at least 10% of the auditor's balance"
        );

        // Deduct staked tokens from the auditor
        burnCredits(auditor.owner, stakeAmount);

        // Record the audit decision
        institutions[auditorId].auditorStakes.push(
            AuditDecision(stakeAmount, voteReputable, auditeeId)
        );
        institutions[auditeeId].auditeeStakes.push(
            AuditDecision(stakeAmount, voteReputable, auditorId)
        );

        // Token of appreciation given to auditors for making audit decision
        institutions[auditorId].reputationPoints += 10;

        emit AuditDecisionMade(auditorId, auditeeId, stakeAmount);

        // Process the audit if there are enough audit decisions
        if (auditee.auditeeStakes.length >= 3) {
            processAudit(auditeeId);
        }
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

        // Determine if the audit passed based on the majority vote
        bool auditPassed = reputableVotes > totalVotes;

        if (auditPassed) {
            // Reward all auditors with a 10% bonus on their stakes and mark the auditee as reputable
            for (uint256 i = 0; i < auditee.auditeeStakes.length; i++) {
                AuditDecision memory decision = auditee.auditeeStakes[i];
                address auditor = institutions[decision.institutionId].owner;
                uint256 auditorId = institutions[decision.institutionId].id;
                // Reward auditors who voted reputable with a 10% bonus on their stakes
                if (decision.voteReputable) {
                    addCredits(auditor, (decision.stakeAmount * 11) / 10);
                } else {
                    addCredits(auditor, (decision.stakeAmount * 7) / 10);
                }
                for (
                    uint256 j = 0;
                    j < institutions[auditorId].auditorStakes.length;
                    j++
                ) {
                    if (
                        institutions[auditorId]
                            .auditorStakes[j]
                            .institutionId == auditeeId
                    ) {
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
                for (
                    uint256 j = 0;
                    j < institutions[stake.institutionId].auditorStakes.length;
                    j++
                ) {
                    if (
                        institutions[stake.institutionId]
                            .auditorStakes[j]
                            .institutionId == auditeeId
                    ) {
                        delete institutions[stake.institutionId].auditorStakes[
                            j
                        ];
                        break;
                    }
                }
            }
        } else {
            // Audit failed, meaning the auditee is marked as unreputable
            for (uint256 i = 0; i < auditee.auditeeStakes.length; i++) {
                AuditDecision memory decision = auditee.auditeeStakes[i];
                address auditor = institutions[decision.institutionId].owner;
                uint256 auditorId = institutions[decision.institutionId].id;
                // Reward auditors who voted unreputable with a 10% bonus on their stakes
                if (!decision.voteReputable) {
                    addCredits(auditor, (decision.stakeAmount * 11) / 10);
                } else {
                    addCredits(auditor, (decision.stakeAmount * 7) / 10);
                }
                for (
                    uint256 j = 0;
                    j < institutions[auditorId].auditorStakes.length;
                    j++
                ) {
                    if (
                        institutions[auditorId]
                            .auditorStakes[j]
                            .institutionId == auditeeId
                    ) {
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
                for (
                    uint256 j = 0;
                    j < institutions[stake.institutionId].auditorStakes.length;
                    j++
                ) {
                    if (
                        institutions[stake.institutionId]
                            .auditorStakes[j]
                            .institutionId == auditeeId
                    ) {
                        delete institutions[stake.institutionId].auditorStakes[
                            j
                        ];
                        break;
                    }
                }
            }
        }

        // Update the last audit date for the auditee (so that reputable endorsee is not subjected to audit immediately after being endorsed)
        auditee.lastAuditDate = block.timestamp;

        // Clear auditing stakes after processing
        delete auditee.auditeeStakes;
    }
}
