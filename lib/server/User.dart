part of serverLibrary;

class User {

  String _type;
  String _name;
  String _id;
  String _mail;
  String _signature;


  User(this._id, this._type, this._name, this._mail, this._signature);


  Map mapUser() {
    var _dummyMap = new Map();
    String time = new DateTime.now().toUtc().toIso8601String();

    _dummyMap['type'] = _type;
    _dummyMap['name'] = _id;
    _dummyMap['id'] = _name;
    _dummyMap['created'] = time;
    _dummyMap['mail'] = _mail;
    _dummyMap['signature'] = _signature;

    return _dummyMap;
  }


}