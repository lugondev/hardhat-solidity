import {ethers} from "hardhat";
import chai from "chai";
import chaiAsPromised from "chai-as-promised";
import {BigNumber} from "ethers";
import {MillionDotToken, MillionDotToken__factory} from "../typechain";
import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";

chai.use(chaiAsPromised);

describe("Million Dot Token ERC20", () => {
    let mdotToken: MillionDotToken;
    let signers: SignerWithAddress[];
    const BigDecimals = BigNumber.from(10).pow(18);

    beforeEach(async () => {
        signers = await ethers.getSigners();

        const mdotFactory = (await ethers.getContractFactory(
            "MillionDotToken",
            signers[0]
        )) as MillionDotToken__factory;
        mdotToken = await mdotFactory.deploy("MillionDotToken", "MDOT", BigNumber.from(10000000).mul(BigDecimals), signers[0].address);
        await mdotToken.deployed();
    });

    describe("information", async () => {
        it("should get name and symbol", async () => {
            let name = await mdotToken.name();
            let symbol = await mdotToken.symbol();
            console.log({name, symbol});
        });
    });

    describe("balance action", async () => {
        it("owner balance", async () => {
            let totalSupply = await mdotToken.totalSupply();
            console.log({totalSupply: totalSupply.div(BigDecimals).toNumber()});
            let balanceOwner = await mdotToken.balanceOf(signers[0].address);
            console.log('balance of' + ' ' + signers[0].address + ': ' + balanceOwner.div(BigDecimals).toNumber());
        });

        const userWallet = '0xC00c6c407ED165c92306724C76eC6148CAe755cA';

        it("transfer balance", async () => {
            console.log('transfer to 12313 => ' + userWallet);

            await mdotToken.transfer(userWallet, BigNumber.from(12313).mul(BigDecimals));

            let balanceOwner = await mdotToken.balanceOf(signers[0].address);
            console.log('after transfer: balance of sender: ' + balanceOwner.div(BigDecimals).toNumber());

            let balanceUser = await mdotToken.balanceOf(userWallet);
            console.log('after transfer: balance of receiver: ' + balanceUser.div(BigDecimals).toNumber());
        });
    })
});
