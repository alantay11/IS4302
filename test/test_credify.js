const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Credify", function () {
    let Credify;
    let credify;
    let owner, university1, university2, university3, company1, company2, company3, company4, company5;

    beforeEach(async function () {
        [owner, university1, university2, university3, company1, company2, company3, company4, company5, ...others] = await ethers.getSigners();

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