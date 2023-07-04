import { ethers } from 'ethers';
import { expect } from 'chai';

async function deployFixture() {
	const [owner] = await ethers.getSigners();
	const Token = await ethers.getContractFactory('Token');
	const token = await Token.deploy();
	await token.deployed();

	const Exchange = await ethers.getContractFactory('Exchange');
	const exchange = await Exchange.deploy(token.address);
	await exchange.deployed();

	return { token, exchange };
}
describe('Exchange', () => {
	describe('addLiquidity', () => {
		it('should add liquidity', async () => {
			const { token, exchange } = await deployFixture();

			await token.approve(exchange.address, toWei(200));
			await exchange.addLiquidity(toWei(200), { value: toWei(100) });

			expect(await getBalance(exchange.address)).to.equal(toWei(100));
			expect(await exchange.getReserve()).to.equal(toWei(200));
		});
	});
});
