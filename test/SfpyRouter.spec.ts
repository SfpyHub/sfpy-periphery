import chai, { expect } from 'chai'
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle'
import { Contract, BigNumber, utils } from 'ethers'
import { AddressZero, MaxUint256 } from '@ethersproject/constants'
import ISfpyPool from '@sfpy/core/build/ISfpyPool.json'

import { SfpyFixture } from './shared/fixtures'
import { expandTo18Decimals, expandTo6Decimals, getApprovalDigest } from './shared/utilities'

import { ecsign } from 'ethereumjs-util'

chai.use(solidity)

describe('SfpyRouter', () => {
	const REQUEST = "BVQ0AQ3PC98SHFSSO9NG"
  const PAYMENT = "C1GL47GI7QKSQPJ3DQOG"
	const HEX_REQUEST = utils.hexlify(utils.hexZeroPad(utils.toUtf8Bytes(REQUEST), 32))
  const HEX_PAYMENT = utils.hexlify(utils.hexZeroPad(utils.toUtf8Bytes(PAYMENT), 32))
  const provider = new MockProvider()
  const [wallet, merchant] = provider.getWallets()
  const walletSigner = provider.getSigner(0)
  const merchantSigner = provider.getSigner(1)
  const loadFixture = createFixtureLoader([wallet], provider)

  let sfpy: Contract
  let weth: Contract
  let router: Contract
  let factory: Contract
  let sfpyPool: Contract
  let wethPool: Contract
  // signer contracts
  let sfpyPoolAsMerchant: Contract
  let wethPoolAsMerchant: Contract
  let routerAsMerchant: Contract
  beforeEach(async function() {
    const fixture = await loadFixture(SfpyFixture)
    sfpy = fixture.SFPY
    weth = fixture.WETH
    router = fixture.router
    factory = fixture.factory
    sfpyPool = fixture.SFPYPool
    wethPool = fixture.WETHPool

    sfpyPoolAsMerchant = sfpyPool.connect(merchantSigner)
    wethPoolAsMerchant = wethPool.connect(merchantSigner)
    routerAsMerchant = router.connect(merchantSigner)
  })

  it("should deploy with the correct factory address", async function () {
  	expect(await router.factory()).to.eq(factory.address)
  })

  it("should deploy with the correct WETH address", async function () {
  	expect(await router.WETH()).to.eq(weth.address)
  })

  it("pays", async function () {
  	const tokenAmount = expandTo18Decimals(9)
  	const expectedLiquidity = expandTo18Decimals(3)
    const oracleRate = expandTo6Decimals(1)

		await sfpy.approve(router.address, MaxUint256)

		await expect(
      router.pay(
	  		sfpy.address, 
	  		tokenAmount,
        oracleRate,
	  		HEX_REQUEST, 
	  		merchant.address, 
	  		MaxUint256
	  	)
    )
	    .to.emit(sfpy, 'Transfer')
	    .withArgs(wallet.address, sfpyPool.address, tokenAmount)
	    .to.emit(sfpyPool, 'Transfer')
	    .withArgs(AddressZero, merchant.address, expectedLiquidity)
	    .to.emit(sfpyPool, 'Mint')
	    .withArgs(router.address, tokenAmount)
	    .to.emit(router, 'Pay')
	    .withArgs(
	    	wallet.address, 
	    	merchant.address, 
	    	sfpy.address, 
	    	HEX_REQUEST, 
	    	tokenAmount,
        oracleRate
	    )

	  expect(await sfpyPool.balanceOf(merchant.address)).to.eq(expectedLiquidity)
  })

  it('pays:gas', async () => {
    const tokenAmount = expandTo18Decimals(9)
    const oracleRate = expandTo6Decimals(1)

    await sfpy.approve(router.address, MaxUint256)

    const tx = await router.pay(
      sfpy.address, 
      tokenAmount,
      oracleRate,
      HEX_REQUEST, 
      merchant.address, 
      MaxUint256
    )

    const receipt = await tx.wait()
    expect(receipt.gasUsed).to.eq(153571)
  })

  it("paysETH", async function () {
  	const ethAmount = expandTo18Decimals(4)
  	const expectedLiquidity = expandTo18Decimals(2)
    const oracleRate = expandTo6Decimals(1)

		await expect(
      router.payETH(
	  		HEX_REQUEST, 
	  		merchant.address,
        oracleRate,
	  		MaxUint256,
      	{ value: ethAmount }
	  	)
    )
    	.to.emit(wethPool, 'Transfer')
	    .withArgs(AddressZero, merchant.address, expectedLiquidity)
	    .to.emit(wethPool, 'Mint')
	    .withArgs(router.address, ethAmount)
	    .to.emit(router, 'Pay')
	    .withArgs(
	    	wallet.address, 
	    	merchant.address, 
	    	AddressZero, 
	    	HEX_REQUEST, 
	    	ethAmount,
        oracleRate
	    )

	  expect(await wethPool.balanceOf(merchant.address)).to.eq(expectedLiquidity)
  })

  it('paysETH:gas', async () => {
    const ethAmount = expandTo18Decimals(4)
    const oracleRate = expandTo6Decimals(1)

    const tx = await router.payETH(
      HEX_REQUEST, 
      merchant.address,
      oracleRate,
      MaxUint256,
      { value: ethAmount }
    )
    
    const receipt = await tx.wait()
    expect(receipt.gasUsed).to.eq(159897)
  })

  async function addLiquidity(tokenAmount: BigNumber) {
    await sfpy.transfer(sfpyPool.address, tokenAmount)
    await sfpyPool.mint(merchant.address)
  }

  it("refundsETH", async function () {
    const ethAmount = expandTo18Decimals(4)
    const expectedLiquidity = expandTo18Decimals(2)
    const oracleRate = expandTo6Decimals(1)

    await router.payETH(
      HEX_REQUEST, 
      merchant.address,
      oracleRate,
      MaxUint256,
      { value: ethAmount }
    )

    expect(await wethPool.balanceOf(merchant.address)).to.eq(expectedLiquidity)
    await wethPoolAsMerchant.approve(router.address, MaxUint256)

    await expect(
      routerAsMerchant.refundETH(
        HEX_PAYMENT,
        ethAmount,
        wallet.address,
        MaxUint256
      )
    )
      .to.emit(weth, 'Transfer')
      .withArgs(wethPool.address, router.address, ethAmount)
      .to.emit(wethPool, 'Burn')
      .withArgs(router.address, ethAmount, router.address)
      .to.emit(wethPool, 'Transfer')
      .withArgs(merchant.address, wethPool.address, expectedLiquidity)
      .to.emit(router, 'Refund')
      .withArgs(
        merchant.address,
        wallet.address, 
        AddressZero, 
        HEX_PAYMENT, 
        ethAmount
      )
  })

  it("refunds", async function () {
    const tokenAmount = expandTo18Decimals(9)
    const expectedLiquidity = expandTo18Decimals(3)

    await addLiquidity(tokenAmount)

    expect(await sfpyPool.balanceOf(merchant.address)).to.eq(expectedLiquidity)

    await sfpyPoolAsMerchant.approve(router.address, MaxUint256)

    await expect(
      routerAsMerchant.refund(
        sfpy.address,
        tokenAmount,
        HEX_PAYMENT, 
        wallet.address,
        MaxUint256
      )
    )
      .to.emit(sfpy, 'Transfer')
      .withArgs(sfpyPool.address, wallet.address, tokenAmount)
      .to.emit(sfpyPool, 'Burn')
      .withArgs(router.address, tokenAmount, wallet.address)
      .to.emit(sfpyPool, 'Transfer')
      .withArgs(merchant.address, sfpyPool.address, expectedLiquidity)
      .to.emit(router, 'Refund')
      .withArgs(
        merchant.address,
        wallet.address, 
        sfpy.address, 
        HEX_PAYMENT, 
        tokenAmount
      )

    expect(await sfpyPool.balanceOf(merchant.address)).to.eq(0)
    const totalTokenSupply = await sfpy.totalSupply()
    expect(await sfpy.balanceOf(wallet.address)).to.eq(totalTokenSupply)
  })

  it("withdraws", async function () {
  	const tokenAmount = expandTo18Decimals(9)
  	const expectedLiquidity = expandTo18Decimals(3)

  	await addLiquidity(tokenAmount)

  	expect(await sfpyPool.balanceOf(merchant.address)).to.eq(expectedLiquidity)

  	await sfpyPoolAsMerchant.approve(router.address, MaxUint256)

  	await expect(
  		routerAsMerchant.withdraw(
	  		sfpy.address,
	  		expectedLiquidity,
	  		0,
	  		merchant.address,
	  		MaxUint256
	  	)
  	)
  		.to.emit(sfpy, 'Transfer')
	    .withArgs(sfpyPool.address, merchant.address, tokenAmount)
  		.to.emit(sfpyPool, 'Burn')
      .withArgs(router.address, tokenAmount, merchant.address)
  		.to.emit(sfpyPool, 'Transfer')
	    .withArgs(merchant.address, sfpyPool.address, expectedLiquidity)

	  expect(await sfpyPool.balanceOf(merchant.address)).to.eq(0)
	  const totalTokenSupply = await sfpy.totalSupply()
	  expect(await sfpy.balanceOf(wallet.address)).to.eq(totalTokenSupply.sub(tokenAmount))
  })

  it("withdrawsETH", async function () {
  	const ethAmount = expandTo18Decimals(4)
  	const expectedLiquidity = expandTo18Decimals(2)

  	await weth.deposit({ value: ethAmount })
    await weth.transfer(wethPool.address, ethAmount)
    await wethPool.mint(merchant.address)	

    await wethPoolAsMerchant.approve(router.address, MaxUint256)

    await expect(
  		routerAsMerchant.withdrawETH(
	  		expectedLiquidity,
	  		0,
	  		merchant.address,
	  		MaxUint256
	  	)
  	)
  		.to.emit(weth, 'Transfer')
	    .withArgs(wethPool.address, router.address, ethAmount)
  		.to.emit(wethPool, 'Burn')
      .withArgs(router.address, ethAmount, router.address)
  		.to.emit(wethPool, 'Transfer')
	    .withArgs(merchant.address, wethPool.address, expectedLiquidity)

	  expect(await wethPool.balanceOf(merchant.address)).to.eq(0)
	  const totalWETHSupply = await weth.totalSupply()
	  expect(await weth.balanceOf(merchant.address)).to.eq(totalWETHSupply)
  })

  it("withdrawsWithPermit", async () => {
  	const tokenAmount = expandTo18Decimals(9)
  	const expectedLiquidity = expandTo18Decimals(3)

  	await addLiquidity(tokenAmount)

  	const nonce = await sfpyPool.nonces(merchant.address)

  	const digest = await getApprovalDigest(
      sfpyPool,
      { owner: merchant.address, spender: router.address, value: expectedLiquidity },
      nonce,
      MaxUint256
    )

    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(merchant.privateKey.slice(2), 'hex'))

    await routerAsMerchant.withdrawWithPermit(
      sfpy.address,
      expectedLiquidity,
      0,
      merchant.address,
      MaxUint256,
      false,
      v,
      r,
      s
    )
  })

  it("refundsWithPermit", async () => {
    const tokenAmount = expandTo18Decimals(9)
    const expectedLiquidity = expandTo18Decimals(3)

    await addLiquidity(tokenAmount)

    const nonce = await sfpyPool.nonces(merchant.address)

    const digest = await getApprovalDigest(
      sfpyPool,
      { owner: merchant.address, spender: router.address, value: expectedLiquidity },
      nonce,
      MaxUint256
    )

    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(merchant.privateKey.slice(2), 'hex'))

    await routerAsMerchant.refundWithPermit(
      sfpy.address,
      tokenAmount,
      HEX_PAYMENT, 
      wallet.address,
      MaxUint256,
      false,
      v,
      r,
      s
    )
  })

  it("withdrawETHWithPermit", async () => {
    const ethAmount = expandTo18Decimals(4)
  	const expectedLiquidity = expandTo18Decimals(2)

  	await weth.deposit({ value: ethAmount })
    await weth.transfer(wethPool.address, ethAmount)
    await wethPool.mint(merchant.address)

    const nonce = await wethPool.nonces(merchant.address)
    const digest = await getApprovalDigest(
      wethPool,
      { owner: merchant.address, spender: router.address, value: expectedLiquidity },
      nonce,
      MaxUint256
    )

    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(merchant.privateKey.slice(2), 'hex'))

    await routerAsMerchant.withdrawETHWithPermit(
      expectedLiquidity,
      0,
      merchant.address,
      MaxUint256,
      false,
      v,
      r,
      s
    )
  })

  it("refundsETHWithPermit", async () => {
    const ethAmount = expandTo18Decimals(4)
    const expectedLiquidity = expandTo18Decimals(2)
    const oracleRate = expandTo6Decimals(1)

    await router.payETH(
      HEX_REQUEST, 
      merchant.address,
      oracleRate,
      MaxUint256,
      { value: ethAmount }
    )

    const nonce = await wethPool.nonces(merchant.address)
    const digest = await getApprovalDigest(
      wethPool,
      { owner: merchant.address, spender: router.address, value: expectedLiquidity },
      nonce,
      MaxUint256
    )

    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(merchant.privateKey.slice(2), 'hex'))

    await routerAsMerchant.refundETHWithPermit(
      HEX_PAYMENT,
      ethAmount,
      wallet.address,
      MaxUint256,
      false,
      v,
      r,
      s
    )
  })

})