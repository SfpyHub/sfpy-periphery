import chai, { expect } from 'chai'
import { solidity, MockProvider, createFixtureLoader, deployContract } from 'ethereum-waffle'
import { Contract, BigNumber, utils } from 'ethers'

import { SfpyFixture } from './shared/fixtures'
import { expandTo18Decimals } from './shared/utilities'

import ExampleFlashLoan from '../build/ExampleFlashLoan.json'
import ExampleDummyExchange from '../build/ExampleDummyExchange.json'

chai.use(solidity)

describe('ExampleFlashLoan', () => {
	const provider = new MockProvider()
  const [wallet] = provider.getWallets()
  const loadFixture = createFixtureLoader([wallet], provider)
  const flashLoanFee = BigNumber.from(10).pow(15)

  let sfpy: Contract
  let factory: Contract
  let sfpyPool: Contract
  let flashLoanExample: Contract
  let dummyExchangeExample: Contract

  beforeEach(async function() {
    const fixture = await loadFixture(SfpyFixture)
    sfpy = fixture.SFPY
    factory = fixture.factory
    sfpyPool = fixture.SFPYPool
    dummyExchangeExample = await deployContract(
      wallet,
      ExampleDummyExchange,
      [fixture.SFPY.address]
    )

    flashLoanExample = await deployContract(
      wallet,
      ExampleFlashLoan,
      [fixture.factory.address, dummyExchangeExample.address]
    )
  })

  it('borrow:0', async () => {
  	const dummyExchangeBalance = expandTo18Decimals(101)
  	const dummyAmount = expandTo18Decimals(200)
  	const sfpyAmount = expandTo18Decimals(100)
  	const arbitrageAmount = expandTo18Decimals(99)

  	const feeAmount = arbitrageAmount.mul(flashLoanFee).div(BigNumber.from(10).pow(18))
  	const expectedBalance = sfpyAmount.add(feeAmount)
  	const profit = arbitrageAmount.sub(feeAmount)

  	await sfpy.transfer(sfpyPool.address, sfpyAmount)
  	await sfpy.transfer(dummyExchangeExample.address, dummyAmount)

  	await sfpyPool.mint(wallet.address)

  	await sfpyPool.borrow(
      arbitrageAmount,
      flashLoanExample.address,
      utils.defaultAbiCoder.encode(['uint'], [BigNumber.from(1)])
    )

  	expect(await sfpy.balanceOf(dummyExchangeExample.address)).to.eq(dummyExchangeBalance)
	  expect(await sfpy.balanceOf(sfpyPool.address)).to.eq(expectedBalance)
	  expect(await sfpy.balanceOf(flashLoanExample.address)).to.eq(profit)
  })
})