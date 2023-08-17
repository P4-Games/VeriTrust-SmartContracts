# Veritrust Smart Contracts

Welcome to the Veritrust Smart Contracts repository. These contracts are an integral part of the Veritrust Protocol. The Veritrust Protocol aims to revolutionize the tender process by harnessing the transparency and security of blockchain technology. These smart contracts facilitate a corruption-resistant environment, ensuring transparency and immutability throughout the tender process. Additionally, the contracts seamlessly integrate Chainlink oracles to obtain accurate ETH/USD price data.

## Contracts

### VeritrustFactory.sol

`VeritrustFactory.sol` is a contract factory that simplifies the deployment of Veritrust contracts. Written in Solidity, it efficiently creates new instances of the 
`Veritrust.sol` contract, ensuring that each tender project is well-isolated and independent. By using the factory contract, the Veritrust ecosystem can scale effectively, accommodating numerous tender projects simultaneously.

- **Creation of Tender:** Allows administrators to create new tenders, specifying important details such as the tender description, deadline, and requirements.

### Veritrust.sol

`Veritrust.sol` is a core smart contract that embodies the principles of the Veritrust project. It's written in Solidity and is designed to handle various stages of the tender process, maintaining transparency and integrity throughout. The contract includes functionalities such as:

- **Commit phase:** Participants can submit their hashed bids for a specific tender.

- **Reveal phase:** Participants submit their visible url which contains all the relevant information.

## Integration with Chainlink Oracles

The Veritrust project places a strong emphasis on accurate pricing data, which is essential for conducting transparent tenders. To achieve this, the contracts utilize Chainlink oracles to obtain real-time ETH/USD price information. This integration ensures that the tender process considers the most up-to-date market data when making decisions related to bidding and payments.

## Security and Testing

The Veritrust Smart Contracts have undergone rigorous testing and auditing using Hardhat's testing framework. However, due to the complexities of blockchain systems, users are advised to exercise caution and perform thorough testing when interacting with these contracts.

## Contributing

Contributions to the Veritrust project are encouraged. If you discover issues or have suggestions for improvements, please open an issue or submit a pull request in this repository.

Thank you for being a part of the Veritrust initiative - together, we're reshaping the future of transparent and corruption-free tenders!