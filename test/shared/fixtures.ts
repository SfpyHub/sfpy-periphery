import { Wallet, Contract } from 'ethers'
import { Web3Provider } from '@ethersproject/providers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import SfpyFactory from '@sfpy/core/build/SfpyFactory.json'
import ISfpyPool from '@sfpy/core/build/ISfpyPool.json'

import ERC20 from '../../build/ERC20.json'
import WETH9 from '../../build/WETH9.json'

import SfpyRouter from '../../build/SfpyRouter.json'

interface Fixture {
  SFPY: Contract
  WETH: Contract
  factory: Contract
  router: Contract
  SFPYPool: Contract
  WETHPool: Contract
}

export async function SfpyFixture([wallet]: Wallet[], provider: Web3Provider): Promise<Fixture> {
	const sfpy = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])
	const weth = await deployContract(wallet, WETH9)

	const factory = await deployContract(wallet, SfpyFactory, [wallet.address])

	const router = await deployContract(wallet, SfpyRouter, [factory.address, weth.address])

	await factory.createPool(sfpy.address)
	await factory.createPool(weth.address)

	const sfpyPoolAddress = await factory.pool(sfpy.address)
	const wethPoolAddress = await factory.pool(weth.address);

	const sfpyPool = new Contract(sfpyPoolAddress, JSON.stringify(ISfpyPool.abi), provider).connect(wallet)
	const wethPool = new Contract(wethPoolAddress, JSON.stringify(ISfpyPool.abi), provider).connect(wallet)

	return {
		SFPY: sfpy,
		WETH: weth,
		factory: factory,
		router: router,
		SFPYPool: sfpyPool,
		WETHPool: wethPool
	}
}