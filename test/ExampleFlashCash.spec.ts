import chai, { expect } from 'chai'
import { solidity, MockProvider, createFixtureLoader, deployContract } from 'ethereum-waffle'
import { Contract, BigNumber, utils } from 'ethers'
import { MaxUint256 } from '@ethersproject/constants'

import { SfpyFixture } from './shared/fixtures'
import { expandTo18Decimals } from './shared/utilities'

import ExampleFlashCash from '../build/ExampleFlashCash.json'
import ExampleAirDrop from '../build/ExampleAirDrop.json'

chai.use(solidity)

describe('ExampleFlashCash', () => {
	const provider = new MockProvider()
  const [wallet, customer, merchant] = provider.getWallets()
  const customerSigner = provider.getSigner(1)
  const loadFixture = createFixtureLoader([wallet], provider)

  let weth: Contract
  let sfpy: Contract
  let router: Contract
  let sfpyPool: Contract
  let flashCashExample: Contract
  let dummyAirDropExample: Contract

  let routerAsCustomer: Contract
  let sfpyAsCustomer: Contract

  beforeEach(async function() {
    const fixture = await loadFixture(SfpyFixture)
    sfpy = fixture.SFPY
    weth = fixture.WETH
    router = fixture.router
    sfpyPool = fixture.SFPYPool
    routerAsCustomer = router.connect(customerSigner)
    sfpyAsCustomer = sfpy.connect(customerSigner)

    dummyAirDropExample = await deployContract(
      wallet,
      ExampleAirDrop,
      [fixture.WETH.address]
    )

    flashCashExample = await deployContract(
      wallet,
      ExampleFlashCash,
      [fixture.router.address, dummyAirDropExample.address]
    )
  })

  it('afterPay:success', async () => {
  	const initSfpyBalance = expandTo18Decimals(10000)
  	const airdropBalance = expandTo18Decimals(1000)
  	const tokenAmount = expandTo18Decimals(9)
  	const expectedLiquidity = expandTo18Decimals(3)
  	const expectedWethBalance = expandTo18Decimals(100)

  	await sfpy.transfer(customer.address, tokenAmount)
  	expect(await sfpy.balanceOf(customer.address)).to.eq(tokenAmount)

  	await weth.deposit({ value: airdropBalance })
  	await weth.transfer(dummyAirDropExample.address, airdropBalance)
  	
  	await sfpyAsCustomer.approve(router.address, MaxUint256)

  	await expect(
      routerAsCustomer.flash(
        sfpy.address, 
    		tokenAmount,
        merchant.address,
    		flashCashExample.address, 
    		MaxUint256,
        utils.defaultAbiCoder.encode(['uint'], [BigNumber.from(1)])
      )
    )
      .to.emit(router, 'Flash')
      .withArgs(
        customer.address, 
        merchant.address, 
        sfpy.address, 
        flashCashExample.address,
        tokenAmount
      )

  	expect(await sfpy.balanceOf(wallet.address)).to.eq(initSfpyBalance.sub(tokenAmount))
  	expect(await sfpy.balanceOf(customer.address)).to.eq(0)
  	expect(await weth.balanceOf(customer.address)).to.eq(expectedWethBalance)
  	expect(await sfpyPool.balanceOf(merchant.address)).to.eq(expectedLiquidity)
  })

  it('afterPay:fail', async () => {
  	const initSfpyBalance = expandTo18Decimals(10000)
  	const airdropBalance = expandTo18Decimals(1000)
  	const tokenAmount = expandTo18Decimals(9)
  	const expectedLiquidity = expandTo18Decimals(3)
  	const expectedWethBalance = expandTo18Decimals(100)

  	await sfpy.transfer(customer.address, tokenAmount)
  	expect(await sfpy.balanceOf(customer.address)).to.eq(tokenAmount)

  	await weth.deposit({ value: airdropBalance })
  	await weth.transfer(dummyAirDropExample.address, airdropBalance)
  	
  	await sfpyAsCustomer.approve(router.address, MaxUint256)

  	await expect(
  		routerAsCustomer.flash(
	      sfpy.address, 
	  		0,
        merchant.address,
	  		flashCashExample.address, 
	  		MaxUint256,
	      utils.defaultAbiCoder.encode(['uint'], [BigNumber.from(1)])
    	)
    )
  		.to.be.revertedWith('INSUFFICIENT_AMOUNT')

  	expect(await sfpy.balanceOf(wallet.address)).to.eq(initSfpyBalance.sub(tokenAmount))
  	expect(await sfpy.balanceOf(customer.address)).to.eq(tokenAmount)
  	expect(await weth.balanceOf(customer.address)).to.eq(0)
  	expect(await sfpyPool.balanceOf(merchant.address)).to.eq(0)
  })

})