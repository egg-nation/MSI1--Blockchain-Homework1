// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <=0.8.15;

contract CrowdFunding {

    struct contributor {

        string username;
        address addressValue;
        uint256 funded;
    }

    contributor[] public contributors;

    address public owner;
    address public sponsor;
    address public distributor;

    uint256 public fundingState = 0;
    uint256 public fundingGoal;
  
    constructor(uint256 goal) {

        owner = msg.sender;
        fundingGoal = goal;
    }

    // warnings
    string private restrictedToOwner = "RESTRICTION: This function can only be called by the owner.";
    string private restrictedToSponsor = "In order to finance the contract you must be a sponsor.";
    string private contractAlreadyFinanced = "The contract was already financed.";
    string private contractEnded = "The contract has ended.";
    string private ownerNotRegistered = "You are not registered yet! Please register to continue.";
    string private endedFinancingPhase = "The financing phase has ended.";
    string private failedSendingSponsorshipToCrowdfunding = "An error has occurred while sending the sponsorship to CrowdFunding.";

    function getState() public view returns (string memory) {

        if (fundingState >= 2) {

            return "financed";

        } else if (fundingState == 1) {

            return "prefinanced";

        } else {

            return "notfinanced";
        }
    }

    modifier restrictToOwner() {

        require(owner == msg.sender, restrictedToOwner);
        _;
    }

    modifier contractIsActive() {

        require(fundingState < 3, contractEnded);
        _;   
    }

    receive() contractIsActive external payable {
        
        require(fundingState != 2, contractAlreadyFinanced);

        if (fundingState == 1) {

            require(sponsor == msg.sender, restrictedToSponsor);
            ++fundingState;
            
        } else {

            (uint index, bool isContributorfound) = findContributor(msg.sender);
            require(isContributorfound, ownerNotRegistered);

            contributors[index].funded += msg.value;

            if (fundingGoal <= address(this).balance) {

                fundingState = 1;
            }
        }
    }

    function register(string memory username) external contractIsActive {

        contributors.push(contributor(username, msg.sender, 0));
    }

    function findContributor(address addressValue) private view returns (uint, bool) {

        for (uint index = 0; index < contributors.length; ++index) {

            if (addressValue == contributors[index].addressValue) {

                return (index, true);
            }
        }
        
        return (0, false);
    }


    function sendFinancing() external restrictToOwner contractIsActive {

        require(fundingState == 2, endedFinancingPhase);

        (bool isSponsorshipSent, ) = payable(distributor).call{value:address(this).balance}("");
        require(isSponsorshipSent, failedSendingSponsorshipToCrowdfunding);
    }

    function returnFinancing() public contractIsActive {

        require(fundingState < 1, endedFinancingPhase);

        (uint index, bool isContributorfound) = findContributor(msg.sender);
        require(isContributorfound, ownerNotRegistered);
        
        payable(msg.sender).transfer(contributors[index].funded);
        contributors[index].funded = 0;
    }

    function setSponsor(address sponsorAddressValue) external restrictToOwner contractIsActive {

        sponsor = sponsorAddressValue;
    }

    function setDistributor(address distributorAddressValue) external restrictToOwner {

        distributor = distributorAddressValue;
    }
}

contract SponsorFunding {

    address owner;

    address crowdFundingAddressValue;
    uint sponsorshipPercent;
    bool canSponsor = false;

    constructor(address newCrowdFundingAddressValue) {

        owner = msg.sender;

        crowdFundingAddressValue = newCrowdFundingAddressValue;
        sponsorshipPercent = 10;
    }

    // warnings 
    string private restrictedToOwner = "RESTRICTION: This function can only be called by the owner.";
    string private restrictedToCrowdFundingOwner = "RESTRICTION: This function can only be called by the owner of CrowdFunding.";
    string private restrictedToSponsor = "In order to finance the contract you must be a sponsor.";
    string private contractNotYetFinanced = "The contract has not yet been financed.";
    string private failedSendingSponsorshipToCrowdfunding = "An error has occurred while sending the sponsorship to CrowdFunding.";
    string private failedSponsorshipDueToInsufficientFunds = "Could not sponsor due to insufficient funds.";

    modifier restrictToOwner() {

        require(owner == msg.sender, restrictedToOwner);
        _;
    }

    receive() external payable {

        require(owner == msg.sender, restrictedToOwner);
    }

    function changeSponsorshipPercent(uint newSponsorshipPercent) external{

        sponsorshipPercent = newSponsorshipPercent;
    }

    function announcePrefinanced() external {

        require(
            CrowdFunding(payable(crowdFundingAddressValue)).owner() == msg.sender, 
            restrictedToCrowdFundingOwner
        );
        require(
            CrowdFunding(payable(crowdFundingAddressValue)).fundingState() == 1, 
            contractNotYetFinanced
        );

        canSponsor = true;
    }

    function sponsor() external {

        require(owner == msg.sender, restrictedToOwner);
        require(canSponsor, contractNotYetFinanced);

        uint neededFunds = (sponsorshipPercent * crowdFundingAddressValue.balance) / 100;
        require(address(this).balance >= neededFunds, failedSponsorshipDueToInsufficientFunds);

        uint remainingFunds = address(this).balance - neededFunds;
        payable(owner).transfer(remainingFunds);

        (bool isSponsorshipSent, ) = payable(crowdFundingAddressValue).call{value:neededFunds}("");
        require(isSponsorshipSent, failedSendingSponsorshipToCrowdfunding);
    }
}

contract DistributeFunding {

    struct shareholder {

        address payable addressValue;
        uint percentage;
        bool isShareTaken;
    }

    shareholder[] public shareholders;

    address public owner;

    address public crowdFundingAddressValue;
    uint public funds = 0;
    bool public areFundsReceived = false;

    constructor(address newCrowdFundingAddressValue) {

        owner = msg.sender;

        crowdFundingAddressValue = newCrowdFundingAddressValue;
        funds = 0;
        areFundsReceived = false;
    }

    // warnings
    string private restrictedToOwner = "RESTRICTION: This function can only be called by the owner.";
    string private restrictedToCrowdFundingContract = "RESTRICTION: In order to send money to this contract you have to be a CrowdFunding contract.";
    string private restrictedToDistributorFundingShareholder = "RESTRICTION: In order to take a share from DistributorFunding contract you have to be a shareholder.";
    string private fundsAlreadyReceived = "The funds were already received.";
    string private fundsNotYetReceived = "The funds have not yet been received.";
    string private shareAlreadyTaken = "You have already taken your share.";

    modifier restrictToOwner() {

        require(owner == msg.sender, restrictedToOwner);
        _;
    }

    receive() external payable {

        require(crowdFundingAddressValue == msg.sender, restrictedToCrowdFundingContract);
        require(!areFundsReceived, fundsAlreadyReceived);

        areFundsReceived = true;
        funds = msg.value;
    }

    function getShareholder(address addressValue) private view returns (uint, bool) {

        for (uint index = 0; index < shareholders.length; ++index){

            if (addressValue == shareholders[index].addressValue){

                return (index, true);
            }
        }

        return (0, false);
    }

    function addShareholder(address shareholderAddress, uint percentage) external restrictToOwner {

        require(owner == msg.sender, restrictedToOwner);
        (uint index, bool isShareholderFound) = getShareholder(shareholderAddress);

        if (!isShareholderFound) {

            shareholders.push(shareholder(payable(shareholderAddress), percentage, false));

        } else {

            shareholders[index].percentage = percentage;
        }
    }

    function takeShare() external {

        (uint index, bool isShareholderFound) = getShareholder(msg.sender);

        require(isShareholderFound, restrictedToDistributorFundingShareholder);
        require(!shareholders[index].isShareTaken, shareAlreadyTaken);
        require(areFundsReceived, fundsNotYetReceived);

        shareholders[index].addressValue.transfer(
            (funds * shareholders[index].percentage) / 100
        );
        shareholders[index].isShareTaken = true;
    }
}