pragma solidity ^0.4.9;
// perhaps if the version is set to 0.9 then the throw statements will be compiled?
 // Play account#2: 0x12
 // Play account#3: 0x98
 // Play account#4: 0x22
 // contract address: 0x86ab9260cc9eb72d6d49a6249f2b57f8de3d2b8194ce826c752e91d575009106

contract CrowdFunder {

// Variables set
address public creator;
address public fundRecipient;   // creator may be different to recipient
uint public minimumToRaise;     // required to tip, else everyone gets refund
string campaignUrl;
byte constant version = 1;     // This variable throws an error-> Decimal literal assigned to bytesXX variable will be left-aligned. Use an explicit conversion to silence this warning.

// Data structures
enum State {                     // what exactly are enum(s)?
    Fundraising,      //State 0
    ExpiredRefund,    //State 1
    Successful,       //State 2
    Closed            //State 3
}

struct Contribution {
    uint amount;
    address contributor;
}

// State Variables
State public state = State.Fundraising; // initialize on create
uint public totalRaised;
uint public currentBalance;
uint public raiseBy;
uint public completeAt;
Contribution[] contributions;  // This is an array? shudder!

event LogFundingReceived(address addr, uint amount, uint currentTotal);
event LogWinnerPaid(address winnerAddress);
event LogFunderInititalized(
  address creator,
  address fundRecipient,
  string url,
  uint _minimumToRaise,
  uint256 raiseby); // note all lc

  /* modifier inState(State _state) {
    if (state != _state) throw; // need to change this to assert I think.
    _;
  } */
  modifier inState(State _state){
    assert(state == _state); // Done.
    _;
  }

  /* modifier isCreator() {
    if (msg.sender != creator) throw; // need to change this to assert I think..
    _;
  } */
  modifier isCreator() {            // what's best, assert, or require?
    require(msg.sender == creator); // Done.
    _;
  }


// Wait 6 months after final contract state before allowing contract destruction
/*
modifier atEndOfLifecycle() {
  if(!((state == State.ExpiredRefund || state == State.Successful) && completeAt + 1 hours < now)) {
    throw;  // The not (!) makes this modifier ammenable to an assert statement.
  }
  _;  // Why is underscore+terminator here?
}
*/
// Wait 1 hour after final contract state before allowing contract destruction
    modifier atEndOfLifecycle() {
        require(((state == State.ExpiredRefund || state == State.Successful) && completeAt + 1 hours < now));
    _;   // Not sure this underscore+terminator is correct but best I can come up with.
    }


    function CrowdFunder(
        uint timeInHoursForFundraising,
        string _campaignUrl,
        address _fundRecipient,
        uint _minimumToRaise)
        public
        {
            creator = msg.sender;
            fundRecipient = _fundRecipient;
            campaignUrl = _campaignUrl;
            minimumToRaise = _minimumToRaise * 1000000000000000000; // convert to wei
            raiseBy = now + (timeInHoursForFundraising * 1 hours);
            currentBalance = 0;
            LogFunderInititalized(
                creator,
                fundRecipient,
                campaignUrl,
                minimumToRaise,
                raiseBy);
    } // eo function CrowdFunder


    function contribute()
    public
    inState(State.Fundraising) payable returns (uint256)
    {
        contributions.push(
            Contribution({
                amount: msg.value,
                contributor: msg.sender
                })  // use array, so can iterate
        );
        totalRaised += msg.value;
        currentBalance = totalRaised;
        LogFundingReceived(msg.sender, msg.value, totalRaised);

        checkIfFundingCompletedOrExpired();
        return contributions.length - 1; // return id
    } // eo function contribute

    function checkIfFundingCompletedOrExpired() public {
        if (totalRaised > minimumToRaise) {
            state = State.Successful;
            payout();
            } else if ( now > raiseBy) {
                state = State.ExpiredRefund; // backer can now collect refunds by calling getRefund(id)
        }
            completeAt = now;
    }  // eo function checkIfFundingCompletedOrExpired

    function payout()
    public
    inState(State.Successful)
    {
    /* if (!fundRecipient.send(this.balance)) {
        throw; // must be changed to assert or revert or require
    } */

        require(fundRecipient.send(this.balance));
        state = State.Closed;
        currentBalance = 0;
        LogWinnerPaid(fundRecipient);
    } // eo function payout

    function getRefund(uint256 id)
    public
    inState(State.ExpiredRefund)
    returns (bool)
    {
        /* if (contributions.length <= id || id < 0 || contributions[id].amount ==0) {
            throw; // Needs changing
        } */

        if(!(contributions.length <= id || id < 0 || contributions[id].amount == 0)){
            return true; // Have changed it but don't know if logic stacks up.
        }

        uint amountToRefund = contributions[id].amount;
        contributions[id].amount = 0;

        if(!contributions[id].contributor.send(amountToRefund)) {
            contributions[id].amount = amountToRefund;
            return false;
            } else {
                totalRaised -= amountToRefund;
                currentBalance = totalRaised;
            }
            return true;
    } // eo function getRefund

    function removeContract()
    public
    isCreator()
    atEndOfLifecycle()
    {
        selfdestruct(msg.sender);
      // creator receives all unclaimed ether.
    } // eo function removeContract

    // The fallback function. One per program allowed.
    // function() { throw;}  // Throw is deprecated 
    function() public {
        revert();   // must be 
    } 

}  // eo contract CrowdFunder
