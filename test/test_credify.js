const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Credify", function () {
    let Credify;
    let credify;
    let owner, university1, university2, university3, company1, company2, company3, company4, company5, company6, others;

    beforeEach(async function () {
        [owner, university1, university2, university3, company1, company2, company3, company4, company5, company6, ...others] = await ethers.getSigners();

        // Deploy Credify
        Credify = await ethers.getContractFactory("Credify");
        credify = await Credify.deploy();
        await credify.waitForDeployment();

        // Add verified university addresses
        await credify.connect(owner).addVerifiedUniAddress(university1.address);
        await credify.connect(owner).addVerifiedUniAddress(university2.address);
        await credify.connect(owner).addVerifiedUniAddress(university3.address);


        // Create institutions
        await credify.connect(university1).createUniversity();
        await credify.connect(university2).createUniversity();
        await credify.connect(university3).createUniversity();
        await credify.connect(company1).createCompany();
        await credify.connect(company2).createCompany();
        await credify.connect(company3).createCompany();
        await credify.connect(company4).createCompany();
        await credify.connect(company5).createCompany();
    });

    // Institution Creation and Verification
    it("Should not allow non-verified addresses to create a university", async function () {
        await expect(
            credify.connect(company1).createUniversity()
        ).to.be.revertedWith("Address not approved to create a university");
    });

    it("Should not allow non-owner to add verified university addresses", async function () {
        await expect(
            credify.connect(company1).addVerifiedUniAddress(others[0].address)
        ).to.be.revertedWith("Only the owner can add verified university addresses");
    });


    // Endorsement
    it("Should update the status of an endorsee when it hits the endorsement threshold", async function () {
        await credify.connect(company1).submitEndorsements([6], [25]);
        await credify.connect(company2).submitEndorsements([6], [25]);

        const company3Status = (await credify.getInstitution(6)).institutionStatus;
        expect(company3Status).to.equal(2);
    });

    it("Should place the endorsee into the auditee pool", async function () {
        await credify.connect(company1).submitEndorsements([6], [25]);
        await credify.connect(company2).submitEndorsements([6], [25]);

        await credify.getInstitutionsForAudit();
        const auditeePool = await credify.getAuditeePool();
        expect(auditeePool.length).to.equal(1);
        // company 3 should be in the auditee pool
        expect(auditeePool[0]).to.equal(6);
    });

    // Audit
    it("Should place the auditor into the auditor pool", async function () {
        await credify.getAuditors();
        const auditorPool = await credify.getAuditorPool();
        // the 3 universities should be in the auditor pool
        expect(auditorPool.length).to.equal(3);
    });


    it("Should get audited and pass", async function () {
        await credify.connect(company1).submitEndorsements([6], [25]);
        await credify.connect(company2).submitEndorsements([6], [25]);

        await credify.getInstitutionsForAudit();

        await credify.connect(university1).makeAuditDecision(6, 25, true);
        await credify.connect(university2).makeAuditDecision(6, 25, false);
        await credify.connect(university3).makeAuditDecision(6, 25, true);

        const company3Status = (await credify.getInstitution(6)).institutionStatus;
        expect(company3Status).to.equal(0);

        // Check token balances
        // auditor's balances
        expect(await credify.credifyTokenBalances(university1.address)).to.equal(52); // 25 + (25 * 1.1)
        expect(await credify.credifyTokenBalances(university3.address)).to.equal(52);; // 25 + (25 * 1.1)
        expect(await credify.credifyTokenBalances(university2.address)).to.equal(42);; // 25 + (25 * 0.7)
        // endorser's balances
        expect(await credify.credifyTokenBalances(company1.address)).to.equal(52);; // 25 + (25 * 1.1)
        expect(await credify.credifyTokenBalances(company2.address)).to.equal(52);; // 25 + (25 * 1.1)
        // endorsee's balances
        expect(await credify.credifyTokenBalances(company3.address)).to.equal(100);; // 25 + 25 + 50
    });

    it("Should get audited and fail", async function () {
        await credify.connect(company1).submitEndorsements([7], [25]);
        await credify.connect(company2).submitEndorsements([7], [25]);

        await credify.getInstitutionsForAudit();

        await credify.connect(university1).makeAuditDecision(7, 25, false);
        await credify.connect(university2).makeAuditDecision(7, 25, true);
        await credify.connect(university3).makeAuditDecision(7, 25, false);

        const company4Status = (await credify.getInstitution(7)).institutionStatus;
        expect(company4Status).to.equal(1);

        // Check token balances
        // auditor's balances
        expect(await credify.credifyTokenBalances(university1.address)).to.equal(52); // 25 + (25 * 1.1)
        expect(await credify.credifyTokenBalances(university3.address)).to.equal(52);; // 25 + (25 * 1.1)
        expect(await credify.credifyTokenBalances(university2.address)).to.equal(42);; // 25 + (25 * 0.7)
        // endorser's balances
        expect(await credify.credifyTokenBalances(company1.address)).to.equal(42);; // 25 + (25 * 0.7)
        expect(await credify.credifyTokenBalances(company2.address)).to.equal(42);; // 25 + (25 * 0.7)
        // endorsee's balances
        expect(await credify.credifyTokenBalances(company3.address)).to.equal(50);; // 50
    });

    it("Should place all universities into the auditee pool after 6 months", async function () {
        // Fast forward 6 months
        await ethers.provider.send("evm_increaseTime", [180 * 24 * 60 * 60]);
        await ethers.provider.send("evm_mine");
        // Get the auditee pool
        await credify.getInstitutionsForAudit();

        const auditeePool = await credify.getAuditeePool();
        // all 3 universities should be in the auditee pool
        expect(auditeePool.length).to.equal(3);
    });

    // Endorsement Restrictions
    it("Should prevent self-endorsement attempts", async function () {
        const institutionId = await credify.institutionIdByOwner(company1.address);

        // Try to get today's endorsement bucket
        const bucket = await credify.connect(company1).getTodayEndorsementBucket();

        // Verify that the institution's own ID is not in its endorsement bucket
        for (let i = 0; i < bucket.length; i++) {
            expect(bucket[i]).to.not.equal(institutionId);
        }

        // Attempt to endorse self (should fail)
        await expect(
            credify.connect(company1).submitEndorsements([institutionId], [25])
        ).to.be.revertedWith("Endorsee not in today's endorsement bucket");
    });

    it("Should not allow endorsing institutions not in today's bucket", async function () {
        // Try to get today's endorsement bucket
        const bucket = await credify.connect(company1).getTodayEndorsementBucket();

        // Find the institution ID not in company 1's bucket
        let institutionIdNotInBucket = 0;
        for (let i = 0; i < bucket.length; i++) {
            for (let j = 0; j < 8; j++) {
                if (bucket[i] == j) {
                    break;
                }
            }
            if (institutionIdNotInBucket == 0) {
                institutionIdNotInBucket = bucket[i];
                break;
            }
        }

        // Try to endorse an institution not in the bucket
        await expect(
            credify.connect(company1).submitEndorsements([institutionIdNotInBucket], [25])
        ).to.be.revertedWith("Endorsee not in today's endorsement bucket");
    });

    it("Should not allow unreputable institutions to endorse", async function () {
        // make company1 unreputable
        await credify.connect(company2).submitEndorsements([4], [25]);
        await credify.connect(company3).submitEndorsements([4], [25]);
        await credify.getInstitutionsForAudit();
        await credify.connect(university1).makeAuditDecision(4, 25, false);
        await credify.connect(university2).makeAuditDecision(4, 25, false);
        await credify.connect(university3).makeAuditDecision(4, 25, false);

        // unreputable institution try to endorse
        await expect(
            credify.connect(company1).submitEndorsements([5], [25])
        ).to.be.revertedWith("Unreputable institutions cannot endorse");
    });

    it("Should not allow endorsing without staking any tokens", async function () {
        // Try to endorse by not staking any tokens
        await expect(
            credify.connect(company1).submitEndorsements([5], [0])
        ).to.be.revertedWith("Stake amount must be greater than 0");
    });

    it("Should not allow endorsing with insufficient tokens", async function () {
        // Try to endorse with more tokens than available
        await expect(
            credify.connect(company1).submitEndorsements([5], [60])
        ).to.be.revertedWith("Insufficient CredifyToken balance");
    });


    // Audit Restrictions
    it("Should not allow non-auditors to make audit decisions", async function () {
        await credify.connect(company1).submitEndorsements([6], [25]);
        await credify.connect(company2).submitEndorsements([6], [25]);
        await credify.getInstitutionsForAudit();

        await expect(
            credify.connect(company3).makeAuditDecision(6, 25, true)
        ).to.be.revertedWith("Caller is not an auditor");
    });

    it("Should not allow auditing institutions not in the auditee pool", async function () {
        await credify.getAuditors();

        await expect(
            credify.connect(university1).makeAuditDecision(5, 25, true)
        ).to.be.revertedWith("The institution that the caller intends to make an audit decision on is not an auditee");
    });

    it("Should not process the audit due to insufficient stake", async function () {
        await credify.connect(company1).submitEndorsements([6], [25]);
        await credify.connect(company2).submitEndorsements([6], [25]);
        await credify.getInstitutionsForAudit();
        // Attempt to make audit decision with insufficient stakes
        await expect(
            credify.connect(university1).makeAuditDecision(6, 2, true)
        ).to.be.revertedWith("Stake amount must be at least 10% of the auditor's balance");

    });
});