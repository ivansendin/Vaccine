pragma solidity >=0.4.25 <0.6.0;

import "./CoinFlippingPool.sol";

contract Vaccine {

using CoinFlippingPool for CoinFlippingPool.CoinFlippingPoolType;

modifier onlyOwner {
    require(msg.sender == owner);
    _;
 }

 modifier onlyClinic {
  require( clinics[msg.sender]);
  _;
 }

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

  address owner;
  uint numberClinics;
  mapping (address => bool) clinics;
  mapping (address => bytes32[]) clinicVaccines;
  mapping (address => CoinFlippingPool.CoinFlippingPoolType) clinicCoins;
  mapping (address => address) patientClinic; //binds patients to clinics...


  uint numberPatients;
  mapping (address => bytes32) patientsShot;
  uint numberVaccines;
  VaccineShot[] vaccines;
  mapping (bytes32 => VaccineShot) vaccinesMap;
  uint threshold;
  uint minEfficiency;
  uint sick;

  uint control;
  uint vaccine;

  bool approved;

  constructor(uint nC, uint nV, uint nP, uint target, uint efficiency) public {
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

  function addClinic(address newClinic) public onlyOwner {

    clinics[newClinic] = true;
    CoinFlippingPool.CoinFlippingPoolType memory pool;
    clinicCoins[newClinic] = pool;

  }


  function addVaccine(bytes32 commit, address clinic) public onlyOwner {
      VaccineShot memory newShot;
      newShot.commit = commit;
      newShot.vt = VaccineType.Hidden;
      newShot.clinic = clinic;
      vaccines.push(newShot);
      vaccinesMap[commit] = newShot;
      clinicVaccines[clinic].push(commit);
  }

  function vaccinateInit(address patient, bytes32 coinCommit) public onlyClinic {
      clinicCoins[msg.sender].initFlipping(coinCommit,patient);
      patientClinic[patient] = msg.sender;
  }

  // ajustar onlyPatient...
  function vaccinatePatientJoin(bytes32 coinCommit) public {
    clinicCoins[patientClinic[msg.sender]].joinFlipping(coinCommit,msg.sender);
  }

  function clinicRevealCoin(bytes32 nonce,byte v,address patient) public onlyClinic {
    CoinFlippingPool.CoinFlippingPoolType storage t1 = clinicCoins[msg.sender];
    t1.revealOwner(nonce,v,patient);
    // clinicCoins[msg.sender].revealOwner(nonce,v,patient);
  }

  function patientRevealCoin(bytes32 nonce,byte v) public  {
    clinicCoins[patientClinic[msg.sender]].revealOther(nonce,v,msg.sender);
  }

  function vaccinate(address patient) public onlyClinic {
    require ( clinicCoins[msg.sender].isCorrect(patient));
    uint16 random =  uint16(bytes2(clinicCoins[msg.sender].getValue(patient))) % uint16(clinicVaccines[msg.sender].length);

    bytes32 shot  = clinicVaccines[msg.sender][random];
    delete clinicVaccines[msg.sender][random];
    patientsShot[patient] = shot;
    vaccinesMap[shot].patient = patient;
  }


  function Xvaccinate(address patient, bytes32 shot) private {
    // verify VC owns the vaccine
    patientsShot[patient] = shot;
    vaccinesMap[shot].patient = patient;

  }

  // Patient confirmation
  function gotVaccinated(bytes32 shot) public onlyPatient {
    VaccineShot memory vs = vaccinesMap[shot];
    require (vs.patient == msg.sender);
    vs.patientVaccinated = true;

  }

  function gotSick() public  {
    VaccineShot memory vs = vaccinesMap[patientsShot[msg.sender]];
    require (vs.patient == msg.sender);
    require (vs.gotSick == false);
    vs.gotSick = true;
    sick = sick +1;
    if (sick>=threshold) {

    }
  }

  // Useless
  function reveal(bytes32 shot, bytes32 nonce, byte v) public onlyOwner {
    // recevives nonce and vaccine VaccineType
    // verifies
    // count....
    require (vaccinesMap[shot].vt == VaccineType.Hidden);
    bytes32 ver = sha256(abi.encodePacked(nonce,v));
    if (ver==shot) {
      if (v == bytes1(0)) {
        vaccine = vaccine+1;
        vaccinesMap[shot].vt = VaccineType.Vaccine;
      } else { // if v == 1
        control = control+1;
        vaccinesMap[shot].vt = VaccineType.Control;
      }
    }
  }

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

  function getControlCount() public returns (uint) {
    return control;
  }

  function finishReveal() public onlyOwner {
    // change state to .... finishig the trial
    // require reveal
    approved =  (threshold - control) < minEfficiency;

  }

  function isApproved() public returns (bool) {
    // require finished
    return approved;
  }

  function gotVaccine(address p) public returns (bool) {
    return true;
  }

}
