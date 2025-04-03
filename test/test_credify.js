const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Credify", function () {
    let Credify;
    let credify;
    let owner, university1, university2, university3, university4, university5, company1, company2;

    beforeEach(async function () {
        [owner, university1, university2, university3, university4, university5, company1, company2, ...others] = await ethers.getSigners();

        // Deploy Credify
        Credify = await ethers.getContractFactory("Credify");
        credify = await Credify.deploy();
        await credify.waitForDeployment();

        // Add verified university addresses
        await credify.connect(owner).addVerifiedUniAddress(university1.address);
        await credify.connect(owner).addVerifiedUniAddress(university2.address);
        await credify.connect(owner).addVerifiedUniAddress(university3.address);
        await credify.connect(owner).addVerifiedUniAddress(university4.address);
        await credify.connect(owner).addVerifiedUniAddress(university5.address);

        // Create institutions
        await credify.connect(university1).createUniversity(); // 0 represents InstitutionStatus.reputable
        await credify.connect(university2).createUniversity();
        await credify.connect(university3).createUniversity();
        await credify.connect(university4).createUniversity();
        await credify.connect(university5).createUniversity();
        await credify.connect(company1).createCompany();
        await credify.connect(company2).createCompany();
    });

    it("Should update the status of an endorsee when it hits the endorsement threshold", async function () {
        await credify.connect(university1).submitEndorsements([6], [25]);
        await credify.connect(university2).submitEndorsements([6], [25]);

        const company1Status = (await credify.getInstitution(6)).institutionStatus;
        expect(company1Status).to.equal(2); // 2 represents InstitutionStatus.eligibleToBeAudited
    });

    it("Should place the endorsee into the auditee pool", async function () {
        await credify.connect(university1).submitEndorsements([6], [25]);
        await credify.connect(university2).submitEndorsements([6], [25]);

        const auditeePool = await credify.getInstitutionsForAudit();
        expect(auditeePool).to.include(6); // Company 1's ID
    });

    it("Should get audited and pass", async function () {
        await credify.connect(university1).submitEndorsements([6], [25]);
        await credify.connect(university2).submitEndorsements([6], [25]);

        await credify.connect(university1).makeAuditDecision(6, 25, true);
        await credify.connect(university4).makeAuditDecision(6, 25, false);
        await credify.connect(university5).makeAuditDecision(6, 25, true);

        const company1Status = (await credify.getInstitution(6)).institutionStatus;
        expect(company1Status).to.equal(0); // 0 represents InstitutionStatus.reputable

        // Check token balances
        expect(await credify.credifyTokenBalances(university1.address)).to.be.closeTo(ethers.parseEther("55.0"), ethers.parseEther("0.01")); // (25 * 1.1) + (25 * 1.1)
        expect(await credify.credifyTokenBalances(university2.address)).to.be.closeTo(ethers.parseEther("52.5"), ethers.parseEther("0.01")); // 25 + (25 * 1.1)
        expect(await credify.credifyTokenBalances(university4.address)).to.be.closeTo(ethers.parseEther("42.5"), ethers.parseEther("0.01")); // 25 + (25 * 0.7)
        expect(await credify.credifyTokenBalances(university5.address)).to.be.closeTo(ethers.parseEther("52.5"), ethers.parseEther("0.01")); // 25 + (25 * 1.1)
    });

    it("Should update the status of an endorsee when it hits the endorsement threshold", async function () {
        await credify.connect(university1).submitEndorsements([7], [25]);
        await credify.connect(university2).submitEndorsements([7], [25]);

        const company2Status = (await credify.getInstitution(7)).institutionStatus;
        expect(company2Status).to.equal(2); // 2 represents InstitutionStatus.eligibleToBeAudited
    });

    it("Should get audited and fail", async function () {
        await credify.connect(university1).submitEndorsements([7], [25]);
        await credify.connect(university2).submitEndorsements([7], [25]);

        await credify.connect(university1).makeAuditDecision(7, 25, false);
        await credify.connect(university4).makeAuditDecision(7, 25, true);
        await credify.connect(university5).makeAuditDecision(7, 25, false);

        const company2Status = (await credify.getInstitution(7)).institutionStatus;
        expect(company2Status).to.equal(1); // 1 represents InstitutionStatus.unreputable

        // Check token balances
        expect(await credify.credifyTokenBalances(university1.address)).to.be.closeTo(ethers.parseEther("45.0"), ethers.parseEther("0.01")); // (25 * 1.1) + (25 * 0.7)
        expect(await credify.credifyTokenBalances(university2.address)).to.be.closeTo(ethers.parseEther("42.5"), ethers.parseEther("0.01")); // 25 + (25 * 0.7)
        expect(await credify.credifyTokenBalances(university4.address)).to.be.closeTo(ethers.parseEther("42.5"), ethers.parseEther("0.01")); // 25 + (25 * 0.7)
        expect(await credify.credifyTokenBalances(university5.address)).to.be.closeTo(ethers.parseEther("52.5"), ethers.parseEther("0.01")); // 25 + (25 * 1.1)
    });

    it("Should place Company 1 into the auditee pool", async function () {
        // Now company1 is reputable, fast forward 6 months
        await ethers.provider.send("evm_increaseTime", [180 * 24 * 60 * 60]);
        await ethers.provider.send("evm_mine");
        // Get the auditee pool
        const auditeePool = await credify.getInstitutionsForAudit();

        // Check that company1's ID is in the auditee pool
        expect(auditeePool).to.include(6); // Company 1's ID
    });

    it("Should not process the audit due to insufficient stake", async function () {
        // Get initial token balances
        const initialUni1Balance = await credify.credifyTokenBalances(university1.address);

        // Calculate insufficient stake (less than 10% of balance)
        const insufficientStake1 = initialUni1Balance.mul(5).div(100); // 5% of balance

        // Attempt to make audit decisions with insufficient stakes
        await expect(
            credify.connect(university1).makeAuditDecision(6, insufficientStake1, true)
        ).to.be.revertedWith("Stake amount must be at least 10% of the auditor's balance");

    });
});