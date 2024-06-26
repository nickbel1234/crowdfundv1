// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @title The crowdfunding platform
/// @author Bahador Ghadamkheir
/// @dev This is a sample crowdfunding smart contract.
/// @notice As this contract is not audited, use at your own risk!
contract CrowdFunding is Ownable {
    using SafeMath for uint256;

    struct Campaign {
        address owner;
        bool payedOut;
        string title;
        string description;
        uint256 target;
        uint256 deadline;
        uint256 amountCollected;
        string image;
        address[] donators;
        uint256[] donations;
    }

    mapping(uint256 => Campaign) public campaigns;

    uint8 public platformTax;
    uint24 public numberOfCampaigns;

    bool public emergencyMode;

    event Action (
        uint256 id,
        string actionType,
        address indexed executor,
        uint256 timestamp
    );

    event ContractStateChanged (
        bool state
    );

    error LowEtherAmount(uint minAmount, uint payedAmount);
    error DeadLine(uint campaingDeadline, uint requestTime);

    modifier privilageEntity(uint _id) {
        _privilagedEntity(_id);
        _;
    }

    modifier notInEmergency() {
        require(!emergencyMode, "Contract is in emergency mode");
        _;
    }

    modifier onlyInEmergency() {
        require(emergencyMode, "Contract is not in emergency mode");
        _;
    }

    modifier notNull(
        string memory title,
        string memory description,
        uint256 target,
        uint256 deadline,
        string memory image
    ) {
        _nullChecker(title, description, target, deadline, image);
        _;
    }

    constructor(uint8 _platformTax) {
        platformTax = _platformTax;
    }

    function createCampaign(
        address _owner,
        string memory _title,
        string memory _description,
        uint256 _target,
        uint256 _deadline,
        string memory _image
    ) external notNull(_title, _description, _target, _deadline, _image) notInEmergency returns (uint256) {
        require(_deadline > block.timestamp, "Deadline must be in the future");
        Campaign storage campaign = campaigns[numberOfCampaigns];
        numberOfCampaigns++;

        campaign.owner = _owner;
        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;
        campaign.payedOut = false;

        emit Action (
            numberOfCampaigns,
            "Campaign Created",
            msg.sender,
            block.timestamp
        );

        return numberOfCampaigns - 1;
    }

    function updateCampaign(
        uint256 _id,
        string memory _title,
        string memory _description,
        uint256 _target,
        uint256 _deadline,
        string memory _image
    ) external privilageEntity(_id) notNull(_title, _description, _target, _deadline, _image) notInEmergency returns (bool) {
        require(_deadline > block.timestamp, "Deadline must be in the future");

        Campaign storage campaign = campaigns[_id];
        require(campaign.owner > address(0), "No campaign exist with this ID");
        require(campaign.amountCollected == 0, "Update error: amount collected");

        campaign.title = _title;
        campaign.description = _description;
        campaign.target = _target;
        campaign.deadline = _deadline;
        campaign.amountCollected = 0;
        campaign.image = _image;
        campaign.payedOut = false;

        emit Action (
            _id,
            "Campaign Updated",
            msg.sender,
            block.timestamp
        );
        return true;
    }

    function donateToCampaign(uint256 _id) external payable notInEmergency {
        if (msg.value == 0) revert LowEtherAmount(1 wei, msg.value);
        Campaign storage campaign = campaigns[_id];
        if (campaign.payedOut == true) revert("Funds already withdrawn");
        require(campaign.owner > address(0), "No campaign exist with this ID");
        require(campaign.deadline > block.timestamp, "Campaign deadline has passed");

        uint256 amount = msg.value;
        if (campaign.amountCollected + amount > campaign.target) revert ("Target amount has been reached");
        campaign.amountCollected = campaign.amountCollected.add(amount);

        campaign.donators.push(msg.sender);
        campaign.donations.push(amount);

        emit Action (
            _id,
            "Donation To The Campaign",
            msg.sender,
            block.timestamp
        );
    }

    function payOutToCampaignTeam(uint256 _id) external privilageEntity(_id) notInEmergency returns (bool) {
        if (campaigns[_id].payedOut == true) revert("Funds already withdrawn");
        require(campaigns[_id].amountCollected >= campaigns[_id].target, "Campaign goal not reached");

        campaigns[_id].payedOut = true;
        (uint256 raisedAmount, uint256 taxAmount) = _calculateTax(_id);
        _payTo(campaigns[_id].owner, raisedAmount - taxAmount);
        _payPlatformFee(taxAmount);
        emit Action (
            _id,
            "Funds Withdrawal",
            msg.sender,
            block.timestamp
        );
        return true;
    }

    function _payPlatformFee(uint256 _taxAmount) internal {
        _payTo(owner(), _taxAmount);
    }

    function deleteCampaign(uint256 _id) external privilageEntity(_id) notInEmergency returns (bool) {
        require(campaigns[_id].owner > address(0), "No campaign exist with this ID");
        if (campaigns[_id].amountCollected > 0) {
            _refundDonators(_id);
        }
        delete campaigns[_id];

        emit Action (
            _id,
            "Campaign Deleted",
            msg.sender,
            block.timestamp
        );

        numberOfCampaigns -= 1;
        return true;
    }

    function getDonators(uint256 _id) external view returns (address[] memory, uint256[] memory) {
        return (campaigns[_id].donators, campaigns[_id].donations);
    }

    function changeTax(uint8 _platformTax) external onlyOwner {
        platformTax = _platformTax;
    }

    function haltCampaign(uint256 _id) external onlyOwner {
        campaigns[_id].deadline = block.timestamp;

        emit Action (
            _id,
            "Campaign halted",
            msg.sender,
            block.timestamp
        );
    }

    function getCampaigns() external view returns (Campaign[] memory) {
        Campaign[] memory allCampaigns = new Campaign[](numberOfCampaigns);

        for (uint i = 0; i < numberOfCampaigns; i++) {
            Campaign storage item = campaigns[i];

            allCampaigns[i] = item;
        }

        return allCampaigns;
    }

    function changeContractState() external onlyOwner {
        emergencyMode = !emergencyMode;

        emit ContractStateChanged(emergencyMode);
    }

    function withdrawFunds(uint256 _startId, uint256 _endId) external onlyOwner onlyInEmergency {
        for (uint i = _startId; i <= _endId; i++) {
            _refundDonators(i);
        }
    }

    function _refundDonators(uint256 _id) internal {
        Campaign storage campaign = campaigns[_id];
        require(campaign.owner > address(0), "No campaign exists with this ID");

        for (uint i = 0; i < campaign.donators.length; i++) {
            uint256 donationAmount = campaign.donations[i];
            campaign.donations[i] = 0;
            _payTo(campaign.donators[i], donationAmount);
        }

        campaign.amountCollected = 0;
    }

    function _calculateTax(uint256 _id) internal view returns (uint256, uint256) {
        uint256 raised = campaigns[_id].amountCollected;
        uint256 tax = (raised * platformTax) / 100;
        return (raised, tax);
    }

    function _payTo(address to, uint256 amount) internal {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Transfer failed");
    }

    function _nullChecker(
        string memory _title,
        string memory _description,
        uint256 _target,
        uint256 _deadline,
        string memory _image
    ) internal view {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_target > 0, "Target must be greater than zero");
        require(_deadline > block.timestamp, "Deadline must be in the future");
        require(bytes(_image).length > 0, "Image cannot be empty");
    }

    function _privilagedEntity(uint256 _id) internal view {
        require(
            msg.sender == campaigns[_id].owner ||
            msg.sender == owner(),
            "Unauthorized Entity"
        );
    } 
}
