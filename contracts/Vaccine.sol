/**

@author Ivan da Silva Sendin


@title A SC to Phase III Vaccine Trial




*/

pragma solidity >=0.4.25 <0.6.0;

import "./CoinFlippingPool.sol";

/// @title A SC to Phase III Vaccine Trial
contract Vaccine {

using CoinFlippingPool for CoinFlippingPool.CoinFlippingPoolType;

/// @dev only contract owner modifier
modifier onlyOwner {
    require(msg.sender == owner);
    _;
 }

 /// @dev only clinics modifier
 modifier onlyClinic {
  require( clinics[msg.sender]);
  _;
 }

 /// @dev only patient modifier
 modifier onlyPatient {
    require( patientsShot[msg.sender] !=0);
  _;
 }

  enum VaccineType {
                      Hidden,
                      Control,
                      Vaccine
                    }


  struct VaccineShot {
    address clinic;
    bool clinicAccepted;
    address patient;
    bool patientVaccinated;
    bool gotSick;
    bytes32 commit;
    VaccineType vt;

  }


  enum TrialSates { Beggining,
                    Clinics,
                    Vaccines,
                    Vaccinating,
                    Waiting,
                    Oppening,
                    Finished}

  /// @notice Contract owner
  address owner;
  /// @notice Number of clinics participating
  uint numberClinics;
  /// @notice set o participating clinics
  mapping (address => bool) clinics;
  /// @notice Associate a clinic to vaccines
  mapping (address => bytes32[]) clinicVaccines;
  /// @notice Used to random assignment patient X shot
  mapping (address => CoinFlippingPool.CoinFlippingPoolType) clinicCoins;
  /// @notice binds patients to clinics...
  mapping (address => address) patientClinic;


  /// @notice Patients participants
  uint numberPatients;
  /// @notice Associate one patient to one shot
  mapping (address => bytes32) patientsShot;
  /// @notice number of vaccines in this trial
  uint numberVaccines;
  /// @notice
  VaccineShot[] vaccines;
  /// @notice
  mapping (bytes32 => VaccineShot) vaccinesMap;
  /// @notice
  uint threshold;
  /// @notice
  uint minEfficiency;
  /// @notice Number of patients that got sick
  uint sick;

  /// @notice Number of sick patients that was associated to control
  uint control;
  /// @notice Number of sick patients that was associated to (real) vaccine
  uint vaccine;

  /// @notice Vaccine aproval status
  bool approved;


/**


@notice Contract constructor
@param nC Number of participants clinics
@param nV NUmber of shots in this Trial
@param nP Number of patients
@param target Number of infected patients before efficiency is calculated
@param efficiency efficiency acceptable

For example, the Pfizer Covid Vaccine Trial(https://pfe-pfizercom-d8-prod.s3.amazonaws.com/2020-09/C4591001_Clinical_Protocol.pdf)
targets 164 (see page 92) confirmed Covid-19 cases on abou 22k patients.
For an hypotetical efficiency limit of 0.5 one should create a vaccine contract with:
    * nC = ??
    * nV = 22000
    * nP = 22000
    * target = 164
    * efficiency =  55 (mening that at most 55 infected patient should be in Vaccine group to vaccine approval)

*/

  constructor(
      uint nC,
      uint nV,
      uint nP,
      uint target,
      uint efficiency
    ) public {

    owner = msg.sender;
    numberClinics = nC;
    numberVaccines = nV;
    numberPatients = nP;
    minEfficiency = efficiency;
    threshold = target;
    sick =0 ;
    control =0;
    vaccine = 0;
    approved = false;
  }

  /// @notice Adds a new clinic
  /// @param newClinic address
  function addClinic(address newClinic) public onlyOwner {
    clinics[newClinic] = true;
    CoinFlippingPool.CoinFlippingPoolType memory pool;
    clinicCoins[newClinic] = pool;
  }

  /// @notice Adds a vaccine shot to be applied on one patient by a clinic
  /// @param commit for vaccine/placebo
  /// @param clinic associated to this shot
  function addVaccine(bytes32 commit, address clinic) public onlyOwner {
      VaccineShot memory newShot;
      newShot.commit = commit;
      newShot.vt = VaccineType.Hidden;
      newShot.clinic = clinic;
      vaccines.push(newShot);
      vaccinesMap[commit] = newShot;
      clinicVaccines[clinic].push(commit);
  }

  /// @notice Initiate the vaccination for a patient flipping a coin
  /// @param patient Target patient
  /// @param coinCommit Commit to coin value
  function vaccinateInit(address patient, bytes32 coinCommit) public onlyClinic {
      clinicCoins[msg.sender].initFlipping(coinCommit,patient);
      patientClinic[patient] = msg.sender;
  }

  /// @notice Patient sart coin flipping
  /// @param coinCommit Commit to coin value
  function vaccinatePatientJoin(bytes32 coinCommit) public {
    clinicCoins[patientClinic[msg.sender]].joinFlipping(coinCommit,msg.sender);
  }

  /// @notice Clinic revals coin value to finish coin flipping
  /// @param nonce to validate v
  /// @param v commited value
  /// @param patient associated to this coin in initFlipping
  function clinicRevealCoin(bytes32 nonce,byte v,address patient) public onlyClinic {
    CoinFlippingPool.CoinFlippingPoolType storage t1 = clinicCoins[msg.sender];
    t1.revealOwner(nonce,v,patient);
    // clinicCoins[msg.sender].revealOwner(nonce,v,patient);
  }

  /// @notice Finihing the coin flipping by patient
  /// @param nonce used to commit
  /// @param v value commited
  function patientRevealCoin(bytes32 nonce,byte v) public  {
    clinicCoins[patientClinic[msg.sender]].revealOther(nonce,v,msg.sender);
  }

  /// @notice Finishes the vaccination process associanting one patient to one shot
  /// @param patient to get vaccinated
  function vaccinate(address patient) public onlyClinic {
    require ( clinicCoins[msg.sender].isCorrect(patient));
    uint16 random =  uint16(bytes2(clinicCoins[msg.sender].getValue(patient))) % uint16(clinicVaccines[msg.sender].length);

    bytes32 shot  = clinicVaccines[msg.sender][random];
    delete clinicVaccines[msg.sender][random];
    patientsShot[patient] = shot;
    vaccinesMap[shot].patient = patient;
  }

  /// @notice  Patient shot confirmation
  function gotVaccinated(bytes32 shot) public onlyPatient {
    VaccineShot memory vs = vaccinesMap[shot];
    require (vs.patient == msg.sender);
    vs.patientVaccinated = true;

  }

  /// @notice Patient communicates an infection event
  /// @dev Increses the sik counter by one and verify the threshold
  function gotSick() public  {
    VaccineShot memory vs = vaccinesMap[patientsShot[msg.sender]];
    require (vs.patient == msg.sender);
    require (vs.gotSick == false);
    vs.gotSick = true;
    sick = sick +1;
    if (sick>=threshold) {
      // handle state changes
    }
  }


  /// @notice Vaccine Developer reveals that shot is not vaccine, but a control/placebo
  /// @param shot shot id
  /// @param nonce to validate the value(implicity 0x01)
  function revealControl(bytes32 shot, bytes32 nonce) public onlyOwner {
    require (vaccinesMap[shot].vt == VaccineType.Hidden);
    byte v;
    v=0x01;
    bytes32 ver = sha256(abi.encodePacked(nonce,v));
    if (ver==shot) {
      control++;
      vaccinesMap[shot].vt = VaccineType.Control;
    }
  }

  // Useless
  function getVaccineCount() public returns (uint) {
    return vaccine;
  }

  /// @notice Number of controls shots
  /// @return Number of control shots revealed
  function getControlCount() public returns (uint) {
    return control;
  }

  /// @notice Finish the reveal phase, calculating the approved
  function finishReveal() public onlyOwner {
    // change state to .... finishig the trial
    // require reveal
    approved =  (threshold - control) < minEfficiency;

  }

  /// @notice
  /// @return Vaccine aproval status
  function isApproved() public returns (bool) {
    // require finished
    return approved;
  }

  /// @notice Verifies if patient got vaccine
  /// @param p patient
  /// @return patient vaccination status
  function gotVaccine(address p) public returns (bool) {
    return true;
  }

}
