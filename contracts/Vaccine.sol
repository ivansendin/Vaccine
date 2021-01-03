pragma solidity >=0.4.25 <0.6.0;


contract Vaccine {

modifier onlyOwner {
    require(msg.sender == owner);
    _;
 }

 modifier onlyClinic {
  require( clinics[msg.sender]);
  _;
 }

 modifier onlyPatient {
    require( patients[msg.sender] !=0);
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

  uint numberPatients;
  mapping (address => bytes32) patients;
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

  function vaccinate(address patient, bytes32 shot) public onlyClinic {
    // verify VC owns the vaccine
    patients[patient] = shot;
    vaccinesMap[shot].patient = patient;

  }

  // Patient confirmation
  function gotVaccinated(bytes32 shot) public onlyPatient {
    VaccineShot memory vs = vaccinesMap[shot];
    require (vs.patient == msg.sender);
    vs.patientVaccinated = true;

  }

  function gotSick() public onlyPatient {
    VaccineShot memory vs = vaccinesMap[patients[msg.sender]];
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
    control = control+1;
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



}
