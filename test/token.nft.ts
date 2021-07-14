// import {ethers} from "hardhat";
// import chai, {assert} from "chai";
// import chaiAsPromised from "chai-as-promised";
// import {MillionDotToken, MillionDotToken__factory, NFTMarket, NFTMarket__factory, TokenNFT, TokenNFT__factory} from "../typechain";
// import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
// import {BigNumber} from "ethers";

// chai.use(chaiAsPromised);

// describe("Million Dot Token NFT", () => {
//     let mdotToken: MillionDotToken;
//     let mdotNFT: TokenNFT;
//     let nftMarket: NFTMarket;
//     let signers: SignerWithAddress[];
//     const BigDecimals = BigNumber.from(10).pow(18);

//     beforeEach(async () => {
//         signers = await ethers.getSigners();

//         const mdotFactory = (await ethers.getContractFactory(
//             "TokenNFT",
//             signers[0]
//         )) as TokenNFT__factory;
//         mdotNFT = await mdotFactory.deploy("MDotNFT", "MFT1")
//         await mdotNFT.deployed()

//         const nftMarketFactory = (await ethers.getContractFactory(
//             "NFTMarket",
//             signers[0]
//         )) as NFTMarket__factory;

//         nftMarket = await nftMarketFactory.deploy();
//         await nftMarket.deployed();

//         const mdotTokenFactory = (await ethers.getContractFactory(
//             "MillionDotToken",
//             signers[0]
//         )) as MillionDotToken__factory;
//         mdotToken = await mdotTokenFactory.deploy(
//             "MillionDotToken",
//             "MDOT",
//             BigNumber.from(100000).mul(BigDecimals),
//             BigNumber.from(10000000).mul(BigDecimals),
//             signers[0].address
//         );
//         await mdotToken.deployed();
//     });

//     describe("information", async () => {
//         it("should get name and symbol", async () => {
//             let name = await mdotNFT.name();
//             let symbol = await mdotNFT.symbol();
//             console.log({name, symbol});
//         });
//     });

//     const userWallet = '0xC00c6c407ED165c92306724C76eC6148CAe755cA'

//     describe("mint token nft", async () => {
//         it("mint with square", async () => {
//             await mdotNFT.mint(userWallet, 123)
//             const isExistSquare123 = await mdotNFT.isExistSquare(123)
//             assert.isTrue(isExistSquare123)
//             const isExistSquare112 = await mdotNFT.isExistSquare(112)
//             assert.isFalse(isExistSquare112)
//         })

//         it("update ad data", async () => {
//             await mdotNFT.mint(signers[1].address, 123)
//             await mdotNFT.connect(signers[1]).updateAd(1, "this is sample ad text", "https://google.com", "Qiuaehf9283248024804")
//             const tokenInfo = await mdotNFT.getAdData(1)
//             console.log({tokenInfo});
//             const squareData = await mdotNFT.getSquareData(1)
//             console.log({squareData});
//         })
//     })

//     describe("Check rarity", async () => {
//         enum Rarity { UNIQUE, LEGENDARY, EPIC, RARE, NORMAL_RARE, COMMON }

//         it('should get square rarity', async () => {
//             const is1 = await mdotNFT.getSquareRarity(BigNumber.from(511))
//             assert(is1 == Rarity.COMMON)
//             const is11 = await mdotNFT.getSquareRarity(BigNumber.from(9092))
//             assert(is11 == Rarity.COMMON)
//             const is2 = await mdotNFT.getSquareRarity(BigNumber.from(219))
//             assert(is2 == Rarity.COMMON)
//             const is211 = await mdotNFT.getSquareRarity(BigNumber.from(8583))
//             assert(is211 == Rarity.NORMAL_RARE)
//             const is21 = await mdotNFT.getSquareRarity(BigNumber.from(2190))
//             assert(is21 == Rarity.NORMAL_RARE)
//             const is3 = await mdotNFT.getSquareRarity(BigNumber.from(2110))
//             assert(is3 == Rarity.NORMAL_RARE)
//             const is4 = await mdotNFT.getSquareRarity(BigNumber.from(2030))
//             assert(is4 == Rarity.RARE)
//             const is5 = await mdotNFT.getSquareRarity(BigNumber.from(4531))
//             assert(is5 == Rarity.EPIC)
//             const is6 = await mdotNFT.getSquareRarity(BigNumber.from(4537))
//             assert(is6 == Rarity.LEGENDARY)
//             const is61 = await mdotNFT.getSquareRarity(BigNumber.from(4349))
//             assert(is61 == Rarity.LEGENDARY)
//             const is7 = await mdotNFT.getSquareRarity(BigNumber.from(4744))
//             assert(is7 == Rarity.UNIQUE)
//         });
//     })

//     describe("Create sale for NFT", () => {
//         let totalSupply = 0

//         async function mintNft(address: string, pos: number) {
//             await mdotNFT.mint(address, pos)
//             totalSupply++
//         }

//         async function transferNft(from: string, to: string, id: number) {
//             await mdotNFT.transferFrom(from, to, id)
//         }

//         async function createData() {
//             await Promise.all([
//                 123, 511, 9092, 219, 8583, 2190, 2030, 4531, 4537, 4349, 4744
//             ].map((pos) => mintNft(signers[0].address, pos)))
//             await Promise.all([
//                 1, 3, 4, 8, 5, 9
//             ].map((pos) => transferNft(signers[0].address, signers[2].address, pos)))
//         }

//         it('should create NFT', async () => {
//             await createData()
//             await Promise.all((new Array(11).fill(0)).map(async (_, index) => {
//                 const tokenId = index + 1
//                 const pos = await mdotNFT.getPositionSquareToken(tokenId)
//                 console.log({tokenId, position: pos.toNumber()});
//             }))

//             const currentTotalSupply = await mdotNFT.totalSupply()
//             const balance1 = await mdotNFT.balanceOf(signers[0].address)
//             const balance2 = await mdotNFT.balanceOf(signers[2].address)
//             assert(currentTotalSupply.toNumber() == totalSupply);
//             assert(balance1.toNumber() == 5);
//             assert(balance2.toNumber() == 6);
//         });

//         it("should create sale on market", async () => {
//             let currentTotalSupply = await mdotNFT.totalSupply()
//             await mdotNFT.updateMarketAddress(nftMarket.address)

//             assert(currentTotalSupply.toNumber() == 0);
//             await createData()
//             currentTotalSupply = await mdotNFT.totalSupply()
//             assert(currentTotalSupply.toNumber() == 11);

//             await nftMarket.supportNft(mdotNFT.address, true)
//             await nftMarket.updateSeller(signers[0].address, true)
//             await nftMarket.supportPaymentToken(mdotToken.address, true)

//             const isApproved = await mdotNFT.isApprovedForAll(signers[0].address, nftMarket.address)
//             console.log({isApproved})
//             await nftMarket.testTransfer(mdotNFT.address, signers[0].address, signers[2].address, 2)
//             // await nftMarket.connect(signers[1]).testTransfer(mdotNFT.address, signers[0].address, signers[4].address, 2)
//             // await nftMarket.createSales(2, 12, 14, 0, 60 * 60, mdotNFT.address, mdotToken.address)
//             // let salesAmount = await nftMarket.totalSales()
//             // console.log(salesAmount.toNumber());
//             // await nftMarket.createSales(6, 12, 14, 0, 60 * 60, mdotNFT.address, mdotToken.address)
//             // salesAmount = await nftMarket.totalSales()
//             // console.log(salesAmount.toNumber());
//             // await nftMarket.createSales(11, 12, 14, 0, 60 * 60, mdotNFT.address, mdotToken.address)
//             // salesAmount = await nftMarket.totalSales()
//             // console.log(salesAmount.toNumber());

//         })
//     })
// });
