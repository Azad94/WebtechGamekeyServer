part of serverLibrary;

class User {

  String _id;
  String _type;
  String _name;
//  String _secret;
  String _eMail;
  DateTime _createdAt = new DateTime.now();
  String _signature;



  User(this._id, this._type, this._name, this._eMail,
      this._createdAt,
      this._signature);

  String toString() {
    String _date = _createdAt.toString();
    return "\nusers: [" + "\n\t{" +
        "\t\tUserID: " + _id + "\n" +
        "\n\t\ttype: " + _type + "\n" +
        "\t\tName: " + _name + "\n" +
       // "\t\tSecret: " + _secret + "\n" +
        "\t\tEMail: " + _eMail + "\n" +
        "\t\tErstellt am: " + _date + "\n" +
        "\t\tSignatur: " + _signature + "\n" +
        "\n\t}" + "\n],";
  }


  Map _mapOneUserToEncode() {
    var _dummyMap = new Map();
    String time = _createdAt.toIso8601String();
    _dummyMap['ID'] = _id;
    _dummyMap['Type'] = _type;
    _dummyMap['Name'] = _name;
    _dummyMap['EMail'] = _eMail;
    _dummyMap['Time'] = time;

    return _dummyMap;
  }

  Map _mapAllUserToEncode() {
    var _dummyMap = new Map();
    String time = _createdAt.toIso8601String();

    _dummyMap['ID'] = _id;
    _dummyMap['Type'] = _type;
    _dummyMap['Name'] = _name;
    _dummyMap['EMail'] = _eMail;
    _dummyMap['Time'] = time;

    return _dummyMap;
  }

}